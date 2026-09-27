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

    /// Every material any loaded monster can drop.
    static let all: [MaterialInfo] = {
        var seen = Set<String>()
        var result: [MaterialInfo] = scraps.map { MaterialInfo(id: $0.id, name: $0.name, rarity: $0.rarity, color: color($0.color, rarity: $0.rarity), source: "各種魔獸") }
        seen.formUnion(scraps.map(\.id))
        for find in finds { result.append(MaterialInfo(id: find.id, name: find.name, rarity: find.rarity, color: color(find.color, rarity: find.rarity), source: "採礦")); seen.insert(find.id) }
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
