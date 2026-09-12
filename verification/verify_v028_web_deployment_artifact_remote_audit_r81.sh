#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
D="$ROOT/safebox-desktop"

[[ "$(cat "$ROOT/SAFEBOX_V028_PACKAGE_ID.txt")" == "v0.2.8-web-deployment-artifact-remote-audit-r81-20260831A" ]]
echo 'SAFEBOX_WEB_R81_PACKAGE_ID_PASS'

python3 -m py_compile \
  "$D/scripts/web_deployment_check.py" \
  "$D/scripts/web_deploy_bundle.py" \
  "$D/scripts/web_remote_audit.py" \
  "$D/scripts/web_browser_cdp_e2e.py" \
  "$D/scripts/web_production_check.py"
rm -rf "$D/scripts/__pycache__"
bash -n "$D/scripts/web_browser_e2e.sh"

python3 "$D/scripts/web_deployment_check.py"
python3 "$D/scripts/web_production_check.py"
python3 "$D/scripts/web_foundation_check.py"
python3 "$D/scripts/desktop_cross_platform_audit.py"
"$ROOT/verification/verify_v027_ios_archive_passthrough_r39.sh"
"$ROOT/verification/verify_v027_ios_gma_link_scope_r41.sh"
"$ROOT/verification/verify_v027_ios_ads_runtime_session_r42.sh"

# Source package hygiene: release outputs and build products must not ship in the source ZIP.
if find "$ROOT" -type d \( -name node_modules -o -name target -o -name dist -o -name release -o -name __pycache__ \) -print -quit | grep -q .; then
  echo 'SAFEBOX_R81_HYGIENE_FAIL: build/cache directory shipped'
  exit 1
fi
if find "$ROOT" -type f \( -name '*.pyc' -o -name '.DS_Store' -o -name '*.map' \) -print -quit | grep -q .; then
  echo 'SAFEBOX_R81_HYGIENE_FAIL: forbidden generated file shipped'
  exit 1
fi

echo 'SAFEBOX_R81_HYGIENE_PASS'
echo 'SAFEBOX_V028_WEB_DEPLOYMENT_ARTIFACT_REMOTE_AUDIT_R81_VERIFY_PASS'
