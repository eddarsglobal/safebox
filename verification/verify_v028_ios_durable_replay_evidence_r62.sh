#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/safebox-desktop"
BRIDGE="$APP/src-tauri/ios/SafeBoxShareInboxBridge.mm"
RUST="$APP/src-tauri/src/lib.rs"
ARM="$APP/scripts/ios_cold_share_arm.sh"
COLD_CHECK="$APP/scripts/ios_cold_share_check.sh"
REPLAY="$APP/scripts/ios_replay_recovery_check.sh"
PARSER="$APP/scripts/ios_replay_recovery_contract_check.py"
fail(){ echo "SAFEBOX_V028_R62_VERIFY_FAIL: $*" >&2; exit 1; }

grep -Fq 'v0.2.8-ios-durable-replay-evidence-r62-20260830A' "$ROOT/SAFEBOX_V028_PACKAGE_ID.txt" || fail 'package id mismatch'
[[ -x "$ARM" && -x "$COLD_CHECK" && -x "$REPLAY" && -x "$PARSER" ]] || fail 'runtime/checker script missing'
echo 'SAFEBOX_V028_R61_SCOPE_BASELINE_RETAINED_R62_PASS'

[[ "$(shasum -a 256 "$BRIDGE" | awk '{print $1}')" == 'da8b92247ee777a03770cc7df67b52b13a8981ca6987b70403fbd97e8913d9e4' ]] || fail 'R59 native recovery implementation changed'
[[ "$(shasum -a 256 "$RUST" | awk '{print $1}')" == '5a4bc10bc1d362a0737c0da2b0b6caad00436206137fd0fc800e2b842c57f297' ]] || fail 'R59 Rust recovery implementation changed'
echo 'SAFEBOX_IOS_REPLAY_R59_IMPLEMENTATION_UNCHANGED_R62_PASS'

grep -Fq 'SAFEBOX_IOS_COLD_SHARE_EVIDENCE_FILE' "$ARM" || fail 'arm evidence path missing'
grep -Fq 'rm -f "$EVIDENCE_FILE" "$EVIDENCE_META"' "$ARM" || fail 'new arm does not invalidate stale evidence'
grep -Fq 'SAFEBOX_IOS_COLD_SHARE_EVIDENCE_RESET_PASS' "$ARM" || fail 'arm reset marker missing'
grep -Fq 'SAFEBOX_IOS_COLD_SHARE_DURABLE_EVIDENCE_PASS' "$COLD_CHECK" || fail 'cold-share durable evidence marker missing'
grep -Fq "'SAFEBOX_IOS_SHARE_' in line" "$COLD_CHECK" || fail 'evidence not marker-filtered'
grep -Fq 'os.fchmod(fd,0o600)' "$COLD_CHECK" || fail '0600 temp evidence mode missing'
grep -Fq 'os.fsync(out.fileno())' "$COLD_CHECK" || fail 'evidence fsync missing'
grep -Fq 'os.replace(tmp,path)' "$COLD_CHECK" || fail 'atomic evidence replace missing'
grep -Fq "'evidence_sha256'" "$COLD_CHECK" || fail 'evidence sha metadata missing'
grep -Fq "'evidence_bytes'" "$COLD_CHECK" || fail 'evidence length metadata missing'
echo 'SAFEBOX_IOS_REPLAY_DURABLE_CAPTURE_R62_PASS'

grep -Fq 'durable cold-share evidence missing' "$REPLAY" || fail 'durable evidence requirement missing'
grep -Fq 'evidence does not match current arm' "$REPLAY" || fail 'arm/evidence binding missing'
grep -Fq 'evidence sha256 mismatch' "$REPLAY" || fail 'integrity check missing'
grep -Fq 'evidence length mismatch' "$REPLAY" || fail 'length check missing'
grep -Fq 'SAFEBOX_IOS_REPLAY_RECOVERY_DURABLE_EVIDENCE_PASS' "$REPLAY" || fail 'durable replay marker missing'
if grep -Fq 'xcrun simctl spawn' "$REPLAY"; then fail 'replay checker still depends on unified logging'; fi
echo 'SAFEBOX_IOS_REPLAY_DURABLE_CONSUMER_R62_PASS'

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
cat > "$TMP/evidence.log" <<'LOG'
2026-08-30 16:20:03.160 Df SafeBoxShareExtension[77558:b8da9] (Foundation) SAFEBOX_IOS_SHARE_EXTENSION_STAGE_PASS
2026-08-30 16:20:10.531 Df SafeBox[77573:b8e5e] (SafeBox.debug.dylib) SAFEBOX_IOS_SHARE_HARDENING_CLAIM_PASS
2026-08-30 16:20:10.539 Df SafeBox[77573:b8e5e] (SafeBox.debug.dylib) SAFEBOX_IOS_SHARE_RECOVERY_NATIVE_ACK_PASS
2026-08-30 16:20:10.541 Df SafeBox[77573:b8e5e] (SafeBox.debug.dylib) SAFEBOX_IOS_SHARE_RECOVERY_DELIVERY_RECEIPT_PASS
2026-08-30 16:20:10.543 Df SafeBox[77573:b8e5e] (SafeBox.debug.dylib) SAFEBOX_IOS_SHARE_INBOX_DRAIN_PASS count=1
2026-08-30 16:20:10.543 Df SafeBox[77573:b8e81] [com.safebox.desktop:app] [stderr] SAFEBOX_IOS_SHARE_INBOX_ACCEPT: route=unlock
2026-08-30 16:20:10.543 Df SafeBox[77573:b8e81] [com.safebox.desktop:app] [stderr] SAFEBOX_IOS_SHARE_RECOVERY_RUST_ACK_PASS: mode=live
2026-08-30 16:20:10.582 Df SafeBox[77573:b8e5e] (SafeBox.debug.dylib) SAFEBOX_IOS_SHARE_INBOX_DRAIN_PASS count=0
LOG
cat > "$TMP/arm.json" <<'JSON'
{"device_udid":"TEST-UDID","bundle_id":"com.safebox.desktop","process_name":"SafeBox","old_pid":73898,"armed_at":"2026-08-30 16:19:34","expected_route":"unlock"}
JSON
python3 - "$TMP/evidence.log" "$TMP/meta.json" <<'PY'
import hashlib,json,sys
body=open(sys.argv[1],'rb').read()
meta={'device_udid':'TEST-UDID','armed_at':'2026-08-30 16:19:34','expected_route':'unlock','old_pid':73898,'new_pid':77573,'evidence_sha256':hashlib.sha256(body).hexdigest(),'evidence_bytes':len(body)}
json.dump(meta,open(sys.argv[2],'w'))
PY
SAFEBOX_IOS_COLD_SHARE_ARM_FILE="$TMP/arm.json" SAFEBOX_IOS_COLD_SHARE_EVIDENCE_FILE="$TMP/evidence.log" SAFEBOX_IOS_COLD_SHARE_EVIDENCE_META="$TMP/meta.json" "$REPLAY" > "$TMP/pass.out" || fail 'durable reference evidence rejected'
grep -Fq 'SAFEBOX_IOS_REPLAY_RECOVERY_RUNTIME_PASS' "$TMP/pass.out" || fail 'runtime pass marker missing from durable reference'
echo 'SAFEBOX_IOS_REPLAY_DURABLE_REFERENCE_R62_PASS'

cp "$TMP/meta.json" "$TMP/stale.json"
python3 - "$TMP/stale.json" <<'PY'
import json,sys
p=sys.argv[1]; d=json.load(open(p)); d['armed_at']='2026-08-30 16:00:00'; json.dump(d,open(p,'w'))
PY
if SAFEBOX_IOS_COLD_SHARE_ARM_FILE="$TMP/arm.json" SAFEBOX_IOS_COLD_SHARE_EVIDENCE_FILE="$TMP/evidence.log" SAFEBOX_IOS_COLD_SHARE_EVIDENCE_META="$TMP/stale.json" "$REPLAY" >/dev/null 2>&1; then fail 'stale evidence accepted'; fi
cp "$TMP/evidence.log" "$TMP/corrupt.log"; printf 'tamper\n' >> "$TMP/corrupt.log"
if SAFEBOX_IOS_COLD_SHARE_ARM_FILE="$TMP/arm.json" SAFEBOX_IOS_COLD_SHARE_EVIDENCE_FILE="$TMP/corrupt.log" SAFEBOX_IOS_COLD_SHARE_EVIDENCE_META="$TMP/meta.json" "$REPLAY" >/dev/null 2>&1; then fail 'corrupted evidence accepted'; fi
rm -f "$TMP/missing.log"
if SAFEBOX_IOS_COLD_SHARE_ARM_FILE="$TMP/arm.json" SAFEBOX_IOS_COLD_SHARE_EVIDENCE_FILE="$TMP/missing.log" SAFEBOX_IOS_COLD_SHARE_EVIDENCE_META="$TMP/meta.json" "$REPLAY" >/dev/null 2>&1; then fail 'missing evidence accepted'; fi
echo 'SAFEBOX_IOS_REPLAY_DURABLE_NEGATIVE_TESTS_R62_PASS'

bash -n "$ARM" || fail 'arm shell syntax invalid'
bash -n "$COLD_CHECK" || fail 'cold check shell syntax invalid'
bash -n "$REPLAY" || fail 'replay shell syntax invalid'
python3 -m py_compile "$PARSER" || fail 'parser syntax invalid'
rm -rf "$APP/scripts/__pycache__"

[[ "$(shasum -a 256 "$APP/src-tauri/ios/SafeBoxAdsBridge.mm" | awk '{print $1}')" == 'a408b55ec036ee71894853c144fc753e7a181eeaca7b5ae6872ec636dfc5e2ea' ]] || fail 'Ads bridge changed'
[[ "$(shasum -a 256 "$APP/src-tauri/ios/SafeBoxColdOpenBridge.mm" | awk '{print $1}')" == '4712895a3941cb359bdb87a55f92c117af247393d5aa1db07b979bde6eb22f42' ]] || fail 'cold-open bridge changed'
[[ "$(shasum -a 256 "$ROOT/safebox-core/src/crypto.rs" | awk '{print $1}')" == 'd30d1530b38988e544f0aa25808b8048f88d1a9578036160fc7efa40c854a99c' ]] || fail 'crypto changed'
[[ "$(shasum -a 256 "$ROOT/safebox-core/src/format.rs" | awk '{print $1}')" == '26edb67b2be91ff5c7d765e100e4aafa5e50933919c0db2e4370901f67205ea1' ]] || fail 'format changed'
echo 'SAFEBOX_IOS_REPLAY_SECURITY_INVARIANTS_R62_PASS'

echo 'IOS_V028_STATUS: DURABLE_REPLAY_EVIDENCE_R62_READY_FOR_RUNTIME_TEST'
echo 'SAFEBOX_V028_IOS_DURABLE_REPLAY_EVIDENCE_R62_VERIFY_PASS'
