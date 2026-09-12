# SafeBox v0.2.6 — iOS Runtime Bootstrap R32

Status: **runtime bootstrap checkpoint — iPhone Simulator launch proof required**.

## Problem fixed

R31 correctly reached `tauri ios init`, but Tauri's Apple dependency helper prompted to update an already-installed Homebrew dependency (`xcodegen`). This made `npm run ios:cold-dev` interactive and blocked deterministic automation.

R32 forces Tauri CLI `CI=true` for the iOS cold-dev session. Per Tauri CLI semantics, CI mode disables user interaction. SafeBox does **not** automatically upgrade, reinstall, or mutate XcodeGen/CocoaPods/libimobiledevice/Homebrew packages during a normal launch.

## Added runtime evidence helper

`npm run ios:runtime-status` checks that an iPhone Simulator is booted and that `com.safebox.desktop` is actually installed. It does not modify simulator data.

## Security invariants

No change to Argon2id, XChaCha20-Poly1305, SBX parsing/format, private staging, security-scoped access, generated-file export allow-list, or Android v0.2.4 behavior.

## 9-council checkpoint review

1. **Crypto/Security — GREEN:** no crypto or SBX change.
2. **Defensive HACKER / Red Team — GREEN for this slice:** normal dev launch cannot silently mutate host package-manager dependencies; CI mode removes unexpected interactive branch behavior.
3. **iOS Platform — YELLOW-GREEN:** bootstrap blocker removed; actual simulator install/launch still needs Mac evidence.
4. **Android Platform — GREEN/FROZEN:** no intentional Android changes.
5. **Design/UI — GREEN/FROZEN:** R29 eye controls and footer Settings unchanged.
6. **Privacy — GREEN:** no new network/upload behavior.
7. **QA — YELLOW:** runtime-status evidence helper added; real launch still required.
8. **Release/Supply Chain — GREEN for this slice:** pinned local Tauri CLI remains used; Homebrew auto-upgrades are not performed by SafeBox launch tooling.
9. **Interoperability/Product — YELLOW:** iOS E2E Files round-trip remains the next gate.

**Council decision:** R32 removes the deterministic-launch blocker. Do not mark iOS DONE until simulator Files → Create → Save → Open-In → wrong/right code → restore byte identity passes.
