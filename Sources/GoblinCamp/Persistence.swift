import Foundation

/// A piece of gear as saved: which, and how much wear it has left. Older saves wrote just the id.
struct SavedGear: Codable {
    var id: String
    var left: Double?

    private enum Keys: String, CodingKey { case id, left }

    init(id: String, left: Double?) { self.id = id; self.left = left }

    init(from decoder: Decoder) throws {
        if let plain = try? decoder.singleValueContainer().decode(String.self) {
            id = plain
            left = nil
        } else {
            let c = try decoder.container(keyedBy: Keys.self)
            id = try c.decode(String.self, forKey: .id)
            left = try c.decodeIfPresent(Double.self, forKey: .left)
        }
    }
}

/// One saved individual: enough to bring the same goblin back (its traits come from breed + seed).
struct SavedGoblin: Codable {
    var id: Int
    var breed: String
    var age: Double
    var seed: UInt64
    /// Always stored, so a later change to the name generator never renames anyone. Older saves lack it: the name then comes from the seed.
    var name: String?
    /// What it wears (slot → gear id).
    var gear: [String: SavedGear]?
}

struct SavedState: Codable {
    var nestX: Double
    var nestY: Double
    var antCount: Int
    // Added later; older saves lack them and are read as "all plain, all young".
    var goblins: [SavedGoblin]?
    var delivered: Int?
    var nextID: Int?
    var princessName: String?
    /// What the goblins brought home from monsters (material id → count) and how many of each monster fell.
    var materials: [String: Int]?
    var kills: [String: Int]?
    /// The most goblins the camp has ever had (the camp window's camp grows with it).
    var peak: Int?
    /// Game time: seconds the camp has been going.
    var playSeconds: Double?
    /// What is in the larder (fish, vegetables) waiting to be cooked.
    var larder: [String: Int]?
    /// What has happened to the camp window's place over the days (see `TerrainLife`).
    var terrain: TerrainLifeState?
    /// Gear back in the nest that nobody needed (gear id → count).
    var armory: [String: Int]?
    /// The same with wear (newer saves).
    var armoryItems: [SavedGear]?
}

/// Colony progress in ~/Library/Application Support/GoblinCamp/state.json.
enum Persistence {
    private static var url: URL {
        // `CAMP_DATA_DIR` moves the saves elsewhere (tests must not touch the real ones)
        if let custom = ProcessInfo.processInfo.environment["CAMP_DATA_DIR"] { return URL(fileURLWithPath: custom).appendingPathComponent("state.json") }
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("GoblinCamp/state.json")
    }

    static func load() -> SavedState? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(SavedState.self, from: data)
    }

    static func save(_ state: SavedState) {
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(state).write(to: url, options: .atomic)
        } catch {
            NSLog("GoblinCamp: save failed: \(error)")
        }
    }

    static func clear() {
        try? FileManager.default.removeItem(at: url)
    }
}
