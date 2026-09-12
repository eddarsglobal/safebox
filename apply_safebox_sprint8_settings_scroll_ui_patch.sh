#!/usr/bin/env bash
set -euo pipefail

# SafeBox Sprint 8 UI Hotfix — Settings Scroll + Sticky Actions
#
# Fixes:
# - Settings modal content too tall
# - Bottom content not reachable
# - Save / Cancel should stay visible
# - Access Profiles should be easier to scroll/edit
#
# Run from project root:
#   cd "/Users/noury/Documents/App_py/SAFEBOX/safebox_sbx_mvp"
#   bash apply_safebox_sprint8_settings_scroll_ui_patch.sh

ROOT="$(pwd)"
if [ ! -d "$ROOT/safebox-desktop" ]; then
  echo "ERROR: Run this from safebox_sbx_mvp root."
  echo "Current: $ROOT"
  exit 1
fi

cd "$ROOT/safebox-desktop"

echo "==> Backup style.css"
cp src/style.css "src/style.css.backup-sprint8-settings-scroll.$(date +%Y%m%d%H%M%S)"

cat >> src/style.css <<'CSS'

/* Sprint 8 UI Hotfix — Settings modal scroll + sticky footer */
.modal-backdrop {
  align-items: center;
  justify-content: center;
  padding: 18px;
}

.settings-modal,
.modal-card,
#settingsModal .settings-modal,
#settingsModal .modal-card {
  max-height: min(86vh, 860px);
  overflow: hidden;
  display: flex;
  flex-direction: column;
}

.settings-body,
.modal-body,
#settingsModal .settings-body,
#settingsModal .modal-body {
  overflow-y: auto;
  overscroll-behavior: contain;
  padding-right: 6px;
  max-height: calc(86vh - 150px);
}

/* If the modal has no explicit body wrapper, make direct form content scrollable */
#settingsModal form,
#settingsModal .settings-content,
#settingsModal .modal-content {
  overflow-y: auto;
  overscroll-behavior: contain;
}

/* Keep Save / Cancel always visible */
.settings-actions,
#settingsModal .settings-actions {
  position: sticky;
  bottom: 0;
  z-index: 10;
  margin-top: 16px;
  padding-top: 14px;
  background:
    linear-gradient(180deg, rgba(8, 26, 49, 0.10), rgba(8, 26, 49, 0.96) 28%),
    var(--panel, #081A31);
  border-top: 1px solid rgba(142, 167, 194, 0.22);
}

/* Make access profiles area readable without making the whole modal endless */
.profiles-section {
  margin-top: 14px;
}

.profiles-list {
  max-height: min(42vh, 460px);
  overflow-y: auto;
  padding-right: 6px;
  overscroll-behavior: contain;
}

/* Better scrollbars */
.settings-body::-webkit-scrollbar,
.modal-body::-webkit-scrollbar,
.profiles-list::-webkit-scrollbar,
#settingsModal form::-webkit-scrollbar,
#settingsModal .settings-content::-webkit-scrollbar,
#settingsModal .modal-content::-webkit-scrollbar {
  width: 9px;
}

.settings-body::-webkit-scrollbar-thumb,
.modal-body::-webkit-scrollbar-thumb,
.profiles-list::-webkit-scrollbar-thumb,
#settingsModal form::-webkit-scrollbar-thumb,
#settingsModal .settings-content::-webkit-scrollbar-thumb,
#settingsModal .modal-content::-webkit-scrollbar-thumb {
  background: rgba(121, 215, 255, 0.35);
  border-radius: 999px;
}

.settings-body::-webkit-scrollbar-track,
.modal-body::-webkit-scrollbar-track,
.profiles-list::-webkit-scrollbar-track,
#settingsModal form::-webkit-scrollbar-track,
#settingsModal .settings-content::-webkit-scrollbar-track,
#settingsModal .modal-content::-webkit-scrollbar-track {
  background: rgba(142, 167, 194, 0.08);
  border-radius: 999px;
}

/* Mobile / smaller windows */
@media (max-width: 760px), (max-height: 760px) {
  .modal-backdrop {
    padding: 10px;
    align-items: stretch;
  }

  .settings-modal,
  .modal-card,
  #settingsModal .settings-modal,
  #settingsModal .modal-card {
    max-height: calc(100vh - 20px);
    width: min(100%, 720px);
  }

  .settings-body,
  .modal-body,
  #settingsModal .settings-body,
  #settingsModal .modal-body {
    max-height: calc(100vh - 160px);
  }

  .profiles-list {
    max-height: 38vh;
  }

  .profiles-header {
    flex-direction: column;
    align-items: stretch;
  }

  .profile-actions {
    justify-content: stretch;
  }

  .profile-actions .mini-btn {
    flex: 1;
  }
}
CSS

echo "==> Build check"
npm run build

echo ""
echo "Settings scroll UI patch applied."
echo "Run:"
echo "  npm run tauri dev"
