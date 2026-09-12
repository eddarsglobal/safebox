# SafeBox v0.2.2C Android Auto-Init R13

## Trigger
R12 passed all gates and successfully cold-booted `Pixel_9_Pro_XL_API_35`, but `tauri android dev` then stopped because a freshly extracted checkpoint does not contain the generated `src-tauri/gen/android` Android Studio project.

## Fix
- `android:cold-dev` now guarantees the Android Studio project exists before device orchestration.
- If `src-tauri/gen/android` is absent, SafeBox runs `npx tauri android init` automatically.
- If a partial/incomplete generated project exists, it is removed and regenerated.
- If the generated project is valid, it is reused without reinitializing.
- If Tauri CLI dependencies are absent, the launcher performs locked `npm ci` first.
- R12 duplicate-AVD/cold-boot protections remain unchanged.
- R9 cryptography and Android document-I/O behavior remain unchanged.

## Packaging policy
`node_modules` and generated Android build output are not part of release checkpoints. They are reconstructed from pinned lockfiles/configuration on the target development machine.

## Council gate
Platform/Build/QA decision: generated platform projects must be reproducible and automatically recoverable from a clean source checkpoint. A user should not need to remember a hidden `android init` prerequisite after each extraction.
