# SafeBox v0.2.9 — Android / Google Play release

Creator credit: Mr Eddars Noureddine, Zurich, Switzerland.

## Frozen Android identity
- App name: SafeBox
- Android application ID: `com.safebox.desktop`
- Version name: `0.2.9`
- Version code: `2009`
- minSdk: 24
- compileSdk / targetSdk: 36
- Developer website: `https://safebox.pages.dev/`
- Privacy policy: `https://safebox.pages.dev/legal/privacy.html`

The application ID must not change after the first Play upload.

## Two release artifacts
- Direct distribution / GitHub Releases: `SafeBox-v0.2.9-universal.apk`
- Google Play Console: `SafeBox-v0.2.9-play.aab`

Both come from the same source and same upload key.

## Signing
The keystore is created outside the repository under `~/.safebox/android-signing/`.
Never commit or upload the keystore, `keystore.properties`, or passwords.
Back up the upload key securely.

## AdMob comes after R86 distribution proof
R87 will add Google Mobile Ads + UMP using Google's test ad IDs first. Production ad IDs are added only after AdMob configuration and privacy review. No SBX file bytes, names, plaintext, passwords, unlock codes, or cryptographic metadata may be sent to advertising SDKs.
