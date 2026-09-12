#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/safebox-desktop"
TAURI="$APP/src-tauri"
fail(){ echo "SAFEBOX_V028_R53_VERIFY_FAIL: $*" >&2; exit 1; }

# R52 is the validated baseline and must remain structurally present.
[[ -x "$ROOT/verification/verify_v028_ios_native_share_extension_r52.sh" ]] || fail 'R52 verifier missing'
grep -Fq 'v0.2.8-ios-direct-sbx-cold-start-r53-20260830B' "$ROOT/SAFEBOX_V028_PACKAGE_ID.txt" || fail 'R53 package id mismatch'
echo 'SAFEBOX_V028_R52_BASELINE_RETAINED_R53_PASS'

BRIDGE="$TAURI/ios/SafeBoxColdOpenBridge.mm"
INSTALLER="$APP/scripts/install_ios_cold_open_intake.sh"
ARM="$APP/scripts/ios_cold_open_arm.sh"
CHECK="$APP/scripts/ios_cold_open_check.sh"
[[ -f "$BRIDGE" && -x "$INSTALLER" && -x "$ARM" && -x "$CHECK" ]] || fail 'R53 cold-open runtime files missing'

grep -Fq 'UIApplicationDidFinishLaunchingNotification' "$BRIDGE" || fail 'didFinish launch observer missing'
grep -Fq 'UIApplicationLaunchOptionsURLKey' "$BRIDGE" || fail 'legacy launch URL fallback missing'
grep -Fq 'application:configurationForConnectingSceneSession:options:' "$BRIDGE" || fail 'scene connection-options hook missing'
grep -Fq 'TaoSceneDelegate' "$BRIDGE" || fail 'Tao scene delegate fallback hook missing'
grep -Fq 'options.URLContexts' "$BRIDGE" || fail 'UIScene URLContexts capture missing'
grep -Fq 'SAFEBOX_IOS_COLD_OPEN_CAPTURE_PASS:' "$BRIDGE" || fail 'route-only capture marker missing'
echo 'SAFEBOX_IOS_COLD_OPEN_LAUNCH_CAPTURE_CONTRACT_R53_PASS'

grep -Fq 'startAccessingSecurityScopedResource' "$BRIDGE" || fail 'security-scoped access missing'
grep -Fq 'stopAccessingSecurityScopedResource' "$BRIDGE" || fail 'security-scoped release missing'
grep -Fq 'NSFileCoordinator' "$BRIDGE" || fail 'coordinated provider read missing'
grep -Fq 'NSURLIsRegularFileKey' "$BRIDGE" || fail 'regular-file validation missing'
grep -Fq 'NSURLIsSymbolicLinkKey' "$BRIDGE" || fail 'symlink rejection missing'
grep -Fq 'NSFilePosixPermissions: @0700' "$BRIDGE" || fail 'private directory permission missing'
grep -Fq 'NSFilePosixPermissions: @0600' "$BRIDGE" || fail 'private payload permission missing'
grep -Fq 'NSFileProtectionComplete' "$BRIDGE" || fail 'complete file protection missing'
grep -Fq '@"payload.sbx"' "$BRIDGE" || fail 'metadata-minimized private payload name missing'
! grep -Eq 'NSLog\(@".*(%@|%s).*path|NSLog\(@".*(%@|%s).*URL' "$BRIDGE" || fail 'path/URL logging detected'
echo 'SAFEBOX_IOS_COLD_OPEN_PRIVATE_STAGING_SECURITY_R53_PASS'

grep -Fq 'safebox_ios_cold_open_accept' "$TAURI/src/lib.rs" || fail 'native-to-Rust cold-open exporter missing'
grep -Fq 'SAFEBOX_IOS_COLD_OPEN_ACCEPT: route=unlock' "$TAURI/src/lib.rs" || fail 'unlock-only Rust route marker missing'
grep -Fq 'IOS_COLD_OPEN_PENDING' "$TAURI/src/lib.rs" || fail 'pre-AppHandle pending queue missing'
grep -Fq 'SAFEBOX_IOS_COLD_OPEN_DELIVERY_PASS: mode=live' "$TAURI/src/lib.rs" || fail 'live delivery marker missing'
grep -Fq 'SAFEBOX_IOS_COLD_OPEN_DELIVERY_PASS: mode=pending' "$TAURI/src/lib.rs" || fail 'pending delivery marker missing'
grep -Fq 'SAFEBOX_IOS_COLD_OPEN_PENDING_DRAIN_PASS' "$TAURI/src/lib.rs" || fail 'setup pending drain missing'
echo 'SAFEBOX_IOS_COLD_OPEN_RUST_DELIVERY_R53_PASS'

grep -Fq '#include "../../../../ios/SafeBoxColdOpenBridge.mm"' "$INSTALLER" || fail 'generated main bridge include contract missing'
grep -Fq 'SBXColdOpenInstall();' "$INSTALLER" || fail 'generated main install call contract missing'
grep -Fq 'install_ios_cold_open_intake.sh' "$APP/scripts/ios_simulator_run.sh" || fail 'simulator pipeline does not install R53 bridge'
echo 'SAFEBOX_IOS_COLD_OPEN_MAIN_WIRING_R53_PASS'

grep -Fq 'xcrun simctl terminate' "$ARM" || fail 'cold-start arming does not terminate SafeBox'
grep -Fq 'SAFEBOX_IOS_COLD_OPEN_NEW_PROCESS_PASS' "$CHECK" || fail 'checker does not prove a new process'
grep -Fq 'SAFEBOX_IOS_COLD_OPEN_ACCEPT: route=unlock' "$CHECK" || fail 'checker does not require unlock route'
grep -Fq 'SAFEBOX_IOS_COLD_OPEN_RUNTIME_PASS' "$CHECK" || fail 'final runtime marker missing'
grep -Fq 'ios:cold-open-arm' "$APP/package.json" || fail 'npm arm script missing'
grep -Fq 'ios:cold-open-check' "$APP/package.json" || fail 'npm checker script missing'
echo 'SAFEBOX_IOS_COLD_OPEN_RUNTIME_CHECKER_R53_PASS'

# R53 must not modify the validated cryptographic/SBX or R52 Share/Ads implementations.
[[ "$(shasum -a 256 "$ROOT/safebox-core/src/crypto.rs" | awk '{print $1}')" == 'd30d1530b38988e544f0aa25808b8048f88d1a9578036160fc7efa40c854a99c' ]] || fail 'crypto.rs changed from R52 baseline'
[[ "$(shasum -a 256 "$ROOT/safebox-core/src/format.rs" | awk '{print $1}')" == '26edb67b2be91ff5c7d765e100e4aafa5e50933919c0db2e4370901f67205ea1' ]] || fail 'format.rs changed from R52 baseline'
[[ "$(shasum -a 256 "$TAURI/ios-share/ShareViewController.swift" | awk '{print $1}')" == '47166d2c995f425cf427d4de81359a175f9d43f83b64021ecdd154a9c8af7410' ]] || fail 'validated R52 Share Extension changed'
[[ "$(shasum -a 256 "$TAURI/ios/SafeBoxShareInboxBridge.mm" | awk '{print $1}')" == '225a81c837d54f4e1b14c91125354ed6e9ab5e2af56d52c0a9f57c87f8b8075f' ]] || fail 'validated R52 Share Inbox bridge changed'
[[ "$(shasum -a 256 "$TAURI/ios/SafeBoxAdsBridge.mm" | awk '{print $1}')" == 'a408b55ec036ee71894853c144fc753e7a181eeaca7b5ae6872ec636dfc5e2ea' ]] || fail 'validated Ads bridge changed'
! grep -Eq 'GAD|GoogleMobileAds|UserMessagingPlatform|UMP' "$BRIDGE" || fail 'Ads surface leaked into cold-open bridge'
echo 'SAFEBOX_IOS_COLD_OPEN_SECURITY_INVARIANTS_R53_PASS'

echo 'IOS_V028_STATUS: DIRECT_SBX_COLD_START_R53_READY_FOR_RUNTIME_TEST'
echo 'SAFEBOX_V028_IOS_DIRECT_SBX_COLD_START_R53_VERIFY_PASS'
