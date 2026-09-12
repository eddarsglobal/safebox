# SAFEBOX V0.2.8 — Web Production Browser E2E R78

R78 promotes the validated R77 WebAssembly engine into a production-oriented static Web App surface.

## Added
- Web-only CSP meta injection; Tauri desktop HTML is not constrained by this browser CSP.
- Deployable `_headers` policy: CSP, nosniff, frame denial, referrer policy, permissions policy, COOP/CORP.
- Content-addressed `safebox_core.<sha12>.wasm` and immutable cache policy.
- `index.html` no-store policy; hashed JS/CSS/WASM immutable.
- No service worker, CDN crypto, third-party script, analytics or remote runtime dependency.
- Real Chrome/Chromium headless browser gate using the installed browser; no Playwright/Puppeteer package required.
- Browser E2E covers Protect, public metadata, wrong-code reject, tamper reject, Unlock byte equality and Blob boundary.
- E2E harness is inert unless both loopback host and explicit `?__safebox_e2e=1` are present.
- Local production server mirrors deployment security/cache headers for runtime verification.

## Security boundary
The browser continues to run the canonical Rust/WASM SBX core locally. R78 does not add a backend or upload path. The Web App remains a static application.
