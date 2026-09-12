# SAFEBOX v0.2.8 — R69 Web WASM Entropy Closure

## Trigger
Reference Mac R68 proved both native safebox-core memory tests, then wasm32-unknown-unknown failed compiling getrandom 0.2.17 because Argon2 0.5.3 default features enable `rand` through `password-hash`/`rand_core`.

## Decision
Do **not** enable getrandom's JavaScript backend. SAFEBOX Web already supplies all format entropy explicitly from browser `crypto.getRandomValues`; enabling a second implicit RNG path would weaken the R68 entropy contract and can introduce WASM imports.

`argon2` is now pinned as:

```toml
argon2 = { version = "=0.5.3", default-features = false, features = ["alloc", "zeroize"] }
```

SAFEBOX uses the low-level deterministic `Argon2::hash_password_into` API with an explicit salt. No PasswordHash/SaltString/RNG API is used. Argon2id algorithm, version, KDF parameters and SBX format are unchanged. `zeroize` additionally wipes Argon2 internal password-derived blocks.

## Runtime gate required on reference Mac
`npm run web:build` must now reach the WASM contract, Node roundtrip/tamper/wrong-code/public-info tests, bidirectional native/WASM interoperability, Vite build and dist checks.
