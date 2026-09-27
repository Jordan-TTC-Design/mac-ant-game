# 哥布林營地・手機網頁（PWA）

登入後看、寫便利貼，和 Mac 同步；提醒時間到手機會收到通知。Nuxt 4（`ssr: false`，純前端）＋ `@vite-pwa/nuxt`。

## 開發（在 repo 最上層）

```bash
nvm use               # Node 22.19 以上（Nuxt 4 需要）
pnpm db:up && pnpm dev   # 資料庫與伺服器（:8787）
pnpm pwa              # 手機網頁（http://localhost:3000，/api 轉給 :8787）
pnpm pwa:build        # 產生 pwa/.output/public（靜態檔，部署時由 Caddy 送出）
```

- 精靈圖直接用 Mac 的（`scripts/copy-sprites.mjs` 在 dev／build 前複製到 `public/sprites/`，不進 git）；App 圖示在 `public/icons/`，由哥布林頭像放大而成。
- 開發時 WebSocket 直接連 `ws://localhost:8787`（Nitro 的開發用 proxy 不轉 WebSocket）；正式環境同一個網域。
- 推播要伺服器設好 VAPID 金鑰（`server/.env`）。iPhone 要 iOS 16.4 以上，並且「加入主畫面」後從主畫面打開，才收得到。
- TypeScript 用 5.9：`vue-tsc`（`nuxt typecheck`）需要 TypeScript 的 JavaScript API，TypeScript 7 沒有。伺服器那邊用 7。

## 結構

```
app/
  pages/          index（便利貼列表）、note/[id]（編輯）、login（登入／註冊）、settings（通知、裝置、登出）、
                  verify-email、forgot-password、reset-password（信裡的連結開這些頁）
  composables/    useAccount（誰登入）、useNotes（便利貼與同步，規則和 Mac 的 Sync.swift 一樣）、useSignedIn
  components/     NoteCard、GoblinSprite（用 Mac 的精靈圖，心情也一樣：平常、快到、遲了、響鈴、完成）
  utils/          api、time、push
service-worker/sw.ts   離線快取、顯示提醒推播、點通知打開那張便利貼
```
