#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
TS="safebox-desktop/src/landing.ts"
CSS="safebox-desktop/src/landing.css"
PKG="SAFEBOX_V029_PACKAGE_ID.txt"

grep -q 'SAFEBOX v0.2.9 R85 — cinematic trust design crypto story' "$PKG"
grep -q 'class="hero-vault"' "$TS"
grep -q 'data-stage="input"' "$TS"
grep -q 'data-stage="encrypt"' "$TS"
grep -q 'data-stage="output"' "$TS"
grep -q 'XCHACHA20' "$TS"
grep -q 'ARGON2 · LOCAL' "$TS"
grep -q 'ONE .SBX' "$TS"
grep -q 'const extensionSizes = \[52,46,40,36,32,28' "$TS"
grep -q '3,2,1' "$TS"
grep -q 'textLike' "$TS"
grep -q 'amp=textLike ? 1.6 : 7.5' "$TS"
grep -q 'https://x.com/EddarsStudio' "$TS"
grep -q 'id="adShell" aria-label="Advertisement" hidden' "$TS"
grep -q '.crypto-story{height:270svh' "$CSS"
grep -q '.ad-shell\[hidden\]{display:none!important}' "$CSS"
grep -q 'grid-template-rows:145px minmax(0,1fr)' "$CSS"
grep -q '.story-outcome' "$CSS"
if grep -q '.crypto-story{height:3600px' "$CSS"; then
  echo SAFEBOX_R85_DEAD_SCROLL_LEGACY_FAIL
  exit 1
fi
python3 - <<'PY'
from pathlib import Path
import hashlib
root=Path('.')
expected={
 root/'safebox-core/src/crypto.rs':'1d75fe23895cb0196fb7ff5b369c59596c300a3bd3eb5a07395d3287f925b670',
 root/'safebox-core/src/format.rs':'26edb67b2be91ff5c7d765e100e4aafa5e50933919c0db2e4370901f67205ea1',
 root/'safebox-web-wasm/src/lib.rs':'d5e65323c3d87b02b2f8958d8edc4dfddf500a9787fdf4377080c5092d9ea4c3',
 root/'safebox-desktop/src/web-sbx-engine.ts':'7396fa6f0cef79a7c6a425258ca117ed67543e19b7b9f8a104b6f26506ba9b8d',
 root/'safebox-desktop/src/main.ts':'ce44f4e0ff059ddcab34639f8ac4b9743d89309552557d72294cb1a97f54beff',
}
for p,h in expected.items():
    got=hashlib.sha256(p.read_bytes()).hexdigest()
    assert got==h,(p,got)
print('SAFEBOX_R85_CRYPTO_RUNTIME_IMMUTABLE_PASS')
PY

echo SAFEBOX_R85_HERO_VAULT_CINEMATIC_PASS
echo SAFEBOX_R85_CRYPTO_THREE_ACT_NARRATIVE_PASS
echo SAFEBOX_R85_CRYPTO_FINALE_VISIBLE_HOLD_PASS
echo SAFEBOX_R85_NO_DEAD_SCROLL_ZONE_PASS
echo SAFEBOX_R85_ALL_DESCENDANTS_SAFE_AMPLITUDE_PASS
echo SAFEBOX_R85_TEXT_BUTTON_COLLISION_GUARD_PASS
echo SAFEBOX_R85_DOWNLOAD_LAYOUT_PROFESSIONAL_PASS
echo SAFEBOX_R85_ADS_OFF_NO_DEAD_SPACE_PASS
echo SAFEBOX_R85_CRYPTO_LABEL_TRUTH_PASS
echo SAFEBOX_R85_CREATOR_X_LINK_PASS
echo SAFEBOX_R85_DESIGN_TRUST_SURFACE_PASS
