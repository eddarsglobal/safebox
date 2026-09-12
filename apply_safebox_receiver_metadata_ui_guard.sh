#!/usr/bin/env bash
set -euo pipefail

ROOT="$(pwd)"
if [ ! -d "$ROOT/safebox-desktop" ]; then
  echo "ERROR: Run this from safebox_sbx_mvp root."
  echo "Current: $ROOT"
  exit 1
fi

cd "$ROOT/safebox-desktop"

cp src/main.ts "src/main.ts.backup-ui-guard.$(date +%Y%m%d%H%M%S)"
cp src/style.css "src/style.css.backup-ui-guard.$(date +%Y%m%d%H%M%S)" 2>/dev/null || true

python3 - <<'PY'
from pathlib import Path

p = Path("src/main.ts")
text = p.read_text()

guard = '''
/**
 * Receiver metadata UI guard
 *
 * Product rule:
 * - Main receiver screen shows only: SafeBox, file name, code field, Unlock, File info.
 * - Sender/access/note are visible only inside File info.
 * - Empty note row is hidden.
 *
 * This guard removes old visible metadata blocks even if older overlay code still creates them.
 */
function enforceReceiverMinimalUi() {
  const overlay = document.querySelector<HTMLElement>("#hardReceiverOverlay");
  if (!overlay) return;

  overlay
    .querySelectorAll<HTMLElement>(
      "#hardReceiverIdentity, #hardReceiverNote, .hard-receiver-identity, .hard-receiver-note"
    )
    .forEach((element) => {
      element.textContent = "";
      element.remove();
    });

  const noteValue = overlay.querySelector<HTMLElement>("#hardInfoNote");
  const noteRow =
    overlay.querySelector<HTMLElement>("#hardInfoNoteRow") ||
    noteValue?.closest<HTMLElement>("div");

  if (noteValue && noteRow) {
    const value = (noteValue.textContent || "").trim().toLowerCase();
    const hasRealNote = value.length > 0 && value !== "empty" && value !== "not set";

    if (!hasRealNote) {
      noteValue.textContent = "";
      noteRow.classList.add("hidden");
      noteRow.style.display = "none";
    } else {
      noteRow.classList.remove("hidden");
      noteRow.style.display = "";
    }
  }
}

const receiverMinimalUiObserver = new MutationObserver(() => {
  enforceReceiverMinimalUi();
});

receiverMinimalUiObserver.observe(document.body, {
  childList: true,
  subtree: true,
  characterData: true
});

setInterval(enforceReceiverMinimalUi, 250);
'''

if "function enforceReceiverMinimalUi()" not in text:
    marker = "applySettingsToUi();"
    idx = text.rfind(marker)
    if idx == -1:
        text = text + "\n" + guard + "\n"
    else:
        text = text[:idx] + guard + "\n\n" + text[idx:]

if "loadReceiverPublicInfo(sbxPath);" in text and "loadReceiverPublicInfo(sbxPath);\n  enforceReceiverMinimalUi();" not in text:
    text = text.replace(
        "loadReceiverPublicInfo(sbxPath);",
        "loadReceiverPublicInfo(sbxPath);\n  enforceReceiverMinimalUi();",
        1
    )

# Call guard immediately after overlay HTML render, before events/focus.
if "const codeInput = document.querySelector<HTMLInputElement>(\"#hardReceiverCode\");" in text and "enforceReceiverMinimalUi();\n\n  const codeInput" not in text:
    text = text.replace(
        "  const codeInput = document.querySelector<HTMLInputElement>(\"#hardReceiverCode\");",
        "  enforceReceiverMinimalUi();\n\n  const codeInput = document.querySelector<HTMLInputElement>(\"#hardReceiverCode\");",
        1
    )

p.write_text(text)
print("Receiver minimal UI guard installed.")
PY

cat >> src/style.css <<'CSS'

/* Receiver metadata UI guard: no public metadata on the main receiver screen */
#hardReceiverOverlay #hardReceiverIdentity,
#hardReceiverOverlay #hardReceiverNote,
#hardReceiverOverlay .hard-receiver-identity,
#hardReceiverOverlay .hard-receiver-note {
  display: none !important;
  visibility: hidden !important;
  height: 0 !important;
  margin: 0 !important;
  padding: 0 !important;
  overflow: hidden !important;
}

/* Hide optional Note row when empty */
#hardInfoNoteRow.hidden {
  display: none !important;
}
CSS

echo "==> Build check"
npm run build

echo ""
echo "==> Verify guard"
grep -n "enforceReceiverMinimalUi" src/main.ts
grep -n "receiverMinimalUiObserver" src/main.ts

echo ""
echo "Done."
echo "Run:"
echo "  npm run tauri dev"
