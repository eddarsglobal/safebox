function routeSafeBoxApp() {
  const mode = new URLSearchParams(location.search).get("mode") || location.hash.replace(/^#/, "");
  if (mode === "open" || mode === "unlock") {
    document.querySelector<HTMLButtonElement>("#switchUnlockBtn")?.click();
    document.querySelector<HTMLElement>("#unlockPanel")?.scrollIntoView({ block: "start" });
  } else if (mode === "create") {
    document.querySelector<HTMLButtonElement>("#switchCreateBtn")?.click();
    document.querySelector<HTMLElement>("#createPanel")?.scrollIntoView({ block: "start" });
  }
}
requestAnimationFrame(() => requestAnimationFrame(routeSafeBoxApp));
