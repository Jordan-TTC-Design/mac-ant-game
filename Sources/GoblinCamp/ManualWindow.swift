import AppKit

/// The help manual inside the app (menu: 說明手冊). Plain text pages so it works offline and never goes out of date with the build.
final class ManualWindow: NSObject {
    private let window: NSWindow
    private let textView = NSTextView()

    /// A line starting with "## " is a small heading, "• " a bullet, anything else a paragraph.
    static let sections: [(title: String, lines: [String])] = [
        ("開始玩", [
            "哥布林營地是一個放在 Mac 選單列的桌面小遊戲，也是一個會跳出來提醒你的番茄鐘與 Claude 通知小工具。",
            "• 第一次打開，畫面會變暗，點一下決定營地的位置（按 Esc 可以先取消）。",
            "• 接著幫被抓來的公主取一個名字。兩隻哥布林會從最近的螢幕邊把她扛進營地，之後每隔一段時間生出一隻新的哥布林。",
            "• 角色蓋在所有視窗上面，但滑鼠可以直接穿透，不會擋到你工作。",
            "• 所有設定都在選單列的哥布林圖示裡。",
        ]),
        ("四種狀態與快捷鍵", [
            "選單最上面有四個選項（打勾的是目前的狀態），也可以用快捷鍵切換：",
            "• 全開（⌃⌥1）：哥布林在畫面上活動，番茄鐘與通知都有。",
            "• 工作模式（⌃⌥2）：營地藏起來，但在背景繼續長大；番茄鐘與 Claude 通知照常出現。平常工作用這個。",
            "• 節能模式（⌃⌥3）：營地藏起來並完全暫停（不計年齡）；番茄鐘與通知照常出現。想省效能時用。",
            "• 專注模式（⌃⌥4）：全部隱藏、暫停、不出聲；番茄鐘只計時。開會、簡報用。錯過的通知會在選單列圖示旁顯示「● 數字」。",
            "## 其他設定",
            "• 「切換模式後持續」：直到我改變、30 分鐘、1 小時或 2 小時；時間到就回到「啟動時的模式」。",
            "• 「啟動時的模式」：預設是工作模式。第一次玩（還沒有營地）時會先全開，好讓你選位置。",
            "• 全螢幕影片或簡報出現時，會自動進入專注模式，離開就恢復（可以在選單關掉）。",
            "• 選單列圖示旁的小字表示目前的狀態：工（工作）、省（節能）、靜（專注）。",
            "## 桌面",
            "• 預設只有「桌面 1」會出現哥布林；切到桌面 2 就完全乾淨，連一格都不會出現（番茄鐘與 Claude 通知仍會出現）。",
            "• 可以在選單「顯示 → 哥布林出現在哪個桌面」選「所有桌面」，或勾選要出現的桌面。",
            "• 全螢幕 App（影片、簡報）自己的桌面永遠不會有哥布林。",
            "## 走動範圍與地圖",
            "• 選單「顯示 → 走動範圍與地圖」：整個螢幕（預設）、底部一條、右邊一條、左邊一條，或獨立的營地視窗。",
            "• 一條的厚度可以選薄、中（預設）、厚、很厚；背景可以選森林、草地或沒有，會跟著電腦的時間變色（傍晚偏橘、夜晚偏藍）。底部一條的樹是橫向排的，左右兩邊的一條是直立的。",
            "• 範圍小的時候，同時出來走動的哥布林會減少（一條大約 20 隻），其他的在營地裡休息、有空位再出來，所以有幾百隻也不會全擠在一起。",
            "• 哥布林、番茄鐘與泡泡的視窗都放在 Dock 下面一層，Dock、選單列、Spotlight、Mission Control、通知橫幅永遠在最上面，不會被蓋住。",
            "• 營地視窗有自己的地圖，哥布林都在裡面，四周是一圈森林（視窗拉多大都有）：可以拖、縮放，按左上角的關閉鈕、縮到 Dock，或選單「收起營地視窗」就收起來（哥布林仍在背景生活，也不會自己彈回來），選單可以再叫出來，也能設成永遠在最上面。",
            "• 在工作、節能、專注模式，或在不在勾選的桌面、全螢幕 App 的桌面時，營地視窗會自動收起。",
            "## 螢幕",
            "• 有多個螢幕時，預設哥布林只住在營地（家）所在的螢幕，其他螢幕完全乾淨，可以專心工作。",
            "• 可以在選單「顯示 → 哥布林出現在哪個螢幕」改成「所有螢幕」，或勾選指定的螢幕。家會跟著營地走：把營地拖到另一個螢幕，家就換過去。",
            "• 番茄鐘與通知要出現在哪個螢幕，是另外在「提醒顯示的螢幕」設定。",
        ]),
        ("番茄鐘", [
            "選單「番茄鐘」可以選專注 25／休息 5、50／10、15／3 分鐘，或自訂。",
            "• 開始後，右上角會有一隻哥布林舉著電子時鐘倒數：綠色是專注，最後一分鐘變紅，時間到會跳起來出聲提醒，接著轉成藍色的休息倒數。",
            "• 從全開狀態開始番茄鐘，會自動進入工作模式，結束後回來（選單可以關掉）。",
            "• 專注模式中只計時、不出聲，時間到時選單列圖示會閃動。",
            "• 可以連續多輪（例如經典的 4 輪，最後長休息 15 分鐘），時鐘會寫 專注2/4、休息、長休息；選單有「暫停」與「跳過這一段」。",
            "• 休息時如果營地是藏起來的，會自動出現營地並升起營火，哥布林圍過來開營火晚會；選單可以關掉。",
            "• 「每日統計…」可以看今天與近 7 天完成的番茄鐘與專注時間。",
        ]),
        ("連接 Claude Code（通知與回覆）", [
            "在選單「連接 Claude Code」按一下「連接」，就能讓 Claude Code 需要你的時候，由哥布林（有時是公主）跳出來。",
            "• Claude 要求授權時：泡泡會寫出它想做什麼，你可以按「允許」、「拒絕」，或「自己去看」（回到終端機）。",
            "• 「允許並記住」：只在這一次對話裡，同類的操作之後都自動允許（不寫進設定檔）。沒有可記住的項目時不會出現這個按鈕。",
            "• Claude 做完一輪時：泡泡有輸入框，打字按 Return，你的話會變成 Claude 的下一個指示；也可以按「自己去看」或「不用了」。",
            "• 不回答也沒關係：超過等待時間（選單可設 15／30／60 秒），Claude Code 就照平常在終端機顯示自己的畫面。",
            "• 專注模式中不會跳出來，也不會擋住 Claude Code。",
            "• 每種哥布林有自己的聲音與語氣，公主用輕柔的聲音。聲音大小可以在「Claude 通知 → 聲音」調整或關掉。",
            "• 連接時會先備份 ~/.claude/settings.json，只加入自己的設定。把哥布林營地搬到別的位置後，請再按一次「連接」。",
            "• 泡泡出現的螢幕可以在「提醒顯示的螢幕」選擇（預設是游標所在的螢幕，右上角）。",
        ]),
        ("哥布林與公主", [
            "• 名字：每隻哥布林出生時會有一個卡通感的名字（一百萬種以上，例如波米露、米露醬、咕嚕），可以在「名冊」裡連按兩下名字改掉。公主的名字在選單「公主的名字…」修改。名字會出現在通知的泡泡裡。",
            "• 品種：平民、敏捷、壯碩、聰明、金皮。搬回的食物越多，稀有品種越容易出生。",
            "• 壽命：平民大約 1 天（只計算程式開著的時間），品種不同壽命不同，老了會走得慢，最後淡出離開。",
            "• 名冊：選單「名冊與圖鑑 → 居民名冊」在畫面右側列出每一隻，點一隻，畫面上會圈出牠並顯示名字。",
            "• 公主有 7 套衣服和各種日常：喝茶、運動、看書、澆花、梳頭髮、唱歌、睡覺、發呆、跳舞……她會對滑鼠有反應。",
            "• 感情線：遊戲進行超過一天後，某個時候會有金皮哥布林開始追求公主，不一定成功。成功了會牽手散步、擁抱、有護衛跟著遠行約會、晚上同床聊天，也會吵架、冷戰、分手；有機會結婚、懷孕（肚子會變大），生下人與哥布林的混血寶寶（三種新品種，可能偏哥布林、偏人或各半）。所有哥布林現在有公母，母的頭上有粉紅色小蝴蝶結。名冊最上方會寫公主現在的感情狀態。詳見 ROMANCE.md。",
        ]),
        ("營地、食物與自然事件", [
            "• 營地會隨哥布林變多分三個階段長大（0／30／90 隻），外觀可以在「營地外觀」換，也能用自己的圖片。",
            "• 「放食物」放水滴或蜂蜜：哥布林只有走到旁邊才會發現，發現後會回去叫同伴一起搬。",
            "• 「編輯營地位置」可以拖曳營地搬家；「重新選擇營地位置」會清空重來。",
            "• 「自然事件」：營地附近會自己長出果樹，雞、羊、豬會從螢幕邊走進來。哥布林會圍捕，但豬會反擊，哥布林可能受傷甚至犧牲。可以調整頻率或關閉。",
            "• 「生成速度」與「數量上限」可以控制哥布林增加得多快、最多幾隻。",
            "• 「魔獸來襲」：全開模式下，偶爾會有史萊姆、巨鼠、沼澤青蛙、蝙蝠（夜晚）從螢幕邊走進來，要遊戲進行一段時間、營地有一定規模才會來。哥布林會出來圍打，受傷的會回營地休息；公主會躲進洞裡，之後幫傷兵治療。魔獸被打倒會掉素材，哥布林搬回營地，可以在「名冊與圖鑑 → 魔獸與素材圖鑑」查看。頻率在「營地 → 魔獸來襲頻率」，可以關閉。",
            "• 哥布林閒著會做自己的事：睡覺（晚上最愛）、去池塘釣魚、砍樹與採石（拿木片與廢鐵，樹不會被砍光）、在火坑煮燉菜、種田、玩耍、看書、鬧著玩打一架（不會受傷）。新生的哥布林是小的，長大的會照顧牠。聰明的不打架，愛看書；金皮會戴著小金冠巡視，普通哥布林在旁邊伺候。名冊點一隻可以看到牠現在在做什麼。",
            "• 「效能保護」：畫面太卡時，會自動減少同時出現的哥布林（其他的回巢穴休息），負擔減輕再慢慢加回來。可以在選單關掉。",
            "• 「工坊（做武器與裝備）…」：用魔獸掉的素材做武器（劍、刀、長槍、弓、法杖）、盾牌、帽子、胸甲、褲子、鞋子與手甲。做好的會交給最需要的哥布林，穿在身上看得到，也讓牠更強。有些配方需要之後才會出現的魔獸的素材，先看著就好。",
            "• 「走動範圍」：整個螢幕、底部一條、左右一條，或獨立的營地視窗。營地視窗與一條範圍偶爾會下雨，哥布林會躲進營地（可以關掉，也能按「現在下一場雨」試試）；整個螢幕不會下雨。",
            "• 營地視窗是一個場景，每個營地都不一樣：草地、森林空地、雪地或沼澤，有大小不同的池塘、小溪與木橋、樹叢、石頭、小路。哥布林住得很原始：巢穴四周是泥地，有獸皮帳篷、圖騰柱、曬肉架和石頭圍起來的營火坑。哥布林會繞過水、樹和石頭。選單「顯示 → 走動範圍與地圖 → 營地視窗 → 地貌」可以換主題或重新生成。營地是慢慢長大的：一開始只有巢穴，哥布林變多才會有火坑、帳篷、曬肉架、圖騰柱。",
            "• 場地會一直變：一季三天，樹葉會變紅飄落、下雪、池塘結冰、春天開花；下雨後地上有水窪，會慢慢乾；空地上會隨機冒出樹苗慢慢長成樹；哥布林常走的地方會被踩成小路。有機率性，每個營地都不一樣。關掉程式再打開，會補上這段時間發生的事。",
        ]),
        ("資料、更新與移除", [
            "• 營地、每一隻哥布林（含名字）、統計都存在 ~/Library/Application Support/GoblinCamp，選單設定存在系統設定裡；這些都在 App 外面，所以更新 App 不會讓紀錄消失。",
            "• 更新：先從選單「結束哥布林營地」，再用新的 GoblinCamp.app 取代舊的（放在同一個位置）。",
            "• 「儲存進度」可以關掉；關掉後每次都重新開始。",
            "• 移除：先在「連接 Claude Code」按「移除連接」，再把 App 丟進垃圾桶。想連紀錄一起刪掉，把上面那個資料夾也刪掉。",
        ]),
        ("常見問題", [
            "## 看不到哥布林？",
            "• 選單最上面如果不是「全開」，就是在工作、節能或專注模式，哥布林被藏起來了（營地仍在背景，或已暫停）。選「全開」或按 ⌃⌥1 就會回來。",
            "• 預設只有「桌面 1」有哥布林；在別的桌面請到選單「顯示 → 哥布林出現在哪個桌面」勾選。",
            "• 有多個螢幕時，哥布林預設只在營地所在的螢幕；其他螢幕請到選單「顯示 → 哥布林出現在哪個螢幕」勾選。",
            "• 滑到別的螢幕時哥布林閃爍或消失？請在選單按「複製診斷資訊」，貼給開發者。",
            "• 全螢幕影片或簡報時也會自動藏起來。",
            "## Claude 沒有跳出泡泡？",
            "到選單「連接 Claude Code」看狀態；沒連接就按「連接」，連接後在 Claude Code 輸入 /hooks 確認或重開。也要確認不是在專注模式，以及「Claude 通知 → 開啟通知」有打勾。",
            "## 第一次打開被系統擋下？",
            "因為這個 App 沒有 Apple 的付費簽署。macOS 15 以上：到「系統設定 → 隱私權與安全性」按「仍要打開」；macOS 13、14：對 App 按右鍵 → 打開。",
            "## 想重新開始？",
            "選單「重新選擇營地位置」會清空哥布林重來。想完全重置，結束程式後刪掉 ~/Library/Application Support/GoblinCamp。",
        ]),
    ]

    override init() {
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 620, height: 720), styleMask: [.titled, .closable, .resizable, .miniaturizable],
                          backing: .buffered, defer: false)
        super.init()
        window.title = "哥布林營地 說明手冊"
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 420, height: 320)
        window.center()

        let scroll = NSScrollView(frame: window.contentView!.bounds)
        scroll.autoresizingMask = [.width, .height]
        scroll.hasVerticalScroller = true
        scroll.borderType = .noBorder
        textView.isEditable = false
        textView.isSelectable = true
        textView.textContainerInset = NSSize(width: 22, height: 18)
        textView.frame = NSRect(x: 0, y: 0, width: scroll.contentSize.width, height: scroll.contentSize.height)
        textView.minSize = NSSize(width: 0, height: scroll.contentSize.height)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.autoresizingMask = [.width]
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.containerSize = NSSize(width: scroll.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        scroll.documentView = textView
        window.contentView?.addSubview(scroll)
        textView.textStorage?.setAttributedString(ManualWindow.render())
    }

    var contentViewForTesting: NSView? { window.contentView }

    func present() {
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    /// Headings, small headings, bullets and paragraphs as styled text.
    static func render() -> NSAttributedString {
        let out = NSMutableAttributedString()
        func add(_ text: String, font: NSFont, color: NSColor = .labelColor, before: CGFloat = 0, after: CGFloat = 4, indent: CGFloat = 0) {
            let style = NSMutableParagraphStyle()
            style.paragraphSpacingBefore = before
            style.paragraphSpacing = after
            style.lineSpacing = 2
            style.headIndent = indent
            style.firstLineHeadIndent = indent > 0 ? indent - 14 : 0
            out.append(NSAttributedString(string: text + "\n", attributes: [.font: font, .foregroundColor: color, .paragraphStyle: style]))
        }
        add("哥布林營地　說明手冊", font: .systemFont(ofSize: 22, weight: .bold), after: 6)
        let version = (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? ""
        add("版本 \(version)", font: .systemFont(ofSize: 11), color: .secondaryLabelColor, after: 8)
        for section in sections {
            add(section.title, font: .systemFont(ofSize: 17, weight: .bold), before: 16, after: 6)
            for line in section.lines {
                if line.hasPrefix("## ") {
                    add(String(line.dropFirst(3)), font: .systemFont(ofSize: 13, weight: .semibold), before: 8, after: 2)
                } else if line.hasPrefix("• ") {
                    add(line, font: .systemFont(ofSize: 13), indent: 16)
                } else {
                    add(line, font: .systemFont(ofSize: 13), after: 6)
                }
            }
        }
        return out
    }
}
