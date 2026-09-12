#!/usr/bin/env bash
set -euo pipefail

# SafeBox Sprint 10A-6C — Hide main Access Profile hard fix
#
# Fixes:
# - "Access profile" showing on main window even when Settings has no profiles.
#
# Rules:
# - If Access Profiles is empty: hide main Access profile field/select.
# - If old demo profiles Private / Work / Family exist: clear them.
# - If a controller recreates the field: hide it immediately again.
# - If a real profile exists: allow the field to show.
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
cp src/main.ts "src/main.ts.backup-sprint10a6c-hide-main-access-profile.$(date +%Y%m%d%H%M%S)"
cp src/style.css "src/style.css.backup-sprint10a6c-hide-main-access-profile.$(date +%Y%m%d%H%M%S)" 2>/dev/null || true

if ! grep -q "sprint10a6c-hide-main-access-profile-v1" src/main.ts; then
cat >> src/main.ts <<'TS'

// SafeBox Sprint 10A-6C — hard hide main Access Profile when profiles are empty
// Marker: sprint10a6c-hide-main-access-profile-v1
function sbxReadRealProfiles10A6C() {
  const profilesKey = "safebox.accessProfiles.v1";
  const demoNames = new Set(["private", "work", "family"]);

  try {
    const raw = localStorage.getItem(profilesKey);
    if (!raw) return [];

    const parsed = JSON.parse(raw);
    if (!Array.isArray(parsed)) return [];

    const profiles = parsed.filter((item) => {
      if (!item || typeof item !== "object") return false;

      const profileName = String((item as any).profileName || "").trim();
      const accessLabel = String((item as any).accessLabel || "").trim();
      const senderLabel = String((item as any).senderLabel || "").trim();

      return !!(profileName || accessLabel || senderLabel);
    });

    const oldDemoOnly =
      profiles.length > 0 &&
      profiles.length <= 3 &&
      profiles.every((item) => {
        const profileName = String((item as any).profileName || "").trim().toLowerCase();
        const accessLabel = String((item as any).accessLabel || "").trim().toLowerCase();
        const senderLabel = String((item as any).senderLabel || "").trim().toLowerCase();

        return (
          demoNames.has(profileName) &&
          (!accessLabel || demoNames.has(accessLabel) || accessLabel === "profile") &&
          (!senderLabel || demoNames.has(senderLabel))
        );
      });

    if (oldDemoOnly) {
      localStorage.setItem(profilesKey, "[]");

      try {
        const settingsRaw = localStorage.getItem("safebox.settings.v1");
        if (settingsRaw) {
          const current = JSON.parse(settingsRaw);
          current.defaultAccessProfile = "";
          localStorage.setItem("safebox.settings.v1", JSON.stringify(current));
        }
      } catch {}

      return [];
    }

    return profiles;
  } catch {
    return [];
  }
}

function sbxIsMainWindowNode10A6C(node: HTMLElement) {
  return !(
    node.closest("#settingsModal") ||
    node.closest("#accessProfileEditorModal") ||
    node.closest("#hardReceiverOverlay") ||
    node.closest("#howToUseModal") ||
    node.closest("#helpModal")
  );
}

function sbxNodeLooksLikeAccessProfileField10A6C(node: HTMLElement) {
  const text = (node.textContent || "").replace(/\s+/g, " ").trim().toLowerCase();

  const hasAccessText =
    text.includes("access profile") ||
    text.includes("profil d’accès") ||
    text.includes("profil d'acces") ||
    text.includes("zugriffsprofil") ||
    text.includes("profil pristupa") ||
    text.includes("perfil de acceso") ||
    text.includes("ملف الوصول");

  const containsCreateProfileSelect = !!node.querySelector("#createProfileSelect");
  const isCreateProfileSelect = node.id === "createProfileSelect";

  return hasAccessText || containsCreateProfileSelect || isCreateProfileSelect;
}

function sbxHideMainAccessProfileHard10A6C() {
  const profiles = sbxReadRealProfiles10A6C();
  const hasProfiles = profiles.length > 0;

  const hide = (node: HTMLElement) => {
    node.dataset.sbxMainAccessProfileHidden10A6C = "1";
    node.classList.add("sbx-main-access-profile-hidden-10a6c");
    node.style.display = "none";
    node.style.visibility = "hidden";
    node.style.opacity = "0";
    node.style.height = "0";
    node.style.maxHeight = "0";
    node.style.margin = "0";
    node.style.padding = "0";
    node.style.overflow = "hidden";
  };

  const show = (node: HTMLElement) => {
    if (node.dataset.sbxMainAccessProfileHidden10A6C !== "1") return;

    delete node.dataset.sbxMainAccessProfileHidden10A6C;
    node.classList.remove("sbx-main-access-profile-hidden-10a6c");
    node.style.display = "";
    node.style.visibility = "";
    node.style.opacity = "";
    node.style.height = "";
    node.style.maxHeight = "";
    node.style.margin = "";
    node.style.padding = "";
    node.style.overflow = "";
  };

  document.querySelectorAll<HTMLSelectElement>("#createProfileSelect").forEach((select) => {
    const wrapper =
      select.closest<HTMLElement>("label") ||
      select.closest<HTMLElement>(".field") ||
      select.closest<HTMLElement>(".form-row") ||
      select.closest<HTMLElement>(".input-group") ||
      select.closest<HTMLElement>(".create-field") ||
      select.parentElement;

    select.disabled = !hasProfiles;

    if (!hasProfiles) {
      select.innerHTML = "";
      hide(select);
      if (wrapper && sbxIsMainWindowNode10A6C(wrapper)) hide(wrapper);
    } else {
      show(select);
      if (wrapper && sbxIsMainWindowNode10A6C(wrapper)) show(wrapper);
    }
  });

  document
    .querySelectorAll<HTMLElement>("label, .field, .form-row, .input-group, .create-field, .advanced-box > *, .sender-panel *")
    .forEach((node) => {
      if (!sbxIsMainWindowNode10A6C(node)) return;
      if (!sbxNodeLooksLikeAccessProfileField10A6C(node)) return;

      if (!hasProfiles) {
        hide(node);
      } else {
        show(node);
      }
    });

  document.body.classList.toggle("sbx-no-access-profiles-10a6c", !hasProfiles);
  document.body.classList.toggle("sbx-has-access-profiles-10a6c", hasProfiles);
}

document.addEventListener(
  "click",
  () => {
    sbxHideMainAccessProfileHard10A6C();
    requestAnimationFrame(sbxHideMainAccessProfileHard10A6C);
    setTimeout(sbxHideMainAccessProfileHard10A6C, 80);
    setTimeout(sbxHideMainAccessProfileHard10A6C, 240);
  },
  true
);

document.addEventListener("change", (event) => {
  const target = event.target as HTMLElement | null;

  if (
    target?.id === "createProfileSelect" ||
    target?.closest("#settingsModal") ||
    target?.closest("#accessProfileEditorModal")
  ) {
    sbxHideMainAccessProfileHard10A6C();
    requestAnimationFrame(sbxHideMainAccessProfileHard10A6C);
    setTimeout(sbxHideMainAccessProfileHard10A6C, 120);
  }
});

window.addEventListener("storage", sbxHideMainAccessProfileHard10A6C);

if (!(window as any).__safeboxHideMainAccessProfileObserver10A6C) {
  const observer = new MutationObserver(() => {
    sbxHideMainAccessProfileHard10A6C();
  });

  observer.observe(document.body, {
    childList: true,
    subtree: true,
    characterData: true,
    attributes: true,
    attributeFilter: ["class", "style"]
  });

  (window as any).__safeboxHideMainAccessProfileObserver10A6C = observer;
}

setTimeout(sbxHideMainAccessProfileHard10A6C, 20);
setTimeout(sbxHideMainAccessProfileHard10A6C, 120);
setTimeout(sbxHideMainAccessProfileHard10A6C, 500);
setTimeout(sbxHideMainAccessProfileHard10A6C, 1200);
setInterval(sbxHideMainAccessProfileHard10A6C, 700);

console.debug("sprint10a6c-hide-main-access-profile-v1");
TS
fi

if ! grep -q "sprint10a6c-hide-main-access-profile-v1" src/style.css; then
cat >> src/style.css <<'CSS'

/* SafeBox Sprint 10A-6C — Hide main Access Profile hard fix */
:root {
  --sprint10a6c-hide-main-access-profile-v1: 1;
}

body.sbx-no-access-profiles-10a6c #createProfileSelect,
body.sbx-no-access-profiles-10a6c .sbx-main-access-profile-hidden-10a6c {
  display: none !important;
  visibility: hidden !important;
  opacity: 0 !important;
  pointer-events: none !important;
  height: 0 !important;
  min-height: 0 !important;
  max-height: 0 !important;
  margin: 0 !important;
  padding: 0 !important;
  overflow: hidden !important;
}

/* Extra guard for common main-window form wrappers. */
body.sbx-no-access-profiles-10a6c label:has(#createProfileSelect),
body.sbx-no-access-profiles-10a6c .field:has(#createProfileSelect),
body.sbx-no-access-profiles-10a6c .form-row:has(#createProfileSelect),
body.sbx-no-access-profiles-10a6c .input-group:has(#createProfileSelect),
body.sbx-no-access-profiles-10a6c .create-field:has(#createProfileSelect) {
  display: none !important;
}
CSS
fi

echo "==> Build check"
rm -rf dist node_modules/.vite
npm run build

echo ""
echo "==> Verify Sprint 10A-6C marker"
grep -R -- "sprint10a6c-hide-main-access-profile-v1" dist || echo "ERROR: Sprint 10A-6C marker absent from dist"

echo ""
echo "Sprint 10A-6C Hide main Access Profile applied."
echo "Run:"
echo "  npm run tauri dev"
