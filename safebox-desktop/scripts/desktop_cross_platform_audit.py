#!/usr/bin/env python3
from pathlib import Path
import json, re, hashlib, sys
ROOT = Path(__file__).resolve().parents[2]
DESKTOP = ROOT / 'safebox-desktop'
TAURI = DESKTOP / 'src-tauri'
CORE = ROOT / 'safebox-core'
lib = (TAURI/'src/lib.rs').read_text()
create = (CORE/'src/create.rs').read_text()
unlock = (CORE/'src/unlock.rs').read_text()
base = json.loads((TAURI/'tauri.conf.json').read_text())
win = json.loads((TAURI/'tauri.windows.conf.json').read_text())
mac = json.loads((TAURI/'tauri.macos.conf.json').read_text())

def require(cond, marker, detail=''):
    if not cond:
        print(f'{marker.replace("_PASS","_FAIL")}: {detail or "contract mismatch"}')
        raise SystemExit(1)
    print(marker)

require(win.get('bundle',{}).get('targets') == ['nsis'], 'SAFEBOX_WINDOWS_INSTALLER_TARGET_PASS')
require(mac.get('bundle',{}).get('targets') == ['app'], 'SAFEBOX_MACOS_APP_BUNDLE_TARGET_PASS')
require('tauri_plugin_single_instance::init' in lib and 'find_sbx_arg(args' in lib,
        'SAFEBOX_DESKTOP_WARM_FILE_ASSOCIATION_PASS')
require('find_sbx_arg(std::env::args()' in lib,
        'SAFEBOX_WINDOWS_COLD_FILE_ASSOCIATION_PASS')
require('#[cfg(any(target_os = "macos", target_os = "ios", target_os = "android"))]' in lib and 'RunEvent::Opened { urls }' in lib,
        'SAFEBOX_MACOS_RUN_EVENT_OPENED_PASS')
require('Command::new(\"cmd.exe\")' not in lib and 'Command::new(\"powershell' not in lib.lower() and 'Command::new(program)' in lib,
        'SAFEBOX_DESKTOP_NO_SHELL_INTERPRETATION_PASS')
require('options.mode(0o600)' in create and 'options.mode(0o600)' in unlock,
        'SAFEBOX_MACOS_PRIVATE_FILE_MODE_PASS')
require('is_windows_reserved_name' in unlock and 'CON" | "PRN" | "AUX" | "NUL' in unlock,
        'SAFEBOX_WINDOWS_RESERVED_FILENAME_GUARD_PASS')
require('target_os = "windows"' in lib and 'explorer.exe' in lib,
        'SAFEBOX_WINDOWS_OPEN_REVEAL_ADAPTER_PASS')
# Ensure the iOS-only surface did not become a desktop dependency.
require('#[cfg(target_os = "ios")]' in lib and '#[cfg(not(target_os = "ios"))]' in lib,
        'SAFEBOX_DESKTOP_IOS_ISOLATION_PASS')
print('SAFEBOX_DESKTOP_CROSS_PLATFORM_AUDIT_PASS')
