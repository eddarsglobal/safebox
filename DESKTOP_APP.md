# SafeBox Desktop MVP

This is Sprint 2: a very light Tauri desktop interface on top of `safebox-core`.

## What it does

- Create `document.sbx` from any original file.
- Hide the original filename and extension inside encrypted metadata.
- Unlock `.sbx` with the correct code.
- Restore the original file with its original extension.
- Delete the local `.sbx` after successful unlock, unless test mode is enabled.
- Provide a dark/light professional UI with responsive layout.

## Run on macOS

From the project root:

```bash
cd safebox-desktop
npm install
npm run tauri dev
```

If `npm` is missing, install Node.js first:

```bash
brew install node
```

## Create test

In the SafeBox window:

1. Open the **Create SBX** tab.
2. Paste the full path to `test.png`, for example:
   `/Users/noury/Desktop/test.png`
3. Visible SBX name: `document`
4. Code: `MIRA-2026-SAFE`
5. Click **Create document.sbx**.

Expected result: `document.sbx` appears in the same folder as `test.png`.

## Unlock test

1. Open the **Unlock SBX** tab.
2. Paste the full path to `document.sbx`.
3. Enter the same code.
4. Click **Unlock & restore original**.

Expected result:

- the original file is restored,
- the local `.sbx` is deleted,
- UI shows: mission completed.

## Notes

This MVP intentionally uses typed file paths first. File picker and OS context-menu integration come next.

Next sprint:

- native file picker,
- double-click `.sbx` opens SafeBox,
- Windows/macOS/Linux file association polishing,
- right-click “Protect with SafeBox”.
