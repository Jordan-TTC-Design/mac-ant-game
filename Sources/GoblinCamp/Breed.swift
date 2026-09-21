import Foundation

/// How a breed differs from a plain goblin. Multipliers are relative to the plain goblin (1.0).
struct BreedStats: Decodable {
    var speed = 1.0
    /// How far away food is noticed.
    var sense = 1.0
    /// How often it goes home to rest (higher = more often).
    var rest = 1.0
    var lifespan = 1.0
    /// Pieces of food carried per trip.
    var carry = 1
    /// Extra helpers called when it brings news of food.
    var recruit = 0
    /// How hard it hits when hunting (1 = a plain goblin).
    var might = 1.0
    /// How many hits it takes before it goes down.
    var health = 3.0

    init() {}

    private enum Keys: String, CodingKey { case speed, sense, rest, lifespan, carry, recruit, might, health }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        speed = try c.decodeIfPresent(Double.self, forKey: .speed) ?? 1
        sense = try c.decodeIfPresent(Double.self, forKey: .sense) ?? 1
        rest = try c.decodeIfPresent(Double.self, forKey: .rest) ?? 1
        lifespan = try c.decodeIfPresent(Double.self, forKey: .lifespan) ?? 1
        carry = try c.decodeIfPresent(Int.self, forKey: .carry) ?? 1
        recruit = try c.decodeIfPresent(Int.self, forKey: .recruit) ?? 0
        might = try c.decodeIfPresent(Double.self, forKey: .might) ?? 1
        health = try c.decodeIfPresent(Double.self, forKey: .health) ?? 3
    }
}

/// A kind of inhabitant: how common it is, what it is good at, and how it looks.
struct Breed {
    let id: String
    let name: String
    /// Share of births (out of the total weight).
    let weight: Double
    /// How much the colony's food wealth raises this breed's share (0 = not at all).
    let prosperityBoost: Double
    let stats: BreedStats
    /// nil for the vector ants.
    let sprites: SpriteRole?
    /// One line about it, shown in the roster.
    let blurb: String

    static let plain = Breed(id: "common", name: "平民", weight: 100, prosperityBoost: 0, stats: BreedStats(), sprites: nil, blurb: "")
}

/// What a breed is like in daily life: what it likes to do when there is nothing to do, and who it picks fights with.
enum Personality {
    case plain
    /// The clever ones: no scuffles; they read, fish and think.
    case calm
    /// The strong ones: love a scuffle.
    case brute
    /// The quick ones: love to play and run about.
    case lively
    /// The golden ones: they do not scuffle with the common sort, they give orders and are waited on.
    case boss

    init(breedID: String) {
        switch breedID {
        case "sage": self = .calm
        case "brute": self = .brute
        case "scout": self = .lively
        case "golden": self = .boss
        default: self = .plain
        }
    }
}

/// The numbers one individual actually plays with: its breed's stats with a little personal variation.
struct Traits {
    let personality: Personality
    let speed: Double
    let sense: Double
    let rest: Double
    let carry: Int
    let recruit: Int
    let might: Double
    let maxHealth: Double
    /// Seconds it lives.
    let lifespan: Double

    /// A plain one lives a day (real time, counted only while the app runs). `CAMP_LIFESPAN` (seconds) overrides
    /// it for testing.
    static var baseLifespan: Double {
        if let s = ProcessInfo.processInfo.environment["CAMP_LIFESPAN"], let v = Double(s), v > 0 { return v }
        return 86_400
    }

    /// Deterministic for a given seed, so a saved colony comes back with the same individuals.
    static func make(for breed: Breed, seed: UInt64) -> Traits {
        var rng = SeededRandom(seed: seed)
        func jitter(_ spread: Double) -> Double { 1 + (rng.next() * 2 - 1) * spread }
        let stats = breed.stats
        return Traits(personality: Personality(breedID: breed.id), speed: stats.speed * jitter(0.08), sense: stats.sense * jitter(0.08), rest: stats.rest * jitter(0.15),
                      carry: stats.carry, recruit: stats.recruit, might: stats.might * jitter(0.10), maxHealth: stats.health,
                      lifespan: baseLifespan * stats.lifespan * jitter(0.10))
    }
}

enum Breeding {
    /// Picks the breed of a newborn. Rare breeds get likelier as the colony brings home more food, and every
    /// birth has a small chance of a random "mutation" into any non-plain breed.
    static func roll(from breeds: [Breed], delivered: Int) -> Int {
        guard breeds.count > 1 else { return 0 }
        // `CAMP_BREEDS=common:40,scout:20,sage:15,golden:5`: fixed shares by breed id (tests)
        if let spec = ProcessInfo.processInfo.environment["CAMP_BREEDS"] {
            var shares: [String: Double] = [:]
            for part in spec.split(separator: ",") {
                let pair = part.split(separator: ":")
                if pair.count == 2, let v = Double(pair[1]) { shares[String(pair[0])] = v }
            }
            let weights = breeds.map { shares[$0.id] ?? 0 }
            var pick = Double.random(in: 0..<max(0.001, weights.reduce(0, +)))
            for (i, w) in weights.enumerated() { pick -= w; if pick < 0 { return i } }
            return 0
        }
        let mutable = breeds.indices.filter { $0 > 0 && breeds[$0].weight > 0 }
        if let pick = mutable.randomElement(), Double.random(in: 0..<1) < 0.02 { return pick }
        let wealth = min(2.0, Double(delivered) / 60) // 0 ... 2, reached after 120 pieces
        let weights = breeds.enumerated().map { $0.offset == 0 ? $0.element.weight : $0.element.weight * (1 + wealth * $0.element.prosperityBoost) }
        var pick = Double.random(in: 0..<weights.reduce(0, +))
        for (i, w) in weights.enumerated() {
            pick -= w
            if pick < 0 { return i }
        }
        return 0
    }
}
