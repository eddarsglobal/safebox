# SAFEBOX v0.2.8 — Web WASM Graph Lock Convergence R75

## Scope
R75 is a lockfile-only convergence on top of the R74 AEAD RNG isolation source change.

## Runtime evidence from R74
R74 passed the canonical Argon2/base64ct lock checks and then Cargo rejected `--locked` before the target graph could be evaluated. Therefore the R74 source feature decision was not disproven; the packaged lockfile was stale relative to that feature graph.

## Root cause
`chacha20poly1305 0.10.1` default features had previously enabled `aead/getrandom`, which activates the optional `crypto-common -> rand_core -> getrandom` edge. R74 disabled the AEAD default features and retained only `alloc`, but its Cargo.lock still carried the old optional `crypto-common -> rand_core` edge. Cargo correctly required the lockfile to be updated.

## R75 decision
- Keep the exact R74 `safebox-core/Cargo.toml` feature declaration.
- Keep native `rand_core::OsRng` target-gated under `cfg(not(target_arch = "wasm32"))`.
- Keep browser entropy supplied explicitly via `crypto.getRandomValues`.
- Remove only the stale `"rand_core"` dependency edge from the `crypto-common 0.1.7` package block in Cargo.lock.
- Retain the `rand_core` and `getrandom` packages required by native targets; do not globally delete them from the workspace lock.
- Keep Web graph validation target-scoped and `--locked`.

## Required Mac proof
The Web target graph must contain Argon2 and XChaCha20-Poly1305 but no `rand_core`, `getrandom`, or `password-hash`. Then the locked WASM build, ABI checks, Node roundtrip/tamper/wrong-code tests, bidirectional native/Web interoperability and Vite dist checks must all pass.
