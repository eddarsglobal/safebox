#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

echo "[1/7] Emulator recovery invariants"
grep -q -- '-no-snapshot-load' safebox-desktop/scripts/android_cold_dev.sh
grep -q -- '-no-snapshot-save' safebox-desktop/scripts/android_cold_dev.sh
grep -q 'sys.boot_completed' safebox-desktop/scripts/android_cold_dev.sh
grep -q 'adb device detected' safebox-desktop/scripts/android_cold_dev.sh
grep -q 'SAFEBOX_ANDROID_COLD_BOOT_READY' safebox-desktop/scripts/android_cold_dev.sh
grep -q 'android:cold-dev' safebox-desktop/package.json
! grep -A5 'struct PreparedLocalInput' safebox-desktop/src-tauri/src/lib.rs | grep -q 'display_name:'
echo "ANDROID_EMULATOR_RECOVERY_R11_INVARIANTS_PASS"

echo "[2/7] Shell syntax"
bash -n safebox-desktop/scripts/android_cold_dev.sh
bash -n safebox-desktop/scripts/safebox_tauri.sh

echo "[3/7] JSON/TOML"
python3 - <<'PY2'
import json, tomllib
from pathlib import Path
json.loads(Path('safebox-desktop/package.json').read_text())
json.loads(Path('safebox-desktop/package-lock.json').read_text())
tomllib.loads(Path('safebox-desktop/src-tauri/Cargo.toml').read_text())
print('JSON_TOML_PASS')
PY2

echo "[4/7] Rust format"
if command -v cargo >/dev/null 2>&1; then cargo fmt --all -- --check; else echo 'SKIP: cargo unavailable'; fi

echo "[5/7] Rust checks"
if command -v cargo >/dev/null 2>&1; then
  cargo test -p safebox-core --locked
  cargo check -p safebox-desktop --locked
else echo 'SKIP: cargo unavailable'; fi

echo "[6/7] Frontend build"
if command -v npm >/dev/null 2>&1; then (cd safebox-desktop && npm ci && npm run build); else echo 'SKIP: npm unavailable'; fi

echo "[7/7] R9 security/platform invariants"
bash verification/verify_v022c_android_document_io_r9.sh

echo "SAFEBOX_V022C_ANDROID_EMULATOR_RECOVERY_R11_VERIFY_PASS"
