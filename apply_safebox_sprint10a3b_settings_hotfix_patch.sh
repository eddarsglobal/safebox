#!/usr/bin/env bash
set -euo pipefail

# SafeBox Sprint 10A-3B — Settings Hotfix
#
# Fixes Sprint 10A-3 regression:
# - tabs became vertical
# - panels appeared empty
#
# This hotfix forces:
# - horizontal tabs
# - visible active panel
# - content restored into General / Access Profiles / Security
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
cp src/main.ts "src/main.ts.backup-sprint10a3b-settings-hotfix.$(date +%Y%m%d%H%M%S)"
cp src/style.css "src/style.css.backup-sprint10a3b-settings-hotfix.$(date +%Y%m%d%H%M%S)" 2>/dev/null || true

if ! grep -q "sprint10a3b-settings-hotfix-horizontal-panels-v1" src/main.ts; then
cat >> src/main.ts <<'TS'

// SafeBox Sprint 10A-3B — Settings hotfix: horizontal tabs + non-empty panels
// Marker: sprint10a3b-settings-hotfix-horizontal-panels-v1
function sbxSettingsHotfixFindField10A3B(selector: string) {
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

function sbxSettingsHotfixMove10A3B(node: HTMLElement | null, target: HTMLElement | null) {
  if (!node || !target) return;

  if (node.parentElement !== target) {
    target.appendChild(node);
  }

  node.classList.remove("hidden");
  node.style.display = "";
  node.style.visibility = "";
  node.style.opacity = "";
}

function sbxSettingsHotfixPanelTitle10A3B(panel: HTMLElement | null, title: string, subtitle: string) {
  if (!panel) return;

  let titleNode = panel.querySelector<HTMLElement>(".sbx-settings-panel-title-10a3b");

  if (!titleNode) {
    titleNode = document.createElement("div");
    titleNode.className = "sbx-settings-panel-title-10a3b";
    panel.prepend(titleNode);
  }

  titleNode.innerHTML = `<h3>${title}</h3><p>${subtitle}</p>`;
}

function sbxSettingsHotfixEnsureLanguage10A3B(target: HTMLElement | null) {
  if (!target) return;

  let languageField =
    document.querySelector<HTMLElement>("#settingsLanguageField") ||
    document.querySelector<HTMLElement>(".settings-language-field");

  if (!languageField) {
    languageField = document.createElement("label");
    languageField.id = "settingsLanguageField";
    languageField.className = "settings-language-field";
    languageField.innerHTML = `
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

  const select = languageField.querySelector<HTMLSelectElement>("#settingsLanguageSelect");

  if (select) {
    try {
      select.value = localStorage.getItem("safebox.language.v1") || "auto";
    } catch {
      select.value = "auto";
    }

    if (select.dataset.sbxHotfixBound !== "1") {
      select.dataset.sbxHotfixBound = "1";
      select.addEventListener("change", () => {
        try {
          localStorage.setItem("safebox.language.v1", select.value);
        } catch {}

        try {
          const applyI18n = (window as any).sbxApplyI18n;
          if (typeof applyI18n === "function") applyI18n();
        } catch {}

        setTimeout(sbxSettingsHotfixController10A3B, 30);
        setTimeout(sbxSettingsHotfixController10A3B, 160);
      });
    }
  }

  sbxSettingsHotfixMove10A3B(languageField, target);
}

function sbxSettingsHotfixEnsureProfiles10A3B(target: HTMLElement | null) {
  if (!target) return;

  let section =
    document.querySelector<HTMLElement>("#settingsProfilesList")?.closest<HTMLElement>(".profiles-section") ||
    document.querySelector<HTMLElement>(".profiles-section");

  if (!section) {
    section = document.createElement("section");
    section.className = "profiles-section";
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
  }

  if (!section.querySelector("#addProfileBtn")) {
    const header = section.querySelector<HTMLElement>(".profiles-header") || section;
    const button = document.createElement("button");
    button.id = "addProfileBtn";
    button.className = "mini-btn";
    button.type = "button";
    button.textContent = "+ Add profile";
    header.appendChild(button);
  }

  if (!section.querySelector("#settingsProfilesList")) {
    const list = document.createElement("div");
    list.id = "settingsProfilesList";
    list.className = "profiles-list";
    section.appendChild(list);
  }

  sbxSettingsHotfixMove10A3B(section, target);

  try {
    renderAccessProfilesSettings();
  } catch {}
}

function sbxSettingsHotfixEnsureSecurityNote10A3B(target: HTMLElement | null) {
  if (!target) return;

  let note = target.querySelector<HTMLElement>(".sbx-security-note-10a3b");

  if (!note) {
    note = document.createElement("p");
    note.className = "settings-note sbx-security-note-10a3b";
    note.textContent = "MVP: the global code is kept only for this app session. Permanent secure storage comes later with Keychain / Credential Manager.";
    target.appendChild(note);
  }
}

function sbxSettingsHotfixActiveTab10A3B(root: HTMLElement) {
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
}

function sbxSettingsHotfixController10A3B() {
  const modal = document.querySelector<HTMLElement>("#settingsModal");

  if (!modal) return;

  const card =
    modal.querySelector<HTMLElement>(".settings-modal") ||
    modal.querySelector<HTMLElement>(".modal-card") ||
    (modal.firstElementChild as HTMLElement | null);

  if (!card) return;

  modal.classList.add("sbx-settings-hotfix-10a3b");

  let root = card.querySelector<HTMLElement>("#settingsTabsRoot");

  if (!root) {
    root = document.createElement("div");
    root.id = "settingsTabsRoot";
    root.className = "settings-tabs-root";

    const actions =
      card.querySelector<HTMLElement>(".settings-actions") ||
      card.querySelector<HTMLElement>(".modal-actions");

    if (actions) {
      card.insertBefore(root, actions);
    } else {
      card.appendChild(root);
    }
  }

  if (!root.querySelector("#settingsPanelGeneral")) {
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

  const general = root.querySelector<HTMLElement>("#settingsPanelGeneral");
  const profiles = root.querySelector<HTMLElement>("#settingsPanelProfiles");
  const security = root.querySelector<HTMLElement>("#settingsPanelSecurity");

  sbxSettingsHotfixPanelTitle10A3B(general, "General", "Language and sender defaults.");
  sbxSettingsHotfixPanelTitle10A3B(profiles, "Access Profiles", "Keep SafeBox simple: add a profile only when you need separate access.");
  sbxSettingsHotfixPanelTitle10A3B(security, "Security", "Session codes and security notes.");

  sbxSettingsHotfixEnsureLanguage10A3B(general);

  sbxSettingsHotfixMove10A3B(sbxSettingsHotfixFindField10A3B("#settingsDefaultName"), general);
  sbxSettingsHotfixMove10A3B(sbxSettingsHotfixFindField10A3B("#settingsGlobalSenderLabel"), general);

  sbxSettingsHotfixEnsureProfiles10A3B(profiles);

  sbxSettingsHotfixMove10A3B(sbxSettingsHotfixFindField10A3B("#settingsUseGlobalCode"), security);
  sbxSettingsHotfixMove10A3B(sbxSettingsHotfixFindField10A3B("#settingsGlobalCode"), security);
  sbxSettingsHotfixEnsureSecurityNote10A3B(security);

  modal
    .querySelectorAll<HTMLElement>("label, .field, .form-row, .settings-field")
    .forEach((node) => {
      const text = (node.textContent || "").replace(/\s+/g, " ").toLowerCase();

      if (
        text.includes("default access profile") ||
        text.includes("profil d’accès par défaut") ||
        text.includes("profil d'acces par defaut")
      ) {
        node.classList.add("legacy-default-access-field");
        node.style.display = "none";
      }
    });

  sbxSettingsHotfixActiveTab10A3B(root);

  try {
    const applyI18n = (window as any).sbxApplyI18n;
    if (typeof applyI18n === "function") applyI18n();
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

      const tab = tabButton.dataset.tab || "general";

      try {
        sessionStorage.setItem("safebox.settings.activeTab.v1", tab);
      } catch {}

      const root = document.querySelector<HTMLElement>("#settingsTabsRoot");
      if (root) sbxSettingsHotfixActiveTab10A3B(root);

      setTimeout(sbxSettingsHotfixController10A3B, 30);
      return;
    }

    if (target?.closest("#settingsBtn")) {
      setTimeout(sbxSettingsHotfixController10A3B, 30);
      setTimeout(sbxSettingsHotfixController10A3B, 160);
      setTimeout(sbxSettingsHotfixController10A3B, 400);
    }
  },
  true
);

setTimeout(sbxSettingsHotfixController10A3B, 100);
setTimeout(sbxSettingsHotfixController10A3B, 500);
setTimeout(sbxSettingsHotfixController10A3B, 1200);

console.debug("sprint10a3b-settings-hotfix-horizontal-panels-v1");
TS
fi

if ! grep -q "sprint10a3b-settings-hotfix-horizontal-panels-v1" src/style.css; then
cat >> src/style.css <<'CSS'

/* SafeBox Sprint 10A-3B — Settings Hotfix */
:root {
  --sprint10a3b-settings-hotfix-horizontal-panels-v1: 1;
}

/* Force horizontal tabs. Do not let old responsive rules stack them vertically. */
#settingsModal.sbx-settings-hotfix-10a3b .settings-tabs-nav,
#settingsModal.sbx-settings-10a3 .settings-tabs-nav,
#settingsModal.sbx-hard-settings-fixed .settings-tabs-nav {
  display: flex !important;
  flex-direction: row !important;
  align-items: center !important;
  gap: 6px !important;
  width: 100% !important;
}

#settingsModal.sbx-settings-hotfix-10a3b .settings-tab-button,
#settingsModal.sbx-settings-10a3 .settings-tab-button,
#settingsModal.sbx-hard-settings-fixed .settings-tab-button {
  flex: 1 1 0 !important;
  min-width: 0 !important;
  width: auto !important;
  white-space: nowrap !important;
  text-align: center !important;
}

/* Force panel visibility only by active class. */
#settingsModal.sbx-settings-hotfix-10a3b .settings-tab-panel {
  display: none !important;
}

#settingsModal.sbx-settings-hotfix-10a3b .settings-tab-panel.active {
  display: block !important;
  min-height: 260px !important;
}

/* Keep scroll inside modal. */
#settingsModal.sbx-settings-hotfix-10a3b {
  overflow: hidden !important;
}

#settingsModal.sbx-settings-hotfix-10a3b .settings-tab-panels {
  flex: 1 1 auto !important;
  min-height: 0 !important;
  overflow: hidden !important;
}

#settingsModal.sbx-settings-hotfix-10a3b .settings-tab-panel {
  overflow-y: auto !important;
  overflow-x: hidden !important;
  scrollbar-gutter: stable !important;
  padding-bottom: 110px !important;
}

.sbx-settings-panel-title-10a3b {
  margin: 0 0 16px !important;
  padding-bottom: 14px !important;
  border-bottom: 1px solid rgba(150, 170, 195, 0.22) !important;
}

.sbx-settings-panel-title-10a3b h3 {
  margin: 0 !important;
  font-size: 15px !important;
  font-weight: 900 !important;
}

.sbx-settings-panel-title-10a3b p {
  margin: 5px 0 0 !important;
  color: var(--muted) !important;
  font-size: 13px !important;
  line-height: 1.45 !important;
}

#settingsModal.sbx-settings-hotfix-10a3b .legacy-default-access-field {
  display: none !important;
}

/* Language may not float outside anymore. */
body > #settingsLanguageField,
#app > #settingsLanguageField,
.modal-backdrop > #settingsLanguageField {
  display: none !important;
}

/* But language must be visible inside General panel. */
#settingsPanelGeneral #settingsLanguageField,
#settingsPanelGeneral .settings-language-field {
  display: grid !important;
  visibility: visible !important;
  opacity: 1 !important;
}

@media (max-width: 760px), (max-height: 760px) {
  #settingsModal.sbx-settings-hotfix-10a3b .settings-tabs-nav,
  #settingsModal.sbx-settings-10a3 .settings-tabs-nav,
  #settingsModal.sbx-hard-settings-fixed .settings-tabs-nav {
    flex-direction: row !important;
  }

  #settingsModal.sbx-settings-hotfix-10a3b .settings-tab-button,
  #settingsModal.sbx-settings-10a3 .settings-tab-button,
  #settingsModal.sbx-hard-settings-fixed .settings-tab-button {
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
echo "==> Verify Sprint 10A-3B marker"
grep -R -- "sprint10a3b-settings-hotfix-horizontal-panels-v1" dist || echo "ERROR: Sprint 10A-3B marker absent from dist"

echo ""
echo "Sprint 10A-3B Settings Hotfix applied."
echo "Run:"
echo "  npm run tauri dev"
