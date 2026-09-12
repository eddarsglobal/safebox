# SAFEBOX V0.2.8 — Web Browser Progressive E2E R79

R79 fixes the only defect observed in the R78 production gate: the headless Chrome step used `--dump-dom` with a 120-second virtual-time budget and therefore stayed silent even while the browser test was running.

## Changes
- Removes `--dump-dom` and `--virtual-time-budget` from the production E2E gate.
- Runs Chrome/Chromium with an ephemeral loopback Chrome DevTools Protocol endpoint.
- Polls only the SafeBox-owned loopback E2E result element.
- Emits each browser PASS marker as soon as it appears.
- Emits a heartbeat every 5 seconds with elapsed time and the last completed marker.
- Enforces a real hard timeout (90 seconds by default, configurable with `SAFEBOX_WEB_E2E_TIMEOUT`).
- Terminates the headless browser immediately after `SAFEBOX_WEB_BROWSER_E2E_PASS` instead of waiting for an arbitrary virtual-time budget.
- The in-page E2E harness now publishes markers progressively while retaining loopback + explicit query gating.

## Security / runtime invariants
- Canonical SBX Rust/WASM crypto core is unchanged from R78/R77.
- SBX format, Argon2id parameters, XChaCha20-Poly1305, Web entropy path and content-addressed WASM are unchanged.
- Desktop, Android and iOS native runtimes are unchanged.
- CDP binds to Chrome's ephemeral loopback debugging endpoint using a fresh disposable browser profile.
- No Playwright/Puppeteer dependency, remote service, analytics, upload path or production test endpoint is added.
