# SAFEBOX v0.2.8 — Web Deployment Artifact & Remote Audit — R81

Package ID: `v0.2.8-web-deployment-artifact-remote-audit-r81-20260831A`

## Baseline accepted

R80 real-browser production gate is validated on the reference Mac through:

- browser engine load;
- Protect;
- SBX1 envelope magic + public header `format: SBX`;
- public info;
- wrong-code rejection;
- tamper rejection;
- Unlock with byte equality;
- browser Blob boundary;
- `SAFEBOX_WEB_BROWSER_E2E_PASS`;
- `SAFEBOX_WEB_BROWSER_PRODUCTION_GATE_PASS`.

## R81 scope

R81 does not modify the cryptographic core, SBX format, WASM runtime, Web cryptographic engine, browser E2E logic, desktop native runtime, iOS Ads bridge or iOS Share runtime.

It closes the deployment boundary:

1. production HSTS policy in `_headers`;
2. deterministic static deploy ZIP built only from validated `dist/`;
3. SHA-256 deployment manifest;
4. fail-closed deploy tree allowlist and high-confidence secret/source-map/key rejection;
5. source-level network egress audit: exactly one `fetch`, the same-origin WASM GET;
6. remote HTTPS deployment audit comparing public bytes to local validated `dist/`;
7. remote CSP/security header/HSTS checks;
8. remote WASM MIME + immutable cache checks;
9. source leak probes for Cargo/source/.env/.git paths;
10. explicit hosting decision: GitHub Pages is not production-approved because SafeBox requires response-header control; `_headers` capable hosts such as Cloudflare Pages / Netlify are suitable candidates.

## New release commands

```bash
npm run web:release-gate
SAFEBOX_WEB_PUBLIC_URL=https://YOUR-HOST npm run web:remote-audit
```

`web:release-gate` performs the already validated production/browser gate, deployment source policy checks, then emits a deterministic deployment ZIP and manifest under `../release/`.

## Security claims bounded

- R81 does **not** claim a public host has been deployed yet.
- `SAFEBOX_WEB_REMOTE_DEPLOYMENT_AUDIT_PASS` can only be produced against an actual HTTPS URL.
- HSTS is validated only at the real HTTPS response boundary.
- No user file/code upload path is added.
- No analytics, third-party scripts, CDN crypto, remote fonts, service workers or network fallback are added.
