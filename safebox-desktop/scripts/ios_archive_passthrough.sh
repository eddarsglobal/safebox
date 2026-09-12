#!/usr/bin/env bash
set -euo pipefail

[[ $# -eq 2 ]] || { echo 'usage: ios_archive_passthrough.sh <source.a> <dest.a>' >&2; exit 64; }
SRC="$1"
DST="$2"
[[ -f "$SRC" ]] || { echo "SAFEBOX_IOS_RUST_ARCHIVE_PASSTHROUGH_FAIL: source archive missing: $SRC" >&2; exit 65; }
mkdir -p "$(dirname "$DST")"
cp -f "$SRC" "$DST"
cmp -s "$SRC" "$DST" || { echo 'SAFEBOX_IOS_RUST_ARCHIVE_PASSTHROUGH_FAIL: copied archive differs from Cargo source' >&2; exit 66; }

# Audit only. Duplicate member *names* inside an ar archive are legal and are
# not equivalent to duplicate linker symbols. R39 therefore reports the five
# Tauri Swift support member counts but never rewrites or drops archive members.
python3 - "$DST" <<'PY'
from pathlib import Path
import sys

p = Path(sys.argv[1])
data = p.read_bytes()
if not data.startswith(b"!<arch>\n"):
    print("SAFEBOX_IOS_RUST_ARCHIVE_PASSTHROUGH_FAIL: invalid ar archive magic", file=sys.stderr)
    raise SystemExit(67)

off = 8
gnu_names = b""
counts = {name: 0 for name in (
    "Tauri.swift.o",
    "Invoke.swift.o",
    "Plugin.swift.o",
    "Channel.swift.o",
    "Logger.swift.o",
)}

while off < len(data):
    if off + 60 > len(data):
        print("SAFEBOX_IOS_RUST_ARCHIVE_PASSTHROUGH_FAIL: truncated ar header", file=sys.stderr)
        raise SystemExit(68)
    h = data[off:off+60]
    if h[58:60] != b"`\n":
        print("SAFEBOX_IOS_RUST_ARCHIVE_PASSTHROUGH_FAIL: malformed ar member header", file=sys.stderr)
        raise SystemExit(69)
    raw_name = h[:16].decode("utf-8", "replace").rstrip()
    try:
        size = int(h[48:58].decode("ascii").strip() or "0")
    except ValueError:
        print("SAFEBOX_IOS_RUST_ARCHIVE_PASSTHROUGH_FAIL: invalid ar member size", file=sys.stderr)
        raise SystemExit(70)
    body_start = off + 60
    body_end = body_start + size
    if body_end > len(data):
        print("SAFEBOX_IOS_RUST_ARCHIVE_PASSTHROUGH_FAIL: truncated ar member body", file=sys.stderr)
        raise SystemExit(71)

    name = raw_name
    if raw_name == "//":
        gnu_names = data[body_start:body_end]
    elif raw_name.startswith("#1/"):
        try:
            n = int(raw_name[3:])
        except ValueError:
            n = 0
        if n > size:
            print("SAFEBOX_IOS_RUST_ARCHIVE_PASSTHROUGH_FAIL: invalid BSD ar extended name", file=sys.stderr)
            raise SystemExit(72)
        name = data[body_start:body_start+n].decode("utf-8", "replace").rstrip("\0")
    elif raw_name.startswith("/") and raw_name[1:].isdigit() and gnu_names:
        idx = int(raw_name[1:])
        if idx < len(gnu_names):
            end = gnu_names.find(b"/\n", idx)
            if end < 0:
                end = gnu_names.find(b"\n", idx)
            if end < 0:
                end = len(gnu_names)
            name = gnu_names[idx:end].decode("utf-8", "replace").rstrip("/")
    else:
        name = raw_name.rstrip("/")

    base = name.rsplit("/", 1)[-1]
    if base in counts:
        counts[base] += 1

    off = body_end + (size & 1)

if off != len(data):
    print("SAFEBOX_IOS_RUST_ARCHIVE_PASSTHROUGH_FAIL: ar archive alignment mismatch", file=sys.stderr)
    raise SystemExit(73)

for name, count in counts.items():
    print(f"SAFEBOX_IOS_RUST_ARCHIVE_MEMBER_INFO: {name}={count}")
PY

cmp -s "$SRC" "$DST" || { echo 'SAFEBOX_IOS_RUST_ARCHIVE_PASSTHROUGH_FAIL: audit mutated archive' >&2; exit 74; }
echo 'SAFEBOX_IOS_RUST_ARCHIVE_PASSTHROUGH_PASS'
