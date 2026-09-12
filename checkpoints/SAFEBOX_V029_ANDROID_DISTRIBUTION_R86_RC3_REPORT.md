# SAFEBOX v0.2.9 — Android Distribution R86 RC3

R86 RC3 fixes the Gradle Kotlin DSL compilation failure observed after the RC2 signing key was successfully created.

Observed failure:
- `build.gradle.kts:33:20: Unresolved reference: FileInputStream`.

Root cause:
- RC2 conditionally added both Java imports only when `import java.util.Properties` was absent.
- a generated Tauri Gradle file can already expose `Properties` while still lacking `FileInputStream`, so the signing block failed to compile.

Fix:
- use fully qualified `java.util.Properties()` and `java.io.FileInputStream(f)`;
- self-heal an existing R86/RC2 generated signing block;
- verify both Java type qualifications before declaring signing configuration PASS;
- reuse the already-created permanent Play upload keystore; never regenerate or delete it.

No SAFEBOX cryptographic runtime behavior is modified.
