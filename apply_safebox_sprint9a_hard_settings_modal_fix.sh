#!/usr/bin/env bash
set -euo pipefail

# SafeBox Sprint 9A — HARD Settings Modal Fix
#
# Fixes:
# - Settings scroll affecting app behind the modal
# - Tabs displayed vertically
# - Tabs not clickable
# - Language selector floating outside modal
# - Default access profile still visible
# - Save/Cancel covering tab content
#
# Does NOT touch encryption / SBX format / unlock logic.

ROOT="$(pwd)"
if [ ! -d "$ROOT/safebox-desktop" ]; then
  echo "ERROR: Run this from safebox_sbx_mvp root."
  echo "Current: $ROOT"
  exit 1
fi

cd "$ROOT/safebox-desktop"

echo "==> Backup files"
cp src/main.ts "src/main.ts.backup-hard-settings-modal-fix.$(date +%Y%m%d%H%M%S)"
cp src/style.css "src/style.css.backup-hard-settings-modal-fix.$(date +%Y%m%d%H%M%S)" 2>/dev/null || true

python3 - <<'PY'
from pathlib import Path

p = Path("src/main.ts")
text = p.read_text()

if "SAFEBOX_HARD_SETTINGS_MODAL_FIX_MARKER" not in text:
    text += r'''

function sbxHardSettingsModalFix() {
  const modal = document.querySelector<HTMLElement>("#settingsModal");
  if (!modal) return;

  const card =
    modal.querySelector<HTMLElement>(".settings-modal") ||
    modal.querySelector<HTMLElement>(".modal-card") ||
    (modal.firstElementChild instanceof HTMLElement ? modal.firstElementChild : null);

  if (!card) return;

  const head = card.querySelector<HTMLElement>(".modal-head");
  const actions =
    card.querySelector<HTMLElement>(".settings-actions") ||
    card.querySelector<HTMLElement>(".modal-actions");

  if (!head || !actions) return;

  // This modal must not make the background page scroll.
  modal.classList.add("sbx-hard-settings-fixed");
  document.body.classList.add("sbx-settings-open");

  // Remove all language fields outside the Settings card.
  Array.from(document.querySelectorAll<HTMLElement>("#settingsLanguageField")).forEach((field) => {
    if (!card.contains(field)) field.remove();
  });

  // Remove old/broken tab roots, then build one clean tab root.
  Array.from(document.querySelectorAll<HTMLElement>("#settingsTabsRoot")).forEach((root) => {
    root.remove();
  });

  const tabsRoot = document.createElement("section");
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

  const generalPanel = tabsRoot.querySelector<HTMLElement>('.settings-tab-panel[data-panel="general"]');
  const profilesPanel = tabsRoot.querySelector<HTMLElement>('.settings-tab-panel[data-panel="profiles"]');
  const securityPanel = tabsRoot.querySelector<HTMLElement>('.settings-tab-panel[data-panel="security"]');

  if (!generalPanel || !profilesPanel || !securityPanel) return;

  const wrapperFor = (selector: string): HTMLElement | null => {
    const element =
      card.querySelector<HTMLElement>(selector) ||
      document.querySelector<HTMLElement>(selector);

    if (!element) return null;

    return (
      element.closest<HTMLElement>("label") ||
      element.closest<HTMLElement>(".field") ||
      element.closest<HTMLElement>(".setting-row") ||
      element.parentElement
    );
  };

  const moveInto = (node: HTMLElement | null, panel: HTMLElement) => {
    if (!node) return;
    panel.appendChild(node);
    node.classList.remove("hidden");
    node.style.display = "";
  };

  // Language field inside General.
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

    const select = languageField.querySelector<HTMLSelectElement>("#settingsLanguageSelect");
    select?.addEventListener("change", () => {
      localStorage.setItem("safebox.language.v1", select.value);
      const apply = (window as any).sbxApplyI18n;
      if (typeof apply === "function") apply();
    });
  }

  moveInto(languageField, generalPanel);

  const languageSelect = card.querySelector<HTMLSelectElement>("#settingsLanguageSelect");
  if (languageSelect) languageSelect.value = localStorage.getItem("safebox.language.v1") || "auto";

  moveInto(wrapperFor("#settingsDefaultName"), generalPanel);
  moveInto(wrapperFor("#settingsGlobalSenderLabel"), generalPanel);

  const legacyDefaultAccess = wrapperFor("#settingsDefaultAccessProfile");
  if (legacyDefaultAccess) {
    legacyDefaultAccess.classList.add("hidden", "legacy-default-access-field");
    legacyDefaultAccess.style.display = "none";
  }

  const profilesSection = card.querySelector<HTMLElement>(".profiles-section");
  moveInto(profilesSection, profilesPanel);

  moveInto(wrapperFor("#settingsUseGlobalCode"), securityPanel);
  const globalCodeWrapper = wrapperFor("#settingsGlobalCode");
  moveInto(globalCodeWrapper, securityPanel);

  const clearBtn =
    card.querySelector<HTMLElement>("#clearGlobalCodeBtn") ||
    document.querySelector<HTMLElement>("#clearGlobalCodeBtn");

  if (clearBtn) {
    const clearWrapper = clearBtn.closest<HTMLElement>(".password-action-row") || clearBtn.parentElement;
    if (clearWrapper && clearWrapper !== globalCodeWrapper) {
      moveInto(clearWrapper, securityPanel);
    } else if (!securityPanel.contains(clearBtn)) {
      securityPanel.appendChild(clearBtn);
    }
  }

  Array.from(card.querySelectorAll<HTMLElement>(".settings-note")).forEach((note) => {
    const txt = (note.textContent || "").toLowerCase();
    if (txt.includes("global code") || txt.includes("keychain") || txt.includes("credential")) {
      securityPanel.appendChild(note);
    }
  });

  Array.from(card.children).forEach((child) => {
    if (!(child instanceof HTMLElement)) return;
    if (child === head || child === tabsRoot || child === actions) return;

    if (child.classList.contains("settings-section-divider")) {
      child.remove();
    }
  });

  const activateTab = (tab: string) => {
    tabsRoot.querySelectorAll<HTMLElement>(".settings-tab-button").forEach((button) => {
      button.classList.toggle("active", button.dataset.tab === tab);
    });

    tabsRoot.querySelectorAll<HTMLElement>(".settings-tab-panel").forEach((panel) => {
      panel.classList.toggle("active", panel.dataset.panel === tab);
    });
  };

  tabsRoot.addEventListener("click", (event) => {
    const target = event.target as HTMLElement;
    const button = target.closest<HTMLButtonElement>(".settings-tab-button");
    if (!button) return;
    activateTab(button.dataset.tab || "general");
  });

  activateTab("general");
}

function sbxHardSettingsModalCloseCleanup() {
  const modal = document.querySelector<HTMLElement>("#settingsModal");
  if (!modal || modal.classList.contains("hidden") || modal.style.display === "none") {
    document.body.classList.remove("sbx-settings-open");
  }
}

function SAFEBOX_HARD_SETTINGS_MODAL_FIX_MARKER() {
  return "hard-settings-modal-fixed-tabs-click-scroll";
}

console.debug(SAFEBOX_HARD_SETTINGS_MODAL_FIX_MARKER());

document.querySelector("#settingsBtn")?.addEventListener("click", () => {
  setTimeout(sbxHardSettingsModalFix, 20);
  setTimeout(sbxHardSettingsModalFix, 100);
  setTimeout(sbxHardSettingsModalFix, 260);
});

document.querySelector("#closeSettingsBtn")?.addEventListener("click", () => {
  setTimeout(sbxHardSettingsModalCloseCleanup, 20);
});

document.querySelector("#cancelSettingsBtn")?.addEventListener("click", () => {
  setTimeout(sbxHardSettingsModalCloseCleanup, 20);
});

document.querySelector("#saveSettingsBtn")?.addEventListener("click", () => {
  setTimeout(sbxHardSettingsModalCloseCleanup, 20);
});
'''

p.write_text(text)
print("Hard Settings Modal Fix patched into src/main.ts")
PY

cat >> src/style.css <<'CSS'

/* SafeBox HARD Settings Modal Fix
   Marker variable: --hard-settings-modal-fixed-tabs-click-scroll
*/
:root {
  --hard-settings-modal-fixed-tabs-click-scroll: 1;
}

/* Never let the page behind Settings scroll */
body.sbx-settings-open {
  overflow: hidden !important;
}

/* The Settings modal itself must be the fixed viewport layer */
#settingsModal.sbx-hard-settings-fixed {
  position: fixed !important;
  inset: 0 !important;
  z-index: 1000000 !important;
  display: grid !important;
  place-items: center !important;
  padding: 24px !important;
  overflow: hidden !important;
  background: rgba(3, 8, 16, 0.72) !important;
  box-sizing: border-box !important;
}

#settingsModal.sbx-hard-settings-fixed.hidden {
  display: none !important;
}

/* Hide any floating language selector outside the modal card */
body > #settingsLanguageField,
#app > #settingsLanguageField,
#settingsModal.sbx-hard-settings-fixed > #settingsLanguageField,
.modal-backdrop > #settingsLanguageField {
  display: none !important;
}

/* Card */
#settingsModal.sbx-hard-settings-fixed .settings-modal,
#settingsModal.sbx-hard-settings-fixed .modal-card,
#settingsModal.sbx-hard-settings-fixed > .settings-modal {
  width: min(760px, calc(100vw - 48px)) !important;
  height: min(820px, calc(100vh - 48px)) !important;
  max-height: calc(100vh - 48px) !important;
  display: flex !important;
  flex-direction: column !important;
  overflow: hidden !important;
  padding: 0 !important;
  box-sizing: border-box !important;
  border-radius: 22px !important;
}

/* Header */
#settingsModal.sbx-hard-settings-fixed .modal-head {
  flex: 0 0 auto !important;
  padding: 24px 26px 18px !important;
  box-sizing: border-box !important;
}

/* Tabs root */
#settingsModal.sbx-hard-settings-fixed #settingsTabsRoot {
  flex: 1 1 auto !important;
  min-height: 0 !important;
  display: flex !important;
  flex-direction: column !important;
  padding: 18px 26px 0 !important;
  box-sizing: border-box !important;
}

/* Force tabs horizontal: never vertical */
#settingsModal.sbx-hard-settings-fixed .settings-tabs-nav {
  flex: 0 0 auto !important;
  display: flex !important;
  flex-direction: row !important;
  align-items: center !important;
  gap: 6px !important;
  padding: 5px !important;
  margin: 0 0 18px !important;
  border-radius: 14px !important;
  border: 1px solid rgba(150, 170, 195, 0.22) !important;
  background: rgba(255, 255, 255, 0.045) !important;
}

#settingsModal.sbx-hard-settings-fixed .settings-tab-button {
  flex: 1 1 0 !important;
  min-width: 0 !important;
  min-height: 40px !important;
  border: 0 !important;
  border-radius: 10px !important;
  background: transparent !important;
  color: rgba(220, 232, 245, 0.72) !important;
  font-size: 13px !important;
  font-weight: 850 !important;
  cursor: pointer !important;
  text-align: center !important;
  white-space: nowrap !important;
  padding: 0 10px !important;
}

#settingsModal.sbx-hard-settings-fixed .settings-tab-button.active {
  background: rgba(255, 255, 255, 0.12) !important;
  color: #ffffff !important;
}

/* Panels */
#settingsModal.sbx-hard-settings-fixed .settings-tab-panels {
  flex: 1 1 auto !important;
  min-height: 0 !important;
  overflow: hidden !important;
}

#settingsModal.sbx-hard-settings-fixed .settings-tab-panel {
  display: none !important;
  height: 100% !important;
  min-height: 0 !important;
  overflow-y: auto !important;
  overflow-x: hidden !important;
  padding: 6px 12px 110px 2px !important;
  box-sizing: border-box !important;
  scrollbar-gutter: stable !important;
}

#settingsModal.sbx-hard-settings-fixed .settings-tab-panel.active {
  display: block !important;
}

/* Hide legacy default access profile */
#settingsModal.sbx-hard-settings-fixed .legacy-default-access-field {
  display: none !important;
}

/* Spacing */
#settingsModal.sbx-hard-settings-fixed label,
#settingsModal.sbx-hard-settings-fixed .profile-card,
#settingsModal.sbx-hard-settings-fixed .profiles-empty-state,
#settingsModal.sbx-hard-settings-fixed .settings-note {
  margin-bottom: 16px !important;
}

#settingsModal.sbx-hard-settings-fixed .settings-language-field {
  margin-bottom: 18px !important;
}

/* Footer */
#settingsModal.sbx-hard-settings-fixed .settings-actions,
#settingsModal.sbx-hard-settings-fixed .modal-actions {
  flex: 0 0 auto !important;
  margin: 0 !important;
  padding: 16px 26px 22px !important;
  border-top: 1px solid rgba(150, 170, 195, 0.20) !important;
  background: rgba(8, 18, 34, 0.98) !important;
  position: sticky !important;
  bottom: 0 !important;
  z-index: 30 !important;
}

/* Real scrollbar for tab panels */
#settingsModal.sbx-hard-settings-fixed .settings-tab-panel::-webkit-scrollbar {
  width: 10px !important;
}

#settingsModal.sbx-hard-settings-fixed .settings-tab-panel::-webkit-scrollbar-thumb {
  background: rgba(150, 170, 195, 0.40) !important;
  border-radius: 999px !important;
}

#settingsModal.sbx-hard-settings-fixed .settings-tab-panel::-webkit-scrollbar-track {
  background: transparent !important;
}

/* Override old media rules that stacked tabs vertically */
@media (max-width: 760px), (max-height: 760px) {
  #settingsModal.sbx-hard-settings-fixed {
    padding: 12px !important;
  }

  #settingsModal.sbx-hard-settings-fixed .settings-modal,
  #settingsModal.sbx-hard-settings-fixed .modal-card,
  #settingsModal.sbx-hard-settings-fixed > .settings-modal {
    width: calc(100vw - 24px) !important;
    height: calc(100vh - 24px) !important;
  }

  #settingsModal.sbx-hard-settings-fixed .settings-tabs-nav {
    display: flex !important;
    flex-direction: row !important;
    grid-template-columns: none !important;
  }

  #settingsModal.sbx-hard-settings-fixed .settings-tab-button {
    font-size: 12px !important;
    padding: 0 6px !important;
  }
}
CSS

echo "==> Build check"
rm -rf dist node_modules/.vite
npm run build

echo ""
echo "==> Verify hard fix marker"
grep -R "hard-settings-modal-fixed-tabs-click-scroll" dist || echo "ERROR: hard settings modal fix marker absent from dist"

echo ""
echo "Hard Settings Modal Fix applied."
echo "Run:"
echo "  npm run tauri dev"
