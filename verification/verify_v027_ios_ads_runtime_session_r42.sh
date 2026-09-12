#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHECK="$ROOT/safebox-desktop/scripts/ios_ads_runtime_check.sh"
RUNNER="$ROOT/safebox-desktop/scripts/ios_simulator_run.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

bash -n "$CHECK"
bash -n "$RUNNER"
grep -Fq 'SAFEBOX_IOS_RUNTIME_SESSION_CAPTURE_PASS' "$RUNNER"
grep -Fq -- '--start "$LOG_START"' "$CHECK"
grep -Fq 'process == \"$PROCESS_NAME\"' "$CHECK"
grep -Fq 'SAFEBOX_IOS_ADS_RUNTIME_SESSION_SCOPE_PASS' "$CHECK"
grep -Fq 'SAFEBOX_IOS_ADS_ORDER_PASS' "$CHECK"
! grep -Fq -- '--last 10m' "$CHECK"

SESSION="$TMP/session.json"
cat > "$SESSION" <<'JSON'
{"bundle_id":"com.safebox.desktop","device_udid":"TEST-UDID","log_start":"2026-08-29 19:44:00","pid":49434,"process_name":"SafeBox"}
JSON

mkdir -p "$TMP/bin"
cat > "$TMP/bin/xcrun" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
if [[ "$1 $2 $3 $4" == 'simctl list devices booted' ]]; then
  cat <<'JSON'
{"devices":{"com.apple.CoreSimulator.SimRuntime.iOS-18-2":[{"udid":"TEST-UDID","state":"Booted"}]}}
JSON
  exit 0
fi
if [[ "$1" == 'simctl' && "$2" == 'spawn' ]]; then
  cat <<'LOG'
2026-08-29 19:44:01 SafeBox SAFEBOX_IOS_UMP_UPDATE_BEGIN
2026-08-29 19:44:02 SafeBox SAFEBOX_IOS_UMP_UPDATE_PASS
2026-08-29 19:44:03 SafeBox SAFEBOX_IOS_UMP_CAN_REQUEST_ADS: YES
2026-08-29 19:44:04 SafeBox SAFEBOX_IOS_GMA_INIT_PASS
2026-08-29 19:44:05 SafeBox SAFEBOX_IOS_BANNER_LOAD_BEGIN
2026-08-29 19:44:06 SafeBox SAFEBOX_IOS_BANNER_LOAD_PASS
2026-08-29 20:05:18 SafeBox SAFEBOX_IOS_BANNER_LOAD_PASS
LOG
  exit 0
fi
exit 99
MOCK
chmod +x "$TMP/bin/xcrun"
OUT="$(PATH="$TMP/bin:$PATH" SAFEBOX_IOS_RUNTIME_SESSION_FILE="$SESSION" bash "$CHECK")"
grep -Fq 'SAFEBOX_IOS_ADS_RUNTIME_SESSION_SCOPE_PASS' <<<"$OUT"
grep -Fq 'SAFEBOX_IOS_ADS_ORDER_PASS' <<<"$OUT"
grep -Fq 'SAFEBOX_IOS_ADS_RUNTIME_PASS' <<<"$OUT"

# Fail closed when GMA appears before UMP in the scoped current-session log.
python3 - <<'PY' "$TMP/bin/xcrun"
from pathlib import Path
import sys
p=Path(sys.argv[1])
s=p.read_text()
s=s.replace('2026-08-29 19:44:01 SafeBox SAFEBOX_IOS_UMP_UPDATE_BEGIN\n2026-08-29 19:44:02 SafeBox SAFEBOX_IOS_UMP_UPDATE_PASS\n2026-08-29 19:44:03 SafeBox SAFEBOX_IOS_UMP_CAN_REQUEST_ADS: YES\n2026-08-29 19:44:04 SafeBox SAFEBOX_IOS_GMA_INIT_PASS', '2026-08-29 19:44:01 SafeBox SAFEBOX_IOS_GMA_INIT_PASS\n2026-08-29 19:44:04 SafeBox SAFEBOX_IOS_UMP_UPDATE_BEGIN')
p.write_text(s)
PY
if PATH="$TMP/bin:$PATH" SAFEBOX_IOS_RUNTIME_SESSION_FILE="$SESSION" bash "$CHECK" >/dev/null 2>&1; then
  echo 'SAFEBOX_IOS_ADS_RUNTIME_SESSION_R42_FAIL: invalid marker order unexpectedly accepted' >&2
  exit 1
fi

echo 'SAFEBOX_IOS_ADS_RUNTIME_SESSION_R42_PASS'
