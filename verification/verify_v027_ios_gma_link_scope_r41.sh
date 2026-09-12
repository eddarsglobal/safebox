#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PATCH="$ROOT/safebox-desktop/scripts/ios_scope_gma_objc_linker.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

SIM_PATH='$(PODS_ROOT)/Google-Mobile-Ads-SDK/Frameworks/GoogleMobileAdsFramework/GoogleMobileAds.xcframework/ios-arm64_x86_64-simulator/GoogleMobileAds.framework/GoogleMobileAds'
DEV_PATH='$(PODS_ROOT)/Google-Mobile-Ads-SDK/Frameworks/GoogleMobileAdsFramework/GoogleMobileAds.xcframework/ios-arm64/GoogleMobileAds.framework/GoogleMobileAds'
OLD_PATH='$(PODS_XCFRAMEWORKS_BUILD_DIR)/Google-Mobile-Ads-SDK/GoogleMobileAds.framework/GoogleMobileAds'

make_cfg(){
  cat > "$1" <<'EOF'
ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES = YES
OTHER_LDFLAGS = $(inherited) -ObjC -l"Google-Mobile-Ads-SDK" -lsqlite3 -lz -framework "AVFoundation" -framework "GoogleMobileAds" -framework "UserMessagingPlatform" -weak_framework "AdSupport"
PODS_ROOT = ${SRCROOT}/Pods
PODS_XCFRAMEWORKS_BUILD_DIR = $(PODS_CONFIGURATION_BUILD_DIR)/XCFrameworkIntermediates
EOF
}

DEBUG="$TMP/Pods-safebox-desktop_iOS.debug.xcconfig"
RELEASE="$TMP/Pods-safebox-desktop_iOS.release.xcconfig"
make_cfg "$DEBUG"
make_cfg "$RELEASE"
OUT="$(bash "$PATCH" "$DEBUG" "$RELEASE")"
grep -F 'SAFEBOX_IOS_GMA_LINK_SCOPE_FILE_PASS: Pods-safebox-desktop_iOS.debug.xcconfig' <<<"$OUT" >/dev/null
grep -F 'SAFEBOX_IOS_GMA_LINK_SCOPE_FILE_PASS: Pods-safebox-desktop_iOS.release.xcconfig' <<<"$OUT" >/dev/null
grep -F 'SAFEBOX_IOS_GMA_SOURCE_SLICE_SCOPE_PASS' <<<"$OUT" >/dev/null
grep -F 'SAFEBOX_IOS_GMA_OBJC_SCOPE_PATCH_PASS' <<<"$OUT" >/dev/null

for cfg in "$DEBUG" "$RELEASE"; do
  ! grep -Eq -- '(^|[[:space:]])-ObjC([[:space:]]|$)' "$cfg"
  grep -Fq -- 'SAFEBOX_GMA_FORCE_LOAD_BINARY[sdk=iphonesimulator*] = '"$SIM_PATH" "$cfg"
  grep -Fq -- 'SAFEBOX_GMA_FORCE_LOAD_BINARY[sdk=iphoneos*] = '"$DEV_PATH" "$cfg"
  grep -Fq -- '-Xlinker -force_load -Xlinker "$(SAFEBOX_GMA_FORCE_LOAD_BINARY)"' "$cfg"
  grep -Fq -- '-l"Google-Mobile-Ads-SDK"' "$cfg"
  grep -Fq -- '-framework "GoogleMobileAds"' "$cfg"
  grep -Fq -- '-framework "UserMessagingPlatform"' "$cfg"
  ! grep -Fq -- "$OLD_PATH" "$cfg"
done

# Idempotency: a second invocation must preserve exactly one pair of source
# slice definitions and the same scoped force-load.
cp "$DEBUG" "$TMP/debug.before"
OUT2="$(bash "$PATCH" "$DEBUG" "$RELEASE")"
grep -F 'SAFEBOX_IOS_GMA_SOURCE_SLICE_SCOPE_PASS' <<<"$OUT2" >/dev/null
cmp -s "$TMP/debug.before" "$DEBUG"
[[ "$(grep -Fc 'SAFEBOX_GMA_FORCE_LOAD_BINARY[sdk=iphonesimulator*] =' "$DEBUG")" == '1' ]]
[[ "$(grep -Fc 'SAFEBOX_GMA_FORCE_LOAD_BINARY[sdk=iphoneos*] =' "$DEBUG")" == '1' ]]

# Upgrade compatibility from an R40-generated aggregate xcconfig.
R40="$TMP/r40.xcconfig"
cat > "$R40" <<EOF
OTHER_LDFLAGS = \$(inherited) -Xlinker -force_load -Xlinker "$OLD_PATH" -l"Google-Mobile-Ads-SDK" -framework "GoogleMobileAds" -framework "UserMessagingPlatform"
PODS_ROOT = \${SRCROOT}/Pods
PODS_XCFRAMEWORKS_BUILD_DIR = \$(PODS_CONFIGURATION_BUILD_DIR)/XCFrameworkIntermediates
EOF
bash "$PATCH" "$R40" >/dev/null
! grep -Fq -- "$OLD_PATH" "$R40"
grep -Fq -- '$(SAFEBOX_GMA_FORCE_LOAD_BINARY)' "$R40"

# Fail closed if the config is unrelated to GMA.
BAD="$TMP/bad.xcconfig"
printf '%s\n' 'OTHER_LDFLAGS = $(inherited) -ObjC -framework "UIKit"' > "$BAD"
if bash "$PATCH" "$BAD" >/dev/null 2>&1; then
  echo 'SAFEBOX_IOS_GMA_SOURCE_SLICE_SCOPE_R41_FAIL: non-GMA xcconfig unexpectedly accepted' >&2
  exit 1
fi

echo 'SAFEBOX_IOS_GMA_SOURCE_SLICE_SCOPE_R41_PASS'
