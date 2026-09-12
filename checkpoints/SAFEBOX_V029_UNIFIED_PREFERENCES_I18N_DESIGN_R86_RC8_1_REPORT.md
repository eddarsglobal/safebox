# SAFEBOX v0.2.9 R86 RC8.1

Scope: gate-only correction after Mac web release execution.

The RC8 landing finale is intentionally translated via `resultLocal`, `resultEncrypted`, and `resultPortable`. The legacy web experience gate still required the former hard-coded English literal `LOCAL · ENCRYPTED · PORTABLE`, producing a false failure after the browser E2E had passed.

RC8.1 changes only `safebox-desktop/scripts/web_experience_check.py` so the gate validates the translated finale tokens and their `data-i` bindings instead of requiring one English-only literal.

No application runtime, crypto core, WASM engine, Android native runtime, landing UI behavior, legal pages, or translations were changed.
