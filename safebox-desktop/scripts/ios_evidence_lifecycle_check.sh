#!/usr/bin/env bash
set -euo pipefail
ARM_FILE="${SAFEBOX_IOS_COLD_SHARE_ARM_FILE:-/tmp/safebox-ios-cold-share-arm-${UID}.json}"
EVIDENCE_FILE="${SAFEBOX_IOS_COLD_SHARE_EVIDENCE_FILE:-/tmp/safebox-ios-cold-share-evidence-${UID}.log}"
EVIDENCE_META="${SAFEBOX_IOS_COLD_SHARE_EVIDENCE_META:-/tmp/safebox-ios-cold-share-evidence-${UID}.json}"
RECEIPT_FILE="${SAFEBOX_IOS_COLD_SHARE_EVIDENCE_RECEIPT:-/tmp/safebox-ios-cold-share-evidence-${UID}.consumed.json}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; APP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"; ROOT="$(cd "$APP_DIR/.." && pwd)"
[[ -f "$ARM_FILE" && -f "$RECEIPT_FILE" ]] || { echo 'SAFEBOX_IOS_EVIDENCE_LIFECYCLE_RUNTIME_FAIL: consumed receipt missing' >&2; exit 1; }
ROUTE="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["expected_route"])' "$ARM_FILE")" || { echo 'SAFEBOX_IOS_EVIDENCE_LIFECYCLE_RUNTIME_FAIL: invalid arm metadata' >&2; exit 1; }
python3 "$SCRIPT_DIR/ios_evidence_lifecycle.py" verify "$ARM_FILE" "$EVIDENCE_META" "$EVIDENCE_FILE" "$RECEIPT_FILE" "$ROOT/SAFEBOX_V028_PACKAGE_ID.txt" "$APP_DIR/src-tauri/ios/SafeBoxShareInboxBridge.mm" "$APP_DIR/src-tauri/src/lib.rs" "$ROUTE" || { echo 'SAFEBOX_IOS_EVIDENCE_LIFECYCLE_RUNTIME_FAIL: consumed receipt validation failed' >&2; exit 1; }
echo 'SAFEBOX_IOS_EVIDENCE_LIFECYCLE_RUNTIME_PASS'
