#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
D="$ROOT/safebox-desktop"
I="$D/scripts/install_ios_app_icon.sh"
S="$D/scripts/ios_simulator_run.sh"
B="$D/scripts/ios_xcode_rust_bridge.sh"
SRC="$ROOT/assets/safebox-app-icon-ios-1024.png"
R="$ROOT/checkpoints/SAFEBOX_V026_IOS_FINAL_REPORT.md"

echo '[1/6] proven R36 runtime bridge retained'
bash "$ROOT/verification/verify_v026_ios_bridge_argv_hardening_r36.sh"
echo 'SAFEBOX_IOS_PROVEN_RUNTIME_BASELINE_PASS'

echo '[2/6] official iOS icon source'
[[ -s "$SRC" ]]
python3 - "$SRC" <<'PY'
import struct, sys
p=sys.argv[1]
b=open(p,'rb').read(32)
assert b[:8] == b'\x89PNG\r\n\x1a\n'
w,h=struct.unpack('>II', b[16:24])
assert (w,h)==(1024,1024), (w,h)
# PNG color type byte: RGB=2, RGBA=6. Official iOS source must be RGB/no alpha.
assert b[25] == 2, f'expected RGB PNG color type 2, got {b[25]}'
PY
echo 'SAFEBOX_IOS_OFFICIAL_ICON_SOURCE_PASS'

echo '[3/6] AppIcon injection pipeline'
bash -n "$I"
grep -F 'Assets.xcassets/AppIcon.appiconset' "$I" >/dev/null
grep -F 'Contents.json' "$I" >/dev/null
grep -F 'SAFEBOX_IOS_APPICON_INSTALL_PASS' "$I" >/dev/null
grep -F 'sips -z' "$I" >/dev/null
grep -F 'hasAlpha' "$I" >/dev/null
grep -F 'install_ios_app_icon.sh' "$S" >/dev/null
echo 'SAFEBOX_IOS_APPICON_PIPELINE_PASS'

echo '[4/6] ABI validation uses real Xcode linker'
grep -F 'SAFEBOX_IOS_ABI_VALIDATION: XCODE_LINKER' "$B" >/dev/null
! grep -F "grep -q 'start_app'" "$B" >/dev/null
! grep -F "grep -F 'start_app'" "$B" >/dev/null
echo 'SAFEBOX_IOS_XCODE_LINKER_ABI_PASS'

echo '[5/6] security/product boundary'
grep -F 'SAFEBOX_IOS_STANDALONE_XCODE_SCRIPT=1' "$S" >/dev/null
grep -F "PLATFORM_NAME:-}" "$B" | grep -F 'iphonesimulator' >/dev/null
grep -F 'iPhoneSimulator.platform' "$B" >/dev/null
grep -F 'No SBX format or crypto change.' "$R" >/dev/null
grep -F '9-council' "$R" >/dev/null
grep -F 'Defensive HACKER / Red Team' "$R" >/dev/null
echo 'SAFEBOX_IOS_FINAL_SECURITY_BOUNDARY_PASS'

echo '[6/6] package hygiene'
for bad in node_modules target .DS_Store; do
  if find "$ROOT" -name "$bad" -print -quit | grep -q .; then
    echo "iOS final hygiene fail: packaged $bad" >&2
    exit 1
  fi
done
[[ ! -d "$D/src-tauri/gen/apple" ]] || { echo 'iOS final hygiene fail: generated Apple project packaged' >&2; exit 1; }
echo 'SAFEBOX_IOS_FINAL_HYGIENE_PASS'

echo 'IOS_V026_STATUS: FINAL_ICON_RUNTIME_BASELINE_READY'
echo 'SAFEBOX_V026_IOS_FINAL_VERIFY_PASS'
