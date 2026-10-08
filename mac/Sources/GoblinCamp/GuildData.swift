import Foundation

/// The guild as the server sends it (`GET /api/guild`, shared/src/guild.ts `GuildResponse`), only what the Mac's hall uses.
struct GuildInfo: Decodable {
    struct Avatar: Codable, Hashable {
        var race: String
        var sex: String
        var face: String
        var eyes: String
        var brows: String
        var mouth: String
        var hair: String
        var hairColor: String
        var skin: String
        var flame: String?
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

    struct Decor: Codable, Equatable {
        let uid: String
        var kind: String
        var x: Double
        var y: Double
        var flip: Bool?
        var locked: Bool?
    }

    struct Floor: Codable, Equatable {
        var base: String
        var tiles: [String: String]
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
        let points: Int
        let toNext: Int?
        /// Asked and not answered yet (only the leader and officers are sent this).
        let invited: [Invited]
    }

    struct Invited: Decodable {
        let id: String
        let name: String
        let race: String
        let at: String
    }

    /// An invitation this account has (when it is in no guild).
    struct Invite: Decodable {
        let guildId: String
        let name: String
        let badge: String
        let members: Int
        let by: String
        let at: String
    }

    let guild: Guild?
    let invites: [Invite]
    let waitUntil: String?
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
