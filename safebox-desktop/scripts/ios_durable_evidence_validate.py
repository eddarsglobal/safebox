#!/usr/bin/env python3
import hashlib, json, os, stat, sys, time
from pathlib import Path
MAX_EVIDENCE_BYTES=2*1024*1024; MAX_AGE_SECONDS=86400; MAX_FUTURE_SKEW=300; SCHEMA_VERSION=2

def fail(msg): raise SystemExit(msg)
def sha(b): return hashlib.sha256(b).hexdigest()
def canonical(o): return (json.dumps(o,sort_keys=True,separators=(',',':'))+'\n').encode()
def secure_regular(p):
    st=p.lstat()
    if stat.S_ISLNK(st.st_mode) or not stat.S_ISREG(st.st_mode): fail(f'unsafe file type: {p.name}')
    if st.st_uid!=os.getuid(): fail(f'owner mismatch: {p.name}')
    if st.st_mode & 0o077: fail(f'permissions too broad: {p.name}')
    if st.st_nlink!=1: fail(f'unexpected hardlink count: {p.name}')
    return st
def runtime_hash(bridge,rust):
    h=hashlib.sha256()
    for label,p in ((b'SafeBoxShareInboxBridge.mm\0',bridge),(b'lib.rs\0',rust)):
        h.update(label); h.update(p.read_bytes()); h.update(b'\0')
    return h.hexdigest()
def loadj(p,what):
    try: return json.loads(p.read_text())
    except Exception as e: fail(f'invalid {what}: {e}')

def main():
    if len(sys.argv)!=8: fail('usage: validator ARM META EVIDENCE PACKAGE BRIDGE RUST ROUTE')
    arm_p,meta_p,ev_p,pkg_p,bridge,rust=map(Path,sys.argv[1:7]); route=sys.argv[7]
    if route not in ('protect','unlock'): fail('invalid expected route')
    for p in (arm_p,meta_p,ev_p):
        try: secure_regular(p)
        except FileNotFoundError: fail(f'missing {p.name}')
    if not (0<ev_p.stat().st_size<=MAX_EVIDENCE_BYTES): fail('evidence size outside policy')
    arm=loadj(arm_p,'arm metadata'); meta=loadj(meta_p,'evidence metadata'); package_id=pkg_p.read_text().strip()
    reqa=('schema_version','device_udid','bundle_id','process_name','old_pid','armed_at','armed_unix','expected_route','package_id','runtime_contract_sha256')
    reqm=('schema_version','device_udid','bundle_id','process_name','armed_at','armed_unix','expected_route','package_id','runtime_contract_sha256','arm_sha256','old_pid','new_pid','captured_unix','expires_unix','evidence_sha256','evidence_bytes','manifest_seal_sha256')
    for k in reqa:
        if arm.get(k) in (None,''): fail(f'arm missing {k}')
    for k in reqm:
        if meta.get(k) in (None,''): fail(f'evidence missing {k}')
    if int(arm['schema_version'])!=2 or int(meta['schema_version'])!=2: fail('evidence schema mismatch')
    print('SAFEBOX_IOS_EVIDENCE_SCHEMA_PASS')
    if arm['expected_route']!=route or meta['expected_route']!=route: fail('route mismatch')
    for k in ('device_udid','bundle_id','process_name','armed_at','armed_unix','expected_route','package_id','runtime_contract_sha256','old_pid'):
        if str(meta[k])!=str(arm[k]): fail(f'arm/evidence mismatch: {k}')
    arm_bytes=canonical(arm)
    if sha(arm_bytes)!=str(meta['arm_sha256']): fail('arm sha256 mismatch')
    print('SAFEBOX_IOS_EVIDENCE_ARM_BINDING_PASS')
    if arm['package_id']!=package_id or meta['package_id']!=package_id: fail('package binding mismatch')
    print('SAFEBOX_IOS_EVIDENCE_PACKAGE_BINDING_PASS')
    current=runtime_hash(bridge,rust)
    if arm['runtime_contract_sha256']!=current or meta['runtime_contract_sha256']!=current: fail('runtime contract binding mismatch')
    print('SAFEBOX_IOS_EVIDENCE_RUNTIME_BINDING_PASS')
    body=ev_p.read_bytes()
    if len(body)!=int(meta['evidence_bytes']): fail('evidence length mismatch')
    if sha(body)!=str(meta['evidence_sha256']): fail('evidence sha256 mismatch')
    now=int(time.time()); armed=int(meta['armed_unix']); captured=int(meta['captured_unix']); expires=int(meta['expires_unix'])
    if captured<armed or captured>now+MAX_FUTURE_SKEW: fail('capture timestamp invalid')
    if expires!=captured+MAX_AGE_SECONDS: fail('expiry policy mismatch')
    if now>expires: fail('durable evidence expired')
    print('SAFEBOX_IOS_EVIDENCE_EXPIRY_PASS')
    sealed=dict(meta); seal=sealed.pop('manifest_seal_sha256')
    if seal!=sha(canonical(sealed)+body+arm_bytes): fail('manifest seal mismatch')
    print('SAFEBOX_IOS_EVIDENCE_SEAL_PASS'); print('SAFEBOX_IOS_EVIDENCE_FILE_SECURITY_PASS')
if __name__=='__main__': main()
