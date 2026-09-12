#!/usr/bin/env bash
set -euo pipefail

# SafeBox Sprint 9A — Settings Content Restore
#
# Fixes:
# - General shows only Language
# - Access Profiles tab empty
# - Security tab empty
#
# Cause:
# Previous repair removed/rebuilt tabsRoot after some fields had already been moved inside it.
#
# Fix:
# - Recreate/move required fields into:
#   General: Language, Default SBX name, Global sender label
#   Access Profiles: Access Profiles section, empty state, + Add profile
#   Security: Use global code, Global code, Clear global code, note
# - Keep tabs clickable
# - Keep Settings modal scroll inside panel

ROOT="$(pwd)"
if [ ! -d "$ROOT/safebox-desktop" ]; then
  echo "ERROR: Run this from safebox_sbx_mvp root."
  echo "Current: $ROOT"
  exit 1
fi

cd "$ROOT/safebox-desktop"

echo "==> Backup files"
cp src/main.ts "src/main.ts.backup-settings-content-restore.$(date +%Y%m%d%H%M%S)"
cp src/style.css "src/style.css.backup-settings-content-restore.$(date +%Y%m%d%H%M%S)" 2>/dev/null || true

cat >> src/main.ts <<'TS'

// HARD RESTORE — Settings content inside tabs
// Marker: settings-content-restore-general-profiles-security-v1
function sbxSettingsContentRestore() {
  const modal = document.querySelector<HTMLElement>("#settingsModal");
  if (!modal) return;

  const card =
    modal.querySelector<HTMLElement>(".settings-modal") ||
    modal.querySelector<HTMLElement>(".modal-card") ||
    (modal.firstElementChild instanceof HTMLElement ? modal.firstElementChild : null);

  if (!card) return;

  const actions =
    card.querySelector<HTMLElement>(".settings-actions") ||
    card.querySelector<HTMLElement>(".modal-actions");

  const head = card.querySelector<HTMLElement>(".modal-head");

  if (!actions || !head) return;

  modal.classList.add("sbx-hard-settings-fixed", "sbx-settings-content-restored");
  document.body.classList.add("sbx-settings-open");

  // Remove floating language fields outside the Settings card.
  Array.from(document.querySelectorAll<HTMLElement>("#settingsLanguageField")).forEach((field) => {
    if (!card.contains(field)) field.remove();
  });

  let tabsRoot = card.querySelector<HTMLElement>("#settingsTabsRoot");

  if (!tabsRoot) {
    tabsRoot = document.createElement("section");
    tabsRoot.id = "settingsTabsRoot";
    tabsRoot.className = "settings-tabs-root sbx-hard-tabs-root";
    tabsRoot.innerHTML = `
      <div class="settings-tabs-nav" role="tablist">
        <button class="settings-tab-button active" type="button" data-tab="general">General</button>
        <button class="settings-tab-button" type="button" data-tab="profiles">Access Profiles</button>
        <button class="settings-tab-button" type="button" data-tab="security">Security</button>
      </div>

      <div class="settings-tab-panels">
        <div class="settings-tab-panel active" data-panel="general"></div>
        <div class="settings-tab-panel" data-panel="profiles"></div>
        <div class="settings-tab-panel" data-panel="security"></div>
      </div>
    `;
    card.insertBefore(tabsRoot, actions);
  }

  const nav = tabsRoot.querySelector<HTMLElement>(".settings-tabs-nav");
  const panels = tabsRoot.querySelector<HTMLElement>(".settings-tab-panels");

  if (!nav || !panels) return;

  const ensurePanel = (name: string) => {
    let panel = tabsRoot!.querySelector<HTMLElement>(`.settings-tab-panel[data-panel="${name}"]`);
    if (!panel) {
      panel = document.createElement("div");
      panel.className = `settings-tab-panel ${name === "general" ? "active" : ""}`;
      panel.dataset.panel = name;
      panels.appendChild(panel);
    }
    return panel;
  };

  const generalPanel = ensurePanel("general");
  const profilesPanel = ensurePanel("profiles");
  const securityPanel = ensurePanel("security");

  const ensureButton = (name: string, label: string) => {
    let button = tabsRoot!.querySelector<HTMLButtonElement>(`.settings-tab-button[data-tab="${name}"]`);
    if (!button) {
      button = document.createElement("button");
      button.className = `settings-tab-button ${name === "general" ? "active" : ""}`;
      button.type = "button";
      button.dataset.tab = name;
      button.textContent = label;
      nav.appendChild(button);
    }
    return button;
  };

  ensureButton("general", "General");
  ensureButton("profiles", "Access Profiles");
  ensureButton("security", "Security");

  const activate = (tab: string) => {
    tabsRoot!.querySelectorAll<HTMLElement>(".settings-tab-button").forEach((button) => {
      button.classList.toggle("active", button.dataset.tab === tab);
    });

    tabsRoot!.querySelectorAll<HTMLElement>(".settings-tab-panel").forEach((panel) => {
      const active = panel.dataset.panel === tab;
      panel.classList.toggle("active", active);
      panel.style.display = active ? "block" : "none";
    });
  };

  tabsRoot.onclick = (event) => {
    const target = event.target as HTMLElement | null;
    const button = target?.closest<HTMLButtonElement>(".settings-tab-button");
    if (!button) return;
    event.preventDefault();
    event.stopPropagation();
    activate(button.dataset.tab || "general");
  };

  const settingsNow = readSettings();

  const moveOrCreateLabelInput = (
    id: string,
    labelText: string,
    value: string,
    panel: HTMLElement,
    inputType = "text"
  ) => {
    let input = document.querySelector<HTMLInputElement>(`#${id}`);
    let wrapper: HTMLElement | null = input?.closest<HTMLElement>("label") || null;

    if (!input || !wrapper) {
      wrapper = document.createElement("label");
      input = document.createElement("input");
      input.id = id;
      input.type = inputType;
      input.autocomplete = "off";
      wrapper.textContent = labelText;
      wrapper.appendChild(input);
    } else {
      const firstTextNode = Array.from(wrapper.childNodes).find((node) => node.nodeType === Node.TEXT_NODE);
      if (firstTextNode) firstTextNode.textContent = labelText;
      else wrapper.prepend(document.createTextNode(labelText));
    }

    input.value = value || "";
    wrapper.classList.remove("hidden");
    wrapper.style.display = "";
    panel.appendChild(wrapper);

    return input;
  };

  // Language field.
  let languageField = card.querySelector<HTMLElement>("#settingsLanguageField");

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

  generalPanel.appendChild(languageField);

  const languageSelect = languageField.querySelector<HTMLSelectElement>("#settingsLanguageSelect");
  if (languageSelect) {
    languageSelect.value = localStorage.getItem("safebox.language.v1") || "auto";
    languageSelect.onchange = () => {
      localStorage.setItem("safebox.language.v1", languageSelect.value);
      const apply = (window as any).sbxApplyI18n;
      if (typeof apply === "function") apply();
    };
  }

  moveOrCreateLabelInput(
    "settingsDefaultName",
    "Default SBX name",
    settingsNow.defaultVisibleName || "document",
    generalPanel
  );

  moveOrCreateLabelInput(
    "settingsGlobalSenderLabel",
    "Global sender label",
    settingsNow.globalSenderLabel || "",
    generalPanel
  );

  // Keep legacy default access profile input for old save code, but hidden.
  let legacyInput = document.querySelector<HTMLInputElement>("#settingsDefaultAccessProfile");
  if (!legacyInput) {
    const legacyWrapper = document.createElement("label");
    legacyWrapper.className = "legacy-default-access-field hidden";
    legacyInput = document.createElement("input");
    legacyInput.id = "settingsDefaultAccessProfile";
    legacyWrapper.appendChild(legacyInput);
    card.appendChild(legacyWrapper);
  }
  legacyInput.value = settingsNow.defaultAccessProfile || "";
  const legacyWrapper = legacyInput.closest<HTMLElement>("label") || legacyInput.parentElement;
  if (legacyWrapper) {
    legacyWrapper.classList.add("hidden", "legacy-default-access-field");
    legacyWrapper.style.display = "none";
  }

  // Access Profiles section.
  let profilesSection = card.querySelector<HTMLElement>(".profiles-section");

  if (!profilesSection) {
    profilesSection = document.createElement("section");
    profilesSection.className = "profiles-section";
    profilesSection.innerHTML = `
      <div class="profiles-header">
        <div>
          <h3>Access Profiles</h3>
          <p>Keep SafeBox simple: add a profile only when you need separate access.</p>
        </div>
        <button id="addProfileBtn" class="mini-btn" type="button">+ Add profile</button>
      </div>
      <div id="settingsProfilesList" class="profiles-list"></div>
      <p class="settings-note">Profile codes are kept only for this app session. Profile names and labels are saved.</p>
    `;
  } else {
    let list = profilesSection.querySelector("#settingsProfilesList");
    if (!list) {
      list = document.createElement("div");
      list.id = "settingsProfilesList";
      list.className = "profiles-list";
      profilesSection.appendChild(list);
    }

    if (!profilesSection.querySelector("#addProfileBtn")) {
      const button = document.createElement("button");
      button.id = "addProfileBtn";
      button.className = "mini-btn";
      button.type = "button";
      button.textContent = "+ Add profile";
      profilesSection.querySelector(".profiles-header")?.appendChild(button);
    }
  }

  profilesPanel.appendChild(profilesSection);

  try {
    renderAccessProfilesSettings();
  } catch (error) {
    console.warn("renderAccessProfilesSettings failed", error);
  }

  // Security content.
  let useGlobalWrapper = document.querySelector<HTMLInputElement>("#settingsUseGlobalCode")?.closest<HTMLElement>("label") || null;

  if (!useGlobalWrapper) {
    useGlobalWrapper = document.createElement("label");
    useGlobalWrapper.className = "settings-check checkline";
    useGlobalWrapper.innerHTML = `
      <input id="settingsUseGlobalCode" type="checkbox" />
      <span>Use global code by default</span>
    `;
  }

  const useGlobal = useGlobalWrapper.querySelector<HTMLInputElement>("#settingsUseGlobalCode");
  if (useGlobal) useGlobal.checked = settingsNow.useGlobalCode;

  securityPanel.appendChild(useGlobalWrapper);

  let globalCodeInput = document.querySelector<HTMLInputElement>("#settingsGlobalCode");
  let globalCodeWrapper = globalCodeInput?.closest<HTMLElement>("label") || null;

  if (!globalCodeInput || !globalCodeWrapper) {
    globalCodeWrapper = document.createElement("label");
    globalCodeWrapper.innerHTML = `
      Global code
      <div class="password-action-row">
        <input id="settingsGlobalCode" type="password" placeholder="kept only for this app session" autocomplete="new-password" />
        <button id="toggleGlobalCodeBtn" class="mini-btn" type="button">Show</button>
      </div>
    `;
  }

  globalCodeInput = globalCodeWrapper.querySelector<HTMLInputElement>("#settingsGlobalCode");
  if (globalCodeInput) {
    try {
      globalCodeInput.value = getGlobalCode();
    } catch {
      globalCodeInput.value = "";
    }
  }

  securityPanel.appendChild(globalCodeWrapper);

  let clearBtn = document.querySelector<HTMLButtonElement>("#clearGlobalCodeBtn");

  if (!clearBtn) {
    clearBtn = document.createElement("button");
    clearBtn.id = "clearGlobalCodeBtn";
    clearBtn.className = "mini-btn danger-link";
    clearBtn.type = "button";
    clearBtn.textContent = "Clear global code";
  }

  securityPanel.appendChild(clearBtn);

  let securityNote = Array.from(card.querySelectorAll<HTMLElement>(".settings-note"))
    .find((note) => (note.textContent || "").toLowerCase().includes("global code"));

  if (!securityNote) {
    securityNote = document.createElement("p");
    securityNote.className = "settings-note";
    securityNote.textContent =
      "MVP: the global code is kept only for this app session. Permanent secure storage comes later with Keychain / Credential Manager.";
  }

  securityPanel.appendChild(securityNote);

  // Delegated actions for restored/new buttons.
  modal.onclick = (event) => {
    const target = event.target as HTMLElement | null;

    const tabButton = target?.closest<HTMLButtonElement>(".settings-tab-button");
    if (tabButton) {
      event.preventDefault();
      event.stopPropagation();
      activate(tabButton.dataset.tab || "general");
      return;
    }

    if (target?.closest("#addProfileBtn")) {
      event.preventDefault();
      event.stopPropagation();
      try {
        addAccessProfileCard();
      } catch (error) {
        console.error("addAccessProfileCard failed", error);
      }
      return;
    }

    if (target?.closest("#toggleGlobalCodeBtn")) {
      event.preventDefault();
      event.stopPropagation();

      const input = document.querySelector<HTMLInputElement>("#settingsGlobalCode");
      const button = document.querySelector<HTMLButtonElement>("#toggleGlobalCodeBtn");

      if (input && button) {
        const hidden = input.type === "password";
        input.type = hidden ? "text" : "password";
        button.textContent = hidden ? "Hide" : "Show";
      }
      return;
    }

    if (target?.closest("#clearGlobalCodeBtn")) {
      const input = document.querySelector<HTMLInputElement>("#settingsGlobalCode");
      if (input) input.value = "";
      return;
    }
  };

  // Make sure the initial visible tab shows real content.
  activate("general");
}

document.querySelector("#settingsBtn")?.addEventListener("click", () => {
  setTimeout(sbxSettingsContentRestore, 20);
  setTimeout(sbxSettingsContentRestore, 100);
  setTimeout(sbxSettingsContentRestore, 280);
});

setTimeout(sbxSettingsContentRestore, 400);

console.debug("settings-content-restore-general-profiles-security-v1");
TS

cat >> src/style.css <<'CSS'

/* HARD RESTORE — Settings content inside tabs */
:root {
  --settings-content-restore-general-profiles-security-v1: 1;
}

#settingsModal.sbx-settings-content-restored .settings-tab-button {
  pointer-events: auto !important;
  cursor: pointer !important;
}

#settingsModal.sbx-settings-content-restored .settings-tab-panel {
  display: none !important;
  overflow-y: auto !important;
  padding-bottom: 110px !important;
}

#settingsModal.sbx-settings-content-restored .settings-tab-panel.active {
  display: block !important;
}

#settingsModal.sbx-settings-content-restored .settings-tabs-nav {
  display: flex !important;
  flex-direction: row !important;
  gap: 6px !important;
}

#settingsModal.sbx-settings-content-restored .settings-tab-button {
  flex: 1 1 0 !important;
  min-height: 40px !important;
}

#settingsModal.sbx-settings-content-restored .legacy-default-access-field {
  display: none !important;
}

#settingsModal.sbx-settings-content-restored #settingsTabsRoot {
  min-height: 0 !important;
}

#settingsModal.sbx-settings-content-restored .settings-tab-panels {
  min-height: 0 !important;
  overflow: hidden !important;
}
CSS

echo "==> Build check"
rm -rf dist node_modules/.vite
npm run build

echo ""
echo "==> Verify restore marker"
grep -R "settings-content-restore-general-profiles-security-v1" dist || echo "ERROR: restore marker absent from dist"

echo ""
echo "Settings Content Restore applied."
echo "Run:"
echo "  npm run tauri dev"
