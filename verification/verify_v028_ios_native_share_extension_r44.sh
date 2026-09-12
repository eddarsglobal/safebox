#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/safebox-desktop"
LIB="$APP/src-tauri/src/lib.rs"
INFO="$APP/src-tauri/Info.ios.plist"
EXT="$APP/src-tauri/ios-share/ShareViewController.swift"
EXT_INFO="$APP/src-tauri/ios-share/Info.plist"
EXT_ENT="$APP/src-tauri/ios-share/SafeBoxShare.entitlements"
BRIDGE="$APP/src-tauri/ios/SafeBoxShareInboxBridge.mm"
INSTALL="$APP/scripts/install_ios_share_extension.sh"
CHECK="$APP/scripts/ios_share_extension_check.sh"
SIM="$APP/scripts/ios_simulator_run.sh"
fail(){ echo "SAFEBOX_V028_IOS_SHARE_R44_FAIL: $*" >&2; exit 1; }

printf '%s\n' '[1/10] package + R42 baseline retained'
grep -Fq 'SAFEBOX_V028_PACKAGE_ID=v0.2.8-ios-native-share-extension-r44-20260829B' "$ROOT/SAFEBOX_V028_PACKAGE_ID.txt" || fail 'package id mismatch'
SAFEBOX_VERIFY_SKIP_TOOLCHAIN=1 bash "$ROOT/verification/verify_v027_ios_ads_privacy.sh" >/dev/null
printf '%s\n' 'SAFEBOX_V028_R42_BASELINE_RETAINED_PASS'

printf '%s\n' '[2/10] validated Ads/linker surfaces unchanged'
check_sha(){ [[ "$(shasum -a 256 "$1" | awk '{print $1}')" == "$2" ]] || fail "validated R42 surface changed: $1"; }
check_sha "$APP/src-tauri/ios/SafeBoxAdsBridge.mm" a408b55ec036ee71894853c144fc753e7a181eeaca7b5ae6872ec636dfc5e2ea
check_sha "$APP/scripts/install_ios_ads_privacy.sh" f40244c11573e0364f8f064a1e180ea5896f61be8a06a550e18803dedc5c3653
check_sha "$APP/scripts/ios_scope_gma_objc_linker.sh" a31b61bbe5b9cc6f6c1da35b5cb175c2fbb49f5550d62b2686baecf225ea8e2c
check_sha "$APP/scripts/ios_ads_runtime_check.sh" 84f13e2f64caa28d736876353a80082d2ad0444b9158a34f4fa7896c0a15ffd3
check_sha "$APP/scripts/ios_xcode_rust_bridge.sh" 1ecd769313f834129fcc57fecc49a2847db5f373ca9e4b74fa3c17614d0562e9
printf '%s\n' 'SAFEBOX_IOS_VALIDATED_R42_RUNTIME_SURFACE_UNCHANGED_PASS'

printf '%s\n' '[3/10] document association corrected to .sbx only'
python3 - "$INFO" <<'PY'
import plistlib,sys
p=plistlib.load(open(sys.argv[1],'rb'))
assert p.get('LSSupportsOpeningDocumentsInPlace') is True
entries=p.get('CFBundleDocumentTypes') or []
sets=[set(e.get('LSItemContentTypes') or []) for e in entries]
assert {'com.safebox.desktop.sbx'} in sets
assert not any('public.data' in x for x in sets)
exports=p.get('UTExportedTypeDeclarations') or []
sbx=next(x for x in exports if x.get('UTTypeIdentifier')=='com.safebox.desktop.sbx')
assert {'public.data','public.content'}.issubset(set(sbx.get('UTTypeConformsTo') or []))
PY
printf '%s\n' 'SAFEBOX_IOS_SBX_DOCUMENT_ASSOCIATION_R44_PASS'

printf '%s\n' '[4/10] native Share Extension declaration'
python3 - "$EXT_INFO" "$EXT_ENT" <<'PY'
import plistlib,sys
info=plistlib.load(open(sys.argv[1],'rb')); ent=plistlib.load(open(sys.argv[2],'rb'))
ext=info['NSExtension']; assert ext['NSExtensionPointIdentifier']=='com.apple.share-services'
rule=ext['NSExtensionAttributes']['NSExtensionActivationRule']
assert rule['NSExtensionActivationSupportsFileWithMaxCount']==1
assert rule['NSExtensionActivationSupportsImageWithMaxCount']==1
assert rule['NSExtensionActivationSupportsMovieWithMaxCount']==1
assert ent['com.apple.security.application-groups']==['group.com.safebox.desktop.share']
PY
grep -Fq 'final class ShareViewController: UIViewController' "$EXT" || fail 'ShareViewController missing'
printf '%s\n' 'SAFEBOX_IOS_SHARE_EXTENSION_DECLARATION_PASS'

printf '%s\n' '[5/10] extension staging security'
for token in 'containerURL(forSecurityApplicationGroupIdentifier: appGroup)' 'UUID().uuidString.lowercased()' '.posixPermissions: 0o700' '.posixPermissions: 0o600' 'FileProtectionType.complete' 'url.startAccessingSecurityScopedResource()' '.isRegularFileKey' '.isSymbolicLinkKey' 'SAFEBOX_IOS_SHARE_EXTENSION_STAGE_PASS'; do
  grep -Fq "$token" "$EXT" || fail "extension security token missing: $token"
done
python3 - "$EXT" <<'PY'
import sys
s=open(sys.argv[1]).read()
assert s.index('try FileManager.default.copyItem') < s.index('let ready = request.appendingPathComponent("READY"')
assert 'UIApplication.shared' not in s
assert '.openURL' not in s
assert 'extensionContext?.open' not in s
for bad in ['NSLog("SAFEBOX_IOS_SHARE_EXTENSION_STAGE_PASS %@', 'print(url', 'NSLog("%@", url']:
    assert bad not in s
PY
printf '%s\n' 'SAFEBOX_IOS_SHARE_EXTENSION_STAGING_SECURITY_PASS'

printf '%s\n' '[6/10] containing-app inbox bridge'
for token in 'group.com.safebox.desktop.share' 'UIApplicationDidBecomeActiveNotification' 'NSURLIsRegularFileKey' 'NSURLIsSymbolicLinkKey' 'SafeBoxShareIntake' 'NSFilePosixPermissions: @0600' 'NSFileProtectionComplete' 'safebox_ios_share_inbox_accept(path)' 'removeItemAtURL:request'; do
  grep -Fq "$token" "$BRIDGE" || fail "inbox bridge token missing: $token"
done
! grep -Eq 'NSLog\([^\n]*(path|URL|lastPathComponent)' "$BRIDGE" || fail 'bridge may leak path/name in log'
printf '%s\n' 'SAFEBOX_IOS_SHARE_INBOX_BRIDGE_SECURITY_PASS'

printf '%s\n' '[7/10] Rust native-to-Tauri intake'
for token in 'static IOS_SHARE_INBOX_PENDING' 'static IOS_SHARE_APP_HANDLE' 'pub unsafe extern "C" fn safebox_ios_share_inbox_accept' 'SAFEBOX_IOS_SHARE_INBOX_ACCEPT: route={route}' 'emit_opened_files(app, vec![value.to_string()])' 'let _ = IOS_SHARE_APP_HANDLE.set(app.handle().clone())' 'let shared = take_ios_share_pending()'; do
  grep -Fq "$token" "$LIB" || fail "Rust share intake token missing: $token"
done
! grep -Fq 'SAFEBOX_IOS_SHARE_INBOX_ACCEPT: path=' "$LIB" || fail 'Rust path leakage marker'
! grep -Fq 'SAFEBOX_IOS_SHARE_INBOX_ACCEPT: url=' "$LIB" || fail 'Rust URL leakage marker'
printf '%s\n' 'SAFEBOX_IOS_SHARE_NATIVE_TO_TAURI_PASS'

printf '%s\n' '[8/10] generated Xcode target installer'
bash -n "$INSTALL"
for token in "project.new_target(:app_extension, 'SafeBoxShareExtension'" "PRODUCT_BUNDLE_IDENTIFIER'] = 'com.safebox.desktop.share'" "CODE_SIGN_ENTITLEMENTS'] = 'SafeBoxShareExtension/SafeBoxShare.entitlements'" "app.add_dependency(ext)" "Embed App Extensions" "dst_subfolder_spec = '13'" "CodeSignOnCopy" "SafeBoxAppGroups.entitlements" 'SBXShareInboxInstallAndDrain();'; do
  grep -Fq "$token" "$INSTALL" || fail "installer token missing: $token"
done
printf '%s\n' 'SAFEBOX_IOS_SHARE_XCODE_TARGET_INSTALLER_PASS'

printf '%s\n' '[9/10] simulator/runtime gate'
bash -n "$CHECK"; bash -n "$SIM"
grep -Fq 'bash "$SCRIPT_DIR/install_ios_share_extension.sh"' "$SIM" || fail 'share installer not called by simulator runtime'
grep -Fq 'SAFEBOX_IOS_SHARE_EXTENSION_EMBED_PASS' "$SIM" || fail 'embedded appex preflight missing'
grep -Fq 'SAFEBOX_IOS_SHARE_RUNTIME_PASS' "$CHECK" || fail 'share runtime final marker missing'
grep -Fq 'SAFEBOX_IOS_SHARE_EXTENSION_STAGE_PASS' "$CHECK" || fail 'extension stage runtime gate missing'
grep -Fq 'SAFEBOX_IOS_SHARE_INBOX_ACCEPT: route=$EXPECTED_ROUTE' "$CHECK" || fail 'route runtime gate missing'
grep -Fq '"ios:share-check": "bash scripts/ios_share_extension_check.sh"' "$APP/package.json" || fail 'npm share checker missing'
printf '%s\n' 'SAFEBOX_IOS_SHARE_RUNTIME_GATE_R44_PASS'

printf '%s\n' '[10/10] hygiene + report'
[[ -s "$ROOT/checkpoints/SAFEBOX_V028_IOS_NATIVE_SHARE_EXTENSION_R44_REPORT.md" ]] || fail 'R44 report missing'
for bad in node_modules target .DS_Store; do
  if find "$ROOT" -name "$bad" -print -quit | grep -q .; then fail "packaged build artifact: $bad"; fi
done
[[ ! -d "$APP/src-tauri/gen/apple" ]] || fail 'generated Apple project packaged'
printf '%s\n' 'SAFEBOX_IOS_SHARE_HYGIENE_R44_PASS'
printf '%s\n' 'IOS_V028_STATUS: NATIVE_SHARE_EXTENSION_READY_FOR_RUNTIME_TEST'
printf '%s\n' 'SAFEBOX_V028_IOS_NATIVE_SHARE_EXTENSION_R44_VERIFY_PASS'
