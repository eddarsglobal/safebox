#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

[[ "$(cat SAFEBOX_V028_PACKAGE_ID.txt)" == "v0.2.8-web-browser-blob-boundary-r77-20260830A" ]] || { echo "SAFEBOX_WEB_R77_PACKAGE_ID_FAIL"; exit 1; }
echo "SAFEBOX_WEB_R77_PACKAGE_ID_PASS"

python3 safebox-desktop/scripts/desktop_cross_platform_audit.py
python3 safebox-desktop/scripts/web_foundation_check.py
python3 safebox-desktop/scripts/web_wasm_source_check.py

python3 - <<'PY'
from pathlib import Path
import hashlib
web = Path('safebox-desktop/src/web-sbx-engine.ts').read_text()
assert 'const downloadBuffer = new ArrayBuffer(bytes.byteLength);' in web
assert 'new Uint8Array(downloadBuffer).set(bytes);' in web
assert 'new Blob([downloadBuffer], { type: mime })' in web
assert 'new Blob([bytes], { type: mime })' not in web
assert 'new Blob([bytes as' not in web
assert 'new Blob([bytes.buffer as' not in web
assert 'SharedArrayBuffer' in web
print('SAFEBOX_WEB_R77_BLOB_ARRAYBUFFER_BOUNDARY_PASS')
print('SAFEBOX_WEB_R77_NO_UNSAFE_BLOB_CAST_PASS')
print('SAFEBOX_WEB_R77_SHARED_BUFFER_EXCLUSION_PASS')

expected={
 'safebox-core/src/crypto.rs':'1d75fe23895cb0196fb7ff5b369c59596c300a3bd3eb5a07395d3287f925b670',
 'safebox-core/src/format.rs':'26edb67b2be91ff5c7d765e100e4aafa5e50933919c0db2e4370901f67205ea1',
 'safebox-core/src/validation.rs':'8ae9df9563a7d8bf0fb0d3399c4642a0ca4e796f284b5681a3cd1f02237f209b',
 'safebox-web-wasm/src/lib.rs':'d5e65323c3d87b02b2f8958d8edc4dfddf500a9787fdf4377080c5092d9ea4c3',
 'safebox-desktop/src-tauri/src/lib.rs':'5a4bc10bc1d362a0737c0da2b0b6caad00436206137fd0fc800e2b842c57f297',
 'safebox-desktop/src-tauri/ios/SafeBoxAdsBridge.mm':'a408b55ec036ee71894853c144fc753e7a181eeaca7b5ae6872ec636dfc5e2ea',
 'safebox-desktop/src-tauri/ios/SafeBoxShareInboxBridge.mm':'da8b92247ee777a03770cc7df67b52b13a8981ca6987b70403fbd97e8913d9e4',
 'safebox-desktop/src-tauri/ios-share/ShareViewController.swift':'c868a61f534a425eabf3bea9adeb591474823053ecd582c799a1cafba4da59a4',
}
for path,h in expected.items():
    got=hashlib.sha256(Path(path).read_bytes()).hexdigest()
    assert got==h,(path,got,h)
print('SAFEBOX_WEB_R77_R76_CRYPTO_WASM_UNCHANGED_PASS')
print('SAFEBOX_WEB_R77_DESKTOP_IOS_RUNTIME_UNCHANGED_PASS')
PY

if find . -type d \( -name node_modules -o -name target -o -name dist -o -name __pycache__ \) -print -quit | grep -q .; then
  echo "SAFEBOX_R77_HYGIENE_FAIL"; exit 1
fi
if find . -type f -name 'safebox_core.wasm' -print -quit | grep -q .; then
  echo "SAFEBOX_R77_HYGIENE_FAIL: prebuilt WASM present"; exit 1
fi

echo "SAFEBOX_R77_HYGIENE_PASS"
echo "SAFEBOX_V028_WEB_BROWSER_BLOB_BOUNDARY_R77_VERIFY_PASS"
