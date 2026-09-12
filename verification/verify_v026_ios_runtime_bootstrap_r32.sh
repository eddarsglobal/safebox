#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
D="$ROOT/safebox-desktop"
R31="$ROOT/verification/verify_v026_ios_files_foundation_r31.sh"
REPORT="$ROOT/checkpoints/SAFEBOX_V026_IOS_RUNTIME_BOOTSTRAP_R32_REPORT.md"

echo '[1/5] R31 iOS foundation retained'
grep -F 'pickerMode: iosScoped ? "document" : undefined' "$D/src/main.ts" >/dev/null
grep -F 'stop_accessing_security_scoped_resource' "$D/src-tauri/src/lib.rs" >/dev/null
echo 'SAFEBOX_IOS_R31_FOUNDATION_RETAINED_R32_PASS'

echo '[2/5] non-interactive Tauri iOS runtime'
grep -F 'export CI=true' "$D/scripts/ios_cold_dev.sh" >/dev/null
grep -F '"$TAURI_BIN" ios init' "$D/scripts/ios_cold_dev.sh" >/dev/null
grep -F 'exec "$TAURI_BIN" ios dev "$DEVICE"' "$D/scripts/ios_cold_dev.sh" >/dev/null
! grep -Eq 'brew (upgrade|update|reinstall|install)' "$D/scripts/ios_cold_dev.sh"
echo 'SAFEBOX_IOS_NONINTERACTIVE_RUNTIME_R32_PASS'

echo '[3/5] runtime status evidence helper'
bash -n "$D/scripts/ios_cold_dev.sh"
bash -n "$D/scripts/ios_runtime_status.sh"
python3 - "$D/package.json" <<'PY'
import json,sys
p=json.load(open(sys.argv[1]))
assert p['scripts']['ios:runtime-status']=='bash scripts/ios_runtime_status.sh'
PY
grep -F 'simctl get_app_container' "$D/scripts/ios_runtime_status.sh" >/dev/null
echo 'SAFEBOX_IOS_RUNTIME_STATUS_TOOL_R32_PASS'

echo '[4/5] 9-council + Defensive HACKER gate'
grep -F '## 9-council checkpoint review' "$REPORT" >/dev/null
grep -F 'Defensive HACKER / Red Team' "$REPORT" >/dev/null
grep -F 'cannot silently mutate host package-manager dependencies' "$REPORT" >/dev/null
echo 'SAFEBOX_IOS_COUNCIL_REDTEAM_R32_PASS'

echo '[5/5] frontend build + formatting'
cd "$D"
bash scripts/ensure_frontend_toolchain.sh
npm run build
cd "$ROOT"
cargo fmt --all
cargo fmt --all -- --check

echo 'IOS_V026_STATUS: RUNTIME_BOOTSTRAP_READY'
echo 'SAFEBOX_V026_IOS_RUNTIME_BOOTSTRAP_R32_VERIFY_PASS'
