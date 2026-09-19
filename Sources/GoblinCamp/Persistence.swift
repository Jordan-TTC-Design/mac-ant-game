import Foundation

/// One saved individual: enough to bring the same goblin back (its traits come from breed + seed).
struct SavedGoblin: Codable {
    var id: Int
    var breed: String
    var age: Double
    var seed: UInt64
}

struct SavedState: Codable {
    var nestX: Double
    var nestY: Double
    var antCount: Int
    // Added later; older saves lack them and are read as "all plain, all young".
    var goblins: [SavedGoblin]?
    var delivered: Int?
    var nextID: Int?
}

/// Colony progress in ~/Library/Application Support/GoblinCamp/state.json.
enum Persistence {
    private static var url: URL {
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
