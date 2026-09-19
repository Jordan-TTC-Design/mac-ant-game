# 哥布林營地 GoblinCamp

一個放在 Mac 選單列的桌面小遊戲：選一個位置紮營，兩隻哥布林會從最近的螢幕邊，把抓來的人類公主扛進營地；之後哥布林越來越多，在你的整個桌面上晃來晃去。（未來會有冒險者來救公主。）

給上班時的一點小樂趣。角色蓋在所有視窗上面，但**滑鼠可以直接穿透**，不會擋到你工作。

> 前身是「螞蟻農場 AntFarm」，現在專心做哥布林（螞蟻版已移除）。

## 玩法

1. 開啟 App，畫面會稍微變暗，出現提示：點一下，選擇營地的位置。還沒想好就按 **Esc** 取消，之後從選單的「選擇營地位置…」再開始。
2. 兩隻哥布林把公主扛進營地、放下後，開始計時，每 10 秒生一隻哥布林（那兩隻是最初的居民）。
3. 不用管它。哥布林會隨機漫步、偶爾停下來，有時會回營地休息一陣子；營地也會隨數量變多而慢慢長大（有上限，不會占滿螢幕）。
4. 想看牠們「工作」的話，從選單「放食物」放一滴水或一坨蜂蜜在畫面上（見下）。

選單列會出現哥布林頭像圖示，所有設定都在裡面。

## 特色

- **像素風角色，四個方向**：哥布林與少女都是 16×16 的像素畫，會依走路方向轉向、有走路動畫。
- **五個品種**：平民、敏捷、壯碩、聰明、金皮。出生時抽品種：大多是平民，稀有品種的機率會隨**累積搬回的食物**變高，每次出生還有一點隨機突變。每隻還有自己的小差異。
- **數值真的影響動作**：敏捷的走得快、眼尖；壯碩的一次搬兩份；聰明的容易發現食物、叫來的同伴比較多；金皮各方面都好一點。
- **會老死**：每隻有壽命，平民基準是 **1 天**（只計算 App 開著的時間），品種不同壽命不同；快到壽命時走得比較慢，最後會淡出離開，營地有空位再生新的。
- **名冊**：選單「名冊…」在畫面右側打開直條視窗，列出每一隻的品種、剩餘壽命、數值；點一隻，畫面上會圈出牠。
- **營地會長大**：四種預設營地（土堆洞穴、岩洞、樹洞、營帳），隨哥布林數量分三個階段長大（0／30／90 隻）。也可以換成自己的圖片。
- **角色可以換**：角色是資料夾裡的精靈圖加一個說明檔，也能放自己畫的角色（見下）。
- **整個桌面都是活動範圍**：支援多螢幕，拔掉外接螢幕時角色和營地會自動搬回剩下的螢幕。
- **會找食物**：放一份水滴或蜂蜜，哥布林**只有剛好走到食物旁邊才會發現**（不會刻意找）。發現的那隻會直接回營地通知同伴，同伴從洞口一隻接一隻出發，沿著幾乎筆直的路線走到食物、圍在邊緣，再各自叼一小份慢慢搬回營地；成功搬回的還會再多叫一兩隻幫忙。食物被搬走會越縮越小，搬完就消失。
- **會回營地休息**：漫步的哥布林平均每 90 秒會回營地，躲在洞裡 10～35 秒再出來（任何時候約 15～20% 在裡面）。
- **公主會換不同款式的衣服**：洋裝、長裙禮服、短裙上衣、運動裝（無袖加短褲）、草帽洋裝、冬季外套（貝雷帽加圍巾）、睡衣（睡帽），不只是換顏色，帽子、袖子、裙長都不同。她偶爾會轉一圈、閃一下光就換好（平均一小時約 18 次）。
- **被抓來的公主有自己的日常**：喝茶（茶几、熱氣）、運動（瑜珈墊）、看書、澆花（花盆）、梳頭髮、唱歌（音符）、睡覺（換睡衣、躺在小床上）、發呆想事情、打哈欠、跳舞……每個活動有專屬姿勢，做之前會先換上合適的衣服（運動前換運動裝、澆花戴草帽…）。並且會對滑鼠有反應（快速掃過會躲進營地、慢慢靠近會好奇、點營地會探頭）。動作陸續換成公主的日常，詳見 [QUEEN_BEHAVIORS.md](QUEEN_BEHAVIORS.md)。
- **可以搬家**：選單的「編輯營地位置」進入編輯模式，拖曳營地就能移動，公主跟著搬，哥布林不受影響；按 Esc 或 Return 結束。
- **可存檔**：營地位置、每一隻的品種／年齡／數值、累積的食物量重開後都還在（也可以關掉存檔）。
- 生成間隔（10 秒／30 秒／1 分鐘／3 分鐘／5 分鐘／自訂）與數量上限可在選單調整；大小與速度固定用預設值。

## 系統需求

- macOS 13 以上
- Xcode Command Line Tools（`xcode-select --install`），Swift 5.9 以上。**不需要完整 Xcode**。

## 建置與執行

```bash
./build.sh          # 產生 GoblinCamp.app
open GoblinCamp.app
```

`build.sh` 用 Swift Package Manager 編譯，再手動組成 `.app` 並做 ad-hoc 簽署。

App 沒有 Apple Developer 憑證簽署或公證。自己在本機建置的可以直接開；如果是從別處拿到的 `.app`，第一次要**右鍵 → 打開**，或先移除隔離標記：

```bash
xattr -dr com.apple.quarantine GoblinCamp.app
```

公司電腦若用 MDM 擋下未簽署的 App，就無法安裝。

## 選單設定

| 項目 | 選項 |
|---|---|
| 暫停 / 繼續 | 暫停時所有角色（含少女）都停住 |
| 選擇營地位置… / 重新選擇營地位置 | 進入選位置畫面（點一下決定，**Esc 取消**）。已有營地時，要真的點下新位置才會清空哥布林；按 Esc 就維持原樣 |
| 放食物 | 水滴 / 蜂蜜：選一種後點畫面放下（**Esc 取消**）。最多同時 6 份，最舊的會被取代；「清除所有食物」可全部收走。需要先有營地 |
| 編輯營地位置 | 畫面微暗、營地周圍出現虛線圈，拖曳它就能移動；Esc、Return 或再按一次選單結束。哥布林會繼續走動 |
| 角色 | 只有一個角色時不顯示；放了自訂角色（見下）就會出現 |
| 名冊… | 在畫面右側打開／關閉名冊視窗 |
| 工作模式・營地在背景跑 | 30 分鐘／1 小時／2 小時／直到我取消：營地從畫面消失但**繼續運行**（出生、覓食、老死照常），番茄鐘與 Claude 通知照常出現。平常寫程式時常駐用 |
| 節能模式・營地暫停 | 同樣的時間選項：營地藏起來並**完全暫停**（省效能、不計年齡），番茄鐘與 Claude 通知照常出現 |
| 專注模式・完全靜音 | 同樣的時間選項：全部隱藏、營地暫停、不跳通知也不出聲，番茄鐘只計時。開會、簡報用。全螢幕影片或簡報出現時會自動進入（可在選單關掉） |
| 提醒顯示的螢幕 | 番茄鐘與通知出現在哪個螢幕的右上角：游標所在（預設）、主螢幕，或指定第二螢幕 |
| 全螢幕時自動專注 | 開（預設）／關 |
| 開機時自動啟動 | 勾選項，預設關 |
| 每日統計… | 今天與近 7 天：番茄鐘完成數、專注分鐘、Claude 通知數 |
| 生成速度 | 每 10 秒（預設）／ 30 秒 ／ 1 分鐘 ／ 3 分鐘 ／ 5 分鐘一隻，或「自訂…」（輸入 45、30s、5m、1.5h、90秒 都可以；1 秒到 24 小時） |
| 數量上限 | 50 / 100 / 150（預設）/ 300 / 500 / 1000，各角色分開記 |
| 營地外觀 | 土堆洞穴（預設）／ 岩洞 ／ 樹洞 ／ 營帳 ／ 自己的圖片…（含圖片大小）；每種營地隨哥布林數量分三個階段長大 |
| 儲存進度 | 開（預設）/ 關 |

食物**不會存檔**：重開 App 後畫面上的食物就沒了（營地與數量會還原）。

自己的營地圖片建議用透明背景的 PNG；一般 JPG 會帶著方形底色。

## 資料存放位置

App 的資料都在你的使用者資料夾裡，**不在專案資料夾內，也不會進 git**：

| 內容 | 位置 |
|---|---|
| 營地位置、每一隻的品種／年齡／數值 | `~/Library/Application Support/GoblinCamp/state.json` |
| 自訂營地圖片（縮小後的副本） | `~/Library/Application Support/GoblinCamp/nest.png` |
| 自訂角色 | `~/Library/Application Support/GoblinCamp/Characters/<角色名>/`（格式見下） |
| 選單設定 | UserDefaults，網域 `dev.goblincamp.game` |

**從螞蟻農場升級**：第一次以「哥布林營地」啟動時，會自動把舊的 `Application Support/AntFarm` 資料夾內容與選單設定複製過來（舊資料不會刪除，確定沒問題後可自行刪掉）。

完全重置：

```bash
rm -rf ~/Library/Application\ Support/GoblinCamp
defaults delete dev.goblincamp.game
```

App 不會讀取鍵盤、也不會錄製螢幕；只用到滑鼠的位置和點擊位置（用來讓少女對游標有反應）。

## 開發

### 專案結構

```
├── Package.swift
├── build.sh                    # 編譯並組出 GoblinCamp.app（含角色、營地與 App 圖示）
├── Resources/
│   ├── Info.plist              # LSUIElement（沒有 Dock 圖示）、bundle id、圖示
│   ├── AppIcon.icns            # App 圖示（由 tools/make_icons.py 產生）
│   ├── Characters/goblin/      # 內建角色：五個品種的哥布林、公主、頭像（由 tools/make_goblin.py 產生）
│   └── Camps/                  # 四種預設營地，各三個成長階段（由 tools/make_camps.py 產生）
├── tools/
│   ├── make_goblin.py          # 用程式畫哥布林各品種、公主與頭像，輸出精靈圖與 manifest.json
│   ├── make_camps.py           # 畫預設營地
│   └── make_icons.py           # 產生 AppIcon.icns
└── Sources/GoblinCamp/
    ├── main.swift              # 進入點（先跑舊資料搬家）
    ├── Migration.swift         # 從 AntFarm 搬存檔與設定
    ├── AppDelegate.swift       # 選單列、覆蓋視窗、主迴圈（30fps，數量多時 20fps）
    ├── OverlayWindow.swift     # 每個螢幕一個透明、滑鼠可穿透的視窗
    ├── AntView.swift           # 全部繪製：角色、營地、氣泡、食物、選取圈
    ├── RosterPanel.swift       # 右側名冊視窗
    ├── Character.swift         # 角色：讀精靈圖與 manifest、方向與影格、品種清單
    ├── Camp.swift              # 營地外觀：讀圖與成長階段
    ├── Breed.swift             # 品種、個體特質、出生時抽品種
    ├── Colony.swift            # 遊戲狀態：營地、居民、食物、出生與老死、螢幕變化
    ├── Ant.swift               # 單一居民：漫步、回巢休息、覓食、搬運、老死（名稱沿用 Ant，是「居民」的通稱）
    ├── Queen.swift             # 公主的狀態機
    ├── Food.swift              # 食物種類與資料
    ├── Settings.swift          # 選單設定（UserDefaults）與時間格式
    ├── Persistence.swift       # state.json 存檔
    ├── NestImageStore.swift    # 自己的營地圖片
    └── SeededRandom.swift      # 可重現的亂數（個體特質）
```

座標一律使用全域螢幕座標（原點在主螢幕左下角）；每個視窗繪製時再減掉自己的原點。

### 自訂角色

一個角色就是一個資料夾，放在 `~/Library/Application Support/GoblinCamp/Characters/<名稱>/`，內容仿照 `Resources/Characters/goblin/`：

- `manifest.json`：`id`、`name`（選單顯示）、`noun`（例如「哥布林」）、`emoji`、`nestName`（例如「營地」）、`frame`（每格邊長，內建是 16）、`icon`（選單列小圖，可省略）、`defaultMaxCount`，以及 `worker`（必要）與 `queen`（可省略，省略時用 `worker`）。
- `breeds`（可省略）：品種清單，每個有 `id`、`name`、`weight`（出生比例）、`boost`（累積食物對機率的加成）、`sheet`、`blurb` 與 `stats`（`speed`、`sense`、`rest`、`lifespan` 為倍率，`carry` 為一次搬幾份，`recruit` 為通知時多叫幾隻）。沒寫時只有一個平民，用 `worker` 的圖。
- 每個角色（`worker`／`queen`）有 `sheet`（精靈圖檔名）、`pixelScale`（每個像素幾點，預設大小下）和 `walk`：`down`、`up`、`side` 各一串影格編號。`side` 畫面向右，向左由程式鏡像。
- 精靈圖是 PNG，每格 `frame`×`frame`，由左到右、由上到下編號。可以用 Aseprite、Piskel 這類點陣編輯器畫。

座標一律使用全域螢幕座標（原點在主螢幕左下角）；每個視窗繪製時再減掉自己的原點。

### 測試用環境變數

需要直接執行執行檔才會帶入（`open` 不一定會傳環境變數）：

```bash
CAMP_SPAWN_INTERVAL=1 CAMP_AUTO_NEST=1 CAMP_NO_SAVE=1 GoblinCamp.app/Contents/MacOS/GoblinCamp
```

| 變數 | 作用 |
|---|---|
| `CAMP_SPAWN_INTERVAL` | 覆蓋生成間隔（秒） |
| `CAMP_AUTO_NEST` | 啟動時自動在主螢幕中央築巢，跳過選位置 |
| `CAMP_NO_SAVE` | 不讀也不寫存檔（測試時避免動到真實進度） |
| `CAMP_NO_NEST_IMAGE` | 忽略自訂營地圖片，測試預設外觀 |
| `CAMP_LIFESPAN=秒` | 覆蓋平民的壽命（預設 86400 秒 = 1 天） |
| `CAMP_TIME_SCALE=倍數` | 讓年齡增加得更快（測試老死） |
| `CAMP_TEST_ROSTER=秒` | 該時間點打開名冊並選中一隻（配合 `CAMP_SNAPSHOT` 會把名冊視窗也截圖存成 `-roster.png`） |
| `CAMP_DEBUG` | 每次生成角色或還原存檔時印 log |
| `CAMP_QUEEN_FORCE=名稱` | 強制少女（首領）進入某個動作（sleeping、yawning、thinking、dancing、digging、carrying、peeking） |
| `CAMP_SNAPSHOT=/路徑前綴` `CAMP_SNAPSHOT_AFTER=秒` | App 把自己的視窗（營地附近）截圖存成 PNG，不需要螢幕錄製權限；加 `CAMP_SNAPSHOT_FULL=1` 改截整個螢幕（縮小一半） |
| `CAMP_TEST_ESC=秒` | 用合成事件按一次 Esc（測試取消選位置） |
| `CAMP_TEST_FOOD=種類,dx,dy` | 用合成事件走完「選單放食物 → 點擊放下」：在營地旁 (dx, dy) 放 `water` 或 `honey`，並每 5 秒印一次覓食狀態；加 `CAMP_TEST_FOOD_CANCEL=1` 會另外測試放食物時按 Esc |
| `CAMP_TEST_POMODORO=專注分,休息分` | 3 秒後開始番茄鐘（可填小數分鐘，例如 `0.25,0.15`） |
| `CAMP_TEST_CLICKMSG=秒` | 該時間點模擬點一下 Claude 通知的泡泡（通知需帶 `app`） |
| `CAMP_WILD_SCALE=倍數` | 讓動物與果樹自動出現、長果實的速度加快（測試用） |
| `CAMP_TEST_WILD=種類,dx,dy` | 在營地旁 (dx, dy) 放一隻動物（`chicken`／`sheep`／`pig`）與一棵果樹，並每 3 秒印一次狀態 |
| `CAMP_TEST_MENU` | 啟動 2 秒後把選單（依目前角色更新過名稱）逐項印出來 |
| `CAMP_TEST_EDIT=dx,dy` | 進入編輯模式、用合成滑鼠事件把營地拖 (dx, dy) 再按 Esc（測試編輯模式）；加 `CAMP_TEST_EDIT_HOLD=1` 會留在編輯模式方便截圖 |

選單設定也能用命令列參數臨時覆蓋、且不會寫進設定，例如 `GoblinCamp -maxAnts 300 -camp cave`。

### 文件

- [PLAN.md](PLAN.md)：設計、開發階段與進度、效能實驗紀錄（包含失敗的做法）
- [SCENARIOS.md](SCENARIOS.md)：工作與遊玩的各種使用情境、三種模式對照與待決定事項
- [QUEEN_BEHAVIORS.md](QUEEN_BEHAVIORS.md)：少女（首領）的 20 種動作、狀態機、如何新增動作

## 已知限制

- 目前沒有自動化測試；行為是用單獨編譯的模擬程式、合成事件與自我截圖驗證的。
- 效能（Retina 螢幕）：哥布林 150 隻 CPU 約 5%、500 隻約 7%。詳見 PLAN.md。
- 實際插拔螢幕、點擊營地讓公主探頭（全域滑鼠監聽）、選單列圖示的實際樣子尚未在真實環境完整驗證。
- 公主目前只有走路與站立的影格：睡覺、打哈欠、跳舞等只有動作本身與頭旁的圖示，沒有專屬姿勢；營地外觀與居民的品種已是哥布林版，公主的動作還在換成公主日常（第 2 步）。
- 食物不存檔；沒有畫費洛蒙軌跡；食物離營地很遠、哥布林又少時，可能很久才會被發現（這是刻意的）。
- 未簽署、未公證（見上方說明）。

## 番茄鐘

選單「番茄鐘」：專注 25／休息 5、50／10、15／3 分鐘，或自訂。開始後有一隻哥布林（營地裡隨機一隻）走到主螢幕右上角，舉著電子時鐘倒數（`專注`：綠色 LCD，最後一分鐘變紅；時間到時哥布林跳起來、出聲提醒，時鐘轉成藍色的 `休息` 倒數；休息完哥布林說一句話後走開）。選單裡可看剩餘時間、隨時停止。聲音用「Claude 通知」的音量設定；專注模式中只計時、不出聲，圖示旁會有通知數；工作模式與節能模式下照常顯示。實作在 `Pomodoro.swift`（計時與走位）與 `AntView.drawPomodoro`（七段顯示器）。

## Claude 通知（哥布林跳出來說話）

任何 Claude Code 需要你時，右上角會有哥布林（有時是公主）走出來，用氣泡和聲音告訴你；點一下泡泡會把跑 Claude 的終端機／編輯器帶到最前面。

- **誰來說話**：25% 是公主（輕柔的聲音、鈴聲），其餘是營地裡某一隻哥布林的品種：平民（尖聲加嘻嘻笑）、敏捷（快速尖叫）、壯碩（低沉悶哼）、聰明（嗯哼、慢條斯理）、金皮（高傲、閃亮音效）。每種有自己的聲音、語氣、台詞（`Notifier.swift` 的 `Speakers`）。氣泡標題是說話者的名稱（哥布林、壯碩哥布林、公主…），下面小字是專案資料夾名。
- **選單「Claude 通知」**：整體開關、要不要在「需要我決定」「工作完成」時出現、聲音（關／小／中／大）、試試看（隨機、公主、壯碩哥布林）。
- **專注模式中**（含全螢幕自動專注）：不跳出、不出聲，選單列圖示旁出現「● 數字」，選單的「回到全開」會寫「期間有 N 則通知」。工作模式與節能模式下通知照常出現。
- 6 秒內同類通知只會出一次，最多排 3 個。

**一行安裝 hook**：在終端機執行 `tools/install-hooks.sh`（會把腳本複製到 `~/.claude/hooks/`、備份設定檔後加入 Notification 與 Stop 兩個 hook，可重複執行，`--uninstall` 移除，`--dir 資料夾` 指定腳本存放處）。裝好後在 Claude Code 輸入 `/hooks` 或重開即可。

**串接方式**：`tools/goblin-notify.sh permission|done` 會用 `open -g "goblincamp://notify?kind=…&project=…&app=…"` 通知遊戲（遊戲沒在跑就什麼都不做，不會自己把遊戲打開）。

**手動設定 hook**（不想跑安裝腳本時）：用編輯器（例如 `vi ~/.claude/settings.json`）打開 Claude Code 設定檔，在最後一項後面補逗號，加上 `hooks` 區塊。下面是加完的整份範例（其他設定照你自己的，只要多 `hooks` 這一塊）：

```json
{
  "statusLine": {
    "type": "command",
    "command": "bash ~/.claude/statusline-command.sh"
  },
  "enabledPlugins": {
    "frontend-design@claude-plugins-official": true
  },
  "tui": "fullscreen",
  "theme": "dark",
  "agentPushNotifEnabled": true,
  "model": "opus",
  "hooks": {
    "Notification": [
      {
        "hooks": [
          { "type": "command", "command": "/path/to/GoblinCamp/tools/goblin-notify.sh permission" }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          { "type": "command", "command": "/path/to/GoblinCamp/tools/goblin-notify.sh done" }
        ]
      }
    ]
  }
}
```

- 兩個 hook：`Notification`（Claude 需要你決定或授權）對應 `permission`（橘框泡泡），`Stop`（Claude 做完一輪）對應 `done`（綠框泡泡）。
- 這樣直接指向專案裡的腳本，不需要先跑安裝腳本；專案資料夾搬家時，這兩個路徑要一起改。
- 存檔後在 Claude Code 輸入 `/hooks` 確認有出現這兩個 hook，或重開 Claude Code。
- 測試：先開著哥布林營地，在終端機執行
  `echo '{"cwd":"/path/to/GoblinCamp"}' | /path/to/GoblinCamp/tools/goblin-notify.sh permission`，右上角應該會有哥布林跳出來說話。
- 移除：把 `hooks` 區塊刪掉即可（或用 `tools/install-hooks.sh --uninstall`）。

每次 `./build.sh` 會重新向系統登記 `goblincamp://`。

## 想法

- 公主的日常動作（喝茶、運動、看書、澆花、梳頭髮、跳舞…）與專用影格。
- 已完成：自動出現的果樹（吃完會長回來）與小動物（雞、羊、豬）；哥布林碰到才發現、圍捕，打獵有風險（豬會反擊，可能受傷或死亡）。選單「自然事件」可調頻率。
- 還沒做：蘑菇、寶箱、敵人。
- 進化與職業（士兵、戰士、魔法師、弓箭手）。
- 角色編輯器（畫正面，其他方向由編輯器產生）。

## 授權

尚未指定。
