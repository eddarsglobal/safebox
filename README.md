# SafeBox Sprint 10A-7 — Default SBX name sync

Fixes:
- main `Visible SBX name` staying `Document` while Settings → General → `Default SBX name` has another value.

Rule:
- Sync only when main visible name is empty or still automatic.
- Do not overwrite a custom name typed by the user.

Run:

```bash
cd "/Users/noury/Documents/App_py/SAFEBOX/safebox_sbx_mvp"

unzip -o "$HOME/Downloads/safebox_sprint10a7_default_sbx_name_sync_patch.zip" -d /tmp/safebox_10a7_name

bash /tmp/safebox_10a7_name/apply_safebox_sprint10a7_default_sbx_name_sync_patch.sh

cd safebox-desktop

killall SafeBox 2>/dev/null || true
killall safebox-desktop 2>/dev/null || true

rm -rf "$HOME/Library/WebKit/com.safebox.desktop"
rm -rf "$HOME/Library/Caches/com.safebox.desktop"
rm -rf "$HOME/Library/Application Support/com.safebox.desktop"
rm -rf "$HOME/Library/HTTPStorages/com.safebox.desktop"
rm -rf "$HOME/Library/Saved Application State/com.safebox.desktop.savedState"

npm run tauri dev
```
