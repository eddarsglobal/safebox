#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NORMALIZER="$ROOT/safebox-desktop/scripts/ios_normalize_tauri_archive.sh"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/safebox-r38-normalizer.XXXXXX")"
cleanup(){ rm -rf "$TMP"; }
trap cleanup EXIT INT TERM

AR_BIN="$(command -v ar)"
MEMBERS=(Tauri.swift.o Invoke.swift.o Plugin.swift.o Channel.swift.o Logger.swift.o)
mkdir -p "$TMP/a" "$TMP/b"
for M in "${MEMBERS[@]}"; do
  printf 'SAFEBOX-R38-%s\n' "$M" > "$TMP/a/$M"
  cp "$TMP/a/$M" "$TMP/b/$M"
done
"$AR_BIN" qc "$TMP/source.a" "${MEMBERS[@]/#/$TMP/a/}"
"$AR_BIN" q "$TMP/source.a" "${MEMBERS[@]/#/$TMP/b/}"

OUTPUT="$(bash "$NORMALIZER" "$TMP/source.a" "$TMP/normalized.a")"
grep -Fq 'SAFEBOX_IOS_RUST_ARCHIVE_NORMALIZED: removed=5' <<<"$OUTPUT"
grep -Fq 'SAFEBOX_IOS_RUST_ARCHIVE_DEDUP_PASS' <<<"$OUTPUT"
for M in "${MEMBERS[@]}"; do
  C="$("$AR_BIN" t "$TMP/normalized.a" | awk -v n="$M" '$0==n{c++} END{print c+0}')"
  [[ "$C" == 1 ]] || { echo "SAFEBOX_IOS_ARCHIVE_NORMALIZER_R38_FAIL: $M count=$C" >&2; exit 1; }
done

# Divergent duplicates must never be silently removed.
printf 'different-payload\n' > "$TMP/b/Tauri.swift.o"
rm -f "$TMP/divergent.a" "$TMP/rejected.a"
"$AR_BIN" qc "$TMP/divergent.a" "${MEMBERS[@]/#/$TMP/a/}"
"$AR_BIN" q "$TMP/divergent.a" "$TMP/b/Tauri.swift.o"
if bash "$NORMALIZER" "$TMP/divergent.a" "$TMP/rejected.a" >/dev/null 2>&1; then
  echo 'SAFEBOX_IOS_ARCHIVE_NORMALIZER_R38_FAIL: divergent duplicate accepted' >&2
  exit 1
fi

echo 'SAFEBOX_IOS_ARCHIVE_NORMALIZER_R38_PASS'
