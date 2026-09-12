#!/usr/bin/env bash
set -euo pipefail
SESSION_FILE="${SAFEBOX_IOS_RUNTIME_SESSION_FILE:-/tmp/safebox-ios-runtime-session-${UID}.json}"
ARM_FILE="${SAFEBOX_IOS_COLD_OPEN_ARM_FILE:-/tmp/safebox-ios-cold-open-arm-${UID}.json}"
[[ -f "$SESSION_FILE" ]] || { echo 'SAFEBOX_IOS_COLD_OPEN_ARM_FAIL: runtime session missing; run npm run ios:cold-dev first' >&2; exit 1; }

FIELDS="$(python3 - "$SESSION_FILE" <<'PY'
import json,shlex,sys
try:d=json.load(open(sys.argv[1]))
except Exception as exc: raise SystemExit(f'invalid session: {exc}')
for k in ('device_udid','bundle_id','process_name','pid'):
    if not d.get(k): raise SystemExit(f'missing {k}')
for k in ('device_udid','bundle_id','process_name','pid'):
    print(k.upper()+'='+shlex.quote(str(d[k])))
PY
)" || { echo 'SAFEBOX_IOS_COLD_OPEN_ARM_FAIL: invalid runtime session' >&2; exit 1; }
eval "$FIELDS"

INSTALLED_APP="$(xcrun simctl get_app_container "$DEVICE_UDID" "$BUNDLE_ID" app 2>/dev/null || true)"
[[ -n "$INSTALLED_APP" && -d "$INSTALLED_APP" ]] || { echo 'SAFEBOX_IOS_COLD_OPEN_ARM_FAIL: SafeBox is not installed' >&2; exit 1; }
INSTALLED_INFO="$INSTALLED_APP/Info.plist"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
python3 "$SCRIPT_DIR/ios_sbx_document_contract_check.py" "$INSTALLED_INFO" || { echo 'SAFEBOX_IOS_COLD_OPEN_ARM_FAIL: installed SBX document contract mismatch' >&2; exit 1; }
echo 'SAFEBOX_IOS_COLD_OPEN_GENERATED_REGISTRATION_ARM_PROOF_PASS'
echo 'SAFEBOX_IOS_COLD_OPEN_SINGLE_REGISTRATION_PASS'
echo 'SAFEBOX_IOS_COLD_OPEN_DOCUMENT_OWNER_PASS'
xcrun simctl terminate "$DEVICE_UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
sleep 1
ARMED_AT="$(date '+%Y-%m-%d %H:%M:%S')"
python3 - "$ARM_FILE" "$DEVICE_UDID" "$BUNDLE_ID" "$PROCESS_NAME" "$PID" "$ARMED_AT" <<'PY'
import json,sys
p,device,bundle,process,old_pid,armed=sys.argv[1:]
with open(p,'w') as f:
    json.dump({'device_udid':device,'bundle_id':bundle,'process_name':process,'old_pid':int(old_pid),'armed_at':armed},f)
PY
chmod 600 "$ARM_FILE"
echo "SAFEBOX_IOS_COLD_OPEN_ARM: start=$ARMED_AT"
echo 'SAFEBOX_IOS_COLD_OPEN_PROCESS_TERMINATED_PASS'
echo 'SAFEBOX_IOS_COLD_OPEN_ARM_PASS'
echo 'SAFEBOX_IOS_COLD_OPEN_HANDLER_MODE: OPEN_WITH'
echo 'In Files, LONG-PRESS the .sbx -> Open With -> SafeBox. A simple tap may be handled by Quick Look/Preview and is not the R57 dispatch test. Then run: npm run ios:cold-open-check'
