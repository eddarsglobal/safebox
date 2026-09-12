(() => {
  const key = "safebox-theme-mode.v1";
  const legacyLanding = "safebox.theme";
  const legacyApp = "safebox-theme";
  const valid = value => value === "system" || value === "light" || value === "dark";
  let mode = localStorage.getItem(key) || localStorage.getItem(legacyLanding) || localStorage.getItem(legacyApp) || "system";
  if (!valid(mode)) mode = "system";
  const resolved = mode === "system" ? (matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light") : mode;
  document.documentElement.dataset.themeMode = mode;
  document.documentElement.dataset.theme = resolved;
})();
