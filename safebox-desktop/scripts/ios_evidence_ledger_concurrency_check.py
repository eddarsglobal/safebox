#!/usr/bin/env python3
import fcntl, hashlib, json, os, signal, stat, subprocess, sys, tempfile, time
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
APP_DIR = SCRIPT_DIR.parent
ROOT = APP_DIR.parent
LEDGER_TOOL = SCRIPT_DIR / "ios_evidence_ledger.py"
LIFE = SCRIPT_DIR / "ios_evidence_lifecycle.py"
PKG = ROOT / "SAFEBOX_V028_PACKAGE_ID.txt"
BRIDGE = APP_DIR / "src-tauri/ios/SafeBoxShareInboxBridge.mm"
RUST = APP_DIR / "src-tauri/src/lib.rs"
REAL_LEDGER = Path(os.environ.get("SAFEBOX_IOS_EVIDENCE_LEDGER_FILE", f"/tmp/safebox-ios-evidence-ledger-{os.getuid()}.json"))

sys.path.insert(0, str(SCRIPT_DIR))
from ios_evidence_lifecycle import canonical, runtime_hash  # noqa: E402


def fail(msg):
    print(f"SAFEBOX_IOS_EVIDENCE_LEDGER_CONCURRENCY_RUNTIME_FAIL: {msg}", file=sys.stderr)
    raise SystemExit(1)


def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def secure_write(path: Path, data: bytes):
    path.write_bytes(data)
    os.chmod(path, 0o600)


def make_pair(base: Path, idx: int, package: str, rh: str):
    now = int(time.time())
    arm = {
        "schema_version": 2,
        "device_udid": f"TEST-DEVICE-{idx}",
        "bundle_id": "com.safebox.desktop",
        "process_name": "SafeBox",
        "old_pid": 1000 + idx,
        "armed_at": f"2026-08-30 20:{idx % 60:02d}:00",
        "armed_unix": now - 20,
        "expected_route": "unlock",
        "package_id": package,
        "runtime_contract_sha256": rh,
    }
    arm_b = canonical(arm)
    arm_p = base / f"arm-{idx}.json"
    secure_write(arm_p, arm_b)
    receipt = {
        "schema_version": 1,
        "device_udid": arm["device_udid"],
        "bundle_id": arm["bundle_id"],
        "process_name": arm["process_name"],
        "armed_at": arm["armed_at"],
        "armed_unix": arm["armed_unix"],
        "expected_route": "unlock",
        "package_id": package,
        "runtime_contract_sha256": rh,
        "arm_sha256": sha(arm_b),
        "evidence_sha256": sha(f"evidence-{idx}".encode()),
        "manifest_seal_sha256": sha(f"manifest-{idx}".encode()),
        "old_pid": arm["old_pid"],
        "new_pid": 2000 + idx,
        "captured_unix": now - 2,
        "consumed_unix": now - 1,
        "expires_unix": now - 1 + 86400,
    }
    receipt["receipt_seal_sha256"] = sha(canonical(receipt) + arm_b)
    receipt_p = base / f"receipt-{idx}.json"
    secure_write(receipt_p, canonical(receipt))
    tx_material = {
        "arm_sha256": receipt["arm_sha256"],
        "manifest_seal_sha256": receipt["manifest_seal_sha256"],
        "receipt_seal_sha256": receipt["receipt_seal_sha256"],
        "route": "unlock",
        "package_id": package,
    }
    return arm_p, receipt_p, sha(canonical(tx_material))


def record_cmd(ledger: Path, arm: Path, receipt: Path):
    return [sys.executable, str(LEDGER_TOOL), "record", str(ledger), str(arm), str(receipt), str(PKG), str(BRIDGE), str(RUST), "unlock"]


def run_checked(cmd, **kwargs):
    p = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, **kwargs)
    if p.returncode != 0:
        fail((p.stderr or p.stdout or "command failed").strip())
    return p


def check_real_continuity():
    run_checked([sys.executable, str(LEDGER_TOOL), "inspect", str(REAL_LEDGER)])
    lock = Path(str(REAL_LEDGER) + ".lock")
    st = lock.lstat()
    if not stat.S_ISREG(st.st_mode) or stat.S_IMODE(st.st_mode) != 0o600 or st.st_nlink != 1 or st.st_size != 0:
        fail("real ledger lock security invalid")
    print("SAFEBOX_IOS_EVIDENCE_LEDGER_LOCK_CONTINUITY_PASS")


def concurrent_unique(tmp: Path, package: str, rh: str):
    ledger = tmp / "concurrent-ledger.json"
    pairs = [make_pair(tmp, i, package, rh) for i in range(1, 17)]
    procs = [subprocess.Popen(record_cmd(ledger, a, r), stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True) for a, r, _ in pairs]
    for p in procs:
        out, err = p.communicate(timeout=20)
        if p.returncode != 0:
            fail(f"concurrent writer failed: {(err or out).strip()}")
    data = json.loads(ledger.read_text())
    if len(data.get("entries", [])) != 16:
        fail("concurrent writers lost an entry")
    seqs = [int(e["seq"]) for e in data["entries"]]
    if seqs != list(range(1, 17)):
        fail("concurrent ledger sequence invalid")
    expected = {tx for _, _, tx in pairs}
    actual = {e["transaction_sha256"] for e in data["entries"]}
    if actual != expected:
        fail("concurrent transaction set mismatch")
    run_checked([sys.executable, str(LEDGER_TOOL), "inspect", str(ledger)])
    print("SAFEBOX_IOS_EVIDENCE_LEDGER_CONCURRENT_WRITERS_PASS writers=16")


def concurrent_idempotent(tmp: Path, package: str, rh: str):
    ledger = tmp / "idempotent-ledger.json"
    arm, receipt, tx = make_pair(tmp, 40, package, rh)
    procs = [subprocess.Popen(record_cmd(ledger, arm, receipt), stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True) for _ in range(8)]
    for p in procs:
        out, err = p.communicate(timeout=20)
        if p.returncode != 0:
            fail(f"idempotent writer failed: {(err or out).strip()}")
    data = json.loads(ledger.read_text())
    if len(data.get("entries", [])) != 1 or data["entries"][0]["transaction_sha256"] != tx:
        fail("concurrent idempotency failed")
    print("SAFEBOX_IOS_EVIDENCE_LEDGER_CONCURRENT_IDEMPOTENCY_PASS writers=8")


def crash_release(tmp: Path):
    ledger = tmp / "crash-ledger.json"
    lock = Path(str(ledger) + ".lock")
    ready = tmp / "lock-ready"
    helper = (
        "import fcntl,os,sys,time; "
        "p=sys.argv[1]; ready=sys.argv[2]; "
        "fd=os.open(p,os.O_RDWR|os.O_CREAT,0o600); os.fchmod(fd,0o600); "
        "fcntl.flock(fd,fcntl.LOCK_EX); open(ready,'w').write('ready'); time.sleep(30)"
    )
    proc = subprocess.Popen([sys.executable, "-c", helper, str(lock), str(ready)])
    deadline = time.time() + 5
    while not ready.exists() and time.time() < deadline:
        time.sleep(0.02)
    if not ready.exists():
        proc.kill(); proc.wait()
        fail("crash lock holder did not acquire lock")
    proc.kill()
    proc.wait(timeout=5)
    start = time.monotonic()
    run_checked([sys.executable, str(LEDGER_TOOL), "inspect", str(ledger)], timeout=5)
    if time.monotonic() - start > 2.0:
        fail("crash-released lock remained blocked")
    print("SAFEBOX_IOS_EVIDENCE_LEDGER_CRASH_RELEASE_PASS")


def negative_lock_security(tmp: Path):
    # Broad mode must fail.
    ledger = tmp / "mode-ledger.json"; lock = Path(str(ledger) + ".lock")
    lock.write_bytes(b""); os.chmod(lock, 0o644)
    p = subprocess.run([sys.executable, str(LEDGER_TOOL), "inspect", str(ledger)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    if p.returncode == 0:
        fail("broad lock mode accepted")
    lock.unlink()
    # Symlink lock must fail.
    target = tmp / "lock-target"; target.write_bytes(b""); os.chmod(target, 0o600); os.symlink(target, lock)
    p = subprocess.run([sys.executable, str(LEDGER_TOOL), "inspect", str(ledger)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    if p.returncode == 0:
        fail("symlink lock accepted")
    lock.unlink()
    # Hardlinked lock must fail.
    base = tmp / "lock-base"; base.write_bytes(b""); os.chmod(base, 0o600); os.link(base, lock)
    p = subprocess.run([sys.executable, str(LEDGER_TOOL), "inspect", str(ledger)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    if p.returncode == 0:
        fail("hardlinked lock accepted")
    print("SAFEBOX_IOS_EVIDENCE_LEDGER_LOCK_FILE_SECURITY_PASS")


def main():
    if not all(p.is_file() for p in (LEDGER_TOOL, LIFE, PKG, BRIDGE, RUST)):
        fail("required R66 files missing")
    package = PKG.read_text().strip()
    rh = runtime_hash(BRIDGE, RUST)
    check_real_continuity()
    with tempfile.TemporaryDirectory(prefix="safebox-r66-") as td:
        tmp = Path(td)
        concurrent_unique(tmp, package, rh)
        concurrent_idempotent(tmp, package, rh)
        crash_release(tmp)
        negative_lock_security(tmp)
    print("SAFEBOX_IOS_EVIDENCE_LEDGER_LOCK_RUNTIME_PASS")


if __name__ == "__main__":
    main()
