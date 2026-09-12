#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PATCH="$ROOT/safebox-desktop/scripts/ios_scope_gma_objc_linker.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

make_cfg(){
  cat > "$1" <<'EOF'
ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES = YES
OTHER_LDFLAGS = $(inherited) -ObjC -l"Google-Mobile-Ads-SDK" -lsqlite3 -lz -framework "AVFoundation" -framework "GoogleMobileAds" -framework "UserMessagingPlatform" -weak_framework "AdSupport"
PODS_XCFRAMEWORKS_BUILD_DIR = $(PODS_CONFIGURATION_BUILD_DIR)/XCFrameworkIntermediates
EOF
}

DEBUG="$TMP/Pods-safebox-desktop_iOS.debug.xcconfig"
RELEASE="$TMP/Pods-safebox-desktop_iOS.release.xcconfig"
make_cfg "$DEBUG"
make_cfg "$RELEASE"
BEFORE_GMA="$(grep -o -- '-l"Google-Mobile-Ads-SDK"' "$DEBUG")"

OUT="$(bash "$PATCH" "$DEBUG" "$RELEASE")"
grep -F 'SAFEBOX_IOS_GMA_LINK_SCOPE_FILE_PASS: Pods-safebox-desktop_iOS.debug.xcconfig' <<<"$OUT" >/dev/null
grep -F 'SAFEBOX_IOS_GMA_LINK_SCOPE_FILE_PASS: Pods-safebox-desktop_iOS.release.xcconfig' <<<"$OUT" >/dev/null
grep -F 'SAFEBOX_IOS_GMA_OBJC_SCOPE_PATCH_PASS' <<<"$OUT" >/dev/null

for cfg in "$DEBUG" "$RELEASE"; do
  ! grep -Eq -- '(^|[[:space:]])-ObjC([[:space:]]|$)' "$cfg"
  grep -Fq -- '-Xlinker -force_load -Xlinker "$(PODS_XCFRAMEWORKS_BUILD_DIR)/Google-Mobile-Ads-SDK/GoogleMobileAds.framework/GoogleMobileAds"' "$cfg"
  grep -Fq -- '-l"Google-Mobile-Ads-SDK"' "$cfg"
  grep -Fq -- '-framework "GoogleMobileAds"' "$cfg"
  grep -Fq -- '-framework "UserMessagingPlatform"' "$cfg"
done
[[ "$BEFORE_GMA" == '-l"Google-Mobile-Ads-SDK"' ]]

# Idempotency: a second invocation must preserve the scoped state and pass.
OUT2="$(bash "$PATCH" "$DEBUG" "$RELEASE")"
grep -F 'SAFEBOX_IOS_GMA_OBJC_SCOPE_PATCH_PASS' <<<"$OUT2" >/dev/null

# Fail closed if the config is not actually a GMA user-target linker surface.
BAD="$TMP/bad.xcconfig"
printf '%s\n' 'OTHER_LDFLAGS = $(inherited) -ObjC -framework "UIKit"' > "$BAD"
if bash "$PATCH" "$BAD" >/dev/null 2>&1; then
  echo 'SAFEBOX_IOS_GMA_LINK_SCOPE_R40_FAIL: non-GMA xcconfig unexpectedly accepted' >&2
  exit 1
fi

echo 'SAFEBOX_IOS_GMA_LINK_SCOPE_R40_PASS'
