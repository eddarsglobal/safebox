#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ROOT_DIR="$(cd "$APP_DIR/.." && pwd)"
TAURI_DIR="$APP_DIR/src-tauri"

# R39: standalone simulator-only replacement for Tauri's `ios xcode-script`
# when SafeBox intentionally drives xcodebuild itself.
#
# Xcode's generated shell phase expands some Tauri CLI values without shell
# quoting. In particular `--platform iOS Simulator` arrives as two argv values,
# and framework/header/definition options can contain multiple values. R36
# reconstructs those option groups before applying a strict Simulator-only
# boundary. Physical-device platforms are always refused.

PLATFORM=''
SDK_ROOT=''
FRAMEWORK_SEARCH_PATHS=''
HEADER_SEARCH_PATHS=''
GCC_PREPROCESSOR_DEFINITIONS=''
CONFIGURATION=''
ARCHES=()

join_with_space() {
  local out='' value
  for value in "$@"; do
    if [[ -n "$out" ]]; then out+=" "; fi
    out+="$value"
  done
  printf '%s' "$out"
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -v|--verbose)
      shift
      ;;
    --platform)
      shift
      VALUES=()
      while [[ $# -gt 0 && "$1" != --* ]]; do
        VALUES+=("$1")
        shift
      done
      PLATFORM="$(join_with_space "${VALUES[@]}")"
      ;;
    --sdk-root)
      [[ $# -ge 2 ]] || { echo 'SAFEBOX_IOS_RUST_BRIDGE_FAIL: --sdk-root missing value' >&2; exit 64; }
      SDK_ROOT="$2"
      shift 2
      ;;
    --framework-search-paths)
      shift
      VALUES=()
      while [[ $# -gt 0 && "$1" != --* ]]; do
        VALUES+=("$1")
        shift
      done
      FRAMEWORK_SEARCH_PATHS="$(join_with_space "${VALUES[@]}")"
      ;;
    --header-search-paths)
      shift
      VALUES=()
      while [[ $# -gt 0 && "$1" != --* ]]; do
        VALUES+=("$1")
        shift
      done
      HEADER_SEARCH_PATHS="$(join_with_space "${VALUES[@]}")"
      ;;
    --gcc-preprocessor-definitions)
      shift
      VALUES=()
      while [[ $# -gt 0 && "$1" != --* ]]; do
        VALUES+=("$1")
        shift
      done
      GCC_PREPROCESSOR_DEFINITIONS="$(join_with_space "${VALUES[@]}")"
      ;;
    --configuration)
      [[ $# -ge 2 ]] || { echo 'SAFEBOX_IOS_RUST_BRIDGE_FAIL: --configuration missing value' >&2; exit 64; }
      CONFIGURATION="$2"
      shift 2
      ;;
    --force-color)
      shift
      ;;
    --*)
      echo "SAFEBOX_IOS_RUST_BRIDGE_FAIL: unsupported xcode-script option: $1" >&2
      exit 64
      ;;
    *)
      ARCHES+=("$1")
      shift
      ;;
  esac
done

# R36 simulator boundary: require all independent signals to agree.
# This prevents the standalone bridge from ever becoming a signing bypass for
# a physical iPhone even if argv is malformed or a generated project changes.
[[ "$PLATFORM" == 'iOS Simulator' ]] || {
  echo "SAFEBOX_IOS_RUST_BRIDGE_REFUSED_PLATFORM: ${PLATFORM:-<missing>}" >&2
  exit 65
}
[[ "${PLATFORM_NAME:-}" == 'iphonesimulator' ]] || {
  echo "SAFEBOX_IOS_RUST_BRIDGE_REFUSED_XCODE_PLATFORM: ${PLATFORM_NAME:-<missing>}" >&2
  exit 65
}
[[ "${EFFECTIVE_PLATFORM_NAME:-}" == '-iphonesimulator' ]] || {
  echo "SAFEBOX_IOS_RUST_BRIDGE_REFUSED_EFFECTIVE_PLATFORM: ${EFFECTIVE_PLATFORM_NAME:-<missing>}" >&2
  exit 65
}
[[ "$SDK_ROOT" == *'/iPhoneSimulator.platform/'* ]] || {
  echo "SAFEBOX_IOS_RUST_BRIDGE_REFUSED_SDK: ${SDK_ROOT:-<missing>}" >&2
  exit 65
}
[[ -d "$SDK_ROOT" ]] || {
  echo "SAFEBOX_IOS_RUST_BRIDGE_FAIL: invalid SDK root: ${SDK_ROOT:-<missing>}" >&2
  exit 66
}
[[ "$CONFIGURATION" == 'debug' || "$CONFIGURATION" == 'release' ]] || {
  echo "SAFEBOX_IOS_RUST_BRIDGE_FAIL: invalid configuration: ${CONFIGURATION:-<missing>}" >&2
  exit 67
}
[[ ${#ARCHES[@]} -ge 1 ]] || {
  echo 'SAFEBOX_IOS_RUST_BRIDGE_FAIL: no simulator architecture supplied by Xcode' >&2
  exit 68
}

# Only true architecture tokens may survive the option parser. This catches
# future generated-script argument drift instead of silently compiling wrong.
for ARCH_TOKEN in "${ARCHES[@]}"; do
  case "$ARCH_TOKEN" in
    x86_64|arm64|arm64-sim) ;;
    *)
      echo "SAFEBOX_IOS_RUST_BRIDGE_FAIL: unexpected positional xcode-script value: $ARCH_TOKEN" >&2
      exit 69
      ;;
  esac
done

# Xcode can report more than one architecture. For a Simulator build we compile
# the first active architecture, matching ONLY_ACTIVE_ARCH=YES in our runtime.
ARCH="${ARCHES[0]}"
case "$ARCH" in
  x86_64)
    RUST_TARGET='x86_64-apple-ios'
    ENV_TRIPLE='x86_64_apple_ios'
    EXTERNAL_ARCH='x86_64'
    ;;
  arm64|arm64-sim)
    RUST_TARGET='aarch64-apple-ios-sim'
    ENV_TRIPLE='aarch64_apple_ios_sim'
    EXTERNAL_ARCH='arm64'
    ;;
  *)
    echo "SAFEBOX_IOS_RUST_BRIDGE_FAIL: unsupported simulator architecture: $ARCH" >&2
    exit 69
    ;;
esac

rustup target list --installed | grep -qx "$RUST_TARGET" || {
  echo "SAFEBOX_IOS_RUST_BRIDGE_FAIL: missing Rust target $RUST_TARGET" >&2
  echo "Run: rustup target add $RUST_TARGET" >&2
  exit 70
}

INCLUDE_DIR="$SDK_ROOT/usr/include"
[[ -d "$INCLUDE_DIR" ]] || {
  echo "SAFEBOX_IOS_RUST_BRIDGE_FAIL: iOS SDK include directory missing: $INCLUDE_DIR" >&2
  exit 71
}

DEPLOYMENT_TARGET="${SAFEBOX_IOS_MIN_VERSION:-14.0}"
ISYSROOT="-isysroot $SDK_ROOT"

# Cargo/Tauri mobile environment. No code/password/secret crosses this shell.
export RUST_BACKTRACE=1
export IPHONEOS_DEPLOYMENT_TARGET="$DEPLOYMENT_TARGET"
export FRAMEWORK_SEARCH_PATHS
export HEADER_SEARCH_PATHS
export GCC_PREPROCESSOR_DEFINITIONS
export TAURI_ENV_TARGET_TRIPLE="$RUST_TARGET"
export TAURI_ENV_ARCH="${RUST_TARGET%%-*}"
export TAURI_ENV_PLATFORM='ios'
export TAURI_ENV_FAMILY='unix'
export TAURI_ENV_DEBUG="$([[ "$CONFIGURATION" == 'debug' ]] && echo true || echo false)"
export TAURI_IOS_PROJECT_PATH="$TAURI_DIR/gen/apple"
export TAURI_IOS_APP_NAME='safebox-desktop'

# Target-specific C/ObjC flags used by native crates/build scripts.
printf -v CFLAGS_VAR 'CFLAGS_%s' "$ENV_TRIPLE"
printf -v CXXFLAGS_VAR 'CXXFLAGS_%s' "$ENV_TRIPLE"
printf -v OBJC_VAR 'OBJC_INCLUDE_PATH_%s' "$ENV_TRIPLE"
export "$CFLAGS_VAR=$ISYSROOT"
export "$CXXFLAGS_VAR=$ISYSROOT"
export "$OBJC_VAR=$INCLUDE_DIR"

# Match Tauri's normal mobile library build path. SafeBox's native Ads bridge
# registers callbacks into Rust (native -> Rust), so Cargo carries no unresolved
# Objective-C Ads symbols. The Cargo aggregate archive is passed through byte-for-byte. Duplicate archive
# member names are informational only; the real Xcode linker is authoritative
# for ABI and duplicate-symbol validation.
CARGO_ARGS=(build --locked -p safebox-desktop --lib --target "$RUST_TARGET")
PROFILE_DIR='debug'
if [[ "$CONFIGURATION" == 'release' ]]; then
  CARGO_ARGS+=(--release)
  PROFILE_DIR='release'
fi

echo "SAFEBOX_IOS_RUST_BRIDGE_ARGV_PASS: $PLATFORM | $RUST_TARGET"
echo "SAFEBOX_IOS_RUST_BRIDGE_BEGIN: $RUST_TARGET $CONFIGURATION"
echo 'SAFEBOX_IOS_RUST_TAURI_BUILD_PATH_PASS'
(
  cd "$ROOT_DIR"
  cargo "${CARGO_ARGS[@]}"
)

TARGET_DIR="$(cd "$ROOT_DIR" && cargo metadata --no-deps --format-version 1 | python3 -c 'import json,sys; print(json.load(sys.stdin)["target_directory"])')"
LIB_PATH="$TARGET_DIR/$RUST_TARGET/$PROFILE_DIR/libsafebox_desktop_lib.a"
[[ -f "$LIB_PATH" ]] || {
  echo "SAFEBOX_IOS_RUST_BRIDGE_FAIL: static library not found: $LIB_PATH" >&2
  exit 72
}

# R39: preserve Cargo's staticlib byte-for-byte. `ar` member names are not linker
# symbol identities, and the reference Mac proved our previous name-based guard
# stopped the build before Apple ld had a chance to validate the archive.
# We therefore audit member counts for diagnostics only and let Xcode perform
# the actual native link. No Swift object is removed, rewritten, or stripped.
EXTERNAL_DIR="$TAURI_DIR/gen/apple/Externals/$EXTERNAL_ARCH/$CONFIGURATION"
mkdir -p "$EXTERNAL_DIR"
TMP_LIB="$EXTERNAL_DIR/.libapp.a.r39.$$"
bash "$APP_DIR/scripts/ios_archive_passthrough.sh" "$LIB_PATH" "$TMP_LIB"

# ABI validation is delegated to the real Xcode linker.
# Xcode links this library with -lapp; a missing/incompatible mobile entry point
# is therefore a hard native link failure instead of a fragile shell nm probe.
echo 'SAFEBOX_IOS_ABI_VALIDATION: XCODE_LINKER'

mv -f "$TMP_LIB" "$EXTERNAL_DIR/libapp.a"
OUTPUT_SHA="$(shasum -a 256 "$EXTERNAL_DIR/libapp.a" | awk '{print $1}')"
SOURCE_SHA="$(shasum -a 256 "$LIB_PATH" | awk '{print $1}')"
echo "SAFEBOX_IOS_RUST_SOURCE_ARCHIVE_SHA256: $SOURCE_SHA"
[[ "$SOURCE_SHA" == "$OUTPUT_SHA" ]] || { echo 'SAFEBOX_IOS_RUST_BRIDGE_FAIL: passthrough SHA mismatch' >&2; exit 73; }
echo "SAFEBOX_IOS_RUST_BRIDGE_SHA256: $OUTPUT_SHA"
echo "SAFEBOX_IOS_RUST_BRIDGE_OUTPUT: $EXTERNAL_DIR/libapp.a"
echo 'SAFEBOX_IOS_RUST_BRIDGE_PASS' 
