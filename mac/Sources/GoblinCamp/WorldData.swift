import AppKit
import CoreLocation

// The big world as the server tells it (shared/src/world/api.ts), the grid its cells are cut on (shared/src/world/grid.ts,
// the same sums), the names it shows (mac/Resources/World/names.json, written from the shared rules), and the store the
// Mac's own 大世界 page (WorldPane) reads from. The server fights, walks and keeps the books; the Mac only asks and shows.

struct WorldOwner: Decodable, Equatable {
    let id: String
    let name: String
    let race: String
    let level: Int?
}

struct WorldCell: Decodable {
    struct Lair: Decodable {
        let kind: String
        let name: String
        let level: Int
        let count: Int
        let foes: [String: Int]
        let power: Int
        let boss: Bool?
        let minRaceLevel: Int?
    }
    struct Boss: Decodable {
        let kind: String
        let name: String
        let hp: Int
        let maxHp: Int
        let endsAt: String
    }
    struct Building: Decodable {
        let kind: String
        let level: Int
        let busy: Bool
    }
    struct Wounds: Decodable {
        let standing: Int
        let total: Int
        let hpShare: Double
        let healedAt: String
    }
    struct Landmark: Decodable {
        let kind: String
        let name: String
    }
    struct Meteor: Decodable {
        let endsAt: String
        let loot: [String: Int]
    }
    let cell: String
    let lat: Double
    let lng: Double
    let terrain: String
    let detail: String?
    let hub: String?
    let owner: WorldOwner?
    let garrison: Int
    let nest: String
    let town: Bool
    let home: Bool?
    let landmark: Landmark?
    let guests: Int?
    let building: Building?
    let lair: Lair?
    let lairBackAt: String?
    let lairWounds: Wounds?
    let boss: Boss?
    let blocks: Bool?
    let threats: [String]?
    let meteor: Meteor?

    var coordinate: CLLocationCoordinate2D { CLLocationCoordinate2D(latitude: lat, longitude: lng) }
}

struct WorldExpedition: Decodable {
    struct Outcome: Decodable {
        struct Where: Decodable {
            let kind: String
            let label: String
            let landmark: String?
        }
        let won: Bool
        let cell: String
        let against: String
        let loot: [String: Int]
        let xp: Int
        let fallen: Int
        let killed: Int
        let damage: Int?
        let `where`: Where?
    }
    let id: String
    let kind: String
    let from: String
    let to: String
    let party: Int
    let setOutAt: String
    let arriveAt: String
    let route: [String]?
    let status: String
    let outcome: Outcome?
    let defending: Bool?
    let by: String?
}

struct WorldIncoming: Decodable {
    struct Where: Decodable {
        let kind: String
        let label: String
        let landmark: String?
    }
    let id: String
    let by: WorldOwner
    let from: String
    let to: String
    let `where`: Where
    let party: Int
    let setOutAt: String
    let arriveAt: String
    let route: [String]?
}

struct WorldMe: Decodable {
    struct Cell: Decodable {
        let cell: String
        let garrison: Int
        let nest: String
        let town: Bool
        let terrain: String
        let nextYieldAt: String
        let region: Int
        let regionTowns: Int
        let regionCentres: Int?
        let party: Int
        let travel: Double
        let capacity: Int
        let camping: Int
    }
    struct Guarding: Decodable {
        let cell: String
        let holder: String
        let count: Int
    }
    struct Upkeep: Decodable {
        let paying: Int
        let perYield: Int
        let everyHours: Int
        let rations: Int
    }
    struct Talents: Decodable {
        let picks: [String: Int]
        let points: Int
    }
    struct Season: Decodable {
        let name: String
        let icon: String
        let blurb: String
        let endsAt: String
    }
    struct Happening: Decodable {
        struct LairBack: Decodable {
            let name: String
            let level: Int
            let held: Bool
            let fallen: Int
            let loot: [String: Int]
        }
        struct BossReward: Decodable {
            let name: String
            let loot: [String: Int]
            let xp: Int
            let share: Double
        }
        let at: String
        let lairBack: LairBack?
        let bossReward: BossReward?
        let yields: [String: Int]?
    }
    struct BossNear: Decodable {
        let cell: String
        let name: String
        let lat: Double
        let lng: Double
        let km: Double
        let hp: Int
        let maxHp: Int
        let endsAt: String
    }
    struct Rules: Decodable {
        let garrisonMin: Int
        let cellCapacity: Int
        let nestCost: [String: Int]
        let nestHours: Int
        let nestBirthMinutes: Int
        let townCellsEach: Int
    }
    struct Point: Decodable {
        let lat: Double
        let lng: Double
    }
    let open: Bool
    let canOpen: Bool
    let unlockPeak: Int
    let peak: Int
    let shieldEndsAt: String?
    let homeCell: String?
    let home: Point?
    let homeMoveAt: String?
    let xp: Int
    let level: Int
    let nextLevelXp: Int
    let cells: [Cell]
    let atHome: Int
    let guarding: [Guarding]
    let upkeep: Upkeep?
    let partyCap: Int?
    let food: [String: Int]?
    let walking: [WorldExpedition]
    let incoming: [WorldIncoming]?
    let talents: Talents?
    let moonGatesLeft: Int?
    let season: Season?
    let recent: [WorldExpedition]
    let happenings: [Happening]?
    let bosses: [BossNear]?
    let rules: Rules
}

/// POST world/expeditions/plan (shared ExpeditionPlan): everything the dispatch window shows.
struct WorldPlan: Decodable {
    struct Resident: Decodable {
        let id: Int
        let name: String?
        let seed: Double
        let legacySeed: String?
        let breed: String
        let gear: Int
        let power: Int
    }
    struct Start: Decodable {
        let id: String
        let n: Int
        let best: Int
        let power: Int
    }
    struct Estimate: Decodable {
        let win: Double
        let fallen: Double
        let killed: Double
        let facing: Int
        let total: Int
    }
    struct Supplies: Decodable {
        let cap: Int
        let extra: Int
        let most: Int
        let spent: [String: Int]
        let problem: String?
    }
    let residents: [Resident]
    let starts: [Start]
    let power: Int
    let estimate: Estimate?
    let entry: Int?
    let supplies: Supplies
    let minutes: Int?
    let detour: Int
    let moonGate: Bool
    let nightRaid: Bool
    let canPlunder: Bool
    let way: WorldRoute
    let problem: String?
}

struct WorldRoute: Decodable {
    struct Blocked: Decodable { let cell: String; let name: String }
    let waypoints: [String]
    let meters: Double
    let straight: Double
    let blockedBy: Blocked?
}

/// A place found by name (GET world/search) or a landmark round the map's middle (GET world/landmarks).
struct WorldPlace: Decodable {
    let cell: String
    let name: String
    let lat: Double
    let lng: Double
    let km: Double?
    let `where`: String?
    let kind: String?
    let owner: WorldOwner?
}

/// A held cell as GET world/territory lists it (for where a recall walks to).
struct WorldTerritoryItem: Decodable {
    struct Landmark: Decodable { let label: String? }
    let cell: String
    let terrain: String
    let home: Bool?
    let garrison: Int
    let capacity: Int
    let camping: Int?
    let landmark: Landmark?
}

// MARK: - the grid (shared/src/world/grid.ts)

enum WorldGrid {
    static let rowMeters = 174.0
    static let cellMeters = 201.0
    static let hexRadius = cellMeters / 3.0.squareRoot()
    private static let metersPerDegree = 111_320.0
    private static let rowDegrees = rowMeters / metersPerDegree

    private static func rowOf(_ lat: Double) -> Int { Int(floor((max(-89.999, min(89.999, lat)) + 90) / rowDegrees)) }
    private static func rowLat(_ row: Int) -> Double { (Double(row) + 0.5) * rowDegrees - 90 }
    private static func colDegrees(_ row: Int) -> Double { cellMeters / (metersPerDegree * max(0.01, cos(rowLat(row) * .pi / 180))) }
    private static func shift(_ row: Int) -> Double { row % 2 == 1 ? colDegrees(row) / 2 : 0 }
    private static func wrap(_ x: Double) -> Double { ((x.truncatingRemainder(dividingBy: 360)) + 360).truncatingRemainder(dividingBy: 360) }

    static func parse(_ id: String) -> (row: Int, col: Int)? {
        let parts = id.split(separator: ":")
        guard parts.count == 2, let row = Int(parts[0]), let col = Int(parts[1]) else { return nil }
        return (row, col)
    }

    static func cellAt(_ p: CLLocationCoordinate2D) -> String {
        let row = rowOf(p.latitude)
        let lng = wrap(p.longitude + 180) - shift(row)
        return "\(row):\(Int(floor(lng / colDegrees(row))))"
    }

    static func center(_ id: String) -> CLLocationCoordinate2D {
        guard let (row, col) = parse(id) else { return CLLocationCoordinate2D() }
        let lng = (Double(col) + 0.5) * colDegrees(row) + shift(row) - 180
        return CLLocationCoordinate2D(latitude: rowLat(row), longitude: wrap(lng + 180) - 180)
    }

    /// The hexagon a cell is drawn as (pointy top), a little inside the cell so outlined neighbours sit side by side.
    static func ring(_ c: CLLocationCoordinate2D, drawn: Double = 0.9) -> [CLLocationCoordinate2D] {
        let mLat = 110_574.0, mLng = 111_320 * cos(c.latitude * .pi / 180)
        return (0...6).map { k in
            let a = Double(60 * k + 30) * .pi / 180
            return CLLocationCoordinate2D(latitude: c.latitude - hexRadius * drawn * sin(a) / mLat, longitude: c.longitude + hexRadius * drawn * cos(a) / mLng)
        }
    }

    static func meters(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> Double {
        hypot((a.latitude - b.latitude) * 110_574, (a.longitude - b.longitude) * 111_320 * cos(a.latitude * .pi / 180))
    }

    /// Where along a road (its turns) a party is by now: `share` of the way (shared/src/world/route.ts alongRoute).
    static func along(_ points: [CLLocationCoordinate2D], _ share: Double) -> CLLocationCoordinate2D {
        guard points.count >= 2 else { return points.first ?? CLLocationCoordinate2D() }
        let legs = (1..<points.count).map { i in
            hypot(points[i].latitude - points[i - 1].latitude, (points[i].longitude - points[i - 1].longitude) * cos(points[i].latitude * .pi / 180))
        }
        var left = legs.reduce(0, +) * max(0, min(1, share))
        for i in 0..<legs.count {
            if left <= legs[i] || i == legs.count - 1 {
                let t = legs[i] > 0 ? min(1, left / legs[i]) : 1
                let a = points[i], b = points[i + 1]
                return CLLocationCoordinate2D(latitude: a.latitude + (b.latitude - a.latitude) * t, longitude: a.longitude + (b.longitude - a.longitude) * t)
            }
            left -= legs[i]
        }
        return points[points.count - 1]
    }
}

// MARK: - names (mac/Resources/World/names.json, from shared/scripts/world-names.ts)

struct WorldNames: Decodable {
    struct Walk: Decodable {
        let setOutMinutes: Double
        let minutesPerKm: Double
        let maxMinutes: Double
        let regionTravel: Double
    }
    struct Rules: Decodable {
        let bossMinRaceLevel: Int
        let guestsMax: Int
        let homeMoveDays: Int
        let rationsPerExtra: Int
        let detailHomeAttack: Double
        let raidShare: Double
        let raidCap: Int
        let raidTotal: Int
    }
    struct Detail: Decodable {
        let name: String
        let icon: String
        let yields: [String]
        let home: [String]
    }
    struct Landmark: Decodable {
        let kind: String
        let name: String
        let icon: String
        let blurb: String
    }
    struct Hub: Decodable {
        let kind: String
        let blurb: String
        let name: [String: String]
    }
    struct Foe: Decodable {
        let name: String
        let hp: Double
    }
    struct Boost: Decodable {
        let id: String
        let name: String
        let what: String
        let item: Bool
    }
    let walk: Walk
    let rules: Rules
    let terrains: [String: String]
    let terrainYield: [String: [String]]
    let details: [String: Detail]
    let landmarks: [Landmark]
    let hubs: [Hub]
    let buildings: [String: [String: String]]
    let foes: [String: Foe]
    let materials: [String: String]
    let rations: [String]
    let boosts: [Boost]

    static let shared: WorldNames = {
        if let url = Bundle.main.resourceURL?.appendingPathComponent("World/names.json"), let data = try? Data(contentsOf: url),
           let names = try? JSONDecoder().decode(WorldNames.self, from: data) {
            return names
        }
        return WorldNames(walk: Walk(setOutMinutes: 3, minutesPerKm: 4, maxMinutes: 180, regionTravel: 0.25), rules: Rules(bossMinRaceLevel: 50, guestsMax: 20, homeMoveDays: 7, rationsPerExtra: 2, detailHomeAttack: 0.1, raidShare: 0.08, raidCap: 10, raidTotal: 60),
                          terrains: [:], terrainYield: [:], details: [:], landmarks: [], hubs: [], buildings: [:], foes: [:], materials: [:], rations: [], boosts: [])
    }()

    func terrain(_ id: String) -> String { terrains[id] ?? id }
    func material(_ id: String) -> String { materials[id] ?? id }
    func foe(_ id: String) -> String { foes[id]?.name ?? id }
    func landmark(_ kind: String) -> Landmark? { landmarks.first { $0.kind == kind } }
    func building(_ kind: String, race: String) -> String { buildings[kind]?[race] ?? kind }
    func hub(_ kind: String, race: String) -> String { hubs.first { $0.kind == kind }?.name[race] ?? kind }

    /// How long a plain walk of `meters` takes (territory.ts walkMinutes).
    func walkMinutes(_ meters: Double) -> Int {
        max(1, Int(min(walk.maxMinutes, walk.setOutMinutes + meters / 1000 * walk.minutesPerKm).rounded()))
    }

    /// The strongest kind of a lair's foes (its icon on the map).
    func leader(_ foes: [String: Int]) -> String {
        foes.keys.sorted { (self.foes[$0]?.hp ?? 0) > (self.foes[$1]?.hp ?? 0) }.first ?? "slime"
    }
}

// MARK: - words (pwa/app/utils/worldText.ts)

enum WorldText {
    static var names: WorldNames { .shared }

    /// A cell's ground: its terrain, and its 細分地形 if it has one.
    static func ground(_ terrain: String, _ detail: String?) -> String {
        if let detail, let d = names.details[detail] { return "\(d.icon) \(d.name)・\(names.terrain(terrain))" }
        return names.terrain(terrain)
    }

    static func detailLine(_ detail: String, race: String) -> String {
        guard let d = names.details[detail] else { return "" }
        let gives = d.yields.map(names.material).joined(separator: "、")
        let home = d.home.contains(race) ? "；你的種族住得慣，守軍攻擊 +\(Int((names.rules.detailHomeAttack * 100).rounded()))%" : ""
        return "\(d.icon) \(d.name)：佔下來每 3 小時多產 \(gives)\(home)；偶爾生出這裡的稀有種"
    }

    static func outcome(_ r: WorldExpedition) -> String {
        guard let o = r.outcome else { return "在路上" }
        let what = o.where?.kind == "home" ? "營地" : o.where?.kind == "town" ? "城鎮" : "領地"
        if r.defending == true {
            return o.won ? (o.cell == "plundered" ? "\(what)被劫掠了" : o.where?.kind == "home" ? "營地被打敗了" : "\(what)被搶走了") : "守住了\(what)"
        }
        let fought = o.killed > 0 || o.fallen > 0
        switch o.cell {
        case "cleared": return o.where?.kind == "home" ? "打贏了，對方營地被打敗" : o.where != nil ? "打贏了，對方的\(what)沒了" : "打贏了，巢穴清掉了"
        case "taken": return "打贏了，搶下這一格"
        case "settled": return fought ? "打贏了，佔領下來" : "住下了"
        case "held": return o.damage.map { "打了 \($0) 點傷害" } ?? "沒打下來"
        case "camping": return "到了，有些在旁邊扎營"
        case "plundered": return "劫掠成功，搶了就走"
        default: return "回來了"
        }
    }

    static func place(_ r: WorldExpedition) -> String? {
        guard let w = r.outcome?.where else { return nil }
        let what = w.kind == "home" ? "營地" : w.kind == "town" ? "城鎮" : "領地"
        let whose = r.defending == true ? "你的\(w.kind == "home" ? "營地" : w.label)" : "對方的\(what)"
        return w.landmark.map { "\(whose)・\($0)" } ?? whose
    }

    static func wentWell(_ r: WorldExpedition) -> Bool {
        r.defending == true ? !(r.outcome?.won ?? false) : (r.outcome?.won ?? false) || (r.outcome?.damage ?? 0) > 0
    }

    static func loot(_ loot: [String: Int], top: Int = 4) -> String {
        loot.sorted { $0.value > $1.value }.prefix(top).map { "\(names.material($0.key)) \($0.value)" }.joined(separator: "、")
    }

    static func cost(_ cost: [String: Int]) -> String { cost.sorted { $0.key < $1.key }.map { "\(names.material($0.key)) \($0.value)" }.joined(separator: "、") }

    static func date(_ iso: String?) -> Date? { iso.flatMap { ISO8601DateFormatter.guild.date(from: $0) ?? ISO8601DateFormatter().date(from: $0) } }

    /// 「今天 14:05」「10/18 09:30」, as the phone's noteTime.
    static func time(_ iso: String?) -> String {
        guard let at = date(iso) else { return "" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_TW")
        f.dateFormat = Calendar.current.isDateInToday(at) ? "'今天' HH:mm" : Calendar.current.isDateInTomorrow(at) ? "'明天' HH:mm" : "M/d HH:mm"
        return f.string(from: at)
    }

    /// 「3 分 05 秒後到」
    static func arriving(_ iso: String, now: Date = Date()) -> String {
        let sec = max(0, Int(((date(iso) ?? now).timeIntervalSince(now)).rounded()))
        return sec == 0 ? "到了，結算中…" : "\(sec / 60) 分 \(String(format: "%02d", sec % 60)) 秒後到"
    }

    /// 「2 小時 5 分」
    static func left(_ iso: String, now: Date = Date()) -> String {
        let m = max(0, Int((((date(iso) ?? now).timeIntervalSince(now)) / 60).rounded()))
        return m >= 60 ? "\(m / 60) 小時 \(m % 60) 分" : "\(m) 分鐘"
    }

    static func distance(_ km: Double) -> String { km < 1 ? "\(Int((km * 1000).rounded())) 公尺" : String(format: "%.1f 公里", km) }

    /// A resident's name, as the Mac names it from its seed (Names.swift) when it was never given one.
    static func residentName(race: String, name: String?, seed: Double, legacySeed: String?) -> String {
        if let name, !name.isEmpty { return name }
        let s = legacySeed.flatMap { UInt64($0) } ?? UInt64(max(0, seed.rounded(.down)))
        switch race {
        case "elf": return Names.elf(seed: s)
        case "undead": return Names.undead(seed: s)
        default: return Names.goblin(seed: s)
        }
    }
}

// MARK: - pictures

enum WorldArt {
    /// The foes' sheet (16 × 16 each, mac/tools/make_world_foes.py).
    private struct Sheet: Decodable {
        let size: Int
        let cols: Int
        let icons: [String: Int]
    }
    private static let sheet: (image: CGImage, info: Sheet)? = {
        guard let folder = Bundle.main.resourceURL?.appendingPathComponent("World"),
              let data = try? Data(contentsOf: folder.appendingPathComponent("foes.json")), let info = try? JSONDecoder().decode(Sheet.self, from: data),
              let img = NSImage(contentsOf: folder.appendingPathComponent("foes.png"))?.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        return (img, info)
    }()
    private static var foeCache: [String: CGImage] = [:]

    static func foe(_ id: String) -> CGImage? {
        if let hit = foeCache[id] { return hit }
        guard let s = sheet, let at = s.info.icons[id] ?? s.info.icons["slime"] else { return nil }
        let n = s.info.size
        let img = s.image.cropping(to: CGRect(x: (at % s.info.cols) * n, y: (at / s.info.cols) * n, width: n, height: n))
        foeCache[id] = img
        return img
    }

    static func character(_ race: String) -> Character? { Characters.all.first { $0.id == race } }

    /// The race's small face (its icon).
    static func face(_ race: String) -> CGImage? { character(race)?.icon?.cgImage(forProposedRect: nil, context: nil, hints: nil) }

    /// A breed's first frame, facing down.
    static func breed(_ race: String, _ breed: String) -> CGImage? {
        guard let c = character(race) else { return nil }
        return (c.breeds.first { $0.id == breed } ?? c.breeds.first)?.sprites?.image(direction: .down, phase: 0)
    }

    static func breedName(_ race: String, _ breed: String) -> String { character(race)?.breeds.first { $0.id == breed }?.name ?? breed }

    /// A pixel picture as a small image view (nearest-neighbour scaling).
    static func view(_ image: CGImage?, size: CGFloat) -> NSImageView {
        let v = NSImageView()
        if let image { v.image = NSImage(cgImage: image, size: NSSize(width: size, height: size)) }
        v.imageScaling = .scaleProportionallyUpOrDown
        v.wantsLayer = true
        v.layer?.magnificationFilter = .nearest
        v.translatesAutoresizingMaskIntoConstraints = false
        v.widthAnchor.constraint(equalToConstant: size).isActive = true
        v.heightAnchor.constraint(equalToConstant: size).isActive = true
        return v
    }

    /// Each race's flag, and the walls and roof its buildings are made of (WorldMap.vue RACE_LOOK).
    static func look(_ race: String) -> (flag: NSColor, wall: NSColor, roof: NSColor, stone: NSColor) {
        func c(_ hex: UInt32) -> NSColor { NSColor(srgbRed: CGFloat(hex >> 16 & 0xff) / 255, green: CGFloat(hex >> 8 & 0xff) / 255, blue: CGFloat(hex & 0xff) / 255, alpha: 1) }
        switch race {
        case "elf": return (c(0x3aa0e0), c(0xe8dcc0), c(0x3f8f5a), c(0xe6e0d0))
        case "undead": return (c(0x9a50d0), c(0x4a4458), c(0x2a2638), c(0x5a5468))
        default: return (c(0x5fb030), c(0x8a5a32), c(0x5e7a2a), c(0x9a8a70))
        }
    }

    /// What a camp's home looks like by its race level: a hut, a stockade (Lv5), a stone keep (Lv10), a citadel (Lv20).
    static func homeTier(_ level: Int) -> Int { level >= 20 ? 3 : level >= 10 ? 2 : level >= 5 ? 1 : 0 }

    /**
     A camp's home or a town (a castle) in pixels, 24 wide and 30 high (the flag above), as the phone's map draws them
     (WorldMap.vue buildingSvg): each part outlined by drawing it a pixel bigger in black first. Drawn in a flipped 24 × 30 box.
     */
    static func building(town: Bool, race: String, level: Int, scale: CGFloat, sway: CGFloat = 0) -> NSImage {
        let look = look(race)
        let ink = NSColor(white: 0.12, alpha: 1)
        typealias Part = (CGFloat, CGFloat, CGFloat, CGFloat, NSColor)
        let castle: [Part] = [
            (2, 9, 6, 14, look.stone), (16, 9, 6, 14, look.stone), (7, 13, 10, 10, look.stone),
            (2, 7, 2, 2, look.stone), (6, 7, 2, 2, look.stone), (16, 7, 2, 2, look.stone), (20, 7, 2, 2, look.stone),
            (8, 11, 2, 2, look.stone), (14, 11, 2, 2, look.stone),
        ]
        let tier = town ? -1 : homeTier(level)
        let parts: [Part] = town ? castle
            : tier == 3 ? castle.filter { $0.1 != 11 } + [(9, 6, 6, 17, look.stone), (9, 4, 2, 2, look.stone), (13, 4, 2, 2, look.stone)]
            : tier == 2 ? [(6, 10, 12, 13, look.stone), (6, 8, 2, 2, look.stone), (10, 8, 4, 2, look.stone), (16, 8, 2, 2, look.stone)]
            : [(5, 16, 14, 7, look.wall)]
        let size = NSSize(width: 24 * scale, height: 30 * scale)
        return NSImage(size: size, flipped: true) { _ in
            guard let g = NSGraphicsContext.current?.cgContext else { return false }
            g.scaleBy(x: scale, y: scale)
            g.translateBy(x: 0, y: 6) // (the flag goes up to y −6)
            g.setShouldAntialias(false)
            func box(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ color: NSColor) {
                g.setFillColor(color.cgColor)
                g.fill(CGRect(x: x, y: y, width: w, height: h))
            }
            for p in parts { box(p.0 - 1, p.1 - 1, p.2 + 2, p.3 + 2, ink) }
            for p in parts { box(p.0, p.1, p.2, p.3, p.4) }
            if town || tier >= 2 {
                box(10, 17, 4, 6, ink); box(11, 16, 2, 1, ink)
                if tier == 2 { box(8, 12, 2, 2, ink); box(14, 12, 2, 2, ink) } else { box(4, 12, 2, 2, ink); box(18, 12, 2, 2, ink) }
                if tier == 3 { box(11, 10, 2, 3, ink) }
            } else {
                g.setShouldAntialias(true)
                g.setFillColor(ink.cgColor)
                g.beginPath(); g.move(to: CGPoint(x: 2, y: 17)); g.addLine(to: CGPoint(x: 12, y: 7)); g.addLine(to: CGPoint(x: 22, y: 17)); g.closePath(); g.fillPath()
                g.setFillColor(look.roof.cgColor)
                g.beginPath(); g.move(to: CGPoint(x: 4, y: 16)); g.addLine(to: CGPoint(x: 12, y: 8.5)); g.addLine(to: CGPoint(x: 20, y: 16)); g.closePath(); g.fillPath()
                g.setShouldAntialias(false)
                box(10, 18, 4, 5, ink)
                if tier == 1 { for x in [1, 4, 7, 15, 18, 21] as [CGFloat] { box(x - 1, 18, 3, 6, ink); box(x, 19, 1, 5, look.wall) } }
            }
            // the flag on its pole, in the race's colour with its face, a star for every five levels (up to four)
            let top: CGFloat = town ? 11 : tier == 3 ? 4 : 8
            box(11, -6, 1, top + 6, ink)
            g.saveGState()
            g.translateBy(x: 12, y: -2.5)
            g.concatenate(CGAffineTransform(a: 1, b: sway, c: 0, d: 1, tx: 0, ty: 0))
            g.translateBy(x: -12, y: 2.5)
            box(12, -6, 9, 7, ink)
            box(12, -5, 8, 5, look.flag)
            if let face = face(race) {
                g.saveGState()
                g.interpolationQuality = .none
                g.translateBy(x: 13, y: 0)
                g.scaleBy(x: 1, y: -1)
                g.draw(face, in: CGRect(x: 0, y: 0, width: 5, height: 5))
                g.restoreGState()
            }
            if !town { for i in 0..<min(4, level / 5) { box(19, -5 + CGFloat(i) * 1.25, 1, 1, NSColor(srgbRed: 1, green: 0.886, blue: 0.478, alpha: 1)) } }
            g.restoreGState()
            return true
        }
    }
}
