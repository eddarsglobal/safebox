#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DESKTOP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DIST="$DESKTOP_DIR/dist"
PORT="${SAFEBOX_WEB_E2E_PORT:-4173}"
BASE="http://127.0.0.1:$PORT"
TIMEOUT="${SAFEBOX_WEB_E2E_TIMEOUT:-90}"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/safebox-web-e2e.XXXXXX")"
SERVER_PID=""
cleanup() {
  [[ -n "$SERVER_PID" ]] && kill "$SERVER_PID" >/dev/null 2>&1 || true
  rm -rf "$TMP"
}
trap cleanup EXIT INT TERM

[[ -f "$DIST/index.html" ]] || { echo "SAFEBOX_WEB_BROWSER_E2E_FAIL: run npm run web:build first"; exit 1; }
WASM_FILE="$(cd "$DIST" && ls safebox_core.*.wasm 2>/dev/null | head -n1 || true)"
[[ -n "$WASM_FILE" ]] || { echo "SAFEBOX_WEB_BROWSER_E2E_FAIL: content-addressed WASM missing"; exit 1; }

BROWSER="${SAFEBOX_WEB_BROWSER:-}"
if [[ -z "$BROWSER" ]]; then
  candidates=(
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
    "/Applications/Chromium.app/Contents/MacOS/Chromium"
    "$(command -v google-chrome 2>/dev/null || true)"
    "$(command -v chromium 2>/dev/null || true)"
    "$(command -v chromium-browser 2>/dev/null || true)"
  )
  for candidate in "${candidates[@]}"; do
    if [[ -n "$candidate" && -x "$candidate" ]]; then BROWSER="$candidate"; break; fi
  done
fi
[[ -n "$BROWSER" && -x "$BROWSER" ]] || { echo "SAFEBOX_WEB_BROWSER_E2E_FAIL: Chrome/Chromium not found"; exit 1; }
echo "SAFEBOX_WEB_BROWSER_FOUND_PASS"

python3 "$SCRIPT_DIR/web_prod_server.py" --bind 127.0.0.1 --port "$PORT" >"$TMP/server.log" 2>&1 &
SERVER_PID=$!
for _ in $(seq 1 100); do
  if curl -fsS "$BASE/" >/dev/null 2>&1; then break; fi
  sleep 0.1
done
curl -fsS "$BASE/" >/dev/null || { cat "$TMP/server.log"; echo "SAFEBOX_WEB_BROWSER_E2E_FAIL: production server did not start"; exit 1; }

curl -fsSI "$BASE/" > "$TMP/index.headers"
curl -fsSI "$BASE/$WASM_FILE" > "$TMP/wasm.headers"
grep -qi '^Content-Security-Policy:' "$TMP/index.headers"
grep -qi '^X-Content-Type-Options: nosniff' "$TMP/index.headers"
grep -qi '^X-Frame-Options: DENY' "$TMP/index.headers"
grep -qi '^Referrer-Policy: no-referrer' "$TMP/index.headers"
grep -qi '^Cache-Control: no-store, max-age=0' "$TMP/index.headers"
grep -qi '^Content-Type: application/wasm' "$TMP/wasm.headers"
grep -qi '^Cache-Control: public, max-age=31536000, immutable' "$TMP/wasm.headers"
echo "SAFEBOX_WEB_PRODUCTION_HEADERS_RUNTIME_PASS"
echo "SAFEBOX_WEB_WASM_IMMUTABLE_CACHE_RUNTIME_PASS"
echo "SAFEBOX_WEB_BROWSER_E2E_PROGRESSIVE_GATE_BEGIN timeout=${TIMEOUT}s"

python3 "$SCRIPT_DIR/web_browser_cdp_e2e.py" \
  --browser "$BROWSER" \
  --url "$BASE/app.html?__safebox_e2e=1" \
  --profile "$TMP/profile" \
  --stderr "$TMP/browser.err" \
  --timeout "$TIMEOUT" \
  --heartbeat 5

echo "SAFEBOX_WEB_BROWSER_PRODUCTION_GATE_PASS"
