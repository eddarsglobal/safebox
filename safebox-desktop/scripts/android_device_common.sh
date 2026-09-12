#!/usr/bin/env bash
# Shared Android-device helpers for SafeBox development scripts.
# This file is sourced by other scripts; it intentionally does not set shell options.

safebox_android_sdk_root() {
  printf '%s\n' "${ANDROID_SDK_ROOT:-${ANDROID_HOME:-$HOME/Library/Android/sdk}}"
}

safebox_adb_path() {
  local sdk
  sdk="$(safebox_android_sdk_root)"
  printf '%s\n' "${SAFEBOX_ADB:-$sdk/platform-tools/adb}"
}

safebox_require_adb() {
  local adb
  adb="$(safebox_adb_path)"
  if [ ! -x "$adb" ]; then
    echo "SAFEBOX_ANDROID_ADB_NOT_FOUND: $adb" >&2
    return 2
  fi
  printf '%s\n' "$adb"
}

safebox_select_android_serial() {
  local adb serial count
  adb="$(safebox_require_adb)" || return $?

  if [ -n "${SAFEBOX_ANDROID_SERIAL:-}" ]; then
    if ! "$adb" devices | awk 'NR>1 && $2=="device" {print $1}' | grep -Fxq "$SAFEBOX_ANDROID_SERIAL"; then
      echo "SAFEBOX_ANDROID_SERIAL_NOT_READY: $SAFEBOX_ANDROID_SERIAL" >&2
      return 3
    fi
    printf '%s\n' "$SAFEBOX_ANDROID_SERIAL"
    return 0
  fi

  # Prefer a single ready emulator for local E2E work.
  serial="$($adb devices | awk 'NR>1 && $1 ~ /^emulator-/ && $2=="device" {print $1; exit}')"
  if [ -n "$serial" ]; then
    printf '%s\n' "$serial"
    return 0
  fi

  count="$($adb devices | awk 'NR>1 && $2=="device" {n++} END {print n+0}')"
  if [ "$count" -eq 1 ]; then
    $adb devices | awk 'NR>1 && $2=="device" {print $1; exit}'
    return 0
  fi

  if [ "$count" -eq 0 ]; then
    echo "SAFEBOX_ANDROID_NO_READY_DEVICE: run npm run android:cold-dev first" >&2
  else
    echo "SAFEBOX_ANDROID_MULTIPLE_DEVICES: set SAFEBOX_ANDROID_SERIAL=<serial>" >&2
  fi
  return 3
}

safebox_shell_quote() {
  # POSIX-shell single-quote escaping for a remote adb shell command.
  printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"
}
