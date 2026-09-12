#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"; APP="$ROOT/safebox-desktop"
ARM="$APP/scripts/ios_cold_share_arm.sh"; REPLAY="$APP/scripts/ios_replay_recovery_check.sh"; EVC="$APP/scripts/ios_evidence_integrity_check.sh"; LIFE="$APP/scripts/ios_evidence_lifecycle.py"; LIFECHECK="$APP/scripts/ios_evidence_lifecycle_check.sh"; VAL="$APP/scripts/ios_durable_evidence_validate.py"
BRIDGE="$APP/src-tauri/ios/SafeBoxShareInboxBridge.mm"; RUST="$APP/src-tauri/src/lib.rs"
fail(){ echo "SAFEBOX_V028_R64_VERIFY_FAIL: $*" >&2; exit 1; }
grep -Fq 'v0.2.8-ios-evidence-single-use-lifecycle-r64-20260830A' "$ROOT/SAFEBOX_V028_PACKAGE_ID.txt" || fail package-id
echo 'SAFEBOX_V028_R63_RUNTIME_BASELINE_RETAINED_R64_PASS'
[[ "$(shasum -a 256 "$BRIDGE"|awk '{print $1}')" == da8b92247ee777a03770cc7df67b52b13a8981ca6987b70403fbd97e8913d9e4 ]] || fail bridge-changed
[[ "$(shasum -a 256 "$RUST"|awk '{print $1}')" == 5a4bc10bc1d362a0737c0da2b0b6caad00436206137fd0fc800e2b842c57f297 ]] || fail rust-changed
[[ "$(shasum -a 256 "$APP/src-tauri/ios-share/ShareViewController.swift"|awk '{print $1}')" == c868a61f534a425eabf3bea9adeb591474823053ecd582c799a1cafba4da59a4 ]] || fail extension-changed
echo 'SAFEBOX_IOS_RUNTIME_IMPLEMENTATION_UNCHANGED_R64_PASS'
for f in "$ARM" "$REPLAY" "$EVC" "$LIFECHECK"; do bash -n "$f" || fail shell; done
python3 -m py_compile "$LIFE" "$VAL" "$APP/scripts/ios_replay_recovery_contract_check.py"; rm -rf "$APP/scripts/__pycache__"
grep -Fq 'durable evidence already consumed' "$REPLAY" || fail replay-single-use-guard
grep -Fq '"$LIFECYCLE" consume' "$REPLAY" || fail consume-commit
grep -Fq 'SAFEBOX_IOS_REPLAY_RECOVERY_EVIDENCE_CONSUMED_PASS' "$REPLAY" || fail consumed-marker
grep -Fq 'SAFEBOX_IOS_COLD_SHARE_EVIDENCE_ROTATION_PASS' "$ARM" || fail rotation-marker
grep -Fq 'receipt_seal_sha256' "$LIFE" || fail receipt-seal
grep -Fq 'ev_p.unlink(); meta_p.unlink()' "$LIFE" || fail retirement
grep -Fq 'If retirement is interrupted, reuse remains blocked' "$LIFE" || fail commit-comment
grep -Fq 'ios:evidence-lifecycle-check' "$APP/package.json" || fail npm-gate
echo 'SAFEBOX_IOS_EVIDENCE_SINGLE_USE_POLICY_R64_PASS'
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
cat > "$TMP/evidence.log" <<'LOG'
2026 Df SafeBoxShareExtension[1:a] (Foundation) SAFEBOX_IOS_SHARE_EXTENSION_STAGE_PASS
2026 Df SafeBox[2:b] (SafeBox.debug.dylib) SAFEBOX_IOS_SHARE_HARDENING_CLAIM_PASS
2026 Df SafeBox[2:c] [stderr] SAFEBOX_IOS_SHARE_INBOX_ACCEPT: route=unlock
2026 Df SafeBox[2:c] [stderr] SAFEBOX_IOS_SHARE_RECOVERY_RUST_ACK_PASS: mode=live
2026 Df SafeBox[2:b] (SafeBox.debug.dylib) SAFEBOX_IOS_SHARE_RECOVERY_NATIVE_ACK_PASS
2026 Df SafeBox[2:b] (SafeBox.debug.dylib) SAFEBOX_IOS_SHARE_RECOVERY_DELIVERY_RECEIPT_PASS
2026 Df SafeBox[2:b] (SafeBox.debug.dylib) SAFEBOX_IOS_SHARE_INBOX_DRAIN_PASS count=1
2026 Df SafeBox[2:b] (SafeBox.debug.dylib) SAFEBOX_IOS_SHARE_INBOX_DRAIN_PASS count=0
LOG
python3 - "$TMP" "$ROOT/SAFEBOX_V028_PACKAGE_ID.txt" "$BRIDGE" "$RUST" <<'PY'
import hashlib,json,os,sys,time
from pathlib import Path
t=Path(sys.argv[1]); pkg=Path(sys.argv[2]).read_text().strip(); bridge=Path(sys.argv[3]); rust=Path(sys.argv[4]); now=int(time.time()); h=hashlib.sha256()
for label,p in ((b'SafeBoxShareInboxBridge.mm\0',bridge),(b'lib.rs\0',rust)): h.update(label); h.update(p.read_bytes()); h.update(b'\0')
r=h.hexdigest(); arm={'schema_version':2,'device_udid':'TEST','bundle_id':'com.safebox.desktop','process_name':'SafeBox','old_pid':1,'armed_at':'2026-08-30 18:55:46','armed_unix':now-20,'expected_route':'unlock','package_id':pkg,'runtime_contract_sha256':r}; ab=(json.dumps(arm,sort_keys=True,separators=(',',':'))+'\n').encode(); (t/'arm.json').write_bytes(ab); os.chmod(t/'arm.json',0o600); os.chmod(t/'evidence.log',0o600); body=(t/'evidence.log').read_bytes(); meta={'schema_version':2,'device_udid':'TEST','bundle_id':'com.safebox.desktop','process_name':'SafeBox','armed_at':arm['armed_at'],'armed_unix':arm['armed_unix'],'expected_route':'unlock','package_id':pkg,'runtime_contract_sha256':r,'arm_sha256':hashlib.sha256(ab).hexdigest(),'old_pid':1,'new_pid':2,'captured_unix':now,'expires_unix':now+86400,'evidence_sha256':hashlib.sha256(body).hexdigest(),'evidence_bytes':len(body)}; seal=(json.dumps(meta,sort_keys=True,separators=(',',':'))+'\n').encode()+body+ab; meta['manifest_seal_sha256']=hashlib.sha256(seal).hexdigest(); (t/'meta.json').write_text(json.dumps(meta,sort_keys=True,separators=(',',':'))+'\n'); os.chmod(t/'meta.json',0o600)
PY
export SAFEBOX_IOS_COLD_SHARE_ARM_FILE="$TMP/arm.json" SAFEBOX_IOS_COLD_SHARE_EVIDENCE_FILE="$TMP/evidence.log" SAFEBOX_IOS_COLD_SHARE_EVIDENCE_META="$TMP/meta.json" SAFEBOX_IOS_COLD_SHARE_EVIDENCE_RECEIPT="$TMP/receipt.json"
"$EVC" > "$TMP/integrity.out" || fail valid-integrity
"$REPLAY" > "$TMP/replay.out" || fail replay-consume
grep -Fq SAFEBOX_IOS_REPLAY_RECOVERY_EVIDENCE_CONSUMED_PASS "$TMP/replay.out" || fail replay-consumed-marker
[[ ! -e "$TMP/evidence.log" && ! -e "$TMP/meta.json" && -f "$TMP/receipt.json" ]] || fail retirement-state
"$LIFECHECK" > "$TMP/lifecycle.out" || fail lifecycle-verify
grep -Fq SAFEBOX_IOS_EVIDENCE_SINGLE_USE_PASS "$TMP/lifecycle.out" || fail single-use-marker
grep -Fq SAFEBOX_IOS_EVIDENCE_LIFECYCLE_RUNTIME_PASS "$TMP/lifecycle.out" || fail lifecycle-marker
if "$REPLAY" >"$TMP/replay2.out" 2>&1; then fail second-replay-accepted; fi
grep -Fq 'durable evidence already consumed' "$TMP/replay2.out" || fail second-replay-reason
echo 'SAFEBOX_IOS_EVIDENCE_SINGLE_USE_REFERENCE_R64_PASS'
cp "$TMP/receipt.json" "$TMP/receipt.good"; printf x >> "$TMP/receipt.json"
if "$LIFECHECK" >/dev/null 2>&1; then fail tampered-receipt-accepted; fi
mv "$TMP/receipt.good" "$TMP/receipt.json"; chmod 644 "$TMP/receipt.json"
if "$LIFECHECK" >/dev/null 2>&1; then fail broad-receipt-mode-accepted; fi
chmod 600 "$TMP/receipt.json"
python3 "$LIFE" reset "$TMP/arm.json" "$TMP/meta.json" "$TMP/evidence.log" "$TMP/receipt.json" > "$TMP/reset.out" || fail reset
[[ ! -e "$TMP/receipt.json" ]] || fail receipt-not-rotated
grep -Fq SAFEBOX_IOS_EVIDENCE_ROTATION_RESET_PASS "$TMP/reset.out" || fail reset-marker
echo 'SAFEBOX_IOS_EVIDENCE_NEGATIVE_LIFECYCLE_TESTS_R64_PASS'
[[ "$(shasum -a 256 "$APP/src-tauri/ios/SafeBoxAdsBridge.mm"|awk '{print $1}')" == a408b55ec036ee71894853c144fc753e7a181eeaca7b5ae6872ec636dfc5e2ea ]] || fail ads
[[ "$(shasum -a 256 "$APP/src-tauri/ios/SafeBoxColdOpenBridge.mm"|awk '{print $1}')" == 4712895a3941cb359bdb87a55f92c117af247393d5aa1db07b979bde6eb22f42 ]] || fail cold-open
[[ "$(shasum -a 256 "$ROOT/safebox-core/src/crypto.rs"|awk '{print $1}')" == d30d1530b38988e544f0aa25808b8048f88d1a9578036160fc7efa40c854a99c ]] || fail crypto
[[ "$(shasum -a 256 "$ROOT/safebox-core/src/format.rs"|awk '{print $1}')" == 26edb67b2be91ff5c7d765e100e4aafa5e50933919c0db2e4370901f67205ea1 ]] || fail format
echo 'SAFEBOX_IOS_EVIDENCE_SECURITY_INVARIANTS_R64_PASS'
echo 'SAFEBOX_V028_IOS_EVIDENCE_SINGLE_USE_LIFECYCLE_R64_VERIFY_PASS'
