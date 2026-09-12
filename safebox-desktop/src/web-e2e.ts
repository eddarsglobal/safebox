import { protectWebFile, readWebPublicInfo, unlockWebFile, WebSbxError } from "./web-sbx-engine";

const E2E_QUERY = "__safebox_e2e";
const E2E_RESULT_ID = "safebox-web-e2e-result";

function isLoopbackHost(hostname: string): boolean {
  return hostname === "127.0.0.1" || hostname === "localhost" || hostname === "[::1]";
}

function exactArrayBuffer(bytes: Uint8Array): ArrayBuffer {
  const out = new ArrayBuffer(bytes.byteLength);
  new Uint8Array(out).set(bytes);
  return out;
}

function bytesEqual(a: Uint8Array, b: Uint8Array): boolean {
  if (a.byteLength !== b.byteLength) return false;
  let diff = 0;
  for (let i = 0; i < a.byteLength; i += 1) diff |= a[i] ^ b[i];
  return diff === 0;
}

async function mustReject(operation: () => Promise<unknown>): Promise<void> {
  try {
    await operation();
  } catch (error) {
    if (error instanceof WebSbxError || error instanceof Error) return;
    return;
  }
  throw new Error("operation unexpectedly succeeded");
}

async function runBrowserE2E(onMarker: (marker: string) => void): Promise<string[]> {
  const markers: string[] = [];
  const mark = (marker: string): void => {
    markers.push(marker);
    onMarker(marker);
  };
  const code = "R78-browser-e2e-code-7Q!2x";
  const source = new TextEncoder().encode(
    "SAFEBOX R78 browser production E2E\n" + "0123456789abcdef".repeat(8192)
  );
  const original = source.slice();
  let protectedBytes: Uint8Array | null = null;
  let restoredBytes: Uint8Array | null = null;
  let tamperedBytes: Uint8Array | null = null;

  try {
    const sourceFile = new File([exactArrayBuffer(source)], "r78-browser-e2e.txt", { type: "text/plain" });
    source.fill(0);

    const protectedResult = await protectWebFile(sourceFile, code, {
      visibleSbxName: "r78-browser-e2e.sbx",
      keepAfterUnlock: true,
      senderLabel: "SafeBox Browser E2E",
      accessProfile: "R78",
      publicNote: "production browser validation"
    });
    protectedBytes = protectedResult.bytes;
    if (protectedBytes.byteLength <= original.byteLength) throw new Error("protected output is unexpectedly small");
    mark("SAFEBOX_WEB_BROWSER_ENGINE_LOAD_PASS");
    mark("SAFEBOX_WEB_BROWSER_PROTECT_PASS");

    const protectedFile = new File(
      [exactArrayBuffer(protectedBytes)],
      protectedResult.visible_sbx_name,
      { type: "application/x-safebox" }
    );

    // SBX1 is the 4-byte envelope magic. The canonical JSON header field is "SBX".
    if (
      protectedBytes[0] !== 0x53 ||
      protectedBytes[1] !== 0x42 ||
      protectedBytes[2] !== 0x58 ||
      protectedBytes[3] !== 0x31
    ) throw new Error("unexpected SBX1 envelope magic");
    mark("SAFEBOX_WEB_BROWSER_MAGIC_SBX1_PASS");

    const publicInfo = await readWebPublicInfo(protectedFile);
    if (publicInfo.format !== "SBX") throw new Error("unexpected public header format");
    mark("SAFEBOX_WEB_BROWSER_PUBLIC_FORMAT_SBX_PASS");
    if (publicInfo.public_metadata?.access_profile !== "R78") throw new Error("public metadata mismatch");
    mark("SAFEBOX_WEB_BROWSER_PUBLIC_INFO_PASS");

    await mustReject(() => unlockWebFile(protectedFile, "definitely-wrong-code"));
    mark("SAFEBOX_WEB_BROWSER_WRONG_CODE_REJECT_PASS");

    tamperedBytes = protectedBytes.slice();
    if (tamperedBytes.byteLength < 16) throw new Error("protected output too short for tamper test");
    tamperedBytes[tamperedBytes.byteLength - 1] ^= 0x01;
    const tamperedFile = new File([exactArrayBuffer(tamperedBytes)], "r78-browser-tampered.sbx", {
      type: "application/x-safebox"
    });
    await mustReject(() => unlockWebFile(tamperedFile, code));
    mark("SAFEBOX_WEB_BROWSER_TAMPER_REJECT_PASS");

    const unlocked = await unlockWebFile(protectedFile, code);
    restoredBytes = unlocked.bytes;
    if (unlocked.original_file_name !== "r78-browser-e2e.txt") throw new Error("restored filename mismatch");
    if (!bytesEqual(restoredBytes, original)) throw new Error("restored bytes mismatch");
    mark("SAFEBOX_WEB_BROWSER_UNLOCK_PASS");

    // Exercise the same ArrayBuffer boundary required by the real browser download path.
    const downloadBoundary = exactArrayBuffer(restoredBytes);
    const blob = new Blob([downloadBoundary], { type: "application/octet-stream" });
    if (blob.size !== restoredBytes.byteLength) throw new Error("Blob boundary size mismatch");
    mark("SAFEBOX_WEB_BROWSER_BLOB_BOUNDARY_PASS");

    mark("SAFEBOX_WEB_BROWSER_E2E_PASS");
    return markers;
  } finally {
    original.fill(0);
    protectedBytes?.fill(0);
    restoredBytes?.fill(0);
    tamperedBytes?.fill(0);
  }
}

export function installWebBrowserE2E(): void {
  if (typeof window === "undefined" || typeof document === "undefined") return;
  const params = new URLSearchParams(window.location.search);
  if (!isLoopbackHost(window.location.hostname) || params.get(E2E_QUERY) !== "1") return;

  const result = document.createElement("pre");
  result.id = E2E_RESULT_ID;
  result.setAttribute("aria-live", "polite");
  result.textContent = "SAFEBOX_WEB_BROWSER_E2E_BEGIN";
  document.body.appendChild(result);

  result.dataset.status = "running";
  const emitted: string[] = ["SAFEBOX_WEB_BROWSER_E2E_BEGIN"];
  const emitMarker = (marker: string): void => {
    emitted.push(marker);
    result.dataset.lastMarker = marker;
    result.textContent = emitted.join("\n");
  };

  void runBrowserE2E(emitMarker)
    .then(() => {
      result.dataset.status = "pass";
    })
    .catch((error) => {
      result.dataset.status = "fail";
      const message = error instanceof Error ? error.message : String(error);
      result.textContent = [...emitted, `SAFEBOX_WEB_BROWSER_E2E_FAIL: ${message}`].join("\n");
    });
}
