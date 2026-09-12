#!/usr/bin/env python3
from pathlib import Path
import sys

WASM = Path(__file__).resolve().parents[1] / "public" / "safebox_core.wasm"
REQUIRED_EXPORTS = {
    "memory",
    "sbx_abi_version",
    "sbx_entropy_len",
    "sbx_alloc",
    "sbx_dealloc",
    "sbx_protect",
    "sbx_unlock",
    "sbx_public_info",
    "sbx_result_data_ptr",
    "sbx_result_data_len",
    "sbx_result_meta_ptr",
    "sbx_result_meta_len",
    "sbx_error_ptr",
    "sbx_error_len",
    "sbx_clear_result",
}

def fail(msg: str) -> None:
    print(f"SAFEBOX_WEB_WASM_CONTRACT_FAIL: {msg}")
    raise SystemExit(1)

def uleb(data: bytes, pos: int):
    value = 0
    shift = 0
    for _ in range(10):
        if pos >= len(data):
            fail("truncated ULEB128")
        b = data[pos]
        pos += 1
        value |= (b & 0x7F) << shift
        if b & 0x80 == 0:
            return value, pos
        shift += 7
    fail("oversized ULEB128")

def name(data: bytes, pos: int):
    n, pos = uleb(data, pos)
    end = pos + n
    if end > len(data):
        fail("truncated name")
    try:
        return data[pos:end].decode("utf-8"), end
    except UnicodeDecodeError:
        fail("invalid UTF-8 export name")

def main() -> None:
    if not WASM.is_file():
        fail(f"missing {WASM.name}; run npm run web:wasm-build")
    data = WASM.read_bytes()
    if len(data) < 8 or data[:4] != b"\x00asm" or data[4:8] != b"\x01\x00\x00\x00":
        fail("invalid WebAssembly header/version")

    pos = 8
    imports = None
    exports = set()
    while pos < len(data):
        section_id = data[pos]
        pos += 1
        section_len, pos = uleb(data, pos)
        end = pos + section_len
        if end > len(data):
            fail("truncated section")
        section = data[pos:end]
        if section_id == 2:
            count, _ = uleb(section, 0)
            imports = count
        elif section_id == 7:
            count, p = uleb(section, 0)
            for _ in range(count):
                export_name, p = name(section, p)
                if p >= len(section):
                    fail("truncated export descriptor")
                p += 1  # kind
                _, p = uleb(section, p)  # index
                exports.add(export_name)
        pos = end

    if imports is None:
        imports = 0
    if imports != 0:
        fail(f"unexpected external imports={imports}; manual ABI must be self-contained")
    missing = sorted(REQUIRED_EXPORTS - exports)
    if missing:
        fail("missing exports: " + ", ".join(missing))
    if len(data) > 8 * 1024 * 1024:
        fail(f"WASM unexpectedly large: {len(data)} bytes")

    print("SAFEBOX_WEB_WASM_MAGIC_PASS")
    print("SAFEBOX_WEB_WASM_NO_EXTERNAL_IMPORTS_PASS")
    print("SAFEBOX_WEB_WASM_ABI_EXPORTS_PASS")
    print(f"SAFEBOX_WEB_WASM_SIZE_PASS bytes={len(data)}")
    print("SAFEBOX_WEB_WASM_CONTRACT_PASS")

if __name__ == "__main__":
    main()
