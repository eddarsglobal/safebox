# SAFEBOX v0.2.7 — iOS Ads Runtime Session R42

## Reference-Mac evidence
R41 reached `BUILD SUCCEEDED`, `SAFEBOX_IOS_DIRECT_SIMULATOR_BUILD_PASS`, simulator install PASS and `SAFEBOX_IOS_RUNTIME_BOOT_PASS`. A later `npm run ios:ads-check` showed repeated `SAFEBOX_IOS_BANNER_LOAD_PASS` events but failed on missing `SAFEBOX_IOS_UMP_UPDATE_BEGIN` because the checker used `log show --last 10m`.

The banner refreshes after startup, while UMP update and GMA initialization are one-shot bootstrap events. Therefore a rolling ten-minute window can discard the privacy/bootstrap evidence while retaining later banner refreshes.

## R42 correction
- `ios_simulator_run.sh` records the exact runtime-session launch boundary, simulator UDID, bundle id, process name and PID in a mode-0600 JSON file under `/tmp`.
- No SBX metadata, filenames, secrets, codes, crypto state or ad identifiers are recorded.
- `ios_ads_runtime_check.sh` scopes Apple unified logs from that recorded launch boundary and to the SafeBox process.
- The gate verifies ordering, not just presence: `UMP_UPDATE_BEGIN` -> `GMA_INIT_PASS` -> `BANNER_LOAD_PASS`.
- The obsolete rolling `--last 10m` window is removed.
- Current-session evidence is required; stale evidence is rejected by the launch boundary.

## Security / product boundary
No change to SafeBox crypto, SBX format, file handling, AdMob SDK pins, UMP consent logic, GMA link scope, or the R41 iOS binary path.

## Defensive HACKER / Red Team
Fail-closed cases cover missing/corrupt session metadata, non-booted recorded simulator, missing UMP/GMA/banner markers, and invalid ordering.

## Internal 9-council review
Approved as a verifier-integrity correction. Runtime PASS must remain tied to the current launch session and privacy-before-ads ordering.
