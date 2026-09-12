# SafeBox v0.2.2D — Android Share/Open R22

## Scope
Verification-only source correction on top of R21.

## Change
- Reformatted `get_initial_sbx_path()` to the exact `rustfmt` layout reported by the macOS gate.
- Added a dedicated R22 regression invariant before the full R21 gate.

## Security / behavior
- No cryptographic change.
- No SBX format change.
- No Android intent/share/open semantic change.
- No UI change.
- R20 supply-chain pin remains unchanged.

## Expected final marker
`SAFEBOX_V022D_ANDROID_SHARE_OPEN_R22_VERIFY_PASS`
