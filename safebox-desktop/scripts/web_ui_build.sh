#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DESKTOP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
WASM_SRC="$DESKTOP_DIR/public/safebox_core.wasm"

[[ -s "$WASM_SRC" ]] || { echo "SAFEBOX_WEB_UI_BUILD_FAIL: canonical WASM missing"; exit 1; }
if command -v shasum >/dev/null 2>&1; then
  WASM_SHA="$(shasum -a 256 "$WASM_SRC" | awk '{print $1}')"
else
  WASM_SHA="$(sha256sum "$WASM_SRC" | awk '{print $1}')"
fi
WASM_SHORT="${WASM_SHA:0:12}"
WASM_FILE="safebox_core.${WASM_SHORT}.wasm"
HASHED_PUBLIC="$DESKTOP_DIR/public/$WASM_FILE"

cleanup() { rm -f "$HASHED_PUBLIC"; }
trap cleanup EXIT
cp "$WASM_SRC" "$HASHED_PUBLIC"
chmod 0644 "$HASHED_PUBLIC"

echo "SAFEBOX_WEB_WASM_CONTENT_ADDRESS_PASS file=$WASM_FILE"
cd "$DESKTOP_DIR"
tsc
VITE_SAFEBOX_WASM_FILE="$WASM_FILE" vite build --mode web
rm -f "$DESKTOP_DIR/dist/safebox_core.wasm"
[[ -s "$DESKTOP_DIR/dist/$WASM_FILE" ]] || { echo "SAFEBOX_WEB_UI_BUILD_FAIL: hashed WASM missing from dist"; exit 1; }
echo "SAFEBOX_WEB_UI_BUILD_PASS"
