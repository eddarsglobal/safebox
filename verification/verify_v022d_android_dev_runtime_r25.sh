#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "[1/6] R25 Android dev-runtime dependency invariants"
python3 - <<'PY'
from pathlib import Path
scripts = {
    'cold': Path('safebox-desktop/scripts/android_cold_dev.sh').read_text(),
    'wrap': Path('safebox-desktop/scripts/safebox_tauri.sh').read_text(),
    'icon': Path('safebox-desktop/scripts/install_android_launcher_icon.sh').read_text(),
    'ensure': Path('safebox-desktop/scripts/ensure_frontend_toolchain.sh').read_text(),
}
for name in ('cold','wrap','icon'):
    assert 'npx tauri' not in scripts[name], f'npx tauri still present in {name}'
assert 'SAFEBOX_FRONTEND_TOOLCHAIN_READY' in scripts['ensure']
assert 'rm -rf node_modules' in scripts['ensure'] and 'npm ci' in scripts['ensure']
assert 'node_modules/.bin/tauri' in scripts['cold']
assert 'node_modules/.bin/tauri' in scripts['wrap']
assert 'android-studio-script' in scripts['wrap']
assert 'SAFEBOX_ANDROID_RUNTIME_TAURI_MISSING' in scripts['wrap']
assert 'node_modules/.bin/tauri' in scripts['icon']
assert 'ensure_frontend_toolchain' in scripts['cold']
print('SAFEBOX_ANDROID_DIRECT_TAURI_RUNTIME_R25_PASS')
PY

echo "[2/6] R25 locked toolchain versions"
python3 - <<'PY'
import json
from pathlib import Path
pkg=json.loads(Path('safebox-desktop/package.json').read_text())
assert pkg['devDependencies']['vite']=='8.1.3'
assert pkg['devDependencies']['@tauri-apps/cli']=='2.11.4'
assert pkg['devDependencies']['typescript']=='7.0.2'
assert pkg.get('overrides',{}).get('postcss')=='8.5.24'
assert pkg.get('overrides',{}).get('nanoid')=='3.3.18'
print('SAFEBOX_ANDROID_LOCKED_TOOLCHAIN_R25_PASS')
PY

echo "[3/6] Shell syntax"
bash -n safebox-desktop/scripts/ensure_frontend_toolchain.sh
bash -n safebox-desktop/scripts/android_cold_dev.sh
bash -n safebox-desktop/scripts/install_android_launcher_icon.sh
bash -n safebox-desktop/scripts/safebox_tauri.sh
bash -n verification/verify_v022d_android_dev_runtime_r25.sh

echo "[4/6] JSON/TOML + Rust format"
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

echo "[5/6] R24 complete baseline gate"
bash verification/verify_v022d_android_supply_chain_r24.sh

echo "[6/6] Runtime script policy"
python3 - <<'PY'
from pathlib import Path
cold=Path('safebox-desktop/scripts/android_cold_dev.sh').read_text()
# npm ci may only be reached through the pre-runtime ensure helper; the cold launcher itself must not mutate deps after Tauri starts.
assert 'npm ci' not in cold
wrap=Path('safebox-desktop/scripts/safebox_tauri.sh').read_text()
assert 'refusing dependency mutation while Vite is running' in wrap
assert 'exec "$DESKTOP_DIR/node_modules/.bin/tauri" android dev' in cold
print('SAFEBOX_ANDROID_NO_CONCURRENT_NPM_R25_PASS')
PY

echo "SAFEBOX_V022D_ANDROID_DEV_RUNTIME_R25_VERIFY_PASS"
