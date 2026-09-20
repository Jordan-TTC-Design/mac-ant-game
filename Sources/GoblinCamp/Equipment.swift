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
        Gear(id: "long_sword", name: "長劍", slot: .weapon, might: 1.7, cost: [("scrap_iron", 6), ("rat_pelt", 2), ("scrap_wood", 1)], look: .longSword, color: rgb(206, 212, 224),
             blurb: "比短劍長一截，砍得更重。"),
        Gear(id: "crystal_blade", name: "晶刃", slot: .weapon, might: 2.5, cost: [("scrap_iron", 5), ("crystal_shard", 2), ("rat_pelt", 1)], look: .longSword, color: rgb(120, 218, 240),
             blurb: "劍身嵌著挖出來的碎晶，會發出淡淡的藍光。很稀有。"),
        Gear(id: "twin_blades", name: "雙刀", slot: .weapon, grip: .two, might: 2.1, cost: [("scrap_iron", 5), ("rat_fang", 4), ("rat_pelt", 2)], look: .twinBlades, color: rgb(196, 204, 216),
             blurb: "兩手各一把，出手快，沒有手拿盾。"),
        Gear(id: "great_sword", name: "雙手劍", slot: .weapon, grip: .two, might: 2.8, cost: [("scrap_iron", 9), ("rat_fang", 4), ("rat_pelt", 3)], look: .greatSword, color: rgb(214, 220, 232),
             blurb: "很重的大劍，要用雙手，一劍下去魔獸都抖一下。"),
        Gear(id: "spear", name: "長槍", slot: .weapon, grip: .two, might: 2.0, reach: 12, cost: [("scrap_wood", 5), ("scrap_iron", 3), ("rat_fang", 2)], look: .spear, color: rgb(180, 186, 196),
             blurb: "站遠一點就能戳到。"),
        Gear(id: "bow", name: "弓箭", slot: .weapon, grip: .two, might: 1.6, reach: 42, cost: [("scrap_wood", 5), ("rat_tail", 3), ("rat_fang", 2)], look: .bow, color: rgb(160, 110, 60),
             blurb: "鼠尾當弦，鼠牙當箭頭，可以從很遠的地方射。"),
        Gear(id: "core_staff", name: "核心法杖", slot: .weapon, might: 2.2, reach: 28, cost: [("slime_core", 2), ("slime_goo", 4), ("shiny_bead", 1)], look: .staff, color: rgb(60, 160, 216),
             blurb: "史萊姆核心在杖頭發著藍光，會射出光球。很稀有。"),
        Gear(id: "night_dagger", name: "夜刃匕首", slot: .weapon, might: 1.9, speed: 0.04, cost: [("bat_fang", 4), ("night_dust", 1), ("scrap_iron", 3)], look: .dagger, color: rgb(150, 120, 200),
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
        Gear(id: "iron_plate", name: "鐵甲", slot: .chest, health: 2.2, speed: -0.04, cost: [("scrap_iron", 10), ("rat_pelt", 2)], look: .plate, color: rgb(150, 156, 172),
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
    ]

    /// Wear before breaking, where it differs from the default (120 for a weapon, 20 for the rest). Cloth wears out fastest, iron lasts longest.
    static let durabilities: [String: Double] = [
        "bone_knife": 120, "short_sword": 160, "claw_dagger": 150, "long_sword": 200, "twin_blades": 180, "great_sword": 240,
        "spear": 160, "bow": 140, "core_staff": 260,
        "wood_shield": 18, "goo_shield": 24,
        "cloth_cap": 10, "leather_cap": 16, "iron_helm": 30, "cloth_armor": 12, "leather_armor": 20, "iron_plate": 36, "gold_cloak": 30,
        "cloth_pants": 10, "leather_pants": 16, "cloth_shoes": 10, "leather_boots": 16, "pelt_wraps": 14, "iron_gauntlets": 26,
    ]

    static func by(id: String) -> Gear? { byID[id] }
    private static let byID = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
}
