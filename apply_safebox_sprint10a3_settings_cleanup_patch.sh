#!/usr/bin/env bash
set -euo pipefail

# SafeBox Sprint 10A-3 — Settings Cleanup

ROOT="$(pwd)"
if [ ! -d "$ROOT/safebox-desktop" ]; then
  echo "ERROR: Run this from safebox_sbx_mvp root."
  echo "Current: $ROOT"
  exit 1
fi

cd "$ROOT/safebox-desktop"

echo "==> Backup src/main.ts and src/style.css"
cp src/main.ts "src/main.ts.backup-sprint10a3-settings.$(date +%Y%m%d%H%M%S)"
cp src/style.css "src/style.css.backup-sprint10a3-settings.$(date +%Y%m%d%H%M%S)" 2>/dev/null || true

if ! grep -q "sprint10a3-settings-single-controller-v1" src/main.ts; then
cat >> src/main.ts <<'TS'

// SafeBox Sprint 10A-3 — single Settings controller
// Marker: sprint10a3-settings-single-controller-v1
function sbxClosestSettingsField10A3(element: HTMLElement | null) {
  if (!element) return null;

  return (
    element.closest<HTMLElement>("label") ||
    element.closest<HTMLElement>(".field") ||
    element.closest<HTMLElement>(".form-row") ||
    element.closest<HTMLElement>(".settings-field") ||
    element.parentElement
  );
}

function sbxMoveNodeOnce10A3(node: HTMLElement | null, target: HTMLElement | null) {
  if (!node || !target) return;

  if (node.parentElement === target) return;

  target.appendChild(node);
}

function sbxEnsureSettingsShell10A3() {
  const modal = document.querySelector<HTMLElement>("#settingsModal");
  if (!modal) return null;

  const card =
    modal.querySelector<HTMLElement>(".settings-modal") ||
    modal.querySelector<HTMLElement>(".modal-card") ||
    (modal.firstElementChild as HTMLElement | null);

  if (!card) return null;

  modal.classList.add("sbx-settings-10a3");
  modal.classList.add("sbx-hard-settings-fixed");

  let root = card.querySelector<HTMLElement>("#settingsTabsRoot");

  if (!root) {
    root = document.createElement("div");
    root.id = "settingsTabsRoot";
    root.className = "settings-tabs-root sbx-settings-tabs-root-10a3";

    const actions =
      card.querySelector<HTMLElement>(".settings-actions") ||
      card.querySelector<HTMLElement>(".modal-actions");

    if (actions) {
      card.insertBefore(root, actions);
    } else {
      card.appendChild(root);
    }
  }

  if (!root.querySelector("#settingsPanelGeneral") || !root.querySelector(".settings-tabs-nav")) {
    root.innerHTML = `
      <nav class="settings-tabs-nav" aria-label="SafeBox settings sections">
        <button class="settings-tab-button" type="button" data-tab="general">General</button>
        <button class="settings-tab-button" type="button" data-tab="profiles">Access Profiles</button>
        <button class="settings-tab-button" type="button" data-tab="security">Security</button>
      </nav>

      <div class="settings-tab-panels">
        <section id="settingsPanelGeneral" class="settings-tab-panel" data-tab-panel="general"></section>
        <section id="settingsPanelProfiles" class="settings-tab-panel" data-tab-panel="profiles"></section>
        <section id="settingsPanelSecurity" class="settings-tab-panel" data-tab-panel="security"></section>
      </div>
    `;
  }

  return {
    modal,
    card,
    root,
    general: root.querySelector<HTMLElement>("#settingsPanelGeneral"),
    profiles: root.querySelector<HTMLElement>("#settingsPanelProfiles"),
    security: root.querySelector<HTMLElement>("#settingsPanelSecurity")
  };
}

function sbxLabelContains10A3(node: HTMLElement | null, needle: string) {
  if (!node) return false;

  return (node.textContent || "").replace(/\s+/g, " ").toLowerCase().includes(needle.toLowerCase());
}

function sbxFindSettingsNodeByInput10A3(selector: string) {
  const input = document.querySelector<HTMLElement>(selector);
  return sbxClosestSettingsField10A3(input);
}

function sbxFindSettingsNodeByText10A3(needle: string) {
  const modal = document.querySelector<HTMLElement>("#settingsModal");
  if (!modal) return null;

  const candidates = Array.from(
    modal.querySelectorAll<HTMLElement>("label, .field, .form-row, .settings-field, .settings-check, .settings-note")
  );

  return candidates.find((candidate) => sbxLabelContains10A3(candidate, needle)) || null;
}

function sbxEnsurePanelTitle10A3(panel: HTMLElement | null, title: string, subtitle: string) {
  if (!panel) return;

  if (panel.querySelector(".sbx-settings-panel-title-10a3")) return;

  const head = document.createElement("div");
  head.className = "sbx-settings-panel-title-10a3";
  head.innerHTML = `
    <h3>${title}</h3>
    <p>${subtitle}</p>
  `;

  panel.prepend(head);
}

function sbxMoveSettingsContent10A3() {
  const shell = sbxEnsureSettingsShell10A3();
  if (!shell) return;

  const { modal, general, profiles, security } = shell;

  const languageField =
    document.querySelector<HTMLElement>("#settingsLanguageField") ||
    document.querySelector<HTMLElement>(".settings-language-field");

  sbxMoveNodeOnce10A3(languageField, general);

  sbxMoveNodeOnce10A3(sbxFindSettingsNodeByInput10A3("#settingsDefaultName"), general);
  sbxMoveNodeOnce10A3(sbxFindSettingsNodeByInput10A3("#settingsGlobalSenderLabel"), general);

  const profilesSection =
    modal.querySelector<HTMLElement>(".profiles-section") ||
    document.querySelector<HTMLElement>("#settingsProfilesList")?.closest<HTMLElement>(".profiles-section") ||
    document.querySelector<HTMLElement>("#settingsProfilesList");

  sbxMoveNodeOnce10A3(profilesSection, profiles);

  sbxMoveNodeOnce10A3(sbxFindSettingsNodeByInput10A3("#settingsUseGlobalCode"), security);
  sbxMoveNodeOnce10A3(sbxFindSettingsNodeByInput10A3("#settingsGlobalCode"), security);

  const globalCodeRow = sbxFindSettingsNodeByText10A3("Global code");
  if (globalCodeRow && globalCodeRow.querySelector("#settingsGlobalCode")) {
    sbxMoveNodeOnce10A3(globalCodeRow, security);
  }

  const globalCodeNoteCandidates = Array.from(modal.querySelectorAll<HTMLElement>(".settings-note, p"));
  globalCodeNoteCandidates.forEach((node) => {
    const content = (node.textContent || "").toLowerCase();

    if (
      content.includes("global code") ||
      content.includes("code global") ||
      content.includes("keychain") ||
      content.includes("credential manager")
    ) {
      sbxMoveNodeOnce10A3(node, security);
    }
  });

  modal
    .querySelectorAll<HTMLElement>("label, .field, .form-row, .settings-field")
    .forEach((node) => {
      const content = (node.textContent || "").replace(/\s+/g, " ").toLowerCase();

      if (
        content.includes("default access profile") ||
        content.includes("profil d’accès par défaut") ||
        content.includes("profil d'acces par defaut")
      ) {
        node.classList.add("legacy-default-access-field");
        node.style.display = "none";
      }
    });

  sbxEnsurePanelTitle10A3(general, "General", "Language and sender defaults.");
  sbxEnsurePanelTitle10A3(profiles, "Access Profiles", "Keep SafeBox simple: add a profile only when you need separate access.");
  sbxEnsurePanelTitle10A3(security, "Security", "Session codes and security notes.");
}

function sbxActivateSettingsTab10A3(tabName: string) {
  const root = document.querySelector<HTMLElement>("#settingsTabsRoot");
  if (!root) return;

  const safeTab = ["general", "profiles", "security"].includes(tabName) ? tabName : "general";

  root.querySelectorAll<HTMLButtonElement>(".settings-tab-button").forEach((button) => {
    const active = button.dataset.tab === safeTab;
    button.classList.toggle("active", active);
    button.setAttribute("aria-selected", active ? "true" : "false");
  });

  root.querySelectorAll<HTMLElement>(".settings-tab-panel").forEach((panel) => {
    const active = panel.dataset.tabPanel === safeTab;
    panel.classList.toggle("active", active);
    panel.hidden = !active;
  });

  try {
    sessionStorage.setItem("safebox.settings.activeTab.v1", safeTab);
  } catch {}
}

function sbxSettingsSingleController10A3() {
  const modal = document.querySelector<HTMLElement>("#settingsModal");
  if (!modal) return;

  sbxMoveSettingsContent10A3();

  const activeTab = (() => {
    try {
      return sessionStorage.getItem("safebox.settings.activeTab.v1") || "general";
    } catch {
      return "general";
    }
  })();

  sbxActivateSettingsTab10A3(activeTab);

  try {
    const applyI18n = (window as any).sbxApplyI18n;
    if (typeof applyI18n === "function") {
      applyI18n();
    }
  } catch {}

  try {
    renderAccessProfilesSettings();
    renderCreateProfileSelect();
    sbxHideMainAccessProfileWhenEmpty();
  } catch {}
}

document.addEventListener(
  "click",
  (event) => {
    const target = event.target as HTMLElement | null;

    const tabButton = target?.closest<HTMLButtonElement>("#settingsTabsRoot .settings-tab-button");

    if (tabButton) {
      event.preventDefault();
      event.stopPropagation();
      sbxActivateSettingsTab10A3(tabButton.dataset.tab || "general");
      return;
    }

    if (target?.closest("#settingsBtn")) {
      setTimeout(sbxSettingsSingleController10A3, 40);
      setTimeout(sbxSettingsSingleController10A3, 160);
      setTimeout(sbxSettingsSingleController10A3, 400);
    }
  },
  true
);

document.addEventListener("change", (event) => {
  const target = event.target as HTMLElement | null;

  if (target?.id === "settingsLanguageSelect") {
    setTimeout(sbxSettingsSingleController10A3, 40);
    setTimeout(sbxSettingsSingleController10A3, 180);
  }
});

setTimeout(sbxSettingsSingleController10A3, 100);
setTimeout(sbxSettingsSingleController10A3, 500);
setTimeout(sbxSettingsSingleController10A3, 1200);

console.debug("sprint10a3-settings-single-controller-v1");

TS
fi

if ! grep -q "sprint10a3-settings-single-controller-v1" src/style.css; then
cat >> src/style.css <<'CSS'

/* SafeBox Sprint 10A-3 — Settings Cleanup */
:root {
  --sprint10a3-settings-single-controller-v1: 1;
}

#settingsModal.sbx-settings-10a3 {
  position: fixed !important;
  inset: 0 !important;
  z-index: 1000000 !important;
  display: grid !important;
  place-items: center !important;
  padding: 24px !important;
  overflow: hidden !important;
  background: rgba(3, 8, 16, 0.72) !important;
}

#settingsModal.sbx-settings-10a3.hidden {
  display: none !important;
}

#settingsModal.sbx-settings-10a3 > .settings-modal,
#settingsModal.sbx-settings-10a3 > .modal-card,
#settingsModal.sbx-settings-10a3 .settings-modal {
  width: min(760px, calc(100vw - 48px)) !important;
  height: min(820px, calc(100vh - 48px)) !important;
  max-height: calc(100vh - 48px) !important;
  display: flex !important;
  flex-direction: column !important;
  overflow: hidden !important;
  padding: 0 !important;
  border-radius: 22px !important;
}

#settingsModal.sbx-settings-10a3 .modal-head {
  flex: none !important;
  padding: 24px 26px 18px !important;
}

#settingsModal.sbx-settings-10a3 #settingsTabsRoot {
  flex: 1 1 auto !important;
  min-height: 0 !important;
  display: flex !important;
  flex-direction: column !important;
  padding: 18px 26px 0 !important;
}

#settingsModal.sbx-settings-10a3 .settings-tabs-nav {
  flex: none !important;
  display: flex !important;
  flex-direction: row !important;
  gap: 6px !important;
  padding: 5px !important;
  margin: 0 0 18px !important;
  border-radius: 14px !important;
}

#settingsModal.sbx-settings-10a3 .settings-tab-button {
  flex: 1 1 0 !important;
  min-width: 0 !important;
  min-height: 40px !important;
  cursor: pointer !important;
  border-radius: 10px !important;
  text-align: center !important;
  white-space: nowrap !important;
}

#settingsModal.sbx-settings-10a3 .settings-tab-button.active {
  background: rgba(255, 255, 255, 0.13) !important;
  color: var(--text) !important;
}

#settingsModal.sbx-settings-10a3 .settings-tab-panels {
  flex: 1 1 auto !important;
  min-height: 0 !important;
  overflow: hidden !important;
}

#settingsModal.sbx-settings-10a3 .settings-tab-panel {
  height: 100% !important;
  min-height: 0 !important;
  display: none !important;
  overflow-y: auto !important;
  overflow-x: hidden !important;
  scrollbar-gutter: stable !important;
  padding: 6px 12px 110px 2px !important;
}

#settingsModal.sbx-settings-10a3 .settings-tab-panel.active {
  display: block !important;
}

#settingsModal.sbx-settings-10a3 .settings-actions,
#settingsModal.sbx-settings-10a3 .modal-actions {
  flex: none !important;
  position: sticky !important;
  bottom: 0 !important;
  z-index: 30 !important;
  margin: 0 !important;
  padding: 16px 26px 22px !important;
}

.sbx-settings-panel-title-10a3 {
  margin: 0 0 16px !important;
  padding-bottom: 14px !important;
  border-bottom: 1px solid rgba(150, 170, 195, 0.20) !important;
}

.sbx-settings-panel-title-10a3 h3 {
  margin: 0 !important;
  font-size: 15px !important;
  font-weight: 900 !important;
  letter-spacing: -0.01em !important;
}

.sbx-settings-panel-title-10a3 p {
  margin: 5px 0 0 !important;
  color: var(--muted) !important;
  font-size: 13px !important;
  line-height: 1.45 !important;
}

#settingsModal.sbx-settings-10a3 .legacy-default-access-field {
  display: none !important;
}

#settingsModal.sbx-settings-10a3 > #settingsLanguageField,
body > #settingsLanguageField,
#app > #settingsLanguageField,
.modal-backdrop > #settingsLanguageField {
  display: none !important;
}

#settingsModal.sbx-settings-10a3 .settings-tab-panel::-webkit-scrollbar {
  width: 10px !important;
}

#settingsModal.sbx-settings-10a3 .settings-tab-panel::-webkit-scrollbar-thumb {
  background: rgba(150, 170, 195, 0.42) !important;
  border-radius: 999px !important;
}

#settingsModal.sbx-settings-10a3 .settings-tab-panel::-webkit-scrollbar-track {
  background: transparent !important;
}

@media (max-width: 760px), (max-height: 760px) {
  #settingsModal.sbx-settings-10a3 {
    padding: 12px !important;
  }

  #settingsModal.sbx-settings-10a3 > .settings-modal,
  #settingsModal.sbx-settings-10a3 > .modal-card,
  #settingsModal.sbx-settings-10a3 .settings-modal {
    width: calc(100vw - 24px) !important;
    height: calc(100vh - 24px) !important;
    max-height: calc(100vh - 24px) !important;
    border-radius: 18px !important;
  }

  #settingsModal.sbx-settings-10a3 .settings-tabs-nav {
    flex-direction: column !important;
  }

  #settingsModal.sbx-settings-10a3 .settings-tab-panel {
    padding-bottom: 130px !important;
  }
}

CSS
fi

echo "==> Build check"
rm -rf dist node_modules/.vite
npm run build

echo ""
echo "==> Verify Sprint 10A-3 marker"
grep -R -- "sprint10a3-settings-single-controller-v1" dist || echo "ERROR: Sprint 10A-3 marker absent from dist"

echo ""
echo "Sprint 10A-3 Settings Cleanup applied."
echo "Run:"
echo "  npm run tauri dev"
