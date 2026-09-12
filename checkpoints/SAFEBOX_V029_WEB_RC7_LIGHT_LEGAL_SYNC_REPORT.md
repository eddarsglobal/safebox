# SAFEBOX v0.2.9 — Web RC7 Light/Legal Sync

## Purpose
This web release carries the physical-device RC7 visual corrections back to the production Web surface without changing the SBX cryptographic core.

## Included corrections
- dedicated high-contrast Light mode for the landing page and crypto application;
- shared System / Light / Dark preference through `safebox-theme-mode.v1`;
- legal pages use the same theme preference and expose an Appearance selector;
- landing and `app.html` remain in the same production static bundle;
- existing strict Web deployment policy, CSP, no-upload/no-third-party defaults and content-addressed WASM workflow are preserved.

## Crypto source freeze
- safebox-core source tree SHA-256 aggregate: `6775299184efb145bfd1c6e247021e077072cb0c7d77bcec93c89728caefb364`
- safebox-web-wasm source tree SHA-256 aggregate: `0e9211d1a4d3c2eb266bedf7f8c7c86c12670111d54785003ffe3ceac66bc385`

## Deployment
Run from `safebox-desktop`:

```bash
npm ci
bash ../verification/verify_v029_web_rc7_light_legal_sync.sh
bash scripts/web_rc7_release.sh
```

The generated deployment archive is written under `../release/` and is intended for a new deployment in the existing Cloudflare Pages project `safebox`, preserving the public URL.
