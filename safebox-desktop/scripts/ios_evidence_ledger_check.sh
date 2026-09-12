#!/usr/bin/env bash
set -euo pipefail
ARM_FILE="${SAFEBOX_IOS_COLD_SHARE_ARM_FILE:-/tmp/safebox-ios-cold-share-arm-${UID}.json}"
RECEIPT_FILE="${SAFEBOX_IOS_COLD_SHARE_EVIDENCE_RECEIPT:-/tmp/safebox-ios-cold-share-evidence-${UID}.consumed.json}"
LEDGER_FILE="${SAFEBOX_IOS_EVIDENCE_LEDGER_FILE:-/tmp/safebox-ios-evidence-ledger-${UID}.json}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; APP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"; ROOT="$(cd "$APP_DIR/.." && pwd)"
LEDGER="$SCRIPT_DIR/ios_evidence_ledger.py"
[[ -f "$ARM_FILE" && -f "$RECEIPT_FILE" ]] || { echo 'SAFEBOX_IOS_EVIDENCE_LEDGER_RUNTIME_FAIL: current consumed transaction missing' >&2; exit 1; }
ROUTE="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["expected_route"])' "$ARM_FILE")" || { echo 'SAFEBOX_IOS_EVIDENCE_LEDGER_RUNTIME_FAIL: invalid arm metadata' >&2; exit 1; }
# Idempotent reconciliation: if receipt commit succeeded but ledger append was interrupted, this repairs it safely.
python3 "$LEDGER" record "$LEDGER_FILE" "$ARM_FILE" "$RECEIPT_FILE" "$ROOT/SAFEBOX_V028_PACKAGE_ID.txt" "$APP_DIR/src-tauri/ios/SafeBoxShareInboxBridge.mm" "$APP_DIR/src-tauri/src/lib.rs" "$ROUTE" >/dev/null || { echo 'SAFEBOX_IOS_EVIDENCE_LEDGER_RUNTIME_FAIL: ledger reconciliation failed' >&2; exit 1; }
python3 "$LEDGER" verify "$LEDGER_FILE" "$ARM_FILE" "$RECEIPT_FILE" "$ROOT/SAFEBOX_V028_PACKAGE_ID.txt" "$APP_DIR/src-tauri/ios/SafeBoxShareInboxBridge.mm" "$APP_DIR/src-tauri/src/lib.rs" "$ROUTE" || { echo 'SAFEBOX_IOS_EVIDENCE_LEDGER_RUNTIME_FAIL: ledger validation failed' >&2; exit 1; }
echo 'SAFEBOX_IOS_EVIDENCE_LEDGER_RUNTIME_PASS'
