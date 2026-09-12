#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "[1/5] R18 UI clarity invariants"
python3 - <<'PY'
from pathlib import Path
main=Path('safebox-desktop/src/main.ts').read_text()
css=Path('safebox-desktop/src/style.css').read_text()
assert 'Overwrite original if exists' not in main
assert '<strong>Replace existing file</strong>' in main
assert 'Off: keep both files. On: replace the existing file with the restored one.' in main
assert 'id="overwrite" type="checkbox"' in main
assert 'id="overwrite" type="checkbox" checked' not in main
assert 'settings-global-sender-field' in main
assert '#settingsModal .settings-global-sender-field' in css
assert 'margin-top: 20px !important;' in css
print('SAFEBOX_UI_CLARITY_R18_INVARIANTS_PASS')
PY

echo "[2/5] Shell syntax"
bash -n verification/verify_v022c_ui_clarity_r18.sh

echo "[3/5] JSON/TOML"
python3 - <<'PY'
import json, pathlib, tomllib
for p in pathlib.Path('.').rglob('*.json'):
    if 'node_modules' not in p.parts and 'target' not in p.parts:
        json.loads(p.read_text())
for p in pathlib.Path('.').rglob('*.toml'):
    if 'target' not in p.parts:
        tomllib.loads(p.read_text())
print('JSON_TOML_PASS')
PY

echo "[4/5] Rust format"
cargo fmt --all -- --check

echo "[5/5] R17 baseline gate"
bash verification/verify_v022c_android_icon_r17.sh

echo "SAFEBOX_V022C_UI_CLARITY_R18_VERIFY_PASS"
