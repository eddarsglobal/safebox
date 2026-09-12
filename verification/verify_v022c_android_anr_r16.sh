#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "[1/4] R14 semantic platform verifier"
bash -n verification/verify_v022c_android_window_api_r14.sh
python3 - <<'PY'
from pathlib import Path
s=Path('verification/verify_v022c_android_window_api_r14.sh').read_text()
assert 'function_level' in s
assert 'mobile focus_main_window stub missing' in s
assert 'unminimize leaked into mobile code path' in s
print('ANDROID_WINDOW_API_SEMANTIC_GATE_R16_PASS')
PY

echo "[2/4] R15 ANR gate script syntax"
bash -n verification/verify_v022c_android_anr_r15.sh

echo "[3/4] R15 complete gate"
bash verification/verify_v022c_android_anr_r15.sh

echo "[4/4] R16 verifier policy"
python3 - <<'PY'
from pathlib import Path
s=Path('safebox-desktop/src-tauri/src/lib.rs').read_text()
assert '#[cfg(desktop)]\nfn focus_main_window(app: &tauri::AppHandle) {' in s
assert '#[cfg(mobile)]\nfn focus_main_window(_app: &tauri::AppHandle) {' in s
print('ANDROID_ANR_R16_POLICY_PASS')
PY

echo "SAFEBOX_V022C_ANDROID_ANR_R16_VERIFY_PASS"
