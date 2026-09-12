# SAFEBOX v0.2.8 R68 — Canonical WebAssembly SBX Core

R68 is the first real Web cryptographic engine slice after the R67 browser/runtime rebaseline.

## Architecture

The browser does not reimplement SafeBox cryptography in JavaScript. `safebox-core` now has in-memory create/unlock/public-info entry points that reuse the canonical SBX header/chunk functions, Argon2id derivation, XChaCha20-Poly1305 AEAD, AAD values and validation limits. A new `safebox-web-wasm` cdylib exposes a small pointer/length ABI with no wasm-bindgen/js-sys/web-sys dependency.

Browser JavaScript owns only browser responsibilities: File/Blob I/O, CSPRNG entropy via `crypto.getRandomValues`, bounded copies into WebAssembly, and download of the generated/restored bytes. Temporary JS copies and retained WASM result buffers are overwritten before release where the platform permits.

## Security boundaries

- Canonical `format.rs` and `validation.rs` remain byte-for-byte R67.
- Cryptographic derive/encrypt/decrypt/chunk source is byte-for-byte R67 after removing the two target-gating annotations around OS randomness.
- OS randomness/chrono remain native-only dependencies; Web creation receives explicit browser CSPRNG entropy instead of invoking an unavailable OS RNG path.
- Browser files are bounded to 128 MiB in this memory-engine slice to avoid trivial memory exhaustion. Larger browser files remain fail-closed until the streaming Web slice.
- WASM build contract rejects external imports and requires the complete ABI export set.
- No network endpoint, account service or cloud upload is introduced.
- Existing Tauri desktop runtime and iOS native surfaces are unchanged.

## Container verification status

The R68 source/static gates and TypeScript strict check were run in the packaging environment. That environment has no Rust/Cargo toolchain and therefore cannot truthfully claim a compiled WebAssembly artifact or Rust test execution. The release intentionally ships source-only for the WASM engine; `npm run web:build` on the reference Mac installs the standard Rust wasm32 target if missing, runs the two canonical memory compatibility tests, builds the locked WASM crate, validates the produced module contract, and then builds Vite.

## Runtime acceptance

R68 becomes runtime-validated only after the reference Mac successfully runs `npm ci && npm run web:build` and a real browser interoperability check is completed in both directions with an existing desktop SafeBox build.
