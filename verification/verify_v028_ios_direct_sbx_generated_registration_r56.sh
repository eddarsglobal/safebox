#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/safebox-desktop"
TAURI="$APP/src-tauri"
fail(){ echo "SAFEBOX_V028_R56_VERIFY_FAIL: $*" >&2; exit 1; }

[[ -x "$ROOT/verification/verify_v028_ios_direct_sbx_single_registration_r55.sh" ]] || fail 'R55 verifier missing'
grep -Fq 'v0.2.8-ios-direct-sbx-generated-registration-r56-20260830E' "$ROOT/SAFEBOX_V028_PACKAGE_ID.txt" || fail 'R56 package id mismatch'
echo 'SAFEBOX_V028_R55_FOUNDATION_RETAINED_R56_PASS'

CANONICAL="$TAURI/ios/SafeBoxDocumentRegistration.plist"
PATCHER="$APP/scripts/ios_sbx_document_registration_patch.py"
CHECKER="$APP/scripts/ios_sbx_document_contract_check.py"
[[ -f "$CANONICAL" ]] || fail 'canonical iOS document registration missing'
[[ -x "$PATCHER" ]] || fail 'generated Info.plist patcher missing'
[[ -x "$CHECKER" ]] || fail 'document contract checker missing'

python3 - "$CANONICAL" "$TAURI/Info.ios.plist" <<'PY'
import plistlib,sys
with open(sys.argv[1],'rb') as f: c=plistlib.load(f)
if set(c)!={'CFBundleDocumentTypes','UTExportedTypeDeclarations'}: raise SystemExit(1)
d=c['CFBundleDocumentTypes']; u=c['UTExportedTypeDeclarations']
if len(d)!=1 or len(u)!=1: raise SystemExit(1)
d=d[0]; u=u[0]
assert d['CFBundleTypeRole']=='Editor'
assert d['LSHandlerRank']=='Owner'
assert d['CFBundleTypeExtensions']==['sbx']
assert d['LSItemContentTypes']==['com.safebox.desktop.sbx']
assert u['UTTypeIdentifier']=='com.safebox.desktop.sbx'
assert u['UTTypeConformsTo']==['public.data']
assert u['UTTypeTagSpecification']['public.filename-extension']==['sbx']
assert u['UTTypeTagSpecification']['public.mime-type']=='application/x-safebox'
with open(sys.argv[2],'rb') as f: supplemental=plistlib.load(f)
if 'CFBundleDocumentTypes' in supplemental or 'UTExportedTypeDeclarations' in supplemental: raise SystemExit(1)
assert supplemental.get('LSSupportsOpeningDocumentsInPlace') is True
PY
echo 'SAFEBOX_IOS_COLD_OPEN_CANONICAL_GENERATED_REGISTRATION_R56_PASS'

# Cross-platform positive proof: replace deliberately conflicting legacy entries
# with the canonical one, then validate the exact result.
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
python3 - "$TMP/Info.plist" <<'PY'
import plistlib,sys
legacy={
 'CFBundleIdentifier':'com.safebox.desktop',
 'CFBundleDocumentTypes':[
   {'CFBundleTypeName':'Legacy A','CFBundleTypeRole':'Viewer','LSHandlerRank':'Alternate','CFBundleTypeExtensions':['sbx'],'LSItemContentTypes':['com.safebox.legacy']},
   {'CFBundleTypeName':'Legacy B','CFBundleTypeRole':'Viewer','LSHandlerRank':'Alternate','CFBundleTypeExtensions':['sbx']},
 ],
 'UTExportedTypeDeclarations':[
   {'UTTypeIdentifier':'com.safebox.legacy','UTTypeConformsTo':['public.content'],'UTTypeTagSpecification':{'public.filename-extension':['sbx'],'public.mime-type':'application/octet-stream'}}
 ],
 'GADApplicationIdentifier':'test-preserve-me'
}
with open(sys.argv[1],'wb') as f: plistlib.dump(legacy,f)
PY
python3 "$PATCHER" "$CANONICAL" "$TMP/Info.plist" >/dev/null
python3 "$CHECKER" "$TMP/Info.plist" >/dev/null
python3 - "$TMP/Info.plist" <<'PY'
import plistlib,sys
with open(sys.argv[1],'rb') as f: p=plistlib.load(f)
assert p['GADApplicationIdentifier']=='test-preserve-me'
assert len(p['CFBundleDocumentTypes'])==1
assert len(p['UTExportedTypeDeclarations'])==1
PY
echo 'SAFEBOX_IOS_COLD_OPEN_CONFLICT_REPLACEMENT_R56_PASS'

INSTALL="$APP/scripts/install_ios_cold_open_intake.sh"
RUNNER="$APP/scripts/ios_simulator_run.sh"
ARM="$APP/scripts/ios_cold_open_arm.sh"
grep -Fq 'SafeBoxDocumentRegistration.plist' "$INSTALL" || fail 'canonical registration not wired into install step'
grep -Fq 'ios_sbx_document_registration_patch.py' "$INSTALL" || fail 'generated plist patcher not wired'
grep -Fq 'SAFEBOX_IOS_COLD_OPEN_GENERATED_DOCUMENT_CONTRACT_PASS' "$INSTALL" || fail 'generated contract pass marker missing'
grep -Fq 'SAFEBOX_IOS_COLD_OPEN_GENERATED_REGISTRATION_RUNTIME_PROOF_PASS' "$RUNNER" || fail 'installed-bundle R56 proof marker missing'
grep -Fq 'SAFEBOX_IOS_COLD_OPEN_GENERATED_REGISTRATION_ARM_PROOF_PASS' "$ARM" || fail 'arm-time R56 proof marker missing'
echo 'SAFEBOX_IOS_COLD_OPEN_GENERATED_WIRING_R56_PASS'

BRIDGE="$TAURI/ios/SafeBoxColdOpenBridge.mm"
[[ "$(shasum -a 256 "$BRIDGE" | awk '{print $1}')" == '4712895a3941cb359bdb87a55f92c117af247393d5aa1db07b979bde6eb22f42' ]] || fail 'R53 cold-open bridge changed'
[[ "$(shasum -a 256 "$ROOT/safebox-core/src/crypto.rs" | awk '{print $1}')" == 'd30d1530b38988e544f0aa25808b8048f88d1a9578036160fc7efa40c854a99c' ]] || fail 'crypto.rs changed'
[[ "$(shasum -a 256 "$ROOT/safebox-core/src/format.rs" | awk '{print $1}')" == '26edb67b2be91ff5c7d765e100e4aafa5e50933919c0db2e4370901f67205ea1' ]] || fail 'format.rs changed'
[[ "$(shasum -a 256 "$TAURI/ios-share/ShareViewController.swift" | awk '{print $1}')" == '47166d2c995f425cf427d4de81359a175f9d43f83b64021ecdd154a9c8af7410' ]] || fail 'R52 Share Extension changed'
[[ "$(shasum -a 256 "$TAURI/ios/SafeBoxShareInboxBridge.mm" | awk '{print $1}')" == '225a81c837d54f4e1b14c91125354ed6e9ab5e2af56d52c0a9f57c87f8b8075f' ]] || fail 'R52 Share Inbox bridge changed'
[[ "$(shasum -a 256 "$TAURI/ios/SafeBoxAdsBridge.mm" | awk '{print $1}')" == 'a408b55ec036ee71894853c144fc753e7a181eeaca7b5ae6872ec636dfc5e2ea' ]] || fail 'Ads bridge changed'
echo 'SAFEBOX_IOS_COLD_OPEN_SECURITY_INVARIANTS_R56_PASS'

echo 'IOS_V028_STATUS: DIRECT_SBX_GENERATED_REGISTRATION_R56_READY_FOR_RUNTIME_TEST'
echo 'SAFEBOX_V028_IOS_DIRECT_SBX_GENERATED_REGISTRATION_R56_VERIFY_PASS'
