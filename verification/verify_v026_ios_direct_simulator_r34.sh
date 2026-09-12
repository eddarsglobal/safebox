#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
D="$ROOT/safebox-desktop"
S="$D/scripts/ios_simulator_run.sh"
R="$ROOT/checkpoints/SAFEBOX_V026_IOS_DIRECT_SIMULATOR_R34_REPORT.md"

echo '[1/7] R31 Files/security boundary retained'
grep -F 'pickerMode: iosScoped ? "document" : undefined' "$D/src/main.ts" >/dev/null
grep -F 'stop_accessing_security_scoped_resource' "$D/src-tauri/src/lib.rs" >/dev/null
grep -F '<key>LSSupportsOpeningDocumentsInPlace</key>' "$D/src-tauri/Info.ios.plist" >/dev/null
echo 'SAFEBOX_IOS_SECURITY_FOUNDATION_RETAINED_R34_PASS'

echo '[2/7] direct iphonesimulator build — no Tauri archive'
grep -F 'xcodebuild \' "$S" >/dev/null
grep -F -- '-sdk iphonesimulator' "$S" >/dev/null
grep -F -- '-destination "id=$DEVICE_UDID"' "$S" >/dev/null
grep -F 'SAFEBOX_IOS_DIRECT_SIMULATOR_BUILD_PASS' "$S" >/dev/null
! grep -F 'ios build --debug' "$S" >/dev/null
! grep -F 'xcodebuild archive' "$S" >/dev/null
! grep -F -- '-sdk iphoneos' "$S" >/dev/null
echo 'SAFEBOX_IOS_DIRECT_SIMULATOR_BUILD_R34_PASS'

echo '[3/7] no Development Team/device-signing bypass in simulator tooling'
! grep -F 'DEVELOPMENT_TEAM=' "$S" >/dev/null
! grep -F 'APPLE_DEVELOPMENT_TEAM=' "$S" >/dev/null
! grep -F 'provisioningProfiles' "$S" >/dev/null
! grep -F 'exportArchive' "$S" >/dev/null
grep -F 'simctl install' "$S" >/dev/null
grep -F 'simctl launch' "$S" >/dev/null
echo 'SAFEBOX_IOS_SIMULATOR_SIGNING_BOUNDARY_R34_PASS'

echo '[4/7] Vite lifecycle + disposable DerivedData'
grep -F 'SAFEBOX_IOS_VITE_READY' "$S" >/dev/null
grep -F 'SAFEBOX_IOS_VITE_REUSED' "$S" >/dev/null
grep -F 'safebox-ios-r34-derived' "$S" >/dev/null
grep -F 'trap cleanup EXIT INT TERM' "$S" >/dev/null
echo 'SAFEBOX_IOS_DEV_RUNTIME_LIFECYCLE_R34_PASS'

echo '[5/7] architecture and Rust target gates'
grep -F "XCODE_SIM_ARCH='arm64-sim'" "$S" >/dev/null
grep -F "RUST_SIM_TARGET='aarch64-apple-ios-sim'" "$S" >/dev/null
grep -F "XCODE_SIM_ARCH='x86_64'" "$S" >/dev/null
grep -F "RUST_SIM_TARGET='x86_64-apple-ios'" "$S" >/dev/null
grep -F 'rustup target list --installed' "$S" >/dev/null
echo 'SAFEBOX_IOS_ARCH_TARGET_R34_PASS'

echo '[6/7] shell/package/report gate'
bash -n "$S"
bash -n "$D/scripts/ios_cold_dev.sh"
python3 - "$D/package.json" <<'PY'
import json,sys
p=json.load(open(sys.argv[1]))
assert p['scripts']['ios:cold-dev']=='bash scripts/ios_cold_dev.sh'
assert p['scripts']['ios:runtime-status']=='bash scripts/ios_runtime_status.sh'
PY
grep -F '## 9-council checkpoint review' "$R" >/dev/null
grep -F 'Defensive HACKER / Red Team' "$R" >/dev/null
echo 'SAFEBOX_IOS_COUNCIL_REDTEAM_R34_PASS'

echo '[7/7] checkpoint hygiene'
for bad in node_modules target .DS_Store; do
  if find "$ROOT" -name "$bad" -print -quit | grep -q .; then
    echo "R34 hygiene fail: packaged $bad" >&2
    exit 1
  fi
done
if [[ -d "$D/src-tauri/gen/apple" ]]; then
  echo 'R34 hygiene fail: generated Apple project must not be packaged' >&2
  exit 1
fi
echo 'SAFEBOX_IOS_CHECKPOINT_HYGIENE_R34_PASS'

echo 'IOS_V026_STATUS: DIRECT_SIMULATOR_RUNTIME_READY'
echo 'SAFEBOX_V026_IOS_DIRECT_SIMULATOR_R34_VERIFY_PASS'
