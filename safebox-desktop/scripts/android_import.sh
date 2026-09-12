#!/usr/bin/env bash
set -euo pipefail

DESKTOP_DIR="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=android_device_common.sh
source "$DESKTOP_DIR/scripts/android_device_common.sh"

if [ "$#" -ne 1 ]; then
  echo 'Usage: npm run android:import -- "/absolute/path/to/file"' >&2
  exit 64
fi

SOURCE="$1"
if [ ! -f "$SOURCE" ]; then
  echo "SAFEBOX_ANDROID_IMPORT_SOURCE_NOT_FOUND: $SOURCE" >&2
  exit 66
fi

ADB="$(safebox_require_adb)"
SERIAL="$(safebox_select_android_serial)"
DEST_DIR="${SAFEBOX_ANDROID_IMPORT_DIR:-/sdcard/Download/SafeBox-E2E}"
BASENAME="$(basename "$SOURCE")"
REMOTE_PATH="$DEST_DIR/$BASENAME"
REMOTE_DIR_Q="$(safebox_shell_quote "$DEST_DIR")"
REMOTE_PATH_Q="$(safebox_shell_quote "$REMOTE_PATH")"

"$ADB" -s "$SERIAL" shell "mkdir -p $REMOTE_DIR_Q"

echo "SafeBox Android import: $SOURCE"
echo " -> $SERIAL:$REMOTE_PATH"
"$ADB" -s "$SERIAL" push "$SOURCE" "$REMOTE_PATH"

LOCAL_SHA="$(shasum -a 256 "$SOURCE" | awk '{print $1}')"
REMOTE_SHA="$($ADB -s "$SERIAL" shell "toybox sha256sum $REMOTE_PATH_Q" | tr -d '\r' | awk '{print $1}')"
if [ -z "$REMOTE_SHA" ] || [ "$LOCAL_SHA" != "$REMOTE_SHA" ]; then
  echo "SAFEBOX_ANDROID_IMPORT_HASH_MISMATCH" >&2
  echo "local : $LOCAL_SHA" >&2
  echo "remote: ${REMOTE_SHA:-<missing>}" >&2
  exit 74
fi

# Best effort: make media/document providers notice the new file immediately.
REMOTE_URI="file://$REMOTE_PATH"
"$ADB" -s "$SERIAL" shell am broadcast \
  -a android.intent.action.MEDIA_SCANNER_SCAN_FILE \
  -d "$REMOTE_URI" >/dev/null 2>&1 || true

echo "SAFEBOX_ANDROID_IMPORT_SHA256: $LOCAL_SHA"
echo "SAFEBOX_ANDROID_IMPORT_READY: $REMOTE_PATH"
