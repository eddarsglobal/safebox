#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"; APP="$ROOT/safebox-desktop"
LEDGER="$APP/scripts/ios_evidence_ledger.py"; CONC="$APP/scripts/ios_evidence_ledger_concurrency_check.py"; ARM="$APP/scripts/ios_cold_share_arm.sh"; CHECK="$APP/scripts/ios_evidence_ledger_check.sh"
BRIDGE="$APP/src-tauri/ios/SafeBoxShareInboxBridge.mm"; RUST="$APP/src-tauri/src/lib.rs"
fail(){ echo "SAFEBOX_V028_R66_VERIFY_FAIL: $*" >&2; exit 1; }
grep -Fq 'v0.2.8-ios-evidence-ledger-concurrency-r66-20260830A' "$ROOT/SAFEBOX_V028_PACKAGE_ID.txt" || fail package-id
echo 'SAFEBOX_V028_R65_RUNTIME_BASELINE_RETAINED_R66_PASS'
[[ "$(shasum -a 256 "$BRIDGE"|awk '{print $1}')" == da8b92247ee777a03770cc7df67b52b13a8981ca6987b70403fbd97e8913d9e4 ]] || fail bridge-changed
[[ "$(shasum -a 256 "$RUST"|awk '{print $1}')" == 5a4bc10bc1d362a0737c0da2b0b6caad00436206137fd0fc800e2b842c57f297 ]] || fail rust-changed
[[ "$(shasum -a 256 "$APP/src-tauri/ios-share/ShareViewController.swift"|awk '{print $1}')" == c868a61f534a425eabf3bea9adeb591474823053ecd582c799a1cafba4da59a4 ]] || fail extension-changed
echo 'SAFEBOX_IOS_RUNTIME_IMPLEMENTATION_UNCHANGED_R66_PASS'
bash -n "$ARM"; bash -n "$CHECK"
PYTHONDONTWRITEBYTECODE=1 python3 -m py_compile "$LEDGER" "$CONC" "$APP/scripts/ios_evidence_lifecycle.py" "$APP/scripts/ios_durable_evidence_validate.py" "$APP/scripts/ios_replay_recovery_contract_check.py"
rm -rf "$APP/scripts/__pycache__"
grep -Fq 'fcntl.flock' "$LEDGER" || fail flock-missing
grep -Fq 'LOCK_EX' "$LEDGER" || fail exclusive-lock-missing
grep -Fq 'LOCK_SH' "$LEDGER" || fail shared-lock-missing
grep -Fq 'O_NOFOLLOW' "$LEDGER" || fail nofollow-missing
grep -Fq 'ledger lock hardlink count invalid' "$LEDGER" || fail hardlink-guard
grep -Fq 'ledger lock mode invalid' "$LEDGER" || fail mode-guard
grep -Fq 'ledger lock must be empty' "$LEDGER" || fail content-guard
grep -Fq 'SAFEBOX_IOS_EVIDENCE_LEDGER_LOCK_SECURITY_PASS' "$LEDGER" || fail lock-marker
grep -Fq 'ios:evidence-ledger-concurrency-check' "$APP/package.json" || fail npm-gate
grep -Fq 'SAFEBOX_IOS_COLD_SHARE_LEDGER_LOCK_CONTINUITY_PASS' "$ARM" || fail arm-lock-continuity
echo 'SAFEBOX_IOS_EVIDENCE_LEDGER_LOCK_POLICY_R66_PASS'
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
SAFEBOX_IOS_EVIDENCE_LEDGER_FILE="$TMP/real-ledger.json" PYTHONDONTWRITEBYTECODE=1 python3 "$CONC" > "$TMP/concurrency.out" || { cat "$TMP/concurrency.out" >&2 || true; fail concurrency-check; }
for marker in \
  SAFEBOX_IOS_EVIDENCE_LEDGER_LOCK_CONTINUITY_PASS \
  SAFEBOX_IOS_EVIDENCE_LEDGER_CONCURRENT_WRITERS_PASS \
  SAFEBOX_IOS_EVIDENCE_LEDGER_CONCURRENT_IDEMPOTENCY_PASS \
  SAFEBOX_IOS_EVIDENCE_LEDGER_CRASH_RELEASE_PASS \
  SAFEBOX_IOS_EVIDENCE_LEDGER_LOCK_FILE_SECURITY_PASS \
  SAFEBOX_IOS_EVIDENCE_LEDGER_LOCK_RUNTIME_PASS; do
  grep -Fq "$marker" "$TMP/concurrency.out" || fail "missing-$marker"
done
echo 'SAFEBOX_IOS_EVIDENCE_LEDGER_CONCURRENCY_REFERENCE_R66_PASS'
# Preserve R65 bounds/privacy declarations.
grep -Fq 'CAPACITY = 32' "$LEDGER" || fail capacity
grep -Fq 'MAX_BYTES = 131072' "$LEDGER" || fail byte-cap
grep -Fq 'ledger contains path/URL/SBX-like value' "$LEDGER" || fail privacy-guard
echo 'SAFEBOX_IOS_EVIDENCE_LEDGER_R65_CONTRACT_RETAINED_R66_PASS'
[[ "$(shasum -a 256 "$APP/src-tauri/ios/SafeBoxAdsBridge.mm"|awk '{print $1}')" == a408b55ec036ee71894853c144fc753e7a181eeaca7b5ae6872ec636dfc5e2ea ]] || fail ads
[[ "$(shasum -a 256 "$APP/src-tauri/ios/SafeBoxColdOpenBridge.mm"|awk '{print $1}')" == 4712895a3941cb359bdb87a55f92c117af247393d5aa1db07b979bde6eb22f42 ]] || fail cold-open
[[ "$(shasum -a 256 "$ROOT/safebox-core/src/crypto.rs"|awk '{print $1}')" == d30d1530b38988e544f0aa25808b8048f88d1a9578036160fc7efa40c854a99c ]] || fail crypto
[[ "$(shasum -a 256 "$ROOT/safebox-core/src/format.rs"|awk '{print $1}')" == 26edb67b2be91ff5c7d765e100e4aafa5e50933919c0db2e4370901f67205ea1 ]] || fail format
echo 'SAFEBOX_IOS_EVIDENCE_LEDGER_SECURITY_INVARIANTS_R66_PASS'
echo 'SAFEBOX_V028_IOS_EVIDENCE_LEDGER_CONCURRENCY_R66_VERIFY_PASS'
