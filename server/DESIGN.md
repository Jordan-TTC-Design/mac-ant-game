# 哥布林營地・後端設計

> 狀態：2026-09-27 使用者確認（第 11 節已決定，只剩網域與 VPS）。**還沒開始寫程式**；照「分階段」一步一步做，每一步做完都先給使用者看。

## 1. 要做到什麼

- 用信箱＋密碼註冊、登入。
- 便利貼在多台 Mac 與手機（PWA）之間同步；沒登入的 Mac 照舊只存本機。
- 提醒跨裝置：時間到，Mac 上的哥布林跳出來，手機也收到推播；任何一台按「知道了」，其他裝置跟著結束。
- 使用者之間派**使者**交流。
- 保存紀錄（先從便利貼開始，之後是番茄鐘統計、營地紀錄）。

**不做的事（先講清楚）**：不做端對端加密（伺服器看得到便利貼內容）；不做 Google／Apple 登入（之後可加）；Mac 上的營地遊戲本身不搬到伺服器。

## 2. 整體架構

```
ant/
  mac/        Mac App（目前還在 repo 最上層，另一個工作階段做完後再搬）
  server/     後端 API（這份文件所在）
  pwa/        手機網頁
  shared/     資料格式（zod schema）與 API 型別，server 與 pwa 共用
  pnpm-workspace.yaml
```

```
 Mac App ──HTTPS + WebSocket──┐
                              ├── Caddy ── /api/*  → server（Hono，Node 22）── PostgreSQL
 手機 PWA ──HTTPS + WebSocket──┘        └── 其他   → pwa 的靜態檔（Nuxt 產生）
                                                   server ──Web Push──> 手機
                                                   server ──寄信────> Resend／SES
```

- **PWA 與 API 同一個網域**（例如 `https://goblin.<你的網域>/` 是 PWA，`/api/` 是 API）：不用處理 CORS，PWA 的登入 cookie 最單純。
- 一台 VPS 用 Docker Compose 跑 Caddy、server、PostgreSQL；Caddy 自動處理 HTTPS。

### 技術選擇

| 部分 | 用什麼 | 理由 |
|---|---|---|
| 執行環境 | Node 22 LTS | 穩定、套件最多 |
| API 框架 | Hono（`@hono/node-server`、`@hono/node-ws`） | 輕量、型別好 |
| 資料庫 | PostgreSQL 16 + Drizzle ORM（drizzle-kit 管 migration） | SQL 看得懂、型別安全 |
| 驗證輸入 | zod（放在 `shared/`，PWA 共用） | 前後端同一份規則 |
| 密碼 | argon2id（`@node-rs/argon2`） | 目前的建議做法 |
| 推播 | `web-push`（VAPID） | PWA 標準做法 |
| 寄信 | Resend（或 SES） | 見「待決定」 |
| 測試 | vitest + Docker 裡的測試資料庫 | |
| PWA | Nuxt 3（`ssr: false`）+ `@vite-pwa/nuxt` | 使用者熟 Nuxt |

**和之前說的不一樣的地方**：原本說用 pg-boss 做排程。仔細想過後改成**伺服器裡一個每 15 秒跑一次的排程迴圈**，直接查資料庫「到時間的提醒、到達的使者」（`FOR UPDATE SKIP LOCKED`，不怕重複處理）。量不大，少一個套件、少一組資料表，出錯也比較好查。

## 3. 帳號與登入

### 流程

1. **註冊**：信箱＋密碼（至少 10 個字）＋暱稱＋**邀請碼** → 寄驗證信（連結 24 小時有效）。邀請碼只在註冊時需要，之後登入只用信箱與密碼。
2. **驗證信箱**：點連結 → 帳號啟用。**驗證前不能登入**。
3. **登入**：成功後發一個 session token。
   - Mac：token 存在 Keychain，每個請求帶 `Authorization: Bearer <token>`。
   - PWA：token 放在 `HttpOnly; Secure; SameSite=Lax` 的 cookie，JavaScript 讀不到。
4. **忘記密碼**：寄重設連結（1 小時有效）；重設後**所有裝置登出**。
5. **登出**：撤銷這台裝置的 session。設定頁可以看到所有登入中的裝置，逐一登出。
6. **刪除帳號**：馬上停用，30 天後永久刪除所有資料。

### 安全細節

- token 是 32 bytes 隨機值，資料庫只存 SHA-256 雜湊（資料庫外洩也拿不到可用的 token）。信箱驗證、重設密碼的 token 也一樣。
- session 90 天沒用就過期；有使用就延長。
- 登入、註冊、忘記密碼都有頻率限制（例如同一 IP＋信箱每分鐘 5 次）。
- 「忘記密碼」「註冊」的回應不透露這個信箱有沒有註冊過。
- 伺服器的紀錄不寫入便利貼內容與密碼。

## 4. 資料表

```sql
users (
  id              uuid primary key,
  email           citext unique not null,
  password_hash   text not null,
  display_name    text not null,           -- 使者上顯示的名字，不顯示信箱
  friend_code     text unique not null,    -- 例如 GOB-7K2QXM，加好友用
  email_verified_at timestamptz,
  created_at      timestamptz not null,
  deleting_at     timestamptz              -- 要求刪除帳號的時間，30 天後清除
)

sessions (
  id            uuid primary key,
  user_id       uuid references users,
  device_id     uuid references devices,
  token_hash    bytea unique not null,
  created_at, last_seen_at, expires_at, revoked_at  timestamptz
)

devices (
  id            uuid primary key,          -- 裝置自己產生，登入時帶上
  user_id       uuid references users,
  kind          text,                      -- 'mac' | 'pwa'
  name          text,                      -- 「Jordan 的 MacBook」「iPhone」
  push_subscription jsonb,                 -- PWA 的 Web Push 訂閱（Mac 不用）
  last_seen_at  timestamptz
)

invites (
  code_hash     bytea primary key,         -- 邀請碼只存雜湊
  created_by    uuid references users,     -- null = 管理員用指令產生的
  expires_at, used_at  timestamptz,        -- 14 天有效，只能用一次
  used_by       uuid references users
)

email_tokens (
  id, user_id, purpose ('verify' | 'reset'), token_hash, expires_at, used_at
)

notes (
  id            uuid primary key,          -- 由裝置產生（就是 Mac notes.json 裡的 id）
  user_id       uuid references users,
  text          text not null,             -- 最多 5000 字
  color, breed, goblin_name   text,
  due_at, remind_at           timestamptz,
  remind_fired  boolean,
  done          boolean,
  deleted       boolean,                   -- 刪除標記，內容清空
  created_at    timestamptz,
  updated_at    timestamptz,               -- 裝置說的修改時間（只用來顯示）
  seq           bigint not null,           -- 伺服器的變更序號，同步靠它
  pushed_for    timestamptz                -- 已經為哪個 remind_at 發過推播（避免重複）
)

friendships (
  user_a, user_b  uuid,                    -- user_a < user_b，一對只有一筆
  requested_by    uuid,
  status          text,                    -- 'pending' | 'accepted' | 'blocked'
  created_at      timestamptz
)

messengers (
  id            uuid primary key,
  from_user, to_user  uuid,
  kind          text,                      -- 'message' | 'kudos' | 'note'（見第 7 節）
  body          text,                      -- 最多 200 字
  note_payload  jsonb,                     -- kind = 'note' 時帶的便利貼
  goblin_breed, goblin_name  text,         -- 寄件人派出的是哪隻哥布林
  sent_at, arrive_at, delivered_at, read_at  timestamptz,
  reply_to      uuid
)
```

每個使用者最多 500 張便利貼（含刪除標記）。刪除標記保留 30 天，所有裝置都同步過之後就可以清掉。

## 5. 便利貼同步

### 原則

- **離線優先**：Mac 與 PWA 都先改本機，再送到伺服器；沒網路時照常使用，連上後補送。
- **伺服器給每次變更一個遞增的 `seq`**：裝置只要記得「我同步到第幾號」，下次問「這號之後有什麼變了」。不依賴各台電腦的時鐘。
- **便利貼的位置不同步**：每台螢幕不一樣，位置只留在各自的 Mac。

### API

| 方法 | 路徑 | 做什麼 |
|---|---|---|
| GET | `/api/notes/changes?since=<seq>` | 回傳 `seq` 之後變過的便利貼與最新的 `seq` |
| POST | `/api/notes/push` | 送出本機改過的便利貼，每張附上它「改之前看到的 `seq`」（`baseSeq`） |

### 衝突

兩台裝置都改了同一張（伺服器那張的 `seq` 比 `baseSeq` 新）：

- **只改了不同的欄位**（一台改文字、一台改提醒時間）→ 兩邊合併。
- **兩邊都改了文字** → 伺服器那份保留，裝置那份另存成一張新的便利貼，開頭加「（衝突副本）」。不會有人寫的字消失。
- **一邊刪除、一邊修改** → 修改的贏（刪除被取消），避免誤刪。

### 第一次登入

Mac 上已經有的便利貼全部上傳，伺服器上已經有的（例如另一台 Mac 的）全部下載，兩邊合併。登出時問：「要保留這台 Mac 上的便利貼嗎？」

## 6. 即時更新與提醒

### WebSocket（`/api/ws`）

登入的裝置連上後，伺服器會推：

| 事件 | 意思 | 裝置怎麼做 |
|---|---|---|
| `notes.changed` | 有便利貼變了 | 呼叫 `/api/notes/changes` 拉回來 |
| `messenger.arrived` | 有使者到了 | Mac：哥布林從螢幕邊走進來；PWA：顯示在收件匣 |
| `friend.request` | 有人想加你好友 | 顯示在選單／好友頁 |

斷線自動重連；連不上時每 5 分鐘自己拉一次。

### 提醒怎麼跨裝置

- **Mac**：照現在的方式在本機排時間（斷線也會響）。專注模式時照舊等你離開才出現。
- **手機**：伺服器的排程迴圈看到 `remind_at` 到了、還沒發過（`pushed_for` 不等於 `remind_at`），就發 Web Push 給這個人所有 PWA 裝置。
- **任何一台按「知道了」**：這張便利貼的 `remind_at` 清掉、同步出去；其他 Mac 上還在說話的哥布林會離開。
- **按「10 分鐘後」「明天」**：改 `remind_at`，所有裝置到時候再響一次。
- **限制**：iPhone 上已經跳出的推播通知，沒辦法從伺服器收回（iOS 規定每則推播都要顯示）；下次打開 PWA 時才清掉。

## 7. 使者（使用者之間交流）

### 規則（先求簡單，之後再加玩法）

- **只能派給好友**：用對方的好友代碼（例如 `GOB-7K2QXM`）送出邀請，對方同意才成為好友。這樣不會被陌生人騷擾，也不會洩漏信箱。
- **可以派的**：
  - `message`：一句話（最多 200 字）
  - `kudos`：一句「謝啦」「辛苦了」之類的，附一個小圖示
  - `note`：**把一張便利貼送過去**。對方接受後，這張便利貼貼到他的桌面，住著你的哥布林。例如「幫我看一下這個 PR」。
- **使者要走一段路**：送出後 1～3 分鐘才到（隨機），到了才出現。這是遊戲的味道；伺服器決定到達時間，客戶端改不了。
- **到達時**：
  - Mac：寄件人營地裡的一隻哥布林（照品種）從螢幕邊走進來，舉著卷軸，泡泡上顯示內容，可以回覆。
  - 專注模式：照舊等離開才出現。
  - 手機：收到推播，收件匣裡有一封。
- **防濫用**：每人每天最多派 50 個；可以封鎖好友；封鎖後對方派不過來，也不會知道被封鎖。

之後可以加的（不在第一版）：使者被魔獸攔截、派送營地素材當禮物、團隊（一群人的共同營地）。

## 8. 客戶端要改的

### Mac App

- 選單新增「帳號」：登入／註冊視窗、登入中的裝置、登出。**不登入一切照舊**。
- `SyncEngine`：
  - 啟動時、便利貼改動後（等 1 秒再送）、收到 WebSocket 事件時同步。
  - 每張便利貼在本機另外記同步狀態（`seq`、有沒有還沒送出去的改動），放在 `notes.json` 的本機區塊。
- 使者：用現在的 `MessageStage` 走進來，泡泡上可以回覆（和 Claude 的回覆泡泡同一套）。
- 好友：選單「好友…」小視窗，顯示自己的好友代碼、加好友、好友列表。

### PWA（手機）

- 頁面：登入／註冊、便利貼列表（每張有會動的點陣哥布林，用 Mac 的同一套精靈圖）、編輯（文字、提醒、目標時間、顏色、完成）、使者收件匣、好友、設定（開啟推播、登出）。
- 離線：App 外殼快取起來，便利貼存在 IndexedDB，連上後同步。
- iPhone 要 iOS 16.4 以上，並且先「加入主畫面」才收得到推播；第一次開啟時會教使用者怎麼做。

## 9. 部署

- 一台 VPS（2 vCPU / 2 GB 就夠）：`docker compose up -d` 跑 caddy、server、postgres。
- PostgreSQL 每天備份（`pg_dump`）到外部的物件儲存，保留 14 天。
- 發新版：`git pull && docker compose up -d --build`；資料庫 migration 在 server 啟動時自動跑。
- 需要準備：網域（設一個子網域）、VPS、寄信服務帳號（寄件網域要設 DNS 記錄）、VAPID 金鑰（我產生）。

## 10. 分階段

每一階段做完都能單獨使用、單獨測試，做完先給你看再往下。

| 階段 | 內容 | 做完可以 |
|---|---|---|
| 0 ✅ | pnpm workspace、`server/` `shared/` 骨架、本機用 Docker 跑 PostgreSQL、健康檢查、migration（2026-09-27 完成） | 本機跑得起來 |
| 1 ✅ | 帳號（2026-09-27 完成；刪除帳號留到之後）：邀請碼（`pnpm invite create` 產生）、註冊、驗證信（本機先印在終端機）、登入、登出、忘記密碼、頻率限制、測試 | 用 curl 或測試跑完整流程 |
| 2 ✅ | 便利貼同步 API＋WebSocket；Mac 的登入視窗與 `SyncEngine`（2026-09-27 完成） | 兩台 Mac 之間同步便利貼 |
| 3 | PWA：登入、便利貼列表與編輯、離線、推播；伺服器的提醒推播 | 手機看、改便利貼，收到提醒 |
| 4 | 好友與使者：API、Mac 上使者走進來、PWA 收件匣 | 同事之間派使者、送便利貼 |
| 5 | 部署到 VPS、備份、Mac App 發新版 | 同事真的能用 |

之後的點子（不在這六個階段裡）：**大世界與對戰**（真實地圖上的領地、魔獸巢穴、遠征與使用者之間的對戰），見 [WORLD.md](WORLD.md)。排在階段 5 之後；它需要伺服器保存和世界、對戰有關的營地資料，和第 1 節「營地遊戲本身不搬到伺服器」相衝，到時候要重新決定。

## 11. 決定（2026-09-27）

1. **網域與 VPS**：未定，到階段 5 再決定。
2. **寄信服務**：**Resend**。本機開發時信只印在終端機；部署時需要網域的 DNS 記錄與 Resend 的 API 金鑰。
3. **驗證信箱前不能登入**。
4. **邀請制**：帳號仍是信箱＋密碼，註冊時多填一組邀請碼。先由管理員用 `pnpm invite create` 產生，一組只能用一次、14 天有效；之後可再加「每位使用者有幾組邀請碼」。
5. **Mac 在專注模式時，手機照樣收到提醒推播**（伺服器不需要知道 Mac 的模式）。
6. **使者**：照第 7 節的規則（只限好友、1～3 分鐘路程、可以送一句話、謝啦或便利貼）。
