#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "[1/8] Naming/UI invariants"
grep -q 'Marker: safebox-r7-original-name-simple' safebox-desktop/src/main.ts
grep -q 'id="visibleName" value="" placeholder="Select a file first"' safebox-desktop/src/main.ts
! grep -q 'visibleNameMode' safebox-desktop/src/main.ts
! grep -q 'Uses the original filename by default' safebox-desktop/src/main.ts
! grep -q 'document\.sbx' safebox-desktop/src/main.ts
grep -q 'normalize_sbx_name(&visible_name, &input)' safebox-desktop/src-tauri/src/lib.rs
grep -q 'file_stem()' safebox-desktop/src-tauri/src/lib.rs
! sed -n '/fn normalize_sbx_name/,/^}/p' safebox-desktop/src-tauri/src/lib.rs | grep -q '"document"'
echo "NAMING_UI_R8_INVARIANTS_PASS"

echo "[2/8] JSON/TOML"
python3 - <<'PY'
import json, tomllib
from pathlib import Path
for p in [Path('safebox-desktop/package.json'), Path('safebox-desktop/src-tauri/tauri.conf.json'), Path('safebox-desktop/src-tauri/capabilities/default.json')]:
    json.loads(p.read_text())
for p in [Path('Cargo.toml'), Path('safebox-core/Cargo.toml'), Path('safebox-cli/Cargo.toml'), Path('safebox-desktop/src-tauri/Cargo.toml')]:
    tomllib.loads(p.read_text())
print('JSON_TOML_PASS')
PY

echo "[3/8] Rust format"
cargo fmt --all -- --check

echo "[4/8] Core tests"
cargo test -p safebox-core

echo "[5/8] CLI check"
cargo check -p safebox-cli

echo "[6/8] Desktop Rust check"
cargo check --manifest-path safebox-desktop/src-tauri/Cargo.toml

echo "[7/8] Frontend build"
(
  cd safebox-desktop
  npm ci
  npm run build
)

echo "[8/8] Legacy security gate"
bash verification/verify_v021_security_foundation.sh >/tmp/safebox-v021-r8.log 2>&1 || { cat /tmp/safebox-v021-r8.log; exit 1; }
grep -q 'SAFEBOX_V021_SECURITY_FOUNDATION_VERIFY_PASS' /tmp/safebox-v021-r8.log

echo "SAFEBOX_V022B_NAME_FIX_R8_VERIFY_PASS"
