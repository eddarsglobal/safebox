#!/usr/bin/env python3
from pathlib import Path
import hashlib, re
D = Path(__file__).resolve().parents[1]
DIST = D/'dist'
PUBLIC = D/'public'

def fail(msg):
    print(f'SAFEBOX_WEB_DIST_FAIL: {msg}')
    raise SystemExit(1)

def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
if not (DIST/'index.html').is_file(): fail('dist/index.html missing')
if not (DIST/'app.html').is_file(): fail('dist/app.html missing')
wasm = list(DIST.glob('safebox_core.*.wasm'))
if len(wasm) != 1: fail(f'exactly one content-addressed WASM required, got {len(wasm)}')
if (DIST/'safebox_core.wasm').exists(): fail('unversioned WASM leaked into dist')
wasm_sha = sha(wasm[0])
if sha(PUBLIC/'safebox_core.wasm') != wasm_sha: fail('WASM changed during content-addressed copy')
match = re.fullmatch(r'safebox_core\.([0-9a-f]{12})\.wasm', wasm[0].name)
if not match or not wasm_sha.startswith(match.group(1)): fail('WASM filename hash does not match bytes')
landing_html=(DIST/'index.html').read_text(errors='replace')
html=(DIST/'app.html').read_text(errors='replace')
if re.search(r'''(?:src|href)=["']/''', html): fail('absolute-root asset URL found')
if 'Content-Security-Policy' not in html or "wasm-unsafe-eval" not in html: fail('web CSP meta missing')
if 'name="referrer" content="no-referrer"' not in html: fail('referrer meta missing')
if 'adsbygoogle.js?client=ca-pub-3925930420157238' not in landing_html: fail('AdSense verification code missing from landing')
if 'google-adsense-account" content="ca-pub-3925930420157238' not in landing_html: fail('AdSense verification meta missing from landing')
if 'adsbygoogle.js' in html or 'google-adsense-account' in html: fail('AdSense verification code leaked into crypto app')
if not (DIST/'_headers').is_file(): fail('deployment _headers missing')
js='\n'.join(p.read_text(errors='replace') for p in (DIST/'assets').glob('*.js'))
if wasm[0].name not in js: fail('content-addressed WASM loader reference missing from JS bundle')
if 'SafeBox WebAssembly engine unavailable' not in js: fail('fail-closed Web engine error missing')
if 'Web cryptographic engine is not enabled yet' in js: fail('R67 placeholder leaked into bundle')
print('SAFEBOX_WEB_DIST_WASM_CONTENT_ADDRESS_PASS')
print('SAFEBOX_WEB_DIST_WASM_COPY_PASS')
print('SAFEBOX_WEB_DIST_RELATIVE_ASSETS_PASS')
print('SAFEBOX_WEB_DIST_SECURITY_META_PASS')
print('SAFEBOX_WEB_DIST_ADSENSE_LANDING_ONLY_PASS')
print('SAFEBOX_WEB_DIST_DEPLOY_HEADERS_PASS')
print('SAFEBOX_WEB_DIST_ENGINE_ROUTING_PASS')
print('SAFEBOX_WEB_DIST_PASS')
