# 哥布林營地・後端

帳號、便利貼同步、使者的 API。設計與分階段計畫見 [DESIGN.md](DESIGN.md)。

## 需要

- Node 22（`.nvmrc`）
- pnpm 12：`npm install -g pnpm@12`（不想全域安裝的話，把下面的 `pnpm` 換成 `npx pnpm@12.6.0`）
- Docker Desktop（本機的 PostgreSQL 跑在裡面，要先打開）

## 常用指令（在 repo 最上層執行）

```bash
pnpm install          # 第一次，或依賴有變時
pnpm db:up            # 啟動本機資料庫（PostgreSQL 16，127.0.0.1:5433；另有測試用的 goblin_test）
cp server/.env.example server/.env
pnpm dev              # 啟動伺服器（改程式會自動重啟），http://localhost:8787/api/health
pnpm test             # 跑測試（用 goblin_test，不會動到開發資料）
pnpm typecheck        # 型別檢查
pnpm db:down          # 關掉資料庫（資料保留在 Docker volume 裡）
pnpm invite create --count 3 --days 14   # 產生邀請碼（只顯示這一次）
pnpm invite list      # 還能用／已使用／過期的數量
```

開發時不會真的寄信：信件（含確認、重設密碼的連結）會印在 `pnpm dev` 的終端機上。

## API（階段 1：帳號）

都在 `/api/auth` 底下，送 JSON。錯誤一律是 `{ "error": "代碼", "message": "給人看的一句話" }`。

| 方法 | 路徑 | 做什麼 |
|---|---|---|
| POST | `/register` | 信箱、密碼（至少 10 字）、暱稱、邀請碼 → 寄確認信。信箱已註冊也回一樣的 202，不透露 |
| POST | `/verify-email` | 確認信裡的 token → 帳號啟用（連結 24 小時有效、只能用一次） |
| POST | `/resend-verification` | 再寄一次確認信 |
| POST | `/login` | 信箱、密碼、裝置（`id` 由裝置產生的 UUID、`kind` mac／pwa、`name`）→ Mac 拿到 token（`Authorization: Bearer`），手機拿到 HttpOnly cookie |
| POST | `/logout` | 登出這台裝置 |
| GET | `/me` | 目前登入的人 |
| GET | `/sessions` | 登入中的裝置 |
| DELETE | `/sessions/:id` | 讓某台裝置登出 |
| POST | `/forgot-password` | 寄重設密碼信（1 小時有效）；一律回 202 |
| POST | `/reset-password` | token＋新密碼 → 所有裝置登出 |

頻率限制（在記憶體裡，重開伺服器歸零）：登入同一信箱每分鐘 5 次、同一 IP 每分鐘 30 次；註冊每 IP 每小時 10 次；寄確認信、忘記密碼每個信箱每小時 3 次。

改資料表：編輯 `server/src/db/schema.ts`，在 `server/` 裡執行 `pnpm db:generate` 產生新的 migration（`server/drizzle/`，要 commit）。伺服器每次啟動都會自動套用還沒跑過的 migration。

## 結構

```
server/
  src/
    index.ts        啟動：讀設定、連資料庫、跑 migration、開始聽 port
    app.ts          API 路由（不含網路層，測試直接呼叫）
    config.ts       環境變數（缺了或錯了會直接說哪裡錯）
    db/             資料表定義、連線、migration
  drizzle/          migration 檔（SQL）
  test/             測試
  compose.dev.yml   本機開發用的資料庫
shared/             server 與 pwa 共用的資料格式（zod）
```

## API（階段 2：便利貼同步）

需要登入（Mac：`Authorization: Bearer`；手機：cookie）。

| 方法 | 路徑 | 做什麼 |
|---|---|---|
| GET | `/api/notes/changes?since=N` | `seq` 大於 N 的便利貼（每次最多 500 張，`more` 表示還有），回傳新的 `seq` |
| POST | `/api/notes/push` | `{ changes: [{ id, baseSeq, fields, createdAt? }] }`，一次最多 100 張；`fields` 只放改過的欄位，新的便利貼要放齊全部欄位 |
| GET | `/api/ws` | WebSocket。連上先收到 `hello`，之後有便利貼變了就收到 `{ "type": "notes.changed", "seq": N }`，收到後去拉 `/changes`；登出時伺服器會用 4001 關掉 |

`push` 每張的結果：`applied`（照收）、`merged`（別台改了其他欄位，兩邊都留）、`conflict_copy`（兩邊都改了文字：伺服器的留著，這台的變成一張新的「（衝突副本）」，在 `copy`）、`delete_refused`（別台改過，刪除不算）、`rejected`（`reason`：`incomplete` 新便利貼欄位不齊、`id_taken` 別人的 id、`limit` 超過 500 張、`not_found`）。

## API（階段 3：手機推播）

| 方法 | 路徑 | 做什麼 |
|---|---|---|
| GET | `/api/push/key` | 推播用的公開金鑰（沒設定時是 `null`） |
| POST | `/api/push/subscribe` | 手機（`kind: pwa` 的裝置）把瀏覽器給的訂閱交給伺服器 |
| DELETE | `/api/push/subscribe` | 不要再推播到這支手機 |

伺服器每 15 秒找一次到時間的提醒（`remind_at` 到了、還沒為這個時間推過 `pushed_for`、沒刪除、不超過一天前），推播到這個人所有訂閱了的手機；延後（改了時間）會再推一次。推播服務說這支手機不在了（404／410）就把訂閱清掉。金鑰：`pnpm --filter @goblincamp/server vapid` 產生一組，填進 `server/.env` 的 `VAPID_PUBLIC_KEY`、`VAPID_PRIVATE_KEY`（沒填的話手機收不到提醒，其他照常）。

