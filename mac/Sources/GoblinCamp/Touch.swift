import AppKit

// The player's hand in the camp window (DESKTOP.md §1): hover to see a name, click to poke, click again and again to pester, press and
// hold to pat, drag to pick up and let go to throw, right-click to give an order. Every breed of every race answers in its own way.

/// What a goblin shows while the hand is on it, or just after.
enum TouchAnim: Equatable {
    case none
    /// A little jump where it stands.
    case hop
    /// Shaking side to side (wriggling, ears twitching, a tail wagging).
    case shake
    /// Running away from where it was poked.
    case flee
    /// A quick step to the side: the click missed.
    case dodge
    /// Swinging a fist at the pointer (a fist shows there and the window shakes).
    case punch
    /// Holding something in front of its face (a book, a hood).
    case cover
    /// A bow, a little squashed.
    case bow
    /// Knocked flat, stars going round.
    case dizzy
    /// Chest out, a little bigger.
    case proud
    /// Feet turned to roots: it cannot be lifted.
    case rooted
    /// Fallen apart into a heap of bones that crawl back together.
    case collapse
    /// See-through for a moment (the pointer went right through it).
    case fade
    /// Walking after the pointer.
    case chase
    /// Hearts going up.
    case hearts
    /// Pink cheeks.
    case blush
    /// A flower (or a leaf) sprouts on its head.
    case flower
    case leaf
    /// Red eyes glowing in the dark.
    case glowEyes
    /// A bigger, blue flame (will-o'-wisps).
    case flare
    /// Little lights around it.
    case sparkle
    /// Thinking it over: a "?" first.
    case think
    /// Crying (a young one): tears.
    case cry
}

/// One goblin's moment in the hand.
struct Touch {
    enum Kind: Equatable {
        /// Dangling under the pointer.
        case held
        /// Thrown: moving across the ground at (vx, vy) and up at vz, coming down.
        case flying(vx: Double, vy: Double, vz: Double)
        /// A short show where it stands (or on the move: fleeing, chasing).
        case react
    }

    var kind: Kind
    var anim: TouchAnim = .none
    /// Seconds left of the show.
    var left = 0.0
    var clock = 0.0
    /// Height above the ground, in points (drawn higher, with a shadow below), and a turn of the whole sprite.
    var lift = 0.0
    var spin = 0.0
    /// What it says over its head, and a sign beside it ("?", "💢").
    var line: String?
    var emote: String?
    /// Where it runs from (fleeing), or to when `toward` is set (hiding behind the princess, running for a coin).
    var from: CGPoint = .zero
    var toward = false
    /// A young one (picked up gently, never thrown) or a heavy one (follows the pointer slowly, lands hard).
    var gentle = false
    var heavy = false
    /// Falls slowly when let go (a silver-moon elf floats down).
    var floaty = false

    static func react(_ anim: TouchAnim, _ seconds: Double, line: String? = nil, emote: String? = nil) -> Touch {
        Touch(kind: .react, anim: anim, left: seconds, line: line, emote: emote)
    }

    var isHeld: Bool { kind == .held }
    var isFlying: Bool { if case .flying = kind { return true } else { return false } }
}

/// What the hand did.
enum Gesture { case poke, pester, pet, lift, land, obey, refuse }

/// An order from the right-click menu.
enum HandOrder: CaseIterable {
    case fell, mine, fish, fight, play, sleep, home
    /// Go and catch an animal that wandered in, for the ranch.
    case herd
}

/// How a breed answers one gesture: what it shows, for how long, and what it might say.
struct Response {
    var anim: TouchAnim
    var seconds: Double
    var lines: [String]
    var emote: String? = nil

    init(_ anim: TouchAnim, _ seconds: Double, _ lines: [String], _ emote: String? = nil) {
        self.anim = anim
        self.seconds = seconds
        self.lines = lines
        self.emote = emote
    }

    var touch: Touch { Touch.react(anim, seconds, line: lines.randomElement(), emote: emote) }
}

/// Who answers how (DESKTOP.md §1.2). `breed` is the breed id: common, scout, brute, sage, golden, half_* (the princess's line).
enum Reactions {
    /// How likely an order is followed.
    static func obedience(race: String, breed: String, order: HandOrder) -> Double {
        let heir = breed.hasPrefix("half_")
        switch (race, heir ? "half" : breed) {
        case ("goblin", "common"): return 0.7
        case ("goblin", "scout"): return order == .play ? 1 : 0.5
        case ("goblin", "brute"): return order == .fight || order == .mine || order == .fell ? 1 : 0.6
        case ("goblin", "sage"): return 0.9
        case ("goblin", "golden"): return 0.2
        case ("elf", "common"): return 0.8
        case ("elf", "scout"): return order == .fight ? 0.9 : 0.6
        case ("elf", "brute"): return 0.7
        case ("elf", "sage"): return 0.85
        case ("elf", "golden"): return 0.3
        case ("undead", "common"): return 0.9
        case ("undead", "scout"): return 0.5
        case ("undead", "brute"): return order == .fight ? 1 : 0.7
        case ("undead", "sage"): return 0.75
        case ("undead", "golden"): return 0.25
        default: return 0.6
        }
    }

    /// The young ones (not the princess's): all alike.
    static func child(_ gesture: Gesture) -> Response {
        switch gesture {
        case .poke: return Response(.hop, 1.2, ["咯咯", "嘻嘻", "嗯？"])
        case .pester: return Response(.cry, 2.5, ["哇——", "嗚嗚…"], "💦")
        case .pet: return Response(.hearts, 2, ["嘿嘿！", "還要～"])
        case .lift: return Response(.none, 0, ["哇～飛高高！", "好高喔！"])
        case .land: return Response(.hop, 1.5, ["再一次～", "咯咯咯"])
        case .obey, .refuse: return Response(.none, 1.5, ["…？"])
        }
    }

    static func response(race: String, breed: String, gesture: Gesture) -> Response {
        let heir = breed.hasPrefix("half_")
        switch race {
        case "elf": return heir ? elfHeir(gesture) : elf(breed, gesture)
        case "undead": return heir ? undeadHeir(gesture) : undead(breed, gesture)
        default: return heir ? goblinHeir(gesture) : goblin(breed, gesture)
        }
    }

    // MARK: Goblins

    private static func goblin(_ breed: String, _ g: Gesture) -> Response {
        switch (breed, g) {
        case ("scout", .poke): return Response(.hop, 1, ["幹嘛？", "嗯？"])
        case ("scout", .pester): return Response(.shake, 2, ["略略略～", "戳不到戳不到！"], "😝")
        case ("scout", .pet): return Response(.shake, 1.8, ["好癢！", "不要摸啦～"])
        case ("scout", .lift): return Response(.none, 0, ["呀呼～！", "再高一點！"])
        case ("scout", .land): return Response(.chase, 3.5, ["再一次！再一次！", "好好玩！"], "✨")
        case ("scout", .obey): return Response(.hop, 1.4, ["好喔！", "衝啊！"])
        case ("scout", .refuse): return Response(.shake, 1.6, ["我要去玩～", "等等再說！"])

        case ("brute", .poke): return Response(.none, 1.6, ["瞪什麼瞪", "…嗯？"], "💢")
        case ("brute", .pester): return Response(.punch, 1.2, ["吃俺一拳！", "找打嗎！"], "💢")
        case ("brute", .pet): return Response(.blush, 2.2, ["…哼", "才、才沒有很開心"])
        case ("brute", .lift): return Response(.none, 0, ["喂！", "放開俺！"])
        case ("brute", .land): return Response(.proud, 1.6, ["咚！", "哼，不痛"])
        case ("brute", .obey): return Response(.proud, 1.4, ["交給俺！", "好！"])
        case ("brute", .refuse): return Response(.none, 1.6, ["俺不想", "你自己去"], "💢")

        case ("sage", .poke): return Response(.think, 3.2, ["…"]) // (the colony puts a useful line here)
        case ("sage", .pester): return Response(.cover, 2.2, ["請不要打擾我看書", "……"], "📖")
        case ("sage", .pet): return Response(.blush, 2.2, ["記錄：被摸頭，愉快", "嗯，不錯"])
        case ("sage", .lift): return Response(.none, 0, ["這不符合物理…", "請放我下來"])
        case ("sage", .land): return Response(.cover, 2.2, ["抗議！我要寫進書裡", "這件事我記住了"], "✎")
        case ("sage", .obey): return Response(.think, 1.4, ["嗯…好吧", "有道理"])
        case ("sage", .refuse): return Response(.think, 1.6, ["這樣做不合理"])

        case ("golden", .poke): return Response(.proud, 1.8, ["放肆！", "你知道本大爺是誰嗎？"], "👑")
        case ("golden", .pester): return Response(.proud, 2.5, ["來人啊！把牠趕走！", "護駕！護駕！"], "💢")
        case ("golden", .pet): return Response(.blush, 2.5, ["哼…本大爺才不稀罕", "…再、再摸一下也行"])
        case ("golden", .lift): return Response(.none, 0, ["大膽！", "本大爺的金幣！"])
        case ("golden", .land): return Response(.proud, 1.8, ["哼，本大爺毫髮無傷"])
        case ("golden", .obey): return Response(.proud, 1.4, ["…就這一次"])
        case ("golden", .refuse): return Response(.proud, 1.8, ["本大爺自己會決定", "叫別人去"])

        case (_, .poke): return Response(.hop, 1.2, ["蛤？", "嗯？", "幹嘛啦"], "?")
        case (_, .pester): return Response(.flee, 2.2, ["哇啊！", "不要再戳了！"], "💦")
        case (_, .pet): return Response(.hearts, 2, ["嘿嘿", "好舒服～"])
        case (_, .lift): return Response(.none, 0, ["哇啊啊啊！", "放我下來！"])
        case (_, .land): return Response(.dizzy, 1.8, ["嗚哇…", "頭好暈"], "💫")
        case (_, .obey): return Response(.hop, 1.2, ["好～", "知道了！"])
        case (_, .refuse): return Response(.none, 1.6, ["等一下啦", "不要～"])
        }
    }

    private static func goblinHeir(_ g: Gesture) -> Response {
        switch g {
        case .poke: return Response(.hop, 1.2, ["咯咯咯", "嘻嘻"])
        case .pester: return Response(.cry, 3, ["哇——", "媽媽！"], "💦") // (the princess comes over)
        case .pet: return Response(.hearts, 2, ["嘿嘿！"])
        case .lift: return Response(.none, 0, ["飛高高！"])
        case .land: return Response(.hop, 1.5, ["再一次～"])
        case .obey: return Response(.hop, 1.2, ["好！"])
        case .refuse: return Response(.shake, 1.5, ["不要～"])
        }
    }

    // MARK: Elves

    private static func elf(_ breed: String, _ g: Gesture) -> Response {
        switch (breed, g) {
        case ("scout", .poke): return Response(.dodge, 1, ["看得見你", "太慢了"])
        case ("scout", .pester): return Response(.none, 1.6, ["看箭！", "別再戳了"]) // (an arrow at the pointer)
        case ("scout", .pet): return Response(.cover, 2, ["……", "別看我"])
        case ("scout", .lift): return Response(.none, 0, ["咻！"])
        case ("scout", .land): return Response(.bow, 1.4, ["落地完美"])
        case ("scout", .obey): return Response(.bow, 1.2, ["收到"])
        case ("scout", .refuse): return Response(.none, 1.5, ["我在巡邏"])

        case ("brute", .poke): return Response(.shake, 1.2, ["（掉了一片樹皮）", "嗯？"])
        case ("brute", .pester): return Response(.rooted, 30, ["（扎根了）", "我不走了"])
        case ("brute", .pet): return Response(.leaf, 3, ["（頭上長出一片葉子）"])
        case ("brute", .lift): return Response(.none, 0, ["好重吧？", "我是樹，不是石頭"])
        case ("brute", .land): return Response(.none, 1.6, ["（腳下長出一圈草）"])
        case ("brute", .obey): return Response(.bow, 1.2, ["好"])
        case ("brute", .refuse): return Response(.none, 1.6, ["我想再站一會兒"])

        case ("sage", .poke): return Response(.sparkle, 1.6, ["願森林護佑你", "✨"])
        case ("sage", .pester): return Response(.sparkle, 3, ["光點追著你跑囉"])
        case ("sage", .pet): return Response(.sparkle, 2.2, ["治癒之光～"])
        case ("sage", .lift): return Response(.none, 0, ["哎呀呀"])
        case ("sage", .land): return Response(.sparkle, 1.6, ["（落地開了一圈花）"])
        case ("sage", .obey): return Response(.bow, 1.2, ["好的"])
        case ("sage", .refuse): return Response(.none, 1.5, ["有人受傷時我得在"])

        case ("golden", .poke): return Response(.none, 1.4, ["……"])
        case ("golden", .pester): return Response(.none, 1.8, ["（冷冷看了一眼）"])
        case ("golden", .pet): return Response(.none, 1.6, ["……"]) // (from the sixth pat of the day it nods: see `pet`)
        case ("golden", .lift): return Response(.none, 0, ["放下。"])
        case ("golden", .land): return Response(.none, 1.4, ["……"])
        case ("golden", .obey): return Response(.none, 1.2, ["……好。"])
        case ("golden", .refuse): return Response(.none, 1.6, ["不。", "我自有安排"])

        case (_, .poke): return Response(.bow, 1.4, ["您好", "有什麼事嗎？"])
        case (_, .pester): return Response(.flee, 2, ["唉…", "我去冥想好了"], "…")
        case (_, .pet): return Response(.flower, 3, ["謝謝", "（頭上開了一朵花）"])
        case (_, .lift): return Response(.none, 0, ["哎呀", "請小心一點"])
        case (_, .land): return Response(.bow, 1.6, ["（拍拍衣服）", "還好沒弄髒"])
        case (_, .obey): return Response(.bow, 1.2, ["好的", "這就去"])
        case (_, .refuse): return Response(.none, 1.6, ["森林需要我", "現在不行"])
        }
    }

    private static func elfHeir(_ g: Gesture) -> Response {
        switch g {
        case .poke: return Response(.shake, 1, ["（耳朵抖了一下）"])
        case .pester: return Response(.none, 1.8, ["嗚——（低吼）", "吼！"], "💢")
        case .pet: return Response(.shake, 2.2, ["（尾巴猛搖）", "嗚嗚～"], "♥")
        case .lift: return Response(.none, 0, ["嗚！"])
        case .land: return Response(.hop, 1.4, ["（四腳著地）"])
        case .obey: return Response(.hop, 1.2, ["嗷！"])
        case .refuse: return Response(.none, 1.5, ["嗚…"])
        }
    }

    // MARK: The undead

    private static func undead(_ breed: String, _ g: Gesture) -> Response {
        switch (breed, g) {
        case ("scout", .poke): return Response(.fade, 1.4, ["（穿過去了）"])
        case ("scout", .pester): return Response(.chase, 20, ["……（跟著你）"])
        case ("scout", .pet): return Response(.none, 2, ["（變得比較不透明）"])
        case ("scout", .lift): return Response(.chase, 3, ["抓不住的～"])
        case ("scout", .land), ("scout", .obey): return Response(.none, 1.2, ["……"])
        case ("scout", .refuse): return Response(.fade, 1.5, ["（飄走了）"])

        case ("brute", .poke): return Response(.none, 1.8, ["……（慢慢轉頭）"])
        case ("brute", .pester): return Response(.none, 2, ["抓到了。", "（緊緊抓住）"]) // (a bony hand at the pointer)
        case ("brute", .pet): return Response(.none, 1.8, ["咕嚕…"])
        case ("brute", .lift): return Response(.none, 0, ["……"])
        case ("brute", .land): return Response(.proud, 1.6, ["轟！"])
        case ("brute", .obey): return Response(.none, 1.2, ["……嗯。"])
        case ("brute", .refuse): return Response(.none, 1.6, ["……（不動）"])

        case ("sage", .poke): return Response(.flare, 1, ["（火焰閃了一下）"])
        case ("sage", .pester): return Response(.flare, 2.5, ["（變成藍色的火）"])
        case ("sage", .pet): return Response(.blush, 2.2, ["（火變成溫暖的橘色）"])
        case ("sage", .lift): return Response(.none, 0, ["呼呼～"])
        case ("sage", .land): return Response(.flare, 1.2, ["呼～"])
        case ("sage", .obey): return Response(.flare, 1, ["呼！"])
        case ("sage", .refuse): return Response(.none, 1.5, ["（火光閃了閃）"])

        case ("golden", .poke): return Response(.none, 1.6, ["……"])
        case ("golden", .pester): return Response(.glowEyes, 2.5, ["（眼窩亮起紅光）"])
        case ("golden", .pet): return Response(.none, 1.6, ["……"])
        case ("golden", .lift): return Response(.none, 0, ["……"])
        case ("golden", .land): return Response(.none, 1.4, ["（站好了）"])
        case ("golden", .obey): return Response(.none, 1.2, ["……"])
        case ("golden", .refuse): return Response(.glowEyes, 1.6, ["……（不理你）"])

        case (_, .poke): return Response(.shake, 1.2, ["（下巴掉了）", "喀啦"])
        case (_, .pester): return Response(.collapse, 4, ["（散架了）", "喀啦喀啦…"])
        case (_, .pet): return Response(.shake, 1.8, ["（骨頭喀喀響）", "喀喀～"])
        case (_, .lift): return Response(.none, 0, ["喀啦喀啦！"])
        case (_, .land): return Response(.collapse, 3, ["（摔散了）", "骨頭…我的骨頭…"])
        case (_, .obey): return Response(.hop, 1.2, ["喀！", "遵命"])
        case (_, .refuse): return Response(.none, 1.6, ["喀…？"])
        }
    }

    private static func undeadHeir(_ g: Gesture) -> Response {
        switch g {
        case .poke: return Response(.none, 1.6, ["（好奇地看著你）"], "?")
        case .pester: return Response(.flee, 2.5, ["（躲到公主身後）"]) // (it runs to her)
        case .pet: return Response(.sparkle, 2, ["（發出微光）"])
        case .lift: return Response(.none, 0, ["……！"])
        case .land: return Response(.hop, 1.2, ["（輕輕落地）"])
        case .obey: return Response(.hop, 1.2, ["嗯！"])
        case .refuse: return Response(.none, 1.4, ["……"])
        }
    }

    // MARK: Others

    /// The princess (any race's).
    static func princess(_ g: Gesture) -> [String] {
        switch g {
        case .poke: return ["你好呀～", "（揮揮手）", "嗯？找我嗎？"]
        case .pester: return ["（鼓起臉頰）", "好了啦！", "再戳我要生氣囉"]
        case .pet: return ["（臉紅）", "討厭啦…", "嘿嘿"]
        case .lift: return ["要帶我去哪裡？", "（牽起你的手）"]
        default: return ["好呀"]
        }
    }

    /// An animal answering a poke, by its kind.
    static func animal(_ kind: String) -> String {
        switch kind {
        case "sheep": return ["咩～", "咩咩！"].randomElement()!
        case "pig": return ["齁齁", "噗嘰！"].randomElement()!
        case "chicken": return ["咕咕！", "咕咕咕咕！"].randomElement()!
        case "frog": return ["呱", "呱呱"].randomElement()!
        case "bat": return "吱！"
        case "deer": return "呦～"
        case "rabbit": return "（動動鼻子）"
        case "eagle": return "唳——"
        case "bone_sheep", "bone_chicken", "bone_dog": return ["喀啦", "喀喀"].randomElement()!
        case "soul_beast": return "（輕輕發亮）"
        default: return "？"
        }
    }

    /// The sage's useful line: what it knows about the camp and the day.
    static func sageTip(colony: Colony) -> String {
        let today = Stats.shared.today
        var tips = [
            "營地現在有 \(colony.ants.count) 隻",
            "記得喝水",
            "坐久了，起來走走吧",
        ]
        if today.pomodoros > 0 { tips.append("你今天專注了 \(today.pomodoros) 輪") }
        if today.focusSeconds > 60 { tips.append("今天專注了 \(Stats.minutes(today.focusSeconds))") }
        if colony.isRaining { tips.append("下雨天，適合看書") }
        if Colony.isNight { tips.append("很晚了，早點睡") }
        return tips.randomElement()!
    }
}

// MARK: - The hand

/// What the hand is doing and the little shows at the pointer. Lives as long as the colony.
final class Hand {
    /// Where the pointer is over the camp (camp coordinates), nil when it is elsewhere.
    var cursor: CGPoint?
    /// What the pointer is over (shown with its name).
    var hover: HandTarget?

    /// A press in progress: on what, where it started, for how long, and whether it became a pat or a lift.
    struct Press {
        let target: HandTarget?
        let start: CGPoint
        var age = 0.0
        var moved = false
        var petting = false
        var lifted = false
    }
    var press: Press?

    /// Where the pointer was over the last moments (to throw with its speed).
    private(set) var trail: [(pos: CGPoint, time: Double)] = []
    var clock = 0.0

    /// A show at the pointer or on the ground.
    struct Effect {
        enum Kind { case fist, arrow(from: CGPoint), sparkles, boneHand, coin, splash, grass, bloom, heal }
        let kind: Kind
        var pos: CGPoint
        var age = 0.0
        let life: Double
        /// Stays with the pointer.
        var follows = false
    }
    private(set) var effects: [Effect] = []

    /// Seconds the camp window still shakes (a punch, a heavy landing).
    var shake = 0.0
    /// Seconds the soul fire still burns brighter (a will-o'-wisp was dropped into it).
    var wispBoost = 0.0
    /// When each goblin was poked lately (four in three seconds is pestering).
    private var pokes: [Int: [Double]] = [:]
    private var princessPokes: [Double] = []
    /// Silver-moon elves are patted five times a day before they take notice.
    private var aloofPats: [Int: Int] = [:]
    private var aloofDay = ""
    /// The last blow at a monster (the hand can only hit so fast).
    var lastStrike = -10.0

    func reset() {
        cursor = nil
        hover = nil
        press = nil
        trail = []
        effects = []
        shake = 0
        wispBoost = 0
        pokes = [:]
        princessPokes = []
    }

    func add(_ kind: Effect.Kind, at pos: CGPoint, life: Double, follows: Bool = false) {
        if effects.count > 12 { effects.removeFirst() }
        effects.append(Effect(kind: kind, pos: pos, life: life, follows: follows))
    }

    func track(_ p: CGPoint) {
        cursor = p
        trail.append((p, clock))
        trail.removeAll { clock - $0.time > 0.12 }
    }

    /// The pointer's speed over the last tenth of a second, in points per second.
    var velocity: CGVector {
        guard let first = trail.first, let last = trail.last, last.time - first.time > 0.01 else { return .zero }
        let dt = last.time - first.time
        return CGVector(dx: (last.pos.x - first.pos.x) / dt, dy: (last.pos.y - first.pos.y) / dt)
    }

    /// Notes a poke; true when it makes four within three seconds (pestering), which starts the count again.
    func poke(_ id: Int) -> Bool {
        var times = (pokes[id] ?? []).filter { clock - $0 < 3 }
        times.append(clock)
        if times.count >= 4 {
            pokes[id] = []
            return true
        }
        pokes[id] = times
        return false
    }

    func pokePrincess() -> Bool {
        princessPokes = princessPokes.filter { clock - $0 < 3 } + [clock]
        if princessPokes.count >= 4 { princessPokes = []; return true }
        return false
    }

    /// Counts a pat for an aloof one; true once it has had more than five today.
    func aloofPat(_ id: Int) -> Bool {
        let day = Stats.key(Date())
        if day != aloofDay { aloofDay = day; aloofPats = [:] }
        aloofPats[id, default: 0] += 1
        return aloofPats[id]! > 5
    }

    func update(dt: Double) {
        clock += dt
        shake = max(0, shake - dt)
        wispBoost = max(0, wispBoost - dt)
        for i in effects.indices {
            effects[i].age += dt
            if effects[i].follows, let cursor { effects[i].pos = cursor }
        }
        effects.removeAll { $0.age >= $0.life }
        press?.age += dt
    }
}

/// What the pointer is over.
enum HandTarget: Equatable {
    case ant(Int)
    case queen
    case creature(Int)
    /// The wandering merchant: a click opens its stall (Merchant.swift).
    case merchant
    /// An animal in a pen (Ranch.swift); 0 is the wild eagle on a visit.
    case beast(Int)
    /// A beast's soul drifting through an undead camp.
    case wisp(Int)
}

extension Colony {
    private var race: String { Characters.current.id }

    private func breedID(of ant: Ant) -> String {
        let breeds = Characters.current.breeds
        guard !breeds.isEmpty else { return "common" }
        return breeds[min(ant.breedIndex, breeds.count - 1)].id
    }

    private func index(of id: Int) -> Int? { ants.firstIndex { $0.id == id } }

    /// Whether the hand may take hold of it at all (not in the nest, not on its way out, not carrying the princess…).
    func canTouch(_ ant: Ant) -> Bool {
        if ant.isHidden || ant.isDying || ant.isDeparting || ant.isCarryingPrincess || ant.lying || ant.inGrave { return false }
        if case .activity(.attend, _) = ant.mode { return false } // (with the princess: her scenes are hers)
        return true
    }

    private func clampWalkable(_ p: CGPoint) -> CGPoint {
        walkable.contains { $0.contains(p) } ? p : nearestWalkable(to: p)
    }

    private func say(_ i: Int, _ response: Response) {
        let onTheMove = response.anim == .flee || response.anim == .chase || response.anim == .dodge
        if onTheMove { ants[i].mode = .wandering } // (a goblin on the run leaves what it was doing)
        var touch = response.touch
        touch.from = hand.cursor ?? ants[i].pos
        ants[i].touch = touch
    }

    // MARK: Pointer events (from AntView)

    func handDown(at p: CGPoint, on target: HandTarget?) {
        hand.track(p)
        hand.press = Hand.Press(target: target, start: p)
        if case .creature(let id)? = target {
            if let c = creatures.first(where: { $0.id == id }), canCatch(c) { pickUp(creature: id) } else { strikeOrPet(creature: id) }
        }
        if target == .beast(0) { patVisitor() }
        if case .wisp(let id)? = target { pickUp(wisp: id) }
        if case .beast(let id)? = target, let b = ranch.beasts.first(where: { $0.id == id }) {
            addFloater(Reactions.animal(b.kind), .common, at: CGPoint(x: b.pos.x, y: b.pos.y + 14))
        }
        if target == .merchant { MerchantWindow.shared.show(colony: self) }
    }

    func handDragged(to p: CGPoint) {
        hand.track(p)
        guard var press = hand.press else { return }
        if !press.moved, hypot(p.x - press.start.x, p.y - press.start.y) > 5 {
            press.moved = true
            if !press.petting, case .ant(let id)? = press.target { press.lifted = lift(id) }
            if !press.petting, press.target == .queen { press.lifted = true }
        }
        hand.press = press
    }

    func handUp(at p: CGPoint) {
        hand.track(p)
        guard let press = hand.press else { return }
        hand.press = nil
        if ranch.held != nil { dropCreature(at: p) }
        if ranch.heldWisp != nil { dropWisp(at: p) }
        switch press.target {
        case .ant(let id)?:
            if press.lifted { release(id) }
            else if press.petting { endPet(id) }
            else if !press.moved { poke(id) }
            else if let i = index(of: id), ants[i].touch?.anim == .chase, ants[i].touch?.kind == .react { ants[i].touch?.left = 3 } // (a shade let go)
        case .queen?:
            if press.lifted { leadPrincess(to: p) }
            else if !press.moved, !press.petting { pokePrincess() }
        default: break
        }
    }

    func handMoved(to p: CGPoint?, over target: HandTarget?) {
        if let p { hand.track(p) } else { hand.cursor = nil }
        hand.hover = target
    }

    // MARK: Gestures

    private func poke(_ id: Int) {
        guard let i = index(of: id), canTouch(ants[i]) else { return }
        let pester = hand.poke(id)
        if ants[i].isChild {
            say(i, Reactions.child(pester ? .pester : .poke))
            return
        }
        let breed = breedID(of: ants[i])
        ants[i].face(hand.cursor ?? ants[i].pos)
        // the quick goblins and the green-cloaked elves are hard to catch
        if !pester, (race == "goblin" && breed == "scout" && Double.random(in: 0..<1) < 0.3) || (race == "elf" && breed == "scout") {
            say(i, Response(.dodge, 0.9, race == "elf" ? ["看得見你", "太慢了"] : ["抓不到～", "嘿嘿，太慢了"]))
            return
        }
        var response = Reactions.response(race: race, breed: breed, gesture: pester ? .pester : .poke)
        if race == "goblin", breed == "sage", !pester { response.lines = [Reactions.sageTip(colony: self)] }
        say(i, response)
        guard pester else {
            if race == "goblin", breed == "golden" { servants(of: id, glare: true) }
            return
        }
        let cursor = hand.cursor ?? ants[i].pos
        switch (race, breed) {
        case ("goblin", "brute"):
            hand.add(.fist, at: cursor, life: 0.7)
            hand.shake = 0.3
        case ("goblin", "golden"):
            servants(of: id, glare: false)
        case ("goblin", let b) where b.hasPrefix("half_"): // the princess comes over
            _ = queen?.lead(to: clampWalkable(CGPoint(x: ants[i].pos.x + 14, y: ants[i].pos.y)))
        case ("elf", "scout"):
            hand.add(.arrow(from: ants[i].pos), at: cursor, life: 1.6)
        case ("elf", "sage"):
            hand.add(.sparkles, at: cursor, life: 3, follows: true)
        case ("undead", "brute"):
            hand.add(.boneHand, at: cursor, life: 2, follows: true)
        case ("undead", let b) where b.hasPrefix("half_"):
            if let q = queen {
                ants[i].touch?.from = CGPoint(x: q.pos.x + 12, y: q.pos.y - 4)
                ants[i].touch?.toward = true
            }
        default: break
        }
    }

    /// The golden goblin's servants: glare at the pointer, or chase it off.
    private func servants(of boss: Int, glare: Bool) {
        var picked = 0
        for j in ants.indices where picked < 3 {
            guard case .activity(.serve(let b, _), _) = ants[j].mode, b == boss, canTouch(ants[j]) else { continue }
            picked += 1
            if glare {
                ants[j].face(hand.cursor ?? ants[j].pos)
                ants[j].touch = Touch.react(.none, 1.8, line: nil, emote: "💢")
            } else {
                say(j, Response(.chase, 3, ["走開走開！", "退下！"], "💢"))
            }
        }
        if !glare, picked == 0, let i = index(of: boss) { // nobody waiting on it: the nearest common ones come running
            let near = ants.indices.filter { $0 != i && !ants[$0].isChild && canTouch(ants[$0]) && breedID(of: ants[$0]) == "common" }
                .sorted { hypot(ants[$0].pos.x - ants[i].pos.x, ants[$0].pos.y - ants[i].pos.y) < hypot(ants[$1].pos.x - ants[i].pos.x, ants[$1].pos.y - ants[i].pos.y) }
            for j in near.prefix(2) { say(j, Response(.chase, 3, ["走開走開！"], "💢")) }
        }
    }

    /// Pressed and held still on it: a pat.
    private func startPet(_ id: Int) {
        guard let i = index(of: id), canTouch(ants[i]) else { return }
        if ants[i].isChild {
            say(i, Reactions.child(.pet))
            ants[i].touch?.left = 1e6
            return
        }
        let breed = breedID(of: ants[i])
        var response = Reactions.response(race: race, breed: breed, gesture: .pet)
        if race == "elf", breed == "golden", hand.aloofPat(id) { response = Response(.hearts, 2, ["……嗯。", "（點了點頭）"]) }
        say(i, response)
        ants[i].touch?.left = 1e6 // (as long as the hand stays)
        if race == "elf", breed == "sage" { // a healing light for the hurt ones around it
            for j in ants.indices where j != i && hypot(ants[j].pos.x - ants[i].pos.x, ants[j].pos.y - ants[i].pos.y) < 70 && ants[j].health < ants[j].maxHealth {
                ants[j].health = min(ants[j].maxHealth, ants[j].health + 1)
            }
            hand.add(.heal, at: ants[i].pos, life: 1.2)
        }
    }

    private func endPet(_ id: Int) {
        guard let i = index(of: id) else { return }
        ants[i].touch?.left = 1.2
        ants[i].cheer = 120 // in a good mood: a little quicker for two minutes
    }

    /// Picks it up; false when it will not be lifted (rooted to the spot, or a shade the hand goes through).
    private func lift(_ id: Int) -> Bool {
        guard let i = index(of: id), canTouch(ants[i]) else { return false }
        if ants[i].touch?.anim == .rooted {
            ants[i].touch?.line = "（扎根了，拖不動）"
            return false
        }
        let breed = breedID(of: ants[i])
        if race == "undead", breed == "scout", !ants[i].isChild { // the hand goes right through: it follows instead
            say(i, Reactions.response(race: race, breed: breed, gesture: .lift))
            ants[i].touch?.left = 1e6
            return false
        }
        let words = ants[i].isChild ? Reactions.child(.lift) : Reactions.response(race: race, breed: breed, gesture: .lift)
        if case .hauling = ants[i].mode { addFloater("東西掉了", .common, at: ants[i].pos) }
        ants[i].mode = .wandering
        var touch = Touch(kind: .held, line: words.lines.randomElement())
        touch.gentle = ants[i].isChild
        touch.heavy = breed == "brute" && !ants[i].isChild
        touch.floaty = race == "elf" && breed == "golden"
        touch.lift = 14
        ants[i].touch = touch
        if race == "goblin", breed == "golden", !ants[i].isChild { // a coin rolls out; a common one runs for it
            hand.add(.coin, at: ants[i].pos, life: 2.5)
            if let j = ants.indices.filter({ $0 != i && breedID(of: ants[$0]) == "common" && !ants[$0].isChild && canTouch(ants[$0]) && ants[$0].touch == nil })
                .min(by: { hypot(ants[$0].pos.x - ants[i].pos.x, ants[$0].pos.y - ants[i].pos.y) < hypot(ants[$1].pos.x - ants[i].pos.x, ants[$1].pos.y - ants[i].pos.y) }) {
                ants[j].mode = .wandering
                var run = Touch.react(.flee, 2.5, line: "金幣！")
                run.from = ants[i].pos
                run.toward = true
                ants[j].touch = run
            }
        }
        return true
    }

    /// Let go: a young one is set down, the rest fly off with the pointer's speed.
    private func release(_ id: Int) {
        guard let i = index(of: id), var touch = ants[i].touch, touch.isHeld else { return }
        if touch.gentle {
            ants[i].pos = clampWalkable(ants[i].pos)
            ants[i].touch = Reactions.child(.land).touch
            return
        }
        var v = hand.velocity
        let speed = hypot(v.dx, v.dy), top = touch.heavy ? 260.0 : 520.0
        if speed > top { v = CGVector(dx: v.dx / speed * top, dy: v.dy / speed * top) }
        let k = touch.heavy ? 0.5 : 0.7
        touch.kind = .flying(vx: v.dx * k, vy: v.dy * k, vz: min(220, speed * 0.25))
        ants[i].touch = touch
    }

    /// Down on the ground again.
    private func land(_ i: Int) {
        let breed = breedID(of: ants[i])
        let spot = ants[i].pos
        if scene?.visiblePonds.contains(where: { $0.blocks(spot, margin: 0) }) == true { // a splash, and out it climbs, dripping
            hand.add(.splash, at: spot, life: 1)
            ants[i].pos = nearestWalkable(to: spot)
            ants[i].wet = 10
            ants[i].touch = Touch.react(.shake, 2, line: ["噗通！", "好冰！", "咕嚕咕嚕…"].randomElement(), emote: "💦")
            return
        }
        ants[i].pos = clampWalkable(spot)
        var response = Reactions.response(race: race, breed: breed, gesture: .land)
        if race == "undead", breed == "sage", let nest, hypot(spot.x - nest.x, spot.y - nest.y) < 40 {
            hand.wispBoost = 60
            response = Response(.flare, 2, ["（飛進靈魂之火）魂塔燒得更旺了！"])
        }
        say(i, response)
        let here = ants[i].pos
        ants[i].touch?.from = here
        switch (race, breed) {
        case (_, "brute"):
            hand.shake = 0.35
            addHit(at: ants[i].pos)
            if race == "elf" { hand.add(.grass, at: ants[i].pos, life: 6) }
            for j in ants.indices where j != i && canTouch(ants[j]) && ants[j].touch == nil && !ants[j].isChild
                && hypot(ants[j].pos.x - ants[i].pos.x, ants[j].pos.y - ants[i].pos.y) < 40 {
                ants[j].touch = Touch.react(.dizzy, 1.4, line: "哎喲！")
            }
        case ("elf", "sage"):
            hand.add(.bloom, at: ants[i].pos, life: 6)
        default: break
        }
    }

    // MARK: The princess

    private func pokePrincess() {
        guard let q = queen, q.arrived else { return }
        let pester = hand.pokePrincess()
        queen?.greet(toward: hand.cursor ?? q.pos)
        addFloater(Reactions.princess(pester ? .pester : .poke).randomElement()!, .common, at: CGPoint(x: q.pos.x, y: q.pos.y + 20))
    }

    private func petPrincess() {
        guard let q = queen, q.arrived else { return }
        addFloater(Reactions.princess(.pet).randomElement()!, .uncommon, at: CGPoint(x: q.pos.x, y: q.pos.y + 20))
    }

    private func leadPrincess(to p: CGPoint) {
        guard let q = queen, q.arrived else { return }
        if queen?.lead(to: clampWalkable(p)) == true {
            addFloater(Reactions.princess(.lift).randomElement()!, .common, at: CGPoint(x: q.pos.x, y: q.pos.y + 20))
        }
    }

    // MARK: Animals and monsters

    private func strikeOrPet(creature id: Int) {
        guard let c = creatures.first(where: { $0.id == id }) else { return }
        if c.kind.hostile {
            guard hand.clock - hand.lastStrike > 0.6 else { return }
            hand.lastStrike = hand.clock
            _ = handStrike(creature: id)
        } else {
            addFloater(Reactions.animal(c.kind.id), .common, at: CGPoint(x: c.pos.x, y: c.pos.y + 14))
        }
    }

    // MARK: Orders

    /// The orders that make sense for it now (for the right-click menu), with their labels.
    func orders(for id: Int) -> [(HandOrder, String)] {
        guard let i = index(of: id), canTouch(ants[i]), !ants[i].isChild else { return [] }
        let rules = Characters.current.rules
        var list: [(HandOrder, String)] = []
        if resourceCache.contains(where: { $0.kind == .tree }) { list.append((.fell, rules.fellsTrees == false ? "去撿樹枝" : "去砍樹")) }
        if resourceCache.contains(where: { $0.kind == .rock }) { list.append((.mine, "去採石")) }
        if race != "undead", scene?.visiblePonds.isEmpty == false { list.append((.fish, "去釣魚")) }
        if creatures.contains(where: { $0.kind.hostile }) { list.append((.fight, "去打魔獸")) }
        if herdTargets.contains(where: { target, p in roomFor(target < 0 ? "soul_beast" : creatures.first { $0.id == target }?.kind.id ?? "", near: p) != nil }) {
            list.append((.herd, race == "undead" && herdTargets.keys.contains { $0 < 0 } ? "去把獸魂收進來" : "去抓動物回牧場"))
        }
        list.append((.play, "去玩"))
        list.append((.sleep, race == "undead" && !graves.isEmpty ? "回墳墓睡覺" : "去睡覺"))
        list.append((.home, "回巢休息"))
        return list
    }

    func order(_ id: Int, _ order: HandOrder) {
        guard let i = index(of: id), canTouch(ants[i]), !ants[i].isChild else { return }
        let breed = breedID(of: ants[i])
        if Double.random(in: 0..<1) >= Reactions.obedience(race: race, breed: breed, order: order) {
            ants[i].touch = Reactions.response(race: race, breed: breed, gesture: .refuse).touch
            return
        }
        let pos = ants[i].pos
        func nearest<T>(_ items: [T], _ at: (T) -> CGPoint) -> T? {
            items.min { hypot(at($0).x - pos.x, at($0).y - pos.y) < hypot(at($1).x - pos.x, at($1).y - pos.y) }
        }
        func start(_ kind: Ant.Activity, _ seconds: Double) {
            ants[i].activityClock = 0
            ants[i].mode = .activity(kind, remaining: seconds)
        }
        switch order {
        case .fell, .mine:
            let busy = Set(ants.compactMap { ant -> Int? in
                if case .activity(.gather(_, _, _, let id, _), _) = ant.mode { return id }
                return nil
            })
            let want: TerrainScene.ResourceSpot.Kind = order == .fell ? .tree : .rock
            guard let spot = nearest(resourceCache.filter { $0.kind == want && !busy.contains($0.id) }, \.foot) else {
                ants[i].touch = Touch.react(.think, 1.6, line: order == .fell ? "沒有樹可以砍了" : "沒有石頭可以挖了")
                return
            }
            let hits = max(3, Int(Double.random(in: 6...12) / ants[i].traits.might))
            start(.gather(kind: order == .fell ? 0 : 1, spot: spot.standAt, face: CGPoint(x: spot.foot.x, y: spot.foot.y + 6), id: spot.id, hitsLeft: hits), 90)
        case .fish:
            let spots = (scene?.visiblePonds ?? []).flatMap { $0.fishingSpots }
            guard let spot = nearest(spots, \.spot) else { return }
            start(.fish(spot: spot.spot, water: spot.water), Double.random(in: 20...45))
        case .fight:
            guard let monster = nearest(creatures.filter(\.kind.hostile), \.pos) else { return }
            ants[i].mode = .hunting(creature: monster.id, cooldown: 0)
        case .herd:
            guard let target = nearest(Array(herdTargets), \.value)?.key else { return }
            ranch.herders[ants[i].id] = target
            start(.herd(target: target), 40)
        case .play:
            start(.play, Double.random(in: 8...16))
        case .sleep:
            if race == "undead", let grave = nearest(graves, { $0 }) { start(.grave(spot: grave), Double.random(in: 30...60)) }
            else { start(.sleep, Double.random(in: 20...40)) }
        case .home:
            ants[i].mode = .returningToNest
        }
        var said = Reactions.response(race: race, breed: breed, gesture: .obey).touch
        said.kind = .react
        said.left = min(said.left, 1.2)
        // (the show is short and keeps the new job: the ant waits while it shows)
        ants[i].touch = said
    }

    // MARK: Every frame

    func updateHand(dt: Double) {
        hand.update(dt: dt)
        if let prefix = TouchTest.prefix { runTouchTest(prefix, before: hand.clock - dt) }
        if let prefix = TouchTest.lifePrefix { runLifeTest(prefix, before: hand.clock - dt) }
        // a press held still on a goblin (or the princess) for a moment is a pat
        if var press = hand.press, !press.moved, !press.petting, press.age > 0.6 {
            press.petting = true
            hand.press = press
            switch press.target {
            case .ant(let id)?: startPet(id)
            case .queen?: petPrincess()
            default: break
            }
        }
        if let press = hand.press, press.petting, case .ant(let id)? = press.target, let i = index(of: id), ants[i].touch != nil {
            let left = ants[i].touch?.left ?? 0
            ants[i].touch?.left = max(left, 0.5)
        }
        let cursor = hand.cursor
        for i in ants.indices {
            guard var touch = ants[i].touch else { continue }
            touch.clock += dt
            switch touch.kind {
            case .held:
                if let cursor {
                    let target = CGPoint(x: cursor.x, y: cursor.y - touch.lift - 6)
                    let follow = touch.heavy ? min(1, dt * 6) : 1
                    ants[i].pos = CGPoint(x: ants[i].pos.x + (target.x - ants[i].pos.x) * follow, y: ants[i].pos.y + (target.y - ants[i].pos.y) * follow)
                }
                touch.spin = touch.gentle ? 0.12 * sin(touch.clock * 4) : 0.3 * sin(touch.clock * 13)
                if hand.press == nil { // (the press ended somewhere we did not see: set it down)
                    touch.kind = .flying(vx: 0, vy: 0, vz: 0)
                }
            case .flying(let vx, let vy, var vz):
                ants[i].pos.x += vx * dt
                ants[i].pos.y += vy * dt
                vz -= (touch.floaty ? 180 : 900) * dt
                if touch.floaty { vz = max(vz, -40) }
                touch.lift += vz * dt
                let breed = breedID(of: ants[i])
                if breed == "scout", race == "goblin" { touch.spin += 14 * dt } else { touch.spin = 0.35 * sin(touch.clock * 15) } // (the quick ones somersault)
                touch.kind = .flying(vx: vx, vy: vy, vz: vz)
                if race == "elf", breed == "scout", touch.clock > 0.15, touch.clock - dt <= 0.15 { // a shot in mid-air
                    hand.add(.arrow(from: ants[i].pos), at: CGPoint(x: ants[i].pos.x + CGFloat(vx * 0.4), y: ants[i].pos.y + 30), life: 1.2)
                }
                if touch.lift <= 0 {
                    touch.lift = 0
                    touch.spin = 0
                    ants[i].touch = touch
                    land(i)
                    continue
                }
            case .react:
                touch.left -= dt
                touch.spin = 0
                switch touch.anim {
                case .flee where touch.toward:
                    if hypot(touch.from.x - ants[i].pos.x, touch.from.y - ants[i].pos.y) > 6 { ants[i].step(to: clampWalkable(touch.from), speed: 75, dt: dt) }
                case .flee:
                    let away = atan2(ants[i].pos.y - touch.from.y, ants[i].pos.x - touch.from.x)
                    ants[i].step(to: clampWalkable(CGPoint(x: ants[i].pos.x + cos(away) * 20, y: ants[i].pos.y + sin(away) * 20)), speed: 75, dt: dt)
                case .dodge where touch.clock < 0.2:
                    let side = atan2(ants[i].pos.y - touch.from.y, ants[i].pos.x - touch.from.x) + .pi / 2
                    ants[i].pos = clampWalkable(CGPoint(x: ants[i].pos.x + cos(side) * 180 * dt, y: ants[i].pos.y + sin(side) * 120 * dt))
                case .chase:
                    if let cursor, hypot(cursor.x - ants[i].pos.x, cursor.y - ants[i].pos.y) > 14 {
                        ants[i].step(to: clampWalkable(cursor), speed: 65, dt: dt)
                    }
                case .punch:
                    if let cursor { ants[i].face(cursor) }
                case .hop:
                    touch.lift = max(0, sin(min(1, touch.clock / 0.35) * .pi) * 6)
                default: break
                }
                if touch.left <= 0 {
                    ants[i].touch = nil
                    continue
                }
            }
            ants[i].touch = touch
        }
    }
}

// MARK: - Test (`CAMP_TEST_TOUCH=/path/prefix`)

/// Pokes, pesters, pats, lifts, throws and gives orders to one of each breed by itself, and draws the camp window at the moments that
/// matter (`prefix-a.png` hands on, `-b` in the air, `-c` landed, `-d` the order and the hover name), then quits. Use with `-character`.
enum TouchTest {
    static let prefix = ProcessInfo.processInfo.environment["CAMP_TEST_TOUCH"]
    /// When the show starts (seconds of hand time): long enough for the camp to fill up.
    static let start = Double(ProcessInfo.processInfo.environment["CAMP_TEST_TOUCH_AT"] ?? "") ?? 25
    static var picked: [String: Int] = [:]
    /// `CAMP_TEST_LIFESHOT=/path/prefix`: what everybody is up to (counted every 15 s from 30 s on, and drawn), to see that the camp is alive.
    static let lifePrefix = ProcessInfo.processInfo.environment["CAMP_TEST_LIFESHOT"]
}

extension Colony {
    fileprivate func shoot(_ path: String) {
        guard let view = AntView.campView,
              let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return NSLog("touch test: no camp window") }
        view.cacheDisplay(in: view.bounds, to: rep)
        if let png = rep.representation(using: .png, properties: [:]) { try? png.write(to: URL(fileURLWithPath: path)) }
    }

    private func report(_ when: String) {
        let lines = TouchTest.picked.sorted { $0.key < $1.key }.map { (name, id) -> String in
            guard let a = ants.first(where: { $0.id == id }) else { return "\(name): gone" }
            let t = a.touch.map { "\($0.kind) \($0.anim) lift \(Int($0.lift)) \"\($0.line ?? "")\"" } ?? "none"
            return "\(name)#\(id) [\(a.stateLabel)] \(t)"
        }
        print("touch test \(when): " + lines.joined(separator: " | ") + " | hover \(String(describing: hand.hover)) cursor \(String(describing: hand.cursor))")
        fflush(stdout)
    }

    fileprivate func runTouchTest(_ prefix: String, before: Double) {
        let t = hand.clock - TouchTest.start
        func at(_ s: Double) -> Bool { t >= s && before - TouchTest.start < s }
        func id(_ name: String) -> Int? { TouchTest.picked[name] }
        if at(0) {
            let center = CGPoint(x: walkable.first?.midX ?? 300, y: walkable.first?.midY ?? 200)
            var used = Set<Int>()
            for breed in ["common", "scout", "brute", "sage", "golden"] {
                var candidates = ants.filter { !used.contains($0.id) && canTouch($0) && !$0.isChild && breedID(of: $0) == breed && $0.activity == nil }
                if candidates.isEmpty { candidates = ants.filter { !used.contains($0.id) && canTouch($0) && !$0.isChild && breedID(of: $0) == breed } }
                if let a = candidates.min(by: { hypot($0.pos.x - center.x, $0.pos.y - center.y) < hypot($1.pos.x - center.x, $1.pos.y - center.y) }) {
                    TouchTest.picked[breed] = a.id
                    used.insert(a.id)
                }
            }
            if let kid = ants.first(where: { $0.isChild && canTouch($0) }) { TouchTest.picked["child"] = kid.id }
            if let extra = ants.first(where: { !used.contains($0.id) && canTouch($0) && !$0.isChild && breedID(of: $0) == "common" && $0.activity == nil }) {
                TouchTest.picked["thrown"] = extra.id
            }
            print("touch test: \(Characters.current.id), \(ants.count) residents, picked \(TouchTest.picked)")
            if let a = id("common") { poke(a) }
            if let a = id("scout"), let ant = ants.first(where: { $0.id == a }) {
                hand.cursor = CGPoint(x: ant.pos.x, y: ant.pos.y + 30)
                hand.press = Hand.Press(target: .ant(a), start: ant.pos, moved: true, lifted: true)
                _ = lift(a)
            }
            if let a = id("brute") { for _ in 0..<4 { poke(a) } }
            if let a = id("sage") { for _ in 0..<4 { poke(a) } }
            if let a = id("golden") { startPet(a) }
            if let a = id("child") { poke(a) }
            pokePrincess()
            report("hands on")
        }
        if at(0.5) { shoot(prefix + "-a.png") }
        if at(3) {
            report("before the throw")
            hand.press = nil
            if let a = id("golden") { endPet(a) }
            for name in ["scout", "thrown", "brute"] {
                guard let a = id(name), let i = ants.firstIndex(where: { $0.id == a }) else { continue }
                if ants[i].touch?.isHeld != true { _ = lift(a) }
                guard ants[i].touch?.isHeld == true else { continue }
                ants[i].touch?.kind = .flying(vx: name == "brute" ? -60 : 160, vy: 40, vz: 160)
            }
        }
        if at(3.2) { report("in the air"); shoot(prefix + "-b.png") }
        if at(3.9) { report("landed"); shoot(prefix + "-c.png") }
        if at(7) {
            if let a = id("brute") { order(a, .fell) }
            if let a = id("common") { order(a, .play) }
            if let a = id("golden") { order(a, .home) }
            if let a = id("sage"), let ant = ants.first(where: { $0.id == a }) { handMoved(to: CGPoint(x: ant.pos.x, y: ant.pos.y + 6), over: .ant(a)) }
        }
        if at(7.5) { report("orders"); shoot(prefix + "-d.png") }
        if at(9) { NSApp.terminate(nil) }
    }
}

extension Colony {
    fileprivate func runLifeTest(_ prefix: String, before: Double) {
        for (k, when) in [30.0, 45, 60, 75, 90].enumerated() where hand.clock >= when && before < when {
            var counts: [String: Int] = [:]
            for ant in ants { counts[ant.stateLabel, default: 0] += 1 }
            let shown = counts.sorted { $0.value > $1.value }.map { "\($0.key) \($0.value)" }.joined(separator: "、")
            print("life: \(Characters.current.id) \(Scenery.currentHour)h t\(Int(when)) \(ants.count) residents: \(shown)")
            fflush(stdout)
            shoot(prefix + "-\(k).png")
            if k == 4 { NSApp.terminate(nil) }
        }
    }
}
