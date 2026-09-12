#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS="$ROOT/safebox-desktop/scripts/ios_archive_passthrough.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
SRC="$TMP/source.a"
DST="$TMP/output.a"

# Build a minimal standards-compliant ar archive directly so duplicate member
# names are guaranteed, independent of the host `ar` implementation.
python3 - "$SRC" <<'PY'
from pathlib import Path
import sys

def member(name: str, payload: bytes) -> bytes:
    n=(name + '/').encode('ascii')
    assert len(n) <= 16
    h = n.ljust(16,b' ') + b'0'.ljust(12,b' ') + b'0'.ljust(6,b' ') + b'0'.ljust(6,b' ') + b'100644'.ljust(8,b' ') + str(len(payload)).encode().ljust(10,b' ') + b'`\n'
    return h + payload + (b'\n' if len(payload) & 1 else b'')

names=['Tauri.swift.o','Invoke.swift.o','Plugin.swift.o','Channel.swift.o','Logger.swift.o']
out=bytearray(b'!<arch>\n')
for i,name in enumerate(names):
    out += member(name, f'first-{i}'.encode())
for i,name in enumerate(names):
    out += member(name, f'second-different-{i}'.encode())
Path(sys.argv[1]).write_bytes(out)
PY

BEFORE="$(shasum -a 256 "$SRC" | awk '{print $1}')"
OUT="$(bash "$PASS" "$SRC" "$DST")"
AFTER="$(shasum -a 256 "$DST" | awk '{print $1}')"
[[ "$BEFORE" == "$AFTER" ]]
cmp -s "$SRC" "$DST"
for M in Tauri.swift.o Invoke.swift.o Plugin.swift.o Channel.swift.o Logger.swift.o; do
  grep -F "SAFEBOX_IOS_RUST_ARCHIVE_MEMBER_INFO: $M=2" <<<"$OUT" >/dev/null
done
grep -F 'SAFEBOX_IOS_RUST_ARCHIVE_PASSTHROUGH_PASS' <<<"$OUT" >/dev/null

echo 'SAFEBOX_IOS_ARCHIVE_PASSTHROUGH_R39_PASS'
