#!/usr/bin/env python3
from __future__ import annotations
from pathlib import Path
import hashlib
import json
import re

D = Path(__file__).resolve().parents[1]
ROOT = D.parent


def fail(msg: str) -> None:
    print(f"SAFEBOX_WEB_DEPLOYMENT_CHECK_FAIL: {msg}")
    raise SystemExit(1)


def need(path: Path, token: str) -> None:
    if not path.is_file():
        fail(f"missing {path}")
    if token not in path.read_text(errors="replace"):
        fail(f"{path.name}: missing {token}")


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()

package_id = (ROOT / "SAFEBOX_V029_PACKAGE_ID.txt").read_text().strip()
if package_id != "SAFEBOX v0.2.9 R85 — cinematic trust design crypto story":
    fail(f"unexpected package id: {package_id}")
print("SAFEBOX_WEB_R85_PACKAGE_ID_PASS")

headers = D / "public/_headers"
bundle = D / "scripts/web_deploy_bundle.py"
remote = D / "scripts/web_remote_audit.py"
production = D / "scripts/web_production_check.py"
pkg_path = D / "package.json"
doc = ROOT / "WEB_DEPLOY.md"
for path in (headers, bundle, remote, production, pkg_path, doc):
    if not path.is_file(): fail(f"missing {path}")

need(headers, "Strict-Transport-Security: max-age=31536000")
need(headers, "Content-Security-Policy:")
need(headers, "connect-src 'self'")
need(headers, "X-Content-Type-Options: nosniff")
print("SAFEBOX_WEB_R85_HSTS_DEPLOY_POLICY_PASS")

# The browser app has exactly one network API call: same-origin GET of the content-addressed WASM.
network_tokens = ("XMLHttpRequest", "WebSocket(", "EventSource(", "sendBeacon(", "navigator.serviceWorker.register")
for ts in sorted((D / "src").glob("*.ts")):
    text = ts.read_text(errors="replace")
    for token in network_tokens:
        if token in text:
            fail(f"forbidden Web egress/runtime API in {ts.name}: {token}")
fetches = []
for ts in sorted((D / "src").glob("*.ts")):
    text = ts.read_text(errors="replace")
    for m in re.finditer(r"\bfetch\s*\(", text):
        fetches.append((ts.name, m.start()))
if len(fetches) != 1 or fetches[0][0] != "web-sbx-engine.ts":
    fail(f"unexpected fetch surface: {fetches}")
engine = (D / "src/web-sbx-engine.ts").read_text(errors="replace")
if 'fetch(wasmUrl(), { cache: "force-cache", credentials: "same-origin" })' not in engine:
    fail("sole fetch is not the audited same-origin WASM loader")
print("SAFEBOX_WEB_R85_NO_USER_DATA_EGRESS_SURFACE_PASS")

for token in (
    "deterministic_zip",
    "SAFEBOX_WEB_DEPLOY_NO_SECRETS_PASS",
    "SAFEBOX_WEB_DEPLOY_TREE_AUDIT_PASS",
    "SAFEBOX_WEB_DEPLOY_MANIFEST_PASS",
    "SAFEBOX_WEB_DEPLOY_BUNDLE_PASS",
):
    need(bundle, token)
print("SAFEBOX_WEB_R85_DETERMINISTIC_DEPLOY_ARTIFACT_PASS")

for token in (
    '"app.html"',
    '"ads-config.json"',
    '"manifest.webmanifest"',
    'ALLOWED_LEGAL_NAMES',
):
    need(bundle, token)
print("SAFEBOX_WEB_R85_PUBLIC_SURFACE_ALLOWLIST_PASS")

for token in (
    'scheme.lower() != "https"',
    "Strict-Transport-Security",
    "Content-Security-Policy",
    "application/wasm",
    "SAFEBOX_WEB_REMOTE_EXACT_BYTES_PASS",
    "SAFEBOX_WEB_REMOTE_NO_SOURCE_LEAK_PASS",
    "SAFEBOX_WEB_REMOTE_DEPLOYMENT_AUDIT_PASS",
):
    need(remote, token)
print("SAFEBOX_WEB_R85_REMOTE_AUDIT_POLICY_PASS")

pkg = json.loads(pkg_path.read_text())
for name in ("web:deployment-check", "web:deploy-bundle", "web:remote-audit", "web:release-gate"):
    if name not in pkg.get("scripts", {}): fail(f"package command missing: {name}")
print("SAFEBOX_WEB_R85_RELEASE_COMMANDS_PASS")

need(doc, "GitHub Pages is not a SafeBox production target in R81")
need(doc, "Cloudflare Pages and Netlify")
need(doc, "SAFEBOX_WEB_REMOTE_DEPLOYMENT_AUDIT_PASS")
print("SAFEBOX_WEB_R85_HOST_SECURITY_DECISION_PASS")

# R81 must not alter the already validated R80 crypto/browser runtime.
expected = {
    ROOT / "safebox-core/src/crypto.rs": "1d75fe23895cb0196fb7ff5b369c59596c300a3bd3eb5a07395d3287f925b670",
    ROOT / "safebox-core/src/format.rs": "26edb67b2be91ff5c7d765e100e4aafa5e50933919c0db2e4370901f67205ea1",
    ROOT / "safebox-core/src/memory.rs": "2ed3cc0f1b91e3815c9fcffdec5aa3c423a481f798c2fc8521b0039a828957ef",
    ROOT / "safebox-web-wasm/src/lib.rs": "d5e65323c3d87b02b2f8958d8edc4dfddf500a9787fdf4377080c5092d9ea4c3",
    D / "src/web-sbx-engine.ts": "7396fa6f0cef79a7c6a425258ca117ed67543e19b7b9f8a104b6f26506ba9b8d",
    D / "src/web-e2e.ts": "18e769e42b8023cae9ebefbfe8409b70ceefbce93f7b790f7e2d32b3079c4629",
    D / "src/main.ts": "b4a161bdd4b9318f05b5fae4916ddcacb0bc3f83e0404be1f0199b9f0e20df36",
    D / "src-tauri/src/lib.rs": "5a4bc10bc1d362a0737c0da2b0b6caad00436206137fd0fc800e2b842c57f297",
    D / "src-tauri/ios/SafeBoxAdsBridge.mm": "a408b55ec036ee71894853c144fc753e7a181eeaca7b5ae6872ec636dfc5e2ea",
    D / "src-tauri/ios/SafeBoxShareInboxBridge.mm": "da8b92247ee777a03770cc7df67b52b13a8981ca6987b70403fbd97e8913d9e4",
    D / "src-tauri/ios-share/ShareViewController.swift": "c868a61f534a425eabf3bea9adeb591474823053ecd582c799a1cafba4da59a4",
}
for path, digest in expected.items():
    if sha(path) != digest:
        fail(f"validated runtime changed: {path}")
print("SAFEBOX_WEB_R80_CRYPTO_BROWSER_RUNTIME_UNCHANGED_R81_PASS")
print("SAFEBOX_DESKTOP_IOS_NATIVE_RUNTIME_UNCHANGED_R81_PASS")
print("SAFEBOX_WEB_DEPLOYMENT_READINESS_R85_PASS")
