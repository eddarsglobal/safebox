#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/safebox-desktop"
TAURI="$APP/src-tauri"
fail(){ echo "SAFEBOX_V028_R55_VERIFY_FAIL: $*" >&2; exit 1; }

[[ -x "$ROOT/verification/verify_v028_ios_direct_sbx_cold_start_r53.sh" ]] || fail 'R53 verifier missing'
grep -Fq 'v0.2.8-ios-direct-sbx-single-registration-r55-20260830D' "$ROOT/SAFEBOX_V028_PACKAGE_ID.txt" || fail 'R55 package id mismatch'
echo 'SAFEBOX_V028_R53_COLD_OPEN_INFRA_RETAINED_R55_PASS'

python3 - "$TAURI/tauri.conf.json" "$TAURI/Info.ios.plist" <<'PY' || exit 1
import json, plistlib, sys
conf=json.load(open(sys.argv[1]))
fa=conf.get('bundle',{}).get('fileAssociations',[])
if len(fa)!=1: raise SystemExit('SAFEBOX_V028_R55_VERIFY_FAIL: expected exactly one canonical Tauri file association')
f=fa[0]
checks={
 'ext': f.get('ext')==['sbx'],
 'role': f.get('role')=='Editor',
 'rank': f.get('rank')=='Owner',
 'mime': f.get('mimeType')=='application/x-safebox',
 'uti': f.get('exportedType',{}).get('identifier')=='com.safebox.desktop.sbx',
 'conforms': f.get('exportedType',{}).get('conformsTo')==['public.data'],
}
for k,v in checks.items():
    if not v: raise SystemExit(f'SAFEBOX_V028_R55_VERIFY_FAIL: canonical Tauri association mismatch: {k}')
with open(sys.argv[2],'rb') as fh: p=plistlib.load(fh)
if 'CFBundleDocumentTypes' in p: raise SystemExit('SAFEBOX_V028_R55_VERIFY_FAIL: Info.ios.plist duplicates CFBundleDocumentTypes')
if 'UTExportedTypeDeclarations' in p: raise SystemExit('SAFEBOX_V028_R55_VERIFY_FAIL: Info.ios.plist duplicates UTExportedTypeDeclarations')
if p.get('LSSupportsOpeningDocumentsInPlace') is not True: raise SystemExit('SAFEBOX_V028_R55_VERIFY_FAIL: opening-documents-in-place flag lost')
PY
echo 'SAFEBOX_IOS_COLD_OPEN_SINGLE_SOURCE_ASSOCIATION_R55_PASS'

HELPER="$APP/scripts/ios_sbx_document_contract_check.py"
[[ -x "$HELPER" ]] || fail 'installed document-contract helper missing'
grep -Fq 'expected exactly one SBX document registration' "$HELPER" || fail 'duplicate document registration rejection missing'
grep -Fq 'expected exactly one exported SBX UTI' "$HELPER" || fail 'duplicate exported UTI rejection missing'
grep -Fq "expected 'Editor'" "$HELPER" || fail 'Editor proof missing'
grep -Fq "expected 'Owner'" "$HELPER" || fail 'Owner proof missing'
grep -Fq 'application/x-safebox' "$HELPER" || fail 'MIME proof missing'
grep -Fq "conformance must be exactly ['public.data']" "$HELPER" || fail 'strict public.data conformance proof missing'
echo 'SAFEBOX_IOS_COLD_OPEN_INSTALLED_CONTRACT_HELPER_R55_PASS'

RUNNER="$APP/scripts/ios_simulator_run.sh"
ARM="$APP/scripts/ios_cold_open_arm.sh"
grep -Fq 'ios_sbx_document_contract_check.py' "$RUNNER" || fail 'runtime installed contract helper not wired'
grep -Fq 'SAFEBOX_IOS_COLD_OPEN_SINGLE_REGISTRATION_INSTALL_PASS' "$RUNNER" || fail 'runtime single-registration install marker missing'
grep -Fq 'ios_sbx_document_contract_check.py' "$ARM" || fail 'arm-time contract helper not wired'
grep -Fq 'SAFEBOX_IOS_COLD_OPEN_SINGLE_REGISTRATION_PASS' "$ARM" || fail 'arm-time single-registration marker missing'
! grep -Fq "CFBundleDocumentTypes:0:CFBundleTypeRole" "$RUNNER" || fail 'brittle R54 index-0 runtime check retained'
! grep -Fq "CFBundleDocumentTypes:0:CFBundleTypeRole" "$ARM" || fail 'brittle R54 index-0 arm check retained'
echo 'SAFEBOX_IOS_COLD_OPEN_RUNTIME_ASSOCIATION_PROOF_R55_PASS'

BRIDGE="$TAURI/ios/SafeBoxColdOpenBridge.mm"
[[ "$(shasum -a 256 "$BRIDGE" | awk '{print $1}')" == '4712895a3941cb359bdb87a55f92c117af247393d5aa1db07b979bde6eb22f42' ]] || fail 'R53 cold-open bridge changed'
grep -Fq 'SAFEBOX_IOS_COLD_OPEN_ACCEPT: route=unlock' "$TAURI/src/lib.rs" || fail 'R53 Rust unlock route lost'
echo 'SAFEBOX_IOS_COLD_OPEN_R53_CAPTURE_UNCHANGED_R55_PASS'

[[ "$(shasum -a 256 "$ROOT/safebox-core/src/crypto.rs" | awk '{print $1}')" == 'd30d1530b38988e544f0aa25808b8048f88d1a9578036160fc7efa40c854a99c' ]] || fail 'crypto.rs changed'
[[ "$(shasum -a 256 "$ROOT/safebox-core/src/format.rs" | awk '{print $1}')" == '26edb67b2be91ff5c7d765e100e4aafa5e50933919c0db2e4370901f67205ea1' ]] || fail 'format.rs changed'
[[ "$(shasum -a 256 "$TAURI/ios-share/ShareViewController.swift" | awk '{print $1}')" == '47166d2c995f425cf427d4de81359a175f9d43f83b64021ecdd154a9c8af7410' ]] || fail 'R52 Share Extension changed'
[[ "$(shasum -a 256 "$TAURI/ios/SafeBoxShareInboxBridge.mm" | awk '{print $1}')" == '225a81c837d54f4e1b14c91125354ed6e9ab5e2af56d52c0a9f57c87f8b8075f' ]] || fail 'R52 Share Inbox bridge changed'
[[ "$(shasum -a 256 "$TAURI/ios/SafeBoxAdsBridge.mm" | awk '{print $1}')" == 'a408b55ec036ee71894853c144fc753e7a181eeaca7b5ae6872ec636dfc5e2ea' ]] || fail 'Ads bridge changed'
echo 'SAFEBOX_IOS_COLD_OPEN_SECURITY_INVARIANTS_R55_PASS'

echo 'IOS_V028_STATUS: DIRECT_SBX_SINGLE_REGISTRATION_R55_READY_FOR_RUNTIME_TEST'
echo 'SAFEBOX_V028_IOS_DIRECT_SBX_SINGLE_REGISTRATION_R55_VERIFY_PASS'
