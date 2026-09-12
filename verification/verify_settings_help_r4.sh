#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MAIN="$ROOT/safebox-desktop/src/main.ts"
CSS="$ROOT/safebox-desktop/src/style.css"

echo "[1/4] R4 Help binding"
grep -q 'sbxSettingsHelpBoundR4' "$MAIN"
grep -q 'openHowToUseModal();' "$MAIN"

echo "[2/4] Help modal layer"
grep -q -- '--settings-help-modal-layer-r4' "$CSS"
grep -q 'z-index: 1000010 !important' "$CSS"

echo "[3/4] TypeScript build"
cd "$ROOT/safebox-desktop"
if [ ! -d node_modules ]; then npm ci; fi
npm run build

echo "[4/4] Rust security regression"
cd "$ROOT"
cargo test -p safebox-core

echo "SAFEBOX_SETTINGS_HELP_R4_PASS"
