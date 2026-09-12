#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "[1/7] Android share/open config invariants"
python3 - <<'PY1'
import json
from pathlib import Path
d=json.loads(Path('safebox-desktop/src-tauri/tauri.android.conf.json').read_text())
fa=d['bundle']['fileAssociations']
assert any(x.get('ext')==['sbx'] and x.get('mimeType')=='application/octet-stream' and x.get('androidIntentActionFilters')==['view'] for x in fa)
assert any(x.get('ext')==[] and x.get('mimeType')=='*/*' and x.get('androidIntentActionFilters')==['send','sendMultiple'] for x in fa)
print('ANDROID_SHARE_OPEN_CONFIG_R21_PASS')
PY1

echo "[2/7] Native-open security semantics"
python3 - <<'PY2'
from pathlib import Path
r=Path('safebox-desktop/src-tauri/src/lib.rs').read_text()
t=Path('safebox-desktop/src/main.ts').read_text()
for token in ['RunEvent::Opened','opened_paths_from_urls','take_initial_opened_paths','safebox-open-files']:
    assert token in r
for token in ['safebox-open-files','get_document_display_name','Shared file ready.','enterReceiverMode(cleaned)','setInput("#createInput", cleaned)']:
    assert token in t
segment=t[t.index('async function handleSystemOpenedPath'):t.index('async function setupSystemOpenHandler')]
assert 'create_sbx_file' not in segment
assert 'unlock_sbx_file' not in segment
print('ANDROID_SHARE_OPEN_SECURITY_R21_PASS')
PY2

echo "[3/7] JSON/TOML"
python3 - <<'PY3'
import json, pathlib, tomllib
for p in pathlib.Path('.').rglob('*.json'):
    if 'node_modules' not in p.parts: json.loads(p.read_text())
for p in pathlib.Path('.').rglob('*.toml'):
    if 'node_modules' not in p.parts: tomllib.loads(p.read_text())
print('JSON_TOML_PASS')
PY3

echo "[4/7] Shell syntax"
for f in verification/*.sh safebox-desktop/scripts/*.sh; do bash -n "$f"; done

echo "[5/7] R20 baseline gate"
bash verification/verify_v022c_settings_supply_chain_r20.sh

echo "[6/7] Frontend build + runtime audit"
cd safebox-desktop
npm ci
npm run build
npm audit --omit=dev --audit-level=high
cd ..

echo "[7/7] R21 marker"
echo "SAFEBOX_V022D_ANDROID_SHARE_OPEN_R21_VERIFY_PASS"
