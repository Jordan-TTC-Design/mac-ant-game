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
```

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
