/// The numbers each race lives by: a copy of shared/src/camp/races.ts (server/CAMP.md §11). fixtures.json holds the
/// TypeScript table, and `camp-rules-check` compares the two, so change both together.
public struct BreedRule: Equatable {
    public let id: String
    public let weight: Double
    public let lifespan: Double
}

public struct RaceRules: Equatable {
    public let homeBirthMinutes: Double
    public let homeCap: Int
    public let stage2: Int
    public let stage3: Int
    public let ages: Bool
    public let raidEveryMinutes: Double
    public let cellCap: Int
    public let cellMin: Int
    public let nestBirthMinutes: Double
    public let townCap: Int
    public let townBirthMinutes: Double
    public let breeds: [BreedRule]
}

public enum Races {
    /// A plain resident lives this long; each breed multiplies it.
    public static let baseLifespanHours = 48.0

    private static let goblinBreeds = [
        BreedRule(id: "common", weight: 100, lifespan: 1),
        BreedRule(id: "scout", weight: 10, lifespan: 0.8),
        BreedRule(id: "brute", weight: 8, lifespan: 1.25),
        BreedRule(id: "sage", weight: 5, lifespan: 1.15),
        BreedRule(id: "golden", weight: 1, lifespan: 2),
    ]

    public static let all: [String: RaceRules] = [
        "goblin": RaceRules(homeBirthMinutes: 5, homeCap: 300, stage2: 50, stage3: 150, ages: true, raidEveryMinutes: 90,
                            cellCap: 50, cellMin: 5, nestBirthMinutes: 15, townCap: 100, townBirthMinutes: 5, breeds: goblinBreeds),
        "elf": RaceRules(homeBirthMinutes: 10, homeCap: 180, stage2: 30, stage3: 90, ages: true, raidEveryMinutes: 120,
                         cellCap: 30, cellMin: 3, nestBirthMinutes: 30, townCap: 60, townBirthMinutes: 10, breeds: [
                            BreedRule(id: "common", weight: 100, lifespan: 2),
                            BreedRule(id: "scout", weight: 10, lifespan: 1.8),
                            BreedRule(id: "brute", weight: 8, lifespan: 2.5),
                            BreedRule(id: "sage", weight: 5, lifespan: 2.3),
                            BreedRule(id: "golden", weight: 1, lifespan: 4),
                         ]),
        "undead": RaceRules(homeBirthMinutes: 7.5, homeCap: 240, stage2: 40, stage3: 120, ages: false, raidEveryMinutes: 90,
                            cellCap: 40, cellMin: 4, nestBirthMinutes: 22.5, townCap: 80, townBirthMinutes: 7.5,
                            breeds: goblinBreeds.map { BreedRule(id: $0.id, weight: $0.weight, lifespan: 1) }),
    ]

    public static func rules(_ race: String) -> RaceRules { all[race] ?? all["goblin"]! }

    /// Which of the camp's three looks it has grown into for the most residents it ever had.
    public static func campStage(_ race: String, peak: Int) -> Int {
        let r = rules(race)
        return peak >= r.stage3 ? 3 : (peak >= r.stage2 ? 2 : 1)
    }
}
