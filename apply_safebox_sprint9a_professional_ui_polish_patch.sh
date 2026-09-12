#!/usr/bin/env bash
set -euo pipefail

# SafeBox Sprint 9A — Professional UI Polish
#
# Goal:
# - Remove childish/bricolage feeling from Settings/Help UI
# - Make Settings / Help look like a serious desktop app
# - Better top action buttons
# - Better tabs
# - Better modal spacing and hierarchy
# - No encryption / core logic changes

ROOT="$(pwd)"
if [ ! -d "$ROOT/safebox-desktop" ]; then
  echo "ERROR: Run this from safebox_sbx_mvp root."
  echo "Current: $ROOT"
  exit 1
fi

cd "$ROOT/safebox-desktop"

echo "==> Backup style.css"
cp src/style.css "src/style.css.backup-sprint9a-pro-ui.$(date +%Y%m%d%H%M%S)"

cat >> src/style.css <<'CSS'

/* ========================================================================
   SafeBox Sprint 9A — Professional UI Polish
   Marker: safebox-professional-ui-polish-v1
   ======================================================================== */

/* Overall refinement */
:root {
  --sbx-surface: rgba(8, 18, 34, 0.96);
  --sbx-surface-2: rgba(12, 25, 45, 0.96);
  --sbx-line: rgba(150, 170, 195, 0.22);
  --sbx-line-strong: rgba(150, 170, 195, 0.34);
  --sbx-soft: rgba(255, 255, 255, 0.055);
  --sbx-soft-hover: rgba(255, 255, 255, 0.085);
  --sbx-focus: rgba(93, 190, 255, 0.26);
  --sbx-blue: #5DBEFF;
  --sbx-text-soft: #A7B5C7;
}

:root[data-theme="light"] {
  --sbx-surface: rgba(255, 255, 255, 0.98);
  --sbx-surface-2: rgba(246, 250, 255, 0.98);
  --sbx-line: rgba(20, 45, 75, 0.16);
  --sbx-line-strong: rgba(20, 45, 75, 0.26);
  --sbx-soft: rgba(11, 92, 173, 0.045);
  --sbx-soft-hover: rgba(11, 92, 173, 0.075);
  --sbx-focus: rgba(11, 92, 173, 0.18);
  --sbx-blue: #0B5CAD;
  --sbx-text-soft: #62758A;
}

/* Top action area: serious desktop toolbar */
.top-actions {
  display: flex !important;
  align-items: center !important;
  gap: 8px !important;
}

.top-actions .ghost-btn,
#settingsBtn,
#helpBtn,
#themeToggle {
  min-height: 38px !important;
  padding: 0 13px !important;
  border-radius: 12px !important;
  border: 1px solid var(--sbx-line) !important;
  background: var(--sbx-soft) !important;
  color: var(--text) !important;
  font-size: 13px !important;
  font-weight: 760 !important;
  letter-spacing: 0 !important;
  box-shadow: none !important;
}

.top-actions .ghost-btn:hover,
#settingsBtn:hover,
#helpBtn:hover,
#themeToggle:hover {
  background: var(--sbx-soft-hover) !important;
  border-color: var(--sbx-line-strong) !important;
}

/* Modal backdrop: less flashy, more professional */
.modal-backdrop,
#settingsModal,
#howToUseModal {
  background: rgba(4, 10, 19, 0.68) !important;
  backdrop-filter: blur(18px) saturate(110%) !important;
  -webkit-backdrop-filter: blur(18px) saturate(110%) !important;
}

/* Modal card */
.settings-modal,
.help-modal-card,
#settingsModal > *,
#howToUseModal > * {
  width: min(720px, calc(100vw - 36px)) !important;
  max-height: min(86vh, 820px) !important;
  padding: 0 !important;
  border-radius: 22px !important;
  border: 1px solid var(--sbx-line-strong) !important;
  background: linear-gradient(180deg, var(--sbx-surface), var(--sbx-surface-2)) !important;
  box-shadow:
    0 34px 90px rgba(0, 0, 0, 0.42),
    0 1px 0 rgba(255, 255, 255, 0.05) inset !important;
  overflow: hidden !important;
}

/* Modal header */
.modal-head {
  padding: 22px 24px 18px !important;
  border-bottom: 1px solid var(--sbx-line) !important;
  background: rgba(255, 255, 255, 0.025) !important;
}

.modal-head h2 {
  margin: 0 !important;
  font-size: 21px !important;
  line-height: 1.15 !important;
  letter-spacing: -0.025em !important;
  font-weight: 850 !important;
}

.modal-head p {
  margin-top: 5px !important;
  font-size: 13px !important;
  color: var(--sbx-text-soft) !important;
  font-weight: 620 !important;
}

.icon-btn {
  width: 34px !important;
  height: 34px !important;
  border-radius: 10px !important;
  border: 1px solid var(--sbx-line) !important;
  background: var(--sbx-soft) !important;
  color: var(--sbx-text-soft) !important;
  font-size: 20px !important;
  line-height: 1 !important;
}

.icon-btn:hover {
  background: var(--sbx-soft-hover) !important;
  color: var(--text) !important;
}

/* Settings tabs: clean segmented control */
.settings-tabs-root {
  padding: 18px 24px 0 !important;
  gap: 16px !important;
}

.settings-tabs-nav {
  display: grid !important;
  grid-template-columns: repeat(3, minmax(0, 1fr)) !important;
  gap: 4px !important;
  padding: 4px !important;
  border-radius: 14px !important;
  border: 1px solid var(--sbx-line) !important;
  background: rgba(0, 0, 0, 0.12) !important;
}

.settings-tab-button {
  min-height: 38px !important;
  border-radius: 10px !important;
  padding: 0 12px !important;
  font-size: 13px !important;
  font-weight: 800 !important;
  color: var(--sbx-text-soft) !important;
  background: transparent !important;
  box-shadow: none !important;
}

.settings-tab-button.active {
  color: var(--text) !important;
  background: rgba(255, 255, 255, 0.105) !important;
  border: 1px solid rgba(255, 255, 255, 0.08) !important;
  box-shadow:
    0 8px 22px rgba(0, 0, 0, 0.18),
    0 1px 0 rgba(255, 255, 255, 0.05) inset !important;
}

/* Panels */
.settings-tab-panels {
  min-height: 0 !important;
  overflow: hidden !important;
}

.settings-tab-panel {
  max-height: min(54vh, 520px) !important;
  padding: 2px 2px 10px !important;
  overflow-y: auto !important;
}

.settings-tab-panel label,
.settings-modal label,
.profile-card label {
  color: var(--text) !important;
  font-size: 13px !important;
  font-weight: 760 !important;
  gap: 7px !important;
}

/* Inputs/selects */
.settings-modal input,
.settings-modal select,
.help-modal-card input,
.help-modal-card select,
.profile-card input,
#settingsLanguageSelect {
  min-height: 44px !important;
  border-radius: 12px !important;
  border: 1px solid var(--sbx-line) !important;
  background: rgba(255, 255, 255, 0.055) !important;
  color: var(--text) !important;
  padding: 0 13px !important;
  font-size: 14px !important;
  box-shadow: none !important;
}

.settings-modal input:focus,
.settings-modal select:focus,
.profile-card input:focus,
#settingsLanguageSelect:focus {
  border-color: rgba(93, 190, 255, 0.72) !important;
  box-shadow: 0 0 0 4px var(--sbx-focus) !important;
}

/* Profiles */
.profiles-header {
  align-items: center !important;
  padding: 0 !important;
  margin-bottom: 14px !important;
}

.profiles-header h3 {
  font-size: 15px !important;
  font-weight: 850 !important;
  margin: 0 !important;
}

.profiles-header p {
  margin-top: 4px !important;
  font-size: 12px !important;
  line-height: 1.45 !important;
  color: var(--sbx-text-soft) !important;
}

.profiles-empty-state {
  border-radius: 16px !important;
  border: 1px dashed var(--sbx-line-strong) !important;
  background: rgba(255, 255, 255, 0.035) !important;
  padding: 16px !important;
}

.profiles-empty-state strong {
  font-size: 14px !important;
  font-weight: 850 !important;
}

.profiles-empty-state p {
  margin-top: 6px !important;
  font-size: 13px !important;
  line-height: 1.45 !important;
  color: var(--sbx-text-soft) !important;
}

.profile-card {
  border-radius: 16px !important;
  border: 1px solid var(--sbx-line) !important;
  background: rgba(255, 255, 255, 0.035) !important;
  padding: 16px !important;
}

.profile-card-top {
  padding-bottom: 12px !important;
  margin-bottom: 14px !important;
  border-bottom: 1px solid var(--sbx-line) !important;
}

.profile-card-top strong {
  font-size: 15px !important;
  font-weight: 850 !important;
}

.profile-card-top span {
  color: var(--sbx-blue) !important;
  background: rgba(93, 190, 255, 0.10) !important;
  border: 1px solid rgba(93, 190, 255, 0.20) !important;
  border-radius: 999px !important;
  padding: 3px 9px !important;
  font-size: 11px !important;
  font-weight: 850 !important;
}

/* Buttons inside modals */
.mini-btn,
.profile-actions .mini-btn,
#addProfileBtn,
.profile-toggle-code,
.profile-set-default,
.profile-delete {
  min-height: 40px !important;
  padding: 0 13px !important;
  border-radius: 11px !important;
  border: 1px solid var(--sbx-line) !important;
  background: rgba(255, 255, 255, 0.055) !important;
  color: var(--text) !important;
  font-size: 13px !important;
  font-weight: 800 !important;
  box-shadow: none !important;
}

.mini-btn:hover,
#addProfileBtn:hover,
.profile-toggle-code:hover,
.profile-set-default:hover {
  background: rgba(255, 255, 255, 0.085) !important;
  border-color: var(--sbx-line-strong) !important;
}

.danger-link,
.profile-delete {
  color: #FF9AAA !important;
}

.danger-link:hover,
.profile-delete:hover {
  background: rgba(255, 113, 139, 0.10) !important;
  border-color: rgba(255, 113, 139, 0.30) !important;
}

/* Modal footer */
.settings-actions,
#settingsModal.settings-tabs-enabled .settings-actions,
#howToUseModal .settings-actions {
  margin: 0 !important;
  padding: 16px 24px 20px !important;
  border-top: 1px solid var(--sbx-line) !important;
  background:
    linear-gradient(180deg, rgba(255,255,255,0.025), rgba(0,0,0,0.08)),
    var(--sbx-surface-2) !important;
  position: sticky !important;
  bottom: 0 !important;
  z-index: 50 !important;
}

.settings-actions .primary-btn,
#saveSettingsBtn,
#closeHelpFooterBtn {
  min-height: 44px !important;
  border-radius: 12px !important;
  border: 1px solid rgba(93, 190, 255, 0.42) !important;
  background: linear-gradient(180deg, rgba(93, 190, 255, 0.92), rgba(11, 92, 173, 0.92)) !important;
  color: white !important;
  font-size: 14px !important;
  font-weight: 850 !important;
  box-shadow: 0 12px 26px rgba(11, 92, 173, 0.24) !important;
}

#cancelSettingsBtn {
  min-height: 44px !important;
  border-radius: 12px !important;
  background: rgba(255, 255, 255, 0.055) !important;
  border: 1px solid var(--sbx-line) !important;
  color: var(--text) !important;
  font-size: 14px !important;
  font-weight: 820 !important;
}

/* Help modal */
.help-content {
  padding: 18px 24px !important;
  gap: 12px !important;
}

.help-section {
  border-radius: 15px !important;
  border: 1px solid var(--sbx-line) !important;
  background: rgba(255, 255, 255, 0.035) !important;
  padding: 14px 15px !important;
}

.help-section h3 {
  font-size: 14px !important;
  font-weight: 850 !important;
  margin: 0 0 6px !important;
}

.help-section p {
  font-size: 13px !important;
  line-height: 1.52 !important;
  color: var(--sbx-text-soft) !important;
}

/* Scrollbars: subtle */
.settings-tab-panel::-webkit-scrollbar,
.help-content::-webkit-scrollbar,
#settingsProfilesList::-webkit-scrollbar {
  width: 8px !important;
}

.settings-tab-panel::-webkit-scrollbar-thumb,
.help-content::-webkit-scrollbar-thumb,
#settingsProfilesList::-webkit-scrollbar-thumb {
  background: rgba(160, 180, 205, 0.30) !important;
  border-radius: 999px !important;
}

.settings-tab-panel::-webkit-scrollbar-track,
.help-content::-webkit-scrollbar-track,
#settingsProfilesList::-webkit-scrollbar-track {
  background: transparent !important;
}

/* Mobile */
@media (max-width: 760px), (max-height: 760px) {
  .settings-modal,
  .help-modal-card,
  #settingsModal > *,
  #howToUseModal > * {
    width: calc(100vw - 20px) !important;
    max-height: calc(100vh - 20px) !important;
    border-radius: 18px !important;
  }

  .modal-head,
  .settings-actions,
  #settingsModal.settings-tabs-enabled .settings-actions,
  #howToUseModal .settings-actions,
  .help-content,
  .settings-tabs-root {
    padding-left: 16px !important;
    padding-right: 16px !important;
  }

  .settings-tabs-nav {
    grid-template-columns: 1fr !important;
  }

  .settings-tab-panel {
    max-height: calc(100vh - 250px) !important;
  }
}
CSS

echo "==> Build check"
rm -rf dist node_modules/.vite
npm run build

echo ""
echo "==> Verify Professional UI marker"
grep -R "safebox-professional-ui-polish-v1" dist || echo "ERROR: professional UI marker absent from dist"

echo ""
echo "Professional UI polish applied."
echo "Run:"
echo "  npm run tauri dev"
