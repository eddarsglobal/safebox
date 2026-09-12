# SafeBox v0.2.2C R20 — Settings cleanup & supply-chain gate

## 9-Council decision
- Remove the MVP global-code storage note from Settings.
- Keep storage semantics documented in Help/Security notes rather than permanent Settings UI.
- Replace the session-oriented password placeholder with `Enter global code`.
- Close the two npm HIGH advisories by pinning transitive `nanoid` to patched `3.3.18`.
- Preserve R19 Android runtime, R18 UI, R17 icon, R16 ANR and SBX crypto behavior unchanged.

## Security rationale
The lockfile previously resolved `nanoid` 3.3.15 through PostCSS. R20 resolves and overrides it to 3.3.18.

## Next gate
Android E2E: idle stability, Choose, Create, Save, Open, wrong-code rejection, Unlock, Save original.
