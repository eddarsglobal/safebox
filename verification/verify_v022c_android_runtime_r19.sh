#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "[1/6] R19 verifier-order invariants"
python3 - <<'PY'
from pathlib import Path
r17=Path('verification/verify_v022c_android_icon_r17.sh').read_text()
assert r17.index('Checkpoint hygiene before dependency installation') < r17.index('R16 complete baseline gate')
lib=Path('safebox-desktop/src-tauri/src/lib.rs').read_text()
needle='#[cfg(any(target_os = "macos", target_os = "windows", target_os = "linux"))]\nfn run_system_command'
assert needle in lib
print('SAFEBOX_ANDROID_RUNTIME_R19_INVARIANTS_PASS')
PY

echo "[2/6] Shell syntax"
bash -n verification/verify_v022c_android_runtime_r19.sh
bash -n verification/verify_v022c_android_icon_r17.sh

echo "[3/6] JSON/TOML"
python3 - <<'PY'
import json, tomllib
from pathlib import Path
for p in [Path('safebox-desktop/package.json'), Path('safebox-desktop/src-tauri/tauri.conf.json')]:
    json.loads(p.read_text())
for p in [Path('Cargo.toml'), Path('safebox-core/Cargo.toml'), Path('safebox-cli/Cargo.toml'), Path('safebox-desktop/src-tauri/Cargo.toml')]:
    tomllib.loads(p.read_text())
print('JSON_TOML_PASS')
PY

echo "[4/6] Rust format"
cargo fmt --all -- --check

echo "[5/6] R18 complete baseline gate"
bash verification/verify_v022c_ui_clarity_r18.sh

echo "[6/6] Android source warning policy"
python3 - <<'PY'
from pathlib import Path
s=Path('safebox-desktop/src-tauri/src/lib.rs').read_text()
pos=s.index('fn run_system_command')
prefix=s[max(0,pos-120):pos]
assert '#[cfg(any(target_os = "macos", target_os = "windows", target_os = "linux"))]' in prefix
print('ANDROID_DESKTOP_COMMAND_CFG_R19_PASS')
PY

echo "SAFEBOX_V022C_ANDROID_RUNTIME_R19_VERIFY_PASS"
