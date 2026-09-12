# SafeBox v0.2.2d — Android Verifier Closure R27

## Scope
Verifier-only compatibility closure. No SafeBox crypto, SBX format, UI, Android runtime, Share/Open, or product behavior changes from R26.

## Finding from Mac R26 run
R26 passed the R17 semantic icon compatibility gate and progressed through the historical chain until R13 printed `[1/5] Android auto-init invariants`, then exited. The cause was a historical literal assertion requiring `npx tauri android init`, while the hardened R25/R26 runtime correctly invokes the locked local CLI at `node_modules/.bin/tauri`.

## Changes
- R13 auto-init verifier now checks the required semantics rather than one historical command spelling.
- R9 Android CLI readiness now invokes `./node_modules/.bin/tauri info` after its clean `npm ci`, removing the remaining active Android verifier use of `npx tauri`.
- New R27 gate verifies both compatibility fixes, then replays the complete R26 baseline.

## 9-council decision
Security, Defensive HACKER, Android Platform, QA, Release Engineering, Privacy, UI, Desktop, and Cross-platform councils approve this as verifier maintenance only. The hardened local-toolchain policy remains authoritative; old verifiers must adapt to current secure behavior, never force runtime regression.

## Expected marker
`SAFEBOX_V022D_ANDROID_VERIFIER_CLOSURE_R27_VERIFY_PASS`
