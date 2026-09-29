import AppKit

/// How often a material drops: the drop chance decides it, so a new monster needs no extra bookkeeping.
enum Rarity: Int, Comparable {
    case common, uncommon, rare

    static func < (a: Rarity, b: Rarity) -> Bool { a.rawValue < b.rawValue }

    init(chance: Double) { self = chance >= 0.5 ? .common : chance >= 0.15 ? .uncommon : .rare }

    var label: String { self == .common ? "普通" : self == .uncommon ? "少見" : "稀有" }

    var color: NSColor {
        switch self {
        case .common: return NSColor(calibratedWhite: 0.55, alpha: 1)
        case .uncommon: return NSColor(calibratedRed: 0.20, green: 0.55, blue: 0.85, alpha: 1)
        case .rare: return NSColor(calibratedRed: 0.72, green: 0.35, blue: 0.85, alpha: 1)
        }
    }
}

/// One thing a monster may leave behind, with the chance that it does and how many.
struct DropSpec: Decodable {
    let id: String
    let name: String
    /// 0...1
    let chance: Double
    let min: Int
    let max: Int
    /// `#rrggbb`, the colour of the little gem on the ground.
    let color: String?

    var rarity: Rarity { Rarity(chance: chance) }
}

/// What the camp has learnt about a material (from the monsters that drop it).
struct MaterialInfo {
    let id: String
    let name: String
    let rarity: Rarity
    let color: NSColor
    /// The monster it comes from.
    let source: String
}

enum Materials {
    /// Odds and ends every monster may leave besides its own drops: the plain stuff for cloth, wood and iron gear.
    static let scraps: [DropSpec] = [
        DropSpec(id: "scrap_rag", name: "碎布", chance: 0.55, min: 1, max: 2, color: "#d8c8a8"),
        DropSpec(id: "scrap_wood", name: "木片", chance: 0.50, min: 1, max: 3, color: "#a8743c"),
        DropSpec(id: "scrap_iron", name: "廢鐵", chance: 0.45, min: 1, max: 2, color: "#8a929e"),
    ]

    /// Rare things the goblins turn up while working: a sliver of crystal in a rock.
    static let finds: [DropSpec] = [
        DropSpec(id: "crystal_shard", name: "碎晶", chance: 0.04, min: 1, max: 1, color: "#6ad8f0"),
    ]

    /// What the camp fells and digs by itself, by the hour (the server works it out: shared/src/camp/production.ts).
    static let made: [DropSpec] = [
        DropSpec(id: "log", name: "木材", chance: 1, min: 1, max: 1, color: "#8a5a2c"),
        DropSpec(id: "stone", name: "石頭", chance: 1, min: 1, max: 1, color: "#9a9a92"),
    ]

    /// What the big world's foes leave (the server fights there and adds them to the books; shared/src/world/drops.ts has the
    /// same names). The chance is the plainest foe's, for the rarity shown.
    static let world: [DropSpec] = [
        DropSpec(id: "wolf_pelt", name: "狼皮", chance: 0.6, min: 1, max: 1, color: "#8a8a92"), // 野狼
        DropSpec(id: "wolf_fang", name: "狼牙", chance: 0.5, min: 1, max: 1, color: "#f0ece0"), // 野狼
        DropSpec(id: "alpha_mane", name: "狼王鬃毛", chance: 0.5, min: 1, max: 1, color: "#c0c8d8"), // 狼王
        DropSpec(id: "bear_pelt", name: "熊皮", chance: 1, min: 1, max: 1, color: "#6a4a2a"), // 洞穴熊
        DropSpec(id: "bear_claw", name: "熊爪", chance: 0.8, min: 1, max: 1, color: "#3a3a3a"), // 洞穴熊
        DropSpec(id: "boar_tusk", name: "野豬獠牙", chance: 0.45, min: 1, max: 1, color: "#f0e0c0"), // 野豬
        DropSpec(id: "boar_hide", name: "野豬皮", chance: 0.6, min: 1, max: 1, color: "#9a6a4a"), // 野豬
        DropSpec(id: "war_paint", name: "戰紋顏料", chance: 0.35, min: 1, max: 1, color: "#c83a2a"), // 野蠻人
        DropSpec(id: "feather", name: "羽毛", chance: 0.3, min: 1, max: 1, color: "#e8e8f0"), // 薩滿
        DropSpec(id: "shaman_charm", name: "薩滿護符", chance: 0.4, min: 1, max: 1, color: "#3ac8a8"), // 薩滿
        DropSpec(id: "bone_shard", name: "碎骨", chance: 0.7, min: 1, max: 1, color: "#e8e0c8"), // 骷髏兵
        DropSpec(id: "ectoplasm", name: "靈質", chance: 0.55, min: 1, max: 1, color: "#9af0e0"), // 怨靈
        DropSpec(id: "cursed_steel", name: "詛咒鋼", chance: 0.5, min: 1, max: 1, color: "#4a3a5a"), // 骸骨騎士
        DropSpec(id: "troll_hide", name: "巨魔皮", chance: 1, min: 1, max: 1, color: "#5a7a4a"), // 巨魔
        DropSpec(id: "troll_tooth", name: "巨魔牙", chance: 0.5, min: 1, max: 1, color: "#e0d8a0"), // 巨魔
        DropSpec(id: "guard_plate", name: "鐵甲片", chance: 0.45, min: 1, max: 1, color: "#a0a8b0"), // 城鎮守衛
        DropSpec(id: "steel_bolt", name: "鋼弩箭", chance: 0.6, min: 1, max: 1, color: "#707880"), // 弩手
        DropSpec(id: "captain_badge", name: "隊長徽章", chance: 0.25, min: 1, max: 1, color: "#e0b030"), // 盜賊頭目
        DropSpec(id: "spider_silk", name: "蜘蛛絲", chance: 0.65, min: 1, max: 1, color: "#f4f4f8"), // 巨蜘蛛
        DropSpec(id: "venom_sac", name: "毒囊", chance: 0.25, min: 1, max: 1, color: "#8ad040"), // 巨蜘蛛
        DropSpec(id: "queen_silk", name: "女王絲", chance: 0.7, min: 1, max: 1, color: "#e0d0ff"), // 蜘蛛女王
        DropSpec(id: "ancient_bark", name: "古樹皮", chance: 1, min: 1, max: 1, color: "#6a5030"), // 樹精
        DropSpec(id: "amber", name: "琥珀", chance: 0.35, min: 1, max: 1, color: "#f0a020"), // 樹精
        DropSpec(id: "ration_bread", name: "乾糧麵包", chance: 1, min: 1, max: 1, color: "#d9a55b"), // 出征的糧食（大世界）
        DropSpec(id: "ration_fish", name: "魚乾", chance: 1, min: 1, max: 1, color: "#9fb6c4"), // 出征的糧食（大世界）
        DropSpec(id: "ration_berry", name: "莓果乾", chance: 1, min: 1, max: 1, color: "#b0426a"), // 出征的糧食（大世界）
        DropSpec(id: "ration_jerky", name: "肉乾", chance: 1, min: 1, max: 1, color: "#8c4a2f"), // 出征的糧食（大世界）
        DropSpec(id: "food_meat", name: "烤肉", chance: 1, min: 1, max: 1, color: "#b5542f"), // 出征的糧食（大世界）
        DropSpec(id: "food_cheese", name: "起司", chance: 1, min: 1, max: 1, color: "#f2cf52"), // 出征的糧食（大世界）
        DropSpec(id: "food_carrot", name: "胡蘿蔔", chance: 1, min: 1, max: 1, color: "#ec8a2e"), // 出征的糧食（大世界）
        DropSpec(id: "food_honey", name: "蜂蜜", chance: 1, min: 1, max: 1, color: "#e8b43c"), // 出征的糧食（大世界）
        DropSpec(id: "heartwood", name: "樹心", chance: 0.12, min: 1, max: 1, color: "#c89040"), // 樹精
        DropSpec(id: "mushroom_cap", name: "蘑菇傘", chance: 0.6, min: 1, max: 1, color: "#d85a4a"), // 蘑菇人
        DropSpec(id: "glow_spore", name: "螢光孢子", chance: 0.7, min: 1, max: 1, color: "#b0f070"), // 孢子母
        DropSpec(id: "kappa_shell", name: "河童甲", chance: 0.45, min: 1, max: 1, color: "#4a8a5a"), // 河童
        DropSpec(id: "river_pearl", name: "河珍珠", chance: 0.06, min: 1, max: 1, color: "#f0f0ff"), // 河童
        DropSpec(id: "snake_scale", name: "蛇鱗", chance: 0.6, min: 1, max: 1, color: "#3a9a8a"), // 水蛇
        DropSpec(id: "naiad_tear", name: "水妖之淚", chance: 0.4, min: 1, max: 1, color: "#6ad0ff"), // 水妖
        DropSpec(id: "crab_shell", name: "蟹殼", chance: 0.8, min: 1, max: 1, color: "#d8603a"), // 巨蟹
        DropSpec(id: "crab_claw", name: "蟹螯", chance: 0.5, min: 1, max: 1, color: "#e87a4a"), // 巨蟹
        DropSpec(id: "rat_crown", name: "鼠王冠", chance: 0.4, min: 1, max: 1, color: "#d8b040"), // 鼠王
        DropSpec(id: "stolen_coin", name: "贓物銅幣", chance: 0.5, min: 1, max: 1, color: "#c89a3a"), // 攔路強盜
        DropSpec(id: "leather_strap", name: "皮帶", chance: 0.3, min: 1, max: 1, color: "#7a5030"), // 攔路強盜
        DropSpec(id: "throwing_knife", name: "飛刀", chance: 0.55, min: 1, max: 1, color: "#b8c0c8"), // 飛刀手
        DropSpec(id: "gargoyle_stone", name: "石像鬼石", chance: 0.6, min: 1, max: 1, color: "#6a6a78"), // 石像鬼
        DropSpec(id: "bee_stinger", name: "蜂針", chance: 0.4, min: 1, max: 1, color: "#2a2a2a"), // 殺人蜂
        DropSpec(id: "beeswax", name: "蜂蠟", chance: 0.25, min: 1, max: 1, color: "#f0d070"), // 殺人蜂
        DropSpec(id: "royal_jelly", name: "蜂王乳", chance: 0.8, min: 1, max: 1, color: "#fff0b0"), // 蜂后
        DropSpec(id: "golem_core", name: "巨人核心", chance: 0.6, min: 1, max: 1, color: "#40e0f0"), // 石像巨人
        DropSpec(id: "vampire_fang", name: "吸血牙", chance: 0.4, min: 1, max: 1, color: "#c82a3a"), // 吸血蝙蝠
        DropSpec(id: "rabbit_fur", name: "兔毛", chance: 0.2, min: 1, max: 1, color: "#f0e8e0"), // 狐狸
        DropSpec(id: "rabbit_foot", name: "幸運兔腳", chance: 0.05, min: 1, max: 1, color: "#f8d0d8"), // 野兔
        DropSpec(id: "snail_shell", name: "蝸牛殼", chance: 0.55, min: 1, max: 1, color: "#c89a6a"), // 蝸牛
        DropSpec(id: "silk_thread", name: "絲線", chance: 0.5, min: 1, max: 1, color: "#f4f0d8"), // 毛毛蟲
        DropSpec(id: "beetle_shell", name: "甲蟲殼", chance: 0.5, min: 1, max: 1, color: "#3a5a8a"), // 甲蟲
        DropSpec(id: "beetle_horn", name: "獨角仙角", chance: 0.08, min: 1, max: 1, color: "#6a3a2a"), // 甲蟲
        DropSpec(id: "black_feather", name: "黑羽毛", chance: 0.6, min: 1, max: 1, color: "#2a2a3a"), // 烏鴉
        DropSpec(id: "shiny_trinket", name: "亮晶晶的小東西", chance: 0.08, min: 1, max: 1, color: "#f0e070"), // 烏鴉
        DropSpec(id: "acorn", name: "橡實", chance: 0.7, min: 1, max: 1, color: "#a8703a"), // 松鼠
        DropSpec(id: "squirrel_tail", name: "松鼠尾巴", chance: 0.2, min: 1, max: 1, color: "#c8784a"), // 松鼠
        DropSpec(id: "hedgehog_spine", name: "刺蝟刺", chance: 0.55, min: 1, max: 1, color: "#8a7060"), // 刺蝟
        DropSpec(id: "goose_feather", name: "鵝毛", chance: 0.6, min: 1, max: 1, color: "#f8f8f8"), // 野鵝
        DropSpec(id: "fox_tail", name: "狐狸尾巴", chance: 0.35, min: 1, max: 1, color: "#e8803a"), // 狐狸
        DropSpec(id: "orc_tusk", name: "強獸人獠牙", chance: 0.25, min: 1, max: 1, color: "#e8e0c0"), // 強獸人弓手
        DropSpec(id: "crude_blade", name: "粗鐵刀刃", chance: 0.3, min: 1, max: 1, color: "#7a7a80"), // 強獸人步兵
        DropSpec(id: "war_banner", name: "軍團旗幟", chance: 0.5, min: 1, max: 1, color: "#a02a2a"), // 強獸人隊長
        DropSpec(id: "dragon_scale", name: "龍鱗", chance: 0.3, min: 1, max: 1, color: "#c83a2a"), // 小飛龍
        DropSpec(id: "dragon_heart", name: "龍心", chance: 0.25, min: 1, max: 1, color: "#ff5a3a"), // 古龍
        DropSpec(id: "soul_gem", name: "靈魂寶石", chance: 0.8, min: 1, max: 1, color: "#8a5aff"), // 巫妖王
        DropSpec(id: "lich_crown", name: "巫妖冠", chance: 0.2, min: 1, max: 1, color: "#5a3a8a"), // 巫妖王
        DropSpec(id: "giant_bone", name: "巨人骨", chance: 1, min: 1, max: 1, color: "#e0d8c0"), // 山丘巨人
        DropSpec(id: "giant_heart", name: "巨人之心", chance: 0.2, min: 1, max: 1, color: "#c8a060"), // 山丘巨人
        DropSpec(id: "hydra_fang", name: "九頭蛇牙", chance: 1, min: 1, max: 1, color: "#9af06a"), // 九頭蛇
        DropSpec(id: "hydra_blood", name: "九頭蛇血", chance: 0.3, min: 1, max: 1, color: "#3ac84a"), // 九頭蛇
        DropSpec(id: "minotaur_horn", name: "牛頭人角", chance: 1, min: 1, max: 1, color: "#a07850"), // 牛頭人
        DropSpec(id: "labyrinth_key", name: "迷宮鑰匙", chance: 0.2, min: 1, max: 1, color: "#e0c040"), // 牛頭人
    ]

    /// Every material any loaded monster can drop.
    static let all: [MaterialInfo] = {
        var seen = Set<String>()
        var result: [MaterialInfo] = scraps.map { MaterialInfo(id: $0.id, name: $0.name, rarity: $0.rarity, color: color($0.color, rarity: $0.rarity), source: "各種魔獸") }
        seen.formUnion(scraps.map(\.id))
        for m in made { result.append(MaterialInfo(id: m.id, name: m.name, rarity: m.rarity, color: color(m.color, rarity: m.rarity), source: "營地生產")); seen.insert(m.id) }
        for find in finds { result.append(MaterialInfo(id: find.id, name: find.name, rarity: find.rarity, color: color(find.color, rarity: find.rarity), source: "採礦")); seen.insert(find.id) }
        for drop in world { result.append(MaterialInfo(id: drop.id, name: drop.name, rarity: drop.rarity, color: color(drop.color, rarity: drop.rarity), source: "大世界")); seen.insert(drop.id) }
        for kind in Animals.all where kind.hostile {
            for drop in kind.monster.drops where seen.insert(drop.id).inserted {
                result.append(MaterialInfo(id: drop.id, name: drop.name, rarity: drop.rarity, color: color(drop.color, rarity: drop.rarity), source: kind.name))
            }
        }
        return result
    }()

    private static let byID: [String: MaterialInfo] = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })

    static func info(_ id: String) -> MaterialInfo? { byID[id] }

    static func color(_ hex: String?, rarity: Rarity) -> NSColor {
        guard let hex, hex.count == 7, hex.hasPrefix("#"), let v = UInt32(hex.dropFirst(), radix: 16) else { return rarity.color }
        return NSColor(calibratedRed: CGFloat((v >> 16) & 255) / 255, green: CGFloat((v >> 8) & 255) / 255, blue: CGFloat(v & 255) / 255, alpha: 1)
    }

    /// Rolls what a monster leaves behind. `luck` scales every chance (a small slime dropping less, for instance).
    static func roll(_ drops: [DropSpec], luck: Double = 1) -> [(id: String, count: Int)] {
        drops.compactMap { drop in
            guard Double.random(in: 0..<1) < min(1, drop.chance * luck) else { return nil }
            return (drop.id, Int.random(in: drop.min...max(drop.min, drop.max)))
        }
    }
}
