#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
D="$ROOT/safebox-desktop"
S="$D/scripts/ios_simulator_run.sh"
B="$D/scripts/ios_xcode_rust_bridge.sh"
T="$D/scripts/safebox_tauri.sh"
R="$ROOT/checkpoints/SAFEBOX_V026_IOS_STANDALONE_RUST_BRIDGE_R35_REPORT.md"

echo '[1/8] R34 direct Simulator build retained'
grep -F -- '-sdk iphonesimulator' "$S" >/dev/null
grep -F -- '-destination "id=$DEVICE_UDID"' "$S" >/dev/null
grep -F 'SAFEBOX_IOS_DIRECT_SIMULATOR_BUILD_PASS' "$S" >/dev/null
! grep -F 'xcodebuild archive' "$S" >/dev/null
! grep -F -- '-sdk iphoneos' "$S" >/dev/null
echo 'SAFEBOX_IOS_R34_DIRECT_BUILD_RETAINED_R35_PASS'

echo '[2/8] scoped standalone xcode-script interception'
grep -F 'SAFEBOX_IOS_STANDALONE_XCODE_SCRIPT=1' "$S" >/dev/null
grep -F '"${1:-}" = "ios"' "$T" >/dev/null
grep -F '"${2:-}" = "xcode-script"' "$T" >/dev/null
grep -F '"${SAFEBOX_IOS_STANDALONE_XCODE_SCRIPT:-0}" = "1"' "$T" >/dev/null
grep -F 'ios_xcode_rust_bridge.sh' "$T" >/dev/null
echo 'SAFEBOX_IOS_XCODE_SCRIPT_INTERCEPT_R35_PASS'

echo '[3/8] simulator-only defensive boundary'
grep -F "[[ \"$PLATFORM\" == 'iOS Simulator' ]]" "$B" >/dev/null || grep -F "== 'iOS Simulator'" "$B" >/dev/null
grep -F 'SAFEBOX_IOS_RUST_BRIDGE_REFUSED_PLATFORM' "$B" >/dev/null
! grep -F 'DEVELOPMENT_TEAM=' "$B" >/dev/null
! grep -F 'APPLE_DEVELOPMENT_TEAM=' "$B" >/dev/null
! grep -F 'IOS_CERTIFICATE' "$B" >/dev/null
echo 'SAFEBOX_IOS_SIMULATOR_ONLY_BRIDGE_R35_PASS'

echo '[4/8] Rust target + locked static library build'
grep -F "RUST_TARGET='x86_64-apple-ios'" "$B" >/dev/null
grep -F "RUST_TARGET='aarch64-apple-ios-sim'" "$B" >/dev/null
grep -F 'build --locked -p safebox-desktop --lib --target' "$B" >/dev/null
grep -F 'libsafebox_desktop_lib.a' "$B" >/dev/null
grep -F 'IPHONEOS_DEPLOYMENT_TARGET' "$B" >/dev/null
grep -F 'CFLAGS_VAR' "$B" >/dev/null
echo 'SAFEBOX_IOS_LOCKED_RUST_BUILD_R35_PASS'

echo '[5/8] Tauri Externals ABI/output contract'
grep -F 'Externals/$EXTERNAL_ARCH/$CONFIGURATION' "$B" >/dev/null
grep -F 'libapp.a' "$B" >/dev/null
grep -F 'SAFEBOX_IOS_ABI_VALIDATION: XCODE_LINKER' "$B" >/dev/null
grep -F 'shasum -a 256' "$B" >/dev/null
grep -F 'SAFEBOX_IOS_RUST_BRIDGE_PASS' "$B" >/dev/null
echo 'SAFEBOX_IOS_EXTERNALS_ABI_R35_PASS'

echo '[6/8] Apple-Silicon architecture correction'
grep -F "XCODE_SIM_ARCH='arm64'" "$S" >/dev/null
! grep -F "XCODE_SIM_ARCH='arm64-sim'" "$S" >/dev/null
grep -F "RUST_SIM_TARGET='aarch64-apple-ios-sim'" "$S" >/dev/null
echo 'SAFEBOX_IOS_XCODE_ARCH_R35_PASS'

echo '[7/8] shell + council/security gate'
bash -n "$B"
bash -n "$S"
bash -n "$T"
grep -F '## 9-council checkpoint review' "$R" >/dev/null
grep -F 'Defensive HACKER / Red Team' "$R" >/dev/null
grep -F 'No SBX format or crypto change.' "$R" >/dev/null
echo 'SAFEBOX_IOS_COUNCIL_REDTEAM_R35_PASS'

echo '[8/8] checkpoint hygiene'
for bad in node_modules target .DS_Store; do
  if find "$ROOT" -name "$bad" -print -quit | grep -q .; then
    echo "R35 hygiene fail: packaged $bad" >&2
    exit 1
  fi
done
if [[ -d "$D/src-tauri/gen/apple" ]]; then
  echo 'R35 hygiene fail: generated Apple project must not be packaged' >&2
  exit 1
fi
echo 'SAFEBOX_IOS_CHECKPOINT_HYGIENE_R35_PASS'

echo 'IOS_V026_STATUS: STANDALONE_RUST_BRIDGE_READY'
echo 'SAFEBOX_V026_IOS_STANDALONE_RUST_BRIDGE_R35_VERIFY_PASS'
