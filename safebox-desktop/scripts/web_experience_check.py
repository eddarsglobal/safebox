#!/usr/bin/env python3
from pathlib import Path
import hashlib, re
D=Path(__file__).resolve().parents[1]; ROOT=D.parent

def fail(m): print(f"SAFEBOX_WEB_EXPERIENCE_CHECK_FAIL: {m}"); raise SystemExit(1)
def need(p,t):
    if not p.is_file() or t not in p.read_text(errors="replace"): fail(f"{p}: missing {t}")
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
landing=D/'src/landing.ts'; css=D/'src/landing.css'; app=D/'app.html'; manifest=D/'public/manifest.webmanifest'; ads=D/'ADS_ACTIVATION.md'
for p in (landing,css,app,manifest,ads):
    if not p.is_file(): fail(f"missing {p}")
for t in ('PDF','MP4','EXE','ZIP','JPG','DOCX','APK','SQL','.SBX','matrix-col','extension-cloud','extension-token','crypto-story','--p','requestAnimationFrame'):
    need(landing if t not in ('crypto-story','--p') else css,t)
print('SAFEBOX_LANDING_SCROLL_CRYPTO_STORY_PASS')
for t in ('motion-scope','motionScopes','querySelectorAll<HTMLElement>("*")','--motion-x','--motion-y','--motion-r','--motion-s','heroSection','promiseSection','downloadsSection'):
    need(landing if t in ('motion-scope','motionScopes','querySelectorAll<HTMLElement>("*")','heroSection','promiseSection','downloadsSection') else css,t)
print('SAFEBOX_LANDING_ALL_DESCENDANTS_SCROLL_MOTION_PASS')
for t in ('DOCX','XLSX','PPTX','PSD','RAW','MKV','FLAC','SQL','APK','IPA','STL','OBJ','BLEND','extensionSizes','52,46','4,3,2,1'):
    need(landing,t)
print('SAFEBOX_LANDING_ANY_EXTENSION_DEPTH_CLOUD_PASS')
for t in ('--accent:#118cf0','--accent2:#72c9ff','--accent3:#0a4dbe','--deep:#06164f','var(--blue-glow)'):
    need(css,t)
print('SAFEBOX_LANDING_SAFEBOX_BLUE_PALETTE_PASS')
for t in ('"en"','"fr"','"it"','"pt"','"ar"','"de"','"es"','"hr"','navigator.languages','document.documentElement.dir'):
    need(landing,t)
print('SAFEBOX_LANDING_I18N_BROWSER_DETECTION_RTL_PASS')
for t in ('system','dark','light','prefers-color-scheme','max-width:780px','max-width:420px','prefers-reduced-motion'):
    need(css if 'max-width' in t or 'prefers' in t else landing,t)
print('SAFEBOX_LANDING_THEME_MOBILE_ACCESSIBILITY_PASS')
for name in ('legal','privacy','terms','cookies','licenses'):
    p=D/f'public/legal/{name}.html'
    if not p.is_file(): fail(f'missing legal page {name}')
need(D/'public/legal/legal.html','Mr Eddars Noureddine, Zurich, Switzerland')
need(D/'public/legal/privacy.html','minimise data collection')
need(D/'public/legal/cookies.html','Google advertising is disabled by default')
print('SAFEBOX_LEGAL_SURFACE_PASS')
need(landing,'id="landing-ad"'); need(ads,'Google AdSense'); need(ads,'Google AdMob'); need(ads,'OFF by default')
print('SAFEBOX_ADS_DISABLED_BY_DEFAULT_ACTIVATION_GUIDE_PASS')
need(manifest,'"display": "standalone"'); need(landing,'iPhone / iPad'); need(landing,'Android APK')
print('SAFEBOX_ZERO_COST_MOBILE_DISTRIBUTION_SURFACE_PASS')
for t in ('height:270svh','--output','story-outcome','ONE .SBX','resultLocal','resultEncrypted','resultPortable','data-i=\"resultLocal\"','data-i=\"resultEncrypted\"','data-i=\"resultPortable\"'):
    need(css if t in ('height:270svh','--output') else landing,t)
print('SAFEBOX_LANDING_CRYPTO_FINALE_HOLD_PASS')
for t in ('textLike','amp=textLike ? 1.6 : 7.5','grid-template-rows:145px minmax(0,1fr)','download-copy'):
    need(landing if t in ('textLike','amp=textLike ? 1.6 : 7.5') else css,t)
print('SAFEBOX_LANDING_TEXT_COLLISION_GUARD_PASS')
need(landing,'id="adShell" aria-label="Advertisement" hidden')
need(css,'.ad-shell[hidden]{display:none!important}')
print('SAFEBOX_LANDING_AD_DISABLED_NO_DEAD_SPACE_PASS')
for t in ('AEAD','XCHACHA20','ARGON2 · LOCAL'):
    need(landing,t)
print('SAFEBOX_LANDING_CRYPTO_LABEL_ACCURACY_PASS')
need(landing,'https://x.com/EddarsStudio')
need(css,'.creator-x')
print('SAFEBOX_LANDING_CREATOR_X_LINK_PASS')
# Crypto boundary remains byte-identical to R81; main.ts is pinned to the reviewed R86 RC8 unified-preferences/i18n/design surface.
expected={
 ROOT/'safebox-core/src/crypto.rs':'1d75fe23895cb0196fb7ff5b369c59596c300a3bd3eb5a07395d3287f925b670',
 ROOT/'safebox-core/src/format.rs':'26edb67b2be91ff5c7d765e100e4aafa5e50933919c0db2e4370901f67205ea1',
 ROOT/'safebox-web-wasm/src/lib.rs':'d5e65323c3d87b02b2f8958d8edc4dfddf500a9787fdf4377080c5092d9ea4c3',
 D/'src/web-sbx-engine.ts':'7396fa6f0cef79a7c6a425258ca117ed67543e19b7b9f8a104b6f26506ba9b8d',
 D/'src/main.ts':'b4a161bdd4b9318f05b5fae4916ddcacb0bc3f83e0404be1f0199b9f0e20df36'
}
for p,h in expected.items():
    if sha(p)!=h: fail(f'validated runtime changed: {p}')
print('SAFEBOX_R81_CRYPTO_RUNTIME_UNCHANGED_PASS')
print('SAFEBOX_WEB_IMMERSIVE_EXPERIENCE_PASS')
