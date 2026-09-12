# SafeBox v0.2.9 — Web RC7.2 Deployment Gate Closure

## Scope

RC7.2 is a validation-only closure for the Web RC7.1 release candidate.

The previous `web_deployment_check.py` still pinned the historical R81 hash of `safebox-desktop/src/main.ts`, while RC7 intentionally changed `src/main.ts` for Android picker/MIME/save-path corrections. The Web browser E2E and experience gates already passed with the RC7 source.

## Fix

- `scripts/web_deployment_check.py` now pins the validated RC7 `src/main.ts` SHA-256:
  `3b7408aad7f8c7d163589a8318a4ce156b324330784a9567cc2945f1ca489e16`
- No crypto source was changed.
- No landing/light/legal source was changed from RC7.1.
- No deployment policy was relaxed; the runtime hash check remains fail-closed.

## Expected markers

- `SAFEBOX_WEB_RC7_2_MAIN_RUNTIME_HASH_PASS`
- `SAFEBOX_WEB_DEPLOYMENT_READINESS_R85_PASS`
- `SAFEBOX_WEB_RC7_2_DEPLOYMENT_GATE_PASS`

