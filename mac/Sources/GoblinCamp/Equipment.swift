import AppKit

/// Where a piece of gear is worn. A goblin has one of each.
enum GearSlot: String, CaseIterable {
    case weapon, shield, head, chest, legs, feet, hands

    var label: String {
        switch self {
        case .weapon: return "武器"
        case .shield: return "盾牌"
        case .head: return "帽子"
        case .chest: return "胸甲"
        case .legs: return "褲子"
        case .feet: return "鞋子"
        case .hands: return "手甲"
        }
    }
}

/// How a weapon is held. A two-handed (or dual) weapon leaves no hand for a shield.
enum Grip { case one, two }

/// How a piece of gear is drawn on the goblin (a few pixels each, see `AntView.drawGear`).
enum GearLook {
    case knife, dagger, shortSword, longSword, twinBlades, greatSword, spear, bow, staff
    case roundShield, woodShield
    case cap, helm
    case tunic, plate, cloak
    case pants, boots, gloves, gauntlet
}

/// One thing the workshop can make: what it costs (materials from monsters) and what it gives.
struct Gear {
    let id: String
    let name: String
    let slot: GearSlot
    var grip = Grip.one
    /// Extra damage per hit, extra hits it takes before going down, and the chance to shrug a monster's hit off.
    var might = 0.0
    var health = 0.0
    var block = 0.0
    /// Extra walking speed (0.05 = 5% faster) and extra reach when hitting (a spear, a bow, a staff), in points.
    var speed = 0.0
    var reach = 0.0
    /// Material id → how many.
    let cost: [(String, Int)]
    let look: GearLook
    let color: NSColor
    let blurb: String

    /// One number to tell which of two pieces for the same slot is better.
    var power: Double { might + health + block * 5 + speed * 6 + reach / 40 }

    var effectText: String {
        var parts: [String] = []
        if might > 0 { parts.append("出手 +\(clean(might))") }
        if health > 0 { parts.append("多撐 \(clean(health)) 下") }
        if block > 0 { parts.append("\(Int(block * 100))% 擋掉攻擊") }
        if speed > 0 { parts.append("走路快 \(Int(speed * 100))%") }
        if reach > 0 { parts.append("打得更遠") }
        if grip == .two { parts.append("雙手") }
        return parts.joined(separator: "，")
    }

    private func clean(_ v: Double) -> String { v == v.rounded() ? "\(Int(v))" : String(format: "%.1f", v) }

    /// How much wear it takes before it breaks: a weapon loses 1 per attack, a shield 1 per hit it takes (2 for one it turns aside), and
    /// the other pieces 1 each time the goblin is hit.
    var durability: Double { Gears.durabilities[id] ?? (slot == .weapon ? 120 : 20) }
}

/// One actual piece of gear, with how much wear it has left. Gear that comes back to the nest keeps its wear.
struct GearItem {
    let id: String
    var left: Double

    init(_ gear: Gear) { id = gear.id; left = gear.durability }
    init(id: String, left: Double?) { self.id = id; self.left = left ?? Gears.by(id: id)?.durability ?? 1 }

    var gear: Gear? { Gears.by(id: id) }
    /// 1 = new, 0 = about to break.
    var fraction: Double { min(1, max(0, left / max(1, gear?.durability ?? 1))) }
    /// Worn out: it works at half strength until it breaks.
    var isWorn: Bool { fraction < 0.25 }
    /// What it is worth as gear now (a worn piece counts half).
    var power: Double { (gear?.power ?? 0) * (isWorn ? 0.5 : 1) }
}

private func rgb(_ r: Int, _ g: Int, _ b: Int) -> NSColor { NSColor(calibratedRed: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: 1) }

enum Gears {
    /// The basic set: every slot has a few, from cloth and leather to iron. Each monster that turns up brings its own materials, and with
    /// them new pieces (shells, wings, spores…): add them here.
    static let all: [Gear] = [
        // weapons: the daggers and swords in one hand, the big ones (great sword, spear, bow, twin blades) in two
        Gear(id: "bone_knife", name: "骨刀", slot: .weapon, might: 1, cost: [("rat_fang", 4), ("rat_tail", 1)], look: .knife, color: rgb(242, 235, 210),
             blurb: "用鼠牙磨成的短刀，繩子是鼠尾。"),
        Gear(id: "short_sword", name: "短劍", slot: .weapon, might: 1.2, cost: [("scrap_iron", 3), ("scrap_wood", 1), ("rat_pelt", 1)], look: .shortSword, color: rgb(184, 190, 200),
             blurb: "廢鐵敲成的短劍，最普通的武器。"),
        Gear(id: "claw_dagger", name: "利爪匕首", slot: .weapon, might: 1.5, cost: [("sharp_claw", 2), ("rat_fang", 4), ("rat_pelt", 1)], look: .dagger, color: rgb(158, 164, 184),
             blurb: "斷爪磨得很利，握柄包著鼠皮。"),
        Gear(id: "long_sword", name: "長劍", slot: .weapon, might: 1.7, cost: [("scrap_iron", 6), ("rat_pelt", 2), ("scrap_wood", 1), ("crude_blade", 1)], look: .longSword, color: rgb(206, 212, 224),
             blurb: "比短劍長一截，砍得更重。"),
        Gear(id: "crystal_blade", name: "晶刃", slot: .weapon, might: 2.5, cost: [("scrap_iron", 5), ("crystal_shard", 2), ("rat_pelt", 1), ("orc_tusk", 2), ("crude_blade", 1)], look: .longSword, color: rgb(120, 218, 240),
             blurb: "劍身嵌著挖出來的碎晶，會發出淡淡的藍光。很稀有。"),
        Gear(id: "twin_blades", name: "雙刀", slot: .weapon, grip: .two, might: 2.1, cost: [("scrap_iron", 5), ("rat_fang", 4), ("rat_pelt", 2), ("crude_blade", 2)], look: .twinBlades, color: rgb(196, 204, 216),
             blurb: "兩手各一把，出手快，沒有手拿盾。"),
        Gear(id: "great_sword", name: "雙手劍", slot: .weapon, grip: .two, might: 2.8, cost: [("scrap_iron", 9), ("rat_fang", 4), ("rat_pelt", 3), ("crude_blade", 2), ("orc_tusk", 2)], look: .greatSword, color: rgb(214, 220, 232),
             blurb: "很重的大劍，要用雙手，一劍下去魔獸都抖一下。"),
        Gear(id: "spear", name: "長槍", slot: .weapon, grip: .two, might: 2.0, reach: 12, cost: [("scrap_wood", 5), ("scrap_iron", 3), ("rat_fang", 2), ("orc_tusk", 1)], look: .spear, color: rgb(180, 186, 196),
             blurb: "站遠一點就能戳到。"),
        Gear(id: "bow", name: "弓箭", slot: .weapon, grip: .two, might: 1.6, reach: 42, cost: [("scrap_wood", 5), ("rat_tail", 3), ("rat_fang", 2), ("squirrel_tail", 2)], look: .bow, color: rgb(160, 110, 60),
             blurb: "鼠尾當弦，鼠牙當箭頭，可以從很遠的地方射。"),
        Gear(id: "core_staff", name: "核心法杖", slot: .weapon, might: 2.2, reach: 28, cost: [("slime_core", 2), ("slime_goo", 4), ("shiny_bead", 1), ("shiny_trinket", 1)], look: .staff, color: rgb(60, 160, 216),
             blurb: "史萊姆核心在杖頭發著藍光，會射出光球。很稀有。"),
        Gear(id: "night_dagger", name: "夜刃匕首", slot: .weapon, might: 1.9, speed: 0.04, cost: [("bat_fang", 4), ("night_dust", 1), ("scrap_iron", 3), ("black_feather", 3)], look: .dagger, color: rgb(150, 120, 200),
             blurb: "用蝙蝠牙磨的匕首，沾了夜光粉，揮起來很輕。"),
        // shields
        Gear(id: "wood_shield", name: "木盾", slot: .shield, block: 0.15, cost: [("scrap_wood", 6), ("rat_pelt", 1)], look: .woodShield, color: rgb(170, 120, 68),
             blurb: "幾片木板釘成的圓盾。"),
        Gear(id: "goo_shield", name: "黏液盾", slot: .shield, block: 0.25, cost: [("slime_goo", 6), ("elastic_gel", 2)], look: .roundShield, color: rgb(104, 208, 120),
             blurb: "凝膠把攻擊彈開。"),
        // head
        Gear(id: "cloth_cap", name: "布帽", slot: .head, health: 0.4, cost: [("scrap_rag", 3)], look: .cap, color: rgb(190, 90, 84),
             blurb: "碎布縫的小帽子。"),
        Gear(id: "leather_cap", name: "皮帽", slot: .head, health: 0.7, cost: [("rat_pelt", 2), ("scrap_rag", 1)], look: .cap, color: rgb(160, 130, 100),
             blurb: "鼠皮做的帽子，有護耳。"),
        Gear(id: "iron_helm", name: "鐵盔", slot: .head, health: 1.1, cost: [("scrap_iron", 5), ("rat_pelt", 1)], look: .helm, color: rgb(170, 176, 190),
             blurb: "廢鐵敲成的頭盔，有點重。"),
        // chest
        Gear(id: "cloth_armor", name: "布甲", slot: .chest, health: 0.9, cost: [("scrap_rag", 6)], look: .tunic, color: rgb(214, 196, 150),
             blurb: "厚厚縫了好幾層的布衣。"),
        Gear(id: "leather_armor", name: "皮甲", slot: .chest, health: 1.5, cost: [("rat_pelt", 5), ("scrap_rag", 2)], look: .tunic, color: rgb(150, 104, 72),
             blurb: "鼠皮縫的皮甲，輕又耐咬。"),
        Gear(id: "iron_plate", name: "鐵甲", slot: .chest, health: 2.2, speed: -0.04, cost: [("scrap_iron", 10), ("rat_pelt", 2), ("leather_strap", 2)], look: .plate, color: rgb(150, 156, 172),
             blurb: "廢鐵拼成的胸甲，很硬但有點重。"),
        Gear(id: "gold_cloak", name: "金毛披風", slot: .chest, health: 2, cost: [("golden_fur", 1), ("rat_pelt", 4), ("rat_tail", 2)], look: .cloak, color: rgb(240, 192, 64),
             blurb: "閃著金光的披風。很稀有。"),
        Gear(id: "bat_cloak", name: "蝙蝠翼披風", slot: .chest, health: 1.7, speed: 0.03, cost: [("bat_wing", 5), ("rat_pelt", 2), ("scrap_rag", 2)], look: .cloak, color: rgb(90, 70, 130),
             blurb: "薄薄的蝙蝠翼縫成的披風，走路輕飄飄的。"),
        // legs
        Gear(id: "cloth_pants", name: "布褲", slot: .legs, health: 0.4, cost: [("scrap_rag", 4)], look: .pants, color: rgb(120, 130, 170),
             blurb: "碎布縫的褲子。"),
        Gear(id: "leather_pants", name: "皮褲", slot: .legs, health: 0.8, cost: [("rat_pelt", 3), ("scrap_rag", 1)], look: .pants, color: rgb(140, 98, 66),
             blurb: "鼠皮褲，跑起來不會被草割到。"),
        // feet
        Gear(id: "cloth_shoes", name: "布鞋", slot: .feet, speed: 0.05, cost: [("scrap_rag", 3)], look: .boots, color: rgb(230, 224, 200),
             blurb: "軟軟的布鞋，走得輕快。"),
        Gear(id: "leather_boots", name: "皮靴", slot: .feet, health: 0.3, speed: 0.08, cost: [("rat_pelt", 3), ("rat_tail", 1)], look: .boots, color: rgb(120, 82, 54),
             blurb: "鼠皮做的靴子，又快又耐穿。"),
        // hands
        Gear(id: "frog_boots", name: "蛙皮靴", slot: .feet, health: 0.3, speed: 0.12, cost: [("frog_skin", 3), ("frog_leg", 1)], look: .boots, color: rgb(96, 168, 86),
             blurb: "滑滑的蛙皮做的靴子，跳起來特別快。"),
        Gear(id: "pelt_wraps", name: "鼠皮護腕", slot: .hands, health: 0.5, cost: [("rat_pelt", 3), ("rat_fang", 1)], look: .gloves, color: rgb(160, 140, 122),
             blurb: "軟軟的皮護腕，不太好看但很耐咬。"),
        Gear(id: "iron_gauntlets", name: "鐵手甲", slot: .hands, might: 0.4, health: 0.4, cost: [("scrap_iron", 4), ("rat_pelt", 1)], look: .gauntlet, color: rgb(168, 174, 190),
             blurb: "打起來更痛，擋起來也更穩。"),
        // made from what the big world's foes drop (shared/src/world/drops.ts); shared/src/camp/gear.ts has the same list
        Gear(id: "wolf_fang_spear", name: "狼牙槍", slot: .weapon, grip: .two, might: 2.3, reach: 12, cost: [("wolf_fang", 4), ("scrap_wood", 4), ("leather_strap", 1)], look: .spear, color: rgb(214, 208, 190),
             blurb: "槍頭綁著一排狼牙，戳進去就不放。"),
        Gear(id: "venom_dagger", name: "毒牙匕首", slot: .weapon, might: 2.2, speed: 0.03, cost: [("venom_sac", 2), ("bat_fang", 2), ("scrap_iron", 2)], look: .dagger, color: rgb(140, 200, 70),
             blurb: "刀刃泡過蜘蛛的毒囊，綠綠的。"),
        Gear(id: "silk_bow", name: "蛛絲弓", slot: .weapon, grip: .two, might: 2.0, reach: 46, cost: [("spider_silk", 4), ("scrap_wood", 5), ("feather", 3)], look: .bow, color: rgb(230, 230, 240),
             blurb: "蜘蛛絲當弦，又韌又遠，箭尾插著野蠻人的羽毛。"),
        Gear(id: "heartwood_staff", name: "樹心法杖", slot: .weapon, might: 2.8, reach: 30, cost: [("heartwood", 1), ("ancient_bark", 3), ("amber", 1)], look: .staff, color: rgb(200, 144, 64),
             blurb: "古樹的樹心削成的杖，頂上嵌著琥珀。很稀有。"),
        Gear(id: "troll_greatsword", name: "巨魔牙大劍", slot: .weapon, grip: .two, might: 3.4, cost: [("troll_tooth", 2), ("scrap_iron", 8), ("troll_hide", 1)], look: .greatSword, color: rgb(224, 216, 160),
             blurb: "劍刃鑲著巨魔的大牙，重得要兩手才揮得動。"),
        Gear(id: "cursed_blade", name: "詛咒之劍", slot: .weapon, might: 3.0, cost: [("cursed_steel", 3), ("bone_shard", 4), ("ectoplasm", 1)], look: .longSword, color: rgb(110, 80, 140),
             blurb: "骸骨騎士的鋼打成的劍，冒著淡淡的紫煙。"),
        Gear(id: "knife_pair", name: "飛刀雙刃", slot: .weapon, grip: .two, might: 2.4, speed: 0.04, cost: [("throwing_knife", 4), ("leather_strap", 2)], look: .twinBlades, color: rgb(184, 192, 200),
             blurb: "盜賊的飛刀改成兩把短刃，出手很快。"),
        Gear(id: "crab_shield", name: "蟹殼盾", slot: .shield, block: 0.3, cost: [("crab_shell", 3), ("crab_claw", 1)], look: .roundShield, color: rgb(216, 96, 58),
             blurb: "整片蟹殼當盾，邊上還留著一隻螯。"),
        Gear(id: "kappa_shield", name: "河童甲盾", slot: .shield, block: 0.28, cost: [("kappa_shell", 2), ("snake_scale", 2)], look: .roundShield, color: rgb(74, 138, 90),
             blurb: "河童的背甲，濕濕的，攻擊會滑開。"),
        Gear(id: "gargoyle_shield", name: "石像盾", slot: .shield, block: 0.38, speed: -0.03, cost: [("gargoyle_stone", 4), ("scrap_iron", 3)], look: .woodShield, color: rgb(106, 106, 120),
             blurb: "石像鬼身上敲下來的石板，很重，但什麼都擋得住。"),
        Gear(id: "alpha_helm", name: "狼王頭盔", slot: .head, might: 0.2, health: 1.3, cost: [("alpha_mane", 1), ("wolf_pelt", 2), ("scrap_iron", 2)], look: .helm, color: rgb(192, 200, 216),
             blurb: "頭盔上披著狼王的銀色鬃毛，戴上去很有氣勢。"),
        Gear(id: "mushroom_hat", name: "蘑菇帽", slot: .head, health: 0.9, cost: [("mushroom_cap", 3), ("glow_spore", 1)], look: .cap, color: rgb(216, 90, 74),
             blurb: "紅底白點的大蘑菇傘，晚上會微微發光。"),
        Gear(id: "rat_crown_hat", name: "鼠王冠", slot: .head, might: 0.3, health: 0.6, cost: [("rat_crown", 1), ("golden_fur", 1)], look: .cap, color: rgb(216, 176, 64),
             blurb: "從鼠王頭上搶來的小王冠，戴歪歪的。"),
        Gear(id: "wolf_cloak", name: "狼皮披風", slot: .chest, health: 1.9, speed: 0.03, cost: [("wolf_pelt", 4), ("leather_strap", 1)], look: .cloak, color: rgb(138, 138, 146),
             blurb: "灰色的狼皮披風，跑起來像一匹狼。"),
        Gear(id: "bear_armor", name: "熊皮甲", slot: .chest, health: 2.6, cost: [("bear_pelt", 3), ("leather_strap", 2)], look: .tunic, color: rgb(106, 74, 42),
             blurb: "厚厚的熊皮，冬天穿也不冷。"),
        Gear(id: "bark_armor", name: "古樹皮甲", slot: .chest, health: 2.8, speed: -0.03, cost: [("ancient_bark", 5), ("amber", 1)], look: .plate, color: rgb(106, 80, 48),
             blurb: "古樹的皮一片片疊起來，比鐵還硬。"),
        Gear(id: "silk_robe", name: "女王絲袍", slot: .chest, health: 2.0, speed: 0.05, cost: [("queen_silk", 2), ("spider_silk", 4)], look: .cloak, color: rgb(224, 208, 255),
             blurb: "蜘蛛女王的絲織成的袍子，輕得像沒穿。很稀有。"),
        Gear(id: "troll_armor", name: "巨魔皮甲", slot: .chest, health: 3.2, speed: -0.04, cost: [("troll_hide", 3), ("leather_strap", 2)], look: .tunic, color: rgb(90, 122, 74),
             blurb: "巨魔的皮又厚又臭，但砍不太進去。"),
        Gear(id: "boar_leggings", name: "野豬皮褲", slot: .legs, health: 1.0, cost: [("boar_hide", 3), ("leather_strap", 1)], look: .pants, color: rgb(154, 106, 74),
             blurb: "粗粗的野豬皮褲，跪在石頭上也不痛。"),
        Gear(id: "scale_pants", name: "蛇鱗褲", slot: .legs, health: 1.1, speed: 0.02, cost: [("snake_scale", 4), ("scrap_rag", 2)], look: .pants, color: rgb(58, 154, 138),
             blurb: "一片片蛇鱗縫上去，會閃青光。"),
        Gear(id: "tusk_boots", name: "獠牙靴", slot: .feet, health: 0.5, speed: 0.09, cost: [("boar_tusk", 2), ("boar_hide", 2)], look: .boots, color: rgb(240, 224, 192),
             blurb: "靴尖套著野豬獠牙，踢起來很痛。"),
        Gear(id: "naiad_slippers", name: "水妖鞋", slot: .feet, speed: 0.15, cost: [("naiad_tear", 1), ("frog_skin", 2)], look: .boots, color: rgb(106, 208, 255),
             blurb: "沾了水妖之淚的鞋，走起路來像在滑。"),
        Gear(id: "bear_claws", name: "熊爪拳套", slot: .hands, might: 0.8, health: 0.3, cost: [("bear_claw", 2), ("bear_pelt", 1)], look: .gauntlet, color: rgb(58, 58, 58),
             blurb: "戴上熊爪，一抓就是三道。"),
        Gear(id: "golem_gauntlets", name: "巨人拳甲", slot: .hands, might: 0.9, health: 0.6, speed: -0.02, cost: [("golem_core", 1), ("gargoyle_stone", 2), ("scrap_iron", 3)], look: .gauntlet, color: rgb(64, 224, 240),
             blurb: "石像巨人的核心在手背上發著藍光。很稀有。"),
        // for beginners: from the small monsters of the world's first lairs (shared/src/world/drops.ts)
        Gear(id: "slingshot", name: "橡實彈弓", slot: .weapon, grip: .two, might: 1.4, reach: 30, cost: [("acorn", 5), ("scrap_wood", 2)], look: .bow, color: rgb(168, 112, 58),
             blurb: "樹枝綁上皮筋，彈出去的是橡實。新手的第一把遠程武器。"),
        Gear(id: "rabbit_cap", name: "兔毛帽", slot: .head, health: 0.8, cost: [("rabbit_fur", 3)], look: .cap, color: rgb(240, 232, 224),
             blurb: "軟綿綿的兔毛帽，還有兩隻耳朵。"),
        Gear(id: "fox_cap", name: "狐尾帽", slot: .head, health: 0.9, speed: 0.03, cost: [("fox_tail", 1), ("rabbit_fur", 2)], look: .cap, color: rgb(232, 128, 58),
             blurb: "後面垂著一條狐狸尾巴，跑起來一甩一甩。"),
        Gear(id: "snail_shield", name: "蝸牛殼盾", slot: .shield, block: 0.2, cost: [("snail_shell", 3)], look: .roundShield, color: rgb(200, 154, 106),
             blurb: "一整個蝸牛殼當盾，圓圓的很好擋。"),
        Gear(id: "beetle_armor", name: "甲蟲甲", slot: .chest, health: 1.8, cost: [("beetle_shell", 4), ("silk_thread", 1)], look: .plate, color: rgb(58, 90, 138),
             blurb: "甲蟲殼用絲線串起來，亮亮的藍色。"),
        Gear(id: "feather_cloak", name: "黑羽披風", slot: .chest, health: 1.3, speed: 0.05, cost: [("black_feather", 5), ("silk_thread", 1)], look: .cloak, color: rgb(42, 42, 58),
             blurb: "烏鴉的黑羽毛縫成的披風，走路輕飄飄。"),
        Gear(id: "spine_gloves", name: "刺蝟手套", slot: .hands, might: 0.5, health: 0.3, cost: [("hedgehog_spine", 3), ("rabbit_fur", 1)], look: .gloves, color: rgb(138, 112, 96),
             blurb: "手套外面插滿刺蝟刺，一拳下去很痛。"),
        Gear(id: "goose_boots", name: "鵝毛鞋", slot: .feet, health: 0.2, speed: 0.1, cost: [("goose_feather", 3), ("scrap_rag", 1)], look: .boots, color: rgb(248, 248, 248),
             blurb: "鞋裡塞滿鵝毛，走起來又輕又暖。"),
        // made from what the first lairs drop that nothing else used (BALANCE.md §5)
        Gear(id: "tusk_axe", name: "獠牙戰斧", slot: .weapon, grip: .two, might: 2.4, cost: [("orc_tusk", 3), ("scrap_wood", 2), ("leather_strap", 1)], look: .greatSword, color: rgb(190, 170, 140),
             blurb: "強獸人的獠牙綁在木柄上，一斧下去很重。"),
        Gear(id: "stinger_rapier", name: "蜂針細劍", slot: .weapon, might: 1.8, speed: 0.03, cost: [("bee_stinger", 4), ("scrap_iron", 2)], look: .shortSword, color: rgb(60, 60, 60),
             blurb: "殺人蜂的針磨成的細劍，刺得又快又準。"),
        Gear(id: "coin_mail", name: "銅錢甲", slot: .chest, health: 2.0, cost: [("stolen_coin", 6), ("leather_strap", 1)], look: .plate, color: rgb(184, 134, 72),
             blurb: "強盜的贓物銅幣一枚枚串成的甲，走路叮噹響。"),
        Gear(id: "horn_helm", name: "獨角仙盔", slot: .head, might: 0.2, health: 1.2, cost: [("beetle_horn", 1), ("beetle_shell", 2)], look: .helm, color: rgb(70, 50, 40),
             blurb: "頭上頂著獨角仙的角，撞過去很痛。"),
        Gear(id: "squirrel_hat", name: "松鼠尾帽", slot: .head, health: 0.8, speed: 0.04, cost: [("squirrel_tail", 2), ("scrap_rag", 1)], look: .cap, color: rgb(196, 120, 60),
             blurb: "蓬蓬的松鼠尾巴垂在後腦勺。"),
        Gear(id: "pearl_shield", name: "珍珠貝盾", slot: .shield, block: 0.22, cost: [("river_pearl", 1), ("snail_shell", 2)], look: .roundShield, color: rgb(230, 236, 244),
             blurb: "蝸牛殼上鑲著河珍珠，閃閃發亮。"),
        Gear(id: "lucky_boots", name: "兔腳靴", slot: .feet, health: 0.2, speed: 0.12, cost: [("rabbit_foot", 1), ("rabbit_fur", 2)], look: .boots, color: rgb(236, 226, 214),
             blurb: "靴子上掛著幸運兔腳，跑起來特別快。"),
        // legendary: from the world's great monsters (shared/src/world/bosses.ts)
        Gear(id: "dragon_scale_armor", name: "龍鱗甲", slot: .chest, health: 4.0, cost: [("dragon_scale", 4), ("leather_strap", 2)], look: .plate, color: rgb(200, 58, 42),
             blurb: "世界魔王古龍的鱗片一片片釘起來，火燒不穿。傳說級。"),
        Gear(id: "lich_staff", name: "巫妖法杖", slot: .weapon, might: 3.6, reach: 34, cost: [("soul_gem", 2), ("cursed_steel", 2)], look: .staff, color: rgb(138, 90, 255),
             blurb: "杖頭的靈魂寶石閃著紫光，會射出靈魂之火。傳說級。"),
        Gear(id: "giant_hammer", name: "巨人戰鎚", slot: .weapon, grip: .two, might: 4.2, speed: -0.05, cost: [("giant_bone", 3), ("scrap_iron", 6)], look: .greatSword, color: rgb(224, 216, 192),
             blurb: "山丘巨人的骨頭做的大鎚，要兩手才舉得起來。傳說級。"),
        Gear(id: "hydra_bow", name: "九頭蛇弓", slot: .weapon, grip: .two, might: 2.8, reach: 50, cost: [("hydra_fang", 2), ("spider_silk", 3), ("scrap_wood", 4)], look: .bow, color: rgb(154, 240, 106),
             blurb: "箭頭是九頭蛇的毒牙，射得比什麼都遠。傳說級。"),
        Gear(id: "minotaur_helm", name: "牛角盔", slot: .head, might: 0.4, health: 1.8, cost: [("minotaur_horn", 2), ("scrap_iron", 3)], look: .helm, color: rgb(160, 120, 80),
             blurb: "頂著一對大牛角的頭盔，衝過去誰都怕。傳說級。"),
    ]

    /// Wear before breaking, where it differs from the default (120 for a weapon, 20 for the rest). Cloth wears out fastest, iron lasts longest.
    static let durabilities: [String: Double] = [
        "bone_knife": 120, "short_sword": 160, "claw_dagger": 150, "long_sword": 200, "twin_blades": 180, "great_sword": 240,
        "spear": 160, "bow": 140, "core_staff": 260,
        "wood_shield": 18, "goo_shield": 24,
        "cloth_cap": 10, "leather_cap": 16, "iron_helm": 30, "cloth_armor": 12, "leather_armor": 20, "iron_plate": 36, "gold_cloak": 30,
        "cloth_pants": 10, "leather_pants": 16, "cloth_shoes": 10, "leather_boots": 16, "pelt_wraps": 14, "iron_gauntlets": 26,
        "wolf_fang_spear": 170, "venom_dagger": 140, "silk_bow": 170, "heartwood_staff": 300, "troll_greatsword": 260, "cursed_blade": 220, "knife_pair": 170, "crab_shield": 30, "kappa_shield": 28, "gargoyle_shield": 40, "alpha_helm": 28, "mushroom_hat": 18, "rat_crown_hat": 24, "wolf_cloak": 24, "bear_armor": 32, "bark_armor": 40, "silk_robe": 22, "troll_armor": 44, "boar_leggings": 20, "scale_pants": 22, "tusk_boots": 20, "naiad_slippers": 18, "bear_claws": 30, "golem_gauntlets": 40,
        "tusk_axe": 180, "stinger_rapier": 130, "coin_mail": 30, "horn_helm": 26, "squirrel_hat": 16, "pearl_shield": 24, "lucky_boots": 18,
        "slingshot": 100, "rabbit_cap": 14, "fox_cap": 18, "snail_shield": 20, "beetle_armor": 24, "feather_cloak": 18, "spine_gloves": 16, "goose_boots": 14,
        "dragon_scale_armor": 60, "lich_staff": 320, "giant_hammer": 300, "hydra_bow": 220, "minotaur_helm": 40,
    ]

    /// Pieces that cannot be made yet: something they need comes only from big-world places not open yet (or the great
    /// monsters, while they are away). The same as shared/src/world/availability.ts `unopenedGear()` (mac-sync.test.ts checks).
    static let unopened: Set<String> = [
        "venom_dagger", "silk_bow", "heartwood_staff", "troll_greatsword", "cursed_blade", "knife_pair", "crab_shield", "kappa_shield", "gargoyle_shield", "bear_armor", "bark_armor", "silk_robe", "troll_armor", "naiad_slippers", "bear_claws", "golem_gauntlets", "dragon_scale_armor", "lich_staff", "giant_hammer", "hydra_bow", "minotaur_helm",
    ]

    static func by(id: String) -> Gear? { byID[id] }
    private static let byID = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
}
