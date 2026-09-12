#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TAURI_DIR="$APP_DIR/src-tauri"
APPLE_DIR="$TAURI_DIR/gen/apple"
CANONICAL_DIR="$TAURI_DIR/ios-share"
CANONICAL_BRIDGE="$TAURI_DIR/ios/SafeBoxShareInboxBridge.mm"
EXT_TARGET='SafeBoxShareExtension'
APP_GROUP='group.com.safebox.desktop.share'

[[ "$(uname -s)" == 'Darwin' ]] || { echo 'SAFEBOX_IOS_SHARE_INSTALL_FAIL: macOS required' >&2; exit 121; }
[[ -d "$APPLE_DIR" ]] || { echo 'SAFEBOX_IOS_SHARE_INSTALL_FAIL: generated Apple project missing' >&2; exit 122; }
[[ -f "$CANONICAL_DIR/ShareViewController.swift" && -f "$CANONICAL_DIR/Info.plist" && -f "$CANONICAL_DIR/SafeBoxShare.entitlements" ]] || { echo 'SAFEBOX_IOS_SHARE_INSTALL_FAIL: canonical extension sources missing' >&2; exit 123; }
[[ -f "$CANONICAL_BRIDGE" ]] || { echo 'SAFEBOX_IOS_SHARE_INSTALL_FAIL: canonical inbox bridge missing' >&2; exit 124; }
XCODEGEN_BIN="$(command -v xcodegen || true)"
[[ -n "$XCODEGEN_BIN" && -x "$XCODEGEN_BIN" ]] || { echo 'SAFEBOX_IOS_SHARE_INSTALL_FAIL: xcodegen unavailable' >&2; exit 125; }

echo 'SAFEBOX_IOS_SHARE_NO_RUBY_PROJECT_MUTATION_PASS'

# R46: build the Share Extension from a tiny standalone XcodeGen project.
# This intentionally avoids mutating Tauri's generated .pbxproj and avoids any
# dependency on Ruby/xcodeproj.  The resulting .appex is embedded after the
# already-validated containing-app build, then both signatures are checked.
GEN_EXT="$APPLE_DIR/$EXT_TARGET"
rm -rf "$GEN_EXT"
mkdir -p "$GEN_EXT"
cp "$CANONICAL_DIR/ShareViewController.swift" "$GEN_EXT/ShareViewController.swift"
cp "$CANONICAL_DIR/Info.plist" "$GEN_EXT/Info.plist"
cp "$CANONICAL_DIR/SafeBoxShare.entitlements" "$GEN_EXT/SafeBoxShare.entitlements"
chmod 600 "$GEN_EXT"/ShareViewController.swift "$GEN_EXT"/Info.plist "$GEN_EXT"/SafeBoxShare.entitlements

cat > "$GEN_EXT/project.yml" <<'YAML'
name: SafeBoxShareExtension
options:
  deploymentTarget:
    iOS: "14.0"
settings:
  base:
    SWIFT_VERSION: "5.0"
targets:
  SafeBoxShareExtension:
    type: app-extension
    platform: iOS
    deploymentTarget: "14.0"
    sources:
      - path: ShareViewController.swift
    settings:
      base:
        PRODUCT_BUNDLE_IDENTIFIER: com.safebox.desktop.share
        INFOPLIST_FILE: Info.plist
        GENERATE_INFOPLIST_FILE: NO
        PRODUCT_NAME: SafeBoxShareExtension
        CODE_SIGN_ENTITLEMENTS: SafeBoxShare.entitlements
        CODE_SIGN_STYLE: Automatic
        APPLICATION_EXTENSION_API_ONLY: YES
        SKIP_INSTALL: YES
        TARGETED_DEVICE_FAMILY: "1,2"
YAML
chmod 600 "$GEN_EXT/project.yml"
EXPECTED_SHARE_POINT='com.apple.share-services'
ACTUAL_CANONICAL_SHARE_POINT="$(/usr/libexec/PlistBuddy -c 'Print :NSExtension:NSExtensionPointIdentifier' "$GEN_EXT/Info.plist" 2>/dev/null || true)"
[[ "$ACTUAL_CANONICAL_SHARE_POINT" == "$EXPECTED_SHARE_POINT" ]] || { echo 'SAFEBOX_IOS_SHARE_INSTALL_FAIL: canonical Share Extension point mismatch' >&2; exit 126; }
PLIST_SHA_BEFORE="$(shasum -a 256 "$GEN_EXT/Info.plist" | awk '{print $1}')"
(
  cd "$GEN_EXT"
  "$XCODEGEN_BIN" generate --spec project.yml >/dev/null
)
[[ -d "$GEN_EXT/$EXT_TARGET.xcodeproj" ]] || { echo 'SAFEBOX_IOS_SHARE_INSTALL_FAIL: standalone Share Extension project generation failed' >&2; exit 127; }
PLIST_SHA_AFTER="$(shasum -a 256 "$GEN_EXT/Info.plist" | awk '{print $1}')"
[[ "$PLIST_SHA_BEFORE" == "$PLIST_SHA_AFTER" ]] || { echo 'SAFEBOX_IOS_SHARE_INSTALL_FAIL: xcodegen mutated static Share Extension Info.plist' >&2; exit 128; }
ACTUAL_POST_XCODEGEN_SHARE_POINT="$(/usr/libexec/PlistBuddy -c 'Print :NSExtension:NSExtensionPointIdentifier' "$GEN_EXT/Info.plist" 2>/dev/null || true)"
[[ "$ACTUAL_POST_XCODEGEN_SHARE_POINT" == "$EXPECTED_SHARE_POINT" ]] || { echo 'SAFEBOX_IOS_SHARE_INSTALL_FAIL: Share Extension point changed after xcodegen' >&2; exit 129; }
echo 'SAFEBOX_IOS_SHARE_INFO_PLIST_PRESERVED_PASS'
echo 'SAFEBOX_IOS_SHARE_STANDALONE_XCODEGEN_PROJECT_PASS'

# Prepare the containing-app App Group entitlement.  R46 applies it only at the
# simulator signing boundary after Xcode has produced the app, preserving all
# runtime-generated entitlements by merging rather than replacing them.
APP_ENT="$APPLE_DIR/safebox-desktop_iOS/SafeBoxAppGroups.entitlements"
mkdir -p "$(dirname "$APP_ENT")"
python3 - "$APP_ENT" "$APP_GROUP" <<'PY'
import plistlib, pathlib, sys
p=pathlib.Path(sys.argv[1]); group=sys.argv[2]
data={'com.apple.security.application-groups':[group]}
with p.open('wb') as f: plistlib.dump(data,f,sort_keys=False)
PY
chmod 600 "$APP_ENT"
echo 'SAFEBOX_IOS_SHARE_APP_GROUP_ENTITLEMENTS_PASS'
echo 'SAFEBOX_IOS_SHARE_MAIN_BUILD_ENTITLEMENTS_INPUT_PASS'

# Wire the containing app to the inbox bridge. R49 mirrors the validated Ads
# registration direction: native registers a drain callback into Rust before
# start_app(), while Rust owns setup/resume lifecycle timing.
MAIN_MM="$(find "$APPLE_DIR/Sources" -name main.mm -type f -print -quit 2>/dev/null || true)"
[[ -n "$MAIN_MM" && -f "$MAIN_MM" ]] || { echo 'SAFEBOX_IOS_SHARE_INSTALL_FAIL: generated main.mm missing' >&2; exit 127; }
INCLUDE_LINE='#include "../../../../ios/SafeBoxShareInboxBridge.mm"'
if ! grep -Fq "$INCLUDE_LINE" "$MAIN_MM"; then
  tmp="$MAIN_MM.safebox-share.$$"
  { printf '%s\n' "$INCLUDE_LINE"; cat "$MAIN_MM"; } > "$tmp"
  mv -f "$tmp" "$MAIN_MM"
fi
if ! grep -Fq 'SBXShareInboxRegisterNativeBridge();' "$MAIN_MM"; then
  python3 - "$MAIN_MM" <<'PY'
from pathlib import Path
import re,sys
p=Path(sys.argv[1]); s=p.read_text()
pat=re.compile(r'^(?P<i>[ \t]*)(?P<c>(?:ffi::)?start_app\(\);)[ \t]*$',re.M)
m=pat.search(s)
if not m: raise SystemExit('SAFEBOX_IOS_SHARE_INSTALL_FAIL: generated start_app call not found')
r=f"{m.group('i')}SBXShareInboxRegisterNativeBridge();\n{m.group('i')}{m.group('c')}"
p.write_text(s[:m.start()]+r+s[m.end():])
PY
fi
grep -Fq 'SBXShareInboxRegisterNativeBridge();' "$MAIN_MM" || { echo 'SAFEBOX_IOS_SHARE_INSTALL_FAIL: native inbox registration call missing' >&2; exit 128; }

grep -Fq 'safebox_ios_share_register' "$CANONICAL_BRIDGE" || { echo 'SAFEBOX_IOS_SHARE_INSTALL_FAIL: native-to-Rust share registration boundary missing' >&2; exit 130; }
echo 'SAFEBOX_IOS_SHARE_INBOX_NATIVE_REGISTRATION_PASS'
echo 'SAFEBOX_IOS_SHARE_INBOX_BRIDGE_PASS'
echo 'SAFEBOX_IOS_SHARE_EXTENSION_INSTALL_PASS'
