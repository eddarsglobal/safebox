# SAFEBOX v0.2.2d — Android Verifier Compatibility R26

## Scope
R26 is a verification-only compatibility closure on top of R25. No SBX format, cryptography, Android Share/Open behavior, UI, or runtime behavior is changed.

## Trigger
R25 intentionally replaced `npx tauri` with the pinned local Tauri CLI to prevent concurrent dependency mutation while Vite is running. The historic R17 icon verifier still required the literal legacy command `npx tauri icon "$ICON_SOURCE"`, causing a false failure even though Android icon generation succeeded at runtime.

## Fix
The R17 verifier now checks the semantic requirement: the official icon installer must invoke Tauri `icon` with the canonical icon source. It accepts the historic `npx` form or the current pinned-local-binary form. R25/R26 continue to explicitly reject `npx tauri` in active Android runtime scripts.

## 9-council decision
1. Crypto/Security: PASS — no crypto or SBX changes.
2. Defensive HACKER/Red Team: PASS — no weakening; local pinned CLI remains mandatory in active runtime.
3. Android: PASS — preserves the R25 runtime path that built, installed, and started MainActivity.
4. iOS: N/A — untouched.
5. Web/WASM: N/A — untouched.
6. Desktop: PASS — historic desktop checks remain in baseline.
7. Design/UI: N/A — untouched.
8. Privacy/Ads: N/A — untouched.
9. QA/Release: PASS — removes a brittle literal-command assertion and replaces it with a semantic invariant.

## Runtime evidence from user Mac before R26
- npm audit: 0 vulnerabilities.
- frontend toolchain restored and ready.
- Android project generated.
- official launcher/adaptive icon generated.
- emulator cold boot ready.
- Vite 8.1.3 started without the previous `Cannot find module 'vite'` failure.
- Android Rust build finished.
- streamed install returned Success.
- MainActivity started.

## Next gate
After R26 verifies, perform the real Android Share/Open + E2E user-flow validation. Do not add new product features before that gate closes.
