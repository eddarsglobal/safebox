#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
D="$ROOT/safebox-desktop"
S="$D/scripts/ios_simulator_run.sh"
B="$D/scripts/ios_xcode_rust_bridge.sh"
T="$D/scripts/safebox_tauri.sh"
R="$ROOT/checkpoints/SAFEBOX_V026_IOS_BRIDGE_ARGV_HARDENING_R36_REPORT.md"

echo '[1/8] R35 standalone bridge retained'
grep -F 'SAFEBOX_IOS_STANDALONE_XCODE_SCRIPT=1' "$S" >/dev/null
grep -F 'ios_xcode_rust_bridge.sh' "$T" >/dev/null
grep -F 'SAFEBOX_IOS_RUST_BRIDGE_PASS' "$B" >/dev/null
echo 'SAFEBOX_IOS_R35_BRIDGE_RETAINED_R36_PASS'

echo '[2/8] multi-token Xcode argv parser'
grep -F 'PLATFORM="$(join_with_space' "$B" >/dev/null
grep -F -- '--framework-search-paths)' "$B" >/dev/null
grep -F -- '--header-search-paths)' "$B" >/dev/null
grep -F -- '--gcc-preprocessor-definitions)' "$B" >/dev/null
grep -F 'unexpected positional xcode-script value' "$B" >/dev/null
grep -F 'SAFEBOX_IOS_RUST_BRIDGE_ARGV_PASS' "$B" >/dev/null
echo 'SAFEBOX_IOS_XCODE_ARGV_PARSER_R36_PASS'

echo '[3/8] simulator-only defensive boundary'
grep -F "[[ \"\$PLATFORM\" == 'iOS Simulator' ]]" "$B" >/dev/null
grep -F "PLATFORM_NAME:-}" "$B" | grep -F 'iphonesimulator' >/dev/null
grep -F "EFFECTIVE_PLATFORM_NAME:-}" "$B" | grep -F -- '-iphonesimulator' >/dev/null
grep -F "iPhoneSimulator.platform" "$B" >/dev/null
grep -F 'SAFEBOX_IOS_RUST_BRIDGE_REFUSED_' "$B" >/dev/null
! grep -F 'DEVELOPMENT_TEAM=' "$B" >/dev/null
! grep -F 'APPLE_DEVELOPMENT_TEAM=' "$B" >/dev/null
echo 'SAFEBOX_IOS_SIMULATOR_BOUNDARY_R36_PASS'

echo '[4/8] exact Mac Xcode argv replay with mocked toolchain'
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"; rm -rf "$D/src-tauri/gen/apple"' EXIT
MOCKBIN="$TMP/bin"
SDK="$TMP/Xcode/iPhoneSimulator.platform/Developer/SDKs/iPhoneSimulator18.2.sdk"
MOCKTARGET="$TMP/target"
mkdir -p "$MOCKBIN" "$SDK/usr/include" "$TMP/build/include"
cat > "$MOCKBIN/rustup" <<'MOCK'
#!/usr/bin/env bash
printf '%s\n' 'x86_64-apple-ios'
MOCK
cat > "$MOCKBIN/cargo" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
if [[ "${1:-}" == 'metadata' ]]; then
  printf '{"target_directory":"%s"}\n' "$SAFEBOX_TEST_TARGET_DIR"
  exit 0
fi
TARGET=''
ARGS=("$@")
for ((i=0; i<${#ARGS[@]}; i++)); do
  if [[ "${ARGS[$i]}" == '--target' ]]; then TARGET="${ARGS[$((i+1))]}"; fi
done
[[ -n "$TARGET" ]]
OUT_LIB="$SAFEBOX_TEST_TARGET_DIR/$TARGET/debug/libsafebox_desktop_lib.a"
mkdir -p "$(dirname "$OUT_LIB")"
MEMDIR="$SAFEBOX_TEST_TARGET_DIR/mock-members"
rm -rf "$MEMDIR" "$OUT_LIB"
mkdir -p "$MEMDIR"
for M in Tauri.swift.o Invoke.swift.o Plugin.swift.o Channel.swift.o Logger.swift.o; do
  printf 'mock-%s\n' "$M" > "$MEMDIR/$M"
done
AR_TOOL="$(command -v llvm-ar || command -v ar)"
"$AR_TOOL" qc "$OUT_LIB" "$MEMDIR/Tauri.swift.o" "$MEMDIR/Invoke.swift.o" "$MEMDIR/Plugin.swift.o" "$MEMDIR/Channel.swift.o" "$MEMDIR/Logger.swift.o"
MOCK
chmod +x "$MOCKBIN/rustup" "$MOCKBIN/cargo"

OUT="$TMP/replay.out"
PATH="$MOCKBIN:$PATH" \
SAFEBOX_TEST_TARGET_DIR="$MOCKTARGET" \
PLATFORM_NAME='iphonesimulator' \
EFFECTIVE_PLATFORM_NAME='-iphonesimulator' \
  bash "$B" -v \
    --platform iOS Simulator \
    --sdk-root "$SDK" \
    --framework-search-paths "$TMP/build" "." \
    --header-search-paths "$TMP/build/include" \
    --gcc-preprocessor-definitions DEBUG=1 \
    --configuration debug x86_64 >"$OUT"
grep -F 'SAFEBOX_IOS_RUST_BRIDGE_ARGV_PASS: iOS Simulator | x86_64-apple-ios' "$OUT" >/dev/null
grep -F 'SAFEBOX_IOS_RUST_BRIDGE_PASS' "$OUT" >/dev/null
echo 'SAFEBOX_IOS_EXACT_ARGV_REPLAY_R36_PASS'

echo '[5/8] physical-device refusal replay'
DEVICE_SDK="$TMP/Xcode/iPhoneOS.platform/Developer/SDKs/iPhoneOS18.2.sdk"
mkdir -p "$DEVICE_SDK/usr/include"
set +e
PATH="$MOCKBIN:$PATH" \
SAFEBOX_TEST_TARGET_DIR="$MOCKTARGET" \
PLATFORM_NAME='iphoneos' \
EFFECTIVE_PLATFORM_NAME='-iphoneos' \
  bash "$B" -v --platform iOS --sdk-root "$DEVICE_SDK" --configuration debug arm64 >"$TMP/device.out" 2>&1
RC=$?
set -e
[[ "$RC" -ne 0 ]]
grep -E 'SAFEBOX_IOS_RUST_BRIDGE_REFUSED_(PLATFORM|XCODE_PLATFORM|EFFECTIVE_PLATFORM|SDK)' "$TMP/device.out" >/dev/null
echo 'SAFEBOX_IOS_PHYSICAL_DEVICE_REFUSAL_R36_PASS'
rm -rf "$D/src-tauri/gen/apple"

echo '[6/8] Rust output/ABI integrity retained'
grep -F "RUST_TARGET='x86_64-apple-ios'" "$B" >/dev/null
grep -F "RUST_TARGET='aarch64-apple-ios-sim'" "$B" >/dev/null
grep -F 'build --locked -p safebox-desktop --lib --target' "$B" >/dev/null
grep -F 'SAFEBOX_IOS_ABI_VALIDATION: XCODE_LINKER' "$B" >/dev/null
grep -F 'shasum -a 256' "$B" >/dev/null
grep -F 'Externals/$EXTERNAL_ARCH/$CONFIGURATION' "$B" >/dev/null
echo 'SAFEBOX_IOS_RUST_ABI_INTEGRITY_R36_PASS'

echo '[7/8] shell + council/security gate'
bash -n "$B"
bash -n "$S"
bash -n "$T"
grep -F '## 9-council checkpoint review' "$R" >/dev/null
grep -F 'Defensive HACKER / Red Team' "$R" >/dev/null
grep -F 'No SBX format or crypto change.' "$R" >/dev/null
echo 'SAFEBOX_IOS_COUNCIL_REDTEAM_R36_PASS'

echo '[8/8] checkpoint hygiene'
for bad in node_modules target .DS_Store; do
  if find "$ROOT" -name "$bad" -print -quit | grep -q .; then
    echo "R36 hygiene fail: packaged $bad" >&2
    exit 1
  fi
done
if [[ -d "$D/src-tauri/gen/apple" ]]; then
  echo 'R36 hygiene fail: generated Apple project must not be packaged' >&2
  exit 1
fi
echo 'SAFEBOX_IOS_CHECKPOINT_HYGIENE_R36_PASS'

echo 'IOS_V026_STATUS: BRIDGE_ARGV_HARDENED'
echo 'SAFEBOX_V026_IOS_BRIDGE_ARGV_HARDENING_R36_VERIFY_PASS'
