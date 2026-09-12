import fs from "node:fs";
import path from "node:path";
import process from "node:process";

const root = path.resolve(path.dirname(new URL(import.meta.url).pathname), "../..");
const wasmPath = path.join(root, "safebox-desktop/public/safebox_core.wasm");
const wasmBytes = fs.readFileSync(wasmPath);
const { instance } = await WebAssembly.instantiate(wasmBytes, {});
const w = instance.exports;

function fail(message) {
  console.error(`SAFEBOX_WEB_WASM_NODE_SMOKE_FAIL: ${message}`);
  process.exit(1);
}
if (w.sbx_abi_version() !== 1) fail("ABI version mismatch");

const enc = new TextEncoder();
const dec = new TextDecoder();
const codeText = "R68-canonical-interop-code";

function alloc(bytes) {
  if (bytes.length === 0) return { ptr: 0, len: 0, clear() {} };
  const ptr = Number(w.sbx_alloc(bytes.length));
  if (!ptr) fail("allocation failed");
  new Uint8Array(w.memory.buffer, ptr, bytes.length).set(bytes);
  return {
    ptr, len: bytes.length,
    clear() {
      new Uint8Array(w.memory.buffer, ptr, bytes.length).fill(0);
      w.sbx_dealloc(ptr, bytes.length);
    }
  };
}
function resultBytes() {
  const ptr = Number(w.sbx_result_data_ptr());
  const len = Number(w.sbx_result_data_len());
  return len ? new Uint8Array(w.memory.buffer, ptr, len).slice() : new Uint8Array();
}
function resultMeta() {
  const ptr = Number(w.sbx_result_meta_ptr());
  const len = Number(w.sbx_result_meta_len());
  if (!ptr || !len) fail("result metadata missing");
  return JSON.parse(dec.decode(new Uint8Array(w.memory.buffer, ptr, len)));
}
function errorInfo() {
  const ptr = Number(w.sbx_error_ptr());
  const len = Number(w.sbx_error_len());
  if (!ptr || !len) return { code: "UNKNOWN", message: "missing WASM error" };
  return JSON.parse(dec.decode(new Uint8Array(w.memory.buffer, ptr, len)));
}
function callProtect(input, originalName = "r68-web-fixture.bin") {
  const config = enc.encode(JSON.stringify({
    original_file_name: originalName,
    visible_sbx_name: "r68-web-fixture.sbx",
    burn_after_unlock: false,
    chunk_size: 64 * 1024,
    sender_label: "R68 Web",
    access_profile: "Interop",
    public_note: "canonical",
    created_utc: "2026-08-30T20:00:00Z"
  }));
  const code = enc.encode(codeText);
  const entropy = new Uint8Array(Number(w.sbx_entropy_len()));
  for (let i = 0; i < entropy.length; i++) entropy[i] = (i * 37 + 11) % 251;
  const a = alloc(input), c = alloc(config), k = alloc(code), e = alloc(entropy);
  try {
    const status = w.sbx_protect(a.ptr, a.len, c.ptr, c.len, k.ptr, k.len, e.ptr, e.len);
    if (status !== 0) fail(`protect failed: ${JSON.stringify(errorInfo())}`);
    return { bytes: resultBytes(), meta: resultMeta() };
  } finally {
    a.clear(); c.clear(); k.clear(); e.clear();
    input.fill(0); config.fill(0); code.fill(0); entropy.fill(0);
    w.sbx_clear_result();
  }
}
function callUnlock(sbx, codeValue = codeText) {
  const code = enc.encode(codeValue);
  const a = alloc(sbx), k = alloc(code);
  try {
    const status = w.sbx_unlock(a.ptr, a.len, k.ptr, k.len);
    if (status !== 0) return { status, error: errorInfo() };
    return { status, bytes: resultBytes(), meta: resultMeta() };
  } finally {
    a.clear(); k.clear(); code.fill(0); w.sbx_clear_result();
  }
}
function callPublicInfo(sbx) {
  const prefix = sbx.slice(0, Math.min(sbx.length, 4 + 2 + 4 + 1024 * 1024));
  const a = alloc(prefix);
  try {
    const status = w.sbx_public_info(a.ptr, a.len);
    if (status !== 0) fail(`public-info failed: ${JSON.stringify(errorInfo())}`);
    return resultMeta();
  } finally {
    a.clear(); prefix.fill(0); w.sbx_clear_result();
  }
}
function bytesEqual(a, b) {
  if (a.length !== b.length) return false;
  for (let i = 0; i < a.length; i++) if (a[i] !== b[i]) return false;
  return true;
}

const mode = process.argv[2] || "roundtrip";
if (mode === "roundtrip") {
  const outDir = process.argv[3];
  if (!outDir) fail("roundtrip output directory missing");
  fs.mkdirSync(outDir, { recursive: true });
  const original = new Uint8Array(180_123);
  for (let i = 0; i < original.length; i++) original[i] = (i * 13 + 7) & 0xff;
  const expected = original.slice();
  const created = callProtect(original);
  if (created.bytes.slice(0, 4).toString() !== new Uint8Array([83,66,88,49]).toString()) fail("SBX1 magic mismatch");
  if (created.meta.encrypted_chunks !== 3) fail("unexpected chunk count");
  const info = callPublicInfo(created.bytes);
  if (info.public_metadata?.public_note !== "canonical") fail("public metadata mismatch");
  const unlocked = callUnlock(created.bytes);
  if (unlocked.status !== 0 || !bytesEqual(unlocked.bytes, expected)) fail("WASM roundtrip mismatch");
  unlocked.bytes.fill(0);
  const wrong = callUnlock(created.bytes, "wrong-code");
  if (wrong.status === 0 || wrong.error?.code !== "ACCESS_DENIED") fail("wrong code was not rejected");
  const tampered = created.bytes.slice();
  tampered[tampered.length - 1] ^= 1;
  const tamper = callUnlock(tampered);
  if (tamper.status === 0 || tamper.error?.code !== "INTEGRITY_FAILED") fail("tamper was not rejected");
  fs.writeFileSync(path.join(outDir, "original.bin"), expected);
  fs.writeFileSync(path.join(outDir, "web-created.sbx"), created.bytes);
  created.bytes.fill(0); tampered.fill(0);
  console.log("SAFEBOX_WEB_WASM_NODE_ROUNDTRIP_PASS");
  console.log("SAFEBOX_WEB_WASM_WRONG_CODE_REJECT_PASS");
  console.log("SAFEBOX_WEB_WASM_TAMPER_REJECT_PASS");
  console.log("SAFEBOX_WEB_WASM_PUBLIC_INFO_PASS");
} else if (mode === "unlock-native") {
  const sbxPath = process.argv[3];
  const originalPath = process.argv[4];
  if (!sbxPath || !originalPath) fail("native fixture paths missing");
  const sbx = new Uint8Array(fs.readFileSync(sbxPath));
  const expected = new Uint8Array(fs.readFileSync(originalPath));
  const unlocked = callUnlock(sbx);
  if (unlocked.status !== 0 || !bytesEqual(unlocked.bytes, expected)) fail(`native->WASM unlock failed: ${JSON.stringify(unlocked.error || {})}`);
  unlocked.bytes.fill(0); sbx.fill(0); expected.fill(0);
  console.log("SAFEBOX_WEB_WASM_NATIVE_TO_WEB_INTEROP_PASS");
} else {
  fail(`unknown mode: ${mode}`);
}
