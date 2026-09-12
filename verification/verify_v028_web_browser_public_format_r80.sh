#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
D="$ROOT/safebox-desktop"

grep -qx 'v0.2.8-web-browser-public-format-r80-20260831A' "$ROOT/SAFEBOX_V028_PACKAGE_ID.txt"
python3 -m py_compile "$D/scripts/web_browser_cdp_e2e.py" "$D/scripts/web_production_check.py"
bash -n "$D/scripts/web_browser_e2e.sh"

# Canonical format semantics: magic SBX1, JSON header format SBX.
grep -q 'protectedBytes\[0\] !== 0x53' "$D/src/web-e2e.ts"
grep -q 'protectedBytes\[3\] !== 0x31' "$D/src/web-e2e.ts"
grep -q 'publicInfo.format !== "SBX"' "$D/src/web-e2e.ts"
! grep -q 'publicInfo.format !== "SBX1"' "$D/src/web-e2e.ts"
grep -q 'SAFEBOX_WEB_BROWSER_MAGIC_SBX1_PASS' "$D/src/web-e2e.ts"
grep -q 'SAFEBOX_WEB_BROWSER_PUBLIC_FORMAT_SBX_PASS' "$D/src/web-e2e.ts"
grep -q 'SAFEBOX_WEB_BROWSER_MAGIC_SBX1_PASS' "$D/scripts/web_browser_cdp_e2e.py"
grep -q 'SAFEBOX_WEB_BROWSER_PUBLIC_FORMAT_SBX_PASS' "$D/scripts/web_browser_cdp_e2e.py"

echo 'SAFEBOX_WEB_R80_PUBLIC_FORMAT_CONTRACT_PASS'

python3 "$D/scripts/web_production_check.py"
python3 "$D/scripts/web_foundation_check.py"
python3 "$D/scripts/desktop_cross_platform_audit.py"
"$ROOT/verification/verify_v027_ios_archive_passthrough_r39.sh"
"$ROOT/verification/verify_v027_ios_gma_link_scope_r41.sh"
"$ROOT/verification/verify_v027_ios_ads_runtime_session_r42.sh"

echo 'SAFEBOX_V028_WEB_BROWSER_PUBLIC_FORMAT_R80_VERIFY_PASS'
