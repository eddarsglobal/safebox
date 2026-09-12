#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
D="$ROOT/safebox-desktop"
fail(){ echo "SAFEBOX_WEB_RC7_SYNC_FAIL: $*" >&2; exit 1; }

if command -v sha256sum >/dev/null 2>&1; then
  SHA256=(sha256sum)
elif command -v shasum >/dev/null 2>&1; then
  SHA256=(shasum -a 256)
else
  fail "no SHA-256 tool available"
fi

tree_sha(){
  local dir="$1"
  (
    cd "$ROOT"
    find "$dir" -type f -print0 | sort -z | while IFS= read -r -d '' f; do
      "${SHA256[@]}" "$f"
    done | "${SHA256[@]}" | awk '{print $1}'
  )
}

[[ "$(tree_sha safebox-core)" == "6775299184efb145bfd1c6e247021e077072cb0c7d77bcec93c89728caefb364" ]] || fail "safebox-core changed"
[[ "$(tree_sha safebox-web-wasm)" == "0e9211d1a4d3c2eb266bedf7f8c7c86c12670111d54785003ffe3ceac66bc385" ]] || fail "safebox-web-wasm changed"
echo SAFEBOX_WEB_RC7_CRYPTO_SOURCE_UNCHANGED_PASS

grep -Fq 'SAFEBOX_SHARED_THEME_KEY = "safebox-theme-mode.v1"' "$D/src/landing.ts" || fail "shared landing theme key missing"
grep -Fq 'SafeBox R86 RC7 — dedicated high-contrast light palette' "$D/src/landing.css" || fail "landing light contrast closure missing"
grep -Fq 'SafeBox R86 RC7 — final light-mode contrast closure' "$D/src/style.css" || fail "app light contrast closure missing"
grep -Fq ':root[data-theme="light"] .stage-rail span' "$D/src/landing.css" || fail "light stage rail rule missing"
grep -Fq ':root[data-theme="light"] .download-card' "$D/src/landing.css" || fail "light download card rule missing"
grep -Fq ':root[data-theme="light"] input' "$D/src/style.css" || fail "light app input rule missing"
echo SAFEBOX_WEB_RC7_LIGHT_MODE_CONTRAST_PASS

grep -Fq ':root[data-theme="light"]' "$D/public/legal/legal.css" || fail "legal light theme missing"
grep -Fq ':root[data-theme="dark"]' "$D/public/legal/legal.css" || fail "legal dark theme missing"
grep -Fq 'SAFEBOX_THEME_MODE_KEY="safebox-theme-mode.v1"' "$D/public/legal/legal.js" || fail "legal shared theme key missing"
grep -Fq 'themeSel.id="legalTheme"' "$D/public/legal/legal.js" || fail "legal Appearance selector missing"
node --check "$D/public/legal/legal.js" >/dev/null
echo SAFEBOX_WEB_RC7_LEGAL_THEME_SYNC_PASS

grep -Fq 'landing: resolve(__dirname, "index.html")' "$D/vite.config.ts" || fail "landing entry missing"
grep -Fq 'app: resolve(__dirname, "app.html")' "$D/vite.config.ts" || fail "app entry missing"
grep -Fq 'safebox_v0.2.9_web_deploy_R86_RC7_LIGHT_LEGAL_SYNC' "$D/scripts/web_deploy_bundle.py" || fail "deploy bundle identity missing"
echo SAFEBOX_WEB_RC7_MULTI_PAGE_DEPLOY_PASS

echo SAFEBOX_V029_WEB_RC7_LIGHT_LEGAL_SYNC_PASS
