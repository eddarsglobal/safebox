#!/usr/bin/env bash
set -euo pipefail

# SafeBox Sprint 10A-5 — Scroll / Modal State cleanup
#
# Goal:
# - No background scroll while Settings / Help / Profile Editor / Receiver is open.
# - Scroll stays inside the active modal.
# - Main page scroll returns when no modal is open.
# - Avoid body/html overflow conflicts from older hotfixes.
#
# Does NOT touch encryption / SBX format / receiver unlock logic / macOS icon.

ROOT="$(pwd)"
if [ ! -d "$ROOT/safebox-desktop" ]; then
  echo "ERROR: Run this from safebox_sbx_mvp root."
  echo "Current: $ROOT"
  exit 1
fi

cd "$ROOT/safebox-desktop"

echo "==> Backup src/main.ts and src/style.css"
cp src/main.ts "src/main.ts.backup-sprint10a5-scroll-modal.$(date +%Y%m%d%H%M%S)"
cp src/style.css "src/style.css.backup-sprint10a5-scroll-modal.$(date +%Y%m%d%H%M%S)" 2>/dev/null || true

if ! grep -q "sprint10a5-scroll-modal-state-v1" src/main.ts; then
cat >> src/main.ts <<'TS'

// SafeBox Sprint 10A-5 — final scroll / modal state controller
// Marker: sprint10a5-scroll-modal-state-v1
function sbxIsVisibleElement10A5(selector: string) {
  const element = document.querySelector<HTMLElement>(selector);

  if (!element) return false;

  const style = window.getComputedStyle(element);

  return (
    !element.classList.contains("hidden") &&
    style.display !== "none" &&
    style.visibility !== "hidden" &&
    style.opacity !== "0"
  );
}

function sbxAnyModalOpen10A5() {
  return (
    sbxIsVisibleElement10A5("#settingsModal") ||
    sbxIsVisibleElement10A5("#howToUseModal") ||
    sbxIsVisibleElement10A5("#helpModal") ||
    sbxIsVisibleElement10A5("#accessProfileEditorModal") ||
    sbxIsVisibleElement10A5("#hardReceiverOverlay")
  );
}

function sbxNormalizeModalScrollTargets10A5() {
  const settings = document.querySelector<HTMLElement>("#settingsModal");

  if (settings && sbxIsVisibleElement10A5("#settingsModal")) {
    settings.classList.add("sbx-scroll-managed-modal-10a5");

    const activePanel = settings.querySelector<HTMLElement>(".settings-tab-panel.active");

    if (activePanel) {
      activePanel.classList.add("sbx-scroll-inside-10a5");
    }
  }

  const howTo = document.querySelector<HTMLElement>("#howToUseModal");

  if (howTo && sbxIsVisibleElement10A5("#howToUseModal")) {
    howTo.classList.add("sbx-scroll-managed-modal-10a5");

    const scrollBody =
      howTo.querySelector<HTMLElement>(".how-to-use-body") ||
      howTo.querySelector<HTMLElement>(".help-content") ||
      howTo.querySelector<HTMLElement>(".modal-body");

    if (scrollBody) {
      scrollBody.classList.add("sbx-scroll-inside-10a5");
    }
  }

  const profileEditor = document.querySelector<HTMLElement>("#accessProfileEditorModal");

  if (profileEditor && sbxIsVisibleElement10A5("#accessProfileEditorModal")) {
    profileEditor.classList.add("sbx-scroll-managed-modal-10a5");

    const scrollBody =
      profileEditor.querySelector<HTMLElement>(".access-profile-editor-body") ||
      profileEditor.querySelector<HTMLElement>(".modal-body");

    if (scrollBody) {
      scrollBody.classList.add("sbx-scroll-inside-10a5");
    }
  }
}

function sbxApplyScrollModalState10A5() {
  const modalOpen = sbxAnyModalOpen10A5();

  document.documentElement.classList.add("sbx-scroll-root-10a5");
  document.body.classList.add("sbx-scroll-body-10a5");

  document.documentElement.classList.toggle("sbx-modal-open-10a5", modalOpen);
  document.body.classList.toggle("sbx-modal-open-10a5", modalOpen);

  document.documentElement.classList.toggle("sbx-no-modal-10a5", !modalOpen);
  document.body.classList.toggle("sbx-no-modal-10a5", !modalOpen);

  if (modalOpen) {
    document.body.classList.add("sbx-settings-open");

    document.documentElement.style.overflowY = "hidden";
    document.documentElement.style.overflowX = "hidden";
    document.body.style.overflowY = "hidden";
    document.body.style.overflowX = "hidden";
  } else {
    document.body.classList.remove("sbx-settings-open");

    document.documentElement.style.overflowY = "scroll";
    document.documentElement.style.overflowX = "hidden";
    document.body.style.overflowY = "scroll";
    document.body.style.overflowX = "hidden";
  }

  sbxNormalizeModalScrollTargets10A5();
}

function sbxScheduleScrollModalState10A5() {
  requestAnimationFrame(() => {
    sbxApplyScrollModalState10A5();
  });
}

window.addEventListener("resize", sbxScheduleScrollModalState10A5);
window.addEventListener("orientationchange", sbxScheduleScrollModalState10A5);

document.addEventListener(
  "click",
  () => {
    sbxApplyScrollModalState10A5();
    setTimeout(sbxApplyScrollModalState10A5, 30);
    setTimeout(sbxApplyScrollModalState10A5, 140);
    setTimeout(sbxApplyScrollModalState10A5, 360);
  },
  true
);

document.addEventListener("keydown", (event) => {
  if (event.key === "Escape") {
    setTimeout(sbxApplyScrollModalState10A5, 30);
    setTimeout(sbxApplyScrollModalState10A5, 140);
  }
});

if (!(window as any).__safeboxScrollModalObserver10A5) {
  const observer = new MutationObserver(() => {
    sbxScheduleScrollModalState10A5();
  });

  observer.observe(document.body, {
    attributes: true,
    childList: true,
    subtree: true,
    attributeFilter: ["class", "style", "hidden"]
  });

  (window as any).__safeboxScrollModalObserver10A5 = observer;
}

setTimeout(sbxApplyScrollModalState10A5, 50);
setTimeout(sbxApplyScrollModalState10A5, 250);
setTimeout(sbxApplyScrollModalState10A5, 900);
setInterval(sbxApplyScrollModalState10A5, 1200);

console.debug("sprint10a5-scroll-modal-state-v1");
TS
fi

if ! grep -q "sprint10a5-scroll-modal-state-v1" src/style.css; then
cat >> src/style.css <<'CSS'

/* SafeBox Sprint 10A-5 — Scroll / Modal State cleanup */
:root {
  --sprint10a5-scroll-modal-state-v1: 1;
}

html.sbx-scroll-root-10a5,
body.sbx-scroll-body-10a5 {
  min-height: 100% !important;
  overflow-x: hidden !important;
}

html.sbx-no-modal-10a5,
body.sbx-no-modal-10a5 {
  overflow-y: scroll !important;
  scrollbar-gutter: stable !important;
}

html.sbx-modal-open-10a5,
body.sbx-modal-open-10a5 {
  overflow: hidden !important;
  overscroll-behavior: none !important;
}

/* Keep modal overlays fixed and prevent background scroll leaks. */
#settingsModal.sbx-scroll-managed-modal-10a5,
#howToUseModal.sbx-scroll-managed-modal-10a5,
#helpModal.sbx-scroll-managed-modal-10a5,
#accessProfileEditorModal.sbx-scroll-managed-modal-10a5 {
  position: fixed !important;
  inset: 0 !important;
  overflow: hidden !important;
  overscroll-behavior: none !important;
}

/* Internal scroll zones only. */
.sbx-scroll-inside-10a5 {
  overflow-y: auto !important;
  overflow-x: hidden !important;
  overscroll-behavior: contain !important;
  scrollbar-gutter: stable !important;
}

/* Settings: active panel is the scroll zone. */
#settingsModal .settings-tab-panel.active.sbx-scroll-inside-10a5 {
  overflow-y: auto !important;
  overflow-x: hidden !important;
}

/* Help / How To: body is the scroll zone. */
#howToUseModal .how-to-use-body.sbx-scroll-inside-10a5,
#howToUseModal .help-content.sbx-scroll-inside-10a5,
#helpModal .help-content.sbx-scroll-inside-10a5 {
  max-height: min(62vh, 620px) !important;
}

/* Profile editor: body is the scroll zone if the window is small. */
#accessProfileEditorModal .access-profile-editor-body.sbx-scroll-inside-10a5 {
  max-height: min(58vh, 520px) !important;
}

/* Better scrollbars for modal internals. */
.sbx-scroll-inside-10a5::-webkit-scrollbar {
  width: 10px !important;
}

.sbx-scroll-inside-10a5::-webkit-scrollbar-thumb {
  background: rgba(150, 170, 195, 0.42) !important;
  border-radius: 999px !important;
}

.sbx-scroll-inside-10a5::-webkit-scrollbar-track {
  background: transparent !important;
}

@media (max-width: 760px), (max-height: 760px) {
  #howToUseModal .how-to-use-body.sbx-scroll-inside-10a5,
  #howToUseModal .help-content.sbx-scroll-inside-10a5,
  #helpModal .help-content.sbx-scroll-inside-10a5 {
    max-height: calc(100vh - 190px) !important;
  }

  #accessProfileEditorModal .access-profile-editor-body.sbx-scroll-inside-10a5 {
    max-height: calc(100vh - 210px) !important;
  }
}
CSS
fi

echo "==> Build check"
rm -rf dist node_modules/.vite
npm run build

echo ""
echo "==> Verify Sprint 10A-5 marker"
grep -R -- "sprint10a5-scroll-modal-state-v1" dist || echo "ERROR: Sprint 10A-5 marker absent from dist"

echo ""
echo "Sprint 10A-5 Scroll / Modal State cleanup applied."
echo "Run:"
echo "  npm run tauri dev"
