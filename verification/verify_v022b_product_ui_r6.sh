#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "[1/8] Product/UI invariants"
grep -q 'id="keepAfterUnlock" type="checkbox" checked' safebox-desktop/src/main.ts
grep -q 'id="keepSbx" type="checkbox" checked' safebox-desktop/src/main.ts
grep -q 'Keep SBX after unlock' safebox-desktop/src/main.ts
! grep -q 'for tests only' safebox-desktop/src/main.ts
! grep -q 'kept for testing' safebox-desktop/src-tauri/src/lib.rs
grep -q 'safebox-r6-original-name-auto' safebox-desktop/src/main.ts
grep -q 'visibleNameFromOriginalPath' safebox-desktop/src/main.ts
grep -q 'name-mode-badge auto' safebox-desktop/src/main.ts
grep -q 'settings-file-naming-info' safebox-desktop/src/main.ts
grep -q 'keepSbx: true' safebox-desktop/src/main.ts
grep -q 'burn_after_unlock: false' safebox-core/src/create.rs
grep -q 'burn_after_unlock: false' safebox-core/src/unlock.rs

echo "PRODUCT_UI_R6_INVARIANTS_PASS"

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

echo "[8/8] Design council checkpoint"
test -s checkpoints/SAFEBOX_DESIGN_UI_COUNCIL_R6.md

echo "SAFEBOX_V022B_PRODUCT_UI_R6_VERIFY_PASS"
