const WEB_WASM_ABI_VERSION = 1;
const WEB_WASM_FILE = import.meta.env.VITE_SAFEBOX_WASM_FILE || "safebox_core.wasm";
export const WEB_SBX_MAX_FILE_BYTES = 128 * 1024 * 1024;

const encoder = new TextEncoder();
const decoder = new TextDecoder("utf-8", { fatal: true });

type WasmExports = WebAssembly.Exports & {
  memory: WebAssembly.Memory;
  sbx_abi_version: () => number;
  sbx_entropy_len: () => number;
  sbx_alloc: (len: number) => number;
  sbx_dealloc: (ptr: number, len: number) => void;
  sbx_protect: (
    inputPtr: number,
    inputLen: number,
    configPtr: number,
    configLen: number,
    codePtr: number,
    codeLen: number,
    entropyPtr: number,
    entropyLen: number
  ) => number;
  sbx_unlock: (sbxPtr: number, sbxLen: number, codePtr: number, codeLen: number) => number;
  sbx_public_info: (sbxPtr: number, sbxLen: number) => number;
  sbx_result_data_ptr: () => number;
  sbx_result_data_len: () => number;
  sbx_result_meta_ptr: () => number;
  sbx_result_meta_len: () => number;
  sbx_error_ptr: () => number;
  sbx_error_len: () => number;
  sbx_clear_result: () => void;
};

type PublicMetadata = {
  sender_label?: string | null;
  access_profile?: string | null;
  public_note?: string | null;
};

export type WebProtectOptions = {
  visibleSbxName: string;
  keepAfterUnlock: boolean;
  senderLabel?: string | null;
  accessProfile?: string | null;
  publicNote?: string | null;
};

export type WebProtectResult = {
  bytes: Uint8Array;
  visible_sbx_name: string;
  original_size: number;
  encrypted_chunks: number;
};

export type WebUnlockResult = {
  bytes: Uint8Array;
  original_file_name: string;
  original_size: number;
  visible_sbx_name: string;
  decrypted_chunks: number;
  burn_after_unlock: boolean;
  public_metadata?: PublicMetadata | null;
};

export type WebPublicInfo = {
  format: string;
  public_metadata?: PublicMetadata | null;
};

export class WebSbxError extends Error {
  readonly code: string;

  constructor(code: string, message: string) {
    super(message);
    this.name = "WebSbxError";
    this.code = code;
  }
}

let wasmPromise: Promise<WasmExports> | null = null;

function wasmUrl(): string {
  return `${import.meta.env.BASE_URL}${WEB_WASM_FILE}`;
}

async function loadWasm(): Promise<WasmExports> {
  if (!wasmPromise) {
    wasmPromise = (async () => {
      const response = await fetch(wasmUrl(), { cache: "force-cache", credentials: "same-origin" });
      if (!response.ok) {
        throw new WebSbxError("WEB_ENGINE_MISSING", `SafeBox WebAssembly engine unavailable (${response.status})`);
      }
      const moduleBytes = await response.arrayBuffer();
      const result = await WebAssembly.instantiate(moduleBytes, {});
      const exports = result.instance.exports as WasmExports;
      if (!(exports.memory instanceof WebAssembly.Memory)) {
        throw new WebSbxError("WEB_ENGINE_INVALID", "SafeBox WebAssembly memory export is missing");
      }
      if (exports.sbx_abi_version?.() !== WEB_WASM_ABI_VERSION) {
        throw new WebSbxError("WEB_ENGINE_ABI", "SafeBox WebAssembly ABI version mismatch");
      }
      const entropyLen = exports.sbx_entropy_len?.();
      if (!Number.isSafeInteger(entropyLen) || entropyLen < 64 || entropyLen > 512) {
        throw new WebSbxError("WEB_ENGINE_ABI", "SafeBox WebAssembly entropy contract is invalid");
      }
      return exports;
    })().catch((error) => {
      wasmPromise = null;
      throw error;
    });
  }
  return wasmPromise;
}

function assertFileSize(size: number): void {
  if (!Number.isSafeInteger(size) || size < 0 || size > WEB_SBX_MAX_FILE_BYTES) {
    throw new WebSbxError(
      "WEB_FILE_TOO_LARGE",
      `Browser mode currently supports files up to ${WEB_SBX_MAX_FILE_BYTES / (1024 * 1024)} MiB`
    );
  }
}

function allocatedCopy(exports: WasmExports, bytes: Uint8Array): { ptr: number; len: number; clear: () => void } {
  if (bytes.byteLength === 0) {
    return { ptr: 0, len: 0, clear: () => {} };
  }
  const ptr = exports.sbx_alloc(bytes.byteLength);
  if (!ptr) throw new WebSbxError("WEB_ENGINE_OOM", "SafeBox WebAssembly allocation failed");
  new Uint8Array(exports.memory.buffer, ptr, bytes.byteLength).set(bytes);
  return {
    ptr,
    len: bytes.byteLength,
    clear: () => {
      try {
        new Uint8Array(exports.memory.buffer, ptr, bytes.byteLength).fill(0);
      } finally {
        exports.sbx_dealloc(ptr, bytes.byteLength);
      }
    }
  };
}

function copyResultBytes(exports: WasmExports): Uint8Array {
  const ptr = exports.sbx_result_data_ptr();
  const len = exports.sbx_result_data_len();
  if (!len) return new Uint8Array();
  if (!ptr || ptr + len > exports.memory.buffer.byteLength) {
    throw new WebSbxError("WEB_ENGINE_INVALID", "SafeBox WebAssembly returned an invalid data range");
  }
  return new Uint8Array(exports.memory.buffer, ptr, len).slice();
}

function copyMeta<T>(exports: WasmExports): T {
  const ptr = exports.sbx_result_meta_ptr();
  const len = exports.sbx_result_meta_len();
  if (!ptr || !len || ptr + len > exports.memory.buffer.byteLength) {
    throw new WebSbxError("WEB_ENGINE_INVALID", "SafeBox WebAssembly returned invalid metadata");
  }
  const bytes = new Uint8Array(exports.memory.buffer, ptr, len).slice();
  try {
    return JSON.parse(decoder.decode(bytes)) as T;
  } finally {
    bytes.fill(0);
  }
}

function throwWasmError(exports: WasmExports, status: number): never {
  const ptr = exports.sbx_error_ptr();
  const len = exports.sbx_error_len();
  if (ptr && len && ptr + len <= exports.memory.buffer.byteLength) {
    try {
      const raw = decoder.decode(new Uint8Array(exports.memory.buffer, ptr, len));
      const parsed = JSON.parse(raw) as { code?: string; message?: string };
      throw new WebSbxError(parsed.code || `WEB_ENGINE_${status}`, parsed.message || "SafeBox WebAssembly operation failed");
    } catch (error) {
      if (error instanceof WebSbxError) throw error;
    }
  }
  throw new WebSbxError(`WEB_ENGINE_${status}`, "SafeBox WebAssembly operation failed");
}

export async function protectWebFile(file: File, code: string, options: WebProtectOptions): Promise<WebProtectResult> {
  assertFileSize(file.size);
  const exports = await loadWasm();
  const inputBytes = new Uint8Array(await file.arrayBuffer());
  const configBytes = encoder.encode(JSON.stringify({
    original_file_name: file.name,
    visible_sbx_name: options.visibleSbxName,
    burn_after_unlock: !options.keepAfterUnlock,
    chunk_size: 1024 * 1024,
    sender_label: options.senderLabel || null,
    access_profile: options.accessProfile || null,
    public_note: options.publicNote || null,
    created_utc: new Date().toISOString()
  }));
  const codeBytes = encoder.encode(code);
  const entropy = new Uint8Array(exports.sbx_entropy_len());
  crypto.getRandomValues(entropy);

  const input = allocatedCopy(exports, inputBytes);
  const config = allocatedCopy(exports, configBytes);
  const codeAlloc = allocatedCopy(exports, codeBytes);
  const entropyAlloc = allocatedCopy(exports, entropy);
  inputBytes.fill(0);
  configBytes.fill(0);
  codeBytes.fill(0);
  entropy.fill(0);

  try {
    const status = exports.sbx_protect(
      input.ptr, input.len,
      config.ptr, config.len,
      codeAlloc.ptr, codeAlloc.len,
      entropyAlloc.ptr, entropyAlloc.len
    );
    if (status !== 0) throwWasmError(exports, status);
    const bytes = copyResultBytes(exports);
    const meta = copyMeta<Omit<WebProtectResult, "bytes">>(exports);
    return { ...meta, bytes };
  } finally {
    input.clear();
    config.clear();
    codeAlloc.clear();
    entropyAlloc.clear();
    exports.sbx_clear_result();
  }
}

export async function unlockWebFile(file: File, code: string): Promise<WebUnlockResult> {
  assertFileSize(file.size);
  const exports = await loadWasm();
  const sbxBytes = new Uint8Array(await file.arrayBuffer());
  const codeBytes = encoder.encode(code);
  const sbx = allocatedCopy(exports, sbxBytes);
  const codeAlloc = allocatedCopy(exports, codeBytes);
  sbxBytes.fill(0);
  codeBytes.fill(0);

  try {
    const status = exports.sbx_unlock(sbx.ptr, sbx.len, codeAlloc.ptr, codeAlloc.len);
    if (status !== 0) throwWasmError(exports, status);
    const bytes = copyResultBytes(exports);
    const meta = copyMeta<Omit<WebUnlockResult, "bytes">>(exports);
    if (meta.original_size !== bytes.byteLength) {
      bytes.fill(0);
      throw new WebSbxError("INTEGRITY_FAILED", "Restored browser size does not match authenticated metadata");
    }
    return { ...meta, bytes };
  } finally {
    sbx.clear();
    codeAlloc.clear();
    exports.sbx_clear_result();
  }
}

export async function readWebPublicInfo(file: File): Promise<WebPublicInfo> {
  const exports = await loadWasm();
  const prefixLimit = 4 + 2 + 4 + 1024 * 1024;
  const prefix = new Uint8Array(await file.slice(0, prefixLimit).arrayBuffer());
  const allocation = allocatedCopy(exports, prefix);
  prefix.fill(0);
  try {
    const status = exports.sbx_public_info(allocation.ptr, allocation.len);
    if (status !== 0) throwWasmError(exports, status);
    return copyMeta<WebPublicInfo>(exports);
  } finally {
    allocation.clear();
    exports.sbx_clear_result();
  }
}

export function downloadWebBytes(bytes: Uint8Array, fileName: string, mime = "application/octet-stream"): void {
  // BlobPart in modern TypeScript requires ArrayBuffer-backed data, while a
  // generic Uint8Array may be typed as ArrayBufferLike (including
  // SharedArrayBuffer). Copy into a fresh ordinary ArrayBuffer so the browser
  // download boundary is explicit and cannot retain a shared backing store.
  const downloadBuffer = new ArrayBuffer(bytes.byteLength);
  new Uint8Array(downloadBuffer).set(bytes);
  const blob = new Blob([downloadBuffer], { type: mime });
  const url = URL.createObjectURL(blob);
  const anchor = document.createElement("a");
  anchor.href = url;
  anchor.download = fileName;
  anchor.rel = "noopener";
  anchor.style.display = "none";
  document.body.appendChild(anchor);
  anchor.click();
  anchor.remove();
  window.setTimeout(() => URL.revokeObjectURL(url), 15_000);
}
