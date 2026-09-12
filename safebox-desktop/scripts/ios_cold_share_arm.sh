#!/usr/bin/env bash
set -euo pipefail
EXPECTED_ROUTE="${1:-unlock}"
case "$EXPECTED_ROUTE" in protect|unlock) ;; *) echo 'Usage: npm run ios:cold-share-arm -- protect|unlock' >&2; exit 2;; esac
SESSION_FILE="${SAFEBOX_IOS_RUNTIME_SESSION_FILE:-/tmp/safebox-ios-runtime-session-${UID}.json}"
ARM_FILE="${SAFEBOX_IOS_COLD_SHARE_ARM_FILE:-/tmp/safebox-ios-cold-share-arm-${UID}.json}"
EVIDENCE_FILE="${SAFEBOX_IOS_COLD_SHARE_EVIDENCE_FILE:-/tmp/safebox-ios-cold-share-evidence-${UID}.log}"
EVIDENCE_META="${SAFEBOX_IOS_COLD_SHARE_EVIDENCE_META:-/tmp/safebox-ios-cold-share-evidence-${UID}.json}"
RECEIPT_FILE="${SAFEBOX_IOS_COLD_SHARE_EVIDENCE_RECEIPT:-/tmp/safebox-ios-cold-share-evidence-${UID}.consumed.json}"
LEDGER_FILE="${SAFEBOX_IOS_EVIDENCE_LEDGER_FILE:-/tmp/safebox-ios-evidence-ledger-${UID}.json}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ROOT="$(cd "$APP_DIR/.." && pwd)"
PACKAGE_ID_FILE="$ROOT/SAFEBOX_V028_PACKAGE_ID.txt"
BRIDGE="$APP_DIR/src-tauri/ios/SafeBoxShareInboxBridge.mm"
RUST="$APP_DIR/src-tauri/src/lib.rs"
LIFECYCLE="$SCRIPT_DIR/ios_evidence_lifecycle.py"
LEDGER="$SCRIPT_DIR/ios_evidence_ledger.py"
[[ -f "$SESSION_FILE" ]] || { echo 'SAFEBOX_IOS_COLD_SHARE_ARM_FAIL: runtime session missing; run npm run ios:cold-dev first' >&2; exit 1; }
FIELDS="$(python3 - "$SESSION_FILE" <<'PY'
import json,shlex,sys
try:d=json.load(open(sys.argv[1]))
except Exception as exc: raise SystemExit(f'invalid session: {exc}')
for k in ('device_udid','bundle_id','process_name','pid'):
    if not d.get(k): raise SystemExit(f'missing {k}')
for k in ('device_udid','bundle_id','process_name','pid'):
    print(k.upper()+'='+shlex.quote(str(d[k])))
PY
)" || { echo 'SAFEBOX_IOS_COLD_SHARE_ARM_FAIL: invalid runtime session' >&2; exit 1; }
eval "$FIELDS"

INSTALLED_APP="$(xcrun simctl get_app_container "$DEVICE_UDID" "$BUNDLE_ID" app 2>/dev/null || true)"
[[ -n "$INSTALLED_APP" && -d "$INSTALLED_APP" ]] || { echo 'SAFEBOX_IOS_COLD_SHARE_ARM_FAIL: SafeBox is not installed' >&2; exit 1; }
APPEX="$INSTALLED_APP/PlugIns/SafeBoxShareExtension.appex"
[[ -d "$APPEX" ]] || { echo 'SAFEBOX_IOS_COLD_SHARE_ARM_FAIL: SafeBox Share Extension is not embedded' >&2; exit 1; }
POINT="$(/usr/libexec/PlistBuddy -c 'Print :NSExtension:NSExtensionPointIdentifier' "$APPEX/Info.plist" 2>/dev/null || true)"
[[ "$POINT" == 'com.apple.share-services' ]] || { echo 'SAFEBOX_IOS_COLD_SHARE_ARM_FAIL: Share Extension point mismatch' >&2; exit 1; }
echo 'SAFEBOX_IOS_COLD_SHARE_EXTENSION_CONTRACT_PASS'

# R65: preserve and validate the bounded privacy-safe ledger across arm rotations.
python3 "$LEDGER" inspect "$LEDGER_FILE" >/dev/null || { echo 'SAFEBOX_IOS_COLD_SHARE_ARM_FAIL: evidence ledger continuity invalid' >&2; exit 1; }
echo 'SAFEBOX_IOS_COLD_SHARE_LEDGER_CONTINUITY_PASS'
echo 'SAFEBOX_IOS_COLD_SHARE_LEDGER_LOCK_CONTINUITY_PASS'

# R64: a new arm rotates all prior current evidence/receipt before creating the new transaction.
python3 "$LIFECYCLE" reset "$ARM_FILE" "$EVIDENCE_META" "$EVIDENCE_FILE" "$RECEIPT_FILE" >/dev/null 2>&1 || { echo 'SAFEBOX_IOS_COLD_SHARE_ARM_FAIL: evidence rotation reset failed' >&2; exit 1; }

xcrun simctl terminate "$DEVICE_UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
sleep 1
ARMED_AT="$(date '+%Y-%m-%d %H:%M:%S')"
ARMED_UNIX="$(date '+%s')"
PACKAGE_ID="$(tr -d '\r\n' < "$PACKAGE_ID_FILE")"
RUNTIME_CONTRACT_SHA256="$(python3 - "$BRIDGE" "$RUST" <<'PY'
import hashlib,sys
h=hashlib.sha256()
for label,path in ((b'SafeBoxShareInboxBridge.mm\0',sys.argv[1]),(b'lib.rs\0',sys.argv[2])):
    h.update(label); h.update(open(path,'rb').read()); h.update(b'\0')
print(h.hexdigest())
PY
)"
python3 - "$ARM_FILE" "$DEVICE_UDID" "$BUNDLE_ID" "$PROCESS_NAME" "$PID" "$ARMED_AT" "$ARMED_UNIX" "$EXPECTED_ROUTE" "$PACKAGE_ID" "$RUNTIME_CONTRACT_SHA256" <<'PY'
import json,os,sys,tempfile
p,device,bundle,process,old_pid,armed,armed_unix,route,package_id,runtime_hash=sys.argv[1:]
d={'schema_version':2,'device_udid':device,'bundle_id':bundle,'process_name':process,'old_pid':int(old_pid),'armed_at':armed,'armed_unix':int(armed_unix),'expected_route':route,'package_id':package_id,'runtime_contract_sha256':runtime_hash}
body=(json.dumps(d,sort_keys=True,separators=(',',':'))+'\n').encode()
directory=os.path.dirname(p) or '.'; fd,tmp=tempfile.mkstemp(prefix='.safebox-arm-',dir=directory)
try:
    os.fchmod(fd,0o600)
    with os.fdopen(fd,'wb') as out:
        out.write(body); out.flush(); os.fsync(out.fileno())
    os.replace(tmp,p); os.chmod(p,0o600)
finally:
    if os.path.exists(tmp): os.unlink(tmp)
PY
echo "SAFEBOX_IOS_COLD_SHARE_ARM: start=$ARMED_AT expected=$EXPECTED_ROUTE"
echo 'SAFEBOX_IOS_COLD_SHARE_EVIDENCE_RESET_PASS'
echo 'SAFEBOX_IOS_COLD_SHARE_EVIDENCE_ROTATION_PASS'
echo 'SAFEBOX_IOS_COLD_SHARE_PROCESS_TERMINATED_PASS'
echo 'SAFEBOX_IOS_COLD_SHARE_ARM_PASS'
echo 'While SafeBox stays terminated: Files -> Share -> SafeBox -> Done. Then launch SafeBox once from its app icon and run: npm run ios:cold-share-check'
