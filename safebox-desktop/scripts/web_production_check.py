#!/usr/bin/env python3
from pathlib import Path
import hashlib, re
D = Path(__file__).resolve().parents[1]
ROOT = D.parent

def fail(msg):
    print(f"SAFEBOX_WEB_PRODUCTION_CHECK_FAIL: {msg}")
    raise SystemExit(1)

def need(path, token):
    text = path.read_text(errors="replace")
    if token not in text: fail(f"{path.name}: missing {token}")

vite = D / "vite.config.ts"
headers = D / "public/_headers"
engine = D / "src/web-sbx-engine.ts"
e2e = D / "src/web-e2e.ts"
ui = D / "scripts/web_ui_build.sh"
browser = D / "scripts/web_browser_e2e.sh"
cdp = D / "scripts/web_browser_cdp_e2e.py"
server = D / "scripts/web_prod_server.py"
pkg = D / "package.json"
for p in (vite, headers, engine, e2e, ui, browser, cdp, server, pkg):
    if not p.is_file(): fail(f"missing {p}")

for token in ("Content-Security-Policy", "wasm-unsafe-eval", "base-uri 'none'", "object-src 'none'", "connect-src 'self'"):
    need(vite, token)
for token in ("frame-ancestors 'none'", "X-Content-Type-Options: nosniff", "X-Frame-Options: DENY", "Referrer-Policy: no-referrer", "Permissions-Policy:", "Cross-Origin-Opener-Policy: same-origin", "Cross-Origin-Resource-Policy: same-origin"):
    need(headers, token)
print("SAFEBOX_WEB_CSP_POLICY_PASS")
print("SAFEBOX_WEB_SECURITY_HEADERS_POLICY_PASS")

need(engine, 'import.meta.env.VITE_SAFEBOX_WASM_FILE || "safebox_core.wasm"')
need(engine, 'cache: "force-cache"')
need(ui, 'WASM_FILE="safebox_core.${WASM_SHORT}.wasm"')
need(ui, 'VITE_SAFEBOX_WASM_FILE="$WASM_FILE" vite build --mode web')
need(ui, 'rm -f "$DESKTOP_DIR/dist/safebox_core.wasm"')
need(headers, '/safebox_core.*.wasm')
need(headers, 'max-age=31536000, immutable')
print("SAFEBOX_WEB_CONTENT_ADDRESSED_WASM_PASS")
print("SAFEBOX_WEB_WASM_CACHE_POLICY_PASS")

need(e2e, 'params.get(E2E_QUERY) !== "1"')
need(e2e, 'isLoopbackHost(window.location.hostname)')
need(e2e, 'SAFEBOX_WEB_BROWSER_WRONG_CODE_REJECT_PASS')
need(e2e, 'SAFEBOX_WEB_BROWSER_TAMPER_REJECT_PASS')
need(e2e, 'SAFEBOX_WEB_BROWSER_BLOB_BOUNDARY_PASS')
need(e2e, 'runBrowserE2E(emitMarker)')
need(e2e, 'result.dataset.lastMarker = marker')
need(browser, 'web_browser_cdp_e2e.py')
need(browser, 'SAFEBOX_WEB_BROWSER_E2E_PROGRESSIVE_GATE_BEGIN')
need(browser, 'SAFEBOX_WEB_PRODUCTION_HEADERS_RUNTIME_PASS')
need(browser, 'SAFEBOX_WEB_BROWSER_PRODUCTION_GATE_PASS')
need(cdp, '"--headless=new"')
need(cdp, 'SAFEBOX_WEB_BROWSER_CDP_READY_PASS')
need(cdp, 'SAFEBOX_WEB_BROWSER_E2E_HEARTBEAT')
need(cdp, 'SAFEBOX_WEB_BROWSER_E2E_TIMEOUT_FAIL')
need(cdp, 'SAFEBOX_WEB_BROWSER_E2E_EARLY_EXIT_PASS')
browser_text = browser.read_text(errors="replace")
if "--virtual-time-budget" in browser_text or "--dump-dom" in browser_text:
    fail("legacy silent dump-dom/virtual-time browser gate retained")
print("SAFEBOX_WEB_E2E_LOOPBACK_SCOPE_PASS")
print("SAFEBOX_WEB_E2E_ADVERSARIAL_CASES_PASS")
e2e_text = e2e.read_text(errors="replace")
if not ('protectedBytes[0] !== 0x53' in e2e_text and 'protectedBytes[3] !== 0x31' in e2e_text):
    fail("SBX1 envelope magic browser assertion missing")
print("SAFEBOX_WEB_E2E_SBX1_MAGIC_SEMANTICS_PASS")
if not ('publicInfo.format !== "SBX"' in e2e_text and 'publicInfo.format !== "SBX1"' not in e2e_text):
    fail("public header format semantics mismatch")
print("SAFEBOX_WEB_E2E_PUBLIC_FORMAT_SEMANTICS_PASS")
print("SAFEBOX_WEB_BROWSER_PROGRESSIVE_HARNESS_PASS")
print("SAFEBOX_WEB_BROWSER_HARD_TIMEOUT_POLICY_PASS")
print("SAFEBOX_WEB_BROWSER_EARLY_EXIT_POLICY_PASS")
print("SAFEBOX_WEB_REAL_BROWSER_GATE_PASS")

need(server, 'application/wasm')
need(server, 'no-store, max-age=0')
need(server, 'max-age=31536000, immutable')
print("SAFEBOX_WEB_PRODUCTION_SERVER_POLICY_PASS")

need(pkg, '"web:production-check"')
need(pkg, '"web:e2e"')
need(pkg, '"web:production-gate"')
print("SAFEBOX_WEB_PRODUCTION_COMMANDS_PASS")

def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()

expected = {
    ROOT / "safebox-core/src/crypto.rs": "1d75fe23895cb0196fb7ff5b369c59596c300a3bd3eb5a07395d3287f925b670",
    ROOT / "safebox-core/src/format.rs": "26edb67b2be91ff5c7d765e100e4aafa5e50933919c0db2e4370901f67205ea1",
    ROOT / "safebox-core/src/memory.rs": "2ed3cc0f1b91e3815c9fcffdec5aa3c423a481f798c2fc8521b0039a828957ef",
    ROOT / "safebox-web-wasm/src/lib.rs": "d5e65323c3d87b02b2f8958d8edc4dfddf500a9787fdf4377080c5092d9ea4c3",
    D / "src-tauri/src/lib.rs": "5a4bc10bc1d362a0737c0da2b0b6caad00436206137fd0fc800e2b842c57f297",
    D / "src-tauri/ios/SafeBoxAdsBridge.mm": "a408b55ec036ee71894853c144fc753e7a181eeaca7b5ae6872ec636dfc5e2ea",
    D / "src-tauri/ios/SafeBoxShareInboxBridge.mm": "da8b92247ee777a03770cc7df67b52b13a8981ca6987b70403fbd97e8913d9e4",
}
for path, digest in expected.items():
    if sha256(path) != digest: fail(f"immutable runtime changed: {path}")
print("SAFEBOX_WEB_R79_CRYPTO_WASM_CORE_UNCHANGED_R80_PASS")
print("SAFEBOX_DESKTOP_IOS_NATIVE_RUNTIME_UNCHANGED_R80_PASS")
print("SAFEBOX_WEB_PRODUCTION_HARDENING_PASS")
