import { fileURLToPath } from "node:url";

// The phone app: a single-page app (no server rendering; it is behind a login) that works offline and gets reminder pushes.
// In development it runs on :3000 and passes /api to the server on :8787 (the WebSocket goes to :8787 directly, see useNotes).
export default defineNuxtConfig({
  compatibilityDate: "2026-09-01",
  ssr: false,
  devtools: { enabled: false },
  modules: ["@vite-pwa/nuxt"],
  css: ["~/assets/main.css"],
  app: {
    head: {
      title: "哥布林營地",
      htmlAttrs: { lang: "zh-Hant-TW" },
      meta: [
        { name: "viewport", content: "width=device-width, initial-scale=1, viewport-fit=cover" },
        { name: "theme-color", content: "#2f4a2a" },
        { name: "mobile-web-app-capable", content: "yes" },
        { name: "apple-mobile-web-app-capable", content: "yes" },
        { name: "apple-mobile-web-app-status-bar-style", content: "black-translucent" },
        { name: "apple-mobile-web-app-title", content: "哥布林營地" },
      ],
      link: [{ rel: "apple-touch-icon", href: "/icons/apple-touch-icon.png" }],
    },
  },
  nitro: {
    devProxy: { "/api": { target: "http://localhost:8787/api" } },
  },

  pwa: {
    strategies: "injectManifest",
    srcDir: fileURLToPath(new URL("./service-worker", import.meta.url)),
    filename: "sw.ts",
    registerType: "autoUpdate",
    injectRegister: "auto",
    manifest: {
      name: "哥布林營地",
      short_name: "哥布林營地",
      description: "哥布林便利貼：和 Mac 同步，時間到會提醒你。",
      lang: "zh-Hant-TW",
      start_url: "/",
      display: "standalone",
      background_color: "#2f4a2a",
      theme_color: "#2f4a2a",
      icons: [
        { src: "/icons/icon-192.png", sizes: "192x192", type: "image/png" },
        { src: "/icons/icon-512.png", sizes: "512x512", type: "image/png" },
        { src: "/icons/maskable-512.png", sizes: "512x512", type: "image/png", purpose: "maskable" },
      ],
    },
    injectManifest: { globPatterns: ["**/*.{js,css,html,png,svg,ico,woff2}"] },
    devOptions: { enabled: true, type: "module" },
  },
});
