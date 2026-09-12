#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"; APP="$ROOT/safebox-desktop"
LEDGER="$APP/scripts/ios_evidence_ledger.py"; LEDGERCHECK="$APP/scripts/ios_evidence_ledger_check.sh"; REPLAY="$APP/scripts/ios_replay_recovery_check.sh"; ARM="$APP/scripts/ios_cold_share_arm.sh"; LIFE="$APP/scripts/ios_evidence_lifecycle.py"; LIFECHECK="$APP/scripts/ios_evidence_lifecycle_check.sh"
BRIDGE="$APP/src-tauri/ios/SafeBoxShareInboxBridge.mm"; RUST="$APP/src-tauri/src/lib.rs"
fail(){ echo "SAFEBOX_V028_R65_VERIFY_FAIL: $*" >&2; exit 1; }
grep -Fq 'v0.2.8-ios-evidence-ledger-r65-20260830A' "$ROOT/SAFEBOX_V028_PACKAGE_ID.txt" || fail package-id
echo 'SAFEBOX_V028_R64_RUNTIME_BASELINE_RETAINED_R65_PASS'
[[ "$(shasum -a 256 "$BRIDGE"|awk '{print $1}')" == da8b92247ee777a03770cc7df67b52b13a8981ca6987b70403fbd97e8913d9e4 ]] || fail bridge-changed
[[ "$(shasum -a 256 "$RUST"|awk '{print $1}')" == 5a4bc10bc1d362a0737c0da2b0b6caad00436206137fd0fc800e2b842c57f297 ]] || fail rust-changed
[[ "$(shasum -a 256 "$APP/src-tauri/ios-share/ShareViewController.swift"|awk '{print $1}')" == c868a61f534a425eabf3bea9adeb591474823053ecd582c799a1cafba4da59a4 ]] || fail extension-changed
echo 'SAFEBOX_IOS_RUNTIME_IMPLEMENTATION_UNCHANGED_R65_PASS'
for f in "$LEDGERCHECK" "$REPLAY" "$ARM" "$LIFECHECK"; do bash -n "$f" || fail shell; done
python3 -m py_compile "$LEDGER" "$LIFE" "$APP/scripts/ios_durable_evidence_validate.py" "$APP/scripts/ios_replay_recovery_contract_check.py"; rm -rf "$APP/scripts/__pycache__"
grep -Fq 'CAPACITY = 32' "$LEDGER" || fail capacity
grep -Fq 'MAX_BYTES = 131072' "$LEDGER" || fail byte-cap
grep -Fq 'SAFEBOX_IOS_REPLAY_RECOVERY_LEDGER_PASS' "$REPLAY" || fail replay-ledger-marker
grep -Fq 'ios:evidence-ledger-check' "$APP/package.json" || fail npm-gate
grep -Fq 'SAFEBOX_IOS_COLD_SHARE_LEDGER_CONTINUITY_PASS' "$ARM" || fail continuity-marker
grep -Fq 'ledger contains path/URL/SBX-like value' "$LEDGER" || fail privacy-guard
echo 'SAFEBOX_IOS_EVIDENCE_LEDGER_POLICY_R65_PASS'
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
export SAFEBOX_IOS_COLD_SHARE_ARM_FILE="$TMP/arm.json" SAFEBOX_IOS_COLD_SHARE_EVIDENCE_FILE="$TMP/evidence.log" SAFEBOX_IOS_COLD_SHARE_EVIDENCE_META="$TMP/meta.json" SAFEBOX_IOS_COLD_SHARE_EVIDENCE_RECEIPT="$TMP/receipt.json" SAFEBOX_IOS_EVIDENCE_LEDGER_FILE="$TMP/ledger.json"
# Build a valid full 32-entry ledger directly, then record one valid receipt to force one bounded rotation.
python3 - "$TMP" "$ROOT/SAFEBOX_V028_PACKAGE_ID.txt" "$BRIDGE" "$RUST" <<'PYLEDGER'
import hashlib,json,os,sys,time
from pathlib import Path
t=Path(sys.argv[1]); pkg=Path(sys.argv[2]).read_text().strip(); bridge=Path(sys.argv[3]); rust=Path(sys.argv[4]); now=int(time.time()); h=hashlib.sha256()
canon=lambda o:(json.dumps(o,sort_keys=True,separators=(',',':'))+'\n').encode()
sha=lambda b:hashlib.sha256(b).hexdigest()
for label,p in ((b'SafeBoxShareInboxBridge.mm\0',bridge),(b'lib.rs\0',rust)): h.update(label); h.update(p.read_bytes()); h.update(b'\0')
rh=h.hexdigest(); zero='0'*64; prev=zero; entries=[]
for i in range(1,33):
    e={'schema_version':1,'seq':i,'event':'consumed','route':'unlock','package_id':pkg,'runtime_contract_sha256':rh,'consumed_unix':now-100+i,'transaction_sha256':sha(f'tx-{i}'.encode()),'receipt_sha256':sha(f'receipt-{i}'.encode()),'prev_hash':prev}; e['entry_hash']=sha(canon(e)); entries.append(e); prev=e['entry_hash']
ledger={'schema_version':1,'capacity':32,'anchor_hash':zero,'head_hash':prev,'next_seq':33,'updated_unix':now,'entries':entries}; ledger['ledger_seal_sha256']=sha(canon(ledger)); (t/'ledger.json').write_bytes(canon(ledger)); os.chmod(t/'ledger.json',0o600)
arm={'schema_version':2,'device_udid':'SECRET-DEVICE-33','bundle_id':'com.safebox.desktop','process_name':'SECRET-PROCESS','old_pid':133,'armed_at':'2026-08-30 19:33:00','armed_unix':now-10,'expected_route':'unlock','package_id':pkg,'runtime_contract_sha256':rh}; ab=canon(arm); (t/'arm.json').write_bytes(ab); os.chmod(t/'arm.json',0o600)
r={'schema_version':1,'device_udid':arm['device_udid'],'bundle_id':arm['bundle_id'],'process_name':arm['process_name'],'armed_at':arm['armed_at'],'armed_unix':arm['armed_unix'],'expected_route':'unlock','package_id':pkg,'runtime_contract_sha256':rh,'arm_sha256':sha(ab),'evidence_sha256':sha(b'evidence-33'),'manifest_seal_sha256':sha(b'manifest-33'),'old_pid':133,'new_pid':233,'captured_unix':now-2,'consumed_unix':now-1,'expires_unix':now-1+86400}; r['receipt_seal_sha256']=sha(canon(r)+ab); (t/'receipt.json').write_bytes(canon(r)); os.chmod(t/'receipt.json',0o600)
PYLEDGER
python3 "$LEDGER" record "$TMP/ledger.json" "$TMP/arm.json" "$TMP/receipt.json" "$ROOT/SAFEBOX_V028_PACKAGE_ID.txt" "$BRIDGE" "$RUST" unlock >/dev/null || fail record-rotation
python3 "$LEDGER" inspect "$TMP/ledger.json" > "$TMP/inspect.out" || fail inspect
python3 - "$TMP/ledger.json" <<'PYCHECK'
import json,sys
p=json.load(open(sys.argv[1])); assert len(p['entries'])==32; assert p['entries'][0]['seq']==2; assert p['entries'][-1]['seq']==33; assert p['next_seq']==34; assert p['anchor_hash']==p['entries'][0]['prev_hash']
text=open(sys.argv[1]).read(); assert 'SECRET-DEVICE' not in text and 'SECRET-PROCESS' not in text and 'com.safebox.desktop' not in text
PYCHECK
echo 'SAFEBOX_IOS_EVIDENCE_LEDGER_ROTATION_REFERENCE_R65_PASS'
# Current transaction verification and idempotent reconciliation.
python3 "$LEDGER" verify "$TMP/ledger.json" "$TMP/arm.json" "$TMP/receipt.json" "$ROOT/SAFEBOX_V028_PACKAGE_ID.txt" "$BRIDGE" "$RUST" unlock > "$TMP/verify.out" || fail verify-current
before="$(python3 -c 'import json,sys; print(len(json.load(open(sys.argv[1]))["entries"]))' "$TMP/ledger.json")"
python3 "$LEDGER" record "$TMP/ledger.json" "$TMP/arm.json" "$TMP/receipt.json" "$ROOT/SAFEBOX_V028_PACKAGE_ID.txt" "$BRIDGE" "$RUST" unlock > "$TMP/idempotent.out" || fail idempotent
after="$(python3 -c 'import json,sys; print(len(json.load(open(sys.argv[1]))["entries"]))' "$TMP/ledger.json")"
[[ "$before" == "$after" ]] || fail duplicate-appended
grep -Fq SAFEBOX_IOS_EVIDENCE_LEDGER_IDEMPOTENT_PASS "$TMP/idempotent.out" || fail idempotent-marker
echo 'SAFEBOX_IOS_EVIDENCE_LEDGER_IDEMPOTENT_REFERENCE_R65_PASS'
# Tamper and unsafe-mode rejection.
cp "$TMP/ledger.json" "$TMP/ledger.good"; printf x >> "$TMP/ledger.json"
if python3 "$LEDGER" inspect "$TMP/ledger.json" >/dev/null 2>&1; then fail tampered-ledger-accepted; fi
mv "$TMP/ledger.good" "$TMP/ledger.json"; chmod 644 "$TMP/ledger.json"
if python3 "$LEDGER" inspect "$TMP/ledger.json" >/dev/null 2>&1; then fail broad-ledger-mode-accepted; fi
chmod 600 "$TMP/ledger.json"
# Inject forbidden identifying field with a recomputed outer seal: privacy guard must still reject.
python3 - "$TMP/ledger.json" <<'PY'
import hashlib,json,sys
p=sys.argv[1]; d=json.load(open(p)); d['device_udid']='SECRET-DEVICE-INJECTED'; d.pop('ledger_seal_sha256',None); canon=lambda o:(json.dumps(o,sort_keys=True,separators=(',',':'))+'\n').encode(); d['ledger_seal_sha256']=hashlib.sha256(canon(d)).hexdigest(); open(p,'wb').write(canon(d))
PY
chmod 600 "$TMP/ledger.json"
if python3 "$LEDGER" inspect "$TMP/ledger.json" >/dev/null 2>&1; then fail privacy-injection-accepted; fi
echo 'SAFEBOX_IOS_EVIDENCE_LEDGER_NEGATIVE_TESTS_R65_PASS'
[[ "$(shasum -a 256 "$APP/src-tauri/ios/SafeBoxAdsBridge.mm"|awk '{print $1}')" == a408b55ec036ee71894853c144fc753e7a181eeaca7b5ae6872ec636dfc5e2ea ]] || fail ads
[[ "$(shasum -a 256 "$APP/src-tauri/ios/SafeBoxColdOpenBridge.mm"|awk '{print $1}')" == 4712895a3941cb359bdb87a55f92c117af247393d5aa1db07b979bde6eb22f42 ]] || fail cold-open
[[ "$(shasum -a 256 "$ROOT/safebox-core/src/crypto.rs"|awk '{print $1}')" == d30d1530b38988e544f0aa25808b8048f88d1a9578036160fc7efa40c854a99c ]] || fail crypto
[[ "$(shasum -a 256 "$ROOT/safebox-core/src/format.rs"|awk '{print $1}')" == 26edb67b2be91ff5c7d765e100e4aafa5e50933919c0db2e4370901f67205ea1 ]] || fail format
echo 'SAFEBOX_IOS_EVIDENCE_LEDGER_SECURITY_INVARIANTS_R65_PASS'
echo 'SAFEBOX_V028_IOS_EVIDENCE_LEDGER_R65_VERIFY_PASS'
