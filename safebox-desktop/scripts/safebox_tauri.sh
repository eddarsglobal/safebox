#!/usr/bin/env bash
set -euo pipefail

DESKTOP_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$DESKTOP_DIR"

bash scripts/ensure_sbx_icon_source.sh

# R35: direct Xcode Simulator builds do not have Tauri's parent mobile CLI
# WebSocket server. Intercept only the generated Simulator xcode-script phase
# when our explicit runtime flag is set. Physical-device/release flows continue
# through the stock Tauri CLI and retain Apple signing requirements.
if [ "${1:-}" = "ios" ] && [ "${2:-}" = "xcode-script" ] && [ "${SAFEBOX_IOS_STANDALONE_XCODE_SCRIPT:-0}" = "1" ]; then
  shift 2
  exec bash "$DESKTOP_DIR/scripts/ios_xcode_rust_bridge.sh" "$@"
fi

# During `tauri android dev`, Gradle invokes this wrapper again for
# `android android-studio-script` while the Vite dev server is already alive.
# Never run npm/node_modules mutation from that nested runtime invocation.
if [ "${1:-}" = "android" ] && [ "${2:-}" = "android-studio-script" ]; then
  if [ ! -x "$DESKTOP_DIR/node_modules/.bin/tauri" ]; then
    echo "SAFEBOX_ANDROID_RUNTIME_TAURI_MISSING: refusing dependency mutation while Vite is running" >&2
    exit 33
  fi
else
  bash scripts/ensure_frontend_toolchain.sh >/dev/null
fi

"$DESKTOP_DIR/node_modules/.bin/tauri" "$@"

if [ "${1:-}" = "build" ]; then
  bash scripts/finalize_macos_bundle.sh
fi
