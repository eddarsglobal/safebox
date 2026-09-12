#!/usr/bin/env bash
set -euo pipefail

SESSION_FILE="${SAFEBOX_IOS_RUNTIME_SESSION_FILE:-/tmp/safebox-ios-runtime-session-${UID}.json}"
[[ -f "$SESSION_FILE" ]] || {
  echo "SAFEBOX_IOS_ADS_RUNTIME_FAIL: runtime session file missing: $SESSION_FILE" >&2
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
print('BUNDLE_ID=' + shlex.quote(str(d['bundle_id'])))
print('PROCESS_NAME=' + shlex.quote(str(d['process_name'])))
print('APP_PID=' + shlex.quote(str(d['pid'])))
print('LOG_START=' + shlex.quote(str(d['log_start'])))
PY
)" || { echo 'SAFEBOX_IOS_ADS_RUNTIME_FAIL: invalid runtime session metadata' >&2; exit 1; }
eval "$SESSION_FIELDS"

[[ "$APP_PID" =~ ^[0-9]+$ ]] || { echo 'SAFEBOX_IOS_ADS_RUNTIME_FAIL: invalid app PID in runtime session' >&2; exit 1; }
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
  echo "SAFEBOX_IOS_ADS_RUNTIME_FAIL: recorded simulator is no longer booted: $DEVICE_UDID" >&2
  exit 1
}

echo "SAFEBOX_IOS_ADS_RUNTIME_SESSION: process=$PROCESS_NAME pid=$APP_PID start=$LOG_START"
echo 'SAFEBOX_IOS_ADS_RUNTIME_SESSION_SCOPE_PASS'

LOG="$(mktemp)"
trap 'rm -f "$LOG"' EXIT
# Apple unified logging supports time-range retrieval and process predicates.
# Scope from the recorded launch boundary instead of a rolling last-N-minutes
# window so one-shot UMP/GMA bootstrap evidence cannot age out during testing.
xcrun simctl spawn "$DEVICE_UDID" log show \
  --start "$LOG_START" \
  --style compact \
  --predicate "process == \"$PROCESS_NAME\" AND eventMessage CONTAINS \"SAFEBOX_IOS_\"" \
  >"$LOG" 2>/dev/null || true

grep -E 'SAFEBOX_IOS_(UMP|GMA|BANNER|PRIVACY)' "$LOG" || true

python3 - "$LOG" <<'PY'
from pathlib import Path
import sys
lines=Path(sys.argv[1]).read_text(errors='replace').splitlines()
markers=[
    'SAFEBOX_IOS_UMP_UPDATE_BEGIN',
    'SAFEBOX_IOS_GMA_INIT_PASS',
    'SAFEBOX_IOS_BANNER_LOAD_PASS',
]
pos=-1
for marker in markers:
    for i in range(pos+1, len(lines)):
        if marker in lines[i]:
            pos=i
            break
    else:
        if marker == markers[0]:
            print('SAFEBOX_IOS_ADS_RUNTIME_FAIL: UMP did not start in this runtime session', file=sys.stderr)
            raise SystemExit(2)
        if marker == markers[1]:
            print('SAFEBOX_IOS_ADS_RUNTIME_FAIL: GMA did not initialize after UMP; finish/accept the consent flow first', file=sys.stderr)
            raise SystemExit(3)
        print('SAFEBOX_IOS_ADS_RUNTIME_FAIL: test banner did not load after GMA initialization', file=sys.stderr)
        raise SystemExit(4)
print('SAFEBOX_IOS_ADS_ORDER_PASS')
PY

echo 'SAFEBOX_IOS_ADS_RUNTIME_PASS'
