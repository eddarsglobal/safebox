#!/usr/bin/env bash
set -euo pipefail

# SafeBox Sprint 10A-1 — Help Cleanup
#
# Goal:
# - Keep only one Help / Aide button.
# - Keep Sprint 9B How To Use SafeBox as the single Help modal.
# - Remove old dedupe v1/v2 JS blocks.
# - Remove legacy #helpBtn instances at runtime.
#
# Does NOT touch encryption / SBX format / Settings / Access Profiles / receiver logic.

ROOT="$(pwd)"
if [ ! -d "$ROOT/safebox-desktop" ]; then
  echo "ERROR: Run this from safebox_sbx_mvp root."
  echo "Current: $ROOT"
  exit 1
fi

cd "$ROOT/safebox-desktop"

echo "==> Backup src/main.ts and src/style.css"
cp src/main.ts "src/main.ts.backup-sprint10a1-help-cleanup.$(date +%Y%m%d%H%M%S)"
cp src/style.css "src/style.css.backup-sprint10a1-help-cleanup.$(date +%Y%m%d%H%M%S)" 2>/dev/null || true

python3 - <<'PY'
from pathlib import Path

p = Path("src/main.ts")
text = p.read_text()

def remove_console_marker_block(source: str, marker: str) -> str:
    changed = True

    while changed and marker in source:
        changed = False
        pos = source.find(marker)

        # Prefer removing from the nearest UX FIX / HARD FIX / SafeBox comment before marker.
        candidates = [
            source.rfind("\n// UX FIX", 0, pos),
            source.rfind("\n// HARD FIX", 0, pos),
            source.rfind("\n// SafeBox", 0, pos),
            source.rfind("\nfunction sbxDedupe", 0, pos),
        ]
        start = max(candidates)

        if start == -1:
            break

        if source[start] == "\n":
            start += 1

        end_console = source.find(f'console.debug("{marker}")', pos)
        if end_console == -1:
            end_console = source.find(f"console.debug('{marker}')", pos)

        if end_console == -1:
            break

        end_line = source.find("\n", end_console)
        if end_line == -1:
            end_line = len(source)

        source = source[:start] + source[end_line + 1:]
        changed = True

    return source

# Remove previous duplicate-help hotfix blocks that added extra timers.
text = remove_console_marker_block(text, "dedupe-help-buttons-9b-v1")
text = remove_console_marker_block(text, "dedupe-help-buttons-9b-v2")

if "sprint10a1-help-single-controller-v1" not in text:
    text += r'''

// SafeBox Sprint 10A-1 — single Help button controller
// Marker: sprint10a1-help-single-controller-v1
function sbxSingleHelpButtonController() {
  const howToButtons = Array.from(document.querySelectorAll<HTMLButtonElement>("#howToUseBtn"));
  const legacyHelpButtons = Array.from(document.querySelectorAll<HTMLButtonElement>("#helpBtn"));

  // Remove old Sprint 9A Help buttons. Sprint 9B owns Help now.
  legacyHelpButtons.forEach((button) => button.remove());

  // Keep only the first Sprint 9B Help button.
  howToButtons.slice(1).forEach((button) => button.remove());

  const keep = document.querySelector<HTMLButtonElement>("#howToUseBtn");

  if (keep) {
    keep.classList.add("how-to-use-btn", "mini-btn");
  }

  // Remove legacy 9A modal if it exists. Keep #howToUseModal.
  document.querySelectorAll<HTMLElement>("#helpModal").forEach((modal) => modal.remove());
}

function sbxStartSingleHelpButtonController() {
  sbxSingleHelpButtonController();

  if ((window as any).__safeboxSingleHelpObserver) return;

  const observer = new MutationObserver(() => {
    sbxSingleHelpButtonController();
  });

  observer.observe(document.body, {
    childList: true,
    subtree: true
  });

  (window as any).__safeboxSingleHelpObserver = observer;
}

setTimeout(sbxStartSingleHelpButtonController, 100);
setTimeout(sbxStartSingleHelpButtonController, 500);
setTimeout(sbxStartSingleHelpButtonController, 1200);

console.debug("sprint10a1-help-single-controller-v1");
'''

p.write_text(text)
print("OK: Sprint 10A-1 Help Cleanup patched into src/main.ts")
PY

cat >> src/style.css <<'CSS'

/* SafeBox Sprint 10A-1 — Help Cleanup */
:root {
  --sprint10a1-help-single-controller-v1: 1;
}

/* Legacy Sprint 9A Help button must never be visible. */
#helpBtn {
  display: none !important;
}
CSS

echo "==> Build check"
rm -rf dist node_modules/.vite
npm run build

echo ""
echo "==> Verify Sprint 10A-1 marker"
grep -R -- "sprint10a1-help-single-controller-v1" dist || echo "ERROR: Sprint 10A-1 Help marker absent from dist"

echo ""
echo "==> Verify old dedupe markers are gone from built JS if possible"
grep -R -- "dedupe-help-buttons-9b-v1" dist && echo "WARN: old v1 marker still in dist" || echo "OK: old v1 marker not in dist"
grep -R -- "dedupe-help-buttons-9b-v2" dist && echo "WARN: old v2 marker still in dist" || echo "OK: old v2 marker not in dist"

echo ""
echo "Sprint 10A-1 Help Cleanup applied."
echo "Run:"
echo "  npm run tauri dev"
