#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/safebox-desktop"
LIB="$APP/src-tauri/src/lib.rs"
BRIDGE="$APP/src-tauri/ios/SafeBoxShareInboxBridge.mm"
INSTALL="$APP/scripts/install_ios_share_extension.sh"
CHECK="$APP/scripts/ios_share_extension_check.sh"
SIM="$APP/scripts/ios_simulator_run.sh"
fail(){ echo "SAFEBOX_V028_IOS_SHARE_R49_FAIL: $*" >&2; exit 1; }

printf '%s\n' '[1/9] package + R48 architecture retained'
grep -Fq 'SAFEBOX_V028_PACKAGE_ID=v0.2.8-ios-native-share-extension-r49-20260830A' "$ROOT/SAFEBOX_V028_PACKAGE_ID.txt" || fail 'package id mismatch'
bash "$ROOT/verification/verify_v028_ios_native_share_extension_r48.sh" >/dev/null || fail 'R48 gate regression'
printf '%s\n' 'SAFEBOX_V028_R48_ARCHITECTURE_RETAINED_PASS'

printf '%s\n' '[2/9] validated Ads/linker surfaces unchanged'
check_sha(){ [[ "$(shasum -a 256 "$1" | awk '{print $1}')" == "$2" ]] || fail "validated R42 surface changed: $1"; }
check_sha "$APP/src-tauri/ios/SafeBoxAdsBridge.mm" a408b55ec036ee71894853c144fc753e7a181eeaca7b5ae6872ec636dfc5e2ea
check_sha "$APP/scripts/install_ios_ads_privacy.sh" f40244c11573e0364f8f064a1e180ea5896f61be8a06a550e18803dedc5c3653
check_sha "$APP/scripts/ios_scope_gma_objc_linker.sh" a31b61bbe5b9cc6f6c1da35b5cb175c2fbb49f5550d62b2686baecf225ea8e2c
check_sha "$APP/scripts/ios_ads_runtime_check.sh" 84f13e2f64caa28d736876353a80082d2ad0444b9158a34f4fa7896c0a15ffd3
check_sha "$APP/scripts/ios_xcode_rust_bridge.sh" 1ecd769313f834129fcc57fecc49a2847db5f373ca9e4b74fa3c17614d0562e9
printf '%s\n' 'SAFEBOX_IOS_VALIDATED_R42_RUNTIME_SURFACE_UNCHANGED_PASS'

printf '%s\n' '[3/9] native -> Rust registration boundary'
for token in \
  'extern "C" void safebox_ios_share_register(void (*drain)(void));' \
  'SBXShareInboxRegisterNativeBridge' \
  'safebox_ios_share_register(SBXDrainShareInboxNow)' \
  'SAFEBOX_IOS_SHARE_INBOX_NATIVE_REGISTER_PASS'; do
  grep -Fq "$token" "$BRIDGE" || fail "native registration token missing: $token"
done
! grep -Fq 'UIApplicationDidBecomeActiveNotification' "$BRIDGE" || fail 'old UIKit lifecycle observer survived'
printf '%s\n' 'SAFEBOX_IOS_SHARE_NATIVE_TO_RUST_REGISTRATION_R49_PASS'

printf '%s\n' '[4/9] Rust drain API and post-AppHandle setup trigger'
for token in \
  'static IOS_SHARE_NATIVE_DRAIN:' \
  'pub unsafe extern "C" fn safebox_ios_share_register' \
  'SAFEBOX_IOS_SHARE_INBOX_NATIVE_REGISTER_RUST_PASS' \
  'fn drain_ios_share_inbox(trigger: &str)' \
  'drain_ios_share_inbox("setup")'; do
  grep -Fq "$token" "$LIB" || fail "Rust lifecycle token missing: $token"
done
APP_HANDLE_LINE="$(grep -n 'IOS_SHARE_APP_HANDLE.set' "$LIB" | head -1 | cut -d: -f1)"
SETUP_DRAIN_LINE="$(grep -n 'drain_ios_share_inbox("setup")' "$LIB" | head -1 | cut -d: -f1)"
[[ -n "$APP_HANDLE_LINE" && -n "$SETUP_DRAIN_LINE" && "$APP_HANDLE_LINE" -lt "$SETUP_DRAIN_LINE" ]] || fail 'setup drain occurs before AppHandle registration'
printf '%s\n' 'SAFEBOX_IOS_SHARE_POST_APPHANDLE_DRAIN_R49_PASS'

printf '%s\n' '[5/9] Tauri Resumed foreground trigger'
grep -Fq 'tauri::RunEvent::Resumed' "$LIB" || fail 'RunEvent::Resumed trigger missing'
grep -Fq 'drain_ios_share_inbox("resumed")' "$LIB" || fail 'resumed drain call missing'
printf '%s\n' 'SAFEBOX_IOS_SHARE_TAURI_RESUMED_DRAIN_R49_PASS'

printf '%s\n' '[6/9] generated main registers bridge before start_app'
bash -n "$INSTALL"
grep -Fq 'SBXShareInboxRegisterNativeBridge();' "$INSTALL" || fail 'generated main registration injection missing'
! grep -Fq 'SBXShareInboxInstallAndDrain();' "$INSTALL" || fail 'obsolete pre-start drain injection survived'
grep -Fq 'SAFEBOX_IOS_SHARE_INBOX_NATIVE_REGISTRATION_PASS' "$INSTALL" || fail 'registration install marker missing'
printf '%s\n' 'SAFEBOX_IOS_SHARE_MAIN_REGISTRATION_R49_PASS'

printf '%s\n' '[7/9] explicit App Group diagnostics'
for token in 'SAFEBOX_IOS_SHARE_INBOX_NATIVE_DRAIN_TRIGGER' 'SAFEBOX_IOS_SHARE_INBOX_CONTAINER_FAIL' 'SAFEBOX_IOS_SHARE_INBOX_CONTAINER_PASS' 'SAFEBOX_IOS_SHARE_INBOX_DRAIN_BEGIN' 'SAFEBOX_IOS_SHARE_INBOX_DRAIN_PASS'; do
  grep -Fq "$token" "$BRIDGE" || fail "native diagnostic missing: $token"
done
printf '%s\n' 'SAFEBOX_IOS_SHARE_CONTAINER_DIAGNOSTICS_R49_PASS'

printf '%s\n' '[8/9] session-aware runtime checker closure'
bash -n "$CHECK"
for token in \
  'SAFEBOX_IOS_SHARE_INBOX_DRAIN_API_UNAVAILABLE' \
  'SAFEBOX_IOS_SHARE_INBOX_CONTAINER_FAIL' \
  'SAFEBOX_IOS_SHARE_INBOX_DRAIN_REQUEST: trigger=resumed' \
  'SAFEBOX_IOS_SHARE_RUNTIME_PASS'; do
  grep -Fq "$token" "$CHECK" || fail "runtime checker token missing: $token"
done
printf '%s\n' 'SAFEBOX_IOS_SHARE_RUNTIME_CHECKER_R49_PASS'

printf '%s\n' '[9/9] R48 bundle/embed + hygiene + report'
for token in 'SAFEBOX_IOS_SHARE_EXTENSION_BUNDLE_CONTRACT_PASS' 'SAFEBOX_IOS_SHARE_APP_GROUP_RUNTIME_ENTITLEMENTS_PASS' 'SAFEBOX_IOS_SHARE_EXTENSION_EMBED_PASS'; do
  grep -Fq "$token" "$SIM" || fail "R48 runtime contract regressed: $token"
done
[[ -s "$ROOT/checkpoints/SAFEBOX_V028_IOS_NATIVE_SHARE_EXTENSION_R49_REPORT.md" ]] || fail 'R49 report missing'
for bad in node_modules target .DS_Store; do
  if find "$ROOT" -name "$bad" -print -quit | grep -q .; then fail "packaged build artifact: $bad"; fi
done
[[ ! -d "$APP/src-tauri/gen/apple" ]] || fail 'generated Apple project packaged'
printf '%s\n' 'SAFEBOX_IOS_SHARE_HYGIENE_R49_PASS'
printf '%s\n' 'IOS_V028_STATUS: NATIVE_SHARE_EXTENSION_R49_READY_FOR_RUNTIME_TEST'
printf '%s\n' 'SAFEBOX_V028_IOS_NATIVE_SHARE_EXTENSION_R49_VERIFY_PASS'
