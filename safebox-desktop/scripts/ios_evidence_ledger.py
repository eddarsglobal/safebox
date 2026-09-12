#!/usr/bin/env python3
import contextlib, fcntl, hashlib, json, os, stat, sys, tempfile, time
from pathlib import Path
from ios_evidence_lifecycle import canonical, loadj, runtime_hash, secure_regular, verify_receipt

SCHEMA = 1
ENTRY_SCHEMA = 1
CAPACITY = 32
MAX_BYTES = 131072
ZERO = "0" * 64

LOCK_SUFFIX = ".lock"

def lock_path_for(ledger_path: Path) -> Path:
    return Path(str(ledger_path) + LOCK_SUFFIX)

def secure_lock_fd(fd: int, path: Path):
    st = os.fstat(fd)
    if not stat.S_ISREG(st.st_mode):
        fail("ledger lock is not regular")
    if st.st_nlink != 1:
        fail("ledger lock hardlink count invalid")
    if stat.S_IMODE(st.st_mode) != 0o600:
        fail("ledger lock mode invalid")
    if st.st_size != 0:
        fail("ledger lock must be empty")
    return st

@contextlib.contextmanager
def ledger_lock(ledger_path: Path, exclusive: bool):
    lock_path = lock_path_for(ledger_path)
    lock_path.parent.mkdir(parents=True, exist_ok=True)
    nofollow = getattr(os, "O_NOFOLLOW", 0)
    created = False
    try:
        fd = os.open(str(lock_path), os.O_RDWR | os.O_CREAT | os.O_EXCL | nofollow, 0o600)
        created = True
    except FileExistsError:
        fd = os.open(str(lock_path), os.O_RDWR | nofollow)
    try:
        if created:
            os.fchmod(fd, 0o600)
        secure_lock_fd(fd, lock_path)
        fcntl.flock(fd, fcntl.LOCK_EX if exclusive else fcntl.LOCK_SH)
        # Re-check after acquisition so a pre-existing unsafe lock cannot be raced in.
        secure_lock_fd(fd, lock_path)
        yield lock_path
    finally:
        try:
            fcntl.flock(fd, fcntl.LOCK_UN)
        finally:
            os.close(fd)

FORBIDDEN_KEYS = {
    "device_udid", "bundle_id", "process_name", "old_pid", "new_pid",
    "path", "filename", "file_name", "url", "source_url", "provider_url",
}

def fail(msg):
    raise SystemExit(msg)

def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()

def fsync_dir(path: Path):
    fd = os.open(str(path), os.O_RDONLY)
    try:
        os.fsync(fd)
    finally:
        os.close(fd)

def atomic_write(path: Path, data: bytes):
    fd, tmp = tempfile.mkstemp(prefix=".safebox-ledger-", dir=path.parent)
    try:
        os.fchmod(fd, 0o600)
        with os.fdopen(fd, "wb") as out:
            out.write(data)
            out.flush()
            os.fsync(out.fileno())
        os.replace(tmp, path)
        os.chmod(path, 0o600)
        fsync_dir(path.parent)
    finally:
        if os.path.exists(tmp):
            os.unlink(tmp)

def secure_ledger(path: Path, required=True):
    st = secure_regular(path, required)
    if st is not None and st.st_size > MAX_BYTES:
        fail("ledger too large")
    return st

def hex64(v):
    return isinstance(v, str) and len(v) == 64 and all(c in "0123456789abcdef" for c in v)

def privacy_walk(value, key=None):
    if key is not None and key in FORBIDDEN_KEYS:
        fail(f"forbidden ledger field: {key}")
    if isinstance(value, dict):
        for k, v in value.items():
            privacy_walk(v, str(k))
    elif isinstance(value, list):
        for v in value:
            privacy_walk(v)
    elif isinstance(value, str):
        low = value.lower()
        if "/" in value or "\\" in value or ".sbx" in low or "file:" in low or "http:" in low or "https:" in low:
            fail("ledger contains path/URL/SBX-like value")

def entry_unsigned(entry):
    out = dict(entry)
    out.pop("entry_hash", None)
    return out

def ledger_unsigned(ledger):
    out = dict(ledger)
    out.pop("ledger_seal_sha256", None)
    return out

def verify_ledger_obj(ledger):
    required = ("schema_version", "capacity", "anchor_hash", "head_hash", "next_seq", "updated_unix", "entries", "ledger_seal_sha256")
    for k in required:
        if k not in ledger:
            fail(f"ledger missing {k}")
    if int(ledger["schema_version"]) != SCHEMA:
        fail("ledger schema mismatch")
    if int(ledger["capacity"]) != CAPACITY:
        fail("ledger capacity mismatch")
    entries = ledger["entries"]
    if not isinstance(entries, list) or len(entries) > CAPACITY:
        fail("ledger bounds invalid")
    if not hex64(ledger["anchor_hash"]) or not hex64(ledger["head_hash"]):
        fail("ledger hash encoding invalid")
    prev = ledger["anchor_hash"]
    last_seq = None
    seen_tx = set()
    for entry in entries:
        for k in ("schema_version", "seq", "event", "route", "package_id", "runtime_contract_sha256", "consumed_unix", "transaction_sha256", "receipt_sha256", "prev_hash", "entry_hash"):
            if k not in entry:
                fail(f"ledger entry missing {k}")
        if int(entry["schema_version"]) != ENTRY_SCHEMA or entry["event"] != "consumed":
            fail("ledger entry schema/event invalid")
        if entry["route"] not in ("protect", "unlock"):
            fail("ledger route invalid")
        if not all(hex64(entry[k]) for k in ("runtime_contract_sha256", "transaction_sha256", "receipt_sha256", "prev_hash", "entry_hash")):
            fail("ledger entry hash encoding invalid")
        if entry["prev_hash"] != prev:
            fail("ledger chain predecessor mismatch")
        if entry["entry_hash"] != sha(canonical(entry_unsigned(entry))):
            fail("ledger entry hash mismatch")
        seq = int(entry["seq"])
        if last_seq is not None and seq != last_seq + 1:
            fail("ledger sequence gap")
        if entry["transaction_sha256"] in seen_tx:
            fail("duplicate transaction in ledger")
        seen_tx.add(entry["transaction_sha256"])
        last_seq = seq
        prev = entry["entry_hash"]
    if ledger["head_hash"] != (prev if entries else ledger["anchor_hash"]):
        fail("ledger head mismatch")
    expected_next = (int(entries[-1]["seq"]) + 1) if entries else int(ledger["next_seq"])
    if entries and int(ledger["next_seq"]) != expected_next:
        fail("ledger next sequence mismatch")
    if not entries and int(ledger["next_seq"]) < 1:
        fail("ledger next sequence invalid")
    seal = ledger["ledger_seal_sha256"]
    if not hex64(seal) or seal != sha(canonical(ledger_unsigned(ledger))):
        fail("ledger seal mismatch")
    privacy_walk(ledger)
    return seen_tx

def new_ledger():
    obj = {
        "schema_version": SCHEMA,
        "capacity": CAPACITY,
        "anchor_hash": ZERO,
        "head_hash": ZERO,
        "next_seq": 1,
        "updated_unix": int(time.time()),
        "entries": [],
    }
    obj["ledger_seal_sha256"] = sha(canonical(obj))
    return obj

def load_ledger(path: Path):
    if secure_ledger(path, False) is None:
        return new_ledger(), False
    obj = loadj(path, "evidence ledger")
    verify_ledger_obj(obj)
    return obj, True

def receipt_context(arm_p, receipt_p, pkg_p, bridge_p, rust_p, route):
    secure_regular(arm_p)
    secure_regular(receipt_p)
    arm = loadj(arm_p, "arm metadata")
    receipt = loadj(receipt_p, "consumed receipt")
    pkg = pkg_p.read_text().strip()
    current_runtime = runtime_hash(bridge_p, rust_p)
    verify_receipt(receipt, arm, pkg, current_runtime, route)
    receipt_bytes = receipt_p.read_bytes()
    tx_material = {
        "arm_sha256": receipt["arm_sha256"],
        "manifest_seal_sha256": receipt["manifest_seal_sha256"],
        "receipt_seal_sha256": receipt["receipt_seal_sha256"],
        "route": route,
        "package_id": pkg,
    }
    return receipt, pkg, current_runtime, sha(canonical(tx_material)), sha(receipt_bytes)

def record(ledger_p, arm_p, receipt_p, pkg_p, bridge_p, rust_p, route):
    with ledger_lock(ledger_p, True):
        receipt, pkg, current_runtime, tx_hash, receipt_hash = receipt_context(arm_p, receipt_p, pkg_p, bridge_p, rust_p, route)
        ledger, existed = load_ledger(ledger_p)
        matches = [e for e in ledger["entries"] if e["transaction_sha256"] == tx_hash]
        if matches:
            if len(matches) != 1:
                fail("ledger duplicate current transaction")
            e = matches[0]
            if e["receipt_sha256"] != receipt_hash or e["route"] != route or e["package_id"] != pkg or e["runtime_contract_sha256"] != current_runtime:
                fail("ledger current transaction mismatch")
            print("SAFEBOX_IOS_EVIDENCE_LEDGER_IDEMPOTENT_PASS")
            print("SAFEBOX_IOS_EVIDENCE_LEDGER_CURRENT_TRANSACTION_PASS")
            return
        seq = int(ledger["next_seq"])
        prev = ledger["head_hash"]
        entry = {
            "schema_version": ENTRY_SCHEMA,
            "seq": seq,
            "event": "consumed",
            "route": route,
            "package_id": pkg,
            "runtime_contract_sha256": current_runtime,
            "consumed_unix": int(receipt["consumed_unix"]),
            "transaction_sha256": tx_hash,
            "receipt_sha256": receipt_hash,
            "prev_hash": prev,
        }
        entry["entry_hash"] = sha(canonical(entry))
        ledger["entries"].append(entry)
        ledger["next_seq"] = seq + 1
        ledger["head_hash"] = entry["entry_hash"]
        while len(ledger["entries"]) > CAPACITY:
            removed = ledger["entries"].pop(0)
            ledger["anchor_hash"] = removed["entry_hash"]
        ledger["updated_unix"] = int(time.time())
        unsigned = ledger_unsigned(ledger)
        ledger["ledger_seal_sha256"] = sha(canonical(unsigned))
        verify_ledger_obj(ledger)
        atomic_write(ledger_p, canonical(ledger))
        secure_ledger(ledger_p)
        print("SAFEBOX_IOS_EVIDENCE_LEDGER_APPEND_PASS")
        print("SAFEBOX_IOS_EVIDENCE_LEDGER_CURRENT_TRANSACTION_PASS")
def verify_current(ledger_p, arm_p, receipt_p, pkg_p, bridge_p, rust_p, route):
    with ledger_lock(ledger_p, False):
        receipt, pkg, current_runtime, tx_hash, receipt_hash = receipt_context(arm_p, receipt_p, pkg_p, bridge_p, rust_p, route)
        ledger, existed = load_ledger(ledger_p)
        if not existed:
            fail("ledger missing")
        matches = [e for e in ledger["entries"] if e["transaction_sha256"] == tx_hash]
        if len(matches) != 1:
            fail("current transaction missing or duplicated")
        e = matches[0]
        if e["receipt_sha256"] != receipt_hash or e["route"] != route or e["package_id"] != pkg or e["runtime_contract_sha256"] != current_runtime:
            fail("current ledger entry mismatch")
        print("SAFEBOX_IOS_EVIDENCE_LEDGER_SCHEMA_PASS")
        print("SAFEBOX_IOS_EVIDENCE_LEDGER_CHAIN_PASS")
        print(f"SAFEBOX_IOS_EVIDENCE_LEDGER_BOUNDED_PASS entries={len(ledger['entries'])} capacity={CAPACITY}")
        print("SAFEBOX_IOS_EVIDENCE_LEDGER_PRIVACY_PASS")
        print("SAFEBOX_IOS_EVIDENCE_LEDGER_CURRENT_TRANSACTION_PASS")
        print("SAFEBOX_IOS_EVIDENCE_LEDGER_FILE_SECURITY_PASS")
        print("SAFEBOX_IOS_EVIDENCE_LEDGER_LOCK_SECURITY_PASS")
def inspect(ledger_p):
    with ledger_lock(ledger_p, False):
        ledger, existed = load_ledger(ledger_p)
        if not existed:
            print("SAFEBOX_IOS_EVIDENCE_LEDGER_GENESIS_PASS")
            return
        print("SAFEBOX_IOS_EVIDENCE_LEDGER_SCHEMA_PASS")
        print("SAFEBOX_IOS_EVIDENCE_LEDGER_CHAIN_PASS")
        print(f"SAFEBOX_IOS_EVIDENCE_LEDGER_BOUNDED_PASS entries={len(ledger['entries'])} capacity={CAPACITY}")
        print("SAFEBOX_IOS_EVIDENCE_LEDGER_PRIVACY_PASS")
        print("SAFEBOX_IOS_EVIDENCE_LEDGER_FILE_SECURITY_PASS")
        print("SAFEBOX_IOS_EVIDENCE_LEDGER_LOCK_SECURITY_PASS")
def main():
    if len(sys.argv) < 3:
        fail("usage: ledger inspect LEDGER | record|verify LEDGER ARM RECEIPT PACKAGE BRIDGE RUST ROUTE")
    cmd = sys.argv[1]
    if cmd == "inspect":
        if len(sys.argv) != 3:
            fail("usage: ledger inspect LEDGER")
        inspect(Path(sys.argv[2]))
        return
    if cmd not in ("record", "verify") or len(sys.argv) != 9:
        fail("usage: ledger record|verify LEDGER ARM RECEIPT PACKAGE BRIDGE RUST ROUTE")
    ledger_p, arm_p, receipt_p, pkg_p, bridge_p, rust_p = map(Path, sys.argv[2:8])
    route = sys.argv[8]
    if cmd == "record":
        record(ledger_p, arm_p, receipt_p, pkg_p, bridge_p, rust_p, route)
    else:
        verify_current(ledger_p, arm_p, receipt_p, pkg_p, bridge_p, rust_p, route)

if __name__ == "__main__":
    main()
