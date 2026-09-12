use safebox_core::{create_sbx, unlock_sbx, CreateOptions, SbxError, UnlockOptions};
use std::fs;
use std::path::PathBuf;
use std::time::{SystemTime, UNIX_EPOCH};

fn test_root(name: &str) -> PathBuf {
    let nonce = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap()
        .as_nanos();
    std::env::temp_dir().join(format!(
        "safebox-test-{name}-{}-{nonce}",
        std::process::id()
    ))
}

#[test]
fn create_unlock_roundtrip_preserves_bytes() {
    let root = test_root("roundtrip");
    let restore_dir = root.join("restore");
    fs::create_dir_all(&root).unwrap();

    let input = root.join("čuvaj_ملف.txt");
    let sbx = root.join("capsule.sbx");
    let payload = b"SafeBox security roundtrip\nwith binary:\0\x01\xff";
    fs::write(&input, payload).unwrap();

    let mut create = CreateOptions::new(&input, &sbx, "correct horse battery staple");
    create.burn_after_unlock = false;
    create_sbx(create).unwrap();

    let mut unlock = UnlockOptions::new(&sbx, "correct horse battery staple");
    unlock.output_dir = Some(restore_dir.clone());
    unlock.burn_after_unlock = false;
    let report = unlock_sbx(unlock).unwrap();

    assert_eq!(fs::read(report.restored_path).unwrap(), payload);
    assert!(sbx.exists());

    let _ = fs::remove_dir_all(root);
}

#[test]
fn wrong_code_is_access_denied_without_output() {
    let root = test_root("wrong-code");
    let restore_dir = root.join("restore");
    fs::create_dir_all(&root).unwrap();

    let input = root.join("input.bin");
    let sbx = root.join("capsule.sbx");
    fs::write(&input, vec![7u8; 200_000]).unwrap();

    let mut create = CreateOptions::new(&input, &sbx, "right-code");
    create.burn_after_unlock = false;
    create_sbx(create).unwrap();

    let mut unlock = UnlockOptions::new(&sbx, "wrong-code");
    unlock.output_dir = Some(restore_dir.clone());
    unlock.burn_after_unlock = false;
    let err = unlock_sbx(unlock).unwrap_err();
    assert!(matches!(err, SbxError::AccessDenied));
    assert!(!restore_dir.exists() || fs::read_dir(&restore_dir).unwrap().next().is_none());

    let _ = fs::remove_dir_all(root);
}

#[test]
fn modified_ciphertext_fails_integrity_and_cleans_temp() {
    let root = test_root("tamper");
    let restore_dir = root.join("restore");
    fs::create_dir_all(&root).unwrap();

    let input = root.join("input.bin");
    let sbx = root.join("capsule.sbx");
    fs::write(&input, vec![3u8; 1_500_000]).unwrap();

    let mut create = CreateOptions::new(&input, &sbx, "tamper-test-code");
    create.burn_after_unlock = false;
    create_sbx(create).unwrap();

    let mut bytes = fs::read(&sbx).unwrap();
    let last = bytes.len() - 1;
    bytes[last] ^= 0x80;
    fs::write(&sbx, bytes).unwrap();

    let mut unlock = UnlockOptions::new(&sbx, "tamper-test-code");
    unlock.output_dir = Some(restore_dir.clone());
    unlock.burn_after_unlock = false;
    let err = unlock_sbx(unlock).unwrap_err();
    assert!(matches!(err, SbxError::IntegrityFailed(_)));

    if restore_dir.exists() {
        for entry in fs::read_dir(&restore_dir).unwrap() {
            let name = entry.unwrap().file_name().to_string_lossy().to_string();
            assert!(
                !name.contains(".sbx-restoring-"),
                "temp file leaked: {name}"
            );
        }
    }

    let _ = fs::remove_dir_all(root);
}

#[test]
fn burn_occurs_only_after_successful_restore() {
    let root = test_root("burn");
    let restore_dir = root.join("restore");
    fs::create_dir_all(&root).unwrap();

    let input = root.join("input.txt");
    let sbx = root.join("capsule.sbx");
    fs::write(&input, b"burn transaction").unwrap();

    let mut create = CreateOptions::new(&input, &sbx, "burn-code");
    create.burn_after_unlock = true;
    create_sbx(create).unwrap();
    let mut unlock = UnlockOptions::new(&sbx, "burn-code");
    unlock.output_dir = Some(restore_dir);
    unlock.burn_after_unlock = true;
    let report = unlock_sbx(unlock).unwrap();

    assert!(report.restored_path.exists());
    assert!(report.sbx_deleted);
    assert!(!sbx.exists());

    let _ = fs::remove_dir_all(root);
}

#[test]
fn default_policy_keeps_sbx_after_unlock() {
    let root = test_root("default-keep");
    let restore_dir = root.join("restore");
    fs::create_dir_all(&root).unwrap();

    let input = root.join("keep-default.txt");
    let sbx = root.join("keep-default.sbx");
    fs::write(&input, b"default retention policy").unwrap();

    create_sbx(CreateOptions::new(&input, &sbx, "keep-default-code")).unwrap();
    let mut unlock = UnlockOptions::new(&sbx, "keep-default-code");
    unlock.output_dir = Some(restore_dir);
    let report = unlock_sbx(unlock).unwrap();

    assert!(report.restored_path.exists());
    assert!(sbx.exists());
    assert!(!report.sbx_deleted);

    let _ = fs::remove_dir_all(root);
}
