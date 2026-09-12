# SAFEBOX v0.2.8 — Web WASM Lock Self-Heal R71

## Scope
R71 closes the repeated R69/R70 packaging failure where the source feature graph was updated but the shipped `Cargo.lock` was still rejected by Cargo under `--locked` on the reference Mac.

## Decision
R71 stops treating a hand-edited lockfile as proof. Before the Web WASM build, Cargo itself validates the workspace lock. If it is stale, a narrowly scoped offline `cargo update -p argon2 --precise 0.5.3` is permitted exactly once.

The repair is fail-closed:
- no network access during repair or graph validation;
- no package additions are accepted;
- no package version changes are accepted;
- only orphan `password-hash 0.5.0` and `base64ct 1.8.3` entries may disappear;
- the resulting lock must immediately pass `cargo metadata --locked`;
- the actual `wasm32-unknown-unknown` dependency tree must contain Argon2 0.5.3 and chacha20poly1305 0.10.1 and must not contain `getrandom`, `password-hash`, or `rand_core`;
- all subsequent core tests, WASM build, interop tests and native CLI operations remain `--locked`.

## Security invariants
Canonical SBX format, Argon2id parameters, XChaCha20-Poly1305 implementation, desktop runtime, iOS runtime, Ads and Share Extension are unchanged from R70/R67 baselines. R71 changes only Web build/lock validation infrastructure.

## Reference Mac gate
Run `npm ci && npm run web:build`. R71 must print `SAFEBOX_WEB_CARGO_LOCK_SYNC_PASS`, then continue through the existing canonical memory tests, wasm32 build, WASM contract, Node negative tests, bidirectional native/WASM interop, Vite build and dist gate.
