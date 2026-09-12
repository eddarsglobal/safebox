#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/safebox-desktop"
TAURI="$APP/src-tauri"
fail(){ echo "SAFEBOX_V028_R54_VERIFY_FAIL: $*" >&2; exit 1; }

[[ -x "$ROOT/verification/verify_v028_ios_direct_sbx_cold_start_r53.sh" ]] || fail 'R53 verifier missing'
grep -Fq 'v0.2.8-ios-direct-sbx-document-owner-r54-20260830C' "$ROOT/SAFEBOX_V028_PACKAGE_ID.txt" || fail 'R54 package id mismatch'
echo 'SAFEBOX_V028_R53_COLD_OPEN_INFRA_RETAINED_R54_PASS'

PLIST="$TAURI/Info.ios.plist"
[[ -f "$PLIST" ]] || fail 'canonical iOS Info plist missing'
grep -A1 -F '<key>CFBundleTypeRole</key>' "$PLIST" | grep -Fq '<string>Editor</string>' || fail 'SBX role is not Editor'
grep -A1 -F '<key>LSHandlerRank</key>' "$PLIST" | grep -Fq '<string>Owner</string>' || fail 'SBX handler rank is not Owner'
grep -Fq '<key>CFBundleTypeExtensions</key>' "$PLIST" || fail 'legacy SBX extension map missing'
grep -Fq '<string>com.safebox.desktop.sbx</string>' "$PLIST" || fail 'SBX UTI missing'
grep -Fq '<string>application/x-safebox</string>' "$PLIST" || fail 'dedicated SBX MIME missing'
[[ "$(grep -Fc '<string>public.content</string>' "$PLIST")" == '0' ]] || fail 'encrypted SBX must not conform to public.content'
grep -Fq '<string>public.data</string>' "$PLIST" || fail 'SBX public.data conformance missing'
echo 'SAFEBOX_IOS_COLD_OPEN_DOCUMENT_OWNER_CONTRACT_R54_PASS'

RUNNER="$APP/scripts/ios_simulator_run.sh"
ARM="$APP/scripts/ios_cold_open_arm.sh"
CHECK="$APP/scripts/ios_cold_open_check.sh"
grep -Fq 'SAFEBOX_IOS_COLD_OPEN_DOCUMENT_OWNER_INSTALL_PASS' "$RUNNER" || fail 'installed-bundle owner proof missing'
grep -Fq "Print :CFBundleDocumentTypes:0:CFBundleTypeRole" "$RUNNER" || fail 'installed document role check missing'
grep -Fq "Print :CFBundleDocumentTypes:0:LSHandlerRank" "$RUNNER" || fail 'installed handler-rank check missing'
grep -Fq "Print :UTExportedTypeDeclarations:0:UTTypeTagSpecification:public.mime-type" "$RUNNER" || fail 'installed MIME check missing'
grep -Fq 'SAFEBOX_IOS_COLD_OPEN_DOCUMENT_OWNER_PASS' "$ARM" || fail 'arm-time installed association proof missing'
grep -Fq 'SAFEBOX_IOS_COLD_OPEN_DISPATCH_FAIL' "$CHECK" || fail 'dispatch-specific failure marker missing'
echo 'SAFEBOX_IOS_COLD_OPEN_INSTALLED_ASSOCIATION_PROOF_R54_PASS'

BRIDGE="$TAURI/ios/SafeBoxColdOpenBridge.mm"
# R54 must preserve R53 cold-open bridge byte-for-byte.
[[ "$(shasum -a 256 "$BRIDGE" | awk '{print $1}')" == '4712895a3941cb359bdb87a55f92c117af247393d5aa1db07b979bde6eb22f42' ]] || fail 'R53 cold-open bridge changed'
grep -Fq 'UIApplicationDidFinishLaunchingNotification' "$BRIDGE" || fail 'R53 did-finish hook lost'
grep -Fq 'options.URLContexts' "$BRIDGE" || fail 'R53 scene URLContexts hook lost'
grep -Fq 'SAFEBOX_IOS_COLD_OPEN_ACCEPT: route=unlock' "$TAURI/src/lib.rs" || fail 'R53 Rust unlock route lost'
echo 'SAFEBOX_IOS_COLD_OPEN_R53_CAPTURE_UNCHANGED_R54_PASS'

[[ "$(shasum -a 256 "$ROOT/safebox-core/src/crypto.rs" | awk '{print $1}')" == 'd30d1530b38988e544f0aa25808b8048f88d1a9578036160fc7efa40c854a99c' ]] || fail 'crypto.rs changed'
[[ "$(shasum -a 256 "$ROOT/safebox-core/src/format.rs" | awk '{print $1}')" == '26edb67b2be91ff5c7d765e100e4aafa5e50933919c0db2e4370901f67205ea1' ]] || fail 'format.rs changed'
[[ "$(shasum -a 256 "$TAURI/ios-share/ShareViewController.swift" | awk '{print $1}')" == '47166d2c995f425cf427d4de81359a175f9d43f83b64021ecdd154a9c8af7410' ]] || fail 'R52 Share Extension changed'
[[ "$(shasum -a 256 "$TAURI/ios/SafeBoxShareInboxBridge.mm" | awk '{print $1}')" == '225a81c837d54f4e1b14c91125354ed6e9ab5e2af56d52c0a9f57c87f8b8075f' ]] || fail 'R52 Share Inbox bridge changed'
[[ "$(shasum -a 256 "$TAURI/ios/SafeBoxAdsBridge.mm" | awk '{print $1}')" == 'a408b55ec036ee71894853c144fc753e7a181eeaca7b5ae6872ec636dfc5e2ea' ]] || fail 'Ads bridge changed'
echo 'SAFEBOX_IOS_COLD_OPEN_SECURITY_INVARIANTS_R54_PASS'

echo 'IOS_V028_STATUS: DIRECT_SBX_DOCUMENT_OWNER_R54_READY_FOR_RUNTIME_TEST'
echo 'SAFEBOX_V028_IOS_DIRECT_SBX_DOCUMENT_OWNER_R54_VERIFY_PASS'
