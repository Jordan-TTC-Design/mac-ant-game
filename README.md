# 螞蟻農場 AntFarm

一個放在 Mac 選單列的桌面小遊戲：先選一個位置築巢，蟻后會從洞口慢慢爬出來，之後每 10 秒多一隻小螞蟻，在你的整個桌面上走來走去。放著不管，螞蟻就會越來越多。

給上班時的一點小樂趣。螞蟻蓋在所有視窗上面，但**滑鼠可以直接穿透**，不會擋到你工作。

## 玩法

1. 開啟 App，畫面會稍微變暗，出現提示：點一下，選擇蟻窩的位置。
2. 蟻后從洞口慢慢爬出來，安頓好之後開始計時，每 10 秒生一隻螞蟻。
3. 不用管它。螞蟻會隨機漫步、偶爾停下來；蟻窩也會隨螞蟻變多而慢慢長大（有上限，不會占滿螢幕）。

選單列會出現 🐜 圖示，所有設定都在裡面。

## 特色

- **整個桌面都是活動範圍**：支援多螢幕，拔掉外接螢幕時螞蟻和蟻窩會自動搬回剩下的螢幕。
- **蟻窩會成長**：小土堆隨螞蟻數量逐漸變大，數量夠多時旁邊會多出小土堆。也可以換成自己的圖片。
- **蟻后有自己的生活**：散步、梳理觸角、鑽進洞口、產卵、挖土、搬小石頭、睡覺、發呆想事情……共 20 種小動作，詳見 [QUEEN_BEHAVIORS.md](QUEEN_BEHAVIORS.md)。
- **會跟滑鼠互動**：滑鼠快速掃過會嚇得躲進洞裡；慢慢靠近她會好奇地走過來；點一下蟻窩她會探出頭。
- **可存檔**：蟻窩位置和螞蟻數量重開後還在（也可以關掉存檔，每次重新開始）。
- 螞蟻大小、顏色、速度、生成間隔、數量上限都能在選單調整。

## 系統需求

- macOS 13 以上
- Xcode Command Line Tools（`xcode-select --install`），Swift 5.9 以上。**不需要完整 Xcode**。

## 建置與執行

```bash
./build.sh          # 產生 AntFarm.app
open AntFarm.app
```

`build.sh` 用 Swift Package Manager 編譯，再手動組成 `.app` 並做 ad-hoc 簽署。

App 沒有 Apple Developer 憑證簽署或公證。自己在本機建置的可以直接開；如果是從別處拿到的 `.app`，第一次要**右鍵 → 打開**，或先移除隔離標記：

```bash
xattr -dr com.apple.quarantine AntFarm.app
```

公司電腦若用 MDM 擋下未簽署的 App，就無法安裝。

## 選單設定

| 項目 | 選項 |
|---|---|
| 暫停 / 繼續 | 暫停時螞蟻與蟻后都停住 |
| 重新選擇蟻窩 | 清空螞蟻，回到選位置畫面 |
| 生成速度 | 每 10（預設）/ 5 / 3 / 1 秒一隻 |
| 螞蟻上限 | 100 / 200 / 500（預設）/ 1000 |
| 螞蟻大小 | 小 / 標準 / 大 / 超大 |
| 移動速度 | 慢 / 標準 / 快 |
| 螞蟻顏色 | 黑色 / 褐色 / 紅色（火蟻） |
| 蟻窩圖案 | 預設土堆 / 選擇圖片… / 圖片大小（小、中、大） |
| 儲存進度 | 開（預設）/ 關 |

自訂蟻窩圖片建議用透明背景的 PNG；一般 JPG 會帶著方形底色。

## 資料存放位置

App 的資料都在你的使用者資料夾裡，**不在專案資料夾內，也不會進 git**：

| 內容 | 位置 |
|---|---|
| 蟻窩位置與螞蟻數量 | `~/Library/Application Support/AntFarm/state.json` |
| 自訂蟻窩圖片（縮小後的副本） | `~/Library/Application Support/AntFarm/nest.png` |
| 選單設定 | UserDefaults，網域 `dev.goblincamp.antfarm` |

完全重置：

```bash
rm -rf ~/Library/Application\ Support/AntFarm
defaults delete dev.goblincamp.antfarm
```

App 不會讀取鍵盤、也不會錄製螢幕；只用到滑鼠的位置和點擊位置（用來讓蟻后對游標有反應）。

## 開發

### 專案結構

```
├── Package.swift
├── build.sh                    # 編譯並組出 AntFarm.app
├── Resources/Info.plist        # LSUIElement（沒有 Dock 圖示）、bundle id
└── Sources/AntFarm/
    ├── main.swift              # 進入點
    ├── AppDelegate.swift       # 選單列、覆蓋視窗、主迴圈（30fps，螞蟻多時 20fps）
    ├── OverlayWindow.swift     # 每個螢幕一個透明、滑鼠可穿透的視窗
    ├── AntView.swift           # 全部繪製：螞蟻、蟻后、蟻窩、氣泡
    ├── Colony.swift            # 遊戲狀態：蟻窩、螞蟻、蛋、泥土、生成計時、螢幕變化
    ├── Ant.swift               # 單隻螞蟻的漫步
    ├── Queen.swift             # 蟻后狀態機
    ├── Settings.swift          # 選單設定（UserDefaults）與顏色主題
    ├── Persistence.swift       # state.json 存檔
    └── NestImageStore.swift    # 自訂蟻窩圖片
```

座標一律使用全域螢幕座標（原點在主螢幕左下角）；每個視窗繪製時再減掉自己的原點。

### 測試用環境變數

需要直接執行執行檔才會帶入（`open` 不一定會傳環境變數）：

```bash
ANT_SPAWN_INTERVAL=1 ANT_AUTO_NEST=1 ANT_NO_SAVE=1 AntFarm.app/Contents/MacOS/AntFarm
```

| 變數 | 作用 |
|---|---|
| `ANT_SPAWN_INTERVAL` | 覆蓋生成間隔（秒） |
| `ANT_AUTO_NEST` | 啟動時自動在主螢幕中央築巢，跳過選位置 |
| `ANT_NO_SAVE` | 不讀也不寫存檔（測試時避免動到真實進度） |
| `ANT_NO_NEST_IMAGE` | 忽略自訂蟻窩圖片，測試預設土堆 |
| `ANT_DEBUG` | 每次生成螞蟻或還原存檔時印 log |
| `ANT_QUEEN_FORCE=名稱` | 強制蟻后進入某個動作（sleeping、yawning、thinking、dancing、digging、carrying、peeking） |
| `ANT_SNAPSHOT=/路徑前綴` `ANT_SNAPSHOT_AFTER=秒` | App 把自己的視窗（蟻窩附近）截圖存成 PNG，不需要螢幕錄製權限 |

選單設定也能用命令列參數臨時覆蓋、且不會寫進設定，例如 `AntFarm -maxAnts 500 -colorTheme black -antScale 1.0`。

### 文件

- [PLAN.md](PLAN.md)：設計、開發階段與進度、效能實驗紀錄（包含失敗的做法）
- [QUEEN_BEHAVIORS.md](QUEEN_BEHAVIORS.md)：蟻后 20 種動作、狀態機、如何新增動作

## 已知限制

- 目前沒有自動化測試；行為是用單獨編譯的模擬程式與自我截圖驗證的。
- 效能：整個螢幕每幀重畫，約 50 隻時 CPU 約 9%、500 隻約 14%（Retina 螢幕）。詳見 PLAN.md。
- 實際插拔螢幕、點擊蟻窩讓蟻后探頭（全域滑鼠監聽）尚未在真實環境完整驗證。
- 未簽署、未公證（見上方說明）。

## 想法

- 螞蟻外觀擴充更多樣子；考慮做成可切換的「外觀風格」（例如向量／點陣）。
- 更多蟻窩造型。

## 授權

尚未指定。
