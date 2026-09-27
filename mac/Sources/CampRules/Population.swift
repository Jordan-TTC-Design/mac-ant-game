import Foundation

/// Births and deaths over time: a copy of shared/src/camp/population.ts, with the same arithmetic in the same order
/// (times are milliseconds since 1970 as Doubles, like JavaScript numbers). See that file for the rules.
public struct CampResident: Equatable {
    public let id: Int
    public let breed: String
    public let seed: UInt32
    public let bornAt: Double
    public let diesAt: Double?
    public var diedAt: Double?
    public init(id: Int, breed: String, seed: UInt32, bornAt: Double, diesAt: Double?, diedAt: Double? = nil) {
        self.id = id; self.breed = breed; self.seed = seed; self.bornAt = bornAt; self.diesAt = diesAt; self.diedAt = diedAt
    }
}

public struct CampPlace: Equatable {
    public let race: String
    public let key: String
    public let startedAt: Double
    public let birthMinutes: Double
    public let cap: Int
    public init(race: String, key: String, startedAt: Double, birthMinutes: Double, cap: Int) {
        self.race = race; self.key = key; self.startedAt = startedAt; self.birthMinutes = birthMinutes; self.cap = cap
    }
}

public struct CampPopulation: Equatable {
    public var residents: [CampResident]
    public var nextId: Int
    public var nextSlot: Int
    public var peak: Int
    public var alive: [CampResident] { residents.filter { $0.diedAt == nil } }
    public init(residents: [CampResident], nextId: Int, nextSlot: Int, peak: Int) {
        self.residents = residents; self.nextId = nextId; self.nextSlot = nextSlot; self.peak = peak
    }
}

public enum Population {
    private static let hour = 3_600_000.0
    private static let minute = 60_000.0

    public static func residentFor(_ place: CampPlace, campSeed: Int, slot: Int, id: Int, bornAt: Double) -> CampResident {
        let rules = Races.rules(place.race)
        var random = CampRandom.seeded([String(campSeed), place.key, "birth", String(slot)])
        let breed = CampRandom.pickWeighted(&random, rules.breeds) { $0.weight }
        let seed = UInt32(floor(random.next() * 4294967296))
        let jitter = 0.9 + 0.2 * random.next()
        let diesAt: Double? = rules.ages ? bornAt + floor(Races.baseLifespanHours * hour * breed.lifespan * jitter) : nil
        return CampResident(id: id, breed: breed.id, seed: seed, bornAt: bornAt, diesAt: diesAt, diedAt: nil)
    }

    public static func startHome(race: String, campSeed: Int, startedAt: Double) -> (place: CampPlace, population: CampPopulation) {
        let rules = Races.rules(race)
        let place = CampPlace(race: race, key: "home", startedAt: startedAt, birthMinutes: rules.homeBirthMinutes, cap: rules.homeCap)
        let startPlace = CampPlace(race: race, key: "home-start", startedAt: startedAt, birthMinutes: rules.homeBirthMinutes, cap: rules.homeCap)
        let starters = (0..<2).map { residentFor(startPlace, campSeed: campSeed, slot: $0, id: $0 + 1, bornAt: startedAt) }
        return (place, CampPopulation(residents: starters, nextId: 3, nextSlot: 1, peak: 2))
    }

    /// Moves a place forward to `to` (deaths of age and births, in time order). Returns who was born and who died.
    @discardableResult
    public static func advance(_ place: CampPlace, _ population: inout CampPopulation, campSeed: Int, to: Double) -> (born: [CampResident], died: [CampResident]) {
        let interval = place.birthMinutes * minute
        var born: [CampResident] = []
        var died: [CampResident] = []
        var aliveCount = population.residents.reduce(0) { $0 + ($1.diedAt == nil ? 1 : 0) }

        for _ in 0..<1_000_000 {
            var nextDeath = Double.infinity
            for r in population.residents where r.diedAt == nil { if let d = r.diesAt, d < nextDeath { nextDeath = d } }
            let slotAt = place.startedAt + Double(population.nextSlot) * interval
            if min(nextDeath, slotAt) > to { break }

            if nextDeath <= slotAt {
                for i in population.residents.indices where population.residents[i].diedAt == nil && population.residents[i].diesAt == nextDeath {
                    population.residents[i].diedAt = nextDeath
                    died.append(population.residents[i])
                    aliveCount -= 1
                }
                continue
            }

            if aliveCount < place.cap {
                let baby = residentFor(place, campSeed: campSeed, slot: population.nextSlot, id: population.nextId, bornAt: slotAt)
                population.nextId += 1
                population.residents.append(baby)
                aliveCount += 1
                born.append(baby)
                if aliveCount > population.peak { population.peak = aliveCount }
                population.nextSlot += 1
            } else {
                let until = min(nextDeath, to + interval)
                population.nextSlot = max(population.nextSlot + 1, Int(ceil((until - place.startedAt) / interval)))
            }
        }
        return (born, died)
    }

    /// Residents falling in battle at `at`.
    @discardableResult
    public static func fall(_ population: inout CampPopulation, ids: [Int], at: Double) -> [CampResident] {
        var gone: [CampResident] = []
        for i in population.residents.indices where population.residents[i].diedAt == nil && ids.contains(population.residents[i].id) {
            population.residents[i].diedAt = at
            gone.append(population.residents[i])
        }
        return gone
    }
}
