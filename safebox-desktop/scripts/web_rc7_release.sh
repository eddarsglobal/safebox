#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
D="$(cd "$SCRIPT_DIR/.." && pwd)"
ROOT="$(cd "$D/.." && pwd)"

bash "$ROOT/verification/verify_v029_web_rc7_light_legal_sync.sh"
cd "$D"
npm run web:release-gate

ZIP="$ROOT/release/safebox_v0.2.9_web_deploy_R86_RC7_LIGHT_LEGAL_SYNC.zip"
SHA="$ROOT/release/safebox_v0.2.9_web_deploy_R86_RC7_LIGHT_LEGAL_SYNC.sha256"
[[ -s "$ZIP" ]] || { echo 'SAFEBOX_WEB_RC7_RELEASE_FAIL: deploy ZIP missing' >&2; exit 1; }
[[ -s "$SHA" ]] || { echo 'SAFEBOX_WEB_RC7_RELEASE_FAIL: SHA manifest missing' >&2; exit 1; }

echo "SAFEBOX_WEB_RC7_DEPLOY_ZIP_READY: $ZIP"
cat "$SHA"
echo SAFEBOX_WEB_RC7_RELEASE_PASS
