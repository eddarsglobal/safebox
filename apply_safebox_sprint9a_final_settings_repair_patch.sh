#!/usr/bin/env bash
set -euo pipefail

# SafeBox Sprint 9A — FINAL Settings Repair
#
# Fixes:
# - Language selector floating outside modal
# - Missing visible tabs
# - Old Default access profile visible
# - No proper scroll
# - Save/Cancel covering content
#
# Does NOT touch encryption / SBX core / unlock logic.

ROOT="$(pwd)"
if [ ! -d "$ROOT/safebox-desktop" ]; then
  echo "ERROR: Run this from safebox_sbx_mvp root."
  echo "Current: $ROOT"
  exit 1
fi

cd "$ROOT/safebox-desktop"

echo "==> Backup files"
cp src/main.ts "src/main.ts.backup-final-settings-repair.$(date +%Y%m%d%H%M%S)"
cp src/style.css "src/style.css.backup-final-settings-repair.$(date +%Y%m%d%H%M%S)" 2>/dev/null || true

python3 - <<'PY'
from pathlib import Path

p = Path("src/main.ts")
text = p.read_text()

if "SAFEBOX_FINAL_SETTINGS_REPAIR_MARKER" not in text:
    text += r'''

function sbxFinalSettingsRepair() {
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

  // Remove language selectors floating outside the card.
  Array.from(document.querySelectorAll<HTMLElement>("#settingsLanguageField")).forEach((field) => {
    if (!card.contains(field)) field.remove();
  });

  // Remove tabs created in wrong places.
  Array.from(document.querySelectorAll<HTMLElement>("#settingsTabsRoot")).forEach((root) => {
    if (!card.contains(root) || root.parentElement !== card) root.remove();
  });

  let tabsRoot = card.querySelector<HTMLElement>("#settingsTabsRoot");

  if (!tabsRoot) {
    tabsRoot = document.createElement("section");
    tabsRoot.id = "settingsTabsRoot";
    tabsRoot.className = "settings-tabs-root sbx-final-settings-tabs";
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

  const select = card.querySelector<HTMLSelectElement>("#settingsLanguageSelect");
  if (select) select.value = localStorage.getItem("safebox.language.v1") || "auto";

  moveInto(wrapperFor("#settingsDefaultName"), generalPanel);
  moveInto(wrapperFor("#settingsGlobalSenderLabel"), generalPanel);

  // Hide legacy access profile input forever.
  const legacy = wrapperFor("#settingsDefaultAccessProfile");
  if (legacy) {
    legacy.classList.add("hidden", "legacy-default-access-field");
    legacy.style.display = "none";
  }

  const profilesSection = card.querySelector<HTMLElement>(".profiles-section");
  moveInto(profilesSection, profilesPanel);

  moveInto(wrapperFor("#settingsUseGlobalCode"), securityPanel);
  moveInto(wrapperFor("#settingsGlobalCode"), securityPanel);

  const clearBtn = card.querySelector<HTMLElement>("#clearGlobalCodeBtn") || document.querySelector<HTMLElement>("#clearGlobalCodeBtn");
  if (clearBtn) {
    const clearWrapper = clearBtn.closest<HTMLElement>(".password-action-row") || clearBtn.parentElement;
    if (clearWrapper && !securityPanel.contains(clearWrapper)) {
      moveInto(clearWrapper, securityPanel);
    } else if (!securityPanel.contains(clearBtn)) {
      securityPanel.appendChild(clearBtn);
    }
  }

  // Move global-code note into Security tab.
  Array.from(card.querySelectorAll<HTMLElement>(".settings-note")).forEach((note) => {
    const txt = (note.textContent || "").toLowerCase();
    if (txt.includes("global code") || txt.includes("keychain") || txt.includes("credential")) {
      securityPanel.appendChild(note);
    }
  });

  // Remove dividers and floating empty leftovers from direct card children.
  Array.from(card.children).forEach((child) => {
    if (!(child instanceof HTMLElement)) return;
    if (child === head || child === tabsRoot || child === actions) return;

    if (child.classList.contains("settings-section-divider")) {
      child.remove();
      return;
    }

    if (child.id === "settingsLanguageField") {
      generalPanel.appendChild(child);
      return;
    }
  });

  // Bind tab clicks once.
  tabsRoot.querySelectorAll<HTMLButtonElement>(".settings-tab-button").forEach((button) => {
    if (button.dataset.sbxFinalTabsBound === "1") return;
    button.dataset.sbxFinalTabsBound = "1";

    button.addEventListener("click", () => {
      const tab = button.dataset.tab || "general";

      tabsRoot?.querySelectorAll<HTMLElement>(".settings-tab-button").forEach((btn) => {
        btn.classList.toggle("active", btn.dataset.tab === tab);
      });

      tabsRoot?.querySelectorAll<HTMLElement>(".settings-tab-panel").forEach((panel) => {
        panel.classList.toggle("active", panel.dataset.panel === tab);
      });
    });
  });

  modal.classList.add("settings-tabs-enabled", "sbx-final-settings-repaired");
}

function SAFEBOX_FINAL_SETTINGS_REPAIR_MARKER() {
  return "final-settings-repair-tabs-language-scroll";
}

console.debug(SAFEBOX_FINAL_SETTINGS_REPAIR_MARKER());

document.querySelector("#settingsBtn")?.addEventListener("click", () => {
  setTimeout(sbxFinalSettingsRepair, 20);
  setTimeout(sbxFinalSettingsRepair, 100);
  setTimeout(sbxFinalSettingsRepair, 250);
});

setTimeout(sbxFinalSettingsRepair, 300);
'''

p.write_text(text)
print("Final Settings Repair patched into src/main.ts")
PY

cat >> src/style.css <<'CSS'

/* SafeBox FINAL Settings Repair
   real marker variable: --final-settings-repair-tabs-language-scroll
*/
:root {
  --final-settings-repair-tabs-language-scroll: 1;
}

#settingsModal.sbx-final-settings-repaired {
  display: grid !important;
  place-items: center !important;
  padding: 24px !important;
  overflow: hidden !important;
}

#settingsModal.sbx-final-settings-repaired > #settingsLanguageField,
body > #settingsLanguageField,
#app > #settingsLanguageField,
.modal-backdrop > #settingsLanguageField {
  display: none !important;
}

#settingsModal.sbx-final-settings-repaired .settings-modal,
#settingsModal.sbx-final-settings-repaired .modal-card,
#settingsModal.sbx-final-settings-repaired > .settings-modal {
  width: min(760px, calc(100vw - 48px)) !important;
  height: min(820px, calc(100vh - 48px)) !important;
  max-height: calc(100vh - 48px) !important;
  display: flex !important;
  flex-direction: column !important;
  overflow: hidden !important;
  padding: 0 !important;
  box-sizing: border-box !important;
}

#settingsModal.sbx-final-settings-repaired .modal-head {
  flex: 0 0 auto !important;
  padding: 24px 26px 18px !important;
}

#settingsModal.sbx-final-settings-repaired #settingsTabsRoot {
  flex: 1 1 auto !important;
  min-height: 0 !important;
  padding: 18px 26px 0 !important;
  display: flex !important;
  flex-direction: column !important;
  box-sizing: border-box !important;
}

#settingsModal.sbx-final-settings-repaired .settings-tabs-nav {
  display: grid !important;
  grid-template-columns: repeat(3, minmax(0, 1fr)) !important;
  gap: 6px !important;
  padding: 5px !important;
  margin: 0 0 18px !important;
  border-radius: 14px !important;
  border: 1px solid rgba(150, 170, 195, 0.22) !important;
  background: rgba(255, 255, 255, 0.045) !important;
  flex: 0 0 auto !important;
}

#settingsModal.sbx-final-settings-repaired .settings-tab-button {
  min-height: 38px !important;
  border: 0 !important;
  border-radius: 10px !important;
  background: transparent !important;
  color: rgba(220, 232, 245, 0.72) !important;
  font-size: 13px !important;
  font-weight: 850 !important;
  cursor: pointer !important;
}

#settingsModal.sbx-final-settings-repaired .settings-tab-button.active {
  background: rgba(255, 255, 255, 0.12) !important;
  color: #ffffff !important;
}

#settingsModal.sbx-final-settings-repaired .settings-tab-panels {
  flex: 1 1 auto !important;
  min-height: 0 !important;
  overflow: hidden !important;
}

#settingsModal.sbx-final-settings-repaired .settings-tab-panel {
  display: none !important;
  height: 100% !important;
  min-height: 0 !important;
  overflow-y: auto !important;
  overflow-x: hidden !important;
  padding: 6px 12px 96px 2px !important;
  box-sizing: border-box !important;
  scrollbar-gutter: stable !important;
}

#settingsModal.sbx-final-settings-repaired .settings-tab-panel.active {
  display: block !important;
}

#settingsModal.sbx-final-settings-repaired .legacy-default-access-field {
  display: none !important;
}

#settingsModal.sbx-final-settings-repaired label,
#settingsModal.sbx-final-settings-repaired .profile-card,
#settingsModal.sbx-final-settings-repaired .profiles-empty-state,
#settingsModal.sbx-final-settings-repaired .settings-note {
  margin-bottom: 16px !important;
}

#settingsModal.sbx-final-settings-repaired .settings-language-field {
  margin-bottom: 18px !important;
}

#settingsModal.sbx-final-settings-repaired .settings-actions,
#settingsModal.sbx-final-settings-repaired .modal-actions {
  flex: 0 0 auto !important;
  margin: 0 !important;
  padding: 16px 26px 22px !important;
  border-top: 1px solid rgba(150, 170, 195, 0.20) !important;
  background: rgba(8, 18, 34, 0.98) !important;
  position: sticky !important;
  bottom: 0 !important;
  z-index: 30 !important;
}

#settingsModal.sbx-final-settings-repaired .settings-tab-panel::-webkit-scrollbar {
  width: 10px !important;
}

#settingsModal.sbx-final-settings-repaired .settings-tab-panel::-webkit-scrollbar-thumb {
  background: rgba(150, 170, 195, 0.38) !important;
  border-radius: 999px !important;
}

#settingsModal.sbx-final-settings-repaired .settings-tab-panel::-webkit-scrollbar-track {
  background: transparent !important;
}

@media (max-width: 760px), (max-height: 760px) {
  #settingsModal.sbx-final-settings-repaired {
    padding: 12px !important;
  }

  #settingsModal.sbx-final-settings-repaired .settings-modal,
  #settingsModal.sbx-final-settings-repaired .modal-card,
  #settingsModal.sbx-final-settings-repaired > .settings-modal {
    width: calc(100vw - 24px) !important;
    height: calc(100vh - 24px) !important;
  }

  #settingsModal.sbx-final-settings-repaired .settings-tabs-nav {
    grid-template-columns: 1fr !important;
  }
}
CSS

echo "==> Build check"
rm -rf dist node_modules/.vite
npm run build

echo ""
echo "==> Verify final settings repair"
grep -R "final-settings-repair-tabs-language-scroll" dist || echo "ERROR: final settings repair marker absent from dist"

echo ""
echo "Final Settings Repair applied."
echo "Run:"
echo "  npm run tauri dev"
