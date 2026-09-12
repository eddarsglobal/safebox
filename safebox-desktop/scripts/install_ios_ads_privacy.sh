#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TAURI_DIR="$APP_DIR/src-tauri"
APPLE_DIR="$TAURI_DIR/gen/apple"
CANONICAL_BRIDGE="$TAURI_DIR/ios/SafeBoxAdsBridge.mm"

[[ "$(uname -s)" == 'Darwin' ]] || { echo 'SAFEBOX_IOS_ADS_INSTALL_FAIL: macOS required' >&2; exit 91; }
command -v pod >/dev/null 2>&1 || { echo 'SAFEBOX_IOS_ADS_INSTALL_FAIL: CocoaPods missing' >&2; exit 92; }
[[ -f "$CANONICAL_BRIDGE" ]] || { echo 'SAFEBOX_IOS_ADS_INSTALL_FAIL: canonical ads bridge missing' >&2; exit 93; }

MAIN_MM="$(find "$APPLE_DIR/Sources" -name main.mm -type f -print -quit 2>/dev/null || true)"
[[ -n "$MAIN_MM" && -f "$MAIN_MM" ]] || { echo 'SAFEBOX_IOS_ADS_INSTALL_FAIL: generated main.mm missing; run tauri ios init first' >&2; exit 94; }

INCLUDE_LINE='#include "../../../../ios/SafeBoxAdsBridge.mm"'
if ! grep -Fq "$INCLUDE_LINE" "$MAIN_MM"; then
  tmp="$MAIN_MM.safebox.$$"
  { printf '%s\n' "$INCLUDE_LINE"; cat "$MAIN_MM"; } > "$tmp"
  mv -f "$tmp" "$MAIN_MM"
fi

# Register the native Ads callback table only after C/C++ runtime startup but
# before Tauri enters Rust. This avoids pre-main Rust calls and gives the linker
# a concrete native -> Rust reference to safebox_ios_ads_register.
if ! grep -Fq 'SBXAdsRegisterNativeBridge();' "$MAIN_MM"; then
  python3 - "$MAIN_MM" <<'PY_MAIN'
from pathlib import Path
import re, sys
p = Path(sys.argv[1])
s = p.read_text()
pat = re.compile(r'^(?P<indent>[ \t]*)(?P<call>(?:ffi::)?start_app\(\);)[ \t]*$', re.M)
m = pat.search(s)
if not m:
    raise SystemExit('SAFEBOX_IOS_ADS_INSTALL_FAIL: generated start_app call not found')
replacement = f"{m.group('indent')}SBXAdsRegisterNativeBridge();\n{m.group('indent')}{m.group('call')}"
p.write_text(s[:m.start()] + replacement + s[m.end():])
PY_MAIN
fi

grep -Fq 'SBXAdsRegisterNativeBridge();' "$MAIN_MM" || { echo 'SAFEBOX_IOS_ADS_INSTALL_FAIL: generated native registration call missing' >&2; exit 95; }
grep -Fq 'safebox_ios_ads_register' "$CANONICAL_BRIDGE" || { echo 'SAFEBOX_IOS_ADS_INSTALL_FAIL: native registration boundary missing' >&2; exit 95; }
grep -Fq 'SBXAdsRegisterNativeBridge' "$CANONICAL_BRIDGE" || { echo 'SAFEBOX_IOS_ADS_INSTALL_FAIL: native registration entry point missing' >&2; exit 95; }
grep -Fq 'UMPConsentInformation.sharedInstance.canRequestAds' "$CANONICAL_BRIDGE" || { echo 'SAFEBOX_IOS_ADS_INSTALL_FAIL: consent gate missing' >&2; exit 96; }

PODFILE="$APPLE_DIR/Podfile"
TARGET_NAME='safebox-desktop_iOS'

# Tauri/XcodeGen may leave a Podfile that references a desktop/macOS target
# even though this generated Apple project contains only the iOS target.
# SafeBox owns the iOS CocoaPods surface for this checkpoint, so regenerate a
# deterministic iOS-only Podfile every time instead of trying to mutate an
# unrelated/stale target list.
cat > "$PODFILE" <<'PODFILE_EOF'
platform :ios, '14.0'
project 'safebox-desktop.xcodeproj'

target 'safebox-desktop_iOS' do
  # SAFEBOX_IOS_ADS_BEGIN
  pod 'Google-Mobile-Ads-SDK', '13.3.0'
  pod 'GoogleUserMessagingPlatform', '3.1.0'
  # SAFEBOX_IOS_ADS_END
end
PODFILE_EOF

# Defensive check: the runtime Podfile must never reference the desktop target.
! grep -Fq 'safebox-desktop_macOS' "$PODFILE" || {
  echo 'SAFEBOX_IOS_ADS_INSTALL_FAIL: macOS target leaked into iOS Podfile' >&2
  exit 96
}
grep -Fq "target '$TARGET_NAME'" "$PODFILE" || {
  echo "SAFEBOX_IOS_ADS_INSTALL_FAIL: iOS target missing from Podfile: $TARGET_NAME" >&2
  exit 96
}
echo 'SAFEBOX_IOS_PODFILE_TARGET_PASS: safebox-desktop_iOS'

GENERATED_INFO="$(find "$APPLE_DIR" -path '*_iOS/Info.plist' -type f -print -quit 2>/dev/null || true)"
[[ -n "$GENERATED_INFO" && -f "$GENERATED_INFO" ]] || { echo 'SAFEBOX_IOS_ADS_INSTALL_FAIL: generated Info.plist missing' >&2; exit 97; }
APP_ID="${SAFEBOX_ADMOB_IOS_APP_ID:-ca-app-pub-3940256099942544~1458002511}"
/usr/libexec/PlistBuddy -c 'Delete :GADApplicationIdentifier' "$GENERATED_INFO" >/dev/null 2>&1 || true
/usr/libexec/PlistBuddy -c "Add :GADApplicationIdentifier string $APP_ID" "$GENERATED_INFO"
/usr/libexec/PlistBuddy -c 'Delete :NSUserTrackingUsageDescription' "$GENERATED_INFO" >/dev/null 2>&1 || true
/usr/libexec/PlistBuddy -c 'Add :NSUserTrackingUsageDescription string SafeBox uses this permission only when required for advertising privacy choices.' "$GENERATED_INFO"
/usr/libexec/PlistBuddy -c 'Delete :SKAdNetworkItems' "$GENERATED_INFO" >/dev/null 2>&1 || true
/usr/libexec/PlistBuddy -c 'Add :SKAdNetworkItems array' "$GENERATED_INFO"
/usr/libexec/PlistBuddy -c 'Add :SKAdNetworkItems:0 dict' "$GENERATED_INFO"
/usr/libexec/PlistBuddy -c 'Add :SKAdNetworkItems:0:SKAdNetworkIdentifier string cstr6suwn9.skadnetwork' "$GENERATED_INFO"

if [[ "$APP_ID" == 'ca-app-pub-3940256099942544~1458002511' ]]; then
  echo 'SAFEBOX_IOS_ADMOB_MODE: TEST'
else
  echo 'SAFEBOX_IOS_ADMOB_MODE: CUSTOM_APP_ID_TEST_BANNER'
fi

POD_HASH="$(shasum -a 256 "$PODFILE" | awk '{print $1}')"
STAMP="$APPLE_DIR/.safebox-ios-ads-podfile.sha256"
NEED_PODS=1
if [[ -f "$STAMP" && -f "$APPLE_DIR/Podfile.lock" && -d "$APPLE_DIR/Pods" ]] && [[ "$(cat "$STAMP")" == "$POD_HASH" ]]; then
  NEED_PODS=0
fi
if [[ "$NEED_PODS" == '1' ]]; then
  echo 'SafeBox iOS Ads: installing pinned Google SDKs'
  if ! (cd "$APPLE_DIR" && pod install --silent); then
    echo 'SafeBox iOS Ads: refreshing CocoaPods specs once'
    (cd "$APPLE_DIR" && pod install --repo-update --silent)
  fi
  printf '%s\n' "$POD_HASH" > "$STAMP"
else
  echo 'SAFEBOX_IOS_ADS_PODS_REUSED'
fi

grep -Fq 'Google-Mobile-Ads-SDK (13.3.0)' "$APPLE_DIR/Podfile.lock" || { echo 'SAFEBOX_IOS_ADS_INSTALL_FAIL: Google Mobile Ads 13.3.0 not locked' >&2; exit 98; }
grep -Fq 'GoogleUserMessagingPlatform (3.1.0)' "$APPLE_DIR/Podfile.lock" || { echo 'SAFEBOX_IOS_ADS_INSTALL_FAIL: UMP 3.1.0 not locked' >&2; exit 99; }

# Google-Mobile-Ads-SDK 13.3.0 injects a global -ObjC into the user target.
# R39 proved that applying it globally forces both repeated Tauri Swift support
# sets out of libapp.a. R41 therefore keeps libapp.a untouched and scopes the
# load-all behavior to Google's *source* XCFramework slice. The source slice is
# already present under Pods before Xcode plans the build; unlike R40's
# XCFrameworkIntermediates path, it is not a generated product of this build.
GMA_XCROOT="$APPLE_DIR/Pods/Google-Mobile-Ads-SDK/Frameworks/GoogleMobileAdsFramework/GoogleMobileAds.xcframework"
GMA_SIM_SOURCE="$GMA_XCROOT/ios-arm64_x86_64-simulator/GoogleMobileAds.framework/GoogleMobileAds"
GMA_DEVICE_SOURCE="$GMA_XCROOT/ios-arm64/GoogleMobileAds.framework/GoogleMobileAds"
[[ -f "$GMA_SIM_SOURCE" ]] || { echo "SAFEBOX_IOS_ADS_INSTALL_FAIL: GMA simulator source slice missing: $GMA_SIM_SOURCE" >&2; exit 99; }
[[ -f "$GMA_DEVICE_SOURCE" ]] || { echo "SAFEBOX_IOS_ADS_INSTALL_FAIL: GMA device source slice missing: $GMA_DEVICE_SOURCE" >&2; exit 99; }
echo 'SAFEBOX_IOS_GMA_SOURCE_SIM_EXISTS_PASS'
echo 'SAFEBOX_IOS_GMA_SOURCE_DEVICE_EXISTS_PASS'
echo 'SAFEBOX_IOS_GMA_SOURCE_SLICE_PRECHECK_PASS'

GMA_SUPPORT_DIR="$APPLE_DIR/Pods/Target Support Files/Pods-$TARGET_NAME"
GMA_XCCONFIGS=(
  "$GMA_SUPPORT_DIR/Pods-$TARGET_NAME.debug.xcconfig"
  "$GMA_SUPPORT_DIR/Pods-$TARGET_NAME.release.xcconfig"
)
bash "$SCRIPT_DIR/ios_scope_gma_objc_linker.sh" "${GMA_XCCONFIGS[@]}"
for cfg in "${GMA_XCCONFIGS[@]}"; do
  if grep -Eq -- '(^|[[:space:]])-ObjC([[:space:]]|$)' "$cfg"; then
    echo "SAFEBOX_IOS_ADS_INSTALL_FAIL: global -ObjC survived in $cfg" >&2
    exit 99
  fi
  grep -Fq -- '-force_load' "$cfg" || { echo "SAFEBOX_IOS_ADS_INSTALL_FAIL: targeted force_load missing in $cfg" >&2; exit 99; }
  grep -Fq -- '$(SAFEBOX_GMA_FORCE_LOAD_BINARY)' "$cfg" || { echo "SAFEBOX_IOS_ADS_INSTALL_FAIL: source-slice force_load variable missing in $cfg" >&2; exit 99; }
  grep -Fq -- '$(PODS_ROOT)/Google-Mobile-Ads-SDK/Frameworks/GoogleMobileAdsFramework/GoogleMobileAds.xcframework/ios-arm64_x86_64-simulator/GoogleMobileAds.framework/GoogleMobileAds' "$cfg" || { echo "SAFEBOX_IOS_ADS_INSTALL_FAIL: simulator GMA source slice missing in $cfg" >&2; exit 99; }
  grep -Fq -- '$(PODS_ROOT)/Google-Mobile-Ads-SDK/Frameworks/GoogleMobileAdsFramework/GoogleMobileAds.xcframework/ios-arm64/GoogleMobileAds.framework/GoogleMobileAds' "$cfg" || { echo "SAFEBOX_IOS_ADS_INSTALL_FAIL: device GMA source slice missing in $cfg" >&2; exit 99; }
  ! grep -Fq -- '$(PODS_XCFRAMEWORKS_BUILD_DIR)/Google-Mobile-Ads-SDK/GoogleMobileAds.framework/GoogleMobileAds' "$cfg" || { echo "SAFEBOX_IOS_ADS_INSTALL_FAIL: obsolete generated GMA force_load path survived in $cfg" >&2; exit 99; }
done
echo 'SAFEBOX_IOS_GLOBAL_OBJC_LINK_FLAG_REMOVED_PASS'
echo 'SAFEBOX_IOS_GMA_SOURCE_SLICE_SCOPE_PASS'
echo 'SAFEBOX_IOS_GMA_TARGETED_FORCE_LOAD_PASS'

WORKSPACE="$(find "$APPLE_DIR" -maxdepth 1 -name '*.xcworkspace' -type d -print -quit 2>/dev/null || true)"
[[ -n "$WORKSPACE" ]] || { echo 'SAFEBOX_IOS_ADS_INSTALL_FAIL: CocoaPods workspace missing' >&2; exit 100; }

echo 'SAFEBOX_IOS_ADS_MAIN_BRIDGE_PASS'
echo 'SAFEBOX_IOS_ADS_PRIVACY_PLIST_PASS'
echo 'SAFEBOX_IOS_ADS_PODS_PASS: GMA=13.3.0 UMP=3.1.0'
echo "SAFEBOX_IOS_ADS_WORKSPACE: $WORKSPACE"
echo 'SAFEBOX_IOS_ADS_INSTALL_PASS'
