#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "[1/7] R20 Settings cleanup invariants"
python3 - <<'PY2'
from pathlib import Path
s=Path('safebox-desktop/src/main.ts').read_text()
settings=s[s.index('<div id="settingsModal"'):s.index('</main>')]
assert 'MVP: the global code is kept only for this app session' not in settings
assert 'Permanent secure storage comes later with Keychain / Credential Manager' not in settings
assert 'placeholder="Enter global code"' in settings
assert 'placeholder="kept only for this app session"' not in settings
print('SAFEBOX_SETTINGS_MVP_NOTE_REMOVED_R20_PASS')
PY2

echo "[2/7] npm supply-chain pin"
python3 - <<'PY2'
import json
from pathlib import Path
pkg=json.loads(Path('safebox-desktop/package.json').read_text())
lock=json.loads(Path('safebox-desktop/package-lock.json').read_text())
assert pkg.get('overrides',{}).get('nanoid') == '3.3.18'
n=lock['packages']['node_modules/nanoid']
assert n['version'] == '3.3.18', n
assert n['resolved'].endswith('/nanoid-3.3.18.tgz')
assert n['integrity'] == 'sha512-DTg4MJbGMWkfi6VZFdNt2/caMbQy4Ou+Op/hJQvGEWcnVfoA1QA+xzRKAzw9jD6+GVOOeYr/mIcuDSdug6F6+w=='
print('SAFEBOX_NANOID_3318_PIN_R20_PASS')
PY2

echo "[3/7] Shell + JSON/TOML"
bash -n verification/verify_v022c_settings_supply_chain_r20.sh
python3 - <<'PY2'
import json, tomllib
from pathlib import Path
for p in [Path('safebox-desktop/package.json'), Path('safebox-desktop/package-lock.json'), Path('safebox-desktop/src-tauri/tauri.conf.json')]:
    json.loads(p.read_text())
for p in [Path('Cargo.toml'),Path('safebox-core/Cargo.toml'),Path('safebox-cli/Cargo.toml'),Path('safebox-desktop/src-tauri/Cargo.toml')]:
    tomllib.loads(p.read_text())
print('JSON_TOML_PASS')
PY2

echo "[4/7] Rust format"
cargo fmt --all -- --check

echo "[5/7] R19 complete baseline gate"
bash verification/verify_v022c_android_runtime_r19.sh

echo "[6/7] Frontend clean install/build + full audit"
cd safebox-desktop
rm -rf node_modules
npm ci
npm run build
npm audit --audit-level=high
cd ..

echo "[7/7] Runtime audit must also be clean"
cd safebox-desktop
npm audit --omit=dev --audit-level=high
cd ..

echo "SAFEBOX_V022C_SETTINGS_SUPPLY_CHAIN_R20_VERIFY_PASS"
