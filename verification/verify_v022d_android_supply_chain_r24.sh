#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "[1/4] R24 PostCSS + nanoid supply-chain invariant"
python3 - <<'PY'
import json
from pathlib import Path
pkg = json.loads(Path('safebox-desktop/package.json').read_text())
lock = json.loads(Path('safebox-desktop/package-lock.json').read_text())
overrides = pkg.get('overrides', {})
assert overrides.get('nanoid') == '3.3.18', overrides
assert overrides.get('postcss') == '8.5.24', overrides
packages = lock.get('packages', {})
assert packages['node_modules/nanoid']['version'] == '3.3.18'
post = packages['node_modules/postcss']
version = tuple(map(int, post['version'].split('.')))
assert version >= (8, 5, 23), post['version']
assert post['version'] == '8.5.24', post['version']
assert post['integrity'] == 'sha512-8RyVklq0owXUTa4xlpzu4l9AaVKIdQvAcOHZWaMh98HgySsUtxRVf/chRe3dsSLqb6i40BzGRzEUddRaI+9TSw=='
print('SAFEBOX_POSTCSS_8524_NANOID_3318_R24_PASS')
PY

echo "[2/4] JSON + shell syntax"
python3 -m json.tool safebox-desktop/package.json >/dev/null
python3 -m json.tool safebox-desktop/package-lock.json >/dev/null
bash -n verification/verify_v022d_android_supply_chain_r24.sh

echo "[3/4] R23 complete baseline gate"
bash verification/verify_v022d_android_share_open_r23.sh

echo "[4/4] Full frontend audit gate is inherited from R20/R23"
echo "SAFEBOX_V022D_ANDROID_SUPPLY_CHAIN_R24_VERIFY_PASS"
