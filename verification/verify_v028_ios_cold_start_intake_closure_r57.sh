#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/safebox-desktop"
TAURI="$APP/src-tauri"
fail(){ echo "SAFEBOX_V028_R57_VERIFY_FAIL: $*" >&2; exit 1; }

grep -Fq 'v0.2.8-ios-cold-start-intake-closure-r57-20260830F' "$ROOT/SAFEBOX_V028_PACKAGE_ID.txt" || fail 'R57 package id mismatch'
[[ -x "$ROOT/verification/verify_v028_ios_direct_sbx_generated_registration_r56.sh" ]] || fail 'R56 verifier missing'
echo 'SAFEBOX_V028_R56_FOUNDATION_RETAINED_R57_PASS'

ARM="$APP/scripts/ios_cold_share_arm.sh"
CHECK="$APP/scripts/ios_cold_share_check.sh"
[[ -x "$ARM" && -x "$CHECK" ]] || fail 'cold-share runtime scripts missing'
grep -Fq 'SAFEBOX_IOS_COLD_SHARE_PROCESS_TERMINATED_PASS' "$ARM" || fail 'cold-share arm terminate gate missing'
grep -Fq 'SafeBoxShareExtension.appex' "$ARM" || fail 'cold-share arm does not verify extension'
grep -Fq 'SAFEBOX_IOS_SHARE_INBOX_DRAIN_REQUEST: trigger=setup' "$CHECK" || fail 'cold-share checker does not require setup drain'
grep -Fq 'SAFEBOX_IOS_COLD_SHARE_UNLOCK_PASS' "$CHECK" || fail 'cold-share unlock marker missing'
grep -Fq 'SAFEBOX_IOS_COLD_SHARE_RUNTIME_PASS' "$CHECK" || fail 'cold-share final marker missing'
python3 - "$APP/package.json" <<'PY'
import json,sys
s=json.load(open(sys.argv[1]))['scripts']
assert s['ios:cold-share-arm']=='bash scripts/ios_cold_share_arm.sh'
assert s['ios:cold-share-check']=='bash scripts/ios_cold_share_check.sh'
PY
echo 'SAFEBOX_IOS_COLD_SHARE_RUNTIME_GATE_R57_PASS'

OPEN_ARM="$APP/scripts/ios_cold_open_arm.sh"
OPEN_CHECK="$APP/scripts/ios_cold_open_check.sh"
grep -Fq 'SAFEBOX_IOS_COLD_OPEN_HANDLER_MODE: OPEN_WITH' "$OPEN_ARM" || fail 'Open With handler mode missing'
grep -Fq 'LONG-PRESS' "$OPEN_ARM" || fail 'Open With instruction missing'
grep -Fq 'SAFEBOX_IOS_COLD_OPEN_FILES_PREVIEW_NO_DISPATCH' "$OPEN_CHECK" || fail 'Files preview diagnostic missing'
grep -Fq 'SAFEBOX_IOS_COLD_OPEN_OPEN_WITH_REQUIRED' "$OPEN_CHECK" || fail 'Open With diagnostic missing'
echo 'SAFEBOX_IOS_COLD_OPEN_PLATFORM_CONTRACT_R57_PASS'

# R57 must not modify validated implementation surfaces.
[[ "$(shasum -a 256 "$TAURI/ios/SafeBoxColdOpenBridge.mm" | awk '{print $1}')" == '4712895a3941cb359bdb87a55f92c117af247393d5aa1db07b979bde6eb22f42' ]] || fail 'R53 cold-open bridge changed'
[[ "$(shasum -a 256 "$TAURI/ios-share/ShareViewController.swift" | awk '{print $1}')" == '47166d2c995f425cf427d4de81359a175f9d43f83b64021ecdd154a9c8af7410' ]] || fail 'R52 Share Extension changed'
[[ "$(shasum -a 256 "$TAURI/ios/SafeBoxShareInboxBridge.mm" | awk '{print $1}')" == '225a81c837d54f4e1b14c91125354ed6e9ab5e2af56d52c0a9f57c87f8b8075f' ]] || fail 'R52 Share bridge changed'
[[ "$(shasum -a 256 "$TAURI/ios/SafeBoxAdsBridge.mm" | awk '{print $1}')" == 'a408b55ec036ee71894853c144fc753e7a181eeaca7b5ae6872ec636dfc5e2ea' ]] || fail 'Ads bridge changed'
[[ "$(shasum -a 256 "$ROOT/safebox-core/src/crypto.rs" | awk '{print $1}')" == 'd30d1530b38988e544f0aa25808b8048f88d1a9578036160fc7efa40c854a99c' ]] || fail 'crypto.rs changed'
[[ "$(shasum -a 256 "$ROOT/safebox-core/src/format.rs" | awk '{print $1}')" == '26edb67b2be91ff5c7d765e100e4aafa5e50933919c0db2e4370901f67205ea1' ]] || fail 'format.rs changed'
echo 'SAFEBOX_IOS_COLD_START_SECURITY_INVARIANTS_R57_PASS'

echo 'IOS_V028_STATUS: COLD_START_INTAKE_CLOSURE_R57_READY_FOR_RUNTIME_TEST'
echo 'SAFEBOX_V028_IOS_COLD_START_INTAKE_CLOSURE_R57_VERIFY_PASS'
