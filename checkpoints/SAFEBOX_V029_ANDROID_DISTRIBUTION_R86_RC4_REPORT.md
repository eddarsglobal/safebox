# SAFEBOX v0.2.9 — Android Distribution R86 RC4

R86 RC4 fixes the Gradle Kotlin DSL failure observed after RC3.

Observed failure:
- `Unresolved reference: util` on `java.util.Properties()`;
- `Unresolved reference: io` on `java.io.FileInputStream(f)`.

Root cause:
- inside the Android Gradle Kotlin DSL receiver, `java` can resolve to the Gradle/Android DSL `java` extension instead of the JVM package root;
- therefore fully qualifying the Java classes inside the `android { ... }` receiver is not safe in this generated script.

Fix:
- prepend explicit alias imports at script scope:
  - `import java.util.Properties as SafeBoxProperties`;
  - `import java.io.FileInputStream as SafeBoxFileInputStream`;
- use only those aliases inside the signing block;
- provide an in-place hotfix for an already-generated RC3 Gradle project, preserving the compiled Rust artifacts and permanent Play upload key;
- keep the permanent upload keystore unchanged.

No SAFEBOX cryptographic runtime behavior is modified.
