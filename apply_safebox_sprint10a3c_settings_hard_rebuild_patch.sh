#!/usr/bin/env bash
set -euo pipefail

# SafeBox Sprint 10A-3C — Settings Hard Rebuild
#
# Fixes:
# - duplicated General / Access Profiles / Security titles
# - all sections appearing together
# - vertical tab regression
#
# Strategy:
# - detach real form fields
# - remove old duplicated Settings panels/titles
# - rebuild one clean Settings root
# - reattach fields into the correct panel
# - force exactly one active panel

ROOT="$(pwd)"
if [ ! -d "$ROOT/safebox-desktop" ]; then
  echo "ERROR: Run this from safebox_sbx_mvp root."
  echo "Current: $ROOT"
  exit 1
fi

cd "$ROOT/safebox-desktop"

echo "==> Backup src/main.ts and src/style.css"
cp src/main.ts "src/main.ts.backup-sprint10a3c-settings-hard-rebuild.$(date +%Y%m%d%H%M%S)"
cp src/style.css "src/style.css.backup-sprint10a3c-settings-hard-rebuild.$(date +%Y%m%d%H%M%S)" 2>/dev/null || true

if ! grep -q "sprint10a3c-settings-hard-rebuild-v1" src/main.ts; then
cat >> src/main.ts <<'TS'

// SafeBox Sprint 10A-3C — Settings hard rebuild
// Marker: sprint10a3c-settings-hard-rebuild-v1
let sbxSettingsHardRebuildRunning10A3C = false;

function sbxFieldWrapper10A3C(selector: string) {
  const input = document.querySelector<HTMLElement>(selector);

  if (!input) return null;

  return (
    input.closest<HTMLElement>("label") ||
    input.closest<HTMLElement>(".field") ||
    input.closest<HTMLElement>(".form-row") ||
    input.closest<HTMLElement>(".settings-field") ||
    input.parentElement
  );
}

function sbxMakeLanguageField10A3C() {
  let field =
    document.querySelector<HTMLElement>("#settingsLanguageField") ||
    document.querySelector<HTMLElement>(".settings-language-field");

  if (!field) {
    field = document.createElement("label");
    field.id = "settingsLanguageField";
    field.className = "settings-language-field";
    field.innerHTML = `
      <span class="settings-language-title">Language</span>
      <select id="settingsLanguageSelect">
        <option value="auto">Auto - System language</option>
        <option value="en">English</option>
        <option value="fr">Français</option>
        <option value="de">Deutsch</option>
        <option value="hr">Hrvatski / BCS</option>
        <option value="ar">العربية</option>
        <option value="es">Español</option>
      </select>
    `;
  }

  const select = field.querySelector<HTMLSelectElement>("#settingsLanguageSelect");

  if (select) {
    try {
      select.value = localStorage.getItem("safebox.language.v1") || "auto";
    } catch {
      select.value = "auto";
    }

    if (select.dataset.sbx10a3cBound !== "1") {
      select.dataset.sbx10a3cBound = "1";

      select.addEventListener("change", () => {
        try {
          localStorage.setItem("safebox.language.v1", select.value);
        } catch {}

        setTimeout(() => {
          try {
            const applyI18n = (window as any).sbxApplyI18n;
            if (typeof applyI18n === "function") applyI18n();
          } catch {}

          sbxSettingsHardRebuild10A3C();
        }, 30);
      });
    }
  }

  return field;
}

function sbxMakeDefaultNameField10A3C() {
  let field = sbxFieldWrapper10A3C("#settingsDefaultName");

  if (!field) {
    field = document.createElement("label");
    field.className = "settings-field sbx-generated-field-10a3c";
    field.innerHTML = `
      Default SBX name
      <input id="settingsDefaultName" autocomplete="off" />
    `;
  }

  const input = field.querySelector<HTMLInputElement>("#settingsDefaultName");

  if (input && !input.value) {
    try {
      input.value = readSettings().defaultName || "document";
    } catch {
      input.value = "document";
    }
  }

  return field;
}

function sbxMakeSenderField10A3C() {
  let field = sbxFieldWrapper10A3C("#settingsGlobalSenderLabel");

  if (!field) {
    field = document.createElement("label");
    field.className = "settings-field sbx-generated-field-10a3c";
    field.innerHTML = `
      Global sender label
      <input id="settingsGlobalSenderLabel" autocomplete="off" />
    `;
  }

  const input = field.querySelector<HTMLInputElement>("#settingsGlobalSenderLabel");

  if (input && !input.value) {
    try {
      input.value = readSettings().globalSenderLabel || "";
    } catch {
      input.value = "";
    }
  }

  return field;
}

function sbxMakeUseGlobalCodeField10A3C() {
  let field = sbxFieldWrapper10A3C("#settingsUseGlobalCode");

  if (!field) {
    field = document.createElement("label");
    field.className = "settings-check settings-field sbx-generated-field-10a3c";
    field.innerHTML = `
      <input id="settingsUseGlobalCode" type="checkbox" />
      Use global code by default
    `;
  }

  const input = field.querySelector<HTMLInputElement>("#settingsUseGlobalCode");

  if (input) {
    try {
      input.checked = !!readSettings().useGlobalCode;
    } catch {
      input.checked = false;
    }
  }

  return field;
}

function sbxMakeGlobalCodeField10A3C() {
  let field = sbxFieldWrapper10A3C("#settingsGlobalCode");

  if (!field) {
    field = document.createElement("label");
    field.className = "settings-field sbx-generated-field-10a3c";
    field.innerHTML = `
      Global code
      <div class="password-action-row">
        <input id="settingsGlobalCode" type="password" autocomplete="new-password" />
        <button id="toggleSettingsGlobalCode" class="mini-btn" type="button">Show</button>
        <button id="clearSettingsGlobalCode" class="mini-btn danger-link" type="button">Clear</button>
      </div>
    `;
  }

  const input = field.querySelector<HTMLInputElement>("#settingsGlobalCode");

  if (input && !input.value) {
    try {
      input.value = sessionStorage.getItem("safebox.globalCode.v1") || "";
    } catch {
      input.value = "";
    }
  }

  const toggle = field.querySelector<HTMLButtonElement>("#toggleSettingsGlobalCode");
  if (toggle && toggle.dataset.sbx10a3cBound !== "1") {
    toggle.dataset.sbx10a3cBound = "1";
    toggle.addEventListener("click", () => {
      const codeInput = document.querySelector<HTMLInputElement>("#settingsGlobalCode");
      if (!codeInput) return;

      const isHidden = codeInput.type === "password";
      codeInput.type = isHidden ? "text" : "password";
      toggle.textContent = isHidden ? "Hide" : "Show";
    });
  }

  const clear = field.querySelector<HTMLButtonElement>("#clearSettingsGlobalCode");
  if (clear && clear.dataset.sbx10a3cBound !== "1") {
    clear.dataset.sbx10a3cBound = "1";
    clear.addEventListener("click", () => {
      const codeInput = document.querySelector<HTMLInputElement>("#settingsGlobalCode");
      if (codeInput) codeInput.value = "";

      try {
        sessionStorage.removeItem("safebox.globalCode.v1");
      } catch {}
    });
  }

  return field;
}

function sbxMakeProfilesSection10A3C() {
  document.querySelectorAll<HTMLElement>(".profiles-section").forEach((node) => node.remove());

  const section = document.createElement("section");
  section.className = "profiles-section sbx-profiles-section-10a3c";
  section.innerHTML = `
    <div class="profiles-header">
      <div>
        <h3>Access Profiles</h3>
        <p>Keep SafeBox simple: add a profile only when you need separate access.</p>
      </div>
      <button id="addProfileBtn" class="mini-btn" type="button">+ Add profile</button>
    </div>
    <div id="settingsProfilesList" class="profiles-list"></div>
  `;

  return section;
}

function sbxPanelTitle10A3C(title: string, subtitle: string) {
  const node = document.createElement("div");
  node.className = "sbx-settings-panel-title-10a3c";
  node.innerHTML = `<h3>${title}</h3><p>${subtitle}</p>`;
  return node;
}

function sbxSettingsSetActivePanel10A3C(tabName: string) {
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
    panel.style.display = active ? "block" : "none";
  });

  try {
    sessionStorage.setItem("safebox.settings.activeTab.v1", safeTab);
  } catch {}
}

function sbxSettingsHardRebuild10A3C() {
  if (sbxSettingsHardRebuildRunning10A3C) return;
  sbxSettingsHardRebuildRunning10A3C = true;

  try {
    const modal = document.querySelector<HTMLElement>("#settingsModal");
    if (!modal) return;

    const card =
      modal.querySelector<HTMLElement>(".settings-modal") ||
      modal.querySelector<HTMLElement>(".modal-card") ||
      (modal.firstElementChild as HTMLElement | null);

    if (!card) return;

    const languageField = sbxMakeLanguageField10A3C();
    const defaultNameField = sbxMakeDefaultNameField10A3C();
    const senderField = sbxMakeSenderField10A3C();
    const useGlobalCodeField = sbxMakeUseGlobalCodeField10A3C();
    const globalCodeField = sbxMakeGlobalCodeField10A3C();
    const profilesSection = sbxMakeProfilesSection10A3C();

    card.querySelectorAll<HTMLElement>("#settingsTabsRoot").forEach((node) => node.remove());
    card.querySelectorAll<HTMLElement>(".sbx-settings-panel-title-10a3, .sbx-settings-panel-title-10a3b, .sbx-settings-panel-title-10a3c").forEach((node) => node.remove());

    const root = document.createElement("div");
    root.id = "settingsTabsRoot";
    root.className = "settings-tabs-root sbx-settings-tabs-root-10a3c";
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

    const actions =
      card.querySelector<HTMLElement>(".settings-actions") ||
      card.querySelector<HTMLElement>(".modal-actions");

    if (actions) {
      card.insertBefore(root, actions);
    } else {
      card.appendChild(root);
    }

    const general = root.querySelector<HTMLElement>("#settingsPanelGeneral");
    const profiles = root.querySelector<HTMLElement>("#settingsPanelProfiles");
    const security = root.querySelector<HTMLElement>("#settingsPanelSecurity");

    if (general) {
      general.appendChild(sbxPanelTitle10A3C("General", "Language and sender defaults."));
      general.appendChild(languageField);
      general.appendChild(defaultNameField);
      general.appendChild(senderField);
    }

    if (profiles) {
      profiles.appendChild(sbxPanelTitle10A3C("Access Profiles", "Keep SafeBox simple: add a profile only when you need separate access."));
      profiles.appendChild(profilesSection);
    }

    if (security) {
      security.appendChild(sbxPanelTitle10A3C("Security", "Session codes and security notes."));
      security.appendChild(useGlobalCodeField);
      security.appendChild(globalCodeField);

      const note = document.createElement("p");
      note.className = "settings-note sbx-security-note-10a3c";
      note.textContent = "MVP: the global code is kept only for this app session. Permanent secure storage comes later with Keychain / Credential Manager.";
      security.appendChild(note);
    }

    modal.classList.add("sbx-settings-hard-rebuilt-10a3c");

    let activeTab = "general";
    try {
      activeTab = sessionStorage.getItem("safebox.settings.activeTab.v1") || "general";
    } catch {}

    sbxSettingsSetActivePanel10A3C(activeTab);

    try {
      renderAccessProfilesSettings();
      renderCreateProfileSelect();
      sbxHideMainAccessProfileWhenEmpty();
    } catch {}

    try {
      const applyI18n = (window as any).sbxApplyI18n;
      if (typeof applyI18n === "function") applyI18n();
    } catch {}
  } finally {
    sbxSettingsHardRebuildRunning10A3C = false;
  }
}

document.addEventListener(
  "click",
  (event) => {
    const target = event.target as HTMLElement | null;

    const tabButton = target?.closest<HTMLButtonElement>("#settingsTabsRoot .settings-tab-button");

    if (tabButton) {
      event.preventDefault();
      event.stopPropagation();

      const tab = tabButton.dataset.tab || "general";
      sbxSettingsSetActivePanel10A3C(tab);

      setTimeout(() => sbxSettingsSetActivePanel10A3C(tab), 20);
      setTimeout(() => sbxSettingsSetActivePanel10A3C(tab), 120);
      return;
    }

    if (target?.closest("#settingsBtn")) {
      setTimeout(sbxSettingsHardRebuild10A3C, 20);
      setTimeout(sbxSettingsHardRebuild10A3C, 120);
      setTimeout(sbxSettingsHardRebuild10A3C, 360);
    }
  },
  true
);

document.addEventListener("change", (event) => {
  const target = event.target as HTMLElement | null;

  if (target?.id === "settingsLanguageSelect") {
    setTimeout(sbxSettingsHardRebuild10A3C, 80);
  }
});

setTimeout(sbxSettingsHardRebuild10A3C, 100);
setTimeout(sbxSettingsHardRebuild10A3C, 500);
setTimeout(sbxSettingsHardRebuild10A3C, 1200);

console.debug("sprint10a3c-settings-hard-rebuild-v1");
TS
fi

if ! grep -q "sprint10a3c-settings-hard-rebuild-v1" src/style.css; then
cat >> src/style.css <<'CSS'

/* SafeBox Sprint 10A-3C — Settings Hard Rebuild */
:root {
  --sprint10a3c-settings-hard-rebuild-v1: 1;
}

#settingsModal.sbx-settings-hard-rebuilt-10a3c .settings-tabs-nav {
  display: flex !important;
  flex-direction: row !important;
  align-items: center !important;
  gap: 6px !important;
  width: 100% !important;
}

#settingsModal.sbx-settings-hard-rebuilt-10a3c .settings-tab-button {
  flex: 1 1 0 !important;
  min-width: 0 !important;
  width: auto !important;
  min-height: 40px !important;
  white-space: nowrap !important;
  text-align: center !important;
}

#settingsModal.sbx-settings-hard-rebuilt-10a3c .settings-tab-panels {
  flex: 1 1 auto !important;
  min-height: 0 !important;
  overflow: hidden !important;
}

#settingsModal.sbx-settings-hard-rebuilt-10a3c .settings-tab-panel {
  display: none !important;
  height: 100% !important;
  min-height: 0 !important;
  overflow-y: auto !important;
  overflow-x: hidden !important;
  scrollbar-gutter: stable !important;
  padding: 6px 12px 110px 2px !important;
}

#settingsModal.sbx-settings-hard-rebuilt-10a3c .settings-tab-panel.active {
  display: block !important;
}

#settingsModal.sbx-settings-hard-rebuilt-10a3c .settings-tab-panel:not(.active) {
  display: none !important;
}

.sbx-settings-panel-title-10a3c {
  margin: 0 0 16px !important;
  padding-bottom: 14px !important;
  border-bottom: 1px solid rgba(150, 170, 195, 0.22) !important;
}

.sbx-settings-panel-title-10a3c h3 {
  margin: 0 !important;
  font-size: 15px !important;
  font-weight: 900 !important;
}

.sbx-settings-panel-title-10a3c p {
  margin: 5px 0 0 !important;
  color: var(--muted) !important;
  font-size: 13px !important;
  line-height: 1.45 !important;
}

#settingsPanelGeneral #settingsLanguageField,
#settingsPanelGeneral .settings-language-field {
  display: grid !important;
  visibility: visible !important;
  opacity: 1 !important;
}

body > #settingsLanguageField,
#app > #settingsLanguageField,
.modal-backdrop > #settingsLanguageField {
  display: none !important;
}

#settingsModal.sbx-settings-hard-rebuilt-10a3c .sbx-settings-panel-title-10a3,
#settingsModal.sbx-settings-hard-rebuilt-10a3c .sbx-settings-panel-title-10a3b {
  display: none !important;
}

@media (max-width: 760px), (max-height: 760px) {
  #settingsModal.sbx-settings-hard-rebuilt-10a3c .settings-tabs-nav {
    flex-direction: row !important;
  }

  #settingsModal.sbx-settings-hard-rebuilt-10a3c .settings-tab-button {
    font-size: 12px !important;
    padding-left: 6px !important;
    padding-right: 6px !important;
  }
}
CSS
fi

echo "==> Build check"
rm -rf dist node_modules/.vite
npm run build

echo ""
echo "==> Verify Sprint 10A-3C marker"
grep -R -- "sprint10a3c-settings-hard-rebuild-v1" dist || echo "ERROR: Sprint 10A-3C marker absent from dist"

echo ""
echo "Sprint 10A-3C Settings Hard Rebuild applied."
echo "Run:"
echo "  npm run tauri dev"
