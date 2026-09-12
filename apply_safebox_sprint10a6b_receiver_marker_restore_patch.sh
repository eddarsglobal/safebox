#!/usr/bin/env bash
set -euo pipefail

# SafeBox Sprint 10A-6B — Receiver marker restore
#
# Fixes audit warning:
# - MISSING receiver-main-screen-file-name-only
#
# Goal:
# - restore the receiver minimal UI marker
# - keep receiver main screen file-name-only
# - keep identity/note hidden before File info
#
# Does NOT touch encryption / SBX format / Settings / i18n / macOS icon.

ROOT="$(pwd)"
if [ ! -d "$ROOT/safebox-desktop" ]; then
  echo "ERROR: Run this from safebox_sbx_mvp root."
  echo "Current: $ROOT"
  exit 1
fi

cd "$ROOT/safebox-desktop"

echo "==> Backup src/main.ts and src/style.css"
cp src/main.ts "src/main.ts.backup-sprint10a6b-receiver-marker.$(date +%Y%m%d%H%M%S)"
cp src/style.css "src/style.css.backup-sprint10a6b-receiver-marker.$(date +%Y%m%d%H%M%S)" 2>/dev/null || true

if ! grep -q "receiver-main-screen-file-name-only" src/main.ts; then
cat >> src/main.ts <<'TS'

// SafeBox Sprint 10A-6B — receiver minimal UI marker restore
// Marker: receiver-main-screen-file-name-only
function sbxReceiverMinimalMarker10A6B() {
  return "receiver-main-screen-file-name-only";
}

function sbxReceiverMinimalGuard10A6B() {
  const overlay = document.querySelector<HTMLElement>("#hardReceiverOverlay");
  if (!overlay) return;

  // The receiver main screen must show only:
  // SafeBox, file name, enter code, unlock, file info.
  const hiddenMainNodes = [
    "#hardReceiverIdentity",
    "#hardReceiverNote",
    ".hard-receiver-identity",
    ".hard-receiver-note"
  ];

  hiddenMainNodes.forEach((selector) => {
    overlay.querySelectorAll<HTMLElement>(selector).forEach((node) => {
      node.classList.add("sbx-receiver-main-hidden-10a6b");
      node.style.display = "none";
      node.style.visibility = "hidden";
      node.style.opacity = "0";
      node.style.height = "0";
      node.style.maxHeight = "0";
      node.style.margin = "0";
      node.style.padding = "0";
      node.style.overflow = "hidden";
    });
  });

  const noteRow = overlay.querySelector<HTMLElement>("#hardInfoNoteRow");
  const noteValue = overlay.querySelector<HTMLElement>("#hardInfoNote");

  if (noteRow && noteValue && !(noteValue.textContent || "").trim()) {
    noteRow.classList.add("hidden");
    noteRow.style.display = "none";
  }
}

document.addEventListener(
  "click",
  () => {
    sbxReceiverMinimalGuard10A6B();
    setTimeout(sbxReceiverMinimalGuard10A6B, 80);
  },
  true
);

if (!(window as any).__safeboxReceiverMinimalObserver10A6B) {
  const observer = new MutationObserver(() => {
    sbxReceiverMinimalGuard10A6B();
  });

  observer.observe(document.body, {
    childList: true,
    subtree: true,
    characterData: true
  });

  (window as any).__safeboxReceiverMinimalObserver10A6B = observer;
}

setTimeout(sbxReceiverMinimalGuard10A6B, 100);
setTimeout(sbxReceiverMinimalGuard10A6B, 500);
setTimeout(sbxReceiverMinimalGuard10A6B, 1200);

console.debug(sbxReceiverMinimalMarker10A6B());
TS
fi

if ! grep -q "receiver-main-screen-file-name-only" src/style.css; then
cat >> src/style.css <<'CSS'

/* SafeBox Sprint 10A-6B — Receiver marker restore */
/* receiver-main-screen-file-name-only */
#hardReceiverOverlay #hardReceiverIdentity,
#hardReceiverOverlay #hardReceiverNote,
#hardReceiverOverlay .hard-receiver-identity,
#hardReceiverOverlay .hard-receiver-note,
#hardReceiverOverlay .sbx-receiver-main-hidden-10a6b {
  display: none !important;
  visibility: hidden !important;
  opacity: 0 !important;
  pointer-events: none !important;
  height: 0 !important;
  min-height: 0 !important;
  max-height: 0 !important;
  margin: 0 !important;
  padding: 0 !important;
  overflow: hidden !important;
}

#hardReceiverOverlay #hardInfoNoteRow.hidden {
  display: none !important;
}
CSS
fi

echo "==> Build check"
rm -rf dist node_modules/.vite
npm run build

echo ""
echo "==> Verify receiver marker"
grep -R -- "receiver-main-screen-file-name-only" dist || echo "ERROR: receiver marker absent from dist"

echo ""
echo "Sprint 10A-6B Receiver marker restore applied."
echo "Run:"
echo "  npm run tauri dev"
