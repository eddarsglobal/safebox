#!/usr/bin/env bash
set -euo pipefail
ARM_FILE="${SAFEBOX_IOS_COLD_OPEN_ARM_FILE:-/tmp/safebox-ios-cold-open-arm-${UID}.json}"
[[ -f "$ARM_FILE" ]] || { echo 'SAFEBOX_IOS_COLD_OPEN_RUNTIME_FAIL: arm file missing; run npm run ios:cold-open-arm first' >&2; exit 1; }
FIELDS="$(python3 - "$ARM_FILE" <<'PY'
import json,shlex,sys
try:d=json.load(open(sys.argv[1]))
except Exception as exc: raise SystemExit(f'invalid arm file: {exc}')
for k in ('device_udid','bundle_id','process_name','old_pid','armed_at'):
    if d.get(k) in ('',None): raise SystemExit(f'missing {k}')
for k in ('device_udid','bundle_id','process_name','old_pid','armed_at'):
    print(k.upper()+'='+shlex.quote(str(d[k])))
PY
)" || { echo 'SAFEBOX_IOS_COLD_OPEN_RUNTIME_FAIL: invalid arm metadata' >&2; exit 1; }
eval "$FIELDS"

BOOTED="$(xcrun simctl list devices booted -j 2>/dev/null || true)"
SAFEBOX_BOOTED_JSON="$BOOTED" python3 - "$DEVICE_UDID" <<'PY' || { echo 'SAFEBOX_IOS_COLD_OPEN_RUNTIME_FAIL: armed simulator is not booted' >&2; exit 1; }
import json,os,sys
try:d=json.loads(os.environ['SAFEBOX_BOOTED_JSON'])
except Exception: raise SystemExit(1)
wanted=sys.argv[1]
raise SystemExit(0 if any(x.get('udid')==wanted and x.get('state')=='Booted' for a in d.get('devices',{}).values() for x in a) else 1)
PY

LOG="$(mktemp)"; trap 'rm -f "$LOG"' EXIT
xcrun simctl spawn "$DEVICE_UDID" log show \
  --start "$ARMED_AT" \
  --style compact \
  --predicate "process == \"$PROCESS_NAME\" AND eventMessage CONTAINS \"SAFEBOX_IOS_COLD_OPEN\"" \
  >"$LOG" 2>/dev/null || true

grep -F 'SAFEBOX_IOS_COLD_OPEN_' "$LOG" || true

NEW_PID="$(sed -nE "s/.*${PROCESS_NAME//./\\.}\\[([0-9]+):[^]]*\\].*/\\1/p" "$LOG" | head -1 || true)"
if [[ ! "$NEW_PID" =~ ^[0-9]+$ ]]; then
  echo 'SAFEBOX_IOS_COLD_OPEN_FILES_PREVIEW_NO_DISPATCH: simple Files preview/tap is not a SafeBox runtime failure' >&2
  echo 'SAFEBOX_IOS_COLD_OPEN_OPEN_WITH_REQUIRED: use Files -> long-press .sbx -> Open With -> SafeBox' >&2
  echo 'SAFEBOX_IOS_COLD_OPEN_RUNTIME_FAIL: no document-handler cold-start process found after arm' >&2
  exit 1
fi
[[ "$NEW_PID" != "$OLD_PID" ]] || { echo 'SAFEBOX_IOS_COLD_OPEN_RUNTIME_FAIL: SafeBox was not cold-started; PID did not change' >&2; exit 1; }
echo "SAFEBOX_IOS_COLD_OPEN_PROCESS: old=$OLD_PID new=$NEW_PID start=$ARMED_AT"
echo 'SAFEBOX_IOS_COLD_OPEN_NEW_PROCESS_PASS'

grep -Fq 'SAFEBOX_IOS_COLD_OPEN_BRIDGE_INSTALL_PASS' "$LOG" || { echo 'SAFEBOX_IOS_COLD_OPEN_RUNTIME_FAIL: cold-open bridge did not install in new process' >&2; exit 1; }
grep -Fq 'SAFEBOX_IOS_COLD_OPEN_DID_FINISH_PASS' "$LOG" || { echo 'SAFEBOX_IOS_COLD_OPEN_RUNTIME_FAIL: did-finish launch boundary missing' >&2; exit 1; }
grep -Fq 'SAFEBOX_IOS_COLD_OPEN_CAPTURE_PASS:' "$LOG" || { echo 'SAFEBOX_IOS_COLD_OPEN_RUNTIME_FAIL: no cold-start .sbx URL captured' >&2; exit 1; }
grep -Fq 'SAFEBOX_IOS_COLD_OPEN_STAGE_PASS' "$LOG" || { echo 'SAFEBOX_IOS_COLD_OPEN_RUNTIME_FAIL: cold-start .sbx was not staged privately' >&2; exit 1; }
grep -Fq 'SAFEBOX_IOS_COLD_OPEN_ACCEPT: route=unlock' "$LOG" || { echo 'SAFEBOX_IOS_COLD_OPEN_RUNTIME_FAIL: Rust did not accept route=unlock' >&2; exit 1; }
grep -Fq 'SAFEBOX_IOS_COLD_OPEN_DELIVERY_PASS:' "$LOG" || { echo 'SAFEBOX_IOS_COLD_OPEN_RUNTIME_FAIL: cold-start intake was not delivered to Tauri state/window' >&2; exit 1; }
if grep -Fq 'SAFEBOX_IOS_COLD_OPEN_STAGE_FAIL:' "$LOG"; then
  echo 'SAFEBOX_IOS_COLD_OPEN_RUNTIME_FAIL: staging failure marker found' >&2
  exit 1
fi
if grep -Fq 'SAFEBOX_IOS_COLD_OPEN_REJECT:' "$LOG"; then
  echo 'SAFEBOX_IOS_COLD_OPEN_RUNTIME_FAIL: Rust rejection marker found' >&2
  exit 1
fi

echo 'SAFEBOX_IOS_COLD_OPEN_CAPTURE_RUNTIME_PASS'
echo 'SAFEBOX_IOS_COLD_OPEN_PRIVATE_STAGE_RUNTIME_PASS'
echo 'SAFEBOX_IOS_COLD_OPEN_UNLOCK_PASS'
echo 'SAFEBOX_IOS_COLD_OPEN_RUNTIME_PASS'
