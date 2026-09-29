import Foundation

/// A piece of gear as saved: which, and how much wear it has left. Older saves wrote just the id.
struct SavedGear: Codable {
    var id: String
    var left: Double?
    /// Put on by hand (on a goblin) / taken off by hand (in the stock): see `GearItem`.
    var pinned: Bool?
    var held: Bool?

    private enum Keys: String, CodingKey { case id, left, pinned, held }

    init(id: String, left: Double?, pinned: Bool = false, held: Bool = false) {
        self.id = id
        self.left = left
        self.pinned = pinned ? true : nil
        self.held = held ? true : nil
    }

    init(from decoder: Decoder) throws {
        if let plain = try? decoder.singleValueContainer().decode(String.self) {
            id = plain
            left = nil
        } else {
            let c = try decoder.container(keyedBy: Keys.self)
            id = try c.decode(String.self, forKey: .id)
            left = try c.decodeIfPresent(Double.self, forKey: .left)
            pinned = try? c.decodeIfPresent(Bool.self, forKey: .pinned)
            held = try? c.decodeIfPresent(Bool.self, forKey: .held)
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
    /// The names of its parents, for the ones born to the princess.
    var parents: String?
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
    /// The same for every place (window, bottom, right, left), by name. `terrain` is the window's, kept for older versions.
    var terrains: [String: TerrainLifeState]?
    /// Gear back in the nest that nobody needed (gear id → count).
    var armory: [String: Int]?
    /// The same with wear (newer saves).
    var armoryItems: [SavedGear]?
    /// The princess's love life.
    var romance: RomanceState?
    /// What the food brought home is still doing (seconds left, by food), and how long before each can be put down again.
    var boosts: [String: Double]?
    var foodCooldowns: [String: Double]?
    /// Which race the camp is (a character id); older saves are goblins.
    var race: String?
    /// Whether the stock is handed out by itself (nil: yes).
    var autoGear: Bool?
}

/// Colony progress in ~/Library/Application Support/GoblinCamp/state.json.
/// Once the camp is kept by the server (server/CAMP.md), the Mac writes camp-local.json instead: the same format, but only
/// its own parts count there (where the camp stands, its land, the game clock); state.json is then the old camp waiting to
/// be moved in (and after that it is renamed state-before-sync.json and kept as a backup).
enum Persistence {
    static let oldCamp = "state.json"
    static let localCamp = "camp-local.json"

    static func url(_ file: String = oldCamp) -> URL {
        // `CAMP_DATA_DIR` moves the saves elsewhere (tests must not touch the real ones)
        if let custom = ProcessInfo.processInfo.environment["CAMP_DATA_DIR"] { return URL(fileURLWithPath: custom).appendingPathComponent(file) }
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("GoblinCamp/\(file)")
    }

    static func load(_ file: String = oldCamp) -> SavedState? {
        guard let data = try? Data(contentsOf: url(file)) else { return nil }
        return try? JSONDecoder().decode(SavedState.self, from: data)
    }

    static func save(_ state: SavedState, _ file: String = oldCamp) {
        do {
            try FileManager.default.createDirectory(at: url(file).deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(state).write(to: url(file), options: .atomic)
        } catch {
            NSLog("GoblinCamp: save failed: \(error)")
        }
    }

    static func clear(_ file: String = oldCamp) {
        try? FileManager.default.removeItem(at: url(file))
    }

    /// The old camp has been moved in (or set aside): keep it as a backup under another name.
    static func retireOldCamp() {
        let backup = url("state-before-sync.json")
        try? FileManager.default.removeItem(at: backup)
        try? FileManager.default.moveItem(at: url(oldCamp), to: backup)
    }
}
