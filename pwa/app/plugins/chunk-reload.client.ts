// After a new version is put up, a page still open from before asks for script files that are no longer there: load the
// app again (once) instead of leaving a blank page.
export default defineNuxtPlugin((nuxtApp) => {
  nuxtApp.hook("app:chunkError", () => {
    if (sessionStorage.getItem("gc-chunk-reload")) return;
    sessionStorage.setItem("gc-chunk-reload", "1");
    reloadNuxtApp({ persistState: false });
  });
  nuxtApp.hook("app:mounted", () => {
    setTimeout(() => sessionStorage.removeItem("gc-chunk-reload"), 10_000);
  });
});
