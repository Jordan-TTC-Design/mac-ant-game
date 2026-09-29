import { isStandalone, measureViewport } from "~/utils/viewport";

// Keeps --vp-gap (utils/viewport.ts) up to date: at the start, when the phone is turned, and when the app comes back.
export default defineNuxtPlugin(() => {
  if (!isStandalone()) return;
  const root = document.documentElement;
  const update = () => {
    const vv = window.visualViewport;
    if (vv && vv.height < window.innerHeight - 40) return; // the keyboard is up: its height is not the gap
    root.style.setProperty("--vp-gap", `${measureViewport().gap}px`);
  };
  update();
  window.addEventListener("resize", update);
  window.addEventListener("orientationchange", () => setTimeout(update, 300));
  window.addEventListener("pageshow", update);
  document.addEventListener("visibilitychange", () => document.visibilityState === "visible" && setTimeout(update, 100));
});
