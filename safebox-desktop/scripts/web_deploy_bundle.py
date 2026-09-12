#!/usr/bin/env python3
from __future__ import annotations
from pathlib import Path
import hashlib
import json
import re
import shutil
import stat
import zipfile

D = Path(__file__).resolve().parents[1]
ROOT = D.parent
DIST = D / "dist"
RELEASE = ROOT / "release"
PACKAGE_ID_FILE = ROOT / "SAFEBOX_V029_PACKAGE_ID.txt"

TEXT_SUFFIXES = {".html", ".js", ".css", ".svg", ".txt", ".json", ".webmanifest"}
ALLOWED_ROOT_NAMES = {
    "index.html",
    "app.html",
    "_headers",
    "safebox-logo.png",
    "safebox-logo-clean-placeholder.svg",
    "ads-config.json",
    "manifest.webmanifest",
}
ALLOWED_LEGAL_NAMES = {"legal.html", "privacy.html", "terms.html", "cookies.html", "licenses.html", "legal.css", "legal.js", "legal-theme-init.js"}
FORBIDDEN_SUFFIXES = {".map", ".pem", ".key", ".p12", ".pfx", ".mobileprovision", ".env"}
SECRET_MARKERS = (
    "-----BEGIN PRIVATE KEY-----",
    "-----BEGIN RSA PRIVATE KEY-----",
    "AWS_SECRET_ACCESS_KEY=",
    "OPENAI_API_KEY=",
    "GITHUB_TOKEN=",
)


def fail(msg: str) -> None:
    print(f"SAFEBOX_WEB_DEPLOY_BUNDLE_FAIL: {msg}")
    raise SystemExit(1)


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def sha256_file(path: Path) -> str:
    return sha256_bytes(path.read_bytes())


def relative_files() -> list[Path]:
    if not (DIST / "index.html").is_file():
        fail("dist/index.html missing; run npm run web:build first")
    files: list[Path] = []
    for path in sorted(DIST.rglob("*")):
        if path.is_symlink():
            fail(f"symlink forbidden in deploy tree: {path.relative_to(DIST)}")
        if not path.is_file():
            continue
        rel = path.relative_to(DIST)
        name = rel.name.lower()
        if name.startswith(".env") or path.suffix.lower() in FORBIDDEN_SUFFIXES:
            fail(f"forbidden deploy file: {rel}")
        if rel.parts[0] == "assets":
            if len(rel.parts) != 2 or path.suffix.lower() not in {".js", ".css"}:
                fail(f"unexpected asset file: {rel}")
        elif re.fullmatch(r"safebox_core\.[0-9a-f]{12}\.wasm", rel.as_posix()):
            pass
        elif rel.as_posix() in ALLOWED_ROOT_NAMES:
            pass
        elif rel.parts[0] == "legal" and len(rel.parts) == 2 and rel.name in ALLOWED_LEGAL_NAMES:
            pass
        else:
            fail(f"unexpected production file: {rel}")
        files.append(path)
    wasm = [p for p in files if re.fullmatch(r"safebox_core\.[0-9a-f]{12}\.wasm", p.relative_to(DIST).as_posix())]
    if len(wasm) != 1:
        fail(f"exactly one content-addressed WASM required, got {len(wasm)}")
    return files


def scan_secrets(files: list[Path]) -> None:
    for path in files:
        if path.suffix.lower() not in TEXT_SUFFIXES and path.name != "_headers":
            continue
        text = path.read_text(errors="replace")
        for marker in SECRET_MARKERS:
            if marker in text:
                fail(f"high-confidence secret marker found in {path.relative_to(DIST)}")
    print("SAFEBOX_WEB_DEPLOY_NO_SECRETS_PASS")


def deterministic_zip(files: list[Path], out: Path) -> None:
    out.parent.mkdir(parents=True, exist_ok=True)
    if out.exists():
        out.unlink()
    with zipfile.ZipFile(out, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as zf:
        for path in files:
            rel = path.relative_to(DIST).as_posix()
            info = zipfile.ZipInfo(rel, date_time=(1980, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = (stat.S_IFREG | 0o644) << 16
            zf.writestr(info, path.read_bytes())


def main() -> None:
    if not PACKAGE_ID_FILE.is_file():
        fail("package id missing")
    package_id = PACKAGE_ID_FILE.read_text().strip()
    if package_id != "SAFEBOX v0.2.9 R85 — cinematic trust design crypto story":
        fail(f"unexpected package id: {package_id}")

    files = relative_files()
    print("SAFEBOX_WEB_DEPLOY_TREE_AUDIT_PASS")
    scan_secrets(files)

    entries = []
    for path in files:
        rel = path.relative_to(DIST).as_posix()
        entries.append({"path": rel, "sha256": sha256_file(path), "bytes": path.stat().st_size})
    wasm = next(e for e in entries if re.fullmatch(r"safebox_core\.[0-9a-f]{12}\.wasm", e["path"]))
    manifest = {
        "schema": 1,
        "package_id": package_id,
        "deployment_root": "dist",
        "wasm": wasm,
        "files": entries,
    }

    RELEASE.mkdir(parents=True, exist_ok=True)
    stem = "safebox_v0.2.9_web_deploy_R86_RC8_UNIFIED_PREFS_I18N_DESIGN"
    zip_path = RELEASE / f"{stem}.zip"
    manifest_path = RELEASE / f"{stem}.manifest.json"
    sha_path = RELEASE / f"{stem}.sha256"

    deterministic_zip(files, zip_path)
    manifest_path.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n")
    digest = sha256_file(zip_path)
    sha_path.write_text(f"{digest}  {zip_path.name}\n")

    # Re-open exact artifact and ensure every member is the validated byte stream.
    with zipfile.ZipFile(zip_path, "r") as zf:
        names = zf.namelist()
        expected = [p.relative_to(DIST).as_posix() for p in files]
        if names != expected:
            fail("deploy ZIP member ordering/content mismatch")
        for path in files:
            rel = path.relative_to(DIST).as_posix()
            if zf.read(rel) != path.read_bytes():
                fail(f"deploy ZIP bytes mismatch: {rel}")

    print("SAFEBOX_WEB_DEPLOY_MANIFEST_PASS")
    print(f"SAFEBOX_WEB_DEPLOY_ARCHIVE_PASS path={zip_path} sha256={digest}")
    print("SAFEBOX_WEB_DEPLOY_BUNDLE_PASS")


if __name__ == "__main__":
    main()
