#!/usr/bin/env python3
import plistlib
import sys
from pathlib import Path

UTI = "com.safebox.desktop.sbx"
MIME = "application/x-safebox"


def fail(message: str) -> None:
    print(f"SAFEBOX_IOS_COLD_OPEN_DOCUMENT_CONTRACT_FAIL: {message}", file=sys.stderr)
    raise SystemExit(1)


def as_list(value):
    if value is None:
        return []
    if isinstance(value, list):
        return value
    return [value]


def main() -> None:
    if len(sys.argv) != 2:
        fail("expected Info.plist path")
    path = Path(sys.argv[1])
    if not path.is_file():
        fail("Info.plist missing")
    try:
        with path.open("rb") as fh:
            info = plistlib.load(fh)
    except Exception as exc:
        fail(f"cannot parse Info.plist: {exc}")

    docs = as_list(info.get("CFBundleDocumentTypes"))
    sbx_docs = []
    for index, doc in enumerate(docs):
        if not isinstance(doc, dict):
            continue
        exts = [str(x).lower() for x in as_list(doc.get("CFBundleTypeExtensions"))]
        utis = [str(x) for x in as_list(doc.get("LSItemContentTypes"))]
        if "sbx" in exts or UTI in utis:
            sbx_docs.append((index, doc))

    if len(sbx_docs) != 1:
        fail(f"expected exactly one SBX document registration, found {len(sbx_docs)}")

    index, doc = sbx_docs[0]
    exts = [str(x).lower() for x in as_list(doc.get("CFBundleTypeExtensions"))]
    utis = [str(x) for x in as_list(doc.get("LSItemContentTypes"))]
    if doc.get("CFBundleTypeRole") != "Editor":
        fail(f"SBX document role is {doc.get('CFBundleTypeRole')!r}, expected 'Editor'")
    if doc.get("LSHandlerRank") != "Owner":
        fail(f"SBX handler rank is {doc.get('LSHandlerRank')!r}, expected 'Owner'")
    if "sbx" not in exts:
        fail("SBX filename-extension mapping missing")
    if UTI not in utis:
        fail("SBX LSItemContentTypes mapping missing")

    exports = as_list(info.get("UTExportedTypeDeclarations"))
    sbx_exports = [x for x in exports if isinstance(x, dict) and x.get("UTTypeIdentifier") == UTI]
    if len(sbx_exports) != 1:
        fail(f"expected exactly one exported SBX UTI, found {len(sbx_exports)}")
    exported = sbx_exports[0]
    conforms = [str(x) for x in as_list(exported.get("UTTypeConformsTo"))]
    if conforms != ["public.data"]:
        fail(f"SBX conformance must be exactly ['public.data'], got {conforms!r}")
    tags = exported.get("UTTypeTagSpecification")
    if not isinstance(tags, dict):
        fail("SBX UTI tag specification missing")
    mime = tags.get("public.mime-type")
    if mime != MIME:
        fail(f"SBX MIME is {mime!r}, expected {MIME!r}")
    tag_exts = [str(x).lower() for x in as_list(tags.get("public.filename-extension"))]
    if "sbx" not in tag_exts:
        fail("SBX exported UTI filename-extension tag missing")

    print(f"SAFEBOX_IOS_COLD_OPEN_DOCUMENT_REGISTRATION_INDEX: {index}")
    print("SAFEBOX_IOS_COLD_OPEN_DOCUMENT_REGISTRATION_COUNT: 1")
    print("SAFEBOX_IOS_COLD_OPEN_EXPORTED_UTI_COUNT: 1")
    print("SAFEBOX_IOS_COLD_OPEN_DOCUMENT_CONTRACT_PASS")


if __name__ == "__main__":
    main()
