# SAFEBOX v0.2.8 — Web WASM AEAD RNG Isolation R74

## Scope
R74 closes the R73 runtime graph failure at its actual source.

## Root cause proven by R73 runtime
The Web target graph showed `rand_core 0.6.4 -> getrandom 0.2.17` underneath the unified `crypto-common 0.1.7` feature set. The enabling dependency is `chacha20poly1305 0.10.1`, whose default features include `getrandom` and `rand_core`. SAFEBOX does not use those random-generation APIs: file keys, salts and nonces are supplied explicitly by the canonical SBX creation paths, and browser entropy is supplied by `crypto.getRandomValues`.

## R74 decision
- Keep `chacha20poly1305 = 0.10.1`.
- Disable its default features.
- Enable only `alloc`, which is required by the existing `Aead` Vec-returning API.
- Keep native SAFEBOX entropy on the existing target-gated `rand_core::OsRng`.
- Keep browser entropy explicit and external to the Rust crypto crates.
- Keep Argon2id, XChaCha20-Poly1305, SBX1 bytes and all runtime source unchanged.

## Required runtime proof
`cargo tree --locked -p safebox-web-wasm --target wasm32-unknown-unknown -e normal` must contain XChaCha20-Poly1305 but no `getrandom`, `rand_core`, or `password-hash`. The subsequent locked WASM build, Node smoke tests and bidirectional native/Web interoperability remain mandatory.
