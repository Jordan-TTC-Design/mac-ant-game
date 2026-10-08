/**
 * A new version of the app. The service worker takes over by itself once it has installed, but the page that is open keeps the old
 * program until it is loaded again: so when a new version has taken over, a line says so with a button, and the settings have one
 * to load the latest at any time (and one for when it will not update: forget the stored copies and fetch everything again).
 */
const ready = ref(false);
let watching = false;

export function useAppUpdate() {
  /** Asks for a new version now (the browser would only look now and then). */
  async function check() {
    if (!("serviceWorker" in navigator)) return;
    try {
      const registration = await navigator.serviceWorker.getRegistration();
      await registration?.update();
    } catch {
      // (offline: nothing to look at)
    }
  }

  /** Looks for a new version when the app comes back to the front and every quarter of an hour; says when one has taken over. */
  function watch() {
    if (watching || !("serviceWorker" in navigator)) return;
    watching = true;
    const hadController = !!navigator.serviceWorker.controller; // (the first visit has none: nothing to update from)
    navigator.serviceWorker.addEventListener("controllerchange", () => {
      if (hadController) ready.value = true;
    });
    document.addEventListener("visibilitychange", () => {
      if (document.visibilityState === "visible") void check();
    });
    setInterval(() => void check(), 15 * 60_000);
    void check();
  }

  /** Loads the page again: the latest version, if one is there. */
  async function reload() {
    await check();
    location.reload();
  }

  /** For when the app will not update: the stored copies of it (and of the pictures) are forgotten and everything is fetched again. Staying signed in. */
  async function reset() {
    try {
      const registrations = "serviceWorker" in navigator ? await navigator.serviceWorker.getRegistrations() : [];
      await Promise.all(registrations.map((r) => r.unregister()));
      for (const key of await caches.keys()) await caches.delete(key);
    } finally {
      location.reload();
    }
  }

  return { ready, watch, check, reload, reset };
}
