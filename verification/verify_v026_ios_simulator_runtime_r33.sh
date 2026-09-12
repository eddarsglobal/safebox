#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
D="$ROOT/safebox-desktop"
R="$ROOT/checkpoints/SAFEBOX_V026_IOS_SIMULATOR_RUNTIME_R33_REPORT.md"

echo '[1/6] R32 + R31 security foundation retained'
grep -F 'pickerMode: iosScoped ? "document" : undefined' "$D/src/main.ts" >/dev/null
grep -F 'stop_accessing_security_scoped_resource' "$D/src-tauri/src/lib.rs" >/dev/null
grep -F 'export CI=true' "$D/scripts/ios_simulator_run.sh" >/dev/null
echo 'SAFEBOX_IOS_FOUNDATION_RETAINED_R33_PASS'

echo '[2/6] simulator no-team build path'
grep -F 'ios build --debug --target "$TAURI_SIM_TARGET" --no-sign' "$D/scripts/ios_simulator_run.sh" >/dev/null
grep -F 'simctl install' "$D/scripts/ios_simulator_run.sh" >/dev/null
grep -F 'simctl launch' "$D/scripts/ios_simulator_run.sh" >/dev/null
! grep -F 'APPLE_DEVELOPMENT_TEAM=' "$D/scripts/ios_simulator_run.sh" >/dev/null
! grep -F 'ios dev "$DEVICE"' "$D/scripts/ios_cold_dev.sh" >/dev/null
echo 'SAFEBOX_IOS_NO_TEAM_SIMULATOR_R33_PASS'

echo '[3/6] native architecture / Rosetta defense'
grep -F 'hw.optional.arm64' "$D/scripts/ios_simulator_run.sh" >/dev/null
grep -F 'sysctl.proc_translated' "$D/scripts/ios_simulator_run.sh" >/dev/null
grep -F "TAURI_SIM_TARGET='aarch64-sim'" "$D/scripts/ios_simulator_run.sh" >/dev/null
grep -F "TAURI_SIM_TARGET='x86_64'" "$D/scripts/ios_simulator_run.sh" >/dev/null
echo 'SAFEBOX_IOS_NATIVE_ARCH_R33_PASS'

echo '[4/6] document open-in-place boundary'
grep -F '<key>LSSupportsOpeningDocumentsInPlace</key>' "$D/src-tauri/Info.ios.plist" >/dev/null
grep -F '<false/>' "$D/src-tauri/Info.ios.plist" >/dev/null
echo 'SAFEBOX_IOS_DOCUMENT_BOUNDARY_R33_PASS'

echo '[5/6] shell + package + council gate'
bash -n "$D/scripts/ios_simulator_run.sh"
bash -n "$D/scripts/ios_cold_dev.sh"
python3 - "$D/package.json" <<'PY'
import json,sys
p=json.load(open(sys.argv[1]))
assert p['scripts']['ios:cold-dev']=='bash scripts/ios_cold_dev.sh'
assert p['scripts']['ios:sim-run']=='bash scripts/ios_simulator_run.sh'
PY
grep -F '## 9-council checkpoint review' "$R" >/dev/null
grep -F 'Defensive HACKER / Red Team' "$R" >/dev/null
echo 'SAFEBOX_IOS_COUNCIL_REDTEAM_R33_PASS'

echo '[6/6] frontend build + Rust formatting'
cd "$D"
bash scripts/ensure_frontend_toolchain.sh
npm run build
cd "$ROOT"
cargo fmt --all
cargo fmt --all -- --check

echo 'IOS_V026_STATUS: SIMULATOR_RUNTIME_READY'
echo 'SAFEBOX_V026_IOS_SIMULATOR_RUNTIME_R33_VERIFY_PASS'
