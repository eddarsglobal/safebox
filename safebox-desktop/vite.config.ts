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
const SAFEBOX_ADSENSE_PUBLISHER_ID = "ca-pub-3925930420157238";
const SAFEBOX_LANDING_CSP = SAFEBOX_WEB_CSP.replace(
  "script-src 'self' 'wasm-unsafe-eval'",
  "script-src 'self' 'wasm-unsafe-eval' https://pagead2.googlesyndication.com"
);

function webSecurityMetaPlugin(): Plugin {
  return {
    name: "safebox-web-security-meta",
    transformIndexHtml(html, context) {
      const landing = context.path === "/" || context.path.endsWith("/index.html");
      const csp = landing ? SAFEBOX_LANDING_CSP : SAFEBOX_WEB_CSP;
      const securedHtml = html.replace(
        "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\" />",
        `<meta name="viewport" content="width=device-width, initial-scale=1.0" />\n    <meta http-equiv="Content-Security-Policy" content="${csp}" />\n    <meta name="referrer" content="no-referrer" />`
      );
      if (!landing) return securedHtml;
      return securedHtml.replace(
        "</head>",
        `    <meta name="google-adsense-account" content="${SAFEBOX_ADSENSE_PUBLISHER_ID}" />\n    <script async src="https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js?client=${SAFEBOX_ADSENSE_PUBLISHER_ID}" crossorigin="anonymous"></script>\n  </head>`
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
