const SHEETS = {
  "web.whatsapp.com": "whatsapp.css",
  "teams.microsoft.com": "teams.css",
  "teams.cloud.microsoft": "teams.css",
  "teams.live.com": "teams.css",
};

const sheet = SHEETS[location.hostname];

if (sheet) {
  const style = document.createElement("style");
  style.id = "matugen-pwa-theme";
  document.documentElement.append(style);

  const refresh = async () => {
    try {
      const url = `${chrome.runtime.getURL(sheet)}?t=${Date.now()}`;
      const res = await fetch(url, { cache: "no-store" });
      if (!res.ok) return;
      const css = await res.text();
      if (css !== style.textContent) style.textContent = css;
    } catch {
      // The sheet doesn't exist until DMS has generated a theme once.
    }
  };

  refresh();
  window.addEventListener("focus", refresh);
  document.addEventListener("visibilitychange", () => {
    if (!document.hidden) refresh();
  });
}
