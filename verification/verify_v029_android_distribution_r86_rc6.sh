#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
D="$ROOT/safebox-desktop"

python3 - "$D/vite.config.ts" "$D/package.json" "$D/scripts/native_app_entry_check.mjs" "$D/src/main.ts" "$D/scripts/android_release_prepare.sh" "$D/scripts/android_release_fix_tauri_buildtask.sh" <<'PY'
from pathlib import Path
import json, sys
vite=Path(sys.argv[1]).read_text()
pkg=json.loads(Path(sys.argv[2]).read_text())
entry=Path(sys.argv[3]).read_text()
main=Path(sys.argv[4]).read_text()
prepare=Path(sys.argv[5]).read_text()
buildtask=Path(sys.argv[6]).read_text()

# Root cause closure: app.html must be bundled in the normal Tauri/Vite build,
# not only when mode=web.
assert 'build: {' in vite
assert 'landing: resolve(__dirname, "index.html")' in vite
assert 'app: resolve(__dirname, "app.html")' in vite
assert 'build: mode === "web" ?' not in vite
assert pkg['scripts']['build'].endswith('node scripts/native_app_entry_check.mjs')
assert 'dist/app.html' in entry
assert 'SAFEBOX_ANDROID_R86_RC6_APP_HTML_BUNDLE_PASS' in entry
print('SAFEBOX_R86_RC6_NATIVE_APP_HTML_INPUT_PASS')
print('SAFEBOX_R86_RC6_NATIVE_APP_ENTRY_FAIL_CLOSED_PASS')

# Android picker hardening: no custom .sbx provider filter, visible failure,
# and guarded retry for the known first Activity-callback stall class.
assert 'SAFEBOX_ANDROID_DIALOG_FIRST_CALLBACK_RECOVERY' in main
assert 'const recoveryAttempt = open(options);' in main
assert 'Promise.race([firstAttempt, recoveryAttempt])' in main
assert 'sbxOnly && !iosScoped && !androidDialogRuntime' in main
assert 'Could not open the file picker.' in main
assert 'SAFEBOX_FILE_PICKER_FAILED' in main
assert 'enterReceiverMode(path);' in main
print('SAFEBOX_R86_RC6_ANDROID_FIRST_DIALOG_RECOVERY_PASS')
print('SAFEBOX_R86_RC6_ANDROID_EXTENSION_FILTER_REMOVED_PASS')
print('SAFEBOX_R86_RC6_ANDROID_PICKER_VISIBLE_ERROR_PASS')
print('SAFEBOX_R86_RC6_ANDROID_RECEIVER_ROUTE_PASS')

# Preserve the RC5 build-pipeline closure that produced the signed APK/AAB.
assert 'npm run tauri -- android init' in prepare
assert 'bash scripts/android_release_fix_tauri_buildtask.sh' in prepare
assert 'val executable = """npm""";' in buildtask
assert 'listOf("run", "--", "tauri", "android", "android-studio-script")' in buildtask
print('SAFEBOX_R86_RC6_RC5_BUILD_PIPELINE_PRESERVED_PASS')
PY

node --check "$D/scripts/native_app_entry_check.mjs"
bash -n "$D/scripts/android_release_prepare.sh"
bash -n "$D/scripts/android_release_fix_tauri_buildtask.sh"
bash -n "$D/scripts/android_release_signing_setup.sh"
bash -n "$D/scripts/android_release_build.sh"

echo 'SAFEBOX_V029_ANDROID_DISTRIBUTION_R86_RC6_PASS'
