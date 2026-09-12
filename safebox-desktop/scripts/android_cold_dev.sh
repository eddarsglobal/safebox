#!/usr/bin/env bash
set -euo pipefail

DESKTOP_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$DESKTOP_DIR"

ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-${ANDROID_HOME:-$HOME/Library/Android/sdk}}"
ADB="${SAFEBOX_ADB:-$ANDROID_SDK_ROOT/platform-tools/adb}"
EMULATOR="${SAFEBOX_EMULATOR:-$ANDROID_SDK_ROOT/emulator/emulator}"

ANDROID_PACKAGE="${SAFEBOX_ANDROID_PACKAGE:-com.safebox.desktop}"
ANDROID_MIN_FREE_KB="${SAFEBOX_ANDROID_MIN_FREE_KB:-524288}"

android_data_free_kb() {
  local serial="$1"
  "$ADB" -s "$serial" shell df -k /data 2>/dev/null \
    | tr -d '\r' \
    | awk 'NR>1 {v=$4} END {gsub(/[^0-9]/, "", v); if (v ~ /^[0-9]+$/) print v}'
}

ensure_emulator_install_space() {
  local serial="$1" free_kb after_kb
  free_kb="$(android_data_free_kb "$serial" || true)"
  if [ -z "$free_kb" ]; then
    echo "SAFEBOX_ANDROID_STORAGE_PROBE_UNAVAILABLE: $serial" >&2
    return 0
  fi

  echo "SAFEBOX_ANDROID_STORAGE_FREE_KB: $free_kb"
  if [ "$free_kb" -ge "$ANDROID_MIN_FREE_KB" ]; then
    echo "SAFEBOX_ANDROID_STORAGE_READY: $serial"
    return 0
  fi

  echo "SafeBox Android: low emulator storage; reclaiming only SafeBox dev/test data"
  "$ADB" -s "$serial" shell pm trim-caches 1G >/dev/null 2>&1 || true
  "$ADB" -s "$serial" uninstall "$ANDROID_PACKAGE" >/dev/null 2>&1 || true
  "$ADB" -s "$serial" shell rm -rf /sdcard/Download/SafeBox-E2E >/dev/null 2>&1 || true
  "$ADB" -s "$serial" shell sync >/dev/null 2>&1 || true
  sleep 1

  after_kb="$(android_data_free_kb "$serial" || true)"
  echo "SAFEBOX_ANDROID_STORAGE_AFTER_RECOVERY_KB: ${after_kb:-unknown}"
  if [ -n "$after_kb" ] && [ "$after_kb" -ge "$ANDROID_MIN_FREE_KB" ]; then
    echo "SAFEBOX_ANDROID_STORAGE_RECOVERED: $serial"
    return 0
  fi

  echo "SAFEBOX_ANDROID_STORAGE_STILL_LOW: ${after_kb:-unknown} KB free; need ${ANDROID_MIN_FREE_KB} KB" >&2
  echo "Run: npm run android:storage-recover" >&2
  echo "If that is still insufficient, wipe the dedicated test AVD in Android Studio Device Manager and rerun android:cold-dev." >&2
  return 7
}

if [ ! -x "$ADB" ]; then
  echo "SAFEBOX_ANDROID_ADB_NOT_FOUND: $ADB" >&2
  exit 2
fi
if [ ! -x "$EMULATOR" ]; then
  echo "SAFEBOX_ANDROID_EMULATOR_NOT_FOUND: $EMULATOR" >&2
  exit 2
fi

ANDROID_PROJECT_DIR="$DESKTOP_DIR/src-tauri/gen/android"

ensure_frontend_toolchain() {
  bash "$DESKTOP_DIR/scripts/ensure_frontend_toolchain.sh"
}


ensure_android_project() {
  # The generated Android Studio project is intentionally not shipped in
  # checkpoints. Recreate it deterministically from tauri.conf.json when absent.
  if [ -f "$ANDROID_PROJECT_DIR/gradlew" ] && [ -d "$ANDROID_PROJECT_DIR/app" ]; then
    echo "SAFEBOX_ANDROID_PROJECT_REUSED: $ANDROID_PROJECT_DIR"
    return 0
  fi

  if [ -e "$ANDROID_PROJECT_DIR" ]; then
    echo "SafeBox Android: removing incomplete generated Android project"
    rm -rf "$ANDROID_PROJECT_DIR"
  fi

  ensure_frontend_toolchain
  echo "SafeBox Android: generating Android Studio project"
  "$DESKTOP_DIR/node_modules/.bin/tauri" android init

  if [ ! -f "$ANDROID_PROJECT_DIR/gradlew" ] || [ ! -d "$ANDROID_PROJECT_DIR/app" ]; then
    echo "SAFEBOX_ANDROID_INIT_FAILED: generated project is incomplete" >&2
    exit 6
  fi
  echo "SAFEBOX_ANDROID_PROJECT_READY: $ANDROID_PROJECT_DIR"
}

ensure_android_project
ensure_frontend_toolchain

# Tauri generates mobile launcher assets into the generated Android project.
# Re-apply the official SafeBox icon after init/re-init and verify every density.
bash "$DESKTOP_DIR/scripts/install_android_launcher_icon.sh"

# If a healthy physical Android device is already connected, use it.
# Emulators are handled below so we can identify their exact AVD and boot state.
physical_serial="$($ADB devices 2>/dev/null | awk 'NR>1 && $1 !~ /^emulator-/ && $2=="device" {print $1; exit}')"
if [ -n "$physical_serial" ]; then
  echo "SafeBox Android: using already connected physical device $physical_serial"
  exec "$DESKTOP_DIR/node_modules/.bin/tauri" android dev
fi

# Restart adb so stale/offline registrations do not poison device discovery.
$ADB kill-server >/dev/null 2>&1 || true
$ADB start-server >/dev/null

AVDS="$($EMULATOR -list-avds | sed '/^[[:space:]]*$/d')"
if [ -z "$AVDS" ]; then
  echo "SAFEBOX_ANDROID_NO_AVD: create an Android Virtual Device in Android Studio first" >&2
  exit 3
fi

if [ -n "${SAFEBOX_ANDROID_AVD:-}" ]; then
  AVD="$SAFEBOX_ANDROID_AVD"
elif printf '%s\n' "$AVDS" | grep -Fxq "Pixel_9_Pro_XL_API_35"; then
  AVD="Pixel_9_Pro_XL_API_35"
else
  AVD="$(printf '%s\n' "$AVDS" | head -n 1)"
fi
if ! printf '%s\n' "$AVDS" | grep -Fxq "$AVD"; then
  echo "SAFEBOX_ANDROID_AVD_NOT_FOUND: $AVD" >&2
  echo "Available AVDs:" >&2
  printf '%s\n' "$AVDS" >&2
  exit 3
fi

avd_for_serial() {
  local serial="$1"
  "$ADB" -s "$serial" emu avd name 2>/dev/null \
    | tr -d '\r' \
    | awk 'NF && $0 != "OK" {print; exit}'
}

boot_complete() {
  local serial="$1"
  [ "$("$ADB" -s "$serial" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r' || true)" = "1" ] \
    && "$ADB" -s "$serial" shell pm path android >/dev/null 2>&1
}

# adb may need a moment to rediscover an emulator that survived the daemon restart.
existing_serial=""
for _ in $(seq 1 8); do
  while read -r serial state; do
    case "$serial" in
      emulator-*)
        if [ "$(avd_for_serial "$serial" || true)" = "$AVD" ]; then
          existing_serial="$serial"
          break
        fi
        ;;
    esac
  done < <("$ADB" devices | awk 'NR>1 && NF>=2 {print $1, $2}')
  [ -n "$existing_serial" ] && break
  sleep 1
done

if [ -n "$existing_serial" ]; then
  if boot_complete "$existing_serial"; then
    echo "SAFEBOX_ANDROID_REUSED_READY: $AVD ($existing_serial)"
    ensure_emulator_install_space "$existing_serial"
    exec "$DESKTOP_DIR/node_modules/.bin/tauri" android dev "$AVD"
  fi

  echo "SafeBox Android: stopping stale/incomplete $AVD ($existing_serial)"
  "$ADB" -s "$existing_serial" emu kill >/dev/null 2>&1 || true
  for _ in $(seq 1 20); do
    if ! "$ADB" devices | awk 'NR>1 {print $1}' | grep -Fxq "$existing_serial"; then
      break
    fi
    sleep 1
  done
fi

# An emulator process can survive while adb has forgotten it. Detect the exact
# target AVD by process arguments and terminate only that orphan before launch.
avd_pids() {
  ps -axo pid=,command= | awk -v avd="$AVD" '
    index($0, "-avd " avd) || index($0, "@" avd) { print $1 }
  '
}

orphan_pids="$(avd_pids || true)"
if [ -n "$orphan_pids" ]; then
  echo "SafeBox Android: removing orphan process(es) for $AVD: $orphan_pids"
  for pid in $orphan_pids; do
    kill "$pid" >/dev/null 2>&1 || true
  done
  for _ in $(seq 1 20); do
    remaining="$(avd_pids || true)"
    [ -z "$remaining" ] && break
    sleep 1
  done
  remaining="$(avd_pids || true)"
  if [ -n "$remaining" ]; then
    for pid in $remaining; do
      kill -9 "$pid" >/dev/null 2>&1 || true
    done
    sleep 1
  fi
fi

# Clean any other stale emulator registrations. Healthy unrelated physical
# devices are never killed here.
while read -r serial state; do
  case "$serial" in
    emulator-*)
      if [ "$state" != "device" ]; then
        "$ADB" -s "$serial" emu kill >/dev/null 2>&1 || true
      fi
      ;;
  esac
done < <("$ADB" devices | awk 'NR>1 && NF>=2 {print $1, $2}')

LOG_DIR="${TMPDIR:-/tmp}/safebox-android"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/${AVD}.log"

# Defensive last check: never launch a second process for the same AVD.
if [ -n "$(avd_pids || true)" ]; then
  echo "SAFEBOX_ANDROID_DUPLICATE_AVD_GUARD: $AVD is still running; refusing a second launch" >&2
  exit 4
fi

echo "SafeBox Android: cold-booting $AVD (snapshots disabled)"
nohup "$EMULATOR" \
  -avd "$AVD" \
  -no-snapshot-load \
  -no-snapshot-save \
  -no-boot-anim \
  >"$LOG_FILE" 2>&1 &
EMU_PID=$!

serial=""
for _ in $(seq 1 120); do
  while read -r candidate state; do
    case "$candidate" in
      emulator-*)
        if [ "$state" = "device" ] && [ "$(avd_for_serial "$candidate" || true)" = "$AVD" ]; then
          serial="$candidate"
          break
        fi
        ;;
    esac
  done < <("$ADB" devices | awk 'NR>1 && NF>=2 {print $1, $2}')
  [ -n "$serial" ] && break

  if ! kill -0 "$EMU_PID" 2>/dev/null; then
    echo "SAFEBOX_ANDROID_EMULATOR_EXITED_EARLY" >&2
    tail -n 80 "$LOG_FILE" >&2 || true
    exit 4
  fi
  sleep 1
done

if [ -z "$serial" ]; then
  echo "SAFEBOX_ANDROID_ADB_TIMEOUT: emulator did not become an adb device" >&2
  tail -n 80 "$LOG_FILE" >&2 || true
  exit 4
fi

echo "SafeBox Android: adb device detected as $serial; waiting for Android boot"
booted=""
for _ in $(seq 1 180); do
  if boot_complete "$serial"; then
    booted="1"
    break
  fi
  sleep 1
done

if [ "$booted" != "1" ]; then
  echo "SAFEBOX_ANDROID_BOOT_TIMEOUT: Android did not finish booting" >&2
  tail -n 80 "$LOG_FILE" >&2 || true
  exit 5
fi

echo "SAFEBOX_ANDROID_COLD_BOOT_READY: $AVD ($serial)"
ensure_emulator_install_space "$serial"
exec "$DESKTOP_DIR/node_modules/.bin/tauri" android dev "$AVD"
