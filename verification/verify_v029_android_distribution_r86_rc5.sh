#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
D="$ROOT/safebox-desktop"
python3 - "$D/scripts/android_release_prepare.sh" "$D/scripts/android_release_fix_tauri_buildtask.sh" <<'PY'
from pathlib import Path
import sys
prepare=Path(sys.argv[1]).read_text()
fix=Path(sys.argv[2]).read_text()
assert 'npm run tauri -- android init' in prepare
assert './node_modules/.bin/tauri android init' not in prepare
assert 'bash scripts/android_release_fix_tauri_buildtask.sh' in prepare
assert 'val executable = """npm""";' in fix
assert 'listOf("run", "--", "tauri", "android", "android-studio-script")' in fix
assert 'SAFEBOX_ANDROID_R86_RC5_NODE_TAURI_MODULE_RESOLUTION_PASS' in fix
print('SAFEBOX_R86_RC5_INIT_VIA_NPM_CONTEXT_PASS')
print('SAFEBOX_R86_RC5_BUILD_TASK_NPM_EXECUTABLE_PASS')
print('SAFEBOX_R86_RC5_BUILD_TASK_NPM_ARGS_PASS')
print('SAFEBOX_R86_RC5_NODE_MODULE_NOT_FOUND_GUARD_PASS')
PY
bash -n "$D/scripts/android_release_prepare.sh"
bash -n "$D/scripts/android_release_fix_tauri_buildtask.sh"
echo 'SAFEBOX_V029_ANDROID_DISTRIBUTION_R86_RC5_PASS'
