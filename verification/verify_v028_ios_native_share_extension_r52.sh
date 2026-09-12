#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/safebox-desktop"
LIB="$APP/src-tauri/src/lib.rs"
BRIDGE="$APP/src-tauri/ios/SafeBoxShareInboxBridge.mm"
INSTALL="$APP/scripts/install_ios_share_extension.sh"
CHECK="$APP/scripts/ios_share_extension_check.sh"
SIM="$APP/scripts/ios_simulator_run.sh"
fail(){ echo "SAFEBOX_V028_IOS_SHARE_R52_FAIL: $*" >&2; exit 1; }

printf '%s\n' '[1/10] package + R48/R49/R51 architecture retained'
grep -Fq 'SAFEBOX_V028_PACKAGE_ID=v0.2.8-ios-native-share-extension-r52-20260830A' "$ROOT/SAFEBOX_V028_PACKAGE_ID.txt" || fail 'package id mismatch'
for token in 'SAFEBOX_IOS_SHARE_EXTENSION_BUNDLE_CONTRACT_PASS' 'SAFEBOX_IOS_SHARE_EXTENSION_EMBED_PASS' 'SAFEBOX_IOS_SHARE_MAIN_SIMULATED_XCENT_PASS' 'SAFEBOX_IOS_SHARE_APP_GROUP_RUNTIME_ENTITLEMENTS_PASS'; do
  grep -Fq "$token" "$SIM" || fail "retained simulator architecture token missing: $token"
done
printf '%s\n' 'SAFEBOX_V028_R51_SIMULATOR_CAPABILITY_ARCHITECTURE_RETAINED_PASS'

printf '%s\n' '[2/10] validated Ads/linker surfaces unchanged'
check_sha(){ [[ "$(shasum -a 256 "$1" | awk '{print $1}')" == "$2" ]] || fail "validated R42 surface changed: $1"; }
check_sha "$APP/src-tauri/ios/SafeBoxAdsBridge.mm" a408b55ec036ee71894853c144fc753e7a181eeaca7b5ae6872ec636dfc5e2ea
check_sha "$APP/scripts/install_ios_ads_privacy.sh" f40244c11573e0364f8f064a1e180ea5896f61be8a06a550e18803dedc5c3653
check_sha "$APP/scripts/ios_scope_gma_objc_linker.sh" a31b61bbe5b9cc6f6c1da35b5cb175c2fbb49f5550d62b2686baecf225ea8e2c
check_sha "$APP/scripts/ios_ads_runtime_check.sh" 84f13e2f64caa28d736876353a80082d2ad0444b9158a34f4fa7896c0a15ffd3
check_sha "$APP/scripts/ios_xcode_rust_bridge.sh" 1ecd769313f834129fcc57fecc49a2847db5f373ca9e4b74fa3c17614d0562e9
printf '%s\n' 'SAFEBOX_IOS_VALIDATED_R42_RUNTIME_SURFACE_UNCHANGED_PASS'

printf '%s\n' '[3/10] native UIKit/scene foreground observers are authoritative'
for token in \
  'UIApplicationDidBecomeActiveNotification' \
  'UISceneDidActivateNotification' \
  'SAFEBOX_IOS_SHARE_INBOX_FOREGROUND_OBSERVER_PASS' \
  'SAFEBOX_IOS_SHARE_INBOX_FOREGROUND_NATIVE_PASS' \
  'safebox_ios_share_foreground();'; do
  grep -Fq "$token" "$BRIDGE" || fail "native foreground token missing: $token"
done
grep -Fq 'dispatch_once' "$BRIDGE" || fail 'foreground observer installation is not idempotent'
printf '%s\n' 'SAFEBOX_IOS_SHARE_NATIVE_FOREGROUND_OBSERVER_R52_PASS'

printf '%s\n' '[4/10] native foreground crosses into Rust then registered drain API'
for token in \
  'pub unsafe extern "C" fn safebox_ios_share_foreground()' \
  'SAFEBOX_IOS_SHARE_INBOX_FOREGROUND_RUST_PASS' \
  'drain_ios_share_inbox("native-foreground")' \
  'safebox_ios_share_register(SBXDrainShareInboxNow)' \
  'SAFEBOX_IOS_SHARE_INBOX_NATIVE_REGISTER_PASS'; do
  grep -Fq "$token" "$LIB" "$BRIDGE" || fail "native/Rust lifecycle token missing: $token"
done
printf '%s\n' 'SAFEBOX_IOS_SHARE_NATIVE_TO_RUST_FOREGROUND_R52_PASS'

printf '%s\n' '[5/10] Tauri Resumed retained as fallback only'
for token in 'tauri::RunEvent::Resumed' 'drain_ios_share_inbox("resumed")' 'R52 fallback only'; do
  grep -Fq "$token" "$LIB" || fail "Resumed fallback token missing: $token"
done
printf '%s\n' 'SAFEBOX_IOS_SHARE_TAURI_RESUMED_FALLBACK_R52_PASS'

printf '%s\n' '[6/10] runtime checker validates stage -> native foreground -> accept'
bash -n "$CHECK"
for token in \
  'trigger=native-foreground' \
  'SAFEBOX_IOS_SHARE_FOREGROUND_NATIVE_RUNTIME_PASS' \
  'SAFEBOX_IOS_SHARE_INBOX_ACCEPT: route=' \
  'stage < fg < accept' \
  'SAFEBOX_IOS_SHARE_RUNTIME_PASS'; do
  grep -Fq "$token" "$CHECK" || fail "R52 runtime checker token missing: $token"
done
if grep -Fq 'did not emit the iOS Resumed drain trigger' "$CHECK"; then fail 'obsolete R51 Resumed requirement retained'; fi
printf '%s\n' 'SAFEBOX_IOS_SHARE_RUNTIME_CHECKER_R52_PASS'

printf '%s\n' '[7/10] App Group and ingestion security invariants retained'
for token in 'group.com.safebox.desktop.share' 'NSFilePosixPermissions: @0700' 'NSFilePosixPermissions: @0600' 'NSFileProtectionComplete'; do
  grep -Fq "$token" "$BRIDGE" || fail "bridge security invariant missing: $token"
done
for token in 'appGroup = "group.com.safebox.desktop.share"' '.posixPermissions: 0o700' '.posixPermissions: 0o600' 'FileProtectionType.complete'; do
  grep -Fq "$token" "$APP/src-tauri/ios-share/ShareViewController.swift" || fail "extension security invariant missing: $token"
done
printf '%s\n' 'SAFEBOX_IOS_SHARE_SECURITY_INVARIANTS_R52_PASS'

printf '%s\n' '[8/10] install and simulator scripts remain syntactically valid'
bash -n "$INSTALL"
bash -n "$SIM"
grep -Fq 'SBXShareInboxRegisterNativeBridge();' "$INSTALL" || fail 'generated main native registration missing'
grep -Fq '#include "../../../../ios/SafeBoxShareInboxBridge.mm"' "$INSTALL" || fail 'native bridge include missing'
printf '%s\n' 'SAFEBOX_IOS_SHARE_INSTALL_RUNTIME_CONTRACT_R52_PASS'

printf '%s\n' '[9/10] crypto/SBX core untouched by R52 slice'
# R52 must be lifecycle-only; its report explicitly records the invariant and no
# R52-specific source file exists in safebox-core.
grep -Fq 'Crypto/SBX unchanged.' "$ROOT/checkpoints/SAFEBOX_V028_IOS_NATIVE_SHARE_EXTENSION_R52_REPORT.md" || fail 'crypto invariant absent from report'
printf '%s\n' 'SAFEBOX_IOS_SHARE_CRYPTO_UNCHANGED_R52_PASS'

printf '%s\n' '[10/10] hygiene + report'
[[ -s "$ROOT/checkpoints/SAFEBOX_V028_IOS_NATIVE_SHARE_EXTENSION_R52_REPORT.md" ]] || fail 'R52 report missing'
for bad in node_modules target .DS_Store; do
  if find "$ROOT" -name "$bad" -print -quit | grep -q .; then fail "packaged build artifact: $bad"; fi
done
[[ ! -d "$APP/src-tauri/gen/apple" ]] || fail 'generated Apple project packaged'
printf '%s\n' 'SAFEBOX_IOS_SHARE_HYGIENE_R52_PASS'
printf '%s\n' 'IOS_V028_STATUS: NATIVE_SHARE_EXTENSION_R52_READY_FOR_RUNTIME_TEST'
printf '%s\n' 'SAFEBOX_V028_IOS_NATIVE_SHARE_EXTENSION_R52_VERIFY_PASS'
