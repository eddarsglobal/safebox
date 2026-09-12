#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
ID="$(cat SAFEBOX_V028_PACKAGE_ID.txt)"
[[ "$ID" == "v0.2.8-cross-platform-web-foundation-r67-20260830A" ]]
echo SAFEBOX_V028_R66_BASELINE_RETAINED_R67_PASS
python3 safebox-desktop/scripts/desktop_cross_platform_audit.py
python3 safebox-desktop/scripts/web_foundation_check.py
# Immutable security/runtime files from R66 must remain untouched in R67.
python3 - <<'PY'
from pathlib import Path
import hashlib
files={
'safebox-core/src/crypto.rs':'d30d1530b38988e544f0aa25808b8048f88d1a9578036160fc7efa40c854a99c',
'safebox-core/src/format.rs':'26edb67b2be91ff5c7d765e100e4aafa5e50933919c0db2e4370901f67205ea1',
'safebox-desktop/src-tauri/ios/SafeBoxAdsBridge.mm':'a408b55ec036ee71894853c144fc753e7a181eeaca7b5ae6872ec636dfc5e2ea',
'safebox-desktop/src-tauri/ios/SafeBoxColdOpenBridge.mm':'4712895a3941cb359bdb87a55f92c117af247393d5aa1db07b979bde6eb22f42',
}
for f, expected in files.items():
    got=hashlib.sha256(Path(f).read_bytes()).hexdigest()
    if got != expected:
        raise SystemExit(f'hash mismatch {f}: {got}')
print('SAFEBOX_R67_SECURITY_IMMUTABLE_HASHES_PASS')
PY
bash verification/verify_v027_ios_archive_passthrough_r39.sh >/dev/null
echo SAFEBOX_R67_R39_RETAINED_PASS
bash verification/verify_v027_ios_gma_link_scope_r41.sh >/dev/null
echo SAFEBOX_R67_R41_RETAINED_PASS
bash verification/verify_v027_ios_ads_runtime_session_r42.sh >/dev/null
echo SAFEBOX_R67_R42_RETAINED_PASS
if find . -type d -name node_modules -print -quit | grep -q .; then
  echo SAFEBOX_R67_HYGIENE_FAIL: node_modules >&2; exit 1
fi
echo SAFEBOX_R67_HYGIENE_PASS
echo SAFEBOX_V028_CROSS_PLATFORM_WEB_FOUNDATION_R67_VERIFY_PASS
