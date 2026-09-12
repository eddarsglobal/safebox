#!/usr/bin/env bash
set -euo pipefail
BUNDLE_ID="${SAFEBOX_IOS_BUNDLE_ID:-com.safebox.desktop}"
DEVICE="${SAFEBOX_IOS_DEVICE_ID:-booted}"

command -v xcrun >/dev/null 2>&1 || { echo 'SAFEBOX_IOS_RUNTIME_STATUS_FAIL: xcrun unavailable' >&2; exit 1; }

if ! xcrun simctl list devices booted | grep -q 'Booted'; then
  echo 'SAFEBOX_IOS_RUNTIME_STATUS_FAIL: no booted iPhone Simulator' >&2
  exit 1
fi

echo 'SAFEBOX_IOS_SIMULATOR_BOOTED'
if APP_CONTAINER="$(xcrun simctl get_app_container "$DEVICE" "$BUNDLE_ID" app 2>/dev/null)"; then
  echo "SAFEBOX_IOS_APP_INSTALLED: $APP_CONTAINER"
  echo 'SAFEBOX_IOS_RUNTIME_STATUS_PASS'
else
  echo "SAFEBOX_IOS_APP_NOT_INSTALLED: $BUNDLE_ID"
  exit 2
fi
