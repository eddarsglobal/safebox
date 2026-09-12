#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/safebox-desktop"
BRIDGE="$APP/src-tauri/ios/SafeBoxShareInboxBridge.mm"
RUST="$APP/src-tauri/src/lib.rs"
CHECK="$APP/scripts/ios_replay_recovery_check.sh"
PARSER="$APP/scripts/ios_replay_recovery_contract_check.py"
fail(){ echo "SAFEBOX_V028_R61_VERIFY_FAIL: $*" >&2; exit 1; }

grep -Fq 'v0.2.8-ios-replay-transaction-scope-r61-20260830A' "$ROOT/SAFEBOX_V028_PACKAGE_ID.txt" || fail 'package id mismatch'
[[ -x "$CHECK" ]] || fail 'runtime checker missing'
[[ -x "$PARSER" ]] || fail 'contract parser missing'
echo 'SAFEBOX_V028_R60_CHECKER_BASELINE_RETAINED_R61_PASS'

[[ "$(shasum -a 256 "$BRIDGE" | awk '{print $1}')" == 'da8b92247ee777a03770cc7df67b52b13a8981ca6987b70403fbd97e8913d9e4' ]] || fail 'R59 native recovery implementation changed'
[[ "$(shasum -a 256 "$RUST" | awk '{print $1}')" == '5a4bc10bc1d362a0737c0da2b0b6caad00436206137fd0fc800e2b842c57f297' ]] || fail 'R59 Rust recovery implementation changed'
echo 'SAFEBOX_IOS_REPLAY_R59_IMPLEMENTATION_UNCHANGED_R61_PASS'

grep -Fq 'SAFEBOX_IOS_COLD_SHARE_ARM_FILE' "$CHECK" || fail 'cold-share arm metadata not used'
grep -Fq 'ARMED_AT=' "$CHECK" || fail 'armed_at not loaded'
grep -Fq -- '--start "$ARMED_AT"' "$CHECK" || fail 'log query not arm-scoped'
if grep -Fq 'LOG_START=' "$CHECK"; then fail 'legacy runtime-session log_start still used'; fi
grep -Fq 'EXPECTED_ROUTE=' "$CHECK" || fail 'expected route not carried from arm metadata'
grep -Fq 'SAFEBOX_IOS_REPLAY_RECOVERY_TRANSACTION_SCOPE_PASS' "$CHECK" || fail 'transaction scope marker missing'
grep -Fq 'SAFEBOX_IOS_REPLAY_RECOVERY_ARM_SCOPE_PASS' "$PARSER" || fail 'arm-scope parser marker missing'
echo 'SAFEBOX_IOS_REPLAY_TRANSACTION_SCOPE_R61_PASS'

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
cat > "$TMP/interleaved-pass.log" <<'LOG'
2026-08-30 16:20:03.160 Df SafeBoxShareExtension[77558:b8da9] (Foundation) SAFEBOX_IOS_SHARE_EXTENSION_STAGE_PASS
2026-08-30 16:20:10.531 Df SafeBox[77573:b8e5e] (SafeBox.debug.dylib) SAFEBOX_IOS_SHARE_HARDENING_CLAIM_PASS
2026-08-30 16:20:10.539 Df SafeBox[77573:b8e5e] (SafeBox.debug.dylib) SAFEBOX_IOS_SHARE_RECOVERY_NATIVE_ACK_PASS
2026-08-30 16:20:10.541 Df SafeBox[77573:b8e5e] (SafeBox.debug.dylib) SAFEBOX_IOS_SHARE_RECOVERY_DELIVERY_RECEIPT_PASS
2026-08-30 16:20:10.543 Df SafeBox[77573:b8e5e] (SafeBox.debug.dylib) SAFEBOX_IOS_SHARE_INBOX_DRAIN_PASS count=1
2026-08-30 16:20:10.543 Df SafeBox[77573:b8e81] [com.safebox.desktop:app] [stderr] SAFEBOX_IOS_SHARE_INBOX_ACCEPT: route=unlock
2026-08-30 16:20:10.543 Df SafeBox[77573:b8e81] [com.safebox.desktop:app] [stderr] SAFEBOX_IOS_SHARE_RECOVERY_RUST_ACK_PASS: mode=live
2026-08-30 16:20:10.582 Df SafeBox[77573:b8e5e] (SafeBox.debug.dylib) SAFEBOX_IOS_SHARE_INBOX_DRAIN_PASS count=0
LOG
python3 "$PARSER" "$TMP/interleaved-pass.log" unlock >/dev/null || fail 'reference transaction rejected'
echo 'SAFEBOX_IOS_REPLAY_REFERENCE_TRANSACTION_R61_PASS'

cat > "$TMP/wrong-route.log" <<'LOG'
S SAFEBOX_IOS_SHARE_EXTENSION_STAGE_PASS
N (SafeBox.debug.dylib) SAFEBOX_IOS_SHARE_HARDENING_CLAIM_PASS
N (SafeBox.debug.dylib) SAFEBOX_IOS_SHARE_RECOVERY_NATIVE_ACK_PASS
N (SafeBox.debug.dylib) SAFEBOX_IOS_SHARE_RECOVERY_DELIVERY_RECEIPT_PASS
N (SafeBox.debug.dylib) SAFEBOX_IOS_SHARE_INBOX_DRAIN_PASS count=1
R SAFEBOX_IOS_SHARE_INBOX_ACCEPT: route=protect
R SAFEBOX_IOS_SHARE_RECOVERY_RUST_ACK_PASS: mode=live
N (SafeBox.debug.dylib) SAFEBOX_IOS_SHARE_INBOX_DRAIN_PASS count=0
LOG
if python3 "$PARSER" "$TMP/wrong-route.log" unlock >/dev/null 2>&1; then fail 'wrong route accepted'; fi

cat > "$TMP/double-one.log" <<'LOG'
S SAFEBOX_IOS_SHARE_EXTENSION_STAGE_PASS
N (SafeBox.debug.dylib) SAFEBOX_IOS_SHARE_HARDENING_CLAIM_PASS
N (SafeBox.debug.dylib) SAFEBOX_IOS_SHARE_RECOVERY_NATIVE_ACK_PASS
N (SafeBox.debug.dylib) SAFEBOX_IOS_SHARE_RECOVERY_DELIVERY_RECEIPT_PASS
N (SafeBox.debug.dylib) SAFEBOX_IOS_SHARE_INBOX_DRAIN_PASS count=1
R SAFEBOX_IOS_SHARE_INBOX_ACCEPT: route=unlock
R SAFEBOX_IOS_SHARE_RECOVERY_RUST_ACK_PASS: mode=live
N (SafeBox.debug.dylib) SAFEBOX_IOS_SHARE_INBOX_DRAIN_PASS count=0
N (SafeBox.debug.dylib) SAFEBOX_IOS_SHARE_INBOX_DRAIN_PASS count=1
LOG
if python3 "$PARSER" "$TMP/double-one.log" unlock >/dev/null 2>&1; then fail 'second accepted drain accepted'; fi

echo 'SAFEBOX_IOS_REPLAY_NEGATIVE_TRANSACTION_TESTS_R61_PASS'

bash -n "$CHECK" || fail 'shell syntax invalid'
python3 -m py_compile "$PARSER" || fail 'parser syntax invalid'
rm -rf "$APP/scripts/__pycache__"

[[ "$(shasum -a 256 "$APP/src-tauri/ios/SafeBoxAdsBridge.mm" | awk '{print $1}')" == 'a408b55ec036ee71894853c144fc753e7a181eeaca7b5ae6872ec636dfc5e2ea' ]] || fail 'Ads bridge changed'
[[ "$(shasum -a 256 "$APP/src-tauri/ios/SafeBoxColdOpenBridge.mm" | awk '{print $1}')" == '4712895a3941cb359bdb87a55f92c117af247393d5aa1db07b979bde6eb22f42' ]] || fail 'cold-open bridge changed'
[[ "$(shasum -a 256 "$ROOT/safebox-core/src/crypto.rs" | awk '{print $1}')" == 'd30d1530b38988e544f0aa25808b8048f88d1a9578036160fc7efa40c854a99c' ]] || fail 'crypto changed'
[[ "$(shasum -a 256 "$ROOT/safebox-core/src/format.rs" | awk '{print $1}')" == '26edb67b2be91ff5c7d765e100e4aafa5e50933919c0db2e4370901f67205ea1' ]] || fail 'format changed'
echo 'SAFEBOX_IOS_REPLAY_SECURITY_INVARIANTS_R61_PASS'

echo 'IOS_V028_STATUS: REPLAY_TRANSACTION_SCOPE_R61_READY_FOR_RUNTIME_RECHECK'
echo 'SAFEBOX_V028_IOS_REPLAY_TRANSACTION_SCOPE_R61_VERIFY_PASS'
