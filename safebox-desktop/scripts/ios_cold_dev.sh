#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# R34: generate with Tauri, but build the iPhone Simulator target directly
# with xcodebuild. Never call `tauri ios build` here because it archives for
# iphoneos and reintroduces Development Team/device-signing requirements.
exec bash "$SCRIPT_DIR/ios_simulator_run.sh"
