#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DESKTOP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ROOT_DIR="$(cd "$DESKTOP_DIR/.." && pwd)"
TARGET="wasm32-unknown-unknown"
WASM_SRC="$ROOT_DIR/target/$TARGET/release/safebox_web_wasm.wasm"
WASM_DST="$DESKTOP_DIR/public/safebox_core.wasm"

command -v cargo >/dev/null 2>&1 || { echo "SAFEBOX_WEB_WASM_BUILD_FAIL: cargo not found"; exit 1; }
command -v rustup >/dev/null 2>&1 || { echo "SAFEBOX_WEB_WASM_BUILD_FAIL: rustup not found"; exit 1; }

if ! rustup target list --installed | grep -qx "$TARGET"; then
  echo "SAFEBOX_WEB_WASM_TARGET_INSTALL_BEGIN: $TARGET"
  rustup target add "$TARGET"
  echo "SAFEBOX_WEB_WASM_TARGET_INSTALL_PASS"
else
  echo "SAFEBOX_WEB_WASM_TARGET_READY_PASS"
fi

cd "$ROOT_DIR"

bash "$SCRIPT_DIR/web_cargo_lock_sync.sh"
cargo test --locked -p safebox-core memory::tests::memory_roundtrip_uses_canonical_sbx_format -- --exact
cargo test --locked -p safebox-core memory::tests::memory_unlock_rejects_wrong_code_and_tamper -- --exact
echo "SAFEBOX_WEB_CORE_MEMORY_COMPAT_PASS"
echo "SAFEBOX_WEB_WASM_ENTROPY_DEPENDENCY_ISOLATION_PASS"

cargo build --locked -p safebox-web-wasm --target "$TARGET" --release
[[ -s "$WASM_SRC" ]] || { echo "SAFEBOX_WEB_WASM_BUILD_FAIL: output missing"; exit 1; }

mkdir -p "$DESKTOP_DIR/public"
tmp="$WASM_DST.tmp.$$"
cp "$WASM_SRC" "$tmp"
chmod 0644 "$tmp"
mv -f "$tmp" "$WASM_DST"

python3 "$SCRIPT_DIR/web_wasm_contract_check.py"

SMOKE_DIR="$ROOT_DIR/target/r68-web-smoke"
rm -rf "$SMOKE_DIR"
mkdir -p "$SMOKE_DIR/native-unlock"
node "$SCRIPT_DIR/web_wasm_node_smoke.mjs" roundtrip "$SMOKE_DIR"
printf '%s\n' 'R68-canonical-interop-code' | cargo run --locked -q -p safebox-cli -- unlock "$SMOKE_DIR/web-created.sbx" --out-dir "$SMOKE_DIR/native-unlock" --keep-sbx --overwrite
cmp "$SMOKE_DIR/original.bin" "$SMOKE_DIR/native-unlock/r68-web-fixture.bin"
echo "SAFEBOX_WEB_WASM_WEB_TO_NATIVE_INTEROP_PASS"

printf '%s\n' 'R68-canonical-interop-code' | cargo run --locked -q -p safebox-cli -- create "$SMOKE_DIR/original.bin" --out "$SMOKE_DIR/native-created.sbx" --keep-after-unlock
node "$SCRIPT_DIR/web_wasm_node_smoke.mjs" unlock-native "$SMOKE_DIR/native-created.sbx" "$SMOKE_DIR/original.bin"
echo "SAFEBOX_WEB_WASM_BIDIRECTIONAL_INTEROP_PASS"
if command -v shasum >/dev/null 2>&1; then
  sha="$(shasum -a 256 "$WASM_DST" | awk '{print $1}')"
else
  sha="$(sha256sum "$WASM_DST" | awk '{print $1}')"
fi
printf 'SAFEBOX_WEB_WASM_SHA256: %s\n' "$sha"
echo "SAFEBOX_WEB_WASM_BUILD_PASS"
