# SafeBox v0.2.2d — Android E2E Hardening R28

## Scope

R28 does not change the SBX format, cryptography, Create/Unlock semantics, retention policy, Share/Open routing, or production UI. It adds deterministic Android E2E tooling around the fully validated R27 baseline.

## Added

- `npm run android:import -- "/path/file"`
  - auto-detects the ready emulator/device;
  - pushes into `/sdcard/Download/SafeBox-E2E`;
  - verifies SHA-256 Mac vs Android after transfer.
- `npm run android:e2e-prepare`
  - creates deterministic text, Unicode-name, PDF, PNG and 64 MiB binary fixtures;
  - imports each fixture and verifies byte identity.
- `npm run android:e2e-idle`
  - starts SafeBox, clears logcat, waits 60 seconds, checks process survival and ANR/fatal signals.
- `npm run android:e2e-log`
  - post-flow crash/ANR scan.
- `npm run android:compare -- "/local/original" "/sdcard/.../restored"`
  - byte-identity proof by SHA-256.

## Security / Defensive HACKER review

- No secret is passed on a command line by the new tooling.
- Import tooling never grants SafeBox broader filesystem permissions.
- Files are imported to Android public Downloads only for test purposes; the application still receives them through the Android document/provider flow when selected.
- Hash verification detects truncated or corrupted host-to-emulator transfers before cryptographic tests begin.
- Idle/log gates fail closed on ANR/fatal evidence.
- Fixture sizes are bounded (1..512 MiB configurable, 64 MiB default).

## Council status

R28 provides the evidence harness required to close the Android v0.2.4 gate. Android is **not declared DONE solely by this source checkpoint**. The real device/emulator flow must still pass:

1. idle 60s;
2. normal file Share/Choose -> Create;
3. Save SBX;
4. Open `.sbx` -> Receiver;
5. wrong-code denial without restored output;
6. correct-code Unlock;
7. Save original;
8. SHA-256 equality;
9. retained SBX when Keep SBX is ON;
10. no ANR/crash log evidence.

After that evidence, the next platform milestone is iOS Files/security-scoped I/O, before advertising work.
