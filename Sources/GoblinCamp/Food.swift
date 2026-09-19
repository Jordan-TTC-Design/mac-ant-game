import AppKit

enum FoodKind: String, CaseIterable {
    case water, honey

    var label: String {
        switch self {
        case .water: return "水滴"
        case .honey: return "蜂蜜"
        }
    }

    var emoji: String {
        switch self {
        case .water: return "💧"
        case .honey: return "🍯"
        }
    }

    /// How many pieces the ants can carry away.
    var initialAmount: Int {
        switch self {
        case .water: return 16
        case .honey: return 24
        }
    }

    /// Radius in points when full (before the ant-size setting).
    var baseRadius: Double {
        switch self {
        case .water: return 9
        case .honey: return 8
        }
    }

    /// Colour of the little piece an ant carries.
    var pieceColor: NSColor {
        switch self {
        case .water: return NSColor(calibratedRed: 0.55, green: 0.78, blue: 0.97, alpha: 1)
        case .honey: return NSColor(calibratedRed: 0.96, green: 0.68, blue: 0.12, alpha: 1)
        }
    }
}

/// A patch of food on the desktop. Coordinates are global screen coordinates.
struct FoodSource {
    let id: Int
    let kind: FoodKind
    var pos: CGPoint
    var amount: Int
    /// An ant has found it and is on her way home with the news.
    var scouted = false
    /// The news reached the nest, so nestmates are on the way (and other finders simply join in).
    var reported = false

    /// It shrinks as the ants carry it off, but never below 40% of its size until it is gone.
    func radius(scale: Double) -> Double {
        kind.baseRadius * scale * (0.4 + 0.6 * (Double(amount) / Double(kind.initialAmount)).squareRoot())
    }

    /// An ant this close to the food notices it.
    func senseRadius(scale: Double) -> Double { radius(scale: scale) + 9 }
}

/// What an ant can see of the world on each update.
struct AntWorld {
    let nest: CGPoint
    let walkable: [CGRect]
    let foods: [FoodSource]
    /// Food size follows the ant-size setting a little, so big ants do not swamp small food.
    let foodScale: Double

    /// The food with this id, if any is left.
    func food(_ id: Int) -> FoodSource? {
        foods.first { $0.id == id && $0.amount > 0 }
    }
}
