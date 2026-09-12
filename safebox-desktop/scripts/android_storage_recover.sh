#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=android_device_common.sh
source "$SCRIPT_DIR/android_device_common.sh"

ADB="$(safebox_require_adb)"
SERIAL="$(safebox_select_android_serial)"
PACKAGE="${SAFEBOX_ANDROID_PACKAGE:-com.safebox.desktop}"
MIN_FREE_KB="${SAFEBOX_ANDROID_MIN_FREE_KB:-524288}"

case "$SERIAL" in
  emulator-*) ;;
  *)
    echo "SAFEBOX_ANDROID_STORAGE_RECOVERY_REFUSED_PHYSICAL_DEVICE: $SERIAL" >&2
    exit 4
    ;;
esac

free_kb() {
  "$ADB" -s "$SERIAL" shell df -k /data 2>/dev/null \
    | tr -d '\r' \
    | awk 'NR>1 {v=$4} END {gsub(/[^0-9]/, "", v); if (v ~ /^[0-9]+$/) print v}'
}

before="$(free_kb || true)"
echo "SAFEBOX_ANDROID_STORAGE_BEFORE_KB: ${before:-unknown}"
echo "SafeBox Android storage recovery: removing only SafeBox app + SafeBox-E2E fixtures and trimming caches"

"$ADB" -s "$SERIAL" shell pm trim-caches 1G >/dev/null 2>&1 || true
"$ADB" -s "$SERIAL" uninstall "$PACKAGE" >/dev/null 2>&1 || true
"$ADB" -s "$SERIAL" shell rm -rf /sdcard/Download/SafeBox-E2E >/dev/null 2>&1 || true
"$ADB" -s "$SERIAL" shell sync >/dev/null 2>&1 || true
sleep 1

after="$(free_kb || true)"
echo "SAFEBOX_ANDROID_STORAGE_AFTER_KB: ${after:-unknown}"

if [ -n "$after" ] && [ "$after" -ge "$MIN_FREE_KB" ]; then
  echo "SAFEBOX_ANDROID_STORAGE_RECOVERY_PASS"
  exit 0
fi

echo "SAFEBOX_ANDROID_STORAGE_RECOVERY_INSUFFICIENT: ${after:-unknown} KB free; need ${MIN_FREE_KB} KB" >&2
echo "Use Android Studio > Device Manager > $SERIAL/target AVD > Wipe Data, then run npm run android:cold-dev." >&2
exit 7
