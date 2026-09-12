# SAFEBOX v0.2.9 R85 — Cinematic Trust Design & Crypto Story

## Nine-council decision

R84 is retained as the validated functional baseline, but the public landing design is not frozen. The councils classify the visible empty-scroll area, missed `.SBX` finale, content collisions and prototype-like download cards as public trust blockers.

## Council directives implemented

1. Product / trust: the landing must explain `ANY FILE -> LOCAL CRYPTO -> ONE .SBX` without requiring paragraph reading.
2. Design / UI-UX: replace generic SaaS cards with a SafeBox-native blue vault visual language, layered depth, precise spacing and stronger hierarchy.
3. Motion: use a three-act scroll narrative with persistent finale rather than decorative random motion.
4. Accessibility: preserve reduced-motion and keep essential CTA/text legible while decorative objects move more aggressively.
5. Security truth: visual labels now reflect the actual validated family (`XChaCha20`, `Argon2`, AEAD) instead of the inaccurate `AES` label. No cryptographic primitive was changed.
6. Responsive: downloads use collision-free grid geometry; text-like descendants receive micro-motion only, structural/decorative layers receive larger amplitude.
7. Advertising: when advertising is disabled, the landing reserves zero ad space.
8. Distribution / creator identity: footer links directly to `https://x.com/EddarsStudio`.
9. Release governance: R81 crypto/runtime byte hashes remain immutable and R85 deployment/version checks are aligned.

## R85 visual behavior

- Hero: animated SafeBox vault aperture, multi-ring depth, floating format chips and `.SBX` core.
- Crypto story: input extensions converge, local cryptographic field intensifies, then a central `.SBX` container becomes the held final state for the last act.
- Story length: viewport-relative (`270svh`, reduced on mobile), removing the legacy fixed 3600 px dead-scroll zone.
- Extension cloud: mixed sizes from 52 px down to 1 px to communicate broad file-type coverage and depth.
- Promise: local-device boundary visualization with cloud explicitly outside the protected flow.
- Downloads: device visual + copy are isolated into separate grid regions to prevent text/button overlap.

## Required Mac validation

```bash
bash verification/verify_v029_cinematic_trust_design_r85.sh
cd safebox-desktop
npm ci
npm run web:release-gate
```

Do not publish R85 until both the automated gate and a real-browser visual review pass.
