// Applies the saved or system colour theme before the page paints.
// Loaded as a separate, non-deferred script (not inline) so the
// Content-Security-Policy can allow scripts from our own origin only.
(() => {
  const systemTheme = () => matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light";

  // Storage can throw (e.g. blocked in some privacy modes); the theme then just
  // isn't remembered, instead of the script stopping before first paint.
  const stored = {
    get: () => { try { return localStorage.getItem("phx:theme"); } catch { return null; } },
    set: (theme) => { try { localStorage.setItem("phx:theme", theme); } catch { /* not remembered */ } },
    remove: () => { try { localStorage.removeItem("phx:theme"); } catch { /* not remembered */ } },
  };

  const setTheme = (theme) => {
    if (theme === "system") {
      stored.remove();
      document.documentElement.setAttribute("data-theme", systemTheme());
      document.documentElement.setAttribute("data-theme-source", "system");
    } else {
      stored.set(theme);
      document.documentElement.setAttribute("data-theme", theme);
      document.documentElement.setAttribute("data-theme-source", "user");
    }
  };
  if (!document.documentElement.hasAttribute("data-theme")) {
    setTheme(stored.get() || "system");
  }
  window.addEventListener("storage", (e) => e.key === "phx:theme" && setTheme(e.newValue || "system"));
  window.addEventListener("phx:set-theme", (e) => setTheme(e.target.dataset.phxTheme));

  matchMedia("(prefers-color-scheme: dark)").addEventListener("change", (e) => {
    if (document.documentElement.getAttribute("data-theme-source") === "system") {
      document.documentElement.setAttribute("data-theme", systemTheme());
    }
  });
})();
