#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

[[ "$(cat SAFEBOX_V028_PACKAGE_ID.txt)" == "v0.2.8-web-wasm-entropy-closure-r69-20260830A" ]] || {
  echo "SAFEBOX_WEB_R69_PACKAGE_ID_FAIL"; exit 1;
}
echo "SAFEBOX_WEB_R69_PACKAGE_ID_PASS"

python3 safebox-desktop/scripts/desktop_cross_platform_audit.py
python3 safebox-desktop/scripts/web_foundation_check.py
python3 safebox-desktop/scripts/web_wasm_source_check.py

python3 - <<'PY'
from pathlib import Path
core = Path('safebox-core/Cargo.toml').read_text()
crypto = Path('safebox-core/src/crypto.rs').read_text()
assert 'argon2 = { version = "=0.5.3", default-features = false, features = ["alloc", "zeroize"] }' in core
assert 'Argon2::new(Algorithm::Argon2id, Version::V0x13, params)' in crypto
assert 'argon2.hash_password_into(code.as_bytes(), salt, &mut key)?' in crypto
assert '#[cfg(not(target_arch = "wasm32"))]\nuse rand_core::{OsRng, RngCore};' in crypto
lock = Path('Cargo.lock').read_text()
argon = lock.split('name = "argon2"',1)[1].split('\n\n',1)[0]
assert '"zeroize"' in argon and '"password-hash"' not in argon
print('SAFEBOX_WEB_R69_LOCKED_FEATURE_GRAPH_PASS')
print('SAFEBOX_WEB_R69_ARGON2_LOW_LEVEL_API_PASS')
print('SAFEBOX_WEB_R69_NO_WASM_OSRNG_PATH_PASS')
PY

python3 -m py_compile \
  safebox-desktop/scripts/web_foundation_check.py \
  safebox-desktop/scripts/web_wasm_source_check.py \
  safebox-desktop/scripts/web_wasm_contract_check.py \
  safebox-desktop/scripts/web_dist_check.py
bash -n safebox-desktop/scripts/web_wasm_build.sh
find . -type d -name __pycache__ -prune -exec rm -rf {} +

# Immutable cryptographic/desktop runtime source files remain byte-for-byte as R68/R67.
python3 - <<'PY'
from pathlib import Path
import hashlib
expected = {
 'safebox-core/src/format.rs':'26edb67b2be91ff5c7d765e100e4aafa5e50933919c0db2e4370901f67205ea1',
 'safebox-core/src/validation.rs':'8ae9df9563a7d8bf0fb0d3399c4642a0ca4e796f284b5681a3cd1f02237f209b',
 'safebox-desktop/src-tauri/src/lib.rs':'5a4bc10bc1d362a0737c0da2b0b6caad00436206137fd0fc800e2b842c57f297',
 'safebox-desktop/src-tauri/ios/SafeBoxAdsBridge.mm':'a408b55ec036ee71894853c144fc753e7a181eeaca7b5ae6872ec636dfc5e2ea',
 'safebox-desktop/src-tauri/ios/SafeBoxShareInboxBridge.mm':'da8b92247ee777a03770cc7df67b52b13a8981ca6987b70403fbd97e8913d9e4',
 'safebox-desktop/src-tauri/ios-share/ShareViewController.swift':'c868a61f534a425eabf3bea9adeb591474823053ecd582c799a1cafba4da59a4',
}
for path,h in expected.items():
    got=hashlib.sha256(Path(path).read_bytes()).hexdigest()
    assert got==h,(path,got,h)
print('SAFEBOX_WEB_R69_SECURITY_IMMUTABLE_HASHES_PASS')
PY

if find . -type d \( -name node_modules -o -name target -o -name dist -o -name __pycache__ \) -print -quit | grep -q .; then
  echo "SAFEBOX_R69_HYGIENE_FAIL: generated dependency/build directory present"
  exit 1
fi
if find . -type f -name 'safebox_core.wasm' -print -quit | grep -q .; then
  echo "SAFEBOX_R69_HYGIENE_FAIL: prebuilt WASM must be produced on reference Mac"
  exit 1
fi

echo "SAFEBOX_R69_HYGIENE_PASS"
echo "SAFEBOX_V028_WEB_WASM_ENTROPY_CLOSURE_R69_VERIFY_PASS"
