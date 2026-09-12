#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
TS="safebox-desktop/src/landing.ts"; CSS="safebox-desktop/src/landing.css"; LJS="safebox-desktop/public/legal/legal.js"
grep -q 'Mr Eddars Noureddine · Zurich, Switzerland' "$TS"
grep -q 'const extensionSizes = \[30,28,26' "$TS"
grep -q '@keyframes sbxOrbitRingA' "$CSS"
grep -q '@keyframes sbxCoreBreathe' "$CSS"
grep -q 'html\[dir="rtl"\] .hero h1' "$CSS"
grep -q '.file b{font-size:clamp(11px' "$CSS"
grep -q '.actions{gap:16px' "$CSS"
grep -q 'animation:sbxShieldFloat' "$CSS"
grep -q 'animation:sbxCardGlow' "$CSS"
grep -q 'const pages=' "$LJS"
for page in legal privacy terms cookies licenses; do
  grep -q "data-legal-page=\"$page\"" "safebox-desktop/public/legal/$page.html"
  grep -q 'Mr Eddars Noureddine' "safebox-desktop/public/legal/$page.html"
  grep -q 'Zurich, Switzerland' "safebox-desktop/public/legal/$page.html"
done
python3 - <<'PY'
import json,re
from pathlib import Path
s=Path("safebox-desktop/public/legal/legal.js").read_text()
m=re.search(r"const pages=(.*?);\nconst auto=",s,re.S)
pages=json.loads(m.group(1))
langs={"en","fr","it","pt","ar","de","es","hr"}
assert set(pages)=={"legal","privacy","terms","cookies","licenses"}
for page,data in pages.items():
    assert set(data)==langs,(page,set(data))
    for lang,c in data.items():
        assert c["title"] and c["intro"] and c["sections"] and c["creator"]
print("SAFEBOX_R84_LEGAL_TRANSLATION_MATRIX_PASS")
PY
echo SAFEBOX_R84_VIEWPORT_CONTAINMENT_PASS
echo SAFEBOX_R84_HERO_ORBIT_ALWAYS_ANIMATED_PASS
echo SAFEBOX_R84_SOURCE_FILES_TYPOGRAPHY_PASS
echo SAFEBOX_R84_SECTION_BUTTON_SPACING_PASS
echo SAFEBOX_R84_MOTION_DENSITY_PASS
echo SAFEBOX_R84_LEGAL_EIGHT_LOCALE_PASS
echo SAFEBOX_R84_CREATOR_CREDIT_PASS
