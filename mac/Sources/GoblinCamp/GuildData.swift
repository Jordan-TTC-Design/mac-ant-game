import Foundation

/// The guild as the server sends it (`GET /api/guild`, shared/src/guild.ts `GuildResponse`), only what the Mac's hall uses.
struct GuildInfo: Decodable {
    struct Avatar: Codable, Hashable {
        let race: String
        let sex: String
        let face: String
        let eyes: String
        let brows: String
        let mouth: String
        let hair: String
        let hairColor: String
        let skin: String
        let flame: String?
    }

    struct Member: Decodable {
        let id: String
        let name: String
        let race: String
        let role: String
        let joinedAt: String
        let avatar: Avatar
        let presence: String
        let seenAt: String?
        let focusToday: Int
    }

    struct Decor: Decodable {
        let uid: String
        let kind: String
        let x: Double
        let y: Double
        let flip: Bool?
        let locked: Bool?
    }

    struct Floor: Decodable {
        let base: String
        let tiles: [String: String]
    }

    struct Rules: Decodable {
        let members: Int
        let width: Int
        let height: Int
        let room: Int
    }

    struct Guild: Decodable {
        let id: String
        let name: String
        let badge: String
        let level: Int
        let rules: Rules
        let members: [Member]
        let decor: [Decor]
        let decorVersion: Int
        let floor: Floor
        let wall: String
        let races: [String]
    }

    let guild: Guild?
    let avatar: Avatar
    let avatarChosen: Bool
}

/// One thing said in the hall (shared/src/guild.ts `GuildChatLine`).
struct GuildChatLine: Decodable, Equatable {
    let id: String
    let userId: String
    let name: String
    let text: String
    let at: String
}

/// A hand-walked avatar as a page or a Mac sends it (shared/src/guild.ts `GuildMove`).
struct GuildMove: Equatable {
    var x: Double
    var y: Double
    var dir: String
    var flip: Bool
    var anim: String

    init(x: Double, y: Double, dir: String, flip: Bool, anim: String) {
        self.x = x
        self.y = y
        self.dir = dir
        self.flip = flip
        self.anim = anim
    }

    init?(event: [String: Any]) {
        guard let x = (event["x"] as? NSNumber)?.doubleValue, let y = (event["y"] as? NSNumber)?.doubleValue,
              let dir = event["dir"] as? String, let anim = event["anim"] as? String else { return nil }
        self.init(x: x, y: y, dir: dir, flip: (event["flip"] as? Bool) ?? false, anim: anim)
    }

    var json: [String: Any] { ["type": "guild.move", "x": x, "y": y, "dir": dir, "flip": flip, "anim": anim] }
}

/// The guild's timings, the same as shared/src/guild.ts.
enum GuildTiming {
    /// A Mac that has said nothing for this long counts as offline (PRESENCE_TTL_SECONDS).
    static let presenceTTL: TimeInterval = 300
    /// Hand-walking: send at most this often, at least this often, and others' that went quiet this long are let go.
    static let moveEvery: TimeInterval = 0.12
    static let moveHeartbeat: TimeInterval = 4
    static let moveStale: TimeInterval = 12
    static let moveIdle: TimeInterval = 120
    /// A line stays over its sayer's head this long (GUILD_BUBBLE_MS).
    static let bubble: TimeInterval = 6
    static let sayMax = 120
}

extension ISO8601DateFormatter {
    /// The server's times (with milliseconds).
    static let guild: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
}
