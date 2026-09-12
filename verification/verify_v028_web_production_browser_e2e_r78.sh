#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
D="$ROOT/safebox-desktop"
python3 "$D/scripts/web_production_check.py"
python3 "$D/scripts/web_foundation_check.py"
python3 "$D/scripts/desktop_cross_platform_audit.py"
"$ROOT/verification/verify_v027_ios_archive_passthrough_r39.sh"
"$ROOT/verification/verify_v027_ios_gma_link_scope_r41.sh"
"$ROOT/verification/verify_v027_ios_ads_runtime_session_r42.sh"
grep -qx 'v0.2.8-web-production-browser-e2e-r78-20260831A' "$ROOT/SAFEBOX_V028_PACKAGE_ID.txt"
echo "SAFEBOX_V028_WEB_PRODUCTION_BROWSER_E2E_R78_VERIFY_PASS"
