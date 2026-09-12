#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

echo "[1/8] Security invariants"
! grep -n 'Command::new("cmd")' safebox-desktop/src-tauri/src/lib.rs
! grep -n 'sessionStorage' safebox-desktop/src/main.ts
! grep -nE '#\[arg\(long\)\][[:space:]]*code:' safebox-cli/src/main.rs

grep -q 'MAX_KDF_MEMORY_KIB' safebox-core/src/validation.rs
grep -q 'max_ciphertext_chunk_len' safebox-core/src/format.rs
grep -q 'create_new(true)' safebox-core/src/unlock.rs
grep -q 'sync_all()' safebox-core/src/unlock.rs
grep -q 'stable_code' safebox-core/src/error.rs

echo "[2/8] JSON/TOML"
python3 - <<'PY'
import json, tomllib
from pathlib import Path
for p in [Path('safebox-desktop/package.json'), Path('safebox-desktop/package-lock.json'), Path('safebox-desktop/src-tauri/tauri.conf.json')]:
    json.loads(p.read_text())
for p in [Path('Cargo.toml'), Path('safebox-core/Cargo.toml'), Path('safebox-cli/Cargo.toml'), Path('safebox-desktop/src-tauri/Cargo.toml')]:
    tomllib.loads(p.read_text())
conf=json.loads(Path('safebox-desktop/src-tauri/tauri.conf.json').read_text())
assert conf['app']['security']['csp']
print('JSON_TOML_PASS')
PY

echo "[3/8] Rust format"
if command -v cargo >/dev/null 2>&1; then
  cargo fmt --all -- --check
else
  echo "SKIP: cargo/rustfmt not installed"
fi

echo "[4/8] Core tests"
if command -v cargo >/dev/null 2>&1; then
  cargo test -p safebox-core --locked
else
  echo "SKIP: cargo not installed"
fi

echo "[5/8] CLI check"
if command -v cargo >/dev/null 2>&1; then
  cargo check -p safebox-cli --locked
else
  echo "SKIP: cargo not installed"
fi

echo "[6/8] Desktop Rust check"
if command -v cargo >/dev/null 2>&1; then
  cargo check -p safebox-desktop --locked
else
  echo "SKIP: cargo not installed"
fi

echo "[7/8] Frontend build"
if command -v npm >/dev/null 2>&1; then
  (cd safebox-desktop && npm ci && npm run build)
else
  echo "SKIP: npm not installed"
fi

echo "[8/8] Dependency policy"
! grep -n '"latest"' safebox-desktop/package.json
grep -q 'tauri = { version = "=2.11.5"' safebox-desktop/src-tauri/Cargo.toml

echo "SAFEBOX_V021_SECURITY_FOUNDATION_VERIFY_PASS"
