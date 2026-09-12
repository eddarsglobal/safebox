#!/usr/bin/env bash
set -euo pipefail

# SafeBox Sprint 10A-3D — Settings Dedupe
#
# Fixes:
# - duplicate Access Profiles title
# - duplicate Security title/note
# - panels leaking into each other after old controllers run
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
cp src/main.ts "src/main.ts.backup-sprint10a3d-settings-dedupe.$(date +%Y%m%d%H%M%S)"
cp src/style.css "src/style.css.backup-sprint10a3d-settings-dedupe.$(date +%Y%m%d%H%M%S)" 2>/dev/null || true

if ! grep -q "sprint10a3d-settings-dedupe-v1" src/main.ts; then
cat >> src/main.ts <<'TS'

// SafeBox Sprint 10A-3D — Settings dedupe
// Marker: sprint10a3d-settings-dedupe-v1
function sbxNormalizeSettingsDedupe10A3D() {
  const modal = document.querySelector<HTMLElement>("#settingsModal");
  const root = document.querySelector<HTMLElement>("#settingsTabsRoot");

  if (!modal || !root) return;

  const general = root.querySelector<HTMLElement>("#settingsPanelGeneral");
  const profiles = root.querySelector<HTMLElement>("#settingsPanelProfiles");
  const security = root.querySelector<HTMLElement>("#settingsPanelSecurity");

  // Access Profiles panel already has .profiles-section with its own header.
  // Remove extra generic panel titles there.
  profiles
    ?.querySelectorAll<HTMLElement>(".sbx-settings-panel-title-10a3, .sbx-settings-panel-title-10a3b, .sbx-settings-panel-title-10a3c")
    .forEach((node) => node.remove());

  // Security should show only one title and one MVP note.
  const securityTitles = Array.from(
    security?.querySelectorAll<HTMLElement>(".sbx-settings-panel-title-10a3, .sbx-settings-panel-title-10a3b, .sbx-settings-panel-title-10a3c") || []
  );

  securityTitles.slice(1).forEach((node) => node.remove());

  const securityNotes = Array.from(
    security?.querySelectorAll<HTMLElement>(".settings-note, p") || []
  ).filter((node) => {
    const text = (node.textContent || "").toLowerCase();
    return (
      text.includes("mvp") ||
      text.includes("global code") ||
      text.includes("code global") ||
      text.includes("keychain") ||
      text.includes("credential manager")
    );
  });

  securityNotes.forEach((node, index) => {
    if (index > 0) {
      node.remove();
    }
  });

  // Profiles panel should only have one profiles section.
  const profileSections = Array.from(profiles?.querySelectorAll<HTMLElement>(".profiles-section") || []);
  profileSections.slice(1).forEach((node) => node.remove());

  // Profiles empty-state may be rendered more than once by old controllers.
  const emptyStates = Array.from(profiles?.querySelectorAll<HTMLElement>(".profiles-empty-state, .compact-profiles-empty") || []);
  emptyStates.slice(1).forEach((node) => node.remove());

  // Remove old titles outside panels if they leaked into modal.
  modal
    .querySelectorAll<HTMLElement>(".sbx-settings-panel-title-10a3, .sbx-settings-panel-title-10a3b")
    .forEach((node) => {
      if (!node.closest("#settingsPanelGeneral") && !node.closest("#settingsPanelSecurity")) {
        node.remove();
      }
    });

  // Force exactly one visible panel.
  let activeTab = "general";

  try {
    activeTab = sessionStorage.getItem("safebox.settings.activeTab.v1") || "general";
  } catch {}

  if (!["general", "profiles", "security"].includes(activeTab)) {
    activeTab = "general";
  }

  root.querySelectorAll<HTMLButtonElement>(".settings-tab-button").forEach((button) => {
    const active = button.dataset.tab === activeTab;
    button.classList.toggle("active", active);
    button.setAttribute("aria-selected", active ? "true" : "false");
  });

  root.querySelectorAll<HTMLElement>(".settings-tab-panel").forEach((panel) => {
    const active = panel.dataset.tabPanel === activeTab;
    panel.classList.toggle("active", active);
    panel.hidden = !active;
    panel.style.display = active ? "block" : "none";
  });

  modal.classList.add("sbx-settings-deduped-10a3d");
}

document.addEventListener(
  "click",
  (event) => {
    const target = event.target as HTMLElement | null;

    const tabButton = target?.closest<HTMLButtonElement>("#settingsTabsRoot .settings-tab-button");

    if (tabButton) {
      try {
        sessionStorage.setItem("safebox.settings.activeTab.v1", tabButton.dataset.tab || "general");
      } catch {}

      setTimeout(sbxNormalizeSettingsDedupe10A3D, 10);
      setTimeout(sbxNormalizeSettingsDedupe10A3D, 80);
      setTimeout(sbxNormalizeSettingsDedupe10A3D, 180);
      return;
    }

    if (target?.closest("#settingsBtn")) {
      setTimeout(sbxNormalizeSettingsDedupe10A3D, 80);
      setTimeout(sbxNormalizeSettingsDedupe10A3D, 220);
      setTimeout(sbxNormalizeSettingsDedupe10A3D, 500);
    }
  },
  true
);

document.addEventListener("change", (event) => {
  const target = event.target as HTMLElement | null;

  if (target?.id === "settingsLanguageSelect") {
    setTimeout(sbxNormalizeSettingsDedupe10A3D, 80);
    setTimeout(sbxNormalizeSettingsDedupe10A3D, 220);
  }
});

setTimeout(sbxNormalizeSettingsDedupe10A3D, 200);
setTimeout(sbxNormalizeSettingsDedupe10A3D, 700);
setTimeout(sbxNormalizeSettingsDedupe10A3D, 1400);

console.debug("sprint10a3d-settings-dedupe-v1");
TS
fi

if ! grep -q "sprint10a3d-settings-dedupe-v1" src/style.css; then
cat >> src/style.css <<'CSS'

/* SafeBox Sprint 10A-3D — Settings Dedupe */
:root {
  --sprint10a3d-settings-dedupe-v1: 1;
}

/* Access Profiles panel uses the profiles section header only. */
#settingsModal.sbx-settings-deduped-10a3d #settingsPanelProfiles > .sbx-settings-panel-title-10a3,
#settingsModal.sbx-settings-deduped-10a3d #settingsPanelProfiles > .sbx-settings-panel-title-10a3b,
#settingsModal.sbx-settings-deduped-10a3d #settingsPanelProfiles > .sbx-settings-panel-title-10a3c {
  display: none !important;
}

/* Exactly one Settings panel should be visible. */
#settingsModal.sbx-settings-deduped-10a3d .settings-tab-panel {
  display: none !important;
}

#settingsModal.sbx-settings-deduped-10a3d .settings-tab-panel.active {
  display: block !important;
}

/* Keep tabs horizontal. */
#settingsModal.sbx-settings-deduped-10a3d .settings-tabs-nav {
  display: flex !important;
  flex-direction: row !important;
}

#settingsModal.sbx-settings-deduped-10a3d .settings-tab-button {
  flex: 1 1 0 !important;
  min-width: 0 !important;
}
CSS
fi

echo "==> Build check"
rm -rf dist node_modules/.vite
npm run build

echo ""
echo "==> Verify Sprint 10A-3D marker"
grep -R -- "sprint10a3d-settings-dedupe-v1" dist || echo "ERROR: Sprint 10A-3D marker absent from dist"

echo ""
echo "Sprint 10A-3D Settings Dedupe applied."
echo "Run:"
echo "  npm run tauri dev"
