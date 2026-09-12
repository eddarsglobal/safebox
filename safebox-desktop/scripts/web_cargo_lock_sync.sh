#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DESKTOP_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
ROOT_DIR="$(cd "$DESKTOP_DIR/.." && pwd)"
LOCK="$ROOT_DIR/Cargo.lock"
TARGET="wasm32-unknown-unknown"

command -v cargo >/dev/null 2>&1 || { echo "SAFEBOX_WEB_LOCK_CHECK_FAIL: cargo not found"; exit 1; }
command -v python3 >/dev/null 2>&1 || { echo "SAFEBOX_WEB_LOCK_CHECK_FAIL: python3 not found"; exit 1; }
[[ -f "$LOCK" ]] || { echo "SAFEBOX_WEB_LOCK_CHECK_FAIL: Cargo.lock missing"; exit 1; }

cd "$ROOT_DIR"

# R75 retains R74 minimal AEAD features and converges Cargo.lock to that graph.
# R74 source was correct but its lock still carried the optional crypto-common ->
# rand_core edge inherited from the previous chacha20poly1305/getrandom feature set.
# R75 removes only that stale lock edge. Production Web builds remain immutable,
# target-scoped and strictly --locked.
python3 - "$LOCK" <<'PY'
from pathlib import Path
import re, sys
text = Path(sys.argv[1]).read_text()

def block(name):
    m = re.search(r'(?ms)^\[\[package\]\]\nname = "' + re.escape(name) + r'"\n.*?(?=^\[\[package\]\]|\Z)', text)
    if not m:
        raise SystemExit(f'missing lock package: {name}')
    return m.group(0)

argon = block('argon2')
base64ct = block('base64ct')
if 'version = "0.5.3"' not in argon:
    raise SystemExit('unexpected Argon2 version')
if 'checksum = "3c3610892ee6e0cbce8ae2700349fcf8f98adb0dbfbee85aec3c9179d29cc072"' not in argon:
    raise SystemExit('unexpected Argon2 checksum')
for dep in ('"base64ct"', '"blake2"', '"cpufeatures"', '"zeroize"'):
    if dep not in argon:
        raise SystemExit(f'Argon2 lock edge missing: {dep}')
for forbidden in ('"password-hash"', '"rand_core"', '"getrandom"'):
    if forbidden in argon:
        raise SystemExit(f'forbidden Argon2 lock edge: {forbidden}')
if 'version = "1.8.3"' not in base64ct:
    raise SystemExit('unexpected base64ct version')
if 'checksum = "2af50177e190e07a26ab74f8b1efbfe2ef87da2116221318cb1c2e82baf7de06"' not in base64ct:
    raise SystemExit('unexpected base64ct checksum')
if re.search(r'(?m)^name = "password-hash"$', text):
    raise SystemExit('orphan password-hash package must not be present')
crypto = block('crypto-common')
if 'version = "0.1.7"' not in crypto:
    raise SystemExit('unexpected crypto-common version')
if '"rand_core"' in crypto or '"getrandom"' in crypto:
    raise SystemExit('stale crypto-common RNG lock edge present')
print('SAFEBOX_WEB_CARGO_LOCK_CANONICAL_ARGON2_PASS')
print('SAFEBOX_WEB_CARGO_LOCK_BASE64CT_EDGE_PASS')
print('SAFEBOX_WEB_CARGO_LOCK_NO_PASSWORD_HASH_PASS')
print('SAFEBOX_WEB_CARGO_LOCK_CRYPTO_COMMON_NO_RNG_PASS')
PY

before_sha="$(python3 - "$LOCK" <<'PY'
from pathlib import Path
import hashlib, sys
print(hashlib.sha256(Path(sys.argv[1]).read_bytes()).hexdigest())
PY
)"

# Ask Cargo only for the actual Web target graph. Network access is allowed for
# downloading crates already pinned by Cargo.lock; --locked forbids dependency
# graph mutation. Unlike R72, no workspace-wide dependency metadata is executed.
tree="$(mktemp "${TMPDIR:-/tmp}/safebox-r73-wasm-tree.XXXXXX")"
trap 'rm -f "$tree"' EXIT
if ! cargo tree --locked -p safebox-web-wasm --target "$TARGET" -e normal > "$tree"; then
  echo "SAFEBOX_WEB_LOCK_CHECK_FAIL: locked wasm target graph rejected"
  exit 1
fi

grep -q 'argon2 v0\.5\.3' "$tree" || { echo "SAFEBOX_WEB_LOCK_CHECK_FAIL: Argon2 0.5.3 missing from wasm graph"; exit 1; }
grep -q 'base64ct v1\.8\.3' "$tree" || { echo "SAFEBOX_WEB_LOCK_CHECK_FAIL: base64ct 1.8.3 missing from wasm graph"; exit 1; }
grep -q 'chacha20poly1305 v0\.10\.1' "$tree" || { echo "SAFEBOX_WEB_LOCK_CHECK_FAIL: XChaCha dependency missing from wasm graph"; exit 1; }
if grep -Eq '(^|[[:space:]├└│])((getrandom|rand_core|password-hash) v)' "$tree"; then
  echo "SAFEBOX_WEB_LOCK_CHECK_FAIL: forbidden RNG/password-hash dependency in wasm graph"
  cat "$tree"
  exit 1
fi

after_sha="$(python3 - "$LOCK" <<'PY'
from pathlib import Path
import hashlib, sys
print(hashlib.sha256(Path(sys.argv[1]).read_bytes()).hexdigest())
PY
)"
[[ "$before_sha" == "$after_sha" ]] || { echo "SAFEBOX_WEB_LOCK_CHECK_FAIL: Cargo.lock mutated during locked graph check"; exit 1; }

echo "SAFEBOX_WEB_XCHACHA_RNG_FEATURE_ISOLATION_PASS"
echo "SAFEBOX_WEB_WASM_NO_RNG_DEPENDENCY_PASS"
echo "SAFEBOX_WEB_WASM_TARGET_SCOPED_LOCK_PASS"
echo "SAFEBOX_WEB_CARGO_LOCK_IMMUTABLE_PASS"
printf 'SAFEBOX_WEB_CARGO_LOCK_SHA256: %s\n' "$after_sha"
echo "SAFEBOX_WEB_CARGO_LOCK_SYNC_PASS"
