# SafeBox v0.2.2C — UI Clarity R18

## Decisions
- Replace the ambiguous `Overwrite original if exists` label with `Replace existing file`.
- Explain the safe default explicitly: OFF keeps both files; ON replaces the existing destination file with the restored one.
- Keep the overwrite option OFF by default.
- Add deliberate vertical separation between the File naming information card and Global sender label in Settings, including mobile.

## Scope
UI copy and spacing only. No SBX format, cryptography, retention policy, Android document I/O, ANR or launcher-icon logic changed.
