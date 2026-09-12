# SAFEBOX v0.2.9 — Immersive Landing / Distribution / Legal — R82

Date: 2026-08-31
Baseline: SAFEBOX v0.2.8 R81

## Implemented

- Public immersive landing separated from `app.html` cryptographic Create/Open surface.
- Scroll-driven file → crypto reactor → `.SBX` visual narrative with PDF/MP4/EXE/ZIP/JPG and KB/MB/GB examples.
- Scroll-controlled 3D transforms, scale, zoom, rotation, depth and crypto-glyph rain; reduced-motion fallback.
- Mobile-first responsive layouts.
- Browser language detection with EN default and EN/FR/IT/PT/AR/DE/ES/HR landing copy; Arabic RTL.
- System / Dark / Light appearance modes.
- PWA manifest and zero-cost iPhone/iPad Add-to-Home-Screen path.
- Android GitHub Release link surface, injected at build by `VITE_SAFEBOX_ANDROID_RELEASE_URL`.
- Legal Notice, Privacy, Terms, Cookies & Advertising, and Third-party Licences pages.
- Attribution: "SafeBox is created by EDDARS, a Swiss developer."
- Google advertising placeholder on landing only, disabled by default.
- `ADS_ACTIVATION.md` with EDDARS activation steps for Web AdSense and Android AdMob.
- Browser E2E routing updated to `app.html?__safebox_e2e=1` so the crypto gate remains on the crypto surface.
- New `web:experience-check` gate.

## Security invariant

The validated R81 crypto/runtime files checked by `scripts/web_experience_check.py` remain byte-identical, including `safebox-core/src/crypto.rs`, `safebox-core/src/format.rs`, `safebox-web-wasm/src/lib.rs`, `src/web-sbx-engine.ts`, and `src/main.ts`.

## Verification completed in packaging environment

- `python3 scripts/web_experience_check.py` — PASS
- TypeScript syntax transpilation for new `src/landing.ts` and `src/app-route.ts` — PASS

## Verification requiring the reference Mac

The packaging environment does not contain Rust/Cargo, therefore the canonical WASM build and real browser production gate must be run on the reference Mac:

```bash
cd safebox-desktop
npm ci
npm run web:release-gate
```

Do not deploy until that gate is green.


## R82 RC2 packaging closure

The first reference-Mac release-gate run validated the complete WASM/browser/landing/deployment checks and then exposed a packaging allowlist regression: the inherited R81 bundler rejected the new R82 public files beginning with `ads-config.json`.

RC2 closes that boundary by:

- moving the deploy bundle identity to `SAFEBOX_V029_PACKAGE_ID.txt`;
- producing `safebox_v0.2.9_web_deploy_R82.*`;
- explicitly allowlisting only the R82 public root files and exact legal-page files;
- extending secret scanning to JSON/WebManifest text;
- adding no-store/no-cache rules for non-hashed R82 public documents/config;
- updating the remote audit identity/leak probes to R82.

No validated R81 cryptographic/runtime file is modified.
