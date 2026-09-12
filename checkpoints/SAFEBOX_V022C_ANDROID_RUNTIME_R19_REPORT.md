# SafeBox v0.2.2C — Android Runtime R19

## Scope

- Fixes the R17 checkpoint-hygiene verifier ordering bug: archive cleanliness is now checked before nested baseline gates run `npm ci`.
- Keeps the R18 UI clarity changes unchanged.
- Marks `run_system_command` desktop-only so Android no longer emits SafeBox's own dead-code warning for that helper.
- No crypto-format or SBX semantics changes.

## Evidence expected on reference Mac

`SAFEBOX_V022C_ANDROID_RUNTIME_R19_VERIFY_PASS`

Then run `npm run android:cold-dev` and confirm stable runtime / no repeated ANR.
