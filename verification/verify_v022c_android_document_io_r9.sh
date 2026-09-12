#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

printf '[1/9] Android document I/O invariants\n'
grep -q 'tauri-plugin-fs = "=2.5.1"' safebox-desktop/src-tauri/Cargo.toml
grep -q 'plugin(tauri_plugin_fs::init())' safebox-desktop/src-tauri/src/lib.rs
grep -q 'trimmed.starts_with("content://")' safebox-desktop/src-tauri/src/lib.rs
grep -q '\.fs()' safebox-desktop/src-tauri/src/lib.rs
grep -q 'get_document_display_name' safebox-desktop/src-tauri/src/lib.rs
grep -q 'save_generated_file' safebox-desktop/src-tauri/src/lib.rs
grep -q 'UNTRUSTED_EXPORT_SOURCE' safebox-desktop/src-tauri/src/lib.rs
grep -q 'verify_export_bytes' safebox-desktop/src-tauri/src/lib.rs
grep -q 'supports_mobile_save' safebox-desktop/src/main.ts
if grep -q 'MOBILE_URI_ADAPTER_REQUIRED' safebox-desktop/src-tauri/src/lib.rs; then
  echo 'legacy Android URI rejection still present' >&2
  exit 1
fi
if grep -q 'unwrap_or("document.sbx")' safebox-core/src/create.rs; then
  echo 'synthetic document.sbx fallback still present' >&2
  exit 1
fi
echo ANDROID_DOCUMENT_IO_R9_INVARIANTS_PASS

printf '[2/9] JSON/TOML\n'
python3 - <<'PY'
import json, pathlib, tomllib
root = pathlib.Path('.')
json.loads((root/'safebox-desktop/src-tauri/tauri.conf.json').read_text())
for path in [root/'Cargo.toml', root/'safebox-core/Cargo.toml', root/'safebox-cli/Cargo.toml', root/'safebox-desktop/src-tauri/Cargo.toml']:
    tomllib.loads(path.read_text())
print('JSON_TOML_PASS')
PY

printf '[3/9] Rust format\n'
cargo fmt --all
cargo fmt --all -- --check

printf '[4/9] Core tests\n'
cargo test --locked -p safebox-core

printf '[5/9] CLI check\n'
cargo check --locked -p safebox-cli

printf '[6/9] Desktop/Tauri Rust check\n'
cargo check --locked --manifest-path safebox-desktop/src-tauri/Cargo.toml

printf '[7/9] Frontend build\n'
(
  cd safebox-desktop
  npm ci
  npm run build
)

printf '[8/9] Android CLI readiness\n'
(
  cd safebox-desktop
  if [ ! -x node_modules/.bin/tauri ]; then
    echo 'SAFEBOX_ANDROID_RUNTIME_TAURI_MISSING: node_modules/.bin/tauri' >&2
    exit 1
  fi
  ./node_modules/.bin/tauri info >/tmp/safebox-v022c-tauri-info.txt
)
grep -q 'tauri' /tmp/safebox-v022c-tauri-info.txt || true

printf '[9/9] Legacy security gate\n'
bash verification/verify_v022b_name_fix_r8.sh >/tmp/safebox-v022c-legacy.log

echo SAFEBOX_V022C_ANDROID_DOCUMENT_IO_R9_VERIFY_PASS
