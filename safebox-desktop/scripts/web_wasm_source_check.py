#!/usr/bin/env python3
from pathlib import Path
import hashlib, json, re, sys
ROOT = Path(__file__).resolve().parents[2]
D = ROOT / 'safebox-desktop'
CORE = ROOT / 'safebox-core'
WASM = ROOT / 'safebox-web-wasm'

def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()

def req(cond: bool, marker: str, detail=''):
    if not cond:
        print(f'{marker.replace("_PASS","_FAIL")}: {detail or "contract mismatch"}')
        raise SystemExit(1)
    print(marker)

pkg = json.loads((D/'package.json').read_text())
main = (D/'src/main.ts').read_text()
engine = (D/'src/web-sbx-engine.ts').read_text()
memory = (CORE/'src/memory.rs').read_text()
crypto = (CORE/'src/crypto.rs').read_text()
core_toml = (CORE/'Cargo.toml').read_text()
wasm_toml = (WASM/'Cargo.toml').read_text()
wasm_src = (WASM/'src/lib.rs').read_text()
build = (D/'scripts/web_wasm_build.sh').read_text()

req((ROOT/'SAFEBOX_V028_PACKAGE_ID.txt').read_text().strip() == 'v0.2.8-web-browser-blob-boundary-r77-20260830A',
    'SAFEBOX_WEB_R77_PACKAGE_ID_PASS')
req('"safebox-web-wasm"' in (ROOT/'Cargo.toml').read_text() and '[lib]' in wasm_toml and 'crate-type = ["cdylib"]' in wasm_toml,
    'SAFEBOX_WEB_WASM_CRATE_PASS')
req('wasm-bindgen' not in wasm_toml and 'js-sys' not in wasm_toml and 'web-sys' not in wasm_toml,
    'SAFEBOX_WEB_WASM_NO_GLUE_RUNTIME_PASS')
req('target_arch = "wasm32"' in core_toml and 'rand_core' in core_toml and 'chrono' in core_toml,
    'SAFEBOX_WEB_CORE_TARGET_ISOLATION_PASS')
req('argon2 = { version = "=0.5.3", default-features = false, features = ["zeroize"] }' in core_toml,
    'SAFEBOX_WEB_ARGON2_WASM_ENTROPY_ISOLATION_PASS')
req('hash_password_into_with_memory' in crypto and 'Block::default()' in crypto and 'argon2.params().block_count()' in crypto,
    'SAFEBOX_WEB_ARGON2_EXPLICIT_MEMORY_PASS')
req('hash_password_into(code.as_bytes()' not in crypto and 'features = ["alloc"]' not in core_toml.split('argon2 =',1)[1].split('\n',1)[0],
    'SAFEBOX_WEB_ARGON2_NO_ALLOC_FEATURE_PASS')
req('memory_blocks.zeroize()' in crypto and 'key.zeroize()' in crypto,
    'SAFEBOX_WEB_ARGON2_MEMORY_ZEROIZE_PASS')
req('chacha20poly1305 = { version = "=0.10.1", default-features = false, features = ["alloc"] }' in core_toml,
    'SAFEBOX_WEB_XCHACHA_RNG_FEATURE_ISOLATION_PASS')
req('features = ["zeroize"]' in core_toml and 'features = ["alloc", "password-hash"' not in core_toml,
    'SAFEBOX_WEB_ARGON2_INTERNAL_ZEROIZE_PASS')
req('create_sbx_bytes' in memory and 'unlock_sbx_bytes' in memory and 'read_public_metadata_from_bytes' in memory,
    'SAFEBOX_WEB_CORE_MEMORY_API_PASS')
req(all(token in memory for token in ['write_header(&mut output, &header)', 'write_chunk(&mut output', 'derive_code_key', 'AAD_FILE_KEY', 'AAD_METADATA', 'chunk_aad', 'chunk_nonce']),
    'SAFEBOX_WEB_CANONICAL_FORMAT_PATH_PASS')
req('WEB_ENTROPY_LEN' in memory and 'file_key = Zeroizing::new(take_entropy::<KEY_LEN>' in memory,
    'SAFEBOX_WEB_EXPLICIT_ENTROPY_CONTRACT_PASS')
req('memory_roundtrip_uses_canonical_sbx_format' in memory and 'memory_unlock_rejects_wrong_code_and_tamper' in memory,
    'SAFEBOX_WEB_CORE_COMPAT_TESTS_PASS')
req(all(name in wasm_src for name in ['sbx_protect', 'sbx_unlock', 'sbx_public_info', 'sbx_clear_result', 'sbx_alloc', 'sbx_dealloc']),
    'SAFEBOX_WEB_MANUAL_ABI_PASS')
req('MAX_CODE_BYTES' in wasm_src and 'MAX_CONFIG_JSON' in wasm_src and 'checked_slice' in wasm_src,
    'SAFEBOX_WEB_ABI_BOUNDS_PASS')
req('value.fill(0)' in wasm_src and 'sbx_clear_result' in wasm_src and 'inputBytes.fill(0)' in engine and 'codeBytes.fill(0)' in engine and 'entropy.fill(0)' in engine,
    'SAFEBOX_WEB_TRANSIENT_MEMORY_CLEAR_PASS')
req('crypto.getRandomValues(entropy)' in engine and 'Math.random' not in engine,
    'SAFEBOX_WEB_CSPRNG_PASS')
req('WEB_SBX_MAX_FILE_BYTES = 128 * 1024 * 1024' in engine,
    'SAFEBOX_WEB_MEMORY_DOS_BOUND_PASS')
req('credentials: "same-origin"' in engine and 'http://' not in engine and 'https://' not in engine,
    'SAFEBOX_WEB_LOCAL_ENGINE_ONLY_PASS')
req('protectWebFile' in main and 'unlockWebFile' in main and 'readWebPublicInfo' in main and 'webCryptoPendingMessage' not in main,
    'SAFEBOX_WEB_UI_REAL_ENGINE_PASS')
req('application/x-safebox' in main and 'downloadWebBytes' in main,
    'SAFEBOX_WEB_BROWSER_DOWNLOAD_PASS')
req('rustup target add "$TARGET"' in build and 'cargo build --locked -p safebox-web-wasm' in build and 'web_wasm_contract_check.py' in build,
    'SAFEBOX_WEB_REPRO_BUILD_PIPELINE_PASS')
req(pkg['scripts'].get('web:build') == 'npm run web:wasm-build && npm run web:ui-build && npm run web:dist-check',
    'SAFEBOX_WEB_PRODUCTION_BUILD_GATE_PASS')

# R67 canonical format/validation remain immutable. R76 changes only the
# Argon2 allocation wrapper: algorithm, version, params, AEAD and AAD constants
# remain exactly the canonical ones.
req(sha(CORE/'src/format.rs') == '26edb67b2be91ff5c7d765e100e4aafa5e50933919c0db2e4370901f67205ea1',
    'SAFEBOX_WEB_FORMAT_R67_HASH_PASS')
req(sha(CORE/'src/validation.rs') == '8ae9df9563a7d8bf0fb0d3399c4642a0ca4e796f284b5681a3cd1f02237f209b',
    'SAFEBOX_WEB_VALIDATION_R67_HASH_PASS')
req(all(token in crypto for token in [
    'Argon2::new(Algorithm::Argon2id, Version::V0x13, params)',
    'Params::new(', 'kdf.memory_kib', 'kdf.time_cost', 'kdf.parallelism',
    'XChaCha20Poly1305::new', 'AAD_FILE_KEY', 'AAD_METADATA', 'AAD_CHUNK'
]), 'SAFEBOX_WEB_CRYPTO_ALGORITHM_R67_EQUIVALENCE_PASS')
req(sha(D/'src-tauri/src/lib.rs') == '5a4bc10bc1d362a0737c0da2b0b6caad00436206137fd0fc800e2b842c57f297',
    'SAFEBOX_DESKTOP_RUNTIME_R67_UNCHANGED_R68_PASS')
req(sha(D/'src-tauri/ios/SafeBoxAdsBridge.mm') == 'a408b55ec036ee71894853c144fc753e7a181eeaca7b5ae6872ec636dfc5e2ea',
    'SAFEBOX_IOS_ADS_UNCHANGED_R68_PASS')
req(sha(D/'src-tauri/ios/SafeBoxShareInboxBridge.mm') == 'da8b92247ee777a03770cc7df67b52b13a8981ca6987b70403fbd97e8913d9e4',
    'SAFEBOX_IOS_SHARE_RUNTIME_UNCHANGED_R68_PASS')
req(sha(D/'src-tauri/ios-share/ShareViewController.swift') == 'c868a61f534a425eabf3bea9adeb591474823053ecd582c799a1cafba4da59a4',
    'SAFEBOX_IOS_SHARE_EXTENSION_UNCHANGED_R68_PASS')

print('SAFEBOX_V028_WEB_WASM_ARGON2_EXPLICIT_MEMORY_R76_SOURCE_PASS')
