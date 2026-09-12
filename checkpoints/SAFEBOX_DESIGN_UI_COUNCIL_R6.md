# SafeBox — Design/UI Council R6

## Product decisions adopted

1. **Retention is conservative by default** — “Keep SBX after unlock” is enabled by default in Create and Unlock. Destructive local removal becomes an explicit user choice.
2. **Per-file naming** — a new SBX inherits the original file basename by default (`photo.png` → `photo.sbx`). The user can edit the visible SBX name before creation.
3. **No global default filename in Settings** — it conflicts with per-file automatic naming and is removed from the active UI.
4. **Visible naming state** — the Create UI shows `Auto` while the name tracks the source file and `Custom` after the user changes it.

## Design council — priorities

### P0 — clarity and trust
- One primary action per screen: Create / Unlock.
- Critical policies must use plain language; remove “for tests only” from end-user UI.
- Keep security claims factual: local encryption/decryption, offline-capable workflow.
- Never make destructive behavior the silent default.

### P1 — premium visual system
- Strong hierarchy: brand → task title → file → code → action.
- Compact trust chips instead of explanatory paragraphs.
- Consistent rounded geometry, spacing rhythm, field heights, focus rings and modal surfaces.
- `Auto` / `Custom` naming status communicates application state without extra dialogs.
- Settings remains a utility action at the right edge of the header on desktop and mobile.

### P1 — mobile-first
- File picker / share / save are primary mobile interactions; folder pickers stay desktop-only.
- Large tap targets and safe-area aware footer space.
- Advertising, when implemented, gets a reserved footer surface separated from Create/Unlock controls to prevent accidental clicks.

### P1 — accessibility
- Keyboard/focus path remains deterministic.
- Theme contrast must pass in System/Light/Dark.
- RTL and Unicode filenames are first-class.
- Reduced-motion support should be added before external beta.

## Next design development

- Replace remaining hotfix-driven modal/layout code with owned controllers.
- Introduce a small design-token layer for spacing/radius/type scale.
- Add mobile bottom action layout and future AdMob footer slot.
- Final accessibility pass for focus trap, Escape, ARIA labels and reduced motion.
