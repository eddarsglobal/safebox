#!/usr/bin/env bash
set -euo pipefail
SESSION_FILE="${SAFEBOX_IOS_RUNTIME_SESSION_FILE:-/tmp/safebox-ios-runtime-session-${UID}.json}"
[[ -f "$SESSION_FILE" ]] || { echo 'SAFEBOX_IOS_INTAKE_HARDENING_RUNTIME_FAIL: runtime session missing; run npm run ios:cold-dev first' >&2; exit 1; }
FIELDS="$(python3 - "$SESSION_FILE" <<'PY'
import json,shlex,sys
d=json.load(open(sys.argv[1]))
for k in ('device_udid','log_start'):
    if not d.get(k): raise SystemExit(f'missing {k}')
print('DEVICE_UDID='+shlex.quote(str(d['device_udid'])))
print('LOG_START='+shlex.quote(str(d['log_start'])))
PY
)" || { echo 'SAFEBOX_IOS_INTAKE_HARDENING_RUNTIME_FAIL: invalid runtime session' >&2; exit 1; }
eval "$FIELDS"
LOG="$(mktemp)"; trap 'rm -f "$LOG"' EXIT
xcrun simctl spawn "$DEVICE_UDID" log show --start "$LOG_START" --style compact \
  --predicate 'eventMessage CONTAINS "SAFEBOX_IOS_SHARE_"' >"$LOG" 2>/dev/null || true

grep -E 'SAFEBOX_IOS_SHARE_(EXTENSION_STAGE_PASS|HARDENING_(CLEANUP_PASS|POLICY_PASS|ATOMIC_COMMIT_PASS|CLAIM_PASS|DRAIN_LIMIT_PASS|REJECT)|INBOX_(ACCEPT|DRAIN_PASS))' "$LOG" || true
for token in \
  'SAFEBOX_IOS_SHARE_HARDENING_CLEANUP_PASS' \
  'SAFEBOX_IOS_SHARE_HARDENING_POLICY_PASS' \
  'SAFEBOX_IOS_SHARE_HARDENING_ATOMIC_COMMIT_PASS' \
  'SAFEBOX_IOS_SHARE_HARDENING_CLAIM_PASS' \
  'SAFEBOX_IOS_SHARE_EXTENSION_STAGE_PASS' \
  'SAFEBOX_IOS_SHARE_INBOX_ACCEPT:'; do
  grep -Fq "$token" "$LOG" || { echo "SAFEBOX_IOS_INTAKE_HARDENING_RUNTIME_FAIL: missing $token" >&2; exit 1; }
done
python3 - "$LOG" <<'PY' || { echo 'SAFEBOX_IOS_INTAKE_HARDENING_RUNTIME_FAIL: hardening marker order invalid' >&2; exit 1; }
import sys
lines=open(sys.argv[1],errors='replace').read().splitlines()
def first(t):
    return next((i for i,l in enumerate(lines) if t in l),None)
policy=first('SAFEBOX_IOS_SHARE_HARDENING_POLICY_PASS')
commit=first('SAFEBOX_IOS_SHARE_HARDENING_ATOMIC_COMMIT_PASS')
stage=first('SAFEBOX_IOS_SHARE_EXTENSION_STAGE_PASS')
claim=first('SAFEBOX_IOS_SHARE_HARDENING_CLAIM_PASS')
accept=first('SAFEBOX_IOS_SHARE_INBOX_ACCEPT:')
if None in (policy,commit,stage,claim,accept): raise SystemExit(1)
# Extension policy/commit must precede READY stage; native claim must precede accept.
if not (policy < commit < stage and claim < accept): raise SystemExit(1)
PY
echo 'SAFEBOX_IOS_INTAKE_HARDENING_POLICY_RUNTIME_PASS'
echo 'SAFEBOX_IOS_INTAKE_HARDENING_ATOMIC_RUNTIME_PASS'
echo 'SAFEBOX_IOS_INTAKE_HARDENING_CLAIM_RUNTIME_PASS'
echo 'SAFEBOX_IOS_INTAKE_HARDENING_RUNTIME_PASS'
