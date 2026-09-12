#!/usr/bin/env python3
from __future__ import annotations
import argparse
from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler
from pathlib import Path
import os

ROOT = Path(__file__).resolve().parents[1]
DIST = ROOT / "dist"
CSP = "default-src 'self'; base-uri 'none'; object-src 'none'; frame-ancestors 'none'; form-action 'none'; script-src 'self' 'wasm-unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data: blob:; font-src 'self'; connect-src 'self'; worker-src 'none'; media-src 'none'; manifest-src 'self'"
LANDING_CSP = CSP.replace(
    "script-src 'self' 'wasm-unsafe-eval'",
    "script-src 'self' 'wasm-unsafe-eval' https://pagead2.googlesyndication.com",
)

class SafeBoxHandler(SimpleHTTPRequestHandler):
    extensions_map = {**SimpleHTTPRequestHandler.extensions_map, ".wasm": "application/wasm"}

    def end_headers(self):
        path = self.path.split("?", 1)[0]
        self.send_header("Content-Security-Policy", LANDING_CSP if path in ("/", "/index.html") else CSP)
        self.send_header("X-Content-Type-Options", "nosniff")
        self.send_header("X-Frame-Options", "DENY")
        self.send_header("Referrer-Policy", "no-referrer")
        self.send_header("Permissions-Policy", "camera=(), microphone=(), geolocation=(), payment=(), usb=(), serial=(), bluetooth=(), browsing-topics=()")
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Resource-Policy", "same-origin")
        if path in ("/", "/index.html"):
            self.send_header("Cache-Control", "no-store, max-age=0")
        elif path.startswith("/assets/") or (path.startswith("/safebox_core.") and path.endswith(".wasm")):
            self.send_header("Cache-Control", "public, max-age=31536000, immutable")
        else:
            self.send_header("Cache-Control", "no-cache")
        super().end_headers()

    def log_message(self, fmt, *args):
        if os.environ.get("SAFEBOX_WEB_SERVER_VERBOSE") == "1":
            super().log_message(fmt, *args)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--bind", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=4173)
    args = parser.parse_args()
    if not (DIST / "index.html").is_file():
        raise SystemExit("SAFEBOX_WEB_PROD_SERVER_FAIL: dist/index.html missing")
    os.chdir(DIST)
    server = ThreadingHTTPServer((args.bind, args.port), SafeBoxHandler)
    print(f"SAFEBOX_WEB_PROD_SERVER_READY http://{args.bind}:{args.port}", flush=True)
    server.serve_forever()

if __name__ == "__main__":
    main()
