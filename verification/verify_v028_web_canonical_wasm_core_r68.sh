#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
python3 safebox-desktop/scripts/desktop_cross_platform_audit.py
python3 safebox-desktop/scripts/web_foundation_check.py
python3 safebox-desktop/scripts/web_wasm_source_check.py
python3 -m py_compile \
  safebox-desktop/scripts/web_foundation_check.py \
  safebox-desktop/scripts/web_wasm_source_check.py \
  safebox-desktop/scripts/web_wasm_contract_check.py \
  safebox-desktop/scripts/web_dist_check.py
bash -n safebox-desktop/scripts/web_wasm_build.sh
if find . -type d \( -name node_modules -o -name target -o -name dist \) -print -quit | grep -q .; then
  echo "SAFEBOX_R68_HYGIENE_FAIL: generated dependency/build directory present"
  exit 1
fi
if find . -type f -name 'safebox_core.wasm' -print -quit | grep -q .; then
  echo "SAFEBOX_R68_HYGIENE_FAIL: prebuilt WASM must be produced on reference Mac from locked Rust source"
  exit 1
fi
echo "SAFEBOX_R68_HYGIENE_PASS"
echo "SAFEBOX_V028_WEB_CANONICAL_WASM_CORE_R68_VERIFY_PASS"
