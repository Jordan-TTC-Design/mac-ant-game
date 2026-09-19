import AppKit

enum FoodKind: String, CaseIterable {
    case water, honey, fruit, meat

    /// What the player can put down from the menu (fruit and meat turn up by themselves).
    static let placeable: [FoodKind] = [.water, .honey]

    var label: String {
        switch self {
        case .water: return "水滴"
        case .honey: return "蜂蜜"
        case .fruit: return "果實"
        case .meat: return "肉"
        }
    }

    var emoji: String {
        switch self {
        case .water: return "💧"
        case .honey: return "🍯"
        case .fruit: return "🍎"
        case .meat: return "🍖"
        }
    }

    /// How many pieces the ants can carry away.
    var initialAmount: Int {
        switch self {
        case .water: return 16
        case .honey: return 24
        case .fruit: return 6
        case .meat: return 12
        }
    }

    /// Radius in points when full (before the ant-size setting).
    var baseRadius: Double {
        switch self {
        case .water: return 9
        case .honey: return 8
        case .fruit: return 10 // the foot of the tree
        case .meat: return 7
        }
    }

    /// Colour of the little piece an ant carries.
    var pieceColor: NSColor {
        switch self {
        case .water: return NSColor(calibratedRed: 0.55, green: 0.78, blue: 0.97, alpha: 1)
        case .honey: return NSColor(calibratedRed: 0.96, green: 0.68, blue: 0.12, alpha: 1)
        case .fruit: return NSColor(calibratedRed: 0.88, green: 0.2, blue: 0.2, alpha: 1)
        case .meat: return NSColor(calibratedRed: 0.72, green: 0.3, blue: 0.24, alpha: 1)
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

    enum Origin {
        /// Put down by the player.
        case placed
        /// A fruit tree: it stays when picked bare, and grows fruit back.
        case tree
        /// What a hunted animal leaves behind.
        case meat
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

    /// The animal with this id, if it is still about.
    func creature(_ id: Int) -> CreatureInfo? {
        creatures.first { $0.id == id }
    }

    /// The food with this id, if any is left.
    func food(_ id: Int) -> FoodSource? {
        foods.first { $0.id == id && $0.amount > 0 }
    }
}
