#!/usr/bin/env python3
import os
import plistlib
import stat
import sys
import tempfile
from copy import deepcopy
from pathlib import Path

DOC_KEY = "CFBundleDocumentTypes"
UTI_KEY = "UTExportedTypeDeclarations"


def fail(message: str) -> None:
    print(f"SAFEBOX_IOS_COLD_OPEN_GENERATED_REGISTRATION_PATCH_FAIL: {message}", file=sys.stderr)
    raise SystemExit(1)


def load(path: Path):
    try:
        with path.open("rb") as fh:
            value = plistlib.load(fh)
    except Exception as exc:
        fail(f"cannot parse plist: {exc}")
    if not isinstance(value, dict):
        fail("plist root must be a dictionary")
    return value


def main() -> None:
    if len(sys.argv) != 3:
        fail("usage: patcher CANONICAL_REGISTRATION.plist GENERATED_Info.plist")
    canonical_path = Path(sys.argv[1])
    target_path = Path(sys.argv[2])
    if not canonical_path.is_file():
        fail("canonical registration plist missing")
    if not target_path.is_file():
        fail("generated Info.plist missing")

    canonical = load(canonical_path)
    target = load(target_path)
    if set(canonical.keys()) != {DOC_KEY, UTI_KEY}:
        fail("canonical registration must contain only document and exported-UTI keys")
    if not isinstance(canonical[DOC_KEY], list) or len(canonical[DOC_KEY]) != 1:
        fail("canonical document registration must contain exactly one entry")
    if not isinstance(canonical[UTI_KEY], list) or len(canonical[UTI_KEY]) != 1:
        fail("canonical exported UTI must contain exactly one entry")

    # Authoritative replacement: any Tauri/legacy declaration is removed first.
    target.pop(DOC_KEY, None)
    target.pop(UTI_KEY, None)
    target[DOC_KEY] = deepcopy(canonical[DOC_KEY])
    target[UTI_KEY] = deepcopy(canonical[UTI_KEY])

    mode = stat.S_IMODE(target_path.stat().st_mode)
    fd, tmp_name = tempfile.mkstemp(prefix=f".{target_path.name}.safebox-r56-", dir=str(target_path.parent))
    try:
        with os.fdopen(fd, "wb") as fh:
            plistlib.dump(target, fh, fmt=plistlib.FMT_XML, sort_keys=False)
            fh.flush()
            os.fsync(fh.fileno())
        os.chmod(tmp_name, mode)
        os.replace(tmp_name, target_path)
    finally:
        try:
            os.unlink(tmp_name)
        except FileNotFoundError:
            pass

    print("SAFEBOX_IOS_COLD_OPEN_GENERATED_REGISTRATION_PATCH_PASS")


if __name__ == "__main__":
    main()
