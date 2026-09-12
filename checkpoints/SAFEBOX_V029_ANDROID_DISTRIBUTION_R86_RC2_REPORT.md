# SAFEBOX v0.2.9 — Android Distribution R86 RC2

R86 RC2 fixes the Play upload-key setup failure observed on the reference Mac.

Cause:
- `keytool` was launched without `-dname`, so it entered its interactive X.500 identity questionnaire.
- pressing Return at the final confirmation uses the default `non`, restarting the questionnaire until keytool aborts after too many attempts.

Fix:
- fixed explicit X.500 identity for the SAFEBOX upload key: `Mr Eddars Noureddine / EDDARS Studio / Zurich / CH`;
- password is entered once + confirmation in the SafeBox script;
- keytool receives the password via `-storepass:env` / `-keypass:env` and no longer asks the identity questionnaire;
- empty interrupted keystore artifacts are safely removed;
- an existing non-empty key is never deleted automatically;
- existing key/password/alias are verified before Gradle signing configuration is written.

No crypto runtime or Android product behavior is modified.
