#!/usr/bin/env bash
set -euo pipefail

# SafeBox Sprint 8B — Settings Tabs
# Adds tabbed Settings UI:
# - General
# - Access Profiles
# - Security
#
# Does not change encryption / create / unlock logic.

ROOT="$(pwd)"
if [ ! -d "$ROOT/safebox-desktop" ]; then
  echo "ERROR: Run this from safebox_sbx_mvp root."
  echo "Current: $ROOT"
  exit 1
fi

cd "$ROOT/safebox-desktop"

echo "==> Backup frontend"
cp src/main.ts "src/main.ts.backup-sprint8b-tabs.$(date +%Y%m%d%H%M%S)"
cp src/style.css "src/style.css.backup-sprint8b-tabs.$(date +%Y%m%d%H%M%S)" 2>/dev/null || true

python3 - <<'PY'
from pathlib import Path

p = Path("src/main.ts")
text = p.read_text()

if "function enhanceSettingsTabs()" not in text:
    marker = "function openSettings() {"
    if marker not in text:
        raise SystemExit("Cannot find openSettings() marker")

    funcs = r'''
function getSettingsFieldWrapper(selector: string): HTMLElement | null {
  const element = document.querySelector<HTMLElement>(selector);
  if (!element) return null;

  return (
    element.closest<HTMLElement>("label") ||
    element.closest<HTMLElement>(".field") ||
    element.closest<HTMLElement>(".setting-row") ||
    element.parentElement
  );
}

function moveSettingsNode(node: HTMLElement | null, panel: HTMLElement) {
  if (!node || node.dataset.settingsTabsMoved === "1") return;
  node.dataset.settingsTabsMoved = "1";
  panel.appendChild(node);
}

function activateSettingsTab(tabName: string) {
  document.querySelectorAll<HTMLElement>(".settings-tab-button").forEach((button) => {
    button.classList.toggle("active", button.dataset.tab === tabName);
  });

  document.querySelectorAll<HTMLElement>(".settings-tab-panel").forEach((panel) => {
    panel.classList.toggle("active", panel.dataset.panel === tabName);
  });
}

function enhanceSettingsTabs() {
  const modal = document.querySelector<HTMLElement>("#settingsModal");
  if (!modal) return;

  const actions = modal.querySelector<HTMLElement>(".settings-actions");
  const profilesSection = modal.querySelector<HTMLElement>(".profiles-section");

  if (!actions || !profilesSection) return;

  if (!modal.querySelector("#settingsTabsRoot")) {
    const tabsRoot = document.createElement("section");
    tabsRoot.id = "settingsTabsRoot";
    tabsRoot.className = "settings-tabs-root";

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

    actions.parentElement?.insertBefore(tabsRoot, actions);

    tabsRoot.querySelectorAll<HTMLButtonElement>(".settings-tab-button").forEach((button) => {
      button.addEventListener("click", () => activateSettingsTab(button.dataset.tab || "general"));
    });
  }

  const generalPanel = modal.querySelector<HTMLElement>('.settings-tab-panel[data-panel="general"]');
  const profilesPanel = modal.querySelector<HTMLElement>('.settings-tab-panel[data-panel="profiles"]');
  const securityPanel = modal.querySelector<HTMLElement>('.settings-tab-panel[data-panel="security"]');

  if (!generalPanel || !profilesPanel || !securityPanel) return;

  moveSettingsNode(getSettingsFieldWrapper("#settingsDefaultName"), generalPanel);
  moveSettingsNode(getSettingsFieldWrapper("#settingsGlobalSenderLabel"), generalPanel);

  const oldDefaultAccessWrapper = getSettingsFieldWrapper("#settingsDefaultAccessProfile");
  if (oldDefaultAccessWrapper) {
    oldDefaultAccessWrapper.classList.add("hidden", "legacy-default-access-field");
    oldDefaultAccessWrapper.style.display = "none";
  }

  moveSettingsNode(profilesSection, profilesPanel);

  moveSettingsNode(getSettingsFieldWrapper("#settingsUseGlobalCode"), securityPanel);
  moveSettingsNode(getSettingsFieldWrapper("#settingsGlobalCode"), securityPanel);

  const clearButton = document.querySelector<HTMLElement>("#clearGlobalCodeBtn");
  if (clearButton && clearButton.dataset.settingsTabsMoved !== "1") {
    const wrapper = clearButton.closest<HTMLElement>(".password-action-row") || clearButton.parentElement;
    if (wrapper && wrapper !== getSettingsFieldWrapper("#settingsGlobalCode")) {
      moveSettingsNode(wrapper, securityPanel);
    } else {
      clearButton.dataset.settingsTabsMoved = "1";
      securityPanel.appendChild(clearButton);
    }
  }

  modal.classList.add("settings-tabs-enabled");
  activateSettingsTab(
    modal.querySelector<HTMLElement>(".settings-tab-button.active")?.dataset.tab || "general"
  );
}

'''
    text = text.replace(marker, funcs + marker, 1)

open_start = text.find("function openSettings()")
if open_start == -1:
    raise SystemExit("Cannot find openSettings function")
open_end = text.find("\n}", open_start)
if open_end == -1:
    raise SystemExit("Cannot find end of openSettings function")
open_block = text[open_start:open_end+2]

if "enhanceSettingsTabs();" not in open_block:
    if "renderAccessProfilesSettings();" in open_block:
        open_block = open_block.replace(
            "renderAccessProfilesSettings();",
            "renderAccessProfilesSettings();\n  enhanceSettingsTabs();",
            1
        )
    elif 'settingsModal.classList.remove("hidden");' in open_block:
        open_block = open_block.replace(
            'settingsModal.classList.remove("hidden");',
            'enhanceSettingsTabs();\n  settingsModal.classList.remove("hidden");',
            1
        )
    else:
        raise SystemExit("Cannot find insertion point inside openSettings")

    text = text[:open_start] + open_block + text[open_end+2:]

if "SAFEBOX_SETTINGS_TABS_SPRINT8B_MARKER" not in text:
    text += r'''

function SAFEBOX_SETTINGS_TABS_SPRINT8B_MARKER() {
  return "settings-tabs-general-profiles-security";
}

console.debug(SAFEBOX_SETTINGS_TABS_SPRINT8B_MARKER());
'''

p.write_text(text)
print("Sprint 8B Settings Tabs patched into src/main.ts")
PY

cat >> src/style.css <<'CSS'

/* Sprint 8B — Settings Tabs */
#settingsModal.settings-tabs-enabled {
  overflow-y: auto !important;
  align-items: flex-start !important;
  padding: 18px !important;
}

#settingsModal.settings-tabs-enabled > * {
  max-height: calc(100vh - 36px) !important;
  overflow: hidden !important;
  display: flex !important;
  flex-direction: column !important;
}

.settings-tabs-root {
  display: flex;
  flex-direction: column;
  gap: 14px;
  min-height: 0;
  flex: 1;
}

.settings-tabs-nav {
  display: grid;
  grid-template-columns: repeat(3, 1fr);
  gap: 8px;
  padding: 6px;
  border-radius: 16px;
  background: rgba(8, 26, 49, 0.42);
  border: 1px solid rgba(142, 167, 194, 0.20);
  flex: 0 0 auto;
}

.settings-tab-button {
  border: 0;
  border-radius: 12px;
  padding: 10px 12px;
  cursor: pointer;
  font-weight: 850;
  color: #8EA7C2;
  background: transparent;
}

.settings-tab-button.active {
  color: #061321;
  background: #79D7FF;
  box-shadow: 0 10px 25px rgba(121, 215, 255, 0.18);
}

.settings-tab-panels {
  min-height: 0;
  flex: 1;
  overflow: hidden;
}

.settings-tab-panel {
  display: none;
  min-height: 0;
  max-height: min(58vh, 560px);
  overflow-y: auto;
  padding-right: 8px;
  padding-bottom: 8px;
}

.settings-tab-panel.active {
  display: block;
}

.settings-tab-panel .profiles-section {
  margin-top: 0;
}

.settings-tab-panel .profiles-list,
#settingsModal.settings-tabs-enabled #settingsProfilesList {
  max-height: none !important;
  overflow: visible !important;
}

#settingsModal.settings-tabs-enabled .settings-actions {
  position: sticky !important;
  bottom: 0 !important;
  z-index: 50 !important;
  flex: 0 0 auto;
  margin-top: 12px !important;
  padding-top: 14px !important;
  padding-bottom: 8px !important;
  background:
    linear-gradient(180deg, rgba(8, 26, 49, 0.10), rgba(8, 26, 49, 0.98) 28%),
    var(--panel, #081A31) !important;
  border-top: 1px solid rgba(142, 167, 194, 0.24) !important;
}

.legacy-default-access-field {
  display: none !important;
}

.settings-tab-panel::-webkit-scrollbar {
  width: 9px;
}

.settings-tab-panel::-webkit-scrollbar-thumb {
  background: rgba(121, 215, 255, 0.45);
  border-radius: 999px;
}

.settings-tab-panel::-webkit-scrollbar-track {
  background: rgba(142, 167, 194, 0.08);
  border-radius: 999px;
}

@media (max-width: 760px), (max-height: 760px) {
  #settingsModal.settings-tabs-enabled {
    padding: 10px !important;
  }

  #settingsModal.settings-tabs-enabled > * {
    max-height: calc(100vh - 20px) !important;
  }

  .settings-tabs-nav {
    grid-template-columns: 1fr;
  }

  .settings-tab-panel {
    max-height: calc(100vh - 245px);
  }
}
CSS

echo "==> Build check"
rm -rf dist node_modules/.vite
npm run build

echo ""
echo "==> Verify Sprint 8B marker"
grep -R "settings-tabs-general-profiles-security" dist || echo "ERROR: Sprint 8B marker absent from dist"
grep -R "settings-tabs-root" dist || echo "ERROR: Settings tabs absent from dist"

echo ""
echo "Sprint 8B Settings Tabs patch applied."
echo "Run:"
echo "  npm run tauri dev"
