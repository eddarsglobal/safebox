#!/usr/bin/env python3
import argparse
import base64
import hashlib
import json
import os
from pathlib import Path
import socket
import struct
import subprocess
import sys
import time
import urllib.request

EXPECTED_MARKERS = [
    "SAFEBOX_WEB_BROWSER_ENGINE_LOAD_PASS",
    "SAFEBOX_WEB_BROWSER_PROTECT_PASS",
    "SAFEBOX_WEB_BROWSER_MAGIC_SBX1_PASS",
    "SAFEBOX_WEB_BROWSER_PUBLIC_FORMAT_SBX_PASS",
    "SAFEBOX_WEB_BROWSER_PUBLIC_INFO_PASS",
    "SAFEBOX_WEB_BROWSER_WRONG_CODE_REJECT_PASS",
    "SAFEBOX_WEB_BROWSER_TAMPER_REJECT_PASS",
    "SAFEBOX_WEB_BROWSER_UNLOCK_PASS",
    "SAFEBOX_WEB_BROWSER_BLOB_BOUNDARY_PASS",
    "SAFEBOX_WEB_BROWSER_E2E_PASS",
]
FAIL_PREFIX = "SAFEBOX_WEB_BROWSER_E2E_FAIL:"


def fail(message: str, stderr_path: Path | None = None) -> "NoReturn":
    print(f"SAFEBOX_WEB_BROWSER_E2E_FAIL: {message}", flush=True)
    if stderr_path and stderr_path.is_file():
        try:
            text = stderr_path.read_text(errors="replace")
            if text.strip():
                print("--- browser stderr ---", flush=True)
                print(text[-12000:], flush=True)
        except OSError:
            pass
    raise SystemExit(1)


def http_json(url: str):
    with urllib.request.urlopen(url, timeout=2.0) as response:
        return json.loads(response.read().decode("utf-8"))


class WebSocket:
    def __init__(self, url: str):
        if not url.startswith("ws://"):
            raise ValueError("only loopback ws:// CDP endpoints are supported")
        rest = url[5:]
        hostport, path = rest.split("/", 1)
        if ":" not in hostport:
            host, port = hostport, 80
        else:
            host, port_text = hostport.rsplit(":", 1)
            port = int(port_text)
        if host not in ("127.0.0.1", "localhost", "[::1]"):
            raise ValueError("CDP endpoint must be loopback")
        self.sock = socket.create_connection(("127.0.0.1" if host == "localhost" else host.strip("[]"), port), timeout=3.0)
        self.sock.settimeout(3.0)
        key = base64.b64encode(os.urandom(16)).decode("ascii")
        request = (
            f"GET /{path} HTTP/1.1\r\n"
            f"Host: {hostport}\r\n"
            "Upgrade: websocket\r\n"
            "Connection: Upgrade\r\n"
            f"Sec-WebSocket-Key: {key}\r\n"
            "Sec-WebSocket-Version: 13\r\n"
            "\r\n"
        ).encode("ascii")
        self.sock.sendall(request)
        response = self._read_until(b"\r\n\r\n", 65536)
        first = response.split(b"\r\n", 1)[0]
        if b" 101 " not in first:
            raise RuntimeError(f"CDP WebSocket handshake failed: {first.decode(errors='replace')}")
        accept = None
        for line in response.decode("latin1").split("\r\n")[1:]:
            if line.lower().startswith("sec-websocket-accept:"):
                accept = line.split(":", 1)[1].strip()
                break
        expected = base64.b64encode(hashlib.sha1((key + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11").encode()).digest()).decode()
        if accept != expected:
            raise RuntimeError("CDP WebSocket handshake accept mismatch")
        self.next_id = 1

    def _read_until(self, marker: bytes, cap: int) -> bytes:
        data = bytearray()
        while marker not in data:
            chunk = self.sock.recv(4096)
            if not chunk:
                raise EOFError("socket closed")
            data.extend(chunk)
            if len(data) > cap:
                raise RuntimeError("CDP handshake too large")
        return bytes(data)

    def close(self):
        try:
            self.sock.close()
        except OSError:
            pass

    def _recv_exact(self, size: int) -> bytes:
        out = bytearray()
        while len(out) < size:
            chunk = self.sock.recv(size - len(out))
            if not chunk:
                raise EOFError("CDP socket closed")
            out.extend(chunk)
        return bytes(out)

    def _send_text(self, text: str):
        payload = text.encode("utf-8")
        first = 0x81
        mask_key = os.urandom(4)
        length = len(payload)
        if length < 126:
            header = bytes([first, 0x80 | length])
        elif length <= 0xFFFF:
            header = bytes([first, 0x80 | 126]) + struct.pack("!H", length)
        else:
            header = bytes([first, 0x80 | 127]) + struct.pack("!Q", length)
        masked = bytes(byte ^ mask_key[i % 4] for i, byte in enumerate(payload))
        self.sock.sendall(header + mask_key + masked)

    def _recv_text(self) -> str:
        while True:
            b1, b2 = self._recv_exact(2)
            opcode = b1 & 0x0F
            masked = (b2 & 0x80) != 0
            length = b2 & 0x7F
            if length == 126:
                length = struct.unpack("!H", self._recv_exact(2))[0]
            elif length == 127:
                length = struct.unpack("!Q", self._recv_exact(8))[0]
            mask_key = self._recv_exact(4) if masked else b""
            payload = self._recv_exact(length)
            if masked:
                payload = bytes(byte ^ mask_key[i % 4] for i, byte in enumerate(payload))
            if opcode == 0x8:
                raise EOFError("CDP WebSocket closed")
            if opcode == 0x9:  # ping
                self._send_pong(payload)
                continue
            if opcode == 0xA:  # pong
                continue
            if opcode != 0x1:
                continue
            return payload.decode("utf-8")

    def _send_pong(self, payload: bytes):
        mask_key = os.urandom(4)
        length = len(payload)
        if length >= 126:
            return
        header = bytes([0x8A, 0x80 | length])
        masked = bytes(byte ^ mask_key[i % 4] for i, byte in enumerate(payload))
        self.sock.sendall(header + mask_key + masked)

    def call(self, method: str, params: dict | None = None) -> dict:
        call_id = self.next_id
        self.next_id += 1
        message = {"id": call_id, "method": method}
        if params is not None:
            message["params"] = params
        self._send_text(json.dumps(message, separators=(",", ":")))
        while True:
            incoming = json.loads(self._recv_text())
            if incoming.get("id") == call_id:
                if "error" in incoming:
                    raise RuntimeError(f"CDP {method} failed: {incoming['error']}")
                return incoming.get("result", {})


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--browser", required=True)
    parser.add_argument("--url", required=True)
    parser.add_argument("--profile", required=True)
    parser.add_argument("--stderr", required=True)
    parser.add_argument("--timeout", type=float, default=90.0)
    parser.add_argument("--heartbeat", type=float, default=5.0)
    args = parser.parse_args()

    if args.timeout < 10 or args.timeout > 300:
        fail("timeout must be between 10 and 300 seconds")
    if args.heartbeat < 1 or args.heartbeat > 30:
        fail("heartbeat must be between 1 and 30 seconds")

    profile = Path(args.profile)
    stderr_path = Path(args.stderr)
    profile.mkdir(parents=True, exist_ok=True)
    stderr_path.parent.mkdir(parents=True, exist_ok=True)

    cmd = [
        args.browser,
        "--headless=new",
        "--disable-gpu",
        "--no-first-run",
        "--no-default-browser-check",
        "--disable-background-networking",
        "--disable-component-update",
        f"--user-data-dir={profile}",
        "--remote-debugging-port=0",
        args.url,
    ]
    if hasattr(os, "geteuid") and os.geteuid() == 0:
        # Linux CI/container compatibility only. Normal macOS user runs never take this branch.
        cmd.insert(1, "--no-sandbox")

    start = time.monotonic()
    browser = None
    ws = None
    stderr_file = stderr_path.open("wb")
    try:
        browser = subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=stderr_file)
        active_port = profile / "DevToolsActivePort"
        port = None
        while time.monotonic() - start < 12.0:
            if browser.poll() is not None:
                stderr_file.flush()
                fail(f"browser exited before CDP became ready (exit={browser.returncode})", stderr_path)
            if active_port.is_file():
                try:
                    lines = active_port.read_text().splitlines()
                    if lines and lines[0].isdigit():
                        port = int(lines[0])
                        break
                except OSError:
                    pass
            time.sleep(0.1)
        if port is None:
            fail("CDP did not become ready within 12 seconds", stderr_path)
        print("SAFEBOX_WEB_BROWSER_CDP_READY_PASS", flush=True)

        target = None
        target_deadline = time.monotonic() + 8.0
        while time.monotonic() < target_deadline:
            try:
                targets = http_json(f"http://127.0.0.1:{port}/json/list")
                for item in targets:
                    if item.get("type") == "page" and item.get("url", "").startswith(args.url.split("?", 1)[0]):
                        target = item
                        break
            except Exception:
                pass
            if target:
                break
            if browser.poll() is not None:
                stderr_file.flush()
                fail(f"browser exited while locating E2E page (exit={browser.returncode})", stderr_path)
            time.sleep(0.1)
        if not target or not target.get("webSocketDebuggerUrl"):
            fail("E2E page CDP target not found", stderr_path)

        ws = WebSocket(target["webSocketDebuggerUrl"])
        print("SAFEBOX_WEB_BROWSER_E2E_BEGIN", flush=True)

        seen = set()
        last_heartbeat = time.monotonic()
        last_marker = "SAFEBOX_WEB_BROWSER_E2E_BEGIN"
        expression = """(() => { const e=document.getElementById('safebox-web-e2e-result'); return e ? {text:e.textContent||'',status:e.dataset.status||''} : {text:'',status:''}; })()"""

        while True:
            now = time.monotonic()
            elapsed = now - start
            if elapsed > args.timeout:
                print(f"SAFEBOX_WEB_BROWSER_E2E_TIMEOUT_FAIL seconds={int(args.timeout)} last={last_marker}", flush=True)
                fail("hard browser E2E timeout reached", stderr_path)
            if browser.poll() is not None:
                stderr_file.flush()
                fail(f"browser exited before E2E completion (exit={browser.returncode})", stderr_path)

            try:
                result = ws.call("Runtime.evaluate", {
                    "expression": expression,
                    "returnByValue": True,
                    "awaitPromise": False,
                })
            except (socket.timeout, EOFError, OSError, RuntimeError) as exc:
                fail(f"CDP polling failed: {exc}", stderr_path)

            value = result.get("result", {}).get("value", {})
            text = value.get("text", "") if isinstance(value, dict) else ""
            status = value.get("status", "") if isinstance(value, dict) else ""
            lines = [line.strip() for line in text.splitlines() if line.strip()]

            for marker in EXPECTED_MARKERS:
                if marker in lines and marker not in seen:
                    seen.add(marker)
                    last_marker = marker
                    print(marker, flush=True)

            failure_lines = [line for line in lines if line.startswith(FAIL_PREFIX)]
            if failure_lines or status == "fail":
                detail = failure_lines[-1] if failure_lines else "browser E2E reported failure"
                fail(detail, stderr_path)

            if "SAFEBOX_WEB_BROWSER_E2E_PASS" in seen:
                missing = [marker for marker in EXPECTED_MARKERS if marker not in seen]
                if missing:
                    fail("E2E pass observed with missing markers: " + ", ".join(missing), stderr_path)
                print(f"SAFEBOX_WEB_BROWSER_E2E_EARLY_EXIT_PASS elapsed_ms={int(elapsed * 1000)}", flush=True)
                try:
                    ws.call("Browser.close")
                except Exception:
                    pass
                return 0

            if now - last_heartbeat >= args.heartbeat:
                print(f"SAFEBOX_WEB_BROWSER_E2E_HEARTBEAT elapsed={int(elapsed)}s last={last_marker}", flush=True)
                last_heartbeat = now
            time.sleep(0.25)
    finally:
        if ws is not None:
            ws.close()
        if browser is not None and browser.poll() is None:
            browser.terminate()
            try:
                browser.wait(timeout=3)
            except subprocess.TimeoutExpired:
                browser.kill()
        stderr_file.close()


if __name__ == "__main__":
    sys.exit(main())
