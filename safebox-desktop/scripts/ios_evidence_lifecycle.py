#!/usr/bin/env python3
import hashlib, json, os, stat, sys, tempfile, time
from pathlib import Path
SCHEMA=1
MAX_AGE=86400
SKEW=300

def fail(msg): raise SystemExit(msg)
def canonical(o): return (json.dumps(o,sort_keys=True,separators=(',',':'))+'\n').encode()
def sha(b): return hashlib.sha256(b).hexdigest()
def secure_regular(p, required=True):
    try: st=p.lstat()
    except FileNotFoundError:
        if required: fail(f'missing {p.name}')
        return None
    if stat.S_ISLNK(st.st_mode) or not stat.S_ISREG(st.st_mode): fail(f'unsafe file type: {p.name}')
    if st.st_uid!=os.getuid(): fail(f'owner mismatch: {p.name}')
    if st.st_mode & 0o077: fail(f'permissions too broad: {p.name}')
    if st.st_nlink!=1: fail(f'unexpected hardlink count: {p.name}')
    return st

def loadj(p,what):
    try: return json.loads(p.read_text())
    except Exception as e: fail(f'invalid {what}: {e}')

def fsync_dir(path):
    fd=os.open(str(path),os.O_RDONLY)
    try: os.fsync(fd)
    finally: os.close(fd)

def atomic_write(path,data):
    fd,tmp=tempfile.mkstemp(prefix='.safebox-consumed-',dir=path.parent)
    try:
        os.fchmod(fd,0o600)
        with os.fdopen(fd,'wb') as out:
            out.write(data); out.flush(); os.fsync(out.fileno())
        os.replace(tmp,path); os.chmod(path,0o600); fsync_dir(path.parent)
    finally:
        if os.path.exists(tmp): os.unlink(tmp)

def runtime_hash(bridge,rust):
    h=hashlib.sha256()
    for label,p in ((b'SafeBoxShareInboxBridge.mm\0',bridge),(b'lib.rs\0',rust)):
        h.update(label); h.update(p.read_bytes()); h.update(b'\0')
    return h.hexdigest()

def validate_source_binding(arm,pkg,current_runtime,route):
    if arm.get('expected_route')!=route: fail('receipt route mismatch')
    if arm.get('package_id')!=pkg: fail('arm package mismatch')
    if arm.get('runtime_contract_sha256')!=current_runtime: fail('arm runtime mismatch')

def verify_receipt(r,arm,pkg,current_runtime,route):
    req=('schema_version','device_udid','bundle_id','process_name','armed_at','armed_unix','expected_route','package_id','runtime_contract_sha256','arm_sha256','evidence_sha256','manifest_seal_sha256','old_pid','new_pid','captured_unix','consumed_unix','expires_unix','receipt_seal_sha256')
    for k in req:
        if r.get(k) in (None,''): fail(f'receipt missing {k}')
    if int(r['schema_version'])!=SCHEMA: fail('receipt schema mismatch')
    for k in ('device_udid','bundle_id','process_name','armed_at','armed_unix','expected_route','package_id','runtime_contract_sha256'):
        if str(r[k])!=str(arm[k]): fail(f'receipt/arm mismatch: {k}')
    if r['expected_route']!=route or r['package_id']!=pkg or r['runtime_contract_sha256']!=current_runtime: fail('receipt source binding mismatch')
    now=int(time.time()); captured=int(r['captured_unix']); consumed=int(r['consumed_unix']); expires=int(r['expires_unix'])
    if consumed<captured or consumed>now+SKEW: fail('receipt consumption timestamp invalid')
    if expires!=consumed+MAX_AGE or now>expires: fail('receipt expiry invalid')
    unsigned=dict(r); seal=unsigned.pop('receipt_seal_sha256')
    if seal!=sha(canonical(unsigned)+canonical(arm)): fail('receipt seal mismatch')

def main():
    if len(sys.argv)<2: fail('usage: lifecycle consume|verify|reset ...')
    cmd=sys.argv[1]
    if cmd=='reset':
        if len(sys.argv)!=6: fail('usage: lifecycle reset ARM META EVIDENCE RECEIPT')
        arm,meta,ev,receipt=map(Path,sys.argv[2:])
        for p in (meta,ev,receipt):
            if secure_regular(p,False) is not None: p.unlink()
        fsync_dir(arm.parent)
        print('SAFEBOX_IOS_EVIDENCE_ROTATION_RESET_PASS')
        return
    if len(sys.argv)!=10: fail('usage: lifecycle consume|verify ARM META EVIDENCE RECEIPT PACKAGE BRIDGE RUST ROUTE')
    arm_p,meta_p,ev_p,receipt_p,pkg_p,bridge_p,rust_p=map(Path,sys.argv[2:9]); route=sys.argv[9]
    secure_regular(arm_p); arm=loadj(arm_p,'arm metadata'); pkg=pkg_p.read_text().strip(); current_runtime=runtime_hash(bridge_p,rust_p)
    validate_source_binding(arm,pkg,current_runtime,route)
    if cmd=='consume':
        if secure_regular(receipt_p,False) is not None: fail('evidence already consumed')
        secure_regular(meta_p); secure_regular(ev_p); meta=loadj(meta_p,'evidence metadata')
        now=int(time.time())
        r={'schema_version':SCHEMA,'device_udid':arm['device_udid'],'bundle_id':arm['bundle_id'],'process_name':arm['process_name'],'armed_at':arm['armed_at'],'armed_unix':int(arm['armed_unix']),'expected_route':arm['expected_route'],'package_id':arm['package_id'],'runtime_contract_sha256':arm['runtime_contract_sha256'],'arm_sha256':meta['arm_sha256'],'evidence_sha256':meta['evidence_sha256'],'manifest_seal_sha256':meta['manifest_seal_sha256'],'old_pid':int(meta['old_pid']),'new_pid':int(meta['new_pid']),'captured_unix':int(meta['captured_unix']),'consumed_unix':now,'expires_unix':now+MAX_AGE}
        r['receipt_seal_sha256']=sha(canonical(r)+canonical(arm))
        atomic_write(receipt_p,canonical(r))
        # Commit point is the receipt. If retirement is interrupted, reuse remains blocked.
        ev_p.unlink(); meta_p.unlink(); fsync_dir(ev_p.parent)
        print('SAFEBOX_IOS_EVIDENCE_CONSUMED_RECEIPT_PASS')
        print('SAFEBOX_IOS_EVIDENCE_RETIREMENT_PASS')
        return
    if cmd=='verify':
        secure_regular(receipt_p)
        if secure_regular(meta_p,False) is not None or secure_regular(ev_p,False) is not None: fail('retired evidence still present')
        r=loadj(receipt_p,'consumed receipt'); verify_receipt(r,arm,pkg,current_runtime,route)
        print('SAFEBOX_IOS_EVIDENCE_CONSUMED_RECEIPT_PASS')
        print('SAFEBOX_IOS_EVIDENCE_RETIREMENT_PASS')
        print('SAFEBOX_IOS_EVIDENCE_SINGLE_USE_PASS')
        return
    fail('unknown lifecycle command')
if __name__=='__main__': main()
