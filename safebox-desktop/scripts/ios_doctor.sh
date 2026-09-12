#!/usr/bin/env bash
set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "SAFEBOX_IOS_DOCTOR_FAIL: iOS development requires macOS" >&2
  exit 1
fi

for cmd in xcodebuild xcrun rustup pod; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "SAFEBOX_IOS_DOCTOR_FAIL: missing $cmd" >&2
    [[ "$cmd" == "pod" ]] && echo "Install with: brew install cocoapods" >&2
    exit 1
  fi
done

xcodebuild -version
xcrun --sdk iphonesimulator --show-sdk-version >/dev/null

required_targets=(aarch64-apple-ios aarch64-apple-ios-sim x86_64-apple-ios)
installed="$(rustup target list --installed)"
missing=()
for target in "${required_targets[@]}"; do
  grep -qx "$target" <<<"$installed" || missing+=("$target")
done
if (( ${#missing[@]} )); then
  echo "SAFEBOX_IOS_DOCTOR_FAIL: missing Rust targets: ${missing[*]}" >&2
  echo "Run: rustup target add ${missing[*]}" >&2
  exit 1
fi

available_iphone="$(xcrun simctl list devices available | sed -nE 's/^[[:space:]]*(iPhone[^()]*) \([0-9A-Fa-f-]+\) \((Booted|Shutdown)\).*$/\1/p' | head -1 | sed 's/[[:space:]]*$//')"
if [[ -z "$available_iphone" ]]; then
  echo "SAFEBOX_IOS_DOCTOR_FAIL: no available iPhone Simulator runtime" >&2
  echo "Install one in Xcode > Settings > Platforms." >&2
  exit 1
fi

echo "SAFEBOX_IOS_SIMULATOR_AVAILABLE: $available_iphone"
echo "SAFEBOX_IOS_DOCTOR_PASS"
