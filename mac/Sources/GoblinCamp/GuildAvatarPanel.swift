import AppKit

/// What an avatar may be put together from (shared/src/guild.ts: AVATAR_OPTIONS, avatarOptions, defaultAvatar, randomAvatar).
enum AvatarKit {
    static let faces = ["round", "pointed", "square", "heart", "chubby"]
    static let eyes = ["round", "narrow", "sparkle", "dot", "sleepy", "sharp", "lashes", "wide", "droopy", "cat_eye", "smiley", "big"]
    static let brows = ["thin", "thick", "faint", "arched", "angry", "none"]
    static let hairColors = ["black", "darkbrown", "chestnut", "orange", "yellow", "blonde", "silver", "pink", "lavender", "mint", "navy", "forest"]
    private static let mouths = ["line", "smile", "smirk", "open", "pout", "cat", "tongue", "toothy", "wavy"]
    private static let skullMouths = ["teeth", "grin", "gap", "jaw", "fang", "stitch", "crooked", "buck", "toothless"]
    private static let spiritSkins = ["pale_blue", "ice", "pale_violet", "lavender", "pale_green", "rose"]

    struct Options { let hair: [String]; let skin: [String]; let mouth: [String]; let flame: [String] }

    static func options(_ race: String, _ sex: String) -> Options {
        let m = sex == "m"
        switch race {
        case "elf":
            return Options(hair: m ? ["neat", "long", "halfup", "ponytail", "side_braid", "waves", "messy", "braided_crown", "short_crop", "low_tail", "circlet", "pixie", "twin_braids", "flower_bun"]
                                   : ["long_wreath", "braided_crown", "side_braid", "waves", "long", "ponytail", "halfup", "wreath_updo", "hime", "flower_bun", "twin_braids", "circlet", "pixie", "low_tail"],
                           skin: ["fair", "warm", "tan", "bronze", "rosy", "umber"], mouth: mouths, flame: [])
        case "undead":
            return Options(hair: m ? ["hood", "bare", "crack", "horns", "long_horns", "ragged_hood", "bone_crown", "candle", "antlers", "unicorn_horn", "bone_ridge", "soul_flame", "iron_circlet", "mossy"]
                                   : ["drift", "flame", "mist", "wisp_twins", "glass_short", "long_wave", "side_wisp", "flame_crown", "veil", "short_wisp", "ponytail_wisp", "star_crown", "twin_buns", "hime"],
                           skin: m ? ["bone", "ivory", "ash", "slate", "moss_bone", "dusk"] : spiritSkins, mouth: m ? skullMouths : mouths, flame: m ? ["cyan", "violet", "green", "orange"] : [])
        default:
            return Options(hair: m ? ["tuft", "mohawk", "topknot", "bald_ring", "dreads", "wild", "bun", "spikes", "afro", "side_shave", "warrior_tail", "bowl", "shaggy", "long_braid"]
                                   : ["braids", "bun", "dreads", "wild", "tuft", "pigtails", "mohawk", "bob", "twin_buns", "long_braid", "afro", "shaggy", "bowl", "warrior_tail"],
                           skin: ["light", "grass", "moss", "deep", "olive", "teal"], mouth: mouths, flame: [])
        }
    }

    static let labels: [String: String] = [
        "round": "圓", "pointed": "尖", "square": "方", "heart": "心形", "chubby": "肉肉",
        "narrow": "細長", "sparkle": "大閃", "dot": "豆豆", "sleepy": "睏睏", "sharp": "銳利", "lashes": "長睫毛", "wide": "圓睜",
        "droopy": "垂眼", "cat_eye": "貓眼", "smiley": "瞇瞇笑眼", "big": "大眼睛",
        "thin": "細眉", "thick": "粗眉", "faint": "淡眉", "none": "無眉", "arched": "彎眉", "angry": "劍眉",
        "tongue": "吐舌", "toothy": "露齒笑", "wavy": "波浪嘴", "crooked": "歪牙", "buck": "暴牙", "toothless": "沒牙",
        "line": "一字", "smile": "微笑", "smirk": "歪嘴笑", "open": "張嘴", "pout": "嘟嘴", "cat": "貓嘴",
        "teeth": "一排牙", "grin": "咧嘴", "gap": "缺牙", "jaw": "下巴骨", "fang": "尖牙", "stitch": "縫線",
        "tuft": "亂翹一撮", "mohawk": "莫霍克", "topknot": "沖天辮", "bald_ring": "光頭加耳環", "dreads": "髒辮", "wild": "狂野亂髮", "bun": "頭頂小髻", "spikes": "刺刺頭",
        "braids": "雙麻花", "pigtails": "雙馬尾", "bob": "短鮑伯",
        "neat": "短俐落", "long": "長直髮", "halfup": "半紮", "ponytail": "長馬尾", "side_braid": "側編辮", "waves": "及腰波浪", "messy": "蓬鬆", "braided_crown": "編髮頭冠",
        "long_wreath": "長直髮・花冠", "wreath_updo": "花環盤髮",
        "hood": "兜帽", "bare": "光頭骨", "crack": "頭骨裂痕", "horns": "小角", "long_horns": "長角", "ragged_hood": "破兜帽", "bone_crown": "骨冠", "candle": "頭頂蠟燭",
        "drift": "飄散的靈髮", "flame": "火焰髮", "mist": "霧狀長髮", "wisp_twins": "雙馬尾鬼火", "glass_short": "半透明短髮", "long_wave": "長波浪", "side_wisp": "側邊靈絲", "flame_crown": "火焰冠",
        "afro": "爆炸頭", "side_shave": "側剃油頭", "warrior_tail": "戰士馬尾", "bowl": "西瓜皮", "shaggy": "蓬亂短髮", "long_braid": "單長辮", "twin_buns": "雙丸子頭",
        "short_crop": "清爽短髮", "low_tail": "低馬尾", "circlet": "頭環長髮", "pixie": "精靈短髮", "twin_braids": "雙垂辮", "flower_bun": "花苞頭", "hime": "公主切",
        "antlers": "鹿角", "unicorn_horn": "獨角", "bone_ridge": "骨刺", "soul_flame": "頭頂魂火", "iron_circlet": "鐵頭箍", "mossy": "長苔蘚",
        "veil": "面紗", "short_wisp": "短靈髮", "ponytail_wisp": "靈絲馬尾", "star_crown": "星冠長髮",
        "olive": "橄欖綠", "teal": "藍綠", "rosy": "粉嫩", "umber": "深褐", "moss_bone": "苔骨", "dusk": "夜骨", "pale_green": "淡綠", "rose": "淡粉",
        "light": "淺綠", "grass": "草綠", "moss": "苔綠", "deep": "深綠",
        "fair": "白皙", "warm": "暖膚", "tan": "小麥", "bronze": "古銅",
        "bone": "骨白", "ivory": "象牙", "ash": "灰骨", "slate": "石灰",
        "pale_blue": "淡藍", "ice": "冰藍", "pale_violet": "淡紫", "lavender": "薰衣草",
        "black": "黑", "darkbrown": "深棕", "chestnut": "栗色", "orange": "橘紅", "yellow": "蜜黃", "blonde": "淡金", "silver": "銀白", "pink": "粉紅", "mint": "薄荷", "navy": "深藍", "forest": "森綠",
        "cyan": "青", "violet": "紫", "green": "綠",
    ]

    /// The clothes (shared/src/guild-outfits.ts GUILD_OUTFITS): bought with one's own contribution, the free ones everyone has.
    /// The limited ones only while a holiday is on, from a guild level on, or when the guild merchant brings them (what one has stays).
    struct Outfit {
        let id: String; let slot: String; let name: String; let price: Int
        var season: String? = nil
        var level: Int? = nil
        var merchant = false
    }
    static let outfits: [Outfit] = [
        Outfit(id: "linen_shirt", slot: "top", name: "亞麻上衣", price: 0),
        Outfit(id: "leather_vest", slot: "top", name: "皮背心", price: 300),
        Outfit(id: "knight_tabard", slot: "top", name: "騎士罩袍", price: 800),
        Outfit(id: "mage_robe", slot: "top", name: "法師長袍", price: 1200),
        Outfit(id: "noble_doublet", slot: "top", name: "貴族短上衣", price: 2000),
        Outfit(id: "work_trousers", slot: "bottom", name: "工作褲", price: 0),
        Outfit(id: "leather_pants", slot: "bottom", name: "皮褲", price: 400),
        Outfit(id: "plaid_kilt", slot: "bottom", name: "格子裙", price: 600),
        Outfit(id: "silk_skirt", slot: "bottom", name: "絲綢長裙", price: 1000),
        Outfit(id: "sandals", slot: "shoes", name: "草鞋", price: 0),
        Outfit(id: "leather_boots", slot: "shoes", name: "皮靴", price: 300),
        Outfit(id: "pointy_slippers", slot: "shoes", name: "尖頭軟鞋", price: 500),
        Outfit(id: "iron_greaves", slot: "shoes", name: "鐵護脛", price: 900),
        Outfit(id: "straw_hat", slot: "hat", name: "草帽", price: 0),
        Outfit(id: "flower_crown", slot: "hat", name: "花冠", price: 400),
        Outfit(id: "feather_cap", slot: "hat", name: "羽毛帽", price: 600),
        Outfit(id: "iron_helm", slot: "hat", name: "鐵頭盔", price: 1000),
        Outfit(id: "wizard_hat", slot: "hat", name: "巫師帽", price: 1500),
        Outfit(id: "red_festive_jacket", slot: "top", name: "紅繡花襖", price: 800, season: "spring_festival"),
        Outfit(id: "lion_dance_hat", slot: "hat", name: "舞獅帽", price: 900, season: "spring_festival"),
        Outfit(id: "embroidered_slippers", slot: "shoes", name: "繡花鞋", price: 400, season: "spring_festival"),
        Outfit(id: "lantern_robe", slot: "top", name: "元宵燈籠袍", price: 700, season: "lantern"),
        Outfit(id: "lantern_hat", slot: "hat", name: "燈籠帽", price: 600, season: "lantern"),
        Outfit(id: "rower_vest", slot: "top", name: "龍舟隊背心", price: 500, season: "dragon_boat"),
        Outfit(id: "rice_dumpling_hat", slot: "hat", name: "粽子帽", price: 600, season: "dragon_boat"),
        Outfit(id: "rabbit_ear_hood", slot: "hat", name: "玉兔耳帽", price: 700, season: "mid_autumn"),
        Outfit(id: "moon_gown", slot: "top", name: "月白長袍", price: 800, season: "mid_autumn"),
        Outfit(id: "cloud_shoes", slot: "shoes", name: "雲紋鞋", price: 400, season: "mid_autumn"),
        Outfit(id: "flag_cap", slot: "hat", name: "國慶小旗帽", price: 500, season: "national"),
        Outfit(id: "parade_jacket", slot: "top", name: "閱兵禮服", price: 800, season: "national"),
        Outfit(id: "party_hat", slot: "hat", name: "派對帽", price: 400, season: "new_year"),
        Outfit(id: "sequin_jacket", slot: "top", name: "亮片外套", price: 800, season: "new_year"),
        Outfit(id: "santa_hat", slot: "hat", name: "聖誕帽", price: 500, season: "christmas"),
        Outfit(id: "santa_coat", slot: "top", name: "聖誕紅外套", price: 900, season: "christmas"),
        Outfit(id: "jingle_boots", slot: "shoes", name: "鈴鐺靴", price: 500, season: "christmas"),
        Outfit(id: "craftsman_apron", slot: "top", name: "工匠圍裙", price: 600, level: 2),
        Outfit(id: "scholar_vest", slot: "top", name: "書生背心", price: 700, level: 2),
        Outfit(id: "canvas_trousers", slot: "bottom", name: "帆布褲", price: 500, level: 2),
        Outfit(id: "work_clogs", slot: "shoes", name: "木鞋", price: 500, level: 2),
        Outfit(id: "study_slippers", slot: "shoes", name: "書房拖鞋", price: 500, level: 2),
        Outfit(id: "reading_cap", slot: "hat", name: "書生帽", price: 800, level: 2),
        Outfit(id: "council_coat", slot: "top", name: "議事長外套", price: 1000, level: 3),
        Outfit(id: "clerk_shirt", slot: "top", name: "書記襯衫", price: 800, level: 3),
        Outfit(id: "pleated_trousers", slot: "bottom", name: "摺線長褲", price: 700, level: 3),
        Outfit(id: "dark_skirt", slot: "bottom", name: "深色長裙", price: 700, level: 3),
        Outfit(id: "polished_shoes", slot: "shoes", name: "亮皮鞋", price: 650, level: 3),
        Outfit(id: "tricorn_hat", slot: "hat", name: "三角帽", price: 1050, level: 3),
        Outfit(id: "gardener_smock", slot: "top", name: "園丁罩衫", price: 900, level: 4),
        Outfit(id: "hunter_jerkin", slot: "top", name: "獵人短衣", price: 1100, level: 4),
        Outfit(id: "green_breeches", slot: "bottom", name: "綠色馬褲", price: 850, level: 4),
        Outfit(id: "garden_boots", slot: "shoes", name: "雨靴", price: 800, level: 4),
        Outfit(id: "hunter_boots", slot: "shoes", name: "獵人長靴", price: 950, level: 4),
        Outfit(id: "sun_bonnet", slot: "hat", name: "遮陽帽", price: 1000, level: 4),
        Outfit(id: "banquet_gown", slot: "top", name: "宴會禮服", price: 1500, level: 5),
        Outfit(id: "velvet_doublet", slot: "top", name: "絲絨短上衣", price: 1400, level: 5),
        Outfit(id: "satin_skirt", slot: "bottom", name: "緞面長裙", price: 1100, level: 5),
        Outfit(id: "velvet_breeches", slot: "bottom", name: "絲絨馬褲", price: 1000, level: 5),
        Outfit(id: "buckle_shoes", slot: "shoes", name: "金扣鞋", price: 950, level: 5),
        Outfit(id: "jeweled_tiara", slot: "hat", name: "寶石頭冠", price: 1550, level: 5),
        Outfit(id: "chainmail", slot: "top", name: "鎖子甲", price: 1600, level: 6),
        Outfit(id: "padded_gambeson", slot: "top", name: "軟甲", price: 1200, level: 6),
        Outfit(id: "armored_leggings", slot: "bottom", name: "鐵腿甲", price: 1400, level: 6),
        Outfit(id: "war_kilt", slot: "bottom", name: "戰裙", price: 1100, level: 6),
        Outfit(id: "sabatons", slot: "shoes", name: "鐵靴", price: 1300, level: 6),
        Outfit(id: "knight_helm", slot: "hat", name: "騎士頭盔", price: 1800, level: 6),
        Outfit(id: "archmage_robe", slot: "top", name: "大法師長袍", price: 2050, level: 7),
        Outfit(id: "star_mantle", slot: "top", name: "星辰披風", price: 1900, level: 7),
        Outfit(id: "runed_skirt", slot: "bottom", name: "符文長裙", price: 1500, level: 7),
        Outfit(id: "starlit_slippers", slot: "shoes", name: "星光軟鞋", price: 1250, level: 7),
        Outfit(id: "silver_greaves", slot: "shoes", name: "銀護脛", price: 1400, level: 7),
        Outfit(id: "astral_crown", slot: "hat", name: "星辰冠", price: 2050, level: 7),
        Outfit(id: "silk_kimono", slot: "top", name: "絲綢和服", price: 2500, merchant: true),
        Outfit(id: "desert_robe", slot: "top", name: "沙漠長袍", price: 1800, merchant: true),
        Outfit(id: "dragon_scale_armor", slot: "top", name: "龍鱗甲", price: 3000, merchant: true),
        Outfit(id: "phoenix_coat", slot: "top", name: "鳳凰羽衣", price: 2800, merchant: true),
        Outfit(id: "harem_pants", slot: "bottom", name: "燈籠褲", price: 1500, merchant: true),
        Outfit(id: "golden_sandals", slot: "shoes", name: "金涼鞋", price: 1600, merchant: true),
        Outfit(id: "dragon_boots", slot: "shoes", name: "龍皮靴", price: 2200, merchant: true),
        Outfit(id: "golden_crown", slot: "hat", name: "黃金王冠", price: 3000, merchant: true),
        Outfit(id: "turban", slot: "hat", name: "纏頭巾", price: 1600, merchant: true),
        Outfit(id: "dragon_horn_helm", slot: "hat", name: "龍角盔", price: 2600, merchant: true),
    ]
    static let slots = [("top", "上衣"), ("bottom", "下身"), ("shoes", "鞋子"), ("hat", "帽子")]

    /// The same look wearing `id` on `slot` (nil: the body's own clothes, or no hat).
    static func wearing(_ a: GuildInfo.Avatar, _ slot: String, _ id: String?) -> GuildInfo.Avatar {
        var out = a
        switch slot {
        case "top": out.top = id
        case "bottom": out.bottom = id
        case "shoes": out.shoes = id
        default: out.hat = id
        }
        return out
    }

    static func worn(_ a: GuildInfo.Avatar, _ slot: String) -> String? {
        switch slot {
        case "top": return a.top
        case "bottom": return a.bottom
        case "shoes": return a.shoes
        default: return a.hat
        }
    }

    /// The clothes of `from` put on `to` (a new body or a roll of the dice keeps what was worn).
    static func dressed(_ to: GuildInfo.Avatar, like from: GuildInfo.Avatar) -> GuildInfo.Avatar {
        slots.reduce(to) { wearing($0, $1.0, worn(from, $1.0)) }
    }

    /// The approved look of each race's two avatars.
    static func standard(_ race: String, _ sex: String) -> GuildInfo.Avatar {
        let r = ["goblin", "elf", "undead"].contains(race) ? race : "goblin"
        let o = options(r, sex)
        var a = GuildInfo.Avatar(race: r, sex: sex, face: "round", eyes: "round", brows: "none", mouth: o.mouth[0], hair: o.hair[0], hairColor: "black", skin: o.skin[0], flame: o.flame.first)
        switch r + sex {
        case "goblinm": a.hairColor = "darkbrown"; a.skin = "grass"; a.brows = "faint"
        case "goblinf": a.hairColor = "orange"; a.skin = "grass"; a.eyes = "lashes"
        case "elfm": a.hairColor = "chestnut"; a.skin = "fair"
        case "elff": a.hairColor = "blonde"; a.skin = "fair"; a.eyes = "lashes"
        case "undeadm": a.hairColor = "black"; a.skin = "bone"; a.flame = "cyan"
        default: a.hairColor = "mint"; a.skin = "pale_blue"; a.eyes = "lashes"
        }
        return a
    }

    /// Hair colours that go badly with a skin, left out when choosing at random.
    private static let clashes: [String: [String]] = ["grass": ["forest", "mint"], "moss": ["forest", "mint"], "deep": ["forest", "navy", "black"], "light": ["mint"], "pale_blue": ["navy"], "ice": ["mint", "navy"]]

    /// Every part chosen at random; `only` names the one part to change (the rest stay as `from` has them).
    static func random(_ race: String, _ sex: String, from: GuildInfo.Avatar? = nil, only part: String? = nil) -> GuildInfo.Avatar {
        let base = standard(race, sex)
        let o = options(base.race, sex)
        let skin = o.skin.randomElement()!
        var out = base
        out.face = faces.randomElement()!
        out.eyes = eyes.randomElement()!
        out.brows = brows.randomElement()!
        out.mouth = o.mouth.randomElement()!
        out.hair = o.hair.randomElement()!
        out.skin = skin
        out.hairColor = hairColors.filter { !(clashes[skin] ?? []).contains($0) }.randomElement()!
        out.flame = o.flame.randomElement()
        guard let from, let part, from.race == out.race, from.sex == out.sex else { return out }
        var kept = from
        switch part {
        case "face": kept.face = out.face
        case "eyes": kept.eyes = out.eyes
        case "brows": kept.brows = out.brows
        case "mouth": kept.mouth = out.mouth
        case "hair": kept.hair = out.hair
        case "hairColor": kept.hairColor = out.hairColor
        case "skin": kept.skin = out.skin
        case "flame": kept.flame = out.flame
        default: break
        }
        return kept
    }
}

/// The avatar, big, doing one of its moves (the maker's preview).
final class AvatarPreview: NSView {
    var avatar: GuildInfo.Avatar { didSet { needsDisplay = true } }
    var anim = "idle" { didSet { began = Date() } }
    private var began = Date()
    private var timer: Timer?

    init(_ avatar: GuildInfo.Avatar) {
        self.avatar = avatar
        super.init(frame: NSRect(x: 0, y: 0, width: 240, height: 250))
        translatesAutoresizingMaskIntoConstraints = false
        widthAnchor.constraint(equalToConstant: 240).isActive = true
        heightAnchor.constraint(equalToConstant: 250).isActive = true
    }

    required init?(coder: NSCoder) { fatalError() }

    override var isFlipped: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        timer?.invalidate()
        guard window != nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 20, repeats: true) { [weak self] _ in self?.needsDisplay = true }
        RunLoop.main.add(timer!, forMode: .common)
    }

    override func draw(_ dirtyRect: NSRect) {
        let card = NSBezierPath(roundedRect: bounds, xRadius: 12, yRadius: 12)
        NSColor(calibratedRed: 0.91, green: 0.86, blue: 0.75, alpha: 1).setFill()
        card.fill()
        let art = GuildArt.shared
        let t = Date().timeIntervalSince(began)
        guard let img = art.avatarFrame(avatar, art.frameIndex(anim: anim, dir: "front", t: t)), let g = NSGraphicsContext.current?.cgContext else { return }
        let scale: CGFloat = 6
        let w = CGFloat(art.frameW) * scale, h = CGFloat(art.frameH) * scale
        g.saveGState()
        g.interpolationQuality = .none
        g.translateBy(x: (bounds.width - w) / 2, y: (bounds.height - h) / 2 + h)
        g.scaleBy(x: 1, y: -1)
        g.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
        g.restoreGState()
    }
}

/// Buttons that wrap onto as many lines as they need.
final class FlowView: NSView {
    private let width: CGFloat
    private var height: CGFloat = 0

    init(width: CGFloat, items: [NSView]) {
        self.width = width
        super.init(frame: NSRect(x: 0, y: 0, width: width, height: 10))
        var x: CGFloat = 0, y: CGFloat = 0, row: CGFloat = 0
        for v in items {
            let size = v.fittingSize
            if x > 0, x + size.width > width {
                x = 0
                y += row + 4
                row = 0
            }
            v.frame = NSRect(x: x, y: y, width: size.width, height: size.height)
            addSubview(v)
            x += size.width + 4
            row = max(row, size.height)
        }
        height = y + row
        frame.size.height = height
        translatesAutoresizingMaskIntoConstraints = false
        widthAnchor.constraint(equalToConstant: width).isActive = true
        heightAnchor.constraint(equalToConstant: max(height, 1)).isActive = true
    }

    required init?(coder: NSCoder) { fatalError() }
    override var isFlipped: Bool { true }
}

/// 我的角色 (GUILD.md §2): the guild avatar, of the camp's race. Each part can be picked, or rolled at random (all of them, or
/// just one), and the preview plays the avatar's moves.
final class GuildAvatarPanel: GuildPanelController, GuildPanelInit {
    let view: GuildPanel
    private let ctx: GuildContext
    private var look: GuildInfo.Avatar
    private let preview: AvatarPreview
    private var move = "idle"
    private var busy = false
    /// The clothes owned and the contribution left (nil: an older server, no clothes to choose).
    private var wardrobe: GuildInfo.Wardrobe?

    private static let moves = [("idle", "站著"), ("walk", "走路"), ("sit", "坐著"), ("type", "打字"), ("wave", "揮手"), ("cheer", "歡呼"), ("doze", "打瞌睡")]

    init(_ ctx: GuildContext) {
        self.ctx = ctx
        let a = ctx.info()?.avatar ?? AvatarKit.standard("goblin", "m")
        look = a
        preview = AvatarPreview(a)
        wardrobe = ctx.info()?.wardrobe
        view = GuildPanel(title: "我的角色", sub: "在公會據點裡代表你", close: ctx.close)
        render()
    }

    func guildChanged() {}

    private func set(_ part: String, _ value: String) {
        switch part {
        case "face": look.face = value
        case "eyes": look.eyes = value
        case "brows": look.brows = value
        case "mouth": look.mouth = value
        case "hair": look.hair = value
        case "hairColor": look.hairColor = value
        case "skin": look.skin = value
        case "flame": look.flame = value
        default: break
        }
        changed()
    }

    private func current(_ part: String) -> String? {
        switch part {
        case "face": return look.face
        case "eyes": return look.eyes
        case "brows": return look.brows
        case "mouth": return look.mouth
        case "hair": return look.hair
        case "hairColor": return look.hairColor
        case "skin": return look.skin
        default: return look.flame
        }
    }

    private func changed() {
        preview.avatar = look
        render()
    }

    private func render() {
        let inner = view.inner
        let bone = look.race == "undead" && look.sex == "m"
        let o = AvatarKit.options(look.race, look.sex)
        var out: [NSView] = [preview]
        let moveButtons = FlowView(width: inner, items: Self.moves.map { m in
            let b = GuildUI.button(m.1, prominent: move == m.0) { [weak self] in
                self?.move = m.0
                self?.preview.anim = m.0
                self?.render()
            }
            return b
        })
        out.append(moveButtons)

        let names = look.race == "undead" ? ["骨系", "魂系"] : ["男", "女"]
        let sex = NSSegmentedControl(labels: names, trackingMode: .selectOne, target: nil, action: nil)
        sex.selectedSegment = look.sex == "m" ? 0 : 1
        sex.controlSize = .small
        let handler = FieldHandler { [weak self, weak sex] in
            guard let self, let sex else { return }
            let s = sex.selectedSegment == 0 ? "m" : "f"
            if s != self.look.sex { self.look = AvatarKit.dressed(AvatarKit.standard(self.look.race, s), like: self.look); self.changed() }
        }
        sex.target = handler
        sex.action = #selector(FieldHandler.fire)
        objc_setAssociatedObject(sex, "handler", handler, .OBJC_ASSOCIATION_RETAIN)
        out.append(GuildUI.row([sex, NSView(), GuildUI.button("🎲 全部隨機") { [weak self] in
            guard let self else { return }
            self.look = AvatarKit.dressed(AvatarKit.random(self.look.race, self.look.sex), like: self.look)
            self.changed()
        }]))

        var parts: [(key: String, title: String, list: [String], colour: String?)] = [("hair", bone ? "頭部" : "髮型", o.hair, nil)]
        if !bone { parts.append(("hairColor", "髮色", AvatarKit.hairColors, "hair")) }
        parts.append(("skin", bone ? "骨色" : "膚色", o.skin, "skin"))
        if !o.flame.isEmpty { parts.append(("flame", "眼火", o.flame, "flame")) }
        parts.append(("face", "臉型", AvatarKit.faces, nil))
        parts.append(("eyes", "眼睛", AvatarKit.eyes, nil))
        if !bone { parts.append(("brows", "眉毛", AvatarKit.brows, nil)) }
        parts.append(("mouth", "嘴巴", o.mouth, nil))

        for p in parts {
            out.append(GuildUI.separator())
            out.append(GuildUI.row([GuildUI.heading(p.title), NSView(), GuildUI.button("🎲") { [weak self] in
                guard let self else { return }
                self.look = AvatarKit.random(self.look.race, self.look.sex, from: self.look, only: p.key)
                self.changed()
            }]))
            let items = p.list.map { v -> NSView in
                let on = current(p.key) == v
                let title = NSMutableAttributedString()
                if let channel = p.colour {
                    let key = channel == "skin" ? "\(look.race)_\(look.sex)_\(v)" : v
                    if let c = GuildArt.shared.swatch(channel, key) { title.append(NSAttributedString(string: "● ", attributes: [.foregroundColor: c])) }
                }
                title.append(NSAttributedString(string: AvatarKit.labels[v] ?? v, attributes: [.foregroundColor: on ? NSColor(calibratedRed: 0.17, green: 0.11, blue: 0, alpha: 1) : NSColor.labelColor]))
                let b = GuildUI.button("") { [weak self] in self?.set(p.key, v) }
                b.attributedTitle = title
                if on { b.bezelColor = GuildUI.gold }
                return b
            }
            out.append(FlowView(width: inner, items: items))
        }

        if let wardrobe { out += clothes(wardrobe, inner) }

        out.append(GuildUI.separator())
        let save = GuildUI.button("儲存角色", prominent: true) { [weak self] in self?.save() }
        save.isEnabled = !busy
        out.append(save)
        view.show(out)
    }

    /// 衣服: each slot's clothes as cards, the avatar wearing each; an owned one is put on (or taken off), the others bought.
    private func clothes(_ w: GuildInfo.Wardrobe, _ inner: CGFloat) -> [NSView] {
        let art = GuildArt.shared
        let idle = art.frameIndex(anim: "idle", dir: "front", t: 0)
        var out: [NSView] = [GuildUI.separator(), GuildUI.row([GuildUI.heading("衣服"), NSView(), GuildUI.heading("貢獻 \(w.points)")])]
        for (slot, title) in AvatarKit.slots {
            out.append(GuildUI.heading(title))
            let worn = AvatarKit.worn(look, slot)
            var cells: [CatalogCell] = []
            let plain = AvatarKit.wearing(look, slot, nil)
            cells.append(CatalogCell(image: art.avatarFrame(plain, idle), pixels: NSSize(width: art.frameW, height: art.frameH), fit: 56, maxScale: 2,
                                     name: slot == "hat" ? "不戴" : "原本的", sub: "", on: worn == nil) { [weak self] in
                guard let self else { return }
                self.look = AvatarKit.wearing(self.look, slot, nil)
                self.changed()
            })
            // (基本, then 節日限定, 公會等級, 商人, each under its name; one not had that can't be had now says when it can: shared outfitClosed)
            let group = { (o: AvatarKit.Outfit) in o.season != nil ? 1 : o.level != nil ? 2 : o.merchant ? 3 : 0 }
            let groups = ["基本", "節日限定", "公會等級", "公會商人"]
            var shown = 0
            for o in AvatarKit.outfits.filter({ $0.slot == slot }).sorted(by: { group($0) != group($1) ? group($0) < group($1) : ($0.level ?? 0, $0.price) < ($1.level ?? 0, $1.price) }) {
                if group(o) != shown {
                    out.append(GuildAvatarPanel.grid(cells, width: inner))
                    out.append(GuildUI.note("\(title)・\(groups[group(o)])"))
                    cells = []
                    shown = group(o)
                }
                let fits = art.canWear(slot, o.id, race: look.race, sex: look.sex)
                let owned = w.owned.contains(o.id)
                let closed = owned ? nil : closedNow(o)
                let sub = !fits ? "這個身形穿不了" : owned ? (worn == o.id ? "穿著" : "") : closed ?? "用 \(o.price) 貢獻換"
                cells.append(CatalogCell(image: art.avatarFrame(AvatarKit.wearing(look, slot, o.id), idle), pixels: NSSize(width: art.frameW, height: art.frameH), fit: 56, maxScale: 2,
                                         name: o.name, sub: sub, on: worn == o.id, shut: !fits || closed != nil || busy) { [weak self] in
                    guard let self else { return }
                    if owned {
                        self.look = AvatarKit.wearing(self.look, slot, o.id)
                        self.changed()
                    } else {
                        self.buy(o)
                    }
                })
            }
            out.append(GuildAvatarPanel.grid(cells, width: inner))
        }
        return out
    }

    /// When a limited piece not had can be had, if not now (shared/src/guild-outfits.ts outfitClosed; the days are the server's).
    private func closedNow(_ o: AvatarKit.Outfit) -> String? {
        let g = ctx.info()?.guild
        if let id = o.season {
            let s = g?.seasons.first { $0.id == id }
            return s?.on == true ? nil : s.map { "\($0.name) \($0.range)" } ?? "節日限定"
        }
        if let level = o.level, (g?.level ?? 0) < level { return "公會 \(level) 級" }
        if o.merchant, g?.merchant?.here != true || g?.merchant?.outfits.contains(o.id) != true { return "公會商人帶來時" }
        return nil
    }

    /// Cards in rows as wide as the panel.
    private static func grid(_ cells: [CatalogCell], width: CGFloat) -> NSView {
        let box = TopDownView()
        let size = CatalogCell.size, gap: CGFloat = 4
        let cols = max(1, Int((width + gap) / (size.width + gap)))
        for (i, c) in cells.enumerated() {
            c.frame.origin = NSPoint(x: CGFloat(i % cols) * (size.width + gap), y: CGFloat(i / cols) * (size.height + gap))
            box.addSubview(c)
        }
        let rows = (cells.count + cols - 1) / cols
        box.translatesAutoresizingMaskIntoConstraints = false
        box.widthAnchor.constraint(equalToConstant: width).isActive = true
        box.heightAnchor.constraint(equalToConstant: max(1, CGFloat(rows) * (size.height + gap) - gap)).isActive = true
        return box
    }

    /// Buys these clothes with contribution (asked first), then puts them on; the server says why not (too little, had it).
    private func buy(_ o: AvatarKit.Outfit) {
        guard let w = wardrobe, !busy else { return }
        let ask = NSAlert()
        ask.messageText = "用 \(o.price) 貢獻換「\(o.name)」？"
        ask.informativeText = "你現在有 \(w.points) 貢獻（捐獻給公會累積的）。換了就是你的，之後隨時可以穿。"
        ask.addButton(withTitle: "換")
        ask.addButton(withTitle: "取消")
        guard ask.runModal() == .alertFirstButtonReturn else { return }
        struct Body: Encodable { let id: String }
        struct Got: Decodable { let wardrobe: GuildInfo.Wardrobe }
        busy = true
        render()
        ctx.run({
            defer { self.busy = false; self.render() }
            let got = try await self.ctx.api.request("POST", "guild/outfits/buy", body: Body(id: o.id), as: Got.self)
            self.wardrobe = got.wardrobe
            self.look = AvatarKit.wearing(self.look, o.slot, o.id)
            self.preview.avatar = self.look
        }, done: "換到「\(o.name)」了，記得按「儲存角色」穿上。", then: { self.ctx.reload() })
    }

    private func save() {
        busy = true
        render()
        ctx.run({
            defer { self.busy = false; self.render() }
            let got = try await self.ctx.api.request("PUT", "guild/avatar", body: self.look, as: GuildInfo.self)
            self.ctx.apply(got)
        }, done: "存好了！")
    }
}
