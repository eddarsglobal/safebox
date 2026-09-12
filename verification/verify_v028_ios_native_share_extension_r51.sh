#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/safebox-desktop"
LIB="$APP/src-tauri/src/lib.rs"
BRIDGE="$APP/src-tauri/ios/SafeBoxShareInboxBridge.mm"
INSTALL="$APP/scripts/install_ios_share_extension.sh"
CHECK="$APP/scripts/ios_share_extension_check.sh"
SIM="$APP/scripts/ios_simulator_run.sh"
fail(){ echo "SAFEBOX_V028_IOS_SHARE_R51_FAIL: $*" >&2; exit 1; }

printf '%s\n' '[1/9] package + R48/R49/R50 architecture retained'
grep -Fq 'SAFEBOX_V028_PACKAGE_ID=v0.2.8-ios-native-share-extension-r51-20260830A' "$ROOT/SAFEBOX_V028_PACKAGE_ID.txt" || fail 'package id mismatch'
for token in \
  'SAFEBOX_IOS_SHARE_EXTENSION_BUNDLE_CONTRACT_PASS' \
  'SAFEBOX_IOS_SHARE_EXTENSION_EMBED_PASS'; do
  grep -Fq "$token" "$SIM" || fail "R48 architecture token missing: $token"
done
for token in \
  'safebox_ios_share_register(SBXDrainShareInboxNow)' \
  'SAFEBOX_IOS_SHARE_INBOX_NATIVE_REGISTER_PASS'; do
  grep -Fq "$token" "$BRIDGE" || fail "R49 native lifecycle token missing: $token"
done
for token in \
  'drain_ios_share_inbox("setup")' \
  'tauri::RunEvent::Resumed' \
  'drain_ios_share_inbox("resumed")'; do
  grep -Fq "$token" "$LIB" || fail "R49 Rust lifecycle token missing: $token"
done
printf '%s\n' 'SAFEBOX_V028_R49_LIFECYCLE_ARCHITECTURE_RETAINED_PASS'

printf '%s\n' '[2/9] validated Ads/linker surfaces unchanged'
check_sha(){ [[ "$(shasum -a 256 "$1" | awk '{print $1}')" == "$2" ]] || fail "validated R42 surface changed: $1"; }
check_sha "$APP/src-tauri/ios/SafeBoxAdsBridge.mm" a408b55ec036ee71894853c144fc753e7a181eeaca7b5ae6872ec636dfc5e2ea
check_sha "$APP/scripts/install_ios_ads_privacy.sh" f40244c11573e0364f8f064a1e180ea5896f61be8a06a550e18803dedc5c3653
check_sha "$APP/scripts/ios_scope_gma_objc_linker.sh" a31b61bbe5b9cc6f6c1da35b5cb175c2fbb49f5550d62b2686baecf225ea8e2c
check_sha "$APP/scripts/ios_ads_runtime_check.sh" 84f13e2f64caa28d736876353a80082d2ad0444b9158a34f4fa7896c0a15ffd3
check_sha "$APP/scripts/ios_xcode_rust_bridge.sh" 1ecd769313f834129fcc57fecc49a2847db5f373ca9e4b74fa3c17614d0562e9
printf '%s\n' 'SAFEBOX_IOS_VALIDATED_R42_RUNTIME_SURFACE_UNCHANGED_PASS'

printf '%s\n' '[3/9] Xcode main build still consumes deterministic App Group source'
bash -n "$INSTALL"
bash -n "$SIM"
for token in \
  'APP_ENT="$APPLE_DIR/safebox-desktop_iOS/SafeBoxAppGroups.entitlements"' \
  '"CODE_SIGN_ENTITLEMENTS=$APP_ENT"' \
  'SAFEBOX_IOS_SHARE_MAIN_BUILD_ENTITLEMENTS_INPUT_PASS'; do
  grep -Fq "$token" "$SIM" "$INSTALL" || fail "R50 build entitlement source missing: $token"
done
printf '%s\n' 'SAFEBOX_IOS_SHARE_MAIN_XCODE_ENTITLEMENT_INJECTION_R51_PASS'

printf '%s\n' '[4/9] simulator capability proof uses Simulated.xcent, not outer codesign metadata'
for token in \
  "-name 'SafeBox.app-Simulated.xcent'" \
  'containing-app Simulated.xcent missing App Group' \
  'SAFEBOX_IOS_SHARE_MAIN_SIMULATED_XCENT_PASS' \
  'SAFEBOX_IOS_SHARE_MAIN_EXECUTABLE_EMBEDDED_APP_GROUP_PASS'; do
  grep -Fq -- "$token" "$SIM" || fail "simulated entitlement proof missing: $token"
done
if grep -Fq 'containing app missing build-time App Group entitlement' "$SIM"; then fail 'obsolete R50 codesign proof retained'; fi
printf '%s\n' 'SAFEBOX_IOS_SHARE_SIMULATED_XCENT_AUTHORITY_R51_PASS'

printf '%s\n' '[5/9] extension simulator capability remains embedded and Xcode-signed'
for token in \
  'SAFEBOX_IOS_SHARE_EXTENSION_SIMULATED_APP_GROUP_PASS' \
  '/usr/bin/codesign --verify --strict "$SHARE_APPEX"'; do
  grep -Fq "$token" "$SIM" || fail "extension simulator entitlement/signature proof missing: $token"
done
printf '%s\n' 'SAFEBOX_IOS_SHARE_EXTENSION_XCODE_SIGNATURE_PRESERVED_R51_PASS'

printf '%s\n' '[6/9] containing app outer re-sign uses Xcode sign xcent and preserves embedded capability'
for token in \
  "-name 'SafeBox.app.xcent'" \
  '--entitlements "$MAIN_SIGN_XCENT" "$APP_PATH"' \
  'SAFEBOX_IOS_SHARE_MAIN_FINAL_EMBEDDED_APP_GROUP_PASS' \
  'SAFEBOX_IOS_SHARE_APP_GROUP_RUNTIME_ENTITLEMENTS_PASS'; do
  grep -Fq -- "$token" "$SIM" || fail "final containing-app signing proof missing: $token"
done
if grep -Fq 'merge_app_group_and_resign' "$SIM"; then fail 'obsolete post-build entitlement mutation retained'; fi
printf '%s\n' 'SAFEBOX_IOS_SHARE_FINAL_SIGNING_MODEL_R51_PASS'

printf '%s\n' '[7/9] App Group identity remains exact'
grep -Fq "APP_GROUP='group.com.safebox.desktop.share'" "$INSTALL" || fail 'install App Group changed'
grep -Fq 'group.com.safebox.desktop.share' "$BRIDGE" || fail 'bridge App Group changed'
grep -Fq 'PRODUCT_BUNDLE_IDENTIFIER: com.safebox.desktop.share' "$INSTALL" || fail 'extension bundle id changed'
printf '%s\n' 'SAFEBOX_IOS_SHARE_APP_GROUP_IDENTITY_R51_PASS'

printf '%s\n' '[8/9] runtime checker still diagnoses container and closes route'
bash -n "$CHECK"
for token in \
  'SAFEBOX_IOS_SHARE_INBOX_CONTAINER_FAIL' \
  'CONTAINER_(FAIL|PASS)' \
  'SAFEBOX_IOS_SHARE_INBOX_ACCEPT: route=' \
  'SAFEBOX_IOS_SHARE_RUNTIME_PASS'; do
  grep -Fq "$token" "$CHECK" || fail "runtime checker token missing: $token"
done
printf '%s\n' 'SAFEBOX_IOS_SHARE_RUNTIME_CHECKER_R51_PASS'

printf '%s\n' '[9/9] hygiene + report'
[[ -s "$ROOT/checkpoints/SAFEBOX_V028_IOS_NATIVE_SHARE_EXTENSION_R51_REPORT.md" ]] || fail 'R51 report missing'
for bad in node_modules target .DS_Store; do
  if find "$ROOT" -name "$bad" -print -quit | grep -q .; then fail "packaged build artifact: $bad"; fi
done
[[ ! -d "$APP/src-tauri/gen/apple" ]] || fail 'generated Apple project packaged'
printf '%s\n' 'SAFEBOX_IOS_SHARE_HYGIENE_R51_PASS'
printf '%s\n' 'IOS_V028_STATUS: NATIVE_SHARE_EXTENSION_R51_READY_FOR_RUNTIME_TEST'
printf '%s\n' 'SAFEBOX_V028_IOS_NATIVE_SHARE_EXTENSION_R51_VERIFY_PASS'
