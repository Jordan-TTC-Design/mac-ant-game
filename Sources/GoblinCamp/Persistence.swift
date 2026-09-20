import Foundation

/// One saved individual: enough to bring the same goblin back (its traits come from breed + seed).
struct SavedGoblin: Codable {
    var id: Int
    var breed: String
    var age: Double
    var seed: UInt64
    /// Only stored when the player renamed it; otherwise the name comes from the seed.
    var name: String?
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
