# SAFEBOX v0.2.8 — Web WASM Full Lock Resolution R72

## Scope
R72 closes the R69/R70/R71 packaging loop where the Argon2 feature change was correct but the shipped workspace lock remained stale under `--locked` on the reference Mac.

## Root cause
R71 attempted a package-scoped `cargo update -p argon2`. Cargo began repairing the feature graph (`base64ct` appeared) but that operation did not fully reconcile every lock edge required by the workspace. The following `cargo metadata --locked` therefore still failed.

## R72 decision
When the shipped lock is stale, Cargo performs one complete `cargo metadata` resolution with `CARGO_NET_OFFLINE=true`. The result must immediately pass `cargo metadata --locked`.

The repair remains fail-closed:
- no network access;
- no version change for any existing package;
- no unexpected package addition/removal;
- only `password-hash 0.5.0` and `base64ct 1.8.3` may be added or removed as a consequence of Argon2's deterministic feature support;
- the real `wasm32-unknown-unknown` tree must contain Argon2 0.5.3 and chacha20poly1305 0.10.1;
- the Web tree must not contain `getrandom` or `rand_core`;
- all subsequent tests/build/interop operations remain `--locked`.

`password-hash` / `base64ct` are not treated as entropy providers. Browser SBX entropy remains explicitly sourced through `crypto.getRandomValues` and passed into the canonical Rust core.

## Runtime scope
No SBX format, crypto parameter, desktop runtime, Android runtime, iOS runtime, Ads or Share Extension behavior is changed by R72. This is Web build/supply-chain closure only.
