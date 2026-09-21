import AppKit

enum FoodKind: String, CaseIterable {
    case water, honey, fruit, meat, loot, stew

    /// What the player can put down from the menu (fruit and meat turn up by themselves).
    static let placeable: [FoodKind] = [.water, .honey]

    var label: String {
        switch self {
        case .water: return "水滴"
        case .honey: return "蜂蜜"
        case .fruit: return "果實"
        case .meat: return "肉"
        case .loot: return "素材"
        case .stew: return "燉菜"
        }
    }

    var emoji: String {
        switch self {
        case .water: return "💧"
        case .honey: return "🍯"
        case .fruit: return "🍎"
        case .meat: return "🍖"
        case .loot: return "💎"
        case .stew: return "🍲"
        }
    }

    /// How many pieces the ants can carry away.
    var initialAmount: Int {
        switch self {
        case .water: return 16
        case .honey: return 24
        case .fruit: return 6
        case .meat: return 12
        case .loot: return 1
        case .stew: return 10
        }
    }

    /// Radius in points when full (before the ant-size setting).
    var baseRadius: Double {
        switch self {
        case .water: return 9
        case .honey: return 8
        case .fruit: return 10 // the foot of the tree
        case .meat: return 7
        case .loot: return 5
        case .stew: return 8
        }
    }

    /// Colour of the little piece an ant carries.
    var pieceColor: NSColor {
        switch self {
        case .water: return NSColor(calibratedRed: 0.55, green: 0.78, blue: 0.97, alpha: 1)
        case .honey: return NSColor(calibratedRed: 0.96, green: 0.68, blue: 0.12, alpha: 1)
        case .fruit: return NSColor(calibratedRed: 0.88, green: 0.2, blue: 0.2, alpha: 1)
        case .meat: return NSColor(calibratedRed: 0.72, green: 0.3, blue: 0.24, alpha: 1)
        case .loot: return NSColor(calibratedRed: 0.95, green: 0.82, blue: 0.3, alpha: 1)
        case .stew: return NSColor(calibratedRed: 0.86, green: 0.55, blue: 0.22, alpha: 1)
        }
    }
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
