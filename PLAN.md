# 螞蟻農場 (AntFarm) — Mac 桌面小遊戲計畫

## Context
想做一個上班摸魚用的小樂趣：螢幕上先由蟻后選位置築巢，之後每 10 秒冒出一隻小螞蟻，在整個桌面上走動，放著不管就越來越多。
決定做成 **Mac 原生 menu bar App**（螞蟻要爬在所有 App 之上，瀏覽器外掛做不到）。進度可存檔，也可在選單中關閉存檔。

環境：從空資料夾開始；只有 Command Line Tools（Swift 6.1.2），沒有完整 Xcode → 用 **Swift Package Manager + build.sh 手動包成 .app**，不依賴 Xcode 專案。

## 設計

**呈現方式**
- App 為 menu bar 常駐（`LSUIElement=true`，無 Dock 圖示），選單項目：暫停/繼續、存檔開關、重置蟻窩、（顯示螞蟻數）、結束。
- 每個 `NSScreen` 一個無邊框透明 `NSWindow`：`ignoresMouseEvents = true`（滑鼠穿透，不干擾工作）、`level = .statusBar`、`collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]`。
- 螞蟻用全域座標；每個視窗的 `AntView.draw` 以自己的 origin 偏移繪製，多螢幕自然銜接。

**遊戲流程**
1. 首次啟動（或重置後）進入「選巢位」：覆蓋視窗暫時 `ignoresMouseEvents = false`、游標改十字，顯示提示「點一下選擇蟻窩位置」。
2. 點擊 → 蟻后從螢幕邊走到該點，停下、挖洞（畫一個小土堆/洞口），視窗恢復滑鼠穿透。
3. 之後每 10 秒從巢口生出一隻螞蟻；蟻后留在巢旁。
4. 螞蟻行為：隨機漫步（heading 每幀小幅隨機轉向、偶爾停頓）、速度約 15–40 px/s、碰到螢幕邊緣反彈；小小的（約 4–6 px 身體 + 腿的擺動），黑/深褐色。
5. 上限預設 500 隻（防止長時間掛著吃 CPU）。

**存檔**
- 選單勾選「儲存進度」（預設開）。存 `~/Library/Application Support/AntFarm/state.json`：巢座標、螞蟻數、上次生成時間。
- 重開後：還原巢與螞蟻數（螞蟻位置重新散布在巢附近）；不做離線補生。關閉存檔則每次都重新選巢。

**效能**
- 單一 `Timer`（30fps）驅動更新，每個視窗一個 view，在 `draw(_:)` 裡用 Core Graphics 一次畫完所有螞蟻。500 隻量級足夠。

## 檔案結構（全部新建）
```
ant/
├── Package.swift
├── build.sh                      # swift build -c release → 組 AntFarm.app + Info.plist + ad-hoc codesign
├── Resources/Info.plist          # LSUIElement, bundle id
└── Sources/AntFarm/
    ├── main.swift                # NSApplication 啟動
    ├── AppDelegate.swift         # menu bar 選單、建立/銷毀 overlay、螢幕變更監聽
    ├── Colony.swift              # 遊戲狀態：階段(選巢/運行)、巢位置、蟻后、螞蟻陣列、10 秒生成計時
    ├── Ant.swift                 # 單隻螞蟻資料 + 移動更新
    ├── Queen.swift               # 蟻后狀態機（20 種動作、對滑鼠與新生螞蟻的反應）
    ├── Settings.swift            # 選單設定（生成速度、上限、大小、速度、顏色…）存 UserDefaults
    ├── NestImageStore.swift      # 自訂蟻窩圖片
    ├── OverlayWindow.swift       # 透明覆蓋視窗（穿透 / 選巢模式切換）
    ├── AntView.swift             # 繪製螞蟻、蟻后、巢、提示文字；選巢時處理 mouseDown
    └── Persistence.swift         # state.json 讀寫
```
偵錯用環境變數 `ANT_SPAWN_INTERVAL`（預設 10）方便快速測試。

## 執行方式（依使用者回饋調整）
- 核准後**第一步**：把本計畫複製成專案內的 `PLAN.md`，並在每個階段完成後勾選進度。
- **逐步開發**：每完成下面一個階段就實際建置、執行驗證，簡短回報結果後再進下一階段，不一次寫完。

## 分階段實作
- [x] 1. Package.swift + build.sh + 最小 App：menu bar 圖示 + 全螢幕透明穿透視窗，可正常結束。
- [x] 2. 選巢流程：十字游標點擊 → 記錄巢位置。（點擊選巢待人工確認）
- [x] 3. 螞蟻生成與漫步、蟻后、巢的繪製。
- [x] 4. 存檔/還原 + 選單開關 + 重置。（含選單設定：生成速度、上限、大小、移動速度、顏色、暫停）
- [x] 4b. 蟻窩自訂圖片（選單「蟻窩圖案」，圖片複製到 Application Support/AntFarm/nest.png）
- [x] 4c. 蟻后行為：20 個動作全部完成（含對滑鼠的反應、點蟻窩探頭、里程碑跳舞），見 [QUEEN_BEHAVIORS.md](QUEEN_BEHAVIORS.md)
- [x] 4d. 蟻后登場改為從洞口慢慢爬出來（原本從螢幕左邊走進來）
- [x] 4e. 預設蟻窩改成會成長的小土堆（見開發紀錄）
- [x] 5. 多螢幕熱插拔、效能優化、500 隻壓力測試（暫停已在階段 4 做完）。

## 驗證
- `./build.sh` 成功產出 `AntFarm.app`；首次執行需右鍵 → 開啟（ad-hoc 簽署，非 Apple 認證）。
- `ANT_SPAWN_INTERVAL=1 open AntFarm.app`：確認選巢提示 → 點擊 → 每秒出現一隻螞蟻並漫步；切到 Chrome/Finder 時螞蟻仍在最上層，且點擊、輸入不受影響（滑鼠穿透）。
- 存檔：累積數隻後結束再開，確認巢與數量還原；關閉「儲存進度」後重開，回到選巢畫面。
- 若有外接螢幕，確認螞蟻可在螢幕間走動；用 `screencapture` 截圖檢查螞蟻大小與外觀。
- 放 500 隻時用 Activity Monitor 檢查 CPU 占用（目標 < 5%）。

## 已知限制
- 沒有 Apple Developer 憑證：分享給同事需右鍵開啟或 `xattr -d com.apple.quarantine`。
- 公司若以 MDM 擋未簽署 App，則此方案無法安裝。

## 開發紀錄
- 階段 1～4 完成；選單設定、蟻窩自訂圖片、蟻后行為（6 個）已加入。
- 設定不是 `.env`：Mac App 不會讀 `.env`，設定一律用選單，存在 UserDefaults（網域 `dev.goblincamp.antfarm`）。`ANT_SPAWN_INTERVAL`、`ANT_AUTO_NEST`、`ANT_DEBUG` 是開發測試用的環境變數，需直接執行 `AntFarm.app/Contents/MacOS/AntFarm` 才會帶入。
- 螞蟻外觀之後想擴充成更多樣子：目前 `AntView.addAnt` 集中定義螞蟻的形狀，`AntColorTheme` 管顏色，擴充時從這兩處著手。
- 階段 5 效能（全螢幕透明視窗，Retina 螢幕，CPU 為單一程序的即時值，量測有 ±3% 的雜訊）：

  | 螞蟻數 | 逐隻繪製（原本） | 現在（批次路徑 + 自適應 fps） |
  |---|---|---|
  | ~50 | 約 7% | 約 8% |
  | ~150 | 約 11% | 約 8% |
  | 500 | 約 25% | 約 13% |

  - 有效：所有螞蟻的身體、腿合併成兩條 `CGPath` 一次畫完（`AntView.addAnt` / `paint`）；螞蟻超過 100 隻時降到 20fps（`AppDelegate.crowdedAnts`）。
  - 無效、已退回：只重畫螞蟻移動過的格子（局部 `setNeedsDisplay`）——每個數量都更慢（56 隻 24% vs 7%），AppKit 的分段繪製開銷比整個重畫還大；`wantsLayer` 圖層繪製——沒有差別。
  - 目標「< 5%」沒有達成：主要成本是每幀整個螢幕重畫（2940×1912），這是這個做法的下限。要再降需換成 Core Animation 每隻一個 layer 之類的 GPU 合成做法，工程較大，暫不做。500 隻要連續掛機約 80 分鐘（10 秒一隻）才會出現。
- 多螢幕熱插拔：監聽 `didChangeScreenParametersNotification` 重建覆蓋視窗；`Colony.updateWalkable` 會把跑出螢幕外的螞蟻搬到最近的螢幕，巢若在被拔掉的螢幕上則移到剩下螢幕的最近邊緣（蟻后重新就位）。純邏輯模擬通過；未實際插拔螢幕測試。
- 開發用環境變數（需直接執行 `AntFarm.app/Contents/MacOS/AntFarm`）：`ANT_SPAWN_INTERVAL`（生成間隔秒數）、`ANT_AUTO_NEST`（啟動時自動在主螢幕中央築巢）、`ANT_DEBUG`（log 每次生成）、`ANT_NO_SAVE`（不讀寫存檔，測試用）、`ANT_SNAPSHOT=/path/prefix` + `ANT_SNAPSHOT_AFTER=秒`（App 截自己的視窗存成 PNG，不需螢幕錄製權限）。UserDefaults 的設定也能用命令列覆蓋，例如 `-maxAnts 500 -colorTheme black`，不會寫進設定。
- 已確認：螞蟻外觀（自我截圖）；選單設定與蟻窩圖片可用（UserDefaults 裡有使用者調過的上限、顏色，截圖中也有自訂蟻窩圖片）。
- 尚未人工確認：點擊選巢、蟻后部分動作的實際畫面（跳舞、轉圈、張望、修補、好奇/被嚇到）、點蟻窩探頭（全域滑鼠監聽）、實際插拔螢幕。
- 蟻后登場：從洞口慢慢爬出來（`Queen.emerging` + 以洞口為界的裁切），取代原本從螢幕邊緣走進來。
- 預設蟻窩（`AntView.drawNest` / `drawMound`）：小土堆有陰影、漸層、土粒與洞口；寬度 = 18 + 16 × (1 − e^(−螞蟻數/120))，即 0 隻 18pt、約 100 隻 27pt、500 隻約 34pt，之後幾乎不再變大；螞蟻 ≥ 60 隻多一個小土堆、≥ 200 隻再多一個；土粒用固定亂數種子（依巢位置），不會逐幀閃動。有自訂圖片時改畫圖片。
- 蟻后 20 動作的實作中發現並修掉「目標落在轉彎半徑內 → 原地繞圈走不到」的 bug（詳見 QUEEN_BEHAVIORS.md「踩過的坑」）。
- 測試用環境變數另有：`ANT_QUEEN_FORCE=動作名`（強制蟻后進入某動作）、`ANT_NO_NEST_IMAGE`（忽略自訂蟻窩圖片）。完整列表見 README。
- 想法（尚未決定）：螞蟻改成點陣（pixel art）風格。傾向做成選單可切換的「外觀風格」而不是直接取代；需要把螞蟻繪製抽成可替換的「外觀」，點陣版要 8 方向 × 數個走路影格的小圖（可用程式內的字元格定義，不需外部素材）、用最近鄰縮放，並把氣泡、表情符號也換成點陣版才不突兀。建議先在同一畫面做預覽比較再決定。
