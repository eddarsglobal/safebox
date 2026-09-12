#!/usr/bin/env bash
set -euo pipefail

# SafeBox Sprint 10A-4B — i18n no flicker
#
# Fixes:
# - Security MVP note appears twice for ~0.5 sec before disappearing.
#
# Strategy:
# - CSS hides duplicate security notes immediately.
# - JS dedupes synchronously when Settings opens / tab changes / language changes.
#
# Does NOT touch encryption / SBX format / receiver unlock logic / macOS icon.

ROOT="$(pwd)"
if [ ! -d "$ROOT/safebox-desktop" ]; then
  echo "ERROR: Run this from safebox_sbx_mvp root."
  echo "Current: $ROOT"
  exit 1
fi

cd "$ROOT/safebox-desktop"

echo "==> Backup src/main.ts and src/style.css"
cp src/main.ts "src/main.ts.backup-sprint10a4b-i18n-no-flicker.$(date +%Y%m%d%H%M%S)"
cp src/style.css "src/style.css.backup-sprint10a4b-i18n-no-flicker.$(date +%Y%m%d%H%M%S)" 2>/dev/null || true

if ! grep -q "sprint10a4b-i18n-no-flicker-v1" src/main.ts; then
cat >> src/main.ts <<'TS'

// SafeBox Sprint 10A-4B — i18n no flicker
// Marker: sprint10a4b-i18n-no-flicker-v1
function sbxSecurityNoteNoFlicker10A4B() {
  const security = document.querySelector<HTMLElement>("#settingsPanelSecurity");
  if (!security) return;

  const notes = Array.from(
    security.querySelectorAll<HTMLElement>(".settings-note, p")
  ).filter((node) => {
    if (node.closest(".sbx-settings-panel-title-10a3c")) return false;
    if (node.closest(".sbx-settings-panel-title-10a3b")) return false;
    if (node.closest(".sbx-settings-panel-title-10a3")) return false;

    const text = (node.textContent || "").toLowerCase();

    return (
      text.includes("mvp") ||
      text.includes("global code") ||
      text.includes("code global") ||
      text.includes("keychain") ||
      text.includes("credential manager")
    );
  });

  notes.forEach((note, index) => {
    note.classList.add("sbx-security-note-candidate-10a4b");

    if (index === 0) {
      note.classList.add("sbx-security-note-primary-10a4b");
      note.classList.remove("sbx-security-note-duplicate-10a4b");
      note.style.display = "";
    } else {
      note.classList.add("sbx-security-note-duplicate-10a4b");
      note.style.display = "none";
    }
  });
}

function sbxSettingsNoFlickerNormalize10A4B() {
  sbxSecurityNoteNoFlicker10A4B();

  try {
    const root = document.querySelector<HTMLElement>("#settingsTabsRoot");

    if (root) {
      let activeTab = "general";

      try {
        activeTab = sessionStorage.getItem("safebox.settings.activeTab.v1") || "general";
      } catch {}

      if (!["general", "profiles", "security"].includes(activeTab)) {
        activeTab = "general";
      }

      root.querySelectorAll<HTMLElement>(".settings-tab-panel").forEach((panel) => {
        const active = panel.dataset.tabPanel === activeTab;
        panel.classList.toggle("active", active);
        panel.hidden = !active;
        panel.style.display = active ? "block" : "none";
      });
    }
  } catch {}
}

document.addEventListener(
  "click",
  (event) => {
    const target = event.target as HTMLElement | null;

    if (
      target?.closest("#settingsBtn") ||
      target?.closest("#settingsTabsRoot .settings-tab-button") ||
      target?.closest("#settingsModal")
    ) {
      sbxSettingsNoFlickerNormalize10A4B();
      requestAnimationFrame(sbxSettingsNoFlickerNormalize10A4B);
    }
  },
  true
);

document.addEventListener("change", (event) => {
  const target = event.target as HTMLElement | null;

  if (target?.id === "settingsLanguageSelect") {
    sbxSettingsNoFlickerNormalize10A4B();
    requestAnimationFrame(sbxSettingsNoFlickerNormalize10A4B);
  }
});

if (!(window as any).__safeboxNoFlickerObserver10A4B) {
  const observer = new MutationObserver(() => {
    sbxSettingsNoFlickerNormalize10A4B();
  });

  observer.observe(document.body, {
    childList: true,
    subtree: true,
    characterData: true
  });

  (window as any).__safeboxNoFlickerObserver10A4B = observer;
}

sbxSettingsNoFlickerNormalize10A4B();
requestAnimationFrame(sbxSettingsNoFlickerNormalize10A4B);

console.debug("sprint10a4b-i18n-no-flicker-v1");
TS
fi

if ! grep -q "sprint10a4b-i18n-no-flicker-v1" src/style.css; then
cat >> src/style.css <<'CSS'

/* SafeBox Sprint 10A-4B — i18n no flicker */
:root {
  --sprint10a4b-i18n-no-flicker-v1: 1;
}

/* Hide duplicate MVP/security notes immediately, before JS cleanup timing is visible. */
#settingsPanelSecurity .settings-note + .settings-note,
#settingsPanelSecurity > p.settings-note ~ p.settings-note,
#settingsPanelSecurity .sbx-security-note-duplicate-10a4b {
  display: none !important;
}

/* When old controllers create two MVP notes as direct children, keep only the first. */
#settingsPanelSecurity > p.sbx-security-note-10a3b ~ p,
#settingsPanelSecurity > p.sbx-security-note-10a3c ~ p,
#settingsPanelSecurity > p.sbx-security-note-candidate-10a4b ~ p.sbx-security-note-candidate-10a4b {
  display: none !important;
}
CSS
fi

echo "==> Build check"
rm -rf dist node_modules/.vite
npm run build

echo ""
echo "==> Verify Sprint 10A-4B marker"
grep -R -- "sprint10a4b-i18n-no-flicker-v1" dist || echo "ERROR: Sprint 10A-4B marker absent from dist"

echo ""
echo "Sprint 10A-4B i18n no flicker applied."
echo "Run:"
echo "  npm run tauri dev"
