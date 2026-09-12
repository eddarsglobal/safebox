#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/safebox-desktop"
TAURI="$APP/src-tauri"
BRIDGE="$TAURI/ios/SafeBoxShareInboxBridge.mm"
RUST="$TAURI/src/lib.rs"
CHECK="$APP/scripts/ios_replay_recovery_check.sh"
fail(){ echo "SAFEBOX_V028_R59_VERIFY_FAIL: $*" >&2; exit 1; }

grep -Fq 'v0.2.8-ios-replay-crash-recovery-r59-20260830A' "$ROOT/SAFEBOX_V028_PACKAGE_ID.txt" || fail 'package id mismatch'
[[ -x "$ROOT/verification/verify_v028_ios_intake_hardening_r58.sh" ]] || fail 'R58 verifier missing'
[[ -x "$CHECK" ]] || fail 'R59 runtime checker missing'
echo 'SAFEBOX_V028_R58_RUNTIME_BASELINE_RETAINED_R59_PASS'

grep -Fq '#include <stdint.h>' "$BRIDGE" || fail 'stdint include missing'
grep -Fq 'extern "C" uint8_t safebox_ios_share_inbox_accept' "$BRIDGE" || fail 'native ACK declaration missing'
grep -Fq 'uint8_t deliveryAck = safebox_ios_share_inbox_accept(path)' "$BRIDGE" || fail 'native ACK capture missing'
grep -Fq 'pub unsafe extern "C" fn safebox_ios_share_inbox_accept(' "$RUST" || fail 'Rust accept missing'
grep -Fq ') -> u8 {' "$RUST" || fail 'Rust ACK return type missing'
grep -Fq 'SAFEBOX_IOS_SHARE_RECOVERY_RUST_ACK_PASS' "$RUST" || fail 'Rust ACK marker missing'
grep -Fq 'SAFEBOX_IOS_SHARE_RECOVERY_RUST_NACK' "$RUST" || fail 'Rust NACK marker missing'
echo 'SAFEBOX_IOS_REPLAY_EXPLICIT_ACK_ABI_R59_PASS'

grep -Fq 'SBXWriteCommitMarker' "$BRIDGE" || fail 'commit marker writer missing'
grep -Fq '@"DELIVERED"' "$BRIDGE" || fail 'DELIVERED receipt missing'
grep -Fq 'SAFEBOX_IOS_SHARE_RECOVERY_DELIVERY_RECEIPT_PASS' "$BRIDGE" || fail 'receipt marker missing'
grep -Fq 'SAFEBOX_IOS_SHARE_RECOVERY_RECEIPT_FAIL' "$BRIDGE" || fail 'receipt fail marker missing'
grep -Fq 'SBXCleanupProcessing(processing)' "$BRIDGE" || fail 'processing recovery cleanup missing'
grep -Fq 'Unacknowledged crash claims are fail-closed' "$BRIDGE" || fail 'unacked crash policy missing'
python3 - "$BRIDGE" <<'PY'
import sys
s=open(sys.argv[1]).read()
a=s.index('uint8_t deliveryAck = safebox_ios_share_inbox_accept(path)')
b=s.index('SBXWriteCommitMarker(delivered)',a)
c=s.index('[fm removeItemAtURL:claimed error:nil]',b)
assert a < b < c
PY
echo 'SAFEBOX_IOS_REPLAY_CRASH_RECEIPT_R59_PASS'

grep -Fq 'SAFEBOX_IOS_SHARE_RECOVERY_NATIVE_NACK_PASS' "$BRIDGE" || fail 'native NACK marker missing'
grep -Fq 'Keep the unacknowledged claim fail-closed' "$BRIDGE" || fail 'NACK fail-closed comment missing'
echo 'SAFEBOX_IOS_REPLAY_NACK_FAIL_CLOSED_R59_PASS'

for token in \
  'SAFEBOX_IOS_SHARE_RECOVERY_RUST_ACK_PASS' \
  'SAFEBOX_IOS_SHARE_RECOVERY_NATIVE_ACK_PASS' \
  'SAFEBOX_IOS_SHARE_RECOVERY_DELIVERY_RECEIPT_PASS' \
  'SAFEBOX_IOS_SHARE_INBOX_DRAIN_PASS count=1' \
  'SAFEBOX_IOS_SHARE_INBOX_DRAIN_PASS count=0' \
  'SAFEBOX_IOS_REPLAY_RECOVERY_RUNTIME_PASS'; do
  grep -Fq "$token" "$CHECK" || fail "runtime checker missing: $token"
done
python3 - "$APP/package.json" <<'PY'
import json,sys
s=json.load(open(sys.argv[1]))['scripts']
assert s['ios:replay-recovery-check']=='bash scripts/ios_replay_recovery_check.sh'
PY
echo 'SAFEBOX_IOS_REPLAY_RUNTIME_GATE_R59_PASS'

[[ "$(shasum -a 256 "$TAURI/ios/SafeBoxAdsBridge.mm" | awk '{print $1}')" == 'a408b55ec036ee71894853c144fc753e7a181eeaca7b5ae6872ec636dfc5e2ea' ]] || fail 'Ads bridge changed'
[[ "$(shasum -a 256 "$TAURI/ios/SafeBoxColdOpenBridge.mm" | awk '{print $1}')" == '4712895a3941cb359bdb87a55f92c117af247393d5aa1db07b979bde6eb22f42' ]] || fail 'cold-open bridge changed'
[[ "$(shasum -a 256 "$ROOT/safebox-core/src/crypto.rs" | awk '{print $1}')" == 'd30d1530b38988e544f0aa25808b8048f88d1a9578036160fc7efa40c854a99c' ]] || fail 'crypto.rs changed'
[[ "$(shasum -a 256 "$ROOT/safebox-core/src/format.rs" | awk '{print $1}')" == '26edb67b2be91ff5c7d765e100e4aafa5e50933919c0db2e4370901f67205ea1' ]] || fail 'format.rs changed'
if grep -Eq 'NSLog\([^\n]*(lastPathComponent|\.path|absoluteString)' "$BRIDGE"; then fail 'sensitive native logging detected'; fi
echo 'SAFEBOX_IOS_REPLAY_SECURITY_INVARIANTS_R59_PASS'

echo 'IOS_V028_STATUS: REPLAY_CRASH_RECOVERY_R59_READY_FOR_RUNTIME_TEST'
echo 'SAFEBOX_V028_IOS_REPLAY_CRASH_RECOVERY_R59_VERIFY_PASS'
