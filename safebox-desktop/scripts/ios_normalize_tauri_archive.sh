#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo 'SAFEBOX_IOS_ARCHIVE_NORMALIZE_FAIL: usage: source.a output.a' >&2
  exit 64
fi
SOURCE="$1"
OUTPUT="$2"
[[ -f "$SOURCE" ]] || { echo "SAFEBOX_IOS_ARCHIVE_NORMALIZE_FAIL: source archive missing: $SOURCE" >&2; exit 65; }
command -v python3 >/dev/null 2>&1 || { echo 'SAFEBOX_IOS_ARCHIVE_NORMALIZE_FAIL: python3 unavailable' >&2; exit 66; }

SOURCE_ABS="$(cd "$(dirname "$SOURCE")" && pwd)/$(basename "$SOURCE")"
OUTPUT_DIR="$(cd "$(dirname "$OUTPUT")" && pwd)"
OUTPUT_ABS="$OUTPUT_DIR/$(basename "$OUTPUT")"

RANLIB_BIN=''
STRIP_BIN=''
if command -v xcrun >/dev/null 2>&1; then
  RANLIB_BIN="$(xcrun --find ranlib 2>/dev/null || true)"
  STRIP_BIN="$(xcrun --find strip 2>/dev/null || true)"
fi
[[ -n "$RANLIB_BIN" ]] || RANLIB_BIN="$(command -v ranlib || true)"
[[ -n "$STRIP_BIN" ]] || STRIP_BIN="$(command -v strip || true)"
[[ -n "$RANLIB_BIN" ]] || { echo 'SAFEBOX_IOS_ARCHIVE_NORMALIZE_FAIL: ranlib unavailable' >&2; exit 66; }

TMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/safebox-ios-archive.XXXXXX")"
cleanup(){ rm -rf "$TMP_ROOT"; }
trap cleanup EXIT INT TERM
TMP_OUT="$TMP_ROOT/libapp.normalized.a"

# R38 portability fix: Apple/Xcode's BSD ar does not support GNU/LLVM xN/dN.
# Parse the standard ar container directly so duplicate occurrence selection is
# deterministic on both BSD and LLVM/GNU toolchains. We preserve every archive
# member byte-for-byte except the verified redundant second Tauri support member,
# then run Apple's ranlib to rebuild the archive symbol table.
python3 - "$SOURCE_ABS" "$TMP_OUT" "$TMP_ROOT" "${STRIP_BIN:-}" <<'PY'
from pathlib import Path
import subprocess, sys

source = Path(sys.argv[1])
out = Path(sys.argv[2])
tmp = Path(sys.argv[3])
strip_bin = sys.argv[4]
targets = ["Tauri.swift.o", "Invoke.swift.o", "Plugin.swift.o", "Channel.swift.o", "Logger.swift.o"]
raw = source.read_bytes()
if not raw.startswith(b"!<arch>\n"):
    print("SAFEBOX_IOS_ARCHIVE_NORMALIZE_FAIL: invalid ar global header", file=sys.stderr)
    raise SystemExit(67)

entries = []
pos = 8
while pos < len(raw):
    if pos + 60 > len(raw):
        print("SAFEBOX_IOS_ARCHIVE_NORMALIZE_FAIL: truncated ar member header", file=sys.stderr)
        raise SystemExit(67)
    hdr = raw[pos:pos+60]
    if hdr[58:60] != b"`\n":
        print("SAFEBOX_IOS_ARCHIVE_NORMALIZE_FAIL: invalid ar member trailer", file=sys.stderr)
        raise SystemExit(67)
    try:
        size = int(hdr[48:58].decode("ascii").strip() or "0")
    except ValueError:
        print("SAFEBOX_IOS_ARCHIVE_NORMALIZE_FAIL: invalid ar member size", file=sys.stderr)
        raise SystemExit(67)
    body_start = pos + 60
    body_end = body_start + size
    if body_end > len(raw):
        print("SAFEBOX_IOS_ARCHIVE_NORMALIZE_FAIL: truncated ar member payload", file=sys.stderr)
        raise SystemExit(67)
    block_end = body_end + (size & 1)
    if block_end > len(raw):
        print("SAFEBOX_IOS_ARCHIVE_NORMALIZE_FAIL: truncated ar padding", file=sys.stderr)
        raise SystemExit(67)
    name_field = hdr[:16].decode("utf-8", "replace").rstrip()
    body = raw[body_start:body_end]
    entry = {
        "start": pos, "end": block_end, "name_field": name_field,
        "body": body, "object": body, "name": None,
    }
    if name_field.startswith("#1/"):
        try:
            nlen = int(name_field[3:])
        except ValueError:
            print("SAFEBOX_IOS_ARCHIVE_NORMALIZE_FAIL: invalid BSD extended member name", file=sys.stderr)
            raise SystemExit(67)
        if nlen > len(body):
            print("SAFEBOX_IOS_ARCHIVE_NORMALIZE_FAIL: invalid BSD extended member length", file=sys.stderr)
            raise SystemExit(67)
        entry["name"] = body[:nlen].decode("utf-8", "replace").rstrip("\x00")
        entry["object"] = body[nlen:]
    elif name_field not in ("/", "//") and not (name_field.startswith("/") and name_field[1:].isdigit()):
        entry["name"] = name_field[:-1] if name_field.endswith("/") else name_field
    entries.append(entry)
    pos = block_end

if pos != len(raw):
    print("SAFEBOX_IOS_ARCHIVE_NORMALIZE_FAIL: malformed ar archive length", file=sys.stderr)
    raise SystemExit(67)

# Resolve GNU long-name references (/123) when present.
long_table = next((e["body"] for e in entries if e["name_field"] == "//"), None)
for e in entries:
    nf = e["name_field"]
    if e["name"] is None and nf.startswith("/") and nf[1:].isdigit():
        if long_table is None:
            print("SAFEBOX_IOS_ARCHIVE_NORMALIZE_FAIL: GNU long-name table missing", file=sys.stderr)
            raise SystemExit(67)
        off = int(nf[1:])
        if off >= len(long_table):
            print("SAFEBOX_IOS_ARCHIVE_NORMALIZE_FAIL: GNU long-name offset invalid", file=sys.stderr)
            raise SystemExit(67)
        tail = long_table[off:]
        end = tail.find(b"/\n")
        if end < 0:
            end = tail.find(b"\n")
        if end < 0:
            end = len(tail)
        e["name"] = tail[:end].decode("utf-8", "replace").rstrip("/")

remove_indexes = set()
removed = 0
for member in targets:
    idxs = [i for i,e in enumerate(entries) if e["name"] == member]
    count = len(idxs)
    if count == 0:
        print(f"SAFEBOX_IOS_ARCHIVE_NORMALIZE_FAIL: expected Tauri member missing: {member}", file=sys.stderr)
        raise SystemExit(69)
    if count > 2:
        print(f"SAFEBOX_IOS_ARCHIVE_NORMALIZE_FAIL: unexpected multiplicity for {member}: {count}", file=sys.stderr)
        raise SystemExit(70)
    if count == 1:
        continue
    a = entries[idxs[0]]["object"]
    b = entries[idxs[1]]["object"]
    identity = "byte-identical"
    if a != b:
        if not strip_bin:
            print(f"SAFEBOX_IOS_ARCHIVE_NORMALIZE_FAIL: duplicate differs and strip is unavailable: {member}", file=sys.stderr)
            raise SystemExit(68)
        first = tmp / f"first-{removed}-{member}"
        second = tmp / f"second-{removed}-{member}"
        first_link = tmp / f"first-{removed}-{member}.link"
        second_link = tmp / f"second-{removed}-{member}.link"
        first.write_bytes(a)
        second.write_bytes(b)
        try:
            subprocess.run([strip_bin, "-S", "-o", str(first_link), str(first)], check=True,
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            subprocess.run([strip_bin, "-S", "-o", str(second_link), str(second)], check=True,
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        except subprocess.CalledProcessError:
            print(f"SAFEBOX_IOS_ARCHIVE_NORMALIZE_FAIL: non-equivalent duplicate member: {member}", file=sys.stderr)
            raise SystemExit(68)
        if first_link.read_bytes() != second_link.read_bytes():
            print(f"SAFEBOX_IOS_ARCHIVE_NORMALIZE_FAIL: non-equivalent duplicate member: {member}", file=sys.stderr)
            raise SystemExit(68)
        identity = "link-equivalent-after-debug-strip"
    print(f"SAFEBOX_IOS_RUST_ARCHIVE_IDENTICAL_DUPLICATE: {member} ({identity})")
    remove_indexes.add(idxs[1])
    removed += 1

normalized = bytearray(b"!<arch>\n")
for i,e in enumerate(entries):
    if i not in remove_indexes:
        normalized.extend(raw[e["start"]:e["end"]])
out.write_bytes(normalized)
print(f"SAFEBOX_IOS_RUST_ARCHIVE_NORMALIZED: removed={removed}")
PY

"$RANLIB_BIN" "$TMP_OUT"

# Independent postcondition using the platform's own `ar t`; no occurrence-
# selection extension is required for this validation.
AR_LIST_BIN="$(command -v ar || true)"
if command -v xcrun >/dev/null 2>&1; then
  XCRUN_AR="$(xcrun --find ar 2>/dev/null || true)"
  [[ -n "$XCRUN_AR" ]] && AR_LIST_BIN="$XCRUN_AR"
fi
[[ -n "$AR_LIST_BIN" ]] || { echo 'SAFEBOX_IOS_ARCHIVE_NORMALIZE_FAIL: ar unavailable for validation' >&2; exit 66; }
for MEMBER in Tauri.swift.o Invoke.swift.o Plugin.swift.o Channel.swift.o Logger.swift.o; do
  COUNT="$("$AR_LIST_BIN" t "$TMP_OUT" | awk -v n="$MEMBER" '$0==n{c++} END{print c+0}')"
  [[ "$COUNT" == '1' ]] || {
    echo "SAFEBOX_IOS_ARCHIVE_NORMALIZE_FAIL: normalized multiplicity for $MEMBER is $COUNT" >&2
    exit 71
  }
done

chmod 0644 "$TMP_OUT"
mv -f "$TMP_OUT" "$OUTPUT_ABS"
echo 'SAFEBOX_IOS_RUST_ARCHIVE_DEDUP_PASS'
