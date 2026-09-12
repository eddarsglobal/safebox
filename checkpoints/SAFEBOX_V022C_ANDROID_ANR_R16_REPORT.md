# SafeBox v0.2.2C Android ANR R16

## Scope
Verification-only correction on top of R15. No crypto, SBX format, UI behavior, or Android runtime logic changed.

## Fix
The legacy R14 verifier required a statement-level `#[cfg(desktop)]` block immediately around `window.unminimize()`. R15 correctly strengthened this to function-level platform separation:

- `#[cfg(desktop)] fn focus_main_window(...)` owns `show / unminimize / set_focus`.
- `#[cfg(mobile)] fn focus_main_window(...)` is a no-op mobile stub.

R16 updates the verifier to validate the platform semantics rather than one obsolete source-code shape. It also rejects any `unminimize()` leakage into the mobile section.

## Security / Councils gate
- Platform Council: PASS by construction; desktop-only API isolated from mobile target.
- Defensive Hacker Council: verifier rejects mobile leakage of `unminimize`.
- Crypto/SBX: unchanged from R15/R14 baseline.
