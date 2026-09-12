#!/usr/bin/env bash
set -euo pipefail
ARM_FILE="${SAFEBOX_IOS_COLD_SHARE_ARM_FILE:-/tmp/safebox-ios-cold-share-arm-${UID}.json}"
EVIDENCE_FILE="${SAFEBOX_IOS_COLD_SHARE_EVIDENCE_FILE:-/tmp/safebox-ios-cold-share-evidence-${UID}.log}"
EVIDENCE_META="${SAFEBOX_IOS_COLD_SHARE_EVIDENCE_META:-/tmp/safebox-ios-cold-share-evidence-${UID}.json}"
RECEIPT_FILE="${SAFEBOX_IOS_COLD_SHARE_EVIDENCE_RECEIPT:-/tmp/safebox-ios-cold-share-evidence-${UID}.consumed.json}"
LEDGER_FILE="${SAFEBOX_IOS_EVIDENCE_LEDGER_FILE:-/tmp/safebox-ios-evidence-ledger-${UID}.json}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; APP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"; ROOT="$(cd "$APP_DIR/.." && pwd)"
CONTRACT_CHECK="$SCRIPT_DIR/ios_replay_recovery_contract_check.py"; VALIDATOR="$SCRIPT_DIR/ios_durable_evidence_validate.py"; LIFECYCLE="$SCRIPT_DIR/ios_evidence_lifecycle.py"; LEDGER="$SCRIPT_DIR/ios_evidence_ledger.py"
[[ -f "$ARM_FILE" ]] || { echo 'SAFEBOX_IOS_REPLAY_RECOVERY_RUNTIME_FAIL: cold-share arm metadata missing; run npm run ios:cold-share-arm first' >&2; exit 1; }
[[ ! -e "$RECEIPT_FILE" ]] || { echo 'SAFEBOX_IOS_REPLAY_RECOVERY_RUNTIME_FAIL: durable evidence already consumed; run a new ios:cold-share-arm transaction' >&2; exit 1; }
[[ -f "$EVIDENCE_FILE" && -f "$EVIDENCE_META" ]] || { echo 'SAFEBOX_IOS_REPLAY_RECOVERY_RUNTIME_FAIL: durable cold-share evidence missing; run a new arm/share followed immediately by npm run ios:cold-share-check' >&2; exit 1; }
FIELDS="$(python3 - "$ARM_FILE" "$EVIDENCE_META" <<'PY'
import json,shlex,sys
arm=json.load(open(sys.argv[1])); meta=json.load(open(sys.argv[2]))
print('ARMED_AT='+shlex.quote(str(arm['armed_at'])))
print('EXPECTED_ROUTE='+shlex.quote(str(arm['expected_route'])))
print('EVIDENCE_SHA256='+shlex.quote(str(meta.get('evidence_sha256',''))))
PY
)" || { echo 'SAFEBOX_IOS_REPLAY_RECOVERY_RUNTIME_FAIL: invalid durable evidence metadata' >&2; exit 1; }
eval "$FIELDS"
echo "SAFEBOX_IOS_REPLAY_RECOVERY_TRANSACTION_SCOPE: start=$ARMED_AT expected=$EXPECTED_ROUTE"
echo "SAFEBOX_IOS_REPLAY_RECOVERY_EVIDENCE_SHA256: $EVIDENCE_SHA256"
python3 "$VALIDATOR" "$ARM_FILE" "$EVIDENCE_META" "$EVIDENCE_FILE" "$ROOT/SAFEBOX_V028_PACKAGE_ID.txt" "$APP_DIR/src-tauri/ios/SafeBoxShareInboxBridge.mm" "$APP_DIR/src-tauri/src/lib.rs" "$EXPECTED_ROUTE" || { echo 'SAFEBOX_IOS_REPLAY_RECOVERY_RUNTIME_FAIL: durable evidence integrity/binding validation failed' >&2; exit 1; }
grep -E 'SAFEBOX_IOS_SHARE_(EXTENSION_STAGE_PASS|HARDENING_CLAIM_PASS|RECOVERY_|INBOX_(ACCEPT|DRAIN_PASS))' "$EVIDENCE_FILE" || true
python3 "$CONTRACT_CHECK" "$EVIDENCE_FILE" "$EXPECTED_ROUTE" || { echo 'SAFEBOX_IOS_REPLAY_RECOVERY_RUNTIME_FAIL: ACK/receipt/replay contract invalid' >&2; exit 1; }
python3 "$LIFECYCLE" consume "$ARM_FILE" "$EVIDENCE_META" "$EVIDENCE_FILE" "$RECEIPT_FILE" "$ROOT/SAFEBOX_V028_PACKAGE_ID.txt" "$APP_DIR/src-tauri/ios/SafeBoxShareInboxBridge.mm" "$APP_DIR/src-tauri/src/lib.rs" "$EXPECTED_ROUTE" || { echo 'SAFEBOX_IOS_REPLAY_RECOVERY_RUNTIME_FAIL: evidence consumption commit failed' >&2; exit 1; }
python3 "$LEDGER" record "$LEDGER_FILE" "$ARM_FILE" "$RECEIPT_FILE" "$ROOT/SAFEBOX_V028_PACKAGE_ID.txt" "$APP_DIR/src-tauri/ios/SafeBoxShareInboxBridge.mm" "$APP_DIR/src-tauri/src/lib.rs" "$EXPECTED_ROUTE" >/dev/null || { echo 'SAFEBOX_IOS_REPLAY_RECOVERY_RUNTIME_FAIL: bounded evidence ledger append failed; receipt remains authoritative and ios:evidence-ledger-check can reconcile' >&2; exit 1; }
echo 'SAFEBOX_IOS_REPLAY_RECOVERY_LEDGER_PASS'
echo 'SAFEBOX_IOS_REPLAY_RECOVERY_EVIDENCE_CONSUMED_PASS'
echo 'SAFEBOX_IOS_REPLAY_RECOVERY_DURABLE_EVIDENCE_PASS'
echo 'SAFEBOX_IOS_REPLAY_RECOVERY_TRANSACTION_SCOPE_PASS'
echo 'SAFEBOX_IOS_REPLAY_RECOVERY_ACK_RUNTIME_PASS'
echo 'SAFEBOX_IOS_REPLAY_RECOVERY_RECEIPT_RUNTIME_PASS'
echo 'SAFEBOX_IOS_REPLAY_RECOVERY_ZERO_REPLAY_RUNTIME_PASS'
echo 'SAFEBOX_IOS_REPLAY_RECOVERY_INTEGRITY_BINDING_PASS'
echo 'SAFEBOX_IOS_REPLAY_RECOVERY_RUNTIME_PASS'
