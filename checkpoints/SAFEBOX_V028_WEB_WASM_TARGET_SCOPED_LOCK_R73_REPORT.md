# SAFEBOX v0.2.8 — Web WASM Target-Scoped Lock R73

## Scope
R73 closes the R72 build failure on the reference Mac without broadening the Web dependency graph or changing SAFEBOX runtime/crypto behavior.

## Root cause proven by R72 runtime
R72's full offline workspace resolution correctly identified the missing `base64ct 1.8.3` lock edge, then failed because Cargo attempted to download `anstyle-wincon 3.0.11` while `--offline` was active. `anstyle-wincon` is a Windows-only dependency already present in the workspace lock and is unrelated to `safebox-web-wasm`.

The shipped R70/R71/R72 lock had been over-pruned: Argon2 0.5.3 with `features = ["zeroize"]` still requires the deterministic `base64ct 1.8.3` edge. The correct lock state is the previously resolved R69 graph minus the now-orphaned `password-hash 0.5.0` package.

## R73 decision
- Restore `base64ct 1.8.3` to the Argon2 lock dependency list with its crates.io checksum.
- Keep `password-hash` absent.
- Keep `rand_core`/`getrandom` absent from the actual Web target graph.
- Stop mutating Cargo.lock during Web builds.
- Stop using workspace-wide `cargo metadata` for the Web gate.
- Validate only `cargo tree --locked -p safebox-web-wasm --target wasm32-unknown-unknown` before build.
- Network may be used only to fetch crate archives already pinned by the immutable lock; `--locked` forbids graph changes.

## Security invariants
Browser entropy remains provided explicitly by `crypto.getRandomValues` and passed to the canonical Rust core. `base64ct` is deterministic encoding support, not an entropy source. SBX1 format, Argon2id parameters, XChaCha20-Poly1305, desktop runtimes, Android, iOS, Ads and Share Extension behavior are unchanged.
