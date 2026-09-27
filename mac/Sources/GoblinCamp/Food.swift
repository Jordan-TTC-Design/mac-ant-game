import AppKit

/// Food is not something the goblins need: nobody goes hungry. What they carry home gives the whole camp a boost for a while (see
/// `Colony.boost`), a different one for each kind. The player puts the first ten down from the menu; fruit, meat from a hunt and the
/// stew from the cooking pot turn up by themselves.
enum FoodKind: String, CaseIterable {
    case water, honey, bread, meat, cheese, carrot, mushroom, berries, fish, cake
    case fruit, loot, stew

    /// What the player can put down from the menu.
    static let placeable: [FoodKind] = [.water, .honey, .bread, .meat, .cheese, .carrot, .mushroom, .berries, .fish, .cake]

    var label: String {
        switch self {
        case .water: return "清水"
        case .honey: return "蜂蜜"
        case .bread: return "麵包"
        case .meat: return "烤肉"
        case .cheese: return "起司"
        case .carrot: return "胡蘿蔔"
        case .mushroom: return "蘑菇"
        case .berries: return "野莓"
        case .fish: return "烤魚"
        case .cake: return "蜂蜜蛋糕"
        case .fruit: return "果實"
        case .loot: return "素材"
        case .stew: return "燉菜"
        }
    }

    var emoji: String {
        switch self {
        case .water: return "💧"
        case .honey: return "🍯"
        case .bread: return "🍞"
        case .meat: return "🍖"
        case .cheese: return "🧀"
        case .carrot: return "🥕"
        case .mushroom: return "🍄"
        case .berries: return "🫐"
        case .fish: return "🐟"
        case .cake: return "🍰"
        case .fruit: return "🍎"
        case .loot: return "💎"
        case .stew: return "🍲"
        }
    }

    /// The boost a piece of it brings home, if any: its own, or (for what turns up by itself) the one it is most like.
    var boost: FoodKind? {
        switch self {
        case .fruit: return .berries
        case .loot: return nil
        default: return self
        }
    }

    /// What the boost does, as the menu says it.
    var effect: String {
        switch self {
        case .water: return "在巢裡回血 +50%"
        case .honey: return "生哥布林的間隔 −25%"
        case .bread: return "伐木、挖石 +30%"
        case .meat: return "打獵、打魔獸的攻擊 +20%"
        case .cheese: return "受到的傷害 −20%"
        case .carrot: return "走路 +15%"
        case .mushroom: return "生出稀有品種的機率提高"
        case .berries: return "小孩長大加快、比較不會生病"
        case .fish: return "釣魚、種田收成 +30%"
        case .cake: return "公主的感情進展加快"
        case .stew: return "每一樣都有一點"
        case .fruit, .loot: return ""
        }
    }

    /// How many pieces the goblins can carry away.
    var initialAmount: Int {
        switch self {
        case .fruit: return 6
        case .meat: return 12
        case .loot: return 1
        case .stew: return 10
        default: return 12
        }
    }

    /// Radius in points when full (before the ant-size setting): where the goblins stand around it.
    var baseRadius: Double {
        switch self {
        case .fruit: return 10 // the foot of the tree
        case .loot: return 5
        case .stew: return 8
        case .water, .honey, .berries, .cake: return 11
        default: return 13
        }
    }

    /// Colour of the little piece a goblin carries.
    var pieceColor: NSColor {
        let rgb: (Double, Double, Double)
        switch self {
        case .water: rgb = (0.55, 0.78, 0.97)
        case .honey: rgb = (0.96, 0.68, 0.12)
        case .bread: rgb = (0.90, 0.70, 0.40)
        case .meat: rgb = (0.80, 0.34, 0.26)
        case .cheese: rgb = (1.0, 0.86, 0.36)
        case .carrot: rgb = (1.0, 0.56, 0.16)
        case .mushroom: rgb = (0.90, 0.26, 0.22)
        case .berries: rgb = (0.40, 0.42, 0.86)
        case .fish: rgb = (0.84, 0.60, 0.30)
        case .cake: rgb = (1.0, 0.92, 0.80)
        case .fruit: rgb = (0.88, 0.2, 0.2)
        case .loot: rgb = (0.95, 0.82, 0.3)
        case .stew: rgb = (0.86, 0.55, 0.22)
        }
        return NSColor(calibratedRed: rgb.0, green: rgb.1, blue: rgb.2, alpha: 1)
    }
}

/// The pixel pictures of the foods the player puts down (drawn in the style of the ground's pumpkins and firewood: a dark outline,
/// two or three shades, light from the top left), made once and kept.
enum FoodSprites {
    private static var cache: [String: CGImage] = [:]

    /// The picture for this food: whole, or the one with little left (under 40%). Nil for what has no picture (fruit trees, loot, stew).
    static func image(_ kind: FoodKind, low: Bool) -> CGImage? {
        let key = kind.rawValue + (low ? "-low" : "")
        if let image = cache[key] { return image }
        guard let grid = grids[kind], let image = render(low ? grid.low : grid.full) else { return nil }
        cache[key] = image
        return image
    }

    private static func render(_ rows: [String]) -> CGImage? {
        let width = rows.map(\.count).max() ?? 0, height = rows.count
        guard width > 0, height > 0 else { return nil }
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        for (y, row) in rows.enumerated() {
            for (x, ch) in row.enumerated() {
                guard let c = palette[ch] else { continue }
                let i = (y * width + x) * 4
                bytes[i] = c.0; bytes[i + 1] = c.1; bytes[i + 2] = c.2; bytes[i + 3] = 255
            }
        }
        guard let provider = CGDataProvider(data: Data(bytes) as CFData) else { return nil }
        return CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
                       space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
    }

    /// The colours the food pictures use, by the letter in the grids.
    static let palette: [Swift.Character: (UInt8, UInt8, UInt8)] = [
        "A": (255, 166, 64), "B": (150, 152, 164), "C": (204, 124, 78), "E": (42, 98, 46), "F": (248, 218, 184), "G": (132, 200, 86),
        "H": (255, 244, 170), "K": (214, 170, 98), "L": (206, 160, 100), "M": (222, 104, 78), "Q": (255, 230, 116), "R": (232, 72, 62),
        "S": (255, 252, 244), "T": (244, 202, 124), "U": (128, 136, 230), "W": (228, 248, 255), "X": (248, 244, 230), "Y": (255, 216, 72),
        "a": (230, 112, 30), "b": (96, 98, 110), "c": (162, 88, 54), "d": (112, 72, 42), "e": (76, 148, 58), "g": (164, 118, 58), "h": (206, 120, 10),
        "i": (76, 78, 178), "j": (44, 42, 110), "k": (112, 56, 36), "l": (164, 112, 64), "m": (176, 64, 50), "n": (116, 40, 34), "o": (56, 34, 26),
        "p": (168, 38, 42), "q": (238, 188, 60), "r": (158, 94, 42), "s": (252, 238, 206), "t": (212, 146, 66), "u": (196, 138, 40),
        "v": (64, 124, 200), "w": (104, 176, 230), "x": (206, 196, 176), "y": (246, 168, 24), "z": (172, 72, 22),
    ]

    /// Each food as it is put down, and when little is left (top row first; `.` is empty).
    static let grids: [FoodKind: (full: [String], low: [String])] = [
        .water: ([
            "...oooooooo...",
            "..oWWwwwwwwo..",
            ".oLWwwwwwwvdo.",
            ".oLlvvvvvvldo.",
            ".oLlllllllldo.",
            ".obBbbbbbbbbo.",
            ".oLlllllllldo.",
            "..oLlllllldo..",
            "..oLlllllldo..",
            "..obBbbbbbbo..",
            "...oLllllo....",
            "...oooooooo...",
        ], [
            "...oooooooo...",
            "..oddddddddo..",
            ".oLdddddddddo.",
            ".oLlwWwwwwldo.",
            ".oLlllllllldo.",
            ".obBbbbbbbbbo.",
            ".oLlllllllldo.",
            "..oLlllllldo..",
            "..oLlllllldo..",
            "..obBbbbbbbo..",
            "...oLllllo....",
            "...oooooooo...",
        ]),
        .honey: ([
            "..........oo..",
            ".........oLo..",
            "...oooooolo...",
            "..oYYYYYYyYo..",
            "..okkkkkkkko..",
            "..oYYyccccko..",
            ".oCYyccccccko.",
            ".oCyhCCcccckko",
            ".oCCyCccccckko",
            ".oCChcccccckko",
            "..okcccccckko.",
            "...okkkkkkko..",
            "....ooooooo...",
        ], [
            "..........oo..",
            ".........oLo..",
            "...oooooolo...",
            "..okkkkkkdko..",
            "..okkkkkkkko..",
            "..oCcccccko...",
            ".oCCcccccccko.",
            ".oCcCCcccccko.",
            ".oCCcCccccckko",
            ".oCccccccccko.",
            "..okcccccckko.",
            "...okkkkkkko..",
            "....ooooooo...",
        ]),
        .bread: ([
            "......ooooooo.....",
            "....ooTTTTTTtoo...",
            "...oTTsTTTsTTtto..",
            "..oTTTTsTTTTsTtto.",
            "..otTTTTsTTTTsttto",
            ".ootttttttttttttro",
            "oTTotttttttttttrro",
            "oTsTorrrrrrrrrrro.",
            "otTTTo.ooooooooo..",
            "ortttro...........",
            ".oooooo...........",
        ], [
            "..................",
            "..................",
            "..................",
            "..................",
            "..................",
            "..................",
            "ooooo.............",
            "oTsTTo............",
            "otTTTo............",
            "ortttro...........",
            ".oooooo...........",
        ]),
        .meat: ([
            "...........oo.....",
            "....oooo..oXXo....",
            "..ooMMMMo.oXxo....",
            ".oMMFMMmmoXxo.....",
            ".oMMMMmmmmxo..oo..",
            "oMMmmmmmmno..oXXo.",
            "oMmmmmmmnno.oXxxo.",
            ".ommmmmnno.ooxo...",
            "..onnnnoo.oMMxo...",
            "EeGoooo..oMMmmo...",
            ".EeGGeeeoMmmnno...",
            "..EEeeeeeonnoo....",
            "....EEEEEEoo......",
        ], [
            "..................",
            "..................",
            "..................",
            "..................",
            "..............oo..",
            ".............oXXo.",
            "............oXxxo.",
            "...........ooxo...",
            "..........oMMxo...",
            "EeG......oMMmmo...",
            ".EeGGeeeoMmmnno...",
            "..EEeeeeeonnoo....",
            "....EEEEEEoo......",
        ]),
        .cheese: ([
            "..........oo....",
            "........ooQQo...",
            "......ooQQQQqo..",
            "....ooQQQQQQqqo.",
            "..ooQQQQQQQqqqqo",
            "ooQQQQQQQQqqqqqo",
            "oqqqqqqqqqqquuuo",
            "oqqouqqqqqquuuuo",
            "oqqqqqqqouququuo",
            "oqqqqouqqqquuuuo",
            "ouuuuuuuuuuuuuuo",
            ".oooooooooooooo.",
        ], [
            "................",
            "................",
            "................",
            "................",
            "................",
            "......oo........",
            "....ooQQo.......",
            "..ooQQQqqo......",
            "ooQQQQqqqo......",
            "oqqouqqquo......",
            "ouuuuuuuuo......",
            ".oooooooo.......",
        ]),
        .carrot: ([
            "..oo..oo..........",
            ".oGeooGeo..oo.....",
            "..oEGGeo..oGeo....",
            "...ooEoAooeEo.....",
            "....oAAAaoEo......",
            "...oAAaaaoAAo.....",
            "..oAAaazoAAaao....",
            "..oAaaaooAaazo....",
            ".oAaazo.oAaaao....",
            ".oaazo..oAaazo....",
            "oazoo...oaazo.....",
            "ozo......ozo......",
            ".o........o.......",
        ], [
            "..................",
            "..................",
            "..........oo......",
            "..........oGeo....",
            "..........oEo.....",
            ".........oAAo.....",
            "........oAAaao....",
            "........oAaazo....",
            "........oAaaao....",
            "........oAaazo....",
            "........oaazo.....",
            ".........ozo......",
            "..........o.......",
        ]),
        .mushroom: ([
            "....oooooo........",
            "..ooRRSRRRoo......",
            ".oRRSRRRRSRpo.....",
            "oRSRRRRSRRRppo....",
            "oppppppppppppo.oo.",
            ".ooooXXxoooo.oRSRo",
            "....oXXxo...oRRRpo",
            "....oXXxo...oppppo",
            "...oXXXxxo...oXxo.",
            "EeGoooooooeGoXxxoe",
            ".EEeeeeeeeeeEoooE.",
        ], [
            "..................",
            "..................",
            "..................",
            "...............oo.",
            ".............oRSRo",
            "............oRRRpo",
            "............oppppo",
            ".............oXxo.",
            "EeG.......eGoXxxoe",
            ".EEeeeeeeeeeEoooE.",
        ]),
        .berries: ([
            "...oooo.oooo....",
            "..oUUioUUiiRRo..",
            ".oUSUiioUiRSRpo.",
            ".oUUijoUiiRRpUo.",
            "oKoiijoKoojppoUo",
            "oKKgKKgKKgKKgKKo",
            "ogKKgKKgKKgKKgKo",
            "oKKgKKgKKgKKgKgo",
            ".ogKKgKKgKKgKgo.",
            "..oggggggggggo..",
            "...oooooooooo...",
        ], [
            "................",
            "................",
            "................",
            "......oooo......",
            "oooooUiRRooooooo",
            "oKKgKKgKKgKKgKKo",
            "ogKKgKKgKKgKKgKo",
            "oKKgKKgKKgKKgKgo",
            ".ogKKgKKgKKgKgo.",
            "..oggggggggggo..",
            "...oooooooooo...",
        ]),
        .fish: ([
            "......ooooooo.....",
            "o...ooTTTTTTToo...",
            "oTooTTnTTnTTTTToo.",
            "oTTtTnttnttTTTSoTo",
            "oToottnttntttttro.",
            "o..oorrrrrrrrrroo.",
            "...EeeGGGeeGGeeE..",
            "....EEEEEEEEEEE...",
        ], [
            "..................",
            "..................",
            "...........oooo...",
            "oX.X.X.X.XoTTSoo..",
            "XXXXXXXXXXoTttro..",
            "oX.X.X.X.Xoooo....",
            "...EeeGGGeeGGeeE..",
            "....EEEEEEEEEEE...",
        ]),
        .cake: ([
            "......oHo.......",
            "......oyo.......",
            "......oSo.......",
            "...oooRSRooo....",
            "..oXSSSSSSSxo...",
            ".oYXYXXYXXYXxo..",
            ".oTyTTyTTTyTto..",
            ".oTTTTTTTTTTto..",
            ".oXXXXXXXXXXxo..",
            ".oTTTTTTTTTttto.",
            "BoooooooooooooB.",
            ".BBBBBBBBBBBBB..",
        ], [
            "................",
            "................",
            "................",
            "................",
            "......ooo.......",
            ".....oXXxo......",
            "....oYXYXo......",
            "....oTyTto......",
            "....oXXXxo......",
            "....oTTtto......",
            "BooooooooooooooB",
            ".BBBBBBBBBBBBB..",
        ]),
    ]
}

/// A patch of food on the desktop. Coordinates are global screen coordinates.
struct FoodSource {
    let id: Int
    let kind: FoodKind
    var pos: CGPoint
    var amount: Int
    var origin: Origin = .placed
    /// How much it held when it was whole (meat depends on the animal); `nil` = the kind's usual amount.
    var capacityOverride: Int?
    /// Seconds until a tree grows its next fruit.
    var regrow: Double = 0
    /// An ant has found it and is on her way home with the news.
    var scouted = false
    /// The news reached the nest, so nestmates are on the way (and other finders simply join in).
    var reported = false
    /// What a `.loot` pile is (a material id from a monster's drops).
    var material: String?

    enum Origin {
        /// Put down by the player.
        case placed
        /// A fruit tree: it stays when picked bare, and grows fruit back.
        case tree
        /// What a hunted animal leaves behind.
        case meat
        /// What a slain monster leaves behind: one pile per material.
        case loot
    }

    var isTree: Bool { origin == .tree }

    var capacity: Int { capacityOverride ?? kind.initialAmount }

    /// It shrinks as the ants carry it off, but never below 40% of its size until it is gone.
    func radius(scale: Double) -> Double {
        if isTree { return kind.baseRadius * scale } // a tree does not shrink
        return kind.baseRadius * scale * (0.4 + 0.6 * min(1, Double(amount) / Double(max(capacity, 1))).squareRoot())
    }

    /// An ant this close to the food notices it.
    func senseRadius(scale: Double) -> Double { radius(scale: scale) + 9 }
}

/// What an ant can see of the world on each update.
struct AntWorld {
    let nest: CGPoint
    /// The tents of the camp that are up (where a goblin can step in): tunnels join them to the nest, so a goblin can go in at any of them
    /// and come out at any other. The nest is the first way in; these are the others.
    var tents: [CGPoint] = []
    let walkable: [CGRect]
    let foods: [FoodSource]
    let creatures: [CreatureInfo]
    /// Food size follows the ant-size setting a little, so big ants do not swamp small food.
    let foodScale: Double
    /// How fast wandering goes in this kind of range: a little slower in a strip or a small window than across a whole screen.
    var pace = 1.0
    /// It is raining: goblins go back to the nest much more often.
    var raining = false
    /// A campfire party (during the pomodoro rest): wanderers drift toward it and mill around it.
    var fire: CGPoint?
    /// Places wanderers keep out of (a pond).
    var obstacles: [Obstacle] = []
    /// The ponds among them (goblins fish from their banks).
    var ponds: [Pond] = []
    /// How full the range is: goblins out walking divided by how many fit. Over 1, goblins rest in the nest longer and go back sooner.
    var crowd = 0.0
    /// Health regained per second inside the nest (faster while the princess is looking after them).
    var healRate = 0.05
    /// What the food brought home does for everyone out walking (1 = nothing): how fast they walk (carrots), how fast they fell and dig
    /// (bread), and how often a fish bites (grilled fish).
    var speedBoost = 1.0
    var workBoost = 1.0
    var fishBoost = 1.0
    /// Night time (goblins sleep more), and whether they may start something to pass the time (not while it rains, in a crowd, or at the campfire party).
    var night = false
    var activitiesOn = true
    /// The stone ring where the goblins cook (once the camp has one), and whether a cook may start now (something in the larder, nobody at the pot).
    var pit: CGPoint?
    var cookSlots = 0
    /// The farm plots nobody is working now, how many more goblins may set out to farm, and whether anything can be sown (not in winter).
    var plots: [TerrainScene.PlotInfo] = []
    var farmSlots = 0
    var canSow = true
    /// The young ones out and about (by id: where, and whether it is ill), and which of them nobody is minding.
    var children: [Int: (pos: CGPoint, sick: Bool)] = [:]
    var unminded: Set<Int> = []
    /// Where the goblins that are scuffling with each other are (by id), and where the golden ones being waited on are.
    /// The trees and rocks goblins may work at (nobody is at them now), and how many more may set out to (a few at a time, not the whole camp).
    var resources: [TerrainScene.ResourceSpot] = []
    var gatherSlots = 0
    var partners: [Int: CGPoint] = [:]
    var bosses: [Int: CGPoint] = [:]
    /// Where each goblin keeping the princess company (her suitor, her partner, her guards) should stand, and what they look at.
    var attendTargets: [Int: CGPoint] = [:]
    var attendFace: CGPoint?
    var crowded: Bool { crowd >= 1 }

    /// The way in nearest to `p`: the nest hole or a tent.
    func nearestEntrance(to p: CGPoint) -> CGPoint {
        var best = nest, bestDistance = hypot(nest.x - p.x, nest.y - p.y)
        for tent in tents {
            let d = hypot(tent.x - p.x, tent.y - p.y)
            if d < bestDistance { best = tent; bestDistance = d }
        }
        return best
    }

    /// Where a goblin comes out: the way out nearest to where it is going (its food, its prey), or any of them, the nest hole a little more often.
    func emergePoint(toward goal: CGPoint? = nil) -> CGPoint {
        var spot = nest
        if let goal { spot = nearestEntrance(to: goal) } else if !tents.isEmpty, Double.random(in: 0..<1) < Double(tents.count) / Double(tents.count + 2) { spot = tents.randomElement() ?? nest }
        return CGPoint(x: spot.x + CGFloat.random(in: -3...3), y: spot.y + CGFloat.random(in: -3...3))
    }

    enum Axis { case horizontal, vertical }

    /// The long direction of the range at this spot, if the range is a strip (much longer than wide).
    func axis(at p: CGPoint) -> Axis? {
        guard let rect = walkable.first(where: { $0.contains(p) }) else { return nil }
        if rect.width >= rect.height * 2 { return .horizontal }
        if rect.height >= rect.width * 2 { return .vertical }
        return nil
    }

    /// How wide the strip is across (its short side) at this spot.
    func thickness(at p: CGPoint) -> Double {
        guard let rect = walkable.first(where: { $0.contains(p) }) else { return 1000 }
        return Double(min(rect.width, rect.height))
    }

    /// The animal with this id, if it is still about.
    func creature(_ id: Int) -> CreatureInfo? {
        creatures.first { $0.id == id }
    }

    /// The food with this id, if any is left.
    func food(_ id: Int) -> FoodSource? {
        foods.first { $0.id == id && $0.amount > 0 }
    }
}
