#!/usr/bin/env bash
set -euo pipefail

DESKTOP_DIR="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=android_device_common.sh
source "$DESKTOP_DIR/scripts/android_device_common.sh"

if [ "$#" -ne 2 ]; then
  echo 'Usage: npm run android:compare -- "/local/original" "/sdcard/Download/restored-file"' >&2
  exit 64
fi

LOCAL_FILE="$1"
REMOTE_FILE="$2"
[ -f "$LOCAL_FILE" ] || { echo "SAFEBOX_COMPARE_LOCAL_NOT_FOUND: $LOCAL_FILE" >&2; exit 66; }

ADB="$(safebox_require_adb)"
SERIAL="$(safebox_select_android_serial)"
REMOTE_Q="$(safebox_shell_quote "$REMOTE_FILE")"
LOCAL_SHA="$(shasum -a 256 "$LOCAL_FILE" | awk '{print $1}')"
REMOTE_SHA="$($ADB -s "$SERIAL" shell "toybox sha256sum $REMOTE_Q" | tr -d '\r' | awk '{print $1}')"

if [ -z "$REMOTE_SHA" ] || [ "$LOCAL_SHA" != "$REMOTE_SHA" ]; then
  echo "SAFEBOX_ANDROID_COMPARE_MISMATCH" >&2
  echo "local : $LOCAL_SHA" >&2
  echo "remote: ${REMOTE_SHA:-<missing>}" >&2
  exit 74
fi

echo "SAFEBOX_ANDROID_COMPARE_SHA256: $LOCAL_SHA"
echo "SAFEBOX_ANDROID_COMPARE_PASS"
