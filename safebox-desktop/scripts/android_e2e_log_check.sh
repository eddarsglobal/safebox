#!/usr/bin/env bash
set -euo pipefail

DESKTOP_DIR="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=android_device_common.sh
source "$DESKTOP_DIR/scripts/android_device_common.sh"
ADB="$(safebox_require_adb)"
SERIAL="$(safebox_select_android_serial)"
PACKAGE="com.safebox.desktop"

LOG="$($ADB -s "$SERIAL" logcat -d -v brief 2>/dev/null || true)"
PATTERN="ANR in $PACKAGE|Input dispatching timed out.*$PACKAGE|am_anr.*$PACKAGE|FATAL EXCEPTION|Process: $PACKAGE.*has died"
if printf '%s\n' "$LOG" | grep -E -i "$PATTERN" >/dev/null; then
  echo "SAFEBOX_ANDROID_E2E_LOG_FAILURE" >&2
  printf '%s\n' "$LOG" | grep -E -i -C 3 "$PATTERN" >&2 || true
  exit 70
fi

echo "SAFEBOX_ANDROID_E2E_LOG_PASS"
