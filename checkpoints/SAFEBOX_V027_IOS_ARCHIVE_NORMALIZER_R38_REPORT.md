# SafeBox v0.2.7 — iOS archive normalizer R38

## Incident
The R37 runtime test on the reference Mac reached the Rust build but failed because Apple/Xcode 16.2 BSD `ar` rejects the LLVM/GNU `N` occurrence selector (`illegal option -- N`).

## Correction
R38 removes the toolchain-specific `xN/dN` dependency. The normalizer parses the standard Unix ar container itself, resolves BSD `#1/<len>` and GNU long-name forms, compares the two known Tauri Swift object payloads, and removes only the verified second occurrence. Divergent payloads remain fail-closed. Apple's `ranlib` rebuilds the symbol table after normalization.

## Security / scope
- Crypto/SBX files unchanged.
- No Ads data boundary change.
- No device-signing bypass.
- Only five known Tauri support members are eligible for deduplication.
- Missing, >2-copy, malformed, or non-equivalent members fail the build.

## Internal 9-council review
Architecture, iOS runtime, crypto boundary, privacy, supply chain, UI, compatibility, release engineering, and testability reviewed the change.

## Defensive HACKER / Red Team
Negative test proves a divergent duplicate is rejected. Malformed archive headers, lengths, long-name offsets, unexpected multiplicity, and missing target members are fail-closed.

## Status
Static/package verification PASS. Reference-Mac iOS simulator runtime remains REQUIRED before v0.2.7 final acceptance.
