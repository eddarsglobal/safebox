# SAFEBOX v0.2.9 — Android Distribution R86 RC5

RC5 closes the Tauri Android Gradle BuildTask launcher regression where a generated task could execute `node tauri ...`, causing Node to search for `src-tauri/tauri` and fail with `MODULE_NOT_FOUND`.

## Decision
- Android init runs under npm context.
- Generated BuildTask is fail-closed patched to npm package-script invocation.
- Permanent Play upload keystore is untouched.
- Crypto/runtime source is untouched.
