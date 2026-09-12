# SAFEBOX v0.2.8 — Web WASM Locked Dependency Graph R70

## Scope
R70 closes the R69 `cargo --locked` packaging failure observed on the reference Mac after `SAFEBOX_WEB_WASM_TARGET_READY_PASS`.

## Root cause
R69 changed Argon2 features but shipped a manually inconsistent lock graph. In addition, enabling Argon2 feature `alloc` activates the optional `password-hash` path; that is unnecessary for SAFEBOX because the canonical core uses low-level `Argon2::hash_password_into` with caller-provided salt and does not use password-hash allocation/random APIs.

## R70 decision
- `argon2 = =0.5.3`, `default-features = false`, `features = ["zeroize"]` only.
- no Argon2 `alloc`, `password-hash`, or `rand` feature in the Web path.
- `Cargo.lock` repaired to Argon2's matching dependency set: `blake2`, `cpufeatures`, `zeroize`.
- orphan `password-hash` and `base64ct` lock entries removed.
- native `rand_core/getrandom` remains target-gated for non-WASM SAFEBOX creation and does not become a WebAssembly dependency.
- canonical SBX format, Argon2id parameters, XChaCha20-Poly1305 path, desktop runtime, iOS runtime, Ads and Share Extension unchanged.

## Runtime gate
The reference Mac must run `npm run web:build`. Success requires the locked Rust tests, locked wasm32 build, WASM contract, Node roundtrip/tamper/wrong-code/public-info, bidirectional native↔WASM interop, Vite build and dist gate.
