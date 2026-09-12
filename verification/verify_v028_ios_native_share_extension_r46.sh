#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/safebox-desktop"
INSTALL="$APP/scripts/install_ios_share_extension.sh"
SIM="$APP/scripts/ios_simulator_run.sh"
EXT="$APP/src-tauri/ios-share/ShareViewController.swift"
BRIDGE="$APP/src-tauri/ios/SafeBoxShareInboxBridge.mm"
fail(){ echo "SAFEBOX_V028_IOS_SHARE_R46_FAIL: $*" >&2; exit 1; }

printf '%s\n' '[1/9] package + R42 baseline retained'
grep -Fq 'SAFEBOX_V028_PACKAGE_ID=v0.2.8-ios-native-share-extension-r46-20260829D' "$ROOT/SAFEBOX_V028_PACKAGE_ID.txt" || fail 'package id mismatch'
SAFEBOX_VERIFY_SKIP_TOOLCHAIN=1 bash "$ROOT/verification/verify_v027_ios_ads_privacy.sh" >/dev/null
printf '%s\n' 'SAFEBOX_V028_R42_BASELINE_RETAINED_PASS'

printf '%s\n' '[2/9] validated Ads/linker surfaces unchanged'
check_sha(){ [[ "$(shasum -a 256 "$1" | awk '{print $1}')" == "$2" ]] || fail "validated R42 surface changed: $1"; }
check_sha "$APP/src-tauri/ios/SafeBoxAdsBridge.mm" a408b55ec036ee71894853c144fc753e7a181eeaca7b5ae6872ec636dfc5e2ea
check_sha "$APP/scripts/install_ios_ads_privacy.sh" f40244c11573e0364f8f064a1e180ea5896f61be8a06a550e18803dedc5c3653
check_sha "$APP/scripts/ios_scope_gma_objc_linker.sh" a31b61bbe5b9cc6f6c1da35b5cb175c2fbb49f5550d62b2686baecf225ea8e2c
check_sha "$APP/scripts/ios_ads_runtime_check.sh" 84f13e2f64caa28d736876353a80082d2ad0444b9158a34f4fa7896c0a15ffd3
check_sha "$APP/scripts/ios_xcode_rust_bridge.sh" 1ecd769313f834129fcc57fecc49a2847db5f373ca9e4b74fa3c17614d0562e9
printf '%s\n' 'SAFEBOX_IOS_VALIDATED_R42_RUNTIME_SURFACE_UNCHANGED_PASS'

printf '%s\n' '[3/9] no Ruby/xcodeproj runtime dependency'
bash -n "$INSTALL"
! grep -Eq "require ['\"]xcodeproj['\"]|project\.new_target|Xcodeproj::Project|GEM_HOME|GEM_PATH" "$INSTALL" || fail 'Ruby/xcodeproj mutation survived'
for token in 'SAFEBOX_IOS_SHARE_NO_RUBY_PROJECT_MUTATION_PASS' 'XCODEGEN_BIN=' 'generate --spec project.yml' 'SAFEBOX_IOS_SHARE_STANDALONE_XCODEGEN_PROJECT_PASS'; do
  grep -Fq "$token" "$INSTALL" || fail "R46 installer token missing: $token"
done
printf '%s\n' 'SAFEBOX_IOS_SHARE_NO_RUBY_XCODEPROJ_R46_PASS'

printf '%s\n' '[4/9] standalone extension project contract'
for token in 'type: app-extension' 'platform: iOS' 'PRODUCT_BUNDLE_IDENTIFIER: com.safebox.desktop.share' 'CODE_SIGN_ENTITLEMENTS: SafeBoxShare.entitlements' 'APPLICATION_EXTENSION_API_ONLY: YES' 'SKIP_INSTALL: YES'; do
  grep -Fq "$token" "$INSTALL" || fail "standalone project token missing: $token"
done
printf '%s\n' 'SAFEBOX_IOS_SHARE_STANDALONE_PROJECT_CONTRACT_PASS'

printf '%s\n' '[5/9] containing-app bridge retained'
for token in 'SBXShareInboxInstallAndDrain();' '../../../../ios/SafeBoxShareInboxBridge.mm'; do
  grep -Fq "$token" "$INSTALL" || fail "bridge install token missing: $token"
done
for token in 'group.com.safebox.desktop.share' 'UIApplicationDidBecomeActiveNotification' 'safebox_ios_share_inbox_accept(path)' 'NSFileProtectionComplete'; do
  grep -Fq "$token" "$BRIDGE" || fail "bridge security token missing: $token"
done
printf '%s\n' 'SAFEBOX_IOS_SHARE_INBOX_BRIDGE_R46_PASS'

printf '%s\n' '[6/9] extension staging security retained'
for token in 'containerURL(forSecurityApplicationGroupIdentifier: appGroup)' '.posixPermissions: 0o700' '.posixPermissions: 0o600' 'FileProtectionType.complete' 'url.startAccessingSecurityScopedResource()' 'SAFEBOX_IOS_SHARE_EXTENSION_STAGE_PASS'; do
  grep -Fq "$token" "$EXT" || fail "extension security token missing: $token"
done
printf '%s\n' 'SAFEBOX_IOS_SHARE_EXTENSION_SECURITY_R46_PASS'

printf '%s\n' '[7/9] standalone build + embed + signing runtime contract'
bash -n "$SIM"
for token in '-project "$SHARE_PROJECT"' '-scheme SafeBoxShareExtension' 'SAFEBOX_IOS_SHARE_EXTENSION_BUILD_BEGIN' 'SAFEBOX_IOS_SHARE_EXTENSION_TARGET_PASS' 'PlugIns/SafeBoxShareExtension.appex' 'merge_app_group_and_resign' 'codesign --force --sign -' 'codesign --verify --deep --strict' 'SAFEBOX_IOS_SHARE_APP_GROUP_RUNTIME_ENTITLEMENTS_PASS' 'SAFEBOX_IOS_SHARE_EXTENSION_EMBED_PASS'; do
  grep -Fq -- "$token" "$SIM" || fail "simulator R46 token missing: $token"
done
printf '%s\n' 'SAFEBOX_IOS_SHARE_RUNTIME_EMBED_SIGNING_CONTRACT_PASS'

printf '%s\n' '[8/9] runtime checker preserved'
bash -n "$APP/scripts/ios_share_extension_check.sh"
grep -Fq 'SAFEBOX_IOS_SHARE_RUNTIME_PASS' "$APP/scripts/ios_share_extension_check.sh" || fail 'share runtime final marker missing'
grep -Fq 'SAFEBOX_IOS_SHARE_EXTENSION_STAGE_PASS' "$APP/scripts/ios_share_extension_check.sh" || fail 'share stage runtime marker missing'
printf '%s\n' 'SAFEBOX_IOS_SHARE_RUNTIME_CHECKER_R46_PASS'

printf '%s\n' '[9/9] hygiene + report'
[[ -s "$ROOT/checkpoints/SAFEBOX_V028_IOS_NATIVE_SHARE_EXTENSION_R46_REPORT.md" ]] || fail 'R46 report missing'
for bad in node_modules target .DS_Store; do
  if find "$ROOT" -name "$bad" -print -quit | grep -q .; then fail "packaged build artifact: $bad"; fi
done
[[ ! -d "$APP/src-tauri/gen/apple" ]] || fail 'generated Apple project packaged'
printf '%s\n' 'SAFEBOX_IOS_SHARE_HYGIENE_R46_PASS'
printf '%s\n' 'IOS_V028_STATUS: NATIVE_SHARE_EXTENSION_R46_READY_FOR_RUNTIME_TEST'
printf '%s\n' 'SAFEBOX_V028_IOS_NATIVE_SHARE_EXTENSION_R46_VERIFY_PASS'
