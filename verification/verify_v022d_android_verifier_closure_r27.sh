#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "[1/5] R27 historical Android verifier semantics"
python3 - <<'PY'
from pathlib import Path
r13=Path('verification/verify_v022c_android_auto_init_r13.sh').read_text()
r9=Path('verification/verify_v022c_android_document_io_r9.sh').read_text()
cold=Path('safebox-desktop/scripts/android_cold_dev.sh').read_text()
assert "semantic Android init invocation missing" in r13
assert "legacy = 'npx tauri android init' in s" in r13
assert "local = 'node_modules/.bin/tauri' in s and 'android init' in s" in r13
assert 'node_modules/.bin/tauri' in cold and 'android init' in cold
assert 'npx tauri android init' not in cold
assert './node_modules/.bin/tauri info' in r9
assert 'npx tauri info' not in r9
print('SAFEBOX_ANDROID_HISTORICAL_VERIFIER_SEMANTICS_R27_PASS')
PY

echo "[2/5] Shell syntax"
bash -n verification/verify_v022c_android_auto_init_r13.sh
bash -n verification/verify_v022c_android_document_io_r9.sh
bash -n verification/verify_v022d_android_verifier_compat_r26.sh
bash -n verification/verify_v022d_android_verifier_closure_r27.sh

echo "[3/5] JSON/TOML + Rust format"
python3 - <<'PY'
import json,tomllib
from pathlib import Path
for p in [Path('safebox-desktop/package.json'),Path('safebox-desktop/package-lock.json'),Path('safebox-desktop/src-tauri/tauri.conf.json'),Path('safebox-desktop/src-tauri/tauri.android.conf.json')]:
    json.loads(p.read_text())
for p in [Path('Cargo.toml'),Path('safebox-core/Cargo.toml'),Path('safebox-cli/Cargo.toml'),Path('safebox-desktop/src-tauri/Cargo.toml')]:
    tomllib.loads(p.read_text())
print('JSON_TOML_PASS')
PY
cargo fmt --all -- --check

echo "[4/5] R26 complete baseline gate"
bash verification/verify_v022d_android_verifier_compat_r26.sh

echo "[5/5] R27 no-npx verifier policy"
python3 - <<'PY'
from pathlib import Path
for rel in [
    'safebox-desktop/scripts/android_cold_dev.sh',
    'safebox-desktop/scripts/safebox_tauri.sh',
    'safebox-desktop/scripts/install_android_launcher_icon.sh',
    'verification/verify_v022c_android_document_io_r9.sh',
]:
    text=Path(rel).read_text()
    assert 'npx tauri' not in text, f'npx tauri remains in active Android path: {rel}'
print('SAFEBOX_ANDROID_NO_NPX_VERIFIER_R27_PASS')
PY

echo "SAFEBOX_V022D_ANDROID_VERIFIER_CLOSURE_R27_VERIFY_PASS"
