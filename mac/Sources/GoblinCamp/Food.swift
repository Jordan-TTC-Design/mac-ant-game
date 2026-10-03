import AppKit

/// Food is not something the goblins need: nobody goes hungry. What they carry home gives the whole camp a boost for a while (see
/// `Colony.boost`), a different one for each kind. The player puts the first ten down from the menu; fruit, meat from a hunt and the
/// stew from the cooking pot turn up by themselves.
enum FoodKind: String, CaseIterable {
    case water, honey, bread, meat, cheese, carrot, mushroom, berries, fish, cake
    case fruit, loot, stew
    /// The undead's: coloured souls give boosts instead of food; bones and wandering souls grow new undead (see RACES.md).
    case soulBlue = "soul_blue", soulGreen = "soul_green", soulPurple = "soul_purple"
    case bones, soul

    /// What each coloured soul does: the same as this food (blue hits harder like roast meat, green heals like water, purple
    /// hurries the soul tower like honey hurries births).
    var actsAs: FoodKind? {
        switch self {
        case .soulBlue: return .meat
        case .soulGreen: return .water
        case .soulPurple: return .honey
        default: return nil
        }
    }

    /// Bones and wandering souls: carried to the soul tower, they become new undead rather than a boost.
    var grows: Bool { self == .bones || self == .soul }

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
        case .soulBlue: return "藍魂"
        case .soulGreen: return "綠魂"
        case .soulPurple: return "紫魂"
        case .bones: return "骨頭"
        case .soul: return "魂魄"
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
        case .soulBlue: return "🔵"
        case .soulGreen: return "🟢"
        case .soulPurple: return "🟣"
        case .bones: return "🦴"
        case .soul: return "👻"
        }
    }

    /// The boost a piece of it brings home, if any: its own, or (for what turns up by itself) the one it is most like.
    var boost: FoodKind? {
        switch self {
        case .fruit: return .berries
        case .loot, .bones, .soul: return nil
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
        case .soulBlue: return "攻擊 +20%"
        case .soulGreen: return "在魂塔裡回血 +50%"
        case .soulPurple: return "魂塔收集加快"
        case .bones: return "搬回魂塔，長出骨系死靈"
        case .soul: return "被靈魂之火吸過去，長出魂系死靈"
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
        case .bones: return 6
        case .soul: return 1
        default: return 12
        }
    }

    /// Radius in points when full (before the ant-size setting): where the goblins stand around it.
    var baseRadius: Double {
        switch self {
        case .fruit: return 10 // the foot of the tree
        case .loot: return 5
        case .stew: return 8
        case .soul: return 5
        case .water, .honey, .berries, .cake, .soulBlue, .soulGreen, .soulPurple, .bones: return 11
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
        case .soulBlue: rgb = (0.4, 0.6, 1.0)
        case .soulGreen: rgb = (0.45, 0.92, 0.6)
        case .soulPurple: rgb = (0.75, 0.5, 1.0)
        case .bones: rgb = (0.94, 0.92, 0.84)
        case .soul: rgb = (0.6, 0.95, 0.9)
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
        // the undead's souls and bones: a cold outline, green, blue and purple souls, the pale wandering soul
        "0": (34, 30, 46), "Z": (200, 255, 230), "P": (90, 220, 160), "I": (190, 220, 255), "J": (90, 140, 250),
        "N": (236, 200, 255), "V": (170, 110, 240), "D": (200, 255, 244),
        "A": (255, 166, 64), "B": (150, 152, 164), "C": (204, 124, 78), "E": (42, 98, 46), "F": (248, 218, 184), "G": (132, 200, 86),
        "H": (255, 244, 170), "K": (214, 170, 98), "L": (206, 160, 100), "M": (222, 104, 78), "Q": (255, 230, 116), "R": (232, 72, 62),
        "S": (255, 252, 244), "T": (244, 202, 124), "U": (128, 136, 230), "W": (228, 248, 255), "X": (248, 244, 230), "Y": (255, 216, 72),
        "a": (230, 112, 30), "b": (96, 98, 110), "c": (162, 88, 54), "d": (112, 72, 42), "e": (76, 148, 58), "g": (164, 118, 58), "h": (206, 120, 10),
        "i": (76, 78, 178), "j": (44, 42, 110), "k": (112, 56, 36), "l": (164, 112, 64), "m": (176, 64, 50), "n": (116, 40, 34), "o": (56, 34, 26),
        "p": (168, 38, 42), "q": (238, 188, 60), "r": (158, 94, 42), "s": (252, 238, 206), "t": (212, 146, 66), "u": (196, 138, 40),
        "v": (64, 124, 200), "w": (104, 176, 230), "x": (206, 196, 176), "y": (246, 168, 24), "z": (172, 72, 22),
    ]

    /// Each food as it is put down, and when little is left (top row first; `.` is empty).
    static let grids: [FoodKind: (full: [String], low: [String])] = soulGrids.merging(baseGrids) { a, _ in a }

    private static let soulFlame = [
        "....00....",
        "...0Q0....",
        "..0QQQ0...",
        ".0QQZQQ0..",
        ".0QZZZQ0..",
        "0QZZZZZQ0.",
        "0QZZZZZQ0.",
        ".0QZZZQ0..",
        "..00000...",
    ]
    private static func tinted(_ grid: [String], _ light: Swift.Character, _ mid: Swift.Character) -> [String] {
        grid.map { String($0.map { $0 == "Z" ? light : $0 == "Q" ? mid : $0 }) }
    }
    private static let soulGrids: [FoodKind: (full: [String], low: [String])] = [
        .soulBlue: (tinted(soulFlame, "I", "J"), tinted(Array(soulFlame.suffix(5)), "I", "J")),
        .soulGreen: (tinted(soulFlame, "Z", "P"), tinted(Array(soulFlame.suffix(5)), "Z", "P")),
        .soulPurple: (tinted(soulFlame, "N", "V"), tinted(Array(soulFlame.suffix(5)), "N", "V")),
        .soul: (["..00..", ".0DD0.", "0DDDD0", "0DDDD0", ".0DD0.", "..00.."], ["..00..", ".0DD0.", "..00.."]),
        .bones: ([
            "......0000......",
            ".....0XXXX0.....",
            "..00.0XoXo0.00..",
            ".0XX00XXXX00XX0.",
            "0XXXXXX00XXXXXX0",
            "0XXxxxXXXXxxXXX0",
            ".00XXXX00XXXX00.",
            "...0000000000...",
        ], [
            "..00......00..",
            ".0XX000000XX0.",
            "0XXXXXXXXXXXX0",
            ".000000000000.",
        ]),
    ]

    static let baseGrids: [FoodKind: (full: [String], low: [String])] = [
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
    /// How far off this race fights from (archers), in points on top of what a weapon adds.
    var rangedReach = 0.0
    /// Night time (goblins sleep more), and whether they may start something to pass the time (not while it rains, in a crowd, or at the campfire party).
    var night = false
    /// How much likelier quiet sitting is (a harp, a meditation stone put down: twice).
    var calm = 1.0
    /// The hour of the day (0…23), for what goes on of an evening.
    var hour = 12
    /// How many more may take up the night watch, and sit round the fire pit.
    var patrolSlots = 0
    var firesideSlots = 0
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
    /// The race's character id (goblin, elf, undead): each passes its spare time its own way (Ant.pickActivity).
    var race = "goblin"
    /// The undead camp's graves (where they sleep).
    var graves: [CGPoint] = []
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
