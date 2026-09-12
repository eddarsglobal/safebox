#!/usr/bin/env python3
from __future__ import annotations
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.parse import urljoin, urlparse
from urllib.request import Request, urlopen
import argparse
import hashlib
import os
import re
import ssl

D = Path(__file__).resolve().parents[1]
DIST = D / "dist"
USER_AGENT = "SafeBox-R85-Remote-Deployment-Audit/1"
REQUIRED_CSP = (
    "default-src 'self'",
    "base-uri 'none'",
    "object-src 'none'",
    "frame-ancestors 'none'",
    "form-action 'none'",
    "script-src 'self' 'wasm-unsafe-eval'",
    "connect-src 'self'",
    "worker-src 'none'",
)
LEAK_PATHS = (
    "Cargo.toml",
    "SAFEBOX_V029_PACKAGE_ID.txt",
    "SAFEBOX_V028_PACKAGE_ID.txt",
    "safebox-core/src/crypto.rs",
    ".env",
    ".git/config",
    "verification/verify_v028_web_browser_public_format_r80.sh",
)


def fail(msg: str) -> None:
    print(f"SAFEBOX_WEB_REMOTE_AUDIT_FAIL: {msg}")
    raise SystemExit(1)


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def origin(url: str) -> tuple[str, str, int | None]:
    p = urlparse(url)
    return (p.scheme.lower(), (p.hostname or "").lower(), p.port)


def get(url: str, timeout: float) -> tuple[bytes, object, str, int]:
    req = Request(url, headers={"User-Agent": USER_AGENT, "Accept": "*/*"})
    try:
        with urlopen(req, timeout=timeout, context=ssl.create_default_context()) as resp:
            return resp.read(), resp.headers, resp.geturl(), resp.status
    except HTTPError as e:
        return e.read(), e.headers, e.geturl(), e.code
    except URLError as e:
        fail(f"request failed for {url}: {e}")


def header(headers: object, name: str) -> str:
    value = headers.get(name)  # type: ignore[attr-defined]
    return value.strip() if value else ""


def require_header(headers: object, name: str, expected: str) -> None:
    actual = header(headers, name)
    if actual.lower() != expected.lower():
        fail(f"{name} mismatch: {actual!r}")


def max_age(value: str) -> int | None:
    m = re.search(r"(?:^|[,;]\s*)max-age\s*=\s*(\d+)", value, re.I)
    return int(m.group(1)) if m else None


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--url", default=os.environ.get("SAFEBOX_WEB_PUBLIC_URL", ""))
    parser.add_argument("--timeout", type=float, default=20.0)
    args = parser.parse_args()

    if not args.url:
        fail("set SAFEBOX_WEB_PUBLIC_URL=https://... or pass --url")
    supplied = args.url.strip()
    parsed = urlparse(supplied)
    if parsed.scheme.lower() != "https" or not parsed.hostname or parsed.username or parsed.password:
        fail("public URL must be credential-free HTTPS")
    if not (DIST / "index.html").is_file():
        fail("local validated dist missing; run npm run web:release-gate first")

    base = supplied if supplied.endswith("/") else supplied + "/"
    index_bytes, index_headers, final_url, status = get(base, args.timeout)
    if status != 200:
        fail(f"index returned HTTP {status}")
    if urlparse(final_url).scheme.lower() != "https":
        fail("deployment redirected away from HTTPS")
    final_base = final_url if final_url.endswith("/") else final_url.rsplit("/", 1)[0] + "/"
    final_origin = origin(final_base)
    print(f"SAFEBOX_WEB_REMOTE_HTTPS_PASS origin={final_origin[1]}")

    local_index = (DIST / "index.html").read_bytes()
    if index_bytes != local_index:
        fail(f"remote index bytes differ from validated dist local={sha(local_index)} remote={sha(index_bytes)}")

    csp = header(index_headers, "Content-Security-Policy")
    for token in REQUIRED_CSP:
        if token not in csp:
            fail(f"CSP missing {token}")
    require_header(index_headers, "X-Content-Type-Options", "nosniff")
    require_header(index_headers, "X-Frame-Options", "DENY")
    require_header(index_headers, "Referrer-Policy", "no-referrer")
    require_header(index_headers, "Cross-Origin-Opener-Policy", "same-origin")
    require_header(index_headers, "Cross-Origin-Resource-Policy", "same-origin")
    perms = header(index_headers, "Permissions-Policy")
    for token in ("camera=()", "microphone=()", "geolocation=()", "payment=()", "usb=()"):
        if token not in perms:
            fail(f"Permissions-Policy missing {token}")
    cache = header(index_headers, "Cache-Control").lower()
    if "no-store" not in cache:
        fail(f"index Cache-Control is not no-store: {cache!r}")
    hsts = header(index_headers, "Strict-Transport-Security")
    hsts_age = max_age(hsts)
    if hsts_age is None or hsts_age < 31536000:
        fail(f"HSTS max-age too small or missing: {hsts!r}")
    print("SAFEBOX_WEB_REMOTE_SECURITY_HEADERS_PASS")

    local_files = [p for p in sorted(DIST.rglob("*")) if p.is_file() and p.name != "_headers" and p.name != "index.html"]
    wasm_seen = False
    immutable_seen = 0
    for path in local_files:
        rel = path.relative_to(DIST).as_posix()
        remote_url = urljoin(final_base, rel)
        data, headers, fetched_url, code = get(remote_url, args.timeout)
        if code != 200:
            fail(f"remote asset HTTP {code}: {rel}")
        if origin(fetched_url) != final_origin:
            fail(f"cross-origin asset redirect: {rel} -> {fetched_url}")
        local = path.read_bytes()
        if data != local:
            fail(f"remote asset bytes differ: {rel}")
        cc = header(headers, "Cache-Control").lower()
        if rel.startswith("assets/"):
            if "immutable" not in cc or (max_age(cc) or 0) < 31536000:
                fail(f"hashed asset cache policy mismatch: {rel}: {cc!r}")
            immutable_seen += 1
        if re.fullmatch(r"safebox_core\.[0-9a-f]{12}\.wasm", rel):
            wasm_seen = True
            ctype = header(headers, "Content-Type").lower()
            if not ctype.startswith("application/wasm"):
                fail(f"WASM MIME mismatch: {ctype!r}")
            if "immutable" not in cc or (max_age(cc) or 0) < 31536000:
                fail(f"WASM cache policy mismatch: {cc!r}")
            immutable_seen += 1
    if not wasm_seen:
        fail("content-addressed WASM missing from local dist")
    if immutable_seen < 3:
        fail("expected immutable JS/CSS/WASM assets not all observed")
    print("SAFEBOX_WEB_REMOTE_EXACT_BYTES_PASS")
    print("SAFEBOX_WEB_REMOTE_WASM_MIME_CACHE_PASS")

    for rel in LEAK_PATHS:
        url = urljoin(final_base, rel)
        data, headers, fetched_url, code = get(url, args.timeout)
        if 200 <= code < 300:
            fail(f"source-like path is publicly served: /{rel}")
    print("SAFEBOX_WEB_REMOTE_NO_SOURCE_LEAK_PASS")
    print("SAFEBOX_WEB_REMOTE_DEPLOYMENT_AUDIT_PASS")


if __name__ == "__main__":
    main()
