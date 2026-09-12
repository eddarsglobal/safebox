#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

echo "[1/8] Duplicate-AVD recovery invariants"
grep -q 'avd_for_serial' safebox-desktop/scripts/android_cold_dev.sh
grep -q 'emu avd name' safebox-desktop/scripts/android_cold_dev.sh
grep -q 'avd_pids' safebox-desktop/scripts/android_cold_dev.sh
grep -q 'SAFEBOX_ANDROID_REUSED_READY' safebox-desktop/scripts/android_cold_dev.sh
grep -q 'SAFEBOX_ANDROID_DUPLICATE_AVD_GUARD' safebox-desktop/scripts/android_cold_dev.sh
grep -q -- '-no-snapshot-load' safebox-desktop/scripts/android_cold_dev.sh
grep -q -- '-no-snapshot-save' safebox-desktop/scripts/android_cold_dev.sh
echo "ANDROID_DUPLICATE_AVD_RECOVERY_R12_INVARIANTS_PASS"

echo "[2/8] Shell syntax"
bash -n safebox-desktop/scripts/android_cold_dev.sh
bash -n safebox-desktop/scripts/safebox_tauri.sh

echo "[3/8] JSON/TOML"
python3 - <<'PY2'
import json, tomllib
from pathlib import Path
json.loads(Path('safebox-desktop/package.json').read_text())
json.loads(Path('safebox-desktop/package-lock.json').read_text())
tomllib.loads(Path('safebox-desktop/src-tauri/Cargo.toml').read_text())
print('JSON_TOML_PASS')
PY2

echo "[4/8] Rust format"
if command -v cargo >/dev/null 2>&1; then cargo fmt --all -- --check; else echo 'SKIP: cargo unavailable'; fi

echo "[5/8] Core tests"
if command -v cargo >/dev/null 2>&1; then cargo test -p safebox-core --locked; else echo 'SKIP: cargo unavailable'; fi

echo "[6/8] Desktop Rust check"
if command -v cargo >/dev/null 2>&1; then cargo check -p safebox-desktop --locked; else echo 'SKIP: cargo unavailable'; fi

echo "[7/8] Frontend build"
if command -v npm >/dev/null 2>&1; then (cd safebox-desktop && npm ci && npm run build); else echo 'SKIP: npm unavailable'; fi

echo "[8/8] R11 + R9 security/platform invariants"
bash verification/verify_v022c_android_emulator_recovery_r11.sh

echo "SAFEBOX_V022C_ANDROID_EMULATOR_RECOVERY_R12_VERIFY_PASS"
