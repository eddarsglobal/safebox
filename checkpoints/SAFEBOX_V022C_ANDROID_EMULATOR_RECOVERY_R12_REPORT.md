# SafeBox v0.2.2C Android Emulator Recovery R12

## Trigger
R11 passed all verification gates, but `android:cold-dev` could launch a second instance of the same AVD when an emulator process survived while adb temporarily forgot it. Android then aborted with `Running multiple emulators with the same AVD`.

## Fix
- Detect target AVD identity through `adb emu avd name`.
- Reuse the exact AVD if it is already healthy and fully booted.
- Stop an incomplete/stale instance before cold boot.
- Detect orphan emulator processes by exact AVD process arguments even when adb cannot see them.
- Add a final duplicate-AVD process guard before launch.
- Keep snapshot loading/saving disabled for deterministic cold boot recovery.
- Preserve R11/R9 crypto, file-I/O and security behavior unchanged.

## Council gate
Platform/QA/Security decision: never use Android emulator `-read-only` merely to bypass an accidental duplicate. Recovery must restore a single authoritative test device so state and I/O tests remain deterministic.
