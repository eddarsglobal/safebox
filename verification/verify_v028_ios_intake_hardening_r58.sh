#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/safebox-desktop"
TAURI="$APP/src-tauri"
SWIFT="$TAURI/ios-share/ShareViewController.swift"
BRIDGE="$TAURI/ios/SafeBoxShareInboxBridge.mm"
RUST="$TAURI/src/lib.rs"
CHECK="$APP/scripts/ios_intake_hardening_check.sh"
fail(){ echo "SAFEBOX_V028_R58_VERIFY_FAIL: $*" >&2; exit 1; }

grep -Fq 'v0.2.8-ios-intake-hardening-r58-20260830A' "$ROOT/SAFEBOX_V028_PACKAGE_ID.txt" || fail 'package id mismatch'
[[ -x "$ROOT/verification/verify_v028_ios_cold_start_intake_closure_r57.sh" ]] || fail 'R57 verifier missing'
[[ -x "$CHECK" ]] || fail 'R58 runtime checker missing'
echo 'SAFEBOX_V028_R57_RUNTIME_BASELINE_RETAINED_R58_PASS'

# Policy must be aligned at both native boundaries.
for token in \
  '512 * 1024 * 1024' \
  'maxReadyRequests = 8' \
  '1024 * 1024 * 1024' \
  'staleReadyAge: TimeInterval = 24 * 60 * 60' \
  'staleIncompleteAge: TimeInterval = 60 * 60'; do
  grep -Fq "$token" "$SWIFT" || fail "Share Extension policy missing: $token"
done
for token in \
  '512ULL * 1024ULL * 1024ULL' \
  'SBXShareMaxRequestsPerDrain = 8' \
  'SBXShareMaxInboxBytes = 1024ULL * 1024ULL * 1024ULL' \
  'SBXShareStaleReadyAge = 24.0 * 60.0 * 60.0' \
  'SBXShareStaleIncompleteAge = 60.0 * 60.0' \
  'SBXShareStaleProcessingAge = 60.0 * 60.0' \
  'SBXSharePrivateRetentionAge = 24.0 * 60.0 * 60.0'; do
  grep -Fq "$token" "$BRIDGE" || fail "containing-app policy missing: $token"
done
echo 'SAFEBOX_IOS_INTAKE_LIMITS_R58_PASS'

# Atomic extension commit: partial -> verification -> rename -> READY last.
grep -Fq '.payload.partial' "$SWIFT" || fail 'extension partial staging missing'
grep -Fq 'copiedSize == sourceSize' "$SWIFT" || fail 'extension post-copy size verification missing'
grep -Fq 'moveItem(at: partial, to: destination)' "$SWIFT" || fail 'extension atomic rename missing'
grep -Fq 'Data().write(to: ready, options: [.atomic])' "$SWIFT" || fail 'READY atomic write missing'
python3 - "$SWIFT" <<'PY' || exit 1
import sys
s=open(sys.argv[1]).read()
a=s.index('moveItem(at: partial, to: destination)')
b=s.index('Data().write(to: ready, options: [.atomic])')
assert a < b
PY
echo 'SAFEBOX_IOS_INTAKE_ATOMIC_EXTENSION_COMMIT_R58_PASS'

# Atomic native claim and private copy commit.
grep -Fq 'SBXShareProcessingName = @"ShareProcessing"' "$BRIDGE" || fail 'processing directory missing'
grep -Fq 'moveItemAtURL:request toURL:claimed' "$BRIDGE" || fail 'atomic request claim missing'
grep -Fq 'SAFEBOX_IOS_SHARE_HARDENING_CLAIM_PASS' "$BRIDGE" || fail 'claim marker missing'
grep -Fq '.payload.partial' "$BRIDGE" || fail 'native partial staging missing'
grep -Fq 'copiedSize != payloadSize' "$BRIDGE" || fail 'native post-copy size verification missing'
grep -Fq 'moveItemAtURL:partial toURL:destination' "$BRIDGE" || fail 'native atomic private commit missing'
echo 'SAFEBOX_IOS_INTAKE_ATOMIC_CLAIM_R58_PASS'

# Cleanup/flood controls and fail-closed processing recovery.
grep -Fq 'SBXCleanupInbox(inbox)' "$BRIDGE" || fail 'inbox cleanup missing'
grep -Fq 'SBXCleanupDirectory(processing, SBXShareStaleProcessingAge)' "$BRIDGE" || fail 'processing expiry missing'
grep -Fq 'SBXCleanupDirectory(privateRoot, SBXSharePrivateRetentionAge)' "$BRIDGE" || fail 'private intake cleanup missing'
grep -Fq 'examined >= SBXShareMaxRequestsPerDrain' "$BRIDGE" || fail 'per-drain request limit missing'
grep -Fq 'usage.readyCount < maxReadyRequests' "$SWIFT" || fail 'extension request quota missing'
grep -Fq 'usage.readyBytes <= maxInboxBytes - sourceSize' "$SWIFT" || fail 'extension byte quota missing'
echo 'SAFEBOX_IOS_INTAKE_CLEANUP_QUOTA_R58_PASS'

# Provider source must never be deleted; logging remains path/name-free.
if grep -Eq 'removeItem\(at: *url\)|removeItemAtURL: *url' "$SWIFT" "$BRIDGE"; then fail 'provider source deletion detected'; fi
if grep -Eq 'NSLog\([^\n]*(lastPathComponent|\.path|absoluteString)' "$SWIFT" "$BRIDGE"; then fail 'sensitive path/name logging detected'; fi
grep -Fq 'NSFilePosixPermissions: @0600' "$BRIDGE" || fail 'native 0600 missing'
grep -Fq 'NSFileProtectionKey: NSFileProtectionComplete' "$BRIDGE" || fail 'native file protection missing'
grep -Fq '.posixPermissions: 0o600' "$SWIFT" || fail 'extension 0600 missing'
grep -Fq 'FileProtectionType.complete' "$SWIFT" || fail 'extension file protection missing'
echo 'SAFEBOX_IOS_INTAKE_SECURITY_INVARIANTS_R58_PASS'

# Rust pending queue has explicit dedupe/capacity diagnostics.
grep -Fq 'SAFEBOX_IOS_SHARE_HARDENING_DEDUP_PASS' "$RUST" || fail 'Rust dedupe marker missing'
grep -Fq 'SAFEBOX_IOS_SHARE_HARDENING_REJECT: reason=pending-capacity' "$RUST" || fail 'Rust pending capacity rejection missing'
grep -Fq 'pending.len() >= 8' "$RUST" || fail 'Rust pending limit missing'
echo 'SAFEBOX_IOS_INTAKE_RUST_BACKSTOP_R58_PASS'

# Runtime checker must verify extension policy/commit and native claim before accept.
for token in \
  'SAFEBOX_IOS_SHARE_HARDENING_CLEANUP_PASS' \
  'SAFEBOX_IOS_SHARE_HARDENING_POLICY_PASS' \
  'SAFEBOX_IOS_SHARE_HARDENING_ATOMIC_COMMIT_PASS' \
  'SAFEBOX_IOS_SHARE_HARDENING_CLAIM_PASS' \
  'SAFEBOX_IOS_INTAKE_HARDENING_RUNTIME_PASS'; do
  grep -Fq "$token" "$CHECK" || fail "runtime checker token missing: $token"
done
python3 - "$APP/package.json" <<'PY' || exit 1
import json,sys
s=json.load(open(sys.argv[1]))['scripts']
assert s['ios:intake-hardening-check']=='bash scripts/ios_intake_hardening_check.sh'
PY
echo 'SAFEBOX_IOS_INTAKE_RUNTIME_CHECKER_R58_PASS'

# Untouched high-value surfaces remain byte-identical to validated baseline.
[[ "$(shasum -a 256 "$TAURI/ios/SafeBoxAdsBridge.mm" | awk '{print $1}')" == 'a408b55ec036ee71894853c144fc753e7a181eeaca7b5ae6872ec636dfc5e2ea' ]] || fail 'Ads bridge changed'
[[ "$(shasum -a 256 "$TAURI/ios/SafeBoxColdOpenBridge.mm" | awk '{print $1}')" == '4712895a3941cb359bdb87a55f92c117af247393d5aa1db07b979bde6eb22f42' ]] || fail 'cold-open bridge changed'
[[ "$(shasum -a 256 "$ROOT/safebox-core/src/crypto.rs" | awk '{print $1}')" == 'd30d1530b38988e544f0aa25808b8048f88d1a9578036160fc7efa40c854a99c' ]] || fail 'crypto.rs changed'
[[ "$(shasum -a 256 "$ROOT/safebox-core/src/format.rs" | awk '{print $1}')" == '26edb67b2be91ff5c7d765e100e4aafa5e50933919c0db2e4370901f67205ea1' ]] || fail 'format.rs changed'
[[ "$(shasum -a 256 "$APP/scripts/ios_cold_share_arm.sh" | awk '{print $1}')" == '56a04686c2458d8e39a994b0f4eb88d453eea44ea95d295c79697bdb6e89fe1f' ]] || fail 'R57 cold-share arm changed'
[[ "$(shasum -a 256 "$APP/scripts/ios_cold_share_check.sh" | awk '{print $1}')" == '4db9ea43a4ee36dc40bed015dfe87385ab584f3f2215864d362f92d291cb5e77' ]] || fail 'R57 cold-share checker changed'
echo 'SAFEBOX_IOS_INTAKE_UNTOUCHED_SURFACES_R58_PASS'

echo 'IOS_V028_STATUS: INTAKE_HARDENING_R58_READY_FOR_RUNTIME_TEST'
echo 'SAFEBOX_V028_IOS_INTAKE_HARDENING_R58_VERIFY_PASS'
