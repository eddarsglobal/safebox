# SAFEBOX v0.2.9 — Immersive Motion Boost — R83

Date: 2026-08-31
Baseline: SAFEBOX v0.2.9 R82 RC2, reference-Mac release gate PASS

## 9-council decision

The nine councils approve a motion-density upgrade under three non-negotiable visual rules:

1. Hero, Promise and Downloads are scroll-driven motion scopes. The section node and every descendant node participate in motion through translation, rotation and scale variables, while reduced-motion remains respected.
2. The crypto story must communicate universal file support rather than a closed list. Large file cards are supplemented by an extension-depth cloud spanning documents, media, code, archives, databases, installers and 3D/CAD formats. Font sizes intentionally range from 52px down to 1px to create depth.
3. The public site palette is aligned to the SafeBox logo: deep navy, cobalt, electric blue and light cyan contrasts in Dark, Light and System modes.

## Motion boost

- Hero: ambient blue fields, copy, title, paragraphs, buttons, orbit, SBX core and format chips all respond to scroll.
- Promise: copy, badges, shield layers and ring respond to scroll.
- Downloads: title, grid, each card and each child label/badge respond to scroll.
- Crypto story: 28 scroll-controlled glyph columns, increased glyph density and 3D depth.
- Extension cloud: 70+ extension tokens converge into the crypto reactor during scroll.
- Existing PDF/MP4/EXE/ZIP/JPG examples expanded with DOCX/APK/SQL cards while the cloud explicitly communicates broader support.
- Mobile layouts retain the same story with reduced card density, not a static fallback.

## Security invariants

- R81 validated crypto runtime remains unchanged.
- Ads remain disabled by default.
- No new network egress surface is introduced.
- Reduced-motion fallback remains available.

## Reference-Mac gate

Run:

```bash
cd safebox-desktop
npm ci
npm run web:release-gate
```

Expected additional markers:

- `SAFEBOX_LANDING_ALL_DESCENDANTS_SCROLL_MOTION_PASS`
- `SAFEBOX_LANDING_ANY_EXTENSION_DEPTH_CLOUD_PASS`
- `SAFEBOX_LANDING_SAFEBOX_BLUE_PALETTE_PASS`
- `SAFEBOX_WEB_DEPLOYMENT_READINESS_R83_PASS`
- `SAFEBOX_WEB_DEPLOY_BUNDLE_PASS`
