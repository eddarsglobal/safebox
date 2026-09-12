# SafeBox Web production deployment — R86 RC7 Light/Legal Sync

R86 RC7 Light/Legal Sync carries the validated RC7 high-contrast Light mode and synchronized legal-page System/Light/Dark theme into the production Web surface. The R85 cryptographic/Web lineage remains unchanged: Create/Open stays fully local in the browser and isolated from advertising code.

## Production host policy

Deploy **only** the generated `safebox-desktop/dist/` tree (or the ZIP produced by `npm run web:deploy-bundle`) over HTTPS.

Production-approved hosting must preserve the response policy in `dist/_headers`, including CSP, `nosniff`, frame denial, referrer policy, permissions policy, COOP/CORP, HSTS and cache rules. Cloudflare Pages and Netlify can consume the `_headers` convention.

**GitHub Pages is not a SafeBox production target in R81** because it does not natively provide the custom response-header control required by this security gate. It may be used only as a non-production preview if the security requirements are intentionally relaxed; that preview must not be treated as the final SafeBox Web deployment.

## Release build

```bash
cd safebox-desktop
npm ci
npm run web:release-gate
```

The gate runs the validated browser Protect/Unlock E2E, the R85 immersive-experience checks, deployment source checks and then creates a deterministic R86 RC7 Light/Legal Sync deploy ZIP plus SHA-256 manifest under `../release/`.

The release bundle contains only production static files. Source files, Cargo manifests, `.env`, source maps, private keys, verification scripts and platform sources are rejected.

## Required production properties

- HTTPS only.
- `Strict-Transport-Security: max-age=31536000`.
- `safebox_core.<sha12>.wasm` served as `application/wasm`.
- `index.html` served with `Cache-Control: no-store, max-age=0`.
- hashed JS/CSS and content-addressed WASM cached for one year with `immutable`.
- CSP remains `connect-src 'self'`; the Web source contains only one network fetch, the same-origin GET used to load the WASM engine.
- no third-party scripts, analytics, CDN crypto, remote fonts, service workers, WebSocket/XHR/beacon egress or user-file uploads.
- unknown/source paths such as `/Cargo.toml`, `/.env`, `/.git/config` and `/safebox-core/src/crypto.rs` must not be publicly served.
- do not configure an SPA fallback that returns `index.html` for arbitrary source-like paths.

## Post-deployment audit

After uploading the deploy ZIP contents, run:

```bash
cd safebox-desktop
SAFEBOX_WEB_PUBLIC_URL=https://YOUR-SAFEBOX-HOST.example npm run web:remote-audit
```

The remote audit compares the public deployment byte-for-byte with the local validated `dist/`, checks HTTPS/HSTS/CSP/security headers, WASM MIME/cache, immutable assets and source-leak denial.

Final required marker:

```text
SAFEBOX_WEB_REMOTE_DEPLOYMENT_AUDIT_PASS
```
