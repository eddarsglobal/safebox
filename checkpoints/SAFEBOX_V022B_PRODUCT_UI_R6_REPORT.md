# SafeBox v0.2.2B — Product/UI Decisions R6

Implemented:
- `Keep SBX after unlock` wording, default enabled in Create and manual Unlock.
- Receiver flows now request retention by default.
- Core Create/Unlock retention defaults changed to non-destructive (`burn_after_unlock = false`).
- Explicit burn transaction test retained by setting burn policy to true in that test.
- New default-retention roundtrip test added.
- Visible SBX name now follows the original file basename until the user edits it.
- `Auto` / `Custom` UI state added.
- Obsolete global default SBX-name field removed from active Settings UI.
- Unicode-aware visible-name sanitization aligned with cross-platform filename constraints.
- Design polish: trust chips, naming hint/state, retention policy surface, light-mode variants.

Verification target:
`bash verification/verify_v022b_product_ui_r6.sh`
