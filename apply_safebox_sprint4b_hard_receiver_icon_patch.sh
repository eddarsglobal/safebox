#!/usr/bin/env bash
set -euo pipefail
ROOT="$(pwd)"
if [ ! -d "$ROOT/safebox-desktop" ]; then
  echo "ERROR: Run this script from the safebox_sbx_mvp project root."
  exit 1
fi
cd "$ROOT/safebox-desktop"
cp src/main.ts "src/main.ts.backup-sprint4b.$(date +%Y%m%d%H%M%S)"
cp src/style.css "src/style.css.backup-sprint4b.$(date +%Y%m%d%H%M%S)" 2>/dev/null || true
cp src-tauri/tauri.conf.json "src-tauri/tauri.conf.json.backup-sprint4b.$(date +%Y%m%d%H%M%S)"
python3 - <<'PY2'
from pathlib import Path
p = Path('src/main.ts')
text = p.read_text()
marker = '$("#createBtn").addEventListener("click", async () => {'
if 'function showHardReceiverOverlay' not in text:
    overlay_code = '''
function showHardReceiverOverlay(sbxPath: string) {
  receiverMode = true;
  receiverSbxPath = sbxPath;
  document.body.dataset.safeboxMode = "receiver";

  let overlay = document.querySelector<HTMLDivElement>("#hardReceiverOverlay");
  if (!overlay) {
    overlay = document.createElement("div");
    overlay.id = "hardReceiverOverlay";
    overlay.className = "hard-receiver-overlay";
    document.body.appendChild(overlay);
  }

  const name = fileNameFromPath(sbxPath) || "document.sbx";
  overlay.innerHTML = `
    <div class="hard-receiver-card">
      <div class="hard-receiver-brand">
        <img src="/safebox-logo.png" alt="SafeBox" />
        <h1>SafeBox</h1>
      </div>
      <div class="hard-receiver-file">${esc(name)}</div>
      <label class="hard-receiver-label">
        Enter code
        <input id="hardReceiverCode" type="password" autocomplete="current-password" />
      </label>
      <button id="hardReceiverUnlock" type="button">Unlock</button>
      <button id="hardReceiverInfoBtn" type="button" class="hard-receiver-info-btn">File info</button>
      <div id="hardReceiverInfo" class="hard-receiver-info hidden">
        <div><span>Name</span><code>${esc(name)}</code></div>
        <div><span>Type</span><code>SafeBox File</code></div>
      </div>
      <div id="hardReceiverResult" class="hard-receiver-result hidden"></div>
    </div>`;

  overlay.style.display = "grid";
  const codeInput = overlay.querySelector<HTMLInputElement>("#hardReceiverCode");
  const unlockBtn = overlay.querySelector<HTMLButtonElement>("#hardReceiverUnlock");
  const infoBtn = overlay.querySelector<HTMLButtonElement>("#hardReceiverInfoBtn");
  const infoBox = overlay.querySelector<HTMLDivElement>("#hardReceiverInfo");
  const overlayResult = overlay.querySelector<HTMLDivElement>("#hardReceiverResult");

  const showOverlayResult = (kind: "ok" | "error", html: string) => {
    if (!overlayResult) return;
    overlayResult.className = `hard-receiver-result ${kind}`;
    overlayResult.innerHTML = html;
  };

  const doUnlock = async () => {
    const code = (codeInput?.value || "").trim();
    if (!code) {
      showOverlayResult("error", "<strong>Wrong code</strong>");
      codeInput?.focus();
      return;
    }

    try {
      const report = await invoke<UnlockReport>("unlock_sbx_file", {
        sbxPath,
        code,
        outputDir: null,
        keepSbx: false,
        overwrite: false
      });

      showOverlayResult("ok", `
        <div class="boom-title">BOOOOM</div>
        <strong>Original restored.</strong><br/>
        <span>SBX completed.</span>
        <div class="result-grid compact">
          <span>Original</span><code>${esc(report.original_file_name)}</code>
          <span>Saved</span><code>${esc(report.restored_path)}</code>
        </div>`);
    } catch (_error) {
      showOverlayResult("error", "<strong>Wrong code</strong>");
      codeInput?.select();
      codeInput?.focus();
    }
  };

  unlockBtn?.addEventListener("click", doUnlock);
  codeInput?.addEventListener("keydown", event => {
    if (event.key === "Enter") doUnlock();
  });
  infoBtn?.addEventListener("click", () => infoBox?.classList.toggle("hidden"));
  setTimeout(() => codeInput?.focus(), 80);
}

function hideHardReceiverOverlay() {
  delete document.body.dataset.safeboxMode;
  const overlay = document.querySelector<HTMLDivElement>("#hardReceiverOverlay");
  if (overlay) overlay.style.display = "none";
}
'''
    if marker not in text:
        raise SystemExit('Could not find create button marker in src/main.ts')
    text = text.replace(marker, overlay_code + '\n' + marker)
if 'hideHardReceiverOverlay();\n  receiverMode = false;' not in text:
    text = text.replace(
        'function enterNormalMode(mode: "create" | "unlock" = "create") {\n  receiverMode = false;',
        'function enterNormalMode(mode: "create" | "unlock" = "create") {\n  hideHardReceiverOverlay();\n  receiverMode = false;'
    )
if 'showHardReceiverOverlay(sbxPath);' not in text:
    text = text.replace(
        'function enterReceiverMode(sbxPath: string) {\n  receiverMode = true;',
        'function enterReceiverMode(sbxPath: string) {\n  showHardReceiverOverlay(sbxPath);\n  receiverMode = true;'
    )
text = text.replace(
'''if (isSbx) {
    enterReceiverMode(path);
  } else {
    enterNormalMode("create");
    setInput("#createInput", path);
    showResult("ok", `<strong>Original file selected.</strong><br/><code>${esc(path)}</code>`);
  }''',
'''if (isSbx) {
    enterReceiverMode(path);
    return;
  }

  enterNormalMode("create");
  setInput("#createInput", path);
  showResult("ok", `<strong>Original file selected.</strong><br/><code>${esc(path)}</code>`);'''
)
p.write_text(text)
print('main.ts patched')
PY2
cat >> src/style.css <<'CSS'

/* Sprint 4B — hard receiver overlay: .sbx must never show normal mode */
body[data-safebox-mode="receiver"] #app { filter: blur(2px); pointer-events: none; user-select: none; }
.hard-receiver-overlay { display:none; position:fixed; inset:0; z-index:999999; place-items:center; padding:22px; background:radial-gradient(circle at 50% 18%, rgba(56,189,248,.20), transparent 38%), linear-gradient(135deg,#050B14,#071A33 48%,#0B2D5C); }
.hard-receiver-card { width:min(420px,100%); border:1px solid rgba(167,232,255,.18); border-radius:30px; padding:30px; background:rgba(5,11,20,.82); box-shadow:0 30px 120px rgba(0,0,0,.48); backdrop-filter:blur(18px); color:#F8FBFF; display:grid; gap:18px; text-align:center; }
.hard-receiver-brand { display:grid; place-items:center; gap:12px; }
.hard-receiver-brand img { width:76px; height:76px; border-radius:22px; }
.hard-receiver-brand h1 { margin:0; font-size:clamp(2rem,9vw,3.1rem); line-height:1; letter-spacing:-.05em; }
.hard-receiver-file { color:#8EA7C2; font-weight:800; word-break:break-word; }
.hard-receiver-label { display:grid; gap:8px; text-align:left; font-weight:900; }
.hard-receiver-label input { min-height:58px; border:1px solid rgba(167,232,255,.18); border-radius:18px; padding:0 16px; background:rgba(255,255,255,.07); color:#F8FBFF; text-align:center; font-size:1.15rem; letter-spacing:.08em; outline:none; }
.hard-receiver-label input:focus { border-color:rgba(56,189,248,.8); box-shadow:0 0 0 4px rgba(56,189,248,.16); }
#hardReceiverUnlock { min-height:58px; border:0; border-radius:18px; background:linear-gradient(135deg,#0B5CAD,#38BDF8); color:#F8FBFF; font-weight:950; cursor:pointer; box-shadow:0 16px 40px rgba(56,189,248,.28); }
.hard-receiver-info-btn { border:0; background:transparent; color:#8EA7C2; font-weight:900; cursor:pointer; }
.hard-receiver-info-btn:hover { color:#38BDF8; }
.hard-receiver-info { display:grid; gap:10px; padding:14px; border:1px solid rgba(167,232,255,.16); border-radius:16px; background:rgba(255,255,255,.055); text-align:left; }
.hard-receiver-info > div { display:grid; grid-template-columns:72px minmax(0,1fr); gap:8px; }
.hard-receiver-info span { color:#8EA7C2; font-weight:900; }
.hard-receiver-info code, .hard-receiver-result code { overflow-wrap:anywhere; }
.hard-receiver-result { padding:14px; border-radius:16px; text-align:left; }
.hard-receiver-result.ok { border:1px solid rgba(34,197,94,.32); background:rgba(34,197,94,.12); }
.hard-receiver-result.error { text-align:center; border:1px solid rgba(248,113,113,.36); background:rgba(248,113,113,.13); color:#FECACA; }
@media (max-width:520px){ .hard-receiver-card{ padding:24px; border-radius:26px; } }
CSS
python3 - <<'PY2'
import json
from pathlib import Path
p = Path('src-tauri/tauri.conf.json')
data = json.loads(p.read_text())
bundle = data.setdefault('bundle', {})
bundle['active'] = True
bundle['targets'] = ['app']
bundle['icon'] = ['icons/32x32.png','icons/128x128.png','icons/128x128@2x.png','icons/icon.png']
bundle['fileAssociations'] = [{
    'ext':['sbx'], 'name':'SafeBox File', 'description':'SafeBox secure capsule',
    'mimeType':'application/vnd.safebox.sbx', 'contentTypes':['com.safebox.sbx'],
    'role':'Viewer', 'rank':'Owner',
    'exportedType': {'identifier':'com.safebox.sbx','conformsTo':['public.data']}
}]
p.write_text(json.dumps(data, indent=2)+'\n')
print('tauri.conf.json patched')
PY2
mkdir -p scripts
cat > scripts/apply_macos_sbx_document_icon.sh <<'SH'
#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
APP="$ROOT/target/release/bundle/macos/SafeBox.app"
if [ ! -d "$APP" ]; then echo "ERROR: SafeBox.app not found: $APP"; exit 1; fi
ICON_PNG="$ROOT/safebox-desktop/src-tauri/icons/icon.png"
ICONSET="/tmp/safebox-file.iconset"
ICNS="$APP/Contents/Resources/safebox-file.icns"
INFO="$APP/Contents/Info.plist"
rm -rf "$ICONSET"; mkdir -p "$ICONSET"
for size in 16 32 128 256 512; do sips -z "$size" "$size" "$ICON_PNG" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null; done
sips -z 32 32 "$ICON_PNG" --out "$ICONSET/icon_16x16@2x.png" >/dev/null
sips -z 64 64 "$ICON_PNG" --out "$ICONSET/icon_32x32@2x.png" >/dev/null
sips -z 256 256 "$ICON_PNG" --out "$ICONSET/icon_128x128@2x.png" >/dev/null
sips -z 512 512 "$ICON_PNG" --out "$ICONSET/icon_256x256@2x.png" >/dev/null
sips -z 1024 1024 "$ICON_PNG" --out "$ICONSET/icon_512x512@2x.png" >/dev/null
iconutil -c icns "$ICONSET" -o "$ICNS"
if /usr/libexec/PlistBuddy -c "Print :CFBundleDocumentTypes:0" "$INFO" >/dev/null 2>&1; then
  /usr/libexec/PlistBuddy -c "Set :CFBundleDocumentTypes:0:CFBundleTypeIconFile safebox-file" "$INFO" 2>/dev/null || /usr/libexec/PlistBuddy -c "Add :CFBundleDocumentTypes:0:CFBundleTypeIconFile string safebox-file" "$INFO"
fi
touch "$APP"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
if [ -x "$LSREGISTER" ]; then "$LSREGISTER" -f "$APP" >/dev/null 2>&1 || true; fi
qlmanage -r >/dev/null 2>&1 || true
qlmanage -r cache >/dev/null 2>&1 || true
killall Finder >/dev/null 2>&1 || true
echo "SBX document icon applied to: $APP"
SH
chmod +x scripts/apply_macos_sbx_document_icon.sh
echo "Sprint 4B patch applied."
