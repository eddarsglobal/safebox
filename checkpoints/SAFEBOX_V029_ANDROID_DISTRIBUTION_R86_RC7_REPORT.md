# SAFEBOX v0.2.9 — Android Distribution R86 RC7

## Release purpose
RC7 closes the four physical-device UX blockers found after the first successful RC6 round-trip: Android restored-file MIME/name semantics, SBX file association identity, light-mode contrast, and legal-page theme synchronization.

## Corrections
- Android save dialogs now provide MIME-aware filters. Images such as PNG are created as `image/png` documents, while SafeBox capsules use `application/x-safebox`.
- Android SBX association now uses the dedicated `application/x-safebox` MIME type instead of generic `application/octet-stream`, preventing restored images/binaries from being routed to SafeBox as generic octet-stream documents.
- The landing and crypto app share the canonical `safebox-theme-mode.v1` preference.
- Light mode receives explicit high-contrast surfaces, typography, pills, story rails, cards, controls, inputs and result states.
- Every legal page now follows System / Light / Dark from the same theme preference and exposes its own Appearance selector.

## Filename semantics
On Android, restored originals use a predictable collision-safe suggestion with `-restored` before the extension (for example `photo-restored.png`) instead of asking the Storage Access Framework to recreate `photo.png` beside an already-existing original. Combined with the MIME-aware save filter, the real extension stays last and Android can classify/thumbnail the restored media. SBX visible names are not rewritten.

## Android file-icon scope
The app registers a dedicated SBX MIME association and uses that MIME when exporting new `.sbx` files. Android file managers control final per-file icon rendering; RC7 provides the correct app/MIME association so compatible managers can show the SafeBox association instead of a generic octet-stream document.

## Security / crypto scope
No SBX format, KDF, AEAD, password handling, encryption, decryption, or cryptographic metadata behavior is changed.

## Acceptance
Static gates in `verification/verify_v029_android_distribution_r86_rc7.sh` must pass, followed by a fresh signed Android build and real-device verification of PNG restore preview, filename semantics, SBX open association, light-mode readability, and legal theme switching.
