#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/safebox-desktop"
INSTALL="$APP/scripts/install_ios_share_extension.sh"
SIM="$APP/scripts/ios_simulator_run.sh"
INFO="$APP/src-tauri/ios-share/Info.plist"
fail(){ echo "SAFEBOX_V028_IOS_SHARE_R48_FAIL: $*" >&2; exit 1; }

printf '%s\n' '[1/8] package + R42 baseline retained'
grep -Eq 'SAFEBOX_V028_PACKAGE_ID=v0\.2\.8-ios-native-share-extension-r(48-20260829F|49-20260830A|50-20260830B)' "$ROOT/SAFEBOX_V028_PACKAGE_ID.txt" || fail 'package id mismatch'
SAFEBOX_VERIFY_SKIP_TOOLCHAIN=1 bash "$ROOT/verification/verify_v027_ios_ads_privacy.sh" >/dev/null
printf '%s\n' 'SAFEBOX_V028_R42_BASELINE_RETAINED_PASS'

printf '%s\n' '[2/8] validated Ads/linker surfaces unchanged'
check_sha(){ [[ "$(shasum -a 256 "$1" | awk '{print $1}')" == "$2" ]] || fail "validated R42 surface changed: $1"; }
check_sha "$APP/src-tauri/ios/SafeBoxAdsBridge.mm" a408b55ec036ee71894853c144fc753e7a181eeaca7b5ae6872ec636dfc5e2ea
check_sha "$APP/scripts/install_ios_ads_privacy.sh" f40244c11573e0364f8f064a1e180ea5896f61be8a06a550e18803dedc5c3653
check_sha "$APP/scripts/ios_scope_gma_objc_linker.sh" a31b61bbe5b9cc6f6c1da35b5cb175c2fbb49f5550d62b2686baecf225ea8e2c
check_sha "$APP/scripts/ios_ads_runtime_check.sh" 84f13e2f64caa28d736876353a80082d2ad0444b9158a34f4fa7896c0a15ffd3
check_sha "$APP/scripts/ios_xcode_rust_bridge.sh" 1ecd769313f834129fcc57fecc49a2847db5f373ca9e4b74fa3c17614d0562e9
printf '%s\n' 'SAFEBOX_IOS_VALIDATED_R42_RUNTIME_SURFACE_UNCHANGED_PASS'

printf '%s\n' '[3/8] canonical Share bundle contract'
python3 - "$INFO" <<'PY'
import plistlib,sys
with open(sys.argv[1],'rb') as f: p=plistlib.load(f)
expected={
 'CFBundleIdentifier':'$(PRODUCT_BUNDLE_IDENTIFIER)',
 'CFBundleExecutable':'$(EXECUTABLE_NAME)',
 'CFBundlePackageType':'XPC!',
 'CFBundleInfoDictionaryVersion':'6.0',
 'CFBundleShortVersionString':'0.2.8',
 'CFBundleVersion':'28',
}
for k,v in expected.items():
    assert p.get(k)==v,(k,p.get(k),v)
assert p['NSExtension']['NSExtensionPointIdentifier']=='com.apple.share-services'
PY
printf '%s\n' 'SAFEBOX_IOS_SHARE_CANONICAL_BUNDLE_CONTRACT_R48_PASS'

printf '%s\n' '[4/8] immutable static plist retained'
bash -n "$INSTALL"
! grep -Eq '^[[:space:]]+info:[[:space:]]*$' "$INSTALL" || fail 'xcodegen info generation block survived'
for token in 'INFOPLIST_FILE: Info.plist' 'GENERATE_INFOPLIST_FILE: NO' 'PLIST_SHA_BEFORE=' 'PLIST_SHA_AFTER=' 'SAFEBOX_IOS_SHARE_INFO_PLIST_PRESERVED_PASS'; do
  grep -Fq "$token" "$INSTALL" || fail "immutable plist token missing: $token"
done
printf '%s\n' 'SAFEBOX_IOS_SHARE_STATIC_PLIST_R48_PASS'

printf '%s\n' '[5/8] compiled appex identity gate'
bash -n "$SIM"
for token in 'ACTUAL_SHARE_BUNDLE_ID=' 'ACTUAL_SHARE_EXECUTABLE=' 'ACTUAL_SHARE_PACKAGE_TYPE=' 'ACTUAL_SHARE_VERSION=' 'SAFEBOX_IOS_SHARE_EXTENSION_BUNDLE_ID_PASS' 'SAFEBOX_IOS_SHARE_EXTENSION_EXECUTABLE_PASS' 'SAFEBOX_IOS_SHARE_EXTENSION_PACKAGE_TYPE_PASS' 'SAFEBOX_IOS_SHARE_EXTENSION_VERSION_PASS' 'SAFEBOX_IOS_SHARE_EXTENSION_BUNDLE_CONTRACT_PASS'; do
  grep -Fq "$token" "$SIM" || fail "compiled bundle identity token missing: $token"
done
printf '%s\n' 'SAFEBOX_IOS_SHARE_COMPILED_BUNDLE_GATE_R48_PASS'

printf '%s\n' '[6/8] R47 extension-point + R46 App Group architecture retained'
for token in 'SAFEBOX_IOS_SHARE_EXTENSION_POINT_PASS' 'SAFEBOX_IOS_SHARE_APP_GROUP_RUNTIME_ENTITLEMENTS_PASS' 'SAFEBOX_IOS_SHARE_EXTENSION_EMBED_PASS'; do
  grep -Fq "$token" "$SIM" || fail "retained runtime token missing: $token"
done
for token in 'SAFEBOX_IOS_SHARE_NO_RUBY_PROJECT_MUTATION_PASS' 'SAFEBOX_IOS_SHARE_STANDALONE_XCODEGEN_PROJECT_PASS' 'SAFEBOX_IOS_SHARE_APP_GROUP_ENTITLEMENTS_PASS' 'SAFEBOX_IOS_SHARE_INBOX_BRIDGE_PASS'; do
  grep -Fq "$token" "$INSTALL" || fail "retained install token missing: $token"
done
printf '%s\n' 'SAFEBOX_IOS_SHARE_R47_R46_ARCHITECTURE_RETAINED_PASS'

printf '%s\n' '[7/8] runtime checker retained'
bash -n "$APP/scripts/ios_share_extension_check.sh"
grep -Fq 'SAFEBOX_IOS_SHARE_RUNTIME_PASS' "$APP/scripts/ios_share_extension_check.sh" || fail 'share runtime final marker missing'
printf '%s\n' 'SAFEBOX_IOS_SHARE_RUNTIME_CHECKER_R48_PASS'

printf '%s\n' '[8/8] hygiene + report'
[[ -s "$ROOT/checkpoints/SAFEBOX_V028_IOS_NATIVE_SHARE_EXTENSION_R48_REPORT.md" ]] || fail 'R48 report missing'
for bad in node_modules target .DS_Store; do
  if find "$ROOT" -name "$bad" -print -quit | grep -q .; then fail "packaged build artifact: $bad"; fi
done
[[ ! -d "$APP/src-tauri/gen/apple" ]] || fail 'generated Apple project packaged'
printf '%s\n' 'SAFEBOX_IOS_SHARE_HYGIENE_R48_PASS'
printf '%s\n' 'IOS_V028_STATUS: NATIVE_SHARE_EXTENSION_R48_READY_FOR_RUNTIME_TEST'
printf '%s\n' 'SAFEBOX_V028_IOS_NATIVE_SHARE_EXTENSION_R48_VERIFY_PASS'
