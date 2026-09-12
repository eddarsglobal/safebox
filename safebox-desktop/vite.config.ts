import { defineConfig, type Plugin } from "vite";
import { resolve } from "node:path";

const host = process.env.TAURI_DEV_HOST;

const SAFEBOX_WEB_CSP = [
  "default-src 'self'",
  "base-uri 'none'",
  "object-src 'none'",
  "form-action 'none'",
  "script-src 'self' 'wasm-unsafe-eval'",
  "style-src 'self' 'unsafe-inline'",
  "img-src 'self' data: blob:",
  "font-src 'self'",
  "connect-src 'self'",
  "worker-src 'none'",
  "media-src 'none'",
  "manifest-src 'self'"
].join("; ");

function webSecurityMetaPlugin(): Plugin {
  return {
    name: "safebox-web-security-meta",
    transformIndexHtml(html) {
      return html.replace(
        "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\" />",
        `<meta name="viewport" content="width=device-width, initial-scale=1.0" />\n    <meta http-equiv="Content-Security-Policy" content="${SAFEBOX_WEB_CSP}" />\n    <meta name="referrer" content="no-referrer" />`
      );
    }
  };
}

export default defineConfig(({ mode }) => ({
  base: process.env.SAFEBOX_WEB_BASE || "./",
  clearScreen: false,
  plugins: mode === "web" ? [webSecurityMetaPlugin()] : [],
  // SAFEBOX R86 RC6: both the landing page and the crypto app must exist in
  // every bundle. Android/iOS Tauri builds use the normal Vite mode, while the
  // landing CTAs navigate to app.html. Keeping this multi-page input web-only
  // produced APKs containing index.html but no app.html.
  build: {
    rollupOptions: {
      input: {
        landing: resolve(__dirname, "index.html"),
        app: resolve(__dirname, "app.html")
      }
    }
  },
  server: {
    port: 1420,
    strictPort: true,
    host: host || "127.0.0.1",
    hmr: host
      ? { protocol: "ws", host, port: 1421 }
      : undefined,
    watch: { ignored: ["**/src-tauri/**"] }
  }
}));
