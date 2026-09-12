import { existsSync, readFileSync } from "node:fs";
import { resolve } from "node:path";

const root = process.cwd();
const landing = resolve(root, "dist/index.html");
const app = resolve(root, "dist/app.html");

if (!existsSync(landing)) {
  throw new Error(`SAFEBOX native bundle missing landing entry: ${landing}`);
}
if (!existsSync(app)) {
  throw new Error(`SAFEBOX native bundle missing crypto app entry: ${app}`);
}

const appHtml = readFileSync(app, "utf8");
if (!/assets\/[^"']+\.js/.test(appHtml)) {
  throw new Error("SAFEBOX crypto app entry has no built JavaScript asset");
}

console.log("SAFEBOX_ANDROID_R86_RC6_APP_HTML_BUNDLE_PASS");
