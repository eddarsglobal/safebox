#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
D="$ROOT/safebox-desktop"

python3 - "$ROOT" <<'PY'
from pathlib import Path
import hashlib, re, sys
ROOT=Path(sys.argv[1]); D=ROOT/'safebox-desktop'
landing=(D/'src/landing.ts').read_text()
main=(D/'src/main.ts').read_text()
css=(D/'src/style.css').read_text()
landing_css=(D/'src/landing.css').read_text()
legal=(D/'public/legal/legal.js').read_text()
legal_init=(D/'public/legal/legal-theme-init.js').read_text()
legal_css=(D/'public/legal/legal.css').read_text()

def fail(msg):
    print('SAFEBOX_R86_RC8_VERIFY_FAIL:',msg,file=sys.stderr); raise SystemExit(1)
def need(text, token, label):
    if token not in text: fail(f'{label} missing {token!r}')

def sha(rel): return hashlib.sha256((ROOT/rel).read_bytes()).hexdigest()

# 1 — one canonical language preference across landing, crypto app and legal pages.
for text,label in ((landing,'landing'),(main,'app'),(legal,'legal')):
    need(text,'safebox.language.v1',label)
need(landing,'safebox.lang','landing legacy language migration')
need(main,'safebox.lang','app legacy language migration')
need(legal,'safebox.lang','legal legacy language migration')
for locale in ('en','fr','it','pt','ar','de','es','hr'):
    if locale not in landing or locale not in main or locale not in legal: fail(f'locale {locale} missing from unified language surface')
need(main,'SBX_RC8_STATUS_I18N','app translation closure')
need(main,'sbxPersistSharedLanguage','app shared language persistence')
need(landing,'SAFEBOX_SHARED_LANGUAGE_KEY','landing shared language persistence')
print('SAFEBOX_R86_RC8_UNIFIED_LANGUAGE_PASS')

# 2 — one canonical theme preference, System resolves to actual light/dark everywhere.
for text,label in ((landing,'landing'),(main,'app'),(legal,'legal'),(legal_init,'legal preflight')):
    need(text,'safebox-theme-mode.v1',label)
need(legal_init,'matchMedia("(prefers-color-scheme: dark)")','legal system resolver')
need(legal_init,'dataset.theme = resolved','legal resolved theme preflight')
need(legal,'systemDark.addEventListener','legal live system theme')
need(legal_css,':root[data-theme="light"]','legal light palette')
need(legal_css,':root[data-theme="dark"]','legal dark palette')
for name in ('legal.html','privacy.html','terms.html','cookies.html','licenses.html'):
    t=(D/'public/legal'/name).read_text()
    need(t,'<script src="./legal-theme-init.js"></script>',name)
    if t.index('legal-theme-init.js') > t.index('legal.css'): fail(f'{name}: theme preflight must execute before CSS')
print('SAFEBOX_R86_RC8_UNIFIED_THEME_LEGAL_PASS')

# 3 — high-importance design council surface + explicit light-mode strengthening.
need(css,'SafeBox R86 RC8 — High-Importance Application Design Council boost','app design council marker')
need(main,'Secure local workspace','secure workspace banner')
need(main,'LOCAL · AEAD · SBX1','security proof line')
need(css,':root[data-theme="light"]','app light-mode design')
need(landing_css,'SafeBox R86 RC8 — unified preference and i18n surface polish','landing design marker')
print('SAFEBOX_R86_RC8_HIGH_IMPORTANCE_DESIGN_PASS')

# 4 — urgent visible-text coverage: any English-looking static UI text/placeholder/aria label
# must have an explicit dictionary/variant occurrence, except immutable protocol/brand/unit labels.
items=[]
for m in re.finditer(r'>([^<>\n]{2,140})<', main):
    t=re.sub(r'\$\{[^}]*\}','',m.group(1)).strip(); t=re.sub(r'\s+',' ',t)
    if t and re.search(r'[A-Za-z]{2,}',t) and not any(x in t for x in ('querySelector','closest','join("")')):
        items.append(t)
for a in ('placeholder','title','aria-label'):
    for m in re.finditer(rf'{a}=["\']([^"\']+)["\']',main):
        t=m.group(1).strip()
        if re.search(r'[A-Za-z]{2,}',t): items.append(t)
allow={'SafeBox','LOCAL · AEAD · SBX1','Rust/WASM · canonical SBX1','bytes','BOOOOM','English','Français','Deutsch','Hrvatski / BCS','Español','Italiano','Português'}
missing=[]
for t in dict.fromkeys(items):
    if t in allow: continue
    dq='"'+t.replace('"','\\"')+'"'; sq="'"+t.replace("'","\\'")+"'"
    if dq not in main and sq not in main: missing.append(t)
if missing: fail('visible translation map gaps: '+', '.join(missing[:12]))
need(main,'"visible in File info": "visibleInFileInfo"','placeholder translation')
need(main,'"Could not open the file picker.": "pickerFailed"','picker translation')
need(main,'"Settings saved.": "settingsSaved"','async status translation')
# result-grid labels may translate, but code/path values remain protected by the <code> exclusion.
if 'parent.closest(".result-grid")' in main: fail('result-grid label translation is still disabled')
need(main,'parent.closest("code")','dynamic path/code translation protection')
print('SAFEBOX_R86_RC8_TRANSLATION_CLOSURE_PASS')

# 5 — crypto/native core is byte-identical to the validated RC7 baseline.
expected={
 'safebox-core/src/crypto.rs':'1d75fe23895cb0196fb7ff5b369c59596c300a3bd3eb5a07395d3287f925b670',
 'safebox-core/src/format.rs':'26edb67b2be91ff5c7d765e100e4aafa5e50933919c0db2e4370901f67205ea1',
 'safebox-core/src/memory.rs':'2ed3cc0f1b91e3815c9fcffdec5aa3c423a481f798c2fc8521b0039a828957ef',
 'safebox-web-wasm/src/lib.rs':'d5e65323c3d87b02b2f8958d8edc4dfddf500a9787fdf4377080c5092d9ea4c3',
 'safebox-desktop/src/web-sbx-engine.ts':'7396fa6f0cef79a7c6a425258ca117ed67543e19b7b9f8a104b6f26506ba9b8d',
 'safebox-desktop/src-tauri/src/lib.rs':'5a4bc10bc1d362a0737c0da2b0b6caad00436206137fd0fc800e2b842c57f297',
}
for rel,digest in expected.items():
    got=sha(rel)
    if got!=digest: fail(f'protected runtime changed: {rel} {got}')
print('SAFEBOX_R86_RC8_PROTECTED_CRYPTO_NATIVE_RUNTIME_UNCHANGED_PASS')

# 6 — web deployment gate updated only to pin the reviewed RC8 UI shell and new legal preflight asset.
main_hash=hashlib.sha256((D/'src/main.ts').read_bytes()).hexdigest()
for name in ('web_experience_check.py','web_deployment_check.py'):
    t=(D/'scripts'/name).read_text()
    need(t,main_hash,name)
bundle=(D/'scripts/web_deploy_bundle.py').read_text()
need(bundle,'legal-theme-init.js','web deploy legal preflight allowlist')
need(bundle,'R86_RC8_UNIFIED_PREFS_I18N_DESIGN','web RC8 bundle naming')
need((D/'scripts/web_rc8_release.sh').read_text(),'SAFEBOX_WEB_RC8_RELEASE_PASS','web RC8 release script')
print('SAFEBOX_R86_RC8_WEB_RELEASE_GATE_ALIGNMENT_PASS')
PY

if command -v node >/dev/null 2>&1; then
  node --experimental-strip-types --check "$D/src/main.ts"
  node --experimental-strip-types --check "$D/src/landing.ts"
  echo SAFEBOX_R86_RC8_TYPESCRIPT_SYNTAX_PASS
else
  echo SAFEBOX_R86_RC8_TYPESCRIPT_SYNTAX_SKIPPED_NO_NODE
fi

echo SAFEBOX_V029_UNIFIED_PREFERENCES_I18N_DESIGN_R86_RC8_PASS
