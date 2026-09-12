#!/usr/bin/env bash
set -euo pipefail
EXPECTED_ROUTE="${1:-}"
case "$EXPECTED_ROUTE" in protect|unlock) ;; *) echo 'Usage: npm run ios:share-check -- protect|unlock' >&2; exit 2;; esac
SESSION_FILE="${SAFEBOX_IOS_RUNTIME_SESSION_FILE:-/tmp/safebox-ios-runtime-session-${UID}.json}"
[[ -f "$SESSION_FILE" ]] || { echo 'SAFEBOX_IOS_SHARE_RUNTIME_FAIL: runtime session file missing; run npm run ios:cold-dev first' >&2; exit 1; }
FIELDS="$(python3 - "$SESSION_FILE" <<'PY'
import json,shlex,sys
d=json.load(open(sys.argv[1]))
for k in ('device_udid','process_name','pid','log_start'):
    if not d.get(k): raise SystemExit(f'missing {k}')
print('DEVICE_UDID='+shlex.quote(str(d['device_udid'])))
print('PROCESS_NAME='+shlex.quote(str(d['process_name'])))
print('APP_PID='+shlex.quote(str(d['pid'])))
print('LOG_START='+shlex.quote(str(d['log_start'])))
PY
)" || { echo 'SAFEBOX_IOS_SHARE_RUNTIME_FAIL: invalid runtime session metadata' >&2; exit 1; }
eval "$FIELDS"
echo "SAFEBOX_IOS_SHARE_RUNTIME_SESSION: process=$PROCESS_NAME pid=$APP_PID start=$LOG_START expected=$EXPECTED_ROUTE"
echo 'SAFEBOX_IOS_SHARE_RUNTIME_SESSION_SCOPE_PASS'
LOG="$(mktemp)"; trap 'rm -f "$LOG"' EXIT
xcrun simctl spawn "$DEVICE_UDID" log show --start "$LOG_START" --style compact \
  --predicate 'eventMessage CONTAINS "SAFEBOX_IOS_SHARE_"' >"$LOG" 2>/dev/null || true
grep -E 'SAFEBOX_IOS_SHARE_(EXTENSION_STAGE_PASS|INBOX_(NATIVE_REGISTER|FOREGROUND_(OBSERVER|NATIVE|RUST)_PASS|NATIVE_DRAIN_TRIGGER|DRAIN_API_UNAVAILABLE|DRAIN_REQUEST|CONTAINER_(FAIL|PASS)|DRAIN_BEGIN|DRAIN_PASS|ACCEPT))' "$LOG" || true
if ! grep -Fq 'SAFEBOX_IOS_SHARE_EXTENSION_STAGE_PASS' "$LOG"; then
  echo 'SAFEBOX_IOS_SHARE_RUNTIME_FAIL: Share Extension did not stage a file in this session' >&2
  exit 1
fi
if grep -Fq 'SAFEBOX_IOS_SHARE_INBOX_DRAIN_API_UNAVAILABLE' "$LOG"; then
  echo 'SAFEBOX_IOS_SHARE_RUNTIME_FAIL: native share drain callback was not registered into Rust' >&2
  exit 1
fi
if grep -Fq 'SAFEBOX_IOS_SHARE_INBOX_CONTAINER_FAIL' "$LOG"; then
  echo 'SAFEBOX_IOS_SHARE_RUNTIME_FAIL: containing app cannot resolve the App Group container' >&2
  exit 1
fi
# R52 validates the actual iOS foreground path, not Tauri RunEvent::Resumed.
python3 - "$LOG" <<'PY' || { echo 'SAFEBOX_IOS_SHARE_RUNTIME_FAIL: no native iOS foreground drain occurred after the shared file was staged; return to SafeBox once, then rerun this checker' >&2; exit 1; }
import sys
lines=open(sys.argv[1],errors='replace').read().splitlines()
stages=[i for i,l in enumerate(lines) if 'SAFEBOX_IOS_SHARE_EXTENSION_STAGE_PASS' in l]
foreground=[i for i,l in enumerate(lines) if 'SAFEBOX_IOS_SHARE_INBOX_DRAIN_REQUEST: trigger=native-foreground' in l]
raise SystemExit(0 if any(s < f for s in stages for f in foreground) else 1)
PY
if ! grep -Fq "SAFEBOX_IOS_SHARE_INBOX_ACCEPT: route=$EXPECTED_ROUTE" "$LOG"; then
  echo "SAFEBOX_IOS_SHARE_RUNTIME_FAIL: native foreground drain ran, but SafeBox did not accept route=$EXPECTED_ROUTE" >&2
  exit 1
fi
python3 - "$LOG" "$EXPECTED_ROUTE" <<'PY' || { echo 'SAFEBOX_IOS_SHARE_RUNTIME_FAIL: marker order invalid' >&2; exit 1; }
import sys
lines=open(sys.argv[1],errors='replace').read().splitlines(); route=sys.argv[2]
def idxs(token): return [i for i,l in enumerate(lines) if token in l]
stages=idxs('SAFEBOX_IOS_SHARE_EXTENSION_STAGE_PASS')
foreground=idxs('SAFEBOX_IOS_SHARE_INBOX_DRAIN_REQUEST: trigger=native-foreground')
accepts=idxs('SAFEBOX_IOS_SHARE_INBOX_ACCEPT: route='+route)
valid=any(stage < fg < accept for stage in stages for fg in foreground for accept in accepts)
raise SystemExit(0 if valid else 1)
PY
echo 'SAFEBOX_IOS_SHARE_FOREGROUND_NATIVE_RUNTIME_PASS'
echo 'SAFEBOX_IOS_SHARE_EXTENSION_STAGE_RUNTIME_PASS'
case "$EXPECTED_ROUTE" in protect) echo 'SAFEBOX_IOS_SHARE_PROTECT_PASS';; unlock) echo 'SAFEBOX_IOS_SHARE_UNLOCK_PASS';; esac
echo 'SAFEBOX_IOS_SHARE_ORDER_PASS'
echo 'SAFEBOX_IOS_SHARE_RUNTIME_PASS'
