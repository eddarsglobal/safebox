#!/usr/bin/env bash
set -euo pipefail
ARM_FILE="${SAFEBOX_IOS_COLD_SHARE_ARM_FILE:-/tmp/safebox-ios-cold-share-arm-${UID}.json}"
EVIDENCE_FILE="${SAFEBOX_IOS_COLD_SHARE_EVIDENCE_FILE:-/tmp/safebox-ios-cold-share-evidence-${UID}.log}"
EVIDENCE_META="${SAFEBOX_IOS_COLD_SHARE_EVIDENCE_META:-/tmp/safebox-ios-cold-share-evidence-${UID}.json}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ROOT="$(cd "$APP_DIR/.." && pwd)"
PACKAGE_ID_FILE="$ROOT/SAFEBOX_V028_PACKAGE_ID.txt"
[[ -f "$ARM_FILE" ]] || { echo 'SAFEBOX_IOS_COLD_SHARE_RUNTIME_FAIL: arm file missing; run npm run ios:cold-share-arm first' >&2; exit 1; }
FIELDS="$(python3 - "$ARM_FILE" <<'PY'
import json,shlex,sys
try:d=json.load(open(sys.argv[1]))
except Exception as exc: raise SystemExit(f'invalid arm file: {exc}')
for k in ('device_udid','bundle_id','process_name','old_pid','armed_at','expected_route'):
    if d.get(k) in ('',None): raise SystemExit(f'missing {k}')
for k in ('device_udid','bundle_id','process_name','old_pid','armed_at','expected_route'):
    print(k.upper()+'='+shlex.quote(str(d[k])))
PY
)" || { echo 'SAFEBOX_IOS_COLD_SHARE_RUNTIME_FAIL: invalid arm metadata' >&2; exit 1; }
eval "$FIELDS"

LOG="$(mktemp)"; trap 'rm -f "$LOG"' EXIT
xcrun simctl spawn "$DEVICE_UDID" log show --start "$ARMED_AT" --style compact \
  --predicate 'eventMessage CONTAINS "SAFEBOX_IOS_SHARE_"' >"$LOG" 2>/dev/null || true

grep -E 'SAFEBOX_IOS_SHARE_(EXTENSION_STAGE_PASS|INBOX_(NATIVE_REGISTER|DRAIN_REQUEST|NATIVE_DRAIN_TRIGGER|CONTAINER_(PASS|FAIL)|DRAIN_BEGIN|DRAIN_PASS|ACCEPT)|HARDENING_|RECOVERY_)' "$LOG" || true

NEW_PID="$(python3 - "$LOG" "$PROCESS_NAME" <<'PY'
import re,sys
name=re.escape(sys.argv[2])
for line in open(sys.argv[1],errors='replace'):
    m=re.search(r'\b'+name+r'\[([0-9]+):',line)
    if m:
        print(m.group(1)); break
PY
)"
if [[ ! "$NEW_PID" =~ ^[0-9]+$ ]]; then
  echo 'SAFEBOX_IOS_COLD_SHARE_RUNTIME_FAIL: SafeBox was not launched after the Share Extension staged the file' >&2
  exit 1
fi
[[ "$NEW_PID" != "$OLD_PID" ]] || { echo 'SAFEBOX_IOS_COLD_SHARE_RUNTIME_FAIL: SafeBox was not cold-started; PID did not change' >&2; exit 1; }
echo "SAFEBOX_IOS_COLD_SHARE_PROCESS: old=$OLD_PID new=$NEW_PID start=$ARMED_AT expected=$EXPECTED_ROUTE"
echo 'SAFEBOX_IOS_COLD_SHARE_NEW_PROCESS_PASS'

if grep -Fq 'SAFEBOX_IOS_SHARE_INBOX_CONTAINER_FAIL' "$LOG"; then
  echo 'SAFEBOX_IOS_COLD_SHARE_RUNTIME_FAIL: containing app could not resolve App Group container' >&2
  exit 1
fi
python3 - "$LOG" "$EXPECTED_ROUTE" <<'PY' || { echo 'SAFEBOX_IOS_COLD_SHARE_RUNTIME_FAIL: cold-start marker order invalid or expected route not accepted' >&2; exit 1; }
import sys
lines=open(sys.argv[1],errors='replace').read().splitlines(); route=sys.argv[2]
def ids(token): return [i for i,l in enumerate(lines) if token in l]
stages=ids('SAFEBOX_IOS_SHARE_EXTENSION_STAGE_PASS')
setup=ids('SAFEBOX_IOS_SHARE_INBOX_DRAIN_REQUEST: trigger=setup')
container=ids('SAFEBOX_IOS_SHARE_INBOX_CONTAINER_PASS')
begins=ids('SAFEBOX_IOS_SHARE_INBOX_DRAIN_BEGIN')
accepts=ids('SAFEBOX_IOS_SHARE_INBOX_ACCEPT: route='+route)
passes=ids('SAFEBOX_IOS_SHARE_INBOX_DRAIN_PASS count=1')
valid=False
for s in stages:
  for d in setup:
    if not s < d: continue
    for c in container:
      if not d <= c: continue
      for b in begins:
        if not c <= b: continue
        for a in accepts:
          if not b <= a: continue
          if any(a <= p for p in passes): valid=True
if not valid: raise SystemExit(1)
PY

echo 'SAFEBOX_IOS_COLD_SHARE_EXTENSION_STAGE_PASS'
echo 'SAFEBOX_IOS_COLD_SHARE_SETUP_DRAIN_PASS'
case "$EXPECTED_ROUTE" in protect) echo 'SAFEBOX_IOS_COLD_SHARE_PROTECT_PASS';; unlock) echo 'SAFEBOX_IOS_COLD_SHARE_UNLOCK_PASS';; esac
echo 'SAFEBOX_IOS_COLD_SHARE_ORDER_PASS'
echo 'SAFEBOX_IOS_COLD_SHARE_RUNTIME_PASS'

# R63: persist schema-v2 evidence bound to arm, package and exact replay runtime.
python3 - "$LOG" "$ARM_FILE" "$EVIDENCE_FILE" "$EVIDENCE_META" "$NEW_PID" "$PACKAGE_ID_FILE" <<'PY'
import hashlib,json,os,sys,tempfile,time
log_path,arm_path,evidence_path,meta_path,new_pid,package_path=sys.argv[1:]
arm=json.load(open(arm_path,encoding='utf-8'))
lines=[line for line in open(log_path,encoding='utf-8',errors='replace') if 'SAFEBOX_IOS_SHARE_' in line]
if not lines: raise SystemExit('no SAFEBOX evidence lines to persist')
body=''.join(lines).encode('utf-8')
package_id=open(package_path,encoding='utf-8').read().strip()
if package_id != arm.get('package_id'): raise SystemExit('package changed after arm')
arm_bytes=(json.dumps(arm,sort_keys=True,separators=(',',':'))+'\n').encode('utf-8')
now=int(time.time())
def atomic_write(path,data):
    directory=os.path.dirname(path) or '.'
    fd,tmp=tempfile.mkstemp(prefix='.safebox-evidence-',dir=directory)
    try:
        os.fchmod(fd,0o600)
        with os.fdopen(fd,'wb') as out:
            out.write(data); out.flush(); os.fsync(out.fileno())
        os.replace(tmp,path); os.chmod(path,0o600)
    finally:
        if os.path.exists(tmp): os.unlink(tmp)
atomic_write(evidence_path,body)
meta={'schema_version':2,'device_udid':arm['device_udid'],'bundle_id':arm['bundle_id'],'process_name':arm['process_name'],'armed_at':arm['armed_at'],'armed_unix':int(arm['armed_unix']),'expected_route':arm['expected_route'],'package_id':arm['package_id'],'runtime_contract_sha256':arm['runtime_contract_sha256'],'arm_sha256':hashlib.sha256(arm_bytes).hexdigest(),'old_pid':int(arm['old_pid']),'new_pid':int(new_pid),'captured_unix':now,'expires_unix':now+86400,'evidence_sha256':hashlib.sha256(body).hexdigest(),'evidence_bytes':len(body)}
seal_input=(json.dumps(meta,sort_keys=True,separators=(',',':'))+'\n').encode('utf-8')+body+arm_bytes
meta['manifest_seal_sha256']=hashlib.sha256(seal_input).hexdigest()
atomic_write(meta_path,(json.dumps(meta,sort_keys=True,separators=(',',':'))+'\n').encode('utf-8'))
PY
chmod 600 "$EVIDENCE_FILE" "$EVIDENCE_META"
echo 'SAFEBOX_IOS_COLD_SHARE_DURABLE_EVIDENCE_PASS'
echo 'SAFEBOX_IOS_COLD_SHARE_EVIDENCE_SCHEMA_V2_PASS'
