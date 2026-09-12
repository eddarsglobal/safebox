# SafeBox v0.2.2D — Android Native Share/Open-With R21

R21 adds Android system intake without allowing an Android intent to trigger cryptographic work automatically.

- `.sbx` Open-With uses Tauri 2 mobile file associations + `RunEvent::Opened`.
- Share to SafeBox registers Android SEND / SEND_MULTIPLE for `*/*`.
- Incoming `content://` and `file://` values remain intact.
- The provider display name determines Create vs Unlock.
- `.sbx` enters Receiver/Unlock; other files enter Create.
- V1 processes one shared file at a time.
- No incoming intent auto-creates or auto-unlocks.

Security: no code/password/metadata is sent over network or to ads.
