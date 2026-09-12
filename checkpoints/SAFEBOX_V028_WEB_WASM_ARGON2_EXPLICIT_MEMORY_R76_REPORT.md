# SAFEBOX v0.2.8 — R76 Web WASM Argon2 Explicit Memory Closure

## Trigger
R75 reached the native `safebox-core` compile and failed with `E0599` because
`Argon2::hash_password_into` is gated behind Argon2's `alloc` feature. SAFEBOX
intentionally disables that feature on the shared Web core to avoid pulling the
password-hash/RNG path into the wasm dependency graph.

## Resolution
R76 keeps `argon2 = 0.5.3` with `default-features = false` and `zeroize` only.
Instead of enabling `alloc`, `derive_code_key` now allocates exactly
`argon2.params().block_count()` public `argon2::Block` values and calls
`hash_password_into_with_memory` directly.

In Argon2 0.5.3 the gated `hash_password_into` convenience API performs that
same allocation and delegates to `hash_password_into_with_memory`, so the
Argon2id algorithm, version, KDF parameters, salt, password and 32-byte output
remain unchanged. The explicit memory buffer is zeroized after each derivation;
the output key is also zeroized before returning an error.

## Security / compatibility invariants
- Argon2id + V0x13 unchanged.
- KDF memory/time/parallelism values unchanged.
- XChaCha20-Poly1305 path unchanged.
- SBX format and validation files unchanged.
- Web wasm dependency graph must remain free of getrandom/rand_core/password-hash.
- Native OsRng remains target-gated and available for non-wasm builds.
- Cargo.lock remains immutable during `web:build`.
