#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NORMALIZER="$ROOT/safebox-desktop/scripts/ios_normalize_tauri_archive.sh"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/safebox-r37-normalizer.XXXXXX")"
cleanup(){ rm -rf "$TMP"; }
trap cleanup EXIT INT TERM

AR_BIN=''
if command -v xcrun >/dev/null 2>&1; then
  CLANG_BIN="$(xcrun --find clang 2>/dev/null || true)"
  [[ -n "$CLANG_BIN" && -x "$(dirname "$CLANG_BIN")/llvm-ar" ]] && AR_BIN="$(dirname "$CLANG_BIN")/llvm-ar"
fi
[[ -n "$AR_BIN" ]] || AR_BIN="$(command -v llvm-ar || command -v ar)"

MEMBERS=(Tauri.swift.o Invoke.swift.o Plugin.swift.o Channel.swift.o Logger.swift.o)
mkdir -p "$TMP/a" "$TMP/b"
for M in "${MEMBERS[@]}"; do
  printf 'SAFEBOX-R37-%s\n' "$M" > "$TMP/a/$M"
  cp "$TMP/a/$M" "$TMP/b/$M"
done
"$AR_BIN" qc "$TMP/source.a" "${MEMBERS[@]/#/$TMP/a/}"
"$AR_BIN" q "$TMP/source.a" "${MEMBERS[@]/#/$TMP/b/}"

bash "$NORMALIZER" "$TMP/source.a" "$TMP/normalized.a" >/dev/null
for M in "${MEMBERS[@]}"; do
  C="$($AR_BIN t "$TMP/normalized.a" | awk -v n="$M" '$0==n{c++} END{print c+0}')"
  [[ "$C" == 1 ]] || { echo "SAFEBOX_IOS_ARCHIVE_NORMALIZER_R37_FAIL: $M count=$C" >&2; exit 1; }
done

# Divergent duplicates must never be silently removed.
printf 'different-payload\n' > "$TMP/b/Tauri.swift.o"
rm -f "$TMP/divergent.a" "$TMP/rejected.a"
"$AR_BIN" qc "$TMP/divergent.a" "${MEMBERS[@]/#/$TMP/a/}"
"$AR_BIN" q "$TMP/divergent.a" "$TMP/b/Tauri.swift.o"
if bash "$NORMALIZER" "$TMP/divergent.a" "$TMP/rejected.a" >/dev/null 2>&1; then
  echo 'SAFEBOX_IOS_ARCHIVE_NORMALIZER_R37_FAIL: divergent duplicate accepted' >&2
  exit 1
fi

echo 'SAFEBOX_IOS_ARCHIVE_NORMALIZER_R37_PASS'
