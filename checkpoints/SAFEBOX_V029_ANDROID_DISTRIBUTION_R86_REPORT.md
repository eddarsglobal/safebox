# SAFEBOX v0.2.9 — Android Distribution R86

R86 prepares one signed universal APK for direct/GitHub distribution and one signed Android App Bundle for Google Play, while preserving the validated SafeBox Android crypto flow.

Key decisions:
- preserve validated Android application ID `com.safebox.desktop`;
- Android version 0.2.9 / versionCode 2009;
- enforce Android 16 target API 36 for submissions on/after 2026-08-31;
- keep signing key outside repository;
- build APK and AAB from the same source/upload key;
- AdMob is intentionally deferred to R87 after distribution artifacts are proven.
