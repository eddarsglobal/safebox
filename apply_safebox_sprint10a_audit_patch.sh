#!/usr/bin/env bash
set -euo pipefail

# SafeBox Sprint 10A — Stabilization Audit
#
# This script does NOT modify src/main.ts or src/style.css.
# It creates an audit report so we can clean safely after all Sprint 8/9 hotfixes.

ROOT="$(pwd)"
if [ ! -d "$ROOT/safebox-desktop" ]; then
  echo "ERROR: Run this from safebox_sbx_mvp root."
  echo "Current: $ROOT"
  exit 1
fi

DESKTOP="$ROOT/safebox-desktop"
REPORT_DIR="$ROOT/checkpoints"
REPORT="$REPORT_DIR/SPRINT10A_STABILIZATION_AUDIT_REPORT.md"
BUILD_LOG="$REPORT_DIR/SPRINT10A_BUILD_REPORT.txt"

mkdir -p "$REPORT_DIR"

cd "$DESKTOP"

echo "==> Sprint 10A audit started"

python3 - <<'PY'
from pathlib import Path
import re
from collections import Counter, defaultdict
from datetime import datetime

root = Path.cwd()
workspace = root.parent
report_dir = workspace / "checkpoints"
report = report_dir / "SPRINT10A_STABILIZATION_AUDIT_REPORT.md"

main = root / "src/main.ts"
css = root / "src/style.css"
pkg = root / "package.json"
tauri_conf = root / "src-tauri/tauri.conf.json"

main_text = main.read_text() if main.exists() else ""
css_text = css.read_text() if css.exists() else ""

markers = sorted(set(re.findall(r"[-a-zA-Z0-9_]*v\d+|sprint\d+[a-z]?-[-a-zA-Z0-9_]+|receiver-main-screen-file-name-only|settings-tabs-general-profiles-security|simple-access-profiles-add-profile-only|compact-access-profiles-edit-modal|force-empty-access-profiles-v1", main_text + "\n" + css_text)))

functions = re.findall(r"\bfunction\s+([A-Za-z0-9_]+)\s*\(", main_text)
func_counts = Counter(functions)
duplicate_functions = [(name, count) for name, count in func_counts.items() if count > 1]

selectors = re.findall(r"(^|\n)\s*([.#][A-Za-z0-9_-]+|#[A-Za-z0-9_-]+(?:\.[A-Za-z0-9_-]+)*)\s*[,{]", css_text)
selector_counts = Counter(sel for _, sel in selectors)
duplicate_selectors = [(sel, count) for sel, count in selector_counts.items() if count > 3]

important_count = css_text.count("!important")
set_interval_count = main_text.count("setInterval(")
set_timeout_count = main_text.count("setTimeout(")
document_click_count = main_text.count('document.addEventListener(\n  "click"') + main_text.count('document.addEventListener("click"')
mutation_count = main_text.count("MutationObserver")
local_storage_count = main_text.count("localStorage")
session_storage_count = main_text.count("sessionStorage")

high_risk_patterns = {
    "replaceAll usage": len(re.findall(r"\.replaceAll\s*\(", main_text)),
    "body inline overflow writes": len(re.findall(r"document\.body\.style\.overflow", main_text)),
    "html inline overflow writes": len(re.findall(r"document\.documentElement\.style\.overflow", main_text)),
    "direct body append modal": len(re.findall(r"document\.body\.appendChild", main_text)),
    "global window assignment": len(re.findall(r"\(window as any\)", main_text)),
    "duplicate id query helpBtn": main_text.count("#helpBtn"),
    "duplicate id query howToUseBtn": main_text.count("#howToUseBtn"),
    "settingsTabsRoot references": main_text.count("settingsTabsRoot"),
    "settingsModal references": main_text.count("settingsModal"),
    "accessProfiles references": main_text.count("AccessProfile"),
}

key_behaviors = {
    ".sbx icon source": (root / "src-tauri/icons/safebox-file.icns").exists(),
    "SafeBox tauri wrapper": "scripts/safebox_tauri.sh" in (pkg.read_text() if pkg.exists() else ""),
    "finalize macOS bundle script": (root / "scripts/finalize_macos_bundle.sh").exists(),
    "ensure sbx icon source script": (root / "scripts/ensure_sbx_icon_source.sh").exists(),
    "package.json exists": pkg.exists(),
    "tauri config exists": tauri_conf.exists(),
}

sections = []

sections.append(f"# SafeBox Sprint 10A — Stabilization Audit\n")
sections.append(f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
sections.append("This audit does **not** change product behavior. It identifies what must be cleaned safely.\n")

sections.append("## Source size\n")
sections.append(f"- `src/main.ts`: {len(main_text.splitlines())} lines\n")
sections.append(f"- `src/style.css`: {len(css_text.splitlines())} lines\n")
sections.append(f"- CSS `!important`: {important_count}\n")
sections.append(f"- `setTimeout(...)`: {set_timeout_count}\n")
sections.append(f"- `setInterval(...)`: {set_interval_count}\n")
sections.append(f"- document click listeners: {document_click_count}\n")
sections.append(f"- `MutationObserver`: {mutation_count}\n")
sections.append(f"- `localStorage`: {local_storage_count}\n")
sections.append(f"- `sessionStorage`: {session_storage_count}\n")

sections.append("## Validated behavior markers found\n")
if markers:
    for marker in markers:
        sections.append(f"- `{marker}`\n")
else:
    sections.append("- No explicit markers found.\n")

sections.append("## Duplicate functions\n")
if duplicate_functions:
    for name, count in sorted(duplicate_functions):
        sections.append(f"- `{name}` appears {count} times\n")
else:
    sections.append("- No duplicated function names found.\n")

sections.append("## CSS selectors repeated many times\n")
if duplicate_selectors:
    for sel, count in sorted(duplicate_selectors, key=lambda x: (-x[1], x[0]))[:80]:
        sections.append(f"- `{sel}` appears {count} times\n")
else:
    sections.append("- No high repetition selectors found.\n")

sections.append("## High-risk patterns\n")
for label, count in high_risk_patterns.items():
    sections.append(f"- {label}: {count}\n")

sections.append("## Key build/release assets\n")
for label, ok in key_behaviors.items():
    sections.append(f"- {label}: {'OK' if ok else 'MISSING'}\n")

sections.append("## Recommended Sprint 10A cleanup plan\n")
sections.append("1. Freeze validated behavior markers before cleaning.\n")
sections.append("2. Extract a single Settings controller and remove old Settings repair blocks.\n")
sections.append("3. Extract a single Help/How-To controller and remove duplicate Help button guards.\n")
sections.append("4. Extract a single Access Profiles controller, preserving empty-by-default behavior.\n")
sections.append("5. Extract a single i18n controller, preserving full-app language switching.\n")
sections.append("6. Extract a single Scrollbar/Modal state guard.\n")
sections.append("7. Consolidate CSS into ordered sections: base, layout, forms, receiver, settings, help, profiles, responsive.\n")
sections.append("8. Rebuild and run QA matrix after every cleanup step.\n")

sections.append("## QA matrix to run after cleanup\n")
qa = [
    "Create simple SBX",
    "Create SBX with public sender/note",
    "Unlock correct code",
    "Unlock wrong code",
    "Double-click .sbx from Finder",
    "Receiver File info",
    "Access Profiles empty by default",
    "Main app hides Access profile when profiles empty",
    "Add/Edit/Delete Access Profile",
    "Settings tabs clickable",
    "Language changes whole app, not only Help",
    "Only one Help button",
    "Help modal scroll",
    "Main page scrollbar when window reduced",
    "Dark/light mode",
    "macOS .sbx icon in source and final bundle",
]
for item in qa:
    sections.append(f"- [ ] {item}\n")

report.write_text("".join(sections))
print(f"Audit report created: {report}")
PY

echo "==> Build check"
set +e
rm -rf dist node_modules/.vite
npm run build > "$BUILD_LOG" 2>&1
BUILD_EXIT=$?
set -e

if [ "$BUILD_EXIT" -eq 0 ]; then
  echo "Build: OK" >> "$REPORT"
  echo "==> Build OK"
else
  echo "Build: FAILED — see SPRINT10A_BUILD_REPORT.txt" >> "$REPORT"
  echo "==> Build FAILED. See: $BUILD_LOG"
fi

echo ""
echo "==> Report:"
echo "$REPORT"
echo ""
echo "==> Last build log:"
echo "$BUILD_LOG"
echo ""
echo "==> Preview:"
tail -n 80 "$REPORT"
