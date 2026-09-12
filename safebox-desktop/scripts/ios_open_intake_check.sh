#!/usr/bin/env bash
set -euo pipefail

EXPECTED_ROUTE="${1:-}"
case "$EXPECTED_ROUTE" in
  protect|unlock) ;;
  *)
    echo 'Usage: npm run ios:open-check -- protect|unlock' >&2
    echo 'Open a matching document in the iOS simulator first, then run this checker.' >&2
    exit 2
    ;;
esac

SESSION_FILE="${SAFEBOX_IOS_RUNTIME_SESSION_FILE:-/tmp/safebox-ios-runtime-session-${UID}.json}"
[[ -f "$SESSION_FILE" ]] || {
  echo "SAFEBOX_IOS_OPEN_IN_RUNTIME_FAIL: runtime session file missing: $SESSION_FILE" >&2
  echo 'Run npm run ios:cold-dev first and keep that Terminal active.' >&2
  exit 1
}

SESSION_FIELDS="$(python3 - "$SESSION_FILE" <<'PY'
import json, shlex, sys
p=sys.argv[1]
try:
    d=json.load(open(p))
except Exception as exc:
    raise SystemExit(f'invalid runtime session file: {exc}')
for k in ('device_udid','bundle_id','process_name','pid','log_start'):
    if k not in d or d[k] in ('', None):
        raise SystemExit(f'missing runtime session field: {k}')
print('DEVICE_UDID=' + shlex.quote(str(d['device_udid'])))
print('PROCESS_NAME=' + shlex.quote(str(d['process_name'])))
print('APP_PID=' + shlex.quote(str(d['pid'])))
print('LOG_START=' + shlex.quote(str(d['log_start'])))
PY
)" || { echo 'SAFEBOX_IOS_OPEN_IN_RUNTIME_FAIL: invalid runtime session metadata' >&2; exit 1; }
eval "$SESSION_FIELDS"

[[ "$APP_PID" =~ ^[0-9]+$ ]] || { echo 'SAFEBOX_IOS_OPEN_IN_RUNTIME_FAIL: invalid app PID' >&2; exit 1; }
BOOTED="$(xcrun simctl list devices booted -j 2>/dev/null || true)"
SAFEBOX_BOOTED_JSON="$BOOTED" python3 - "$DEVICE_UDID" <<'PY' || {
import json, os, sys
wanted=sys.argv[1]
try:
    d=json.loads(os.environ['SAFEBOX_BOOTED_JSON'])
except Exception:
    raise SystemExit(1)
raise SystemExit(0 if any(x.get('udid') == wanted and x.get('state') == 'Booted' for a in d.get('devices',{}).values() for x in a) else 1)
PY
  echo "SAFEBOX_IOS_OPEN_IN_RUNTIME_FAIL: recorded simulator is no longer booted: $DEVICE_UDID" >&2
  exit 1
}

echo "SAFEBOX_IOS_OPEN_IN_RUNTIME_SESSION: process=$PROCESS_NAME pid=$APP_PID start=$LOG_START expected=$EXPECTED_ROUTE"
echo 'SAFEBOX_IOS_OPEN_IN_RUNTIME_SESSION_SCOPE_PASS'

LOG="$(mktemp)"
trap 'rm -f "$LOG"' EXIT
xcrun simctl spawn "$DEVICE_UDID" log show \
  --start "$LOG_START" \
  --style compact \
  --predicate "process == \"$PROCESS_NAME\" AND eventMessage CONTAINS \"SAFEBOX_IOS_OPEN_IN_ACCEPT\"" \
  >"$LOG" 2>/dev/null || true

# Route-only output is intentional: filenames/URLs are never logged by SafeBox.
grep -F 'SAFEBOX_IOS_OPEN_IN_ACCEPT:' "$LOG" || true

if ! grep -Fq "SAFEBOX_IOS_OPEN_IN_ACCEPT: route=$EXPECTED_ROUTE" "$LOG"; then
  echo "SAFEBOX_IOS_OPEN_IN_RUNTIME_FAIL: no current-session $EXPECTED_ROUTE intake marker found" >&2
  exit 1
fi

case "$EXPECTED_ROUTE" in
  protect) echo 'SAFEBOX_IOS_OPEN_IN_PROTECT_PASS' ;;
  unlock) echo 'SAFEBOX_IOS_OPEN_IN_UNLOCK_PASS' ;;
esac
echo 'SAFEBOX_IOS_OPEN_IN_RUNTIME_PASS'
