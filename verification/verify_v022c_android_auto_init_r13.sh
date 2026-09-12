#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

echo "[1/5] Android auto-init invariants"
python3 - <<'PY_R13'
from pathlib import Path
s = Path('safebox-desktop/scripts/android_cold_dev.sh').read_text()
assert 'ANDROID_PROJECT_DIR=' in s and 'src-tauri/gen/android' in s
assert 'ensure_android_project' in s
legacy = 'npx tauri android init' in s
local = 'node_modules/.bin/tauri' in s and 'android init' in s
assert legacy or local, 'semantic Android init invocation missing'
for marker in ('SAFEBOX_ANDROID_PROJECT_READY','SAFEBOX_ANDROID_PROJECT_REUSED','SAFEBOX_ANDROID_INIT_FAILED'):
    assert marker in s, f'missing Android auto-init marker: {marker}'
print('ANDROID_AUTO_INIT_R13_INVARIANTS_PASS')
PY_R13

echo "[2/5] Shell syntax"
bash -n safebox-desktop/scripts/android_cold_dev.sh

echo "[3/5] JSON/TOML"
python3 - <<'PY2'
import json, tomllib
from pathlib import Path
json.loads(Path('safebox-desktop/package.json').read_text())
json.loads(Path('safebox-desktop/package-lock.json').read_text())
tomllib.loads(Path('safebox-desktop/src-tauri/Cargo.toml').read_text())
print('JSON_TOML_PASS')
PY2

echo "[4/5] R12 complete baseline gate"
bash verification/verify_v022c_android_emulator_recovery_r12.sh

echo "[5/5] Generated-project policy"
if [ -d safebox-desktop/src-tauri/gen/android ]; then
  echo "NOTE: local generated Android project present; checkpoints may omit it"
fi

echo "SAFEBOX_V022C_ANDROID_AUTO_INIT_R13_VERIFY_PASS"
