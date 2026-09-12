#!/usr/bin/env bash
set -euo pipefail

DESKTOP_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ROOT_DIR="$(cd "$DESKTOP_DIR/.." && pwd)"
WORK_DIR="${SAFEBOX_E2E_FIXTURE_DIR:-${TMPDIR:-/tmp}/safebox-e2e-fixtures}"
LARGE_MIB="${SAFEBOX_E2E_LARGE_MIB:-64}"

if ! [[ "$LARGE_MIB" =~ ^[0-9]+$ ]] || [ "$LARGE_MIB" -lt 1 ] || [ "$LARGE_MIB" -gt 512 ]; then
  echo "SAFEBOX_E2E_BAD_LARGE_MIB: choose 1..512" >&2
  exit 64
fi

rm -rf "$WORK_DIR"
mkdir -p "$WORK_DIR"

cat > "$WORK_DIR/safebox-e2e-small.txt" <<'TXT'
SafeBox Android E2E deterministic text fixture.
This file must survive Create -> SBX -> Unlock byte-for-byte.
TXT

cat > "$WORK_DIR/SafeBox E2E – unicode čćžšđ.txt" <<'TXT'
SafeBox Unicode filename fixture: č ć ž š đ — é à العربية 日本語
TXT

python3 - "$WORK_DIR/safebox-e2e-document.pdf" <<'PY'
from pathlib import Path
import sys
out = Path(sys.argv[1])
stream = b"BT /F1 16 Tf 36 110 Td (SafeBox Android E2E PDF) Tj ET\n"
objects = [
    b"<< /Type /Catalog /Pages 2 0 R >>",
    b"<< /Type /Pages /Kids [3 0 R] /Count 1 >>",
    b"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 300 200] /Resources << /Font << /F1 5 0 R >> >> /Contents 4 0 R >>",
    b"<< /Length " + str(len(stream)).encode() + b" >>\nstream\n" + stream + b"endstream",
    b"<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>",
]
buf = bytearray(b"%PDF-1.4\n")
offsets = [0]
for i, obj in enumerate(objects, 1):
    offsets.append(len(buf))
    buf.extend(f"{i} 0 obj\n".encode())
    buf.extend(obj)
    buf.extend(b"\nendobj\n")
xref = len(buf)
buf.extend(f"xref\n0 {len(objects)+1}\n".encode())
buf.extend(b"0000000000 65535 f \n")
for off in offsets[1:]:
    buf.extend(f"{off:010d} 00000 n \n".encode())
buf.extend(f"trailer\n<< /Size {len(objects)+1} /Root 1 0 R >>\nstartxref\n{xref}\n%%EOF\n".encode())
out.write_bytes(buf)
PY

if [ -f "$DESKTOP_DIR/public/safebox-logo.png" ]; then
  cp "$DESKTOP_DIR/public/safebox-logo.png" "$WORK_DIR/safebox-e2e-image.png"
fi

python3 - "$WORK_DIR/safebox-e2e-large-${LARGE_MIB}MiB.bin" "$LARGE_MIB" <<'PY'
from pathlib import Path
import sys
path = Path(sys.argv[1])
mib = int(sys.argv[2])
block = bytes((i % 251 for i in range(1024 * 1024)))
with path.open('wb') as f:
    for _ in range(mib):
        f.write(block)
PY

(
  cd "$WORK_DIR"
  shasum -a 256 * > SHA256SUMS.txt
)

echo "SafeBox Android E2E fixtures: $WORK_DIR"
cat "$WORK_DIR/SHA256SUMS.txt"

for file in "$WORK_DIR"/*; do
  [ -f "$file" ] || continue
  bash "$DESKTOP_DIR/scripts/android_import.sh" "$file"
done

echo "SAFEBOX_ANDROID_E2E_FIXTURES_READY: /sdcard/Download/SafeBox-E2E"
echo "Use Android Files -> Downloads -> SafeBox-E2E for the manual Create/Unlock flow."
