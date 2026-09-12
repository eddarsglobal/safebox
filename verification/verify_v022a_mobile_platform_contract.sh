#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

echo "[1/8] Mobile platform contract invariants"
grep -q "SafeBox Header Placement R5" safebox-desktop/src/style.css
grep -q "get_platform_capabilities" safebox-desktop/src-tauri/src/lib.rs
grep -q "MOBILE_URI_ADAPTER_REQUIRED" safebox-desktop/src-tauri/src/lib.rs
grep -q "setupPlatformCapabilities" safebox-desktop/src/main.ts
grep -q "platform-hidden" safebox-desktop/src/style.css

echo "[2/8] Rust format"
cargo fmt --all -- --check

echo "[3/8] Core tests"
cargo test -p safebox-core

echo "[4/8] CLI check"
cargo check -p safebox-cli

echo "[5/8] Tauri Rust check"
cargo check -p safebox-desktop

echo "[6/8] Frontend install/build"
cd safebox-desktop
npm ci
npm run build

echo "[7/8] Runtime dependency audit"
if npm audit --omit=dev --audit-level=high; then
  echo "RUNTIME_NPM_AUDIT_PASS"
else
  echo "RUNTIME_NPM_AUDIT_FAIL" >&2
  exit 1
fi

echo "[8/8] Final markers"
grep -q '"version": "0.2.2"' package.json
cd ..
echo "SAFEBOX_V022A_MOBILE_PLATFORM_CONTRACT_VERIFY_PASS"
