#!/usr/bin/env bash
set -euo pipefail

DESKTOP_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$DESKTOP_DIR"

need_install=0
for tool in tauri vite tsc; do
  if [ ! -x "$DESKTOP_DIR/node_modules/.bin/$tool" ]; then
    need_install=1
  fi
done

if [ "$need_install" -eq 0 ]; then
  if ! node - <<'NODE' >/dev/null 2>&1
const fs = require('fs');
const path = require('path');
const root = process.cwd();
const expected = {
  'vite': '8.1.3',
  '@tauri-apps/cli': '2.11.4',
  'typescript': '7.0.2'
};
for (const [name, version] of Object.entries(expected)) {
  const p = path.join(root, 'node_modules', ...name.split('/'), 'package.json');
  const pkg = JSON.parse(fs.readFileSync(p, 'utf8'));
  if (pkg.version !== version) process.exit(1);
}
NODE
  then
    need_install=1
  fi
fi

if [ "$need_install" -eq 1 ]; then
  echo "SafeBox frontend toolchain: restoring locked dependencies before runtime"
  rm -rf node_modules
  npm ci
fi

for tool in tauri vite tsc; do
  if [ ! -x "$DESKTOP_DIR/node_modules/.bin/$tool" ]; then
    echo "SAFEBOX_FRONTEND_TOOLCHAIN_MISSING: $tool" >&2
    exit 31
  fi
done

node - <<'NODE'
const fs = require('fs');
const path = require('path');
const root = process.cwd();
const expected = {
  'vite': '8.1.3',
  '@tauri-apps/cli': '2.11.4',
  'typescript': '7.0.2'
};
for (const [name, version] of Object.entries(expected)) {
  const p = path.join(root, 'node_modules', ...name.split('/'), 'package.json');
  const pkg = JSON.parse(fs.readFileSync(p, 'utf8'));
  if (pkg.version !== version) {
    console.error(`SAFEBOX_FRONTEND_TOOLCHAIN_VERSION_MISMATCH: ${name}=${pkg.version}, expected=${version}`);
    process.exit(32);
  }
}
NODE

echo "SAFEBOX_FRONTEND_TOOLCHAIN_READY"
