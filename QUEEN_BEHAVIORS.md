# 蟻后行為（QUEEN_BEHAVIORS）

蟻后從蟻窩洞口慢慢爬出來後，不會只是站著，而是每隔幾秒隨機做一件「自己的事」，也會對滑鼠、新生螞蟻做出反應。
實作在 `Sources/AntFarm/Queen.swift`（狀態機）、`Colony.swift`（蛋、泥土、小石頭、里程碑等事件）、`AntView.swift`（繪製）。

## 20 個動作（全部已實作）

### A. 基本動作
| # | 動作 | 說明 | 狀態 |
|---|------|------|------|
| 1 | 繞巢小散步 | 在家附近 12～30px 內隨機挑點慢慢走 | `wandering` |
| 2 | 原地轉圈 | 轉兩圈再停下（1.3 秒） | `spinning` |
| 3 | 發呆 | 停 2～6 秒（偶爾 6～12 秒），觸角偶爾抖一下 | `resting` |
| 4 | 梳理觸角 | 兩根觸角輪流往頭部擺，2.5 秒 | `grooming` |
| 5 | 來回張望 | 身體左右各轉約 30 度，2.6 秒 | `lookingAround` |
| 6 | 鑽進洞口 | 走進洞口漸漸消失，3～6 秒後再走出來 | `enteringHole` / `inHole` / `leavingHole` |

### B. 需要多畫一點東西
| # | 動作 | 說明 | 狀態 |
|---|------|------|------|
| 7 | 探出頭又縮回去 | 鑽進洞後，只露出前半身、觸角揮動，3.2 秒後縮回 | `peeking`（身體以洞口為界裁切） |
| 8 | 挖土 | 面向洞口，5 秒內每 0.8 秒在洞口周圍冒出一粒土 | `digging` + `Colony.dirt`（最多 10 粒，40 秒後淡出） |
| 9 | 搬小石頭 | 走到 35～50px 外，嘴裡叼一顆灰色小石頭走回洞口旁放下 | `fetching` / `carrying` + `Colony.pebbles`（最多 6 顆，90 秒後淡出） |
| 10 | 修補巢口 | 繞洞口走一圈（半徑 12px）壓平土，土粒快速淡出，蟻窩短暫膨脹一下 | `patchApproach` / `patching` + `Colony.nestPulse` |
| 11 | 產卵 | 停下 2.6 秒，身後放一顆小白蛋，8 秒後淡出 | `layingEgg` + `Colony.eggs` |
| 12 | 睡覺 | 觸角下垂，頭上飄出 z z z，8～14 秒 | `sleeping` |

### C. 有情境的動作
| # | 動作 | 說明 | 觸發 |
|---|------|------|------|
| 13 | 迎接新生 | 轉向新螞蟻，觸角揮動 1.8 秒 | 每次生成螞蟻（`Queen.greet`） |
| 14 | 目送出門 | 迎接後接著面向那隻新螞蟻，緩緩轉頭追著牠 4 秒 | 迎接結束後（`watching`） |
| 15 | 游標好奇 | 游標在 220px 內且移動緩慢時，走向游標方向（最多 26px）、面向它嗅一嗅，最多 6 秒 | 發呆時，平均每 6～7 秒一次機會（`curious`） |
| 16 | 被打擾 | 游標在 120px 內快速掃過（> 1200 px/s）就飛快躲進洞裡，躲 6～10 秒 | 發呆時；20 秒冷卻 |
| 17 | 回應點擊 | 點蟻窩（26px 內）時她鑽進洞再探頭；若已在洞裡就直接探頭 | 全域滑鼠監聽（`Queen.poke`）；**點擊不會被攔截**，下面的 App 照常收到 |

### D. 彩蛋
| # | 動作 | 說明 | 狀態 |
|---|------|------|------|
| 18 | 打哈欠 | 頭部先變大再縮回，旁邊冒兩顆小氣泡，2.2 秒 | `yawning` |
| 19 | 跳舞 | 螞蟻數達 10 / 50 / 100 / 200 / 300 / 400 / 500 時，身體左右扭動、觸角亂擺 2.5 秒 | `dancing`（`Colony.milestones`） |
| 20 | 想事情 | 頭上冒出想法泡泡，裡面是 🍎 🍰 💭 🍯 🌿 其中之一，3.5 秒 | `thinking` |

### 登場方式
放好蟻窩後，蟻后從洞口慢慢爬出來（約 3 秒）：她一開始藏在洞口後方，只有「已經越過洞口」的那一段身體看得到（`Queen.clipLine`），爬到她的位置才開始計時生螞蟻。`emerging` 狀態。

## 狀態機

```
emerging ──爬出洞口──▶ resting ──計時結束，依權重隨機挑下一個──▶
   ├ 20%  wandering        走到隨機點 ──▶ resting
   ├ 12%  grooming
   ├  8%  enteringHole ─▶ inHole(3~6s) ─▶ leavingHole ─▶ resting
   ├  8%  layingEgg        剩 1 秒時產卵
   ├  5%  spinning
   ├  6%  lookingAround
   ├  6%  enteringHole(peekPending) ─▶ inHole ─▶ peeking ─▶ inHole(1.2s) ─▶ leavingHole
   ├  7%  digging
   ├  6%  fetching ─▶ carrying ─▶ (放下石頭) ─▶ resting
   ├  5%  patchApproach ─▶ patching ─▶ wandering(回家) ─▶ resting
   ├  5%  sleeping
   ├  4%  yawning
   ├  5%  thinking
   └  3%  長 resting（6~12 秒）

外部觸發（只在 resting 時檢查，有 reactCooldown）：
   游標快速掃過 ─▶ 快速 enteringHole（躲長一點）      游標慢慢靠近 ─▶ curious ─▶ wandering(回家)
外部觸發（隨時，但 emerging / 洞裡的狀態會忽略）：
   greet(新螞蟻) ─▶ greeting ─▶ watching ─▶ resting     celebrate(里程碑) ─▶ dancing ─▶ resting
   poke(點蟻窩)  ─▶ 鑽進洞再探頭
```

- 動作之間一定先休息 2～6 秒，不會連續做事。
- 走路速度：爬出洞口 10 px/s、散步 22、搬石頭 20、進出洞 18（被嚇到 70、被點擊 40）；轉向最快 6 rad/s，離目標很近時會自動加快轉向，否則會在原地繞圈（見下方「踩過的坑」）。
- 進出洞時透明度隨與洞口的距離漸變（`Queen.alpha`）；探頭時以身體為基準裁掉洞口以下的部分（`Queen.emergence`）。
- 觸角姿勢由 `Queen.antennae` 提供，頭的大小由 `Queen.headScale`（打哈欠）提供，飄浮圖示由 `Queen.decoration` 提供，`AntView.drawDecoration` 負責畫。
- 散步與搬石頭的目標若不在任何螢幕內（巢在螢幕邊緣時）會放棄，改成發呆。
- 每個走路動作有 20 秒逾時保險，不會永遠卡住。

## 怎麼新增一個動作

1. 在 `Queen.State` 加一個 case（需要參數就帶關聯值），`stateName` 補上名字。
2. 在 `Queen.update` 加對應的分支（計時、走路、結束後 `beginResting()`）。
3. 在 `pickNextAction` 的權重表加一段，調整其他權重使總和為 100。
4. 需要畫新東西：由 `update` 回傳 `Queen.Event`，`Colony.tick` 處理，`AntView` 繪製；浮在頭旁的圖示加 `Queen.Decoration`。
5. 想在畫面上檢查，用 `ANT_QUEEN_FORCE` 加自我截圖（見 README），並在 `Queen.debugForce` 補上名字。
6. 在本文件更新。

## 驗證紀錄

- **純邏輯模擬**（`Queen.swift` 單獨編譯，30fps）：
  - 爬出洞口約 2.9 秒；爬出時有裁切線、到家後沒有。
  - 閒置 60 分鐘：所有動作都會出現（散步 122、梳理 53、進洞 58、探頭 18、產卵 33、挖土 37、搬石頭 27、修補 40、睡覺 20、打哈欠 24、想事情 18…），最遠離巢 53px，沒有 NaN。
  - 滑鼠快速掃過近處 → 躲進洞；掃過遠處 → 沒反應。慢慢靠近 150px 外 → 20 次裡 18 次在 20 秒內好奇地走過來。
  - 點蟻窩：`enteringHole > inHole > peeking > inHole > leavingHole > resting`；已在洞裡時點擊直接探頭。
  - 迎接：`greeting > watching > resting`；里程碑 → 跳舞；正在鑽進洞時忽略。
- **自我截圖**（App 截自己的視窗）確認：爬出洞口三個時間點、探頭、睡覺 z z z、想事情氣泡、打哈欠氣泡、挖土的泥土、叼石頭。
- **尚未在畫面上確認**：跳舞的扭動、轉圈、張望、修補巢口繞圈、好奇／被嚇到的實際反應（邏輯模擬通過）。
- 用真實滑鼠點蟻窩（全域滑鼠監聽）尚未實測。

## 踩過的坑

- **繞圈走不到**：修補巢口的起點離她只有約 5px，而她的轉彎半徑（速度 ÷ 轉向速率 = 22 ÷ 6 ≈ 3.7px）讓她永遠轉不過去，在原地繞圈，60 分鐘模擬裡只切換了 8 次狀態才發現。修法：離目標近時轉向速率提高到 `max(6, 2.5 × 速度 ÷ 距離)`，並加 20 秒走路逾時。
