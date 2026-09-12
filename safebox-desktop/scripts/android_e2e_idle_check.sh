#!/usr/bin/env bash
set -euo pipefail

DESKTOP_DIR="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=android_device_common.sh
source "$DESKTOP_DIR/scripts/android_device_common.sh"

ADB="$(safebox_require_adb)"
SERIAL="$(safebox_select_android_serial)"
SECONDS_TO_WAIT="${SAFEBOX_E2E_IDLE_SECONDS:-60}"
PACKAGE="com.safebox.desktop"

if ! [[ "$SECONDS_TO_WAIT" =~ ^[0-9]+$ ]] || [ "$SECONDS_TO_WAIT" -lt 5 ] || [ "$SECONDS_TO_WAIT" -gt 600 ]; then
  echo "SAFEBOX_E2E_BAD_IDLE_SECONDS: choose 5..600" >&2
  exit 64
fi

if ! "$ADB" -s "$SERIAL" shell pm path "$PACKAGE" >/dev/null 2>&1; then
  echo "SAFEBOX_ANDROID_APP_NOT_INSTALLED: $PACKAGE" >&2
  exit 69
fi

"$ADB" -s "$SERIAL" logcat -c
"$ADB" -s "$SERIAL" shell am start -n "$PACKAGE/.MainActivity" >/dev/null

echo "SafeBox Android idle gate: waiting ${SECONDS_TO_WAIT}s on $SERIAL"
sleep "$SECONDS_TO_WAIT"

PID="$($ADB -s "$SERIAL" shell pidof "$PACKAGE" | tr -d '\r' || true)"
if [ -z "$PID" ]; then
  echo "SAFEBOX_ANDROID_IDLE_PROCESS_DIED" >&2
  exit 70
fi

LOG="$($ADB -s "$SERIAL" logcat -d -v brief 2>/dev/null || true)"
if printf '%s\n' "$LOG" | grep -E -i \
  "ANR in $PACKAGE|Input dispatching timed out.*$PACKAGE|am_anr.*$PACKAGE|FATAL EXCEPTION.*$PACKAGE" >/dev/null; then
  echo "SAFEBOX_ANDROID_IDLE_RUNTIME_FAILURE" >&2
  printf '%s\n' "$LOG" | grep -E -i \
    "ANR in $PACKAGE|Input dispatching timed out.*$PACKAGE|am_anr.*$PACKAGE|FATAL EXCEPTION.*$PACKAGE" >&2 || true
  exit 70
fi

echo "SAFEBOX_ANDROID_IDLE_PID: $PID"
echo "SAFEBOX_ANDROID_E2E_IDLE_PASS"
