# SAFEBOX v0.2.8 — iOS Cold-Start Intake Closure R57

## Baseline
R52 is the validated Share Extension baseline. R53 private cold-open capture remains present. R56 provides an exact generated and installed `.sbx` LaunchServices registration.

## Reference-Mac finding after R56
The R56 document registration contract is no longer the blocker, but a simple tap on a `.sbx` in Files did not launch SafeBox. This is consistent with iOS Files being allowed to route a custom data file to Quick Look / Preview. A plain document-type declaration does not turn a Tauri application into a full UIKit document-based app.

## R57 decision
Do not replace Tauri's root UIKit controller with `UIDocumentBrowserViewController` / `UIDocumentViewController` solely to force simple-tap behavior. That would be an invasive architecture change and would add a second UI lifecycle to the validated Tauri/Ads/Share stack.

R57 separates two supported contracts:

1. `Open With -> SafeBox`: keeps R53/R56 as the direct document-handler cold-start path when Files explicitly dispatches the document to SafeBox.
2. `Share -> SafeBox` while the containing app is terminated, then launch SafeBox once: uses the already validated native Share Extension and App Group. On setup, Rust invokes the registered native drain and routes `.sbx` to Unlock. This is now a dedicated cold-start runtime gate.

A simple Files tap/preview is therefore diagnostic only and is no longer classified as a SafeBox failure.

## New runtime commands
- `npm run ios:cold-share-arm -- unlock`
- while SafeBox is terminated: Files -> Share -> SafeBox -> Done -> launch SafeBox once
- `npm run ios:cold-share-check`

Final marker: `SAFEBOX_IOS_COLD_SHARE_RUNTIME_PASS`.

## Security / regressions
No changes to crypto, SBX format, Ads/UMP, Share Extension staging, App Group identifier, provider-file deletion rules, permissions, or file-protection policy. R57 changes only test/orchestration semantics around iOS cold-start intake.
