#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TS="$ROOT/safebox-desktop/src/main.ts"
CSS="$ROOT/safebox-desktop/src/style.css"

grep -q 'settings-appearance-help-light-fix-r3' "$TS"
grep -q 'settings-appearance-help-light-fix-r3' "$CSS"
grep -q 'data-theme-mode="system"' "$TS"
grep -q 'data-theme-mode="light"' "$TS"
grep -q 'data-theme-mode="dark"' "$TS"
! grep -q '<button id="themeToggle"' "$TS"
grep -q ':root\[data-theme="light"\] #settingsModal.sbx-hard-settings-fixed .settings-tab-button.active' "$CSS"
echo SAFEBOX_SETTINGS_R3_INVARIANTS_PASS

cd "$ROOT/safebox-desktop"
if [ ! -d node_modules ]; then npm ci; fi
npm run build
echo SAFEBOX_SETTINGS_R3_BUILD_PASS
