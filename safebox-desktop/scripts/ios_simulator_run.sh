#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$APP_DIR"

# R34 simulator-only runtime path.
# Important: do NOT use `tauri ios build` here. Tauri's build command archives
# for iphoneos after/while building, which requires device signing and caused
# the R33 failure. We generate the Apple project with Tauri, then invoke the
# proven Xcode simulator BUILD action directly and install the resulting .app
# with simctl. Physical-device signing remains a separate release path.
export CI=true

bash "$SCRIPT_DIR/ensure_frontend_toolchain.sh"
bash "$SCRIPT_DIR/ios_doctor.sh"
TAURI_BIN="$APP_DIR/node_modules/.bin/tauri"
[[ -x "$TAURI_BIN" ]] || { echo 'SAFEBOX_IOS_SIM_RUN_FAIL: local Tauri CLI unavailable' >&2; exit 1; }

APPLE_DIR="$APP_DIR/src-tauri/gen/apple"
if [[ ! -d "$APPLE_DIR" ]] || ! find "$APPLE_DIR" -maxdepth 3 -name '*.xcodeproj' -print -quit 2>/dev/null | grep -q .; then
  echo 'SafeBox iOS: generating Xcode project'
  rm -rf "$APPLE_DIR"
  "$TAURI_BIN" ios init
fi

XCODEPROJ="$(find "$APPLE_DIR" -maxdepth 2 -name '*.xcodeproj' -print -quit)"
[[ -n "$XCODEPROJ" && -d "$XCODEPROJ" ]] || { echo 'SAFEBOX_IOS_SIM_RUN_FAIL: generated Xcode project not found' >&2; exit 1; }
SCHEME="${SAFEBOX_IOS_SCHEME:-safebox-desktop_iOS}"

echo "SAFEBOX_IOS_PROJECT_READY: $APPLE_DIR"

# Always restore SafeBox's official icon, then install the validated iOS
# Ads/UMP layer and the R44 native Share Extension.
bash "$SCRIPT_DIR/install_ios_app_icon.sh"
bash "$SCRIPT_DIR/install_ios_ads_privacy.sh"
bash "$SCRIPT_DIR/install_ios_share_extension.sh"
bash "$SCRIPT_DIR/install_ios_cold_open_intake.sh"

# R41: fail before the expensive Rust/Xcode build if CocoaPods restores a
# global -ObjC or if the scoped force-load no longer resolves to the immutable
# GoogleMobileAds source XCFramework slice already present under Pods.
R41_DEBUG_XCCONFIG="$APPLE_DIR/Pods/Target Support Files/Pods-$SCHEME/Pods-$SCHEME.debug.xcconfig"
[[ -f "$R41_DEBUG_XCCONFIG" ]] || { echo "SAFEBOX_IOS_SIM_RUN_FAIL: R41 aggregate xcconfig missing: $R41_DEBUG_XCCONFIG" >&2; exit 1; }
! grep -Eq -- '(^|[[:space:]])-ObjC([[:space:]]|$)' "$R41_DEBUG_XCCONFIG" || { echo 'SAFEBOX_IOS_SIM_RUN_FAIL: global -ObjC restored by CocoaPods' >&2; exit 1; }
grep -Fq -- '-force_load' "$R41_DEBUG_XCCONFIG" || { echo 'SAFEBOX_IOS_SIM_RUN_FAIL: GMA targeted force_load missing' >&2; exit 1; }
grep -Fq -- '$(SAFEBOX_GMA_FORCE_LOAD_BINARY)' "$R41_DEBUG_XCCONFIG" || { echo 'SAFEBOX_IOS_SIM_RUN_FAIL: GMA source-slice variable missing' >&2; exit 1; }
! grep -Fq -- '$(PODS_XCFRAMEWORKS_BUILD_DIR)/Google-Mobile-Ads-SDK/GoogleMobileAds.framework/GoogleMobileAds' "$R41_DEBUG_XCCONFIG" || { echo 'SAFEBOX_IOS_SIM_RUN_FAIL: obsolete R40 generated force_load path restored' >&2; exit 1; }
R41_GMA_SIM_SOURCE="$APPLE_DIR/Pods/Google-Mobile-Ads-SDK/Frameworks/GoogleMobileAdsFramework/GoogleMobileAds.xcframework/ios-arm64_x86_64-simulator/GoogleMobileAds.framework/GoogleMobileAds"
[[ -f "$R41_GMA_SIM_SOURCE" ]] || { echo "SAFEBOX_IOS_SIM_RUN_FAIL: GMA simulator source binary missing: $R41_GMA_SIM_SOURCE" >&2; exit 1; }
echo 'SAFEBOX_IOS_GLOBAL_OBJC_LINK_FLAG_REMOVED_PASS'
echo 'SAFEBOX_IOS_GMA_SOURCE_SLICE_PRECHECK_PASS'
echo 'SAFEBOX_IOS_GMA_TARGETED_FORCE_LOAD_PASS'

# CocoaPods workspace is authoritative once Ads/UMP are attached.
WORKSPACE="$(find "$APPLE_DIR" -maxdepth 1 -name '*.xcworkspace' -type d -print -quit 2>/dev/null || true)"
if [[ -z "$WORKSPACE" ]]; then
  WORKSPACE="$XCODEPROJ/project.xcworkspace"
fi
[[ -d "$WORKSPACE" ]] || { echo "SAFEBOX_IOS_SIM_RUN_FAIL: workspace not found: $WORKSPACE" >&2; exit 1; }
echo "SAFEBOX_IOS_ACTIVE_WORKSPACE: $WORKSPACE"

DEVICE_NAME="${SAFEBOX_IOS_DEVICE:-}"
if [[ -z "$DEVICE_NAME" ]]; then
  DEVICE_NAME="$(xcrun simctl list devices available | sed -nE 's/^[[:space:]]*(iPhone[^()]*) \([0-9A-Fa-f-]+\) \((Booted|Shutdown)\).*$/\1/p' | head -1 | sed 's/[[:space:]]*$//')"
fi
[[ -n "$DEVICE_NAME" ]] || { echo 'SAFEBOX_IOS_SIM_RUN_FAIL: no iPhone Simulator available' >&2; exit 1; }

DEVICE_UDID="$(SAFEBOX_IOS_DEVICE_NAME="$DEVICE_NAME" python3 - <<'PY'
import json, os, subprocess
name=os.environ['SAFEBOX_IOS_DEVICE_NAME']
data=json.loads(subprocess.check_output(['xcrun','simctl','list','devices','available','-j']))
for runtime, devices in data.get('devices', {}).items():
    for d in devices:
        if d.get('name') == name and d.get('isAvailable', True):
            print(d['udid'])
            raise SystemExit(0)
raise SystemExit(1)
PY
)" || { echo "SAFEBOX_IOS_SIM_RUN_FAIL: simulator not found: $DEVICE_NAME" >&2; exit 1; }

echo "SAFEBOX_IOS_SIMULATOR_DEVICE: $DEVICE_NAME ($DEVICE_UDID)"

# Xcode uses arm64 for Apple-Silicon Simulator builds; Tauri maps that to the
# Rust target aarch64-apple-ios-sim inside its bridge. Intel uses x86_64.
NATIVE_ARM64=0
if [[ "$(uname -m)" == 'arm64' ]]; then
  NATIVE_ARM64=1
elif [[ "$(sysctl -n hw.optional.arm64 2>/dev/null || true)" == '1' ]]; then
  NATIVE_ARM64=1
elif [[ "$(sysctl -in sysctl.proc_translated 2>/dev/null || true)" == '1' ]]; then
  NATIVE_ARM64=1
fi

if [[ "$NATIVE_ARM64" == '1' ]]; then
  XCODE_SIM_ARCH='arm64'
  RUST_SIM_TARGET='aarch64-apple-ios-sim'
else
  XCODE_SIM_ARCH='x86_64'
  RUST_SIM_TARGET='x86_64-apple-ios'
fi

echo "SAFEBOX_IOS_NATIVE_SIM_TARGET: $XCODE_SIM_ARCH ($RUST_SIM_TARGET)"
rustup target list --installed | grep -qx "$RUST_SIM_TARGET" || {
  echo "SAFEBOX_IOS_SIM_RUN_FAIL: missing Rust target $RUST_SIM_TARGET" >&2
  echo "Run: rustup target add $RUST_SIM_TARGET" >&2
  exit 1
}

STATE="$(xcrun simctl list devices | awk -v id="$DEVICE_UDID" 'index($0,id){ if ($0 ~ /\(Booted\)/) print "Booted"; else print "Shutdown"; exit }')"
if [[ "$STATE" != 'Booted' ]]; then
  xcrun simctl boot "$DEVICE_UDID"
fi
xcrun simctl bootstatus "$DEVICE_UDID" -b
open -a Simulator >/dev/null 2>&1 || true

# Direct Xcode debug builds use SafeBox's devUrl. Start Vite ourselves if port
# 1420 is not already listening. Keep it alive after app launch until Ctrl+C.
VITE_PID=''
VITE_LOG="${TMPDIR:-/tmp}/safebox-ios-vite-${USER:-user}.log"
port_ready() {
  python3 - <<'PY'
import socket
s=socket.socket()
s.settimeout(0.25)
try:
    s.connect(('127.0.0.1', 1420))
except OSError:
    raise SystemExit(1)
finally:
    s.close()
PY
}
cleanup() {
  if [[ -n "$VITE_PID" ]] && kill -0 "$VITE_PID" >/dev/null 2>&1; then
    kill "$VITE_PID" >/dev/null 2>&1 || true
    wait "$VITE_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT INT TERM

if port_ready; then
  echo 'SAFEBOX_IOS_VITE_REUSED: 127.0.0.1:1420'
else
  echo "SafeBox iOS: starting Vite dev server (log: $VITE_LOG)"
  npm run dev >"$VITE_LOG" 2>&1 &
  VITE_PID=$!
  READY=0
  for _ in $(seq 1 80); do
    if port_ready; then READY=1; break; fi
    if ! kill -0 "$VITE_PID" >/dev/null 2>&1; then
      echo 'SAFEBOX_IOS_SIM_RUN_FAIL: Vite exited before becoming ready' >&2
      cat "$VITE_LOG" >&2 || true
      exit 1
    fi
    sleep 0.25
  done
  if [[ "$READY" != '1' ]]; then
    echo 'SAFEBOX_IOS_SIM_RUN_FAIL: Vite did not become ready on port 1420' >&2
    cat "$VITE_LOG" >&2 || true
    exit 1
  fi
  echo 'SAFEBOX_IOS_VITE_READY: 127.0.0.1:1420'
fi

# Use a disposable DerivedData location so no runtime build debris is stored in
# the source checkpoint. This is a pure simulator BUILD action: no archive,
# export, provisioning profile or Development Team is involved.
DERIVED_ROOT="${SAFEBOX_IOS_DERIVED_DATA:-${TMPDIR:-/tmp}/safebox-ios-v027-derived}"
rm -rf "$DERIVED_ROOT"
mkdir -p "$DERIVED_ROOT"

# CocoaPods can replace the target base xcconfig and drop Tauri's conditional
# Externals search path. The Rust bridge still writes libapp.a to the canonical
# Tauri location, so re-add that directory explicitly while preserving all
# inherited CocoaPods/Xcode library search paths.
EXTERNAL_LIB_DIR="$APPLE_DIR/Externals/$XCODE_SIM_ARCH/debug"
XCODE_INHERITED='$(inherited)'
echo "SAFEBOX_IOS_LIBAPP_SEARCH_PATH: $EXTERNAL_LIB_DIR"

# R50: the containing app must receive the App Group entitlement during the
# Xcode signing phase itself. A post-build ad-hoc re-sign can display the
# entitlement in `codesign -d` while Simulator still denies containerURL().
APP_ENT="$APPLE_DIR/safebox-desktop_iOS/SafeBoxAppGroups.entitlements"
[[ -f "$APP_ENT" ]] || { echo 'SAFEBOX_IOS_SIM_RUN_FAIL: containing-app App Group entitlements input missing' >&2; exit 1; }
/usr/libexec/PlistBuddy -c 'Print :com.apple.security.application-groups:0' "$APP_ENT" 2>/dev/null | grep -Fxq 'group.com.safebox.desktop.share' || { echo 'SAFEBOX_IOS_SIM_RUN_FAIL: containing-app App Group entitlements input invalid' >&2; exit 1; }
echo 'SAFEBOX_IOS_SHARE_MAIN_BUILD_ENTITLEMENTS_INPUT_PASS'

echo "SafeBox iOS: direct Xcode simulator build ($XCODE_SIM_ARCH)"
echo 'SAFEBOX_IOS_DIRECT_SIMULATOR_BUILD_BEGIN'
SAFEBOX_IOS_STANDALONE_XCODE_SCRIPT=1 \
PATH="$APP_DIR/node_modules/.bin:$HOME/.cargo/bin:$PATH" \
  xcodebuild \
    -workspace "$WORKSPACE" \
    -scheme "$SCHEME" \
    -configuration debug \
    -sdk iphonesimulator \
    -destination "id=$DEVICE_UDID" \
    -derivedDataPath "$DERIVED_ROOT" \
    ARCHS="$XCODE_SIM_ARCH" \
    ONLY_ACTIVE_ARCH=YES \
    CLANG_ENABLE_MODULES=YES \
    CLANG_ENABLE_OBJC_ARC=YES \
    "CODE_SIGN_ENTITLEMENTS=$APP_ENT" \
    "LIBRARY_SEARCH_PATHS=$XCODE_INHERITED $EXTERNAL_LIB_DIR" \
    build

echo 'SAFEBOX_IOS_DIRECT_SIMULATOR_BUILD_PASS'

APP_PATH="$(find "$DERIVED_ROOT/Build/Products/debug-iphonesimulator" -maxdepth 2 -name '*.app' -type d -print -quit 2>/dev/null || true)"
[[ -n "$APP_PATH" && -d "$APP_PATH" ]] || {
  echo "SAFEBOX_IOS_SIM_RUN_FAIL: built simulator .app not found under $DERIVED_ROOT" >&2
  exit 1
}

echo "SAFEBOX_IOS_SIM_APP: $APP_PATH"

# R51 simulator entitlement proof. Xcode 16 emits two entitlement payloads for
# simulator apps: SafeBox.app.xcent is the outer code-sign payload and may be
# intentionally empty, while SafeBox.app-Simulated.xcent is injected into the
# Mach-O __TEXT,__entitlements section and is what Simulator consults for
# capabilities such as App Groups. R50 incorrectly treated `codesign -d` on
# the outer bundle as the authoritative simulator proof and stopped even though
# Xcode had generated the correct Simulated.xcent.
MAIN_SIM_XCENT="$(find "$DERIVED_ROOT/Build/Intermediates.noindex" -type f -name 'SafeBox.app-Simulated.xcent' -print -quit 2>/dev/null || true)"
[[ -n "$MAIN_SIM_XCENT" && -f "$MAIN_SIM_XCENT" ]] || { echo 'SAFEBOX_IOS_SIM_RUN_FAIL: containing-app Simulated.xcent missing' >&2; exit 1; }
/usr/libexec/PlistBuddy -c 'Print :com.apple.security.application-groups:0' "$MAIN_SIM_XCENT" 2>/dev/null | grep -Fxq 'group.com.safebox.desktop.share' || { echo 'SAFEBOX_IOS_SIM_RUN_FAIL: containing-app Simulated.xcent missing App Group' >&2; exit 1; }
MAIN_SIM_APP_ID="$(/usr/libexec/PlistBuddy -c 'Print :application-identifier' "$MAIN_SIM_XCENT" 2>/dev/null || true)"
[[ "$MAIN_SIM_APP_ID" == *.com.safebox.desktop ]] || { echo 'SAFEBOX_IOS_SIM_RUN_FAIL: containing-app Simulated.xcent application identifier mismatch' >&2; exit 1; }
echo 'SAFEBOX_IOS_SHARE_MAIN_SIMULATED_XCENT_PASS'

MAIN_EXECUTABLE="$APP_PATH/SafeBox"
[[ -f "$MAIN_EXECUTABLE" ]] || { echo 'SAFEBOX_IOS_SIM_RUN_FAIL: containing-app executable missing' >&2; exit 1; }
/usr/bin/strings "$MAIN_EXECUTABLE" | grep -Fq 'group.com.safebox.desktop.share' || { echo 'SAFEBOX_IOS_SIM_RUN_FAIL: App Group missing from simulator executable entitlement section' >&2; exit 1; }
echo 'SAFEBOX_IOS_SHARE_MAIN_EXECUTABLE_EMBEDDED_APP_GROUP_PASS'

# R46: build the Share Extension as an isolated XcodeGen project.  Do not
# mutate Tauri's generated project and do not depend on Ruby/xcodeproj.
SHARE_PROJECT="$APPLE_DIR/SafeBoxShareExtension/SafeBoxShareExtension.xcodeproj"
[[ -d "$SHARE_PROJECT" ]] || { echo "SAFEBOX_IOS_SIM_RUN_FAIL: standalone Share Extension project missing: $SHARE_PROJECT" >&2; exit 1; }
SHARE_DERIVED_ROOT="${DERIVED_ROOT}-share"
rm -rf "$SHARE_DERIVED_ROOT"
mkdir -p "$SHARE_DERIVED_ROOT"
echo 'SAFEBOX_IOS_SHARE_EXTENSION_BUILD_BEGIN'
PATH="$HOME/.cargo/bin:$PATH" \
  xcodebuild \
    -project "$SHARE_PROJECT" \
    -scheme SafeBoxShareExtension \
    -configuration debug \
    -sdk iphonesimulator \
    -destination "id=$DEVICE_UDID" \
    -derivedDataPath "$SHARE_DERIVED_ROOT" \
    ARCHS="$XCODE_SIM_ARCH" \
    ONLY_ACTIVE_ARCH=YES \
    build

BUILT_SHARE_APPEX="$(find "$SHARE_DERIVED_ROOT/Build/Products/debug-iphonesimulator" -maxdepth 2 -name 'SafeBoxShareExtension.appex' -type d -print -quit 2>/dev/null || true)"
[[ -n "$BUILT_SHARE_APPEX" && -d "$BUILT_SHARE_APPEX" ]] || { echo 'SAFEBOX_IOS_SIM_RUN_FAIL: standalone Share Extension build product missing' >&2; exit 1; }
echo 'SAFEBOX_IOS_SHARE_EXTENSION_TARGET_PASS'

SHARE_APPEX="$APP_PATH/PlugIns/SafeBoxShareExtension.appex"
mkdir -p "$APP_PATH/PlugIns"
rm -rf "$SHARE_APPEX"
cp -R "$BUILT_SHARE_APPEX" "$SHARE_APPEX"
SHARE_INFO="$SHARE_APPEX/Info.plist"
[[ -f "$SHARE_INFO" ]] || { echo 'SAFEBOX_IOS_SIM_RUN_FAIL: Share Extension Info.plist missing' >&2; exit 1; }
ACTUAL_SHARE_POINT="$(/usr/libexec/PlistBuddy -c 'Print :NSExtension:NSExtensionPointIdentifier' "$SHARE_INFO" 2>/dev/null || true)"
ACTUAL_SHARE_BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$SHARE_INFO" 2>/dev/null || true)"
ACTUAL_SHARE_EXECUTABLE="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$SHARE_INFO" 2>/dev/null || true)"
ACTUAL_SHARE_PACKAGE_TYPE="$(/usr/libexec/PlistBuddy -c 'Print :CFBundlePackageType' "$SHARE_INFO" 2>/dev/null || true)"
ACTUAL_SHARE_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$SHARE_INFO" 2>/dev/null || true)"
printf 'SAFEBOX_IOS_SHARE_EXTENSION_POINT: %s\n' "${ACTUAL_SHARE_POINT:-<missing>}"
printf 'SAFEBOX_IOS_SHARE_EXTENSION_BUNDLE_ID: %s\n' "${ACTUAL_SHARE_BUNDLE_ID:-<missing>}"
printf 'SAFEBOX_IOS_SHARE_EXTENSION_EXECUTABLE: %s\n' "${ACTUAL_SHARE_EXECUTABLE:-<missing>}"
printf 'SAFEBOX_IOS_SHARE_EXTENSION_PACKAGE_TYPE: %s\n' "${ACTUAL_SHARE_PACKAGE_TYPE:-<missing>}"
printf 'SAFEBOX_IOS_SHARE_EXTENSION_VERSION: %s\n' "${ACTUAL_SHARE_VERSION:-<missing>}"
[[ "$ACTUAL_SHARE_POINT" == 'com.apple.share-services' ]] || { echo 'SAFEBOX_IOS_SIM_RUN_FAIL: Share Extension point mismatch' >&2; exit 1; }
[[ "$ACTUAL_SHARE_BUNDLE_ID" == 'com.safebox.desktop.share' ]] || { echo 'SAFEBOX_IOS_SIM_RUN_FAIL: Share Extension bundle identifier mismatch' >&2; exit 1; }
[[ "$ACTUAL_SHARE_EXECUTABLE" == 'SafeBoxShareExtension' ]] || { echo 'SAFEBOX_IOS_SIM_RUN_FAIL: Share Extension executable mismatch' >&2; exit 1; }
[[ "$ACTUAL_SHARE_PACKAGE_TYPE" == 'XPC!' ]] || { echo 'SAFEBOX_IOS_SIM_RUN_FAIL: Share Extension package type mismatch' >&2; exit 1; }
[[ -n "$ACTUAL_SHARE_VERSION" ]] || { echo 'SAFEBOX_IOS_SIM_RUN_FAIL: Share Extension bundle version missing' >&2; exit 1; }
echo 'SAFEBOX_IOS_SHARE_EXTENSION_POINT_PASS'
echo 'SAFEBOX_IOS_SHARE_EXTENSION_BUNDLE_ID_PASS'
echo 'SAFEBOX_IOS_SHARE_EXTENSION_EXECUTABLE_PASS'
echo 'SAFEBOX_IOS_SHARE_EXTENSION_PACKAGE_TYPE_PASS'
echo 'SAFEBOX_IOS_SHARE_EXTENSION_VERSION_PASS'
echo 'SAFEBOX_IOS_SHARE_EXTENSION_BUNDLE_CONTRACT_PASS'

# R51: preserve the extension exactly as Xcode signed it. Its simulator App
# Group capability is embedded in its executable's simulated entitlement
# section; a post-build entitlement rewrite is unnecessary and can obscure the
# actual capability source. After embedding, only re-sign the containing app
# outer bundle so its resource seal includes PlugIns/SafeBoxShareExtension.appex.
SHARE_EXECUTABLE="$SHARE_APPEX/SafeBoxShareExtension"
[[ -f "$SHARE_EXECUTABLE" ]] || { echo 'SAFEBOX_IOS_SIM_RUN_FAIL: Share Extension executable missing after embed' >&2; exit 1; }
/usr/bin/strings "$SHARE_EXECUTABLE" | grep -Fq 'group.com.safebox.desktop.share' || { echo 'SAFEBOX_IOS_SIM_RUN_FAIL: Share Extension simulated App Group entitlement missing' >&2; exit 1; }
echo 'SAFEBOX_IOS_SHARE_EXTENSION_SIMULATED_APP_GROUP_PASS'
/usr/bin/codesign --verify --strict "$SHARE_APPEX" >/dev/null 2>&1 || { echo 'SAFEBOX_IOS_SIM_RUN_FAIL: Share Extension signature invalid after embed' >&2; exit 1; }

MAIN_SIGN_XCENT="$(find "$DERIVED_ROOT/Build/Intermediates.noindex" -type f -name 'SafeBox.app.xcent' -print -quit 2>/dev/null || true)"
[[ -n "$MAIN_SIGN_XCENT" && -f "$MAIN_SIGN_XCENT" ]] || { echo 'SAFEBOX_IOS_SIM_RUN_FAIL: containing-app Xcode sign xcent missing' >&2; exit 1; }
/usr/bin/codesign --force --sign - --timestamp=none --entitlements "$MAIN_SIGN_XCENT" "$APP_PATH" >/dev/null
/usr/bin/codesign --verify --deep --strict "$APP_PATH" >/dev/null 2>&1 || { echo 'SAFEBOX_IOS_SIM_RUN_FAIL: containing-app signature invalid after extension embed' >&2; exit 1; }

# Re-signing the outer bundle must not remove the simulator entitlement section
# already linked into the main executable.
/usr/bin/strings "$MAIN_EXECUTABLE" | grep -Fq 'group.com.safebox.desktop.share' || { echo 'SAFEBOX_IOS_SIM_RUN_FAIL: containing-app embedded App Group lost after final signing' >&2; exit 1; }
echo 'SAFEBOX_IOS_SHARE_MAIN_FINAL_EMBEDDED_APP_GROUP_PASS'
echo 'SAFEBOX_IOS_SHARE_APP_GROUP_RUNTIME_ENTITLEMENTS_PASS'
echo 'SAFEBOX_IOS_SHARE_EXTENSION_EMBED_PASS'
BUNDLE_ID="${SAFEBOX_IOS_BUNDLE_ID:-com.safebox.desktop}"
xcrun simctl uninstall "$DEVICE_UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
xcrun simctl install "$DEVICE_UDID" "$APP_PATH"

# R56: install_ios_cold_open_intake.sh authoritatively replaces the generated
# iOS document registration after Tauri project generation. Validate the bundle
# that Simulator actually registered and fail on duplicate/conflicting entries.
INSTALLED_APP="$(xcrun simctl get_app_container "$DEVICE_UDID" "$BUNDLE_ID" app 2>/dev/null || true)"
[[ -n "$INSTALLED_APP" && -d "$INSTALLED_APP" ]] || { echo 'SAFEBOX_IOS_SIM_RUN_FAIL: installed SafeBox container unavailable for R55 association proof' >&2; exit 1; }
INSTALLED_INFO="$INSTALLED_APP/Info.plist"
[[ -f "$INSTALLED_INFO" ]] || { echo 'SAFEBOX_IOS_SIM_RUN_FAIL: installed SafeBox Info.plist missing' >&2; exit 1; }
python3 "$SCRIPT_DIR/ios_sbx_document_contract_check.py" "$INSTALLED_INFO" || { echo 'SAFEBOX_IOS_SIM_RUN_FAIL: installed SBX document contract invalid' >&2; exit 1; }
echo 'SAFEBOX_IOS_COLD_OPEN_GENERATED_REGISTRATION_RUNTIME_PROOF_PASS'
echo 'SAFEBOX_IOS_COLD_OPEN_SINGLE_REGISTRATION_INSTALL_PASS'
echo 'SAFEBOX_IOS_COLD_OPEN_DOCUMENT_OWNER_INSTALL_PASS'
# R42: capture the exact start of this runtime session before launch so the
# Ads/UMP verifier can retrieve one-shot bootstrap markers hours later without
# accepting stale evidence from an older SafeBox run.
RUNTIME_SESSION_FILE="${SAFEBOX_IOS_RUNTIME_SESSION_FILE:-/tmp/safebox-ios-runtime-session-${UID}.json}"
RUNTIME_SESSION_START="$(date '+%Y-%m-%d %H:%M:%S')"
PROCESS_NAME="$(basename "$APP_PATH" .app)"
LAUNCH_OUTPUT="$(xcrun simctl launch "$DEVICE_UDID" "$BUNDLE_ID")"
echo "$LAUNCH_OUTPUT"
APP_PID="$(printf '%s\n' "$LAUNCH_OUTPUT" | sed -nE 's/^.*:[[:space:]]*([0-9]+)[[:space:]]*$/\1/p' | tail -1)"
[[ "$APP_PID" =~ ^[0-9]+$ ]] || { echo "SAFEBOX_IOS_SIM_RUN_FAIL: could not parse launched app PID from: $LAUNCH_OUTPUT" >&2; exit 1; }
SAFEBOX_SESSION_PATH="$RUNTIME_SESSION_FILE" \
SAFEBOX_SESSION_UDID="$DEVICE_UDID" \
SAFEBOX_SESSION_BUNDLE="$BUNDLE_ID" \
SAFEBOX_SESSION_PROCESS="$PROCESS_NAME" \
SAFEBOX_SESSION_PID="$APP_PID" \
SAFEBOX_SESSION_START="$RUNTIME_SESSION_START" \
python3 - <<'PY_SESSION'
import json, os
from pathlib import Path
p=Path(os.environ['SAFEBOX_SESSION_PATH'])
p.write_text(json.dumps({
    'device_udid': os.environ['SAFEBOX_SESSION_UDID'],
    'bundle_id': os.environ['SAFEBOX_SESSION_BUNDLE'],
    'process_name': os.environ['SAFEBOX_SESSION_PROCESS'],
    'pid': int(os.environ['SAFEBOX_SESSION_PID']),
    'log_start': os.environ['SAFEBOX_SESSION_START'],
}, sort_keys=True) + '\n')
p.chmod(0o600)
PY_SESSION

echo "SAFEBOX_IOS_RUNTIME_SESSION_FILE: $RUNTIME_SESSION_FILE"
echo "SAFEBOX_IOS_RUNTIME_SESSION_PID: $APP_PID"
echo 'SAFEBOX_IOS_RUNTIME_SESSION_CAPTURE_PASS'
echo "SAFEBOX_IOS_SIMULATOR_INSTALL_PASS: $BUNDLE_ID"
echo 'SAFEBOX_IOS_RUNTIME_BOOT_PASS'

# If this script owns Vite, stay in the foreground so hot reload/devUrl remains
# available. The user can run ios:runtime-status in a second Terminal.
if [[ -n "$VITE_PID" ]]; then
  echo 'SAFEBOX_IOS_DEV_SERVER_ACTIVE: press Ctrl+C to stop'
  wait "$VITE_PID"
fi
