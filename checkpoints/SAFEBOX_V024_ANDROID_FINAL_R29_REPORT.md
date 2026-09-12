# SafeBox v0.2.4 — Android Finalization R29

## Status

**ANDROID CORE FLOW: DONE**

R29 freezes the Android v0.2.4 baseline after the successful R28 end-to-end proof. The revised final UI also closes two explicit product requirements: **Password visibility** uses an eye icon for Show/Hide on the important code fields, and **Footer Settings** replaces the text SETTINGS action in the app header with a single gear icon in the app footer. These are presentation/input-visibility changes only; R29 does not change SBX format, cryptography, Create/Unlock semantics, Android document I/O, retention semantics, or the Android runtime.


## Final R29 UI requirements

- **Password visibility:** Create code, Unlock code, receiver code, Global code, Access Profile code and hard receiver code expose a compact eye icon. The eye toggles only the HTML input visibility (`password`/`text`) and never changes, persists, logs or transmits the secret.
- **Footer Settings:** the word `SETTINGS` is removed from the app header. Settings is opened from one gear-only button in the footer. The control keeps an accessible label/title even though no visible word is rendered.
- Password-eye and Settings controls keep keyboard focus styling and mobile-safe sizing.

## Runtime evidence accepted for closure

The Android emulator E2E session validated:

- R28 fixture generation and import into Android Downloads.
- Unicode filename fixture import.
- PNG, PDF, text and 64 MiB binary fixture import.
- SHA-256 verified Mac -> Android fixture transfer.
- 60-second foreground idle gate with `SAFEBOX_ANDROID_E2E_IDLE_PASS`.
- Runtime crash/ANR scan with `SAFEBOX_ANDROID_E2E_LOG_PASS`.
- Manual Create -> Save SBX -> Open With SafeBox -> wrong-code rejection -> correct-code Unlock -> Save original flow.
- Restored PNG byte-for-byte identity with `SAFEBOX_ANDROID_COMPARE_PASS`.
- Original/restored PNG SHA-256:
  `78f6e771760e5eb03a547ebc1dc48a4ce5461ccc5c8573f56f74fb3517ba59dc`.
- Keep-SBX default remains non-destructive.

## Android DocumentsUI duplicate-name behavior

During the proof, Android saved a duplicate restored filename as:

`/sdcard/Download/SafeBox-E2E/safebox-e2e-image.png (1)`

This name is selected by the Android document provider / DocumentsUI after the user chooses a destination where the requested display name already exists. SafeBox supplies the original filename as the suggested name and writes to the URI returned by the provider. SafeBox must not silently rename or replace a provider-selected document after Save.

Therefore R29 does **not** add a risky post-save rename workaround. The important invariant is preserved: the exported bytes were verified against the private generated source before success was reported.

## 9-council closure

1. **Core/Crypto — GREEN**: roundtrip and hostile-input gates remain green.
2. **Defensive HACKER / Red Team — GREEN for Android core flow**: wrong code creates no restored output; modified ciphertext and hostile KDF cases are covered by core tests.
3. **Android Platform — GREEN**: build/install, `content://`, private staging, Save verification and Open/Share routing are implemented.
4. **Runtime/ANR — GREEN**: 60-second foreground idle test and log scan pass.
5. **Supply Chain — GREEN**: frontend audit was previously closed at zero known npm vulnerabilities with locked toolchain versions.
6. **UX/Product — GREEN for V1 Android core**: real filenames, editable SBX visible name, non-destructive Keep SBX default, explicit Create/Unlock actions.
7. **Privacy — GREEN for pre-ads Android core**: crypto flow is local and no ad SDK is present in this checkpoint.
8. **QA/Release — GREEN for Android development baseline**: R9-R28 gates plus live E2E evidence complete the core Android acceptance criteria.
9. **Cross-platform Governance — YELLOW overall**: iOS, Web/WASM and final 5x5 interoperability remain future gates.

## Next milestone

**iOS Files / security-scoped document I/O foundation.**

The Android v0.2.4 core baseline must remain frozen while iOS work begins.
