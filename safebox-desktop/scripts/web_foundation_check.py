#!/usr/bin/env python3
from pathlib import Path
import json
ROOT = Path(__file__).resolve().parents[2]
D = ROOT/'safebox-desktop'
main=(D/'src/main.ts').read_text()
engine=(D/'src/web-sbx-engine.ts').read_text()
vite=(D/'vite.config.ts').read_text()
pkg=json.loads((D/'package.json').read_text())

def req(cond, marker, detail=''):
    if not cond:
        print(f'{marker.replace("_PASS","_FAIL")}: {detail or "contract mismatch"}')
        raise SystemExit(1)
    print(marker)

req('"__TAURI_INTERNALS__" in window' in main, 'SAFEBOX_WEB_RUNTIME_DETECTION_PASS')
req('platform: "web"' in main and 'dataset.platform = "web"' in main,
    'SAFEBOX_WEB_CAPABILITIES_FALLBACK_PASS')
req('if (!SAFEBOX_TAURI_RUNTIME) return;' in main,
    'SAFEBOX_WEB_NATIVE_EVENT_ISOLATION_PASS')
req('registerBrowserFile' in main and 'picker.type = "file"' in main and 'dataTransfer?.files?.[0]' in main,
    'SAFEBOX_WEB_BROWSER_FILE_INTAKE_PASS')
req('protectWebFile' in main and 'unlockWebFile' in main and 'readWebPublicInfo' in main,
    'SAFEBOX_WEB_CANONICAL_ENGINE_ROUTING_PASS')
req('webCryptoPendingMessage' not in main and 'Web cryptographic engine is not enabled yet' not in main,
    'SAFEBOX_WEB_PLACEHOLDER_REMOVED_PASS')
req('crypto.getRandomValues(entropy)' in engine and 'WEB_WASM_ABI_VERSION = 1' in engine,
    'SAFEBOX_WEB_BROWSER_ENTROPY_PASS')
req('fetch(wasmUrl()' in engine and 'credentials: "same-origin"' in engine and 'http://' not in engine and 'https://' not in engine,
    'SAFEBOX_WEB_LOCAL_WASM_ONLY_PASS')
req('process.env.SAFEBOX_WEB_BASE || "./"' in vite,
    'SAFEBOX_WEB_RELATIVE_STATIC_BASE_PASS')
req('src="/safebox-logo.png"' not in main and 'SAFEBOX_LOGO_URL' in main,
    'SAFEBOX_WEB_SUBPATH_ASSET_PASS')
req(pkg.get('scripts',{}).get('web:build') == 'npm run web:wasm-build && npm run web:ui-build && npm run web:dist-check',
    'SAFEBOX_WEB_BUILD_ENTRYPOINT_PASS')
print('SAFEBOX_WEB_FOUNDATION_PASS')
