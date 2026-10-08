/// The guild hall, bit for bit the same as shared/src/guild-hall.ts (and the level table in shared/src/guild.ts): where
/// things stand in it, and what each member's avatar is doing at a moment. Worked out from the time and the members alone,
/// so the Mac shows the same hall at the same moment as every phone, without the server sending positions.
///
/// Positions are in tiles from the hall's top left; an avatar's or a piece's position is where its feet (bottom middle) are.
/// The top `guildWallRows` rows are the wall. `swift run guild-rules-check` checks this against
/// shared/src/guild-hall-fixtures.json.
import Foundation

public let guildWallRows: Double = 2
/// Walking speed, tiles a second.
public let guildWalkSpeed: Double = 1.6
/// Someone there does one thing (walking to it included) for this long.
public let guildActivitySeconds: Double = 24

// ── Levels (GUILD.md §4.1) ───────────────────────────────────────────────────────────────────────────────────────────

public struct GuildLevel {
    public let level, members, width, height, room: Int
}

public let guildLevels: [GuildLevel] = [
    GuildLevel(level: 1, members: 5, width: 32, height: 20, room: 160),
    GuildLevel(level: 2, members: 8, width: 40, height: 24, room: 240),
    GuildLevel(level: 3, members: 12, width: 48, height: 28, room: 340),
    GuildLevel(level: 4, members: 16, width: 56, height: 32, room: 440),
    GuildLevel(level: 5, members: 20, width: 64, height: 36, room: 560),
    GuildLevel(level: 6, members: 25, width: 72, height: 40, room: 700),
    GuildLevel(level: 7, members: 30, width: 80, height: 44, room: 880),
]

public func guildLevel(_ level: Int) -> GuildLevel {
    guildLevels[min(max(level, 1), guildLevels.count) - 1]
}

// ── Where things stand ───────────────────────────────────────────────────────────────────────────────────────────────

public struct HallPoint: Equatable {
    public var x: Double
    public var y: Double
    public init(x: Double, y: Double) { self.x = x; self.y = y }
}

public struct HallPiece {
    /// The furniture id in Resources/Guild/manifest.json.
    public let id: String
    public let x: Double
    public let y: Double
}

public struct HallLayout {
    public let width, height: Int
    public let pieces: [HallPiece]
    /// Where each desk's sitter is, in seat order (members get them by when they joined).
    public let seats: [HallPoint]
    /// Where to stand for a drink, the bench's seats, and the rows free of desks to walk along.
    public let drink: HallPoint
    public let bench: [HallPoint]
    public let aisles: [Double]
}

/// Desks in rows: the first desk row's y, then every deskRowStep tiles; columns from x = 3, every 3 tiles.
private let firstDeskRow = guildWallRows + 2.5
/// At most this many desks side by side; the block of desks stands in the middle of the hall.
private let desksPerRow = 6
private let deskRowStep = 2.5
/// Where the sitter's feet go from the desk's floor point (Resources/Guild/manifest.json: desk seat − anchor, in tiles).
private let deskSeat = HallPoint(x: -3.0 / 16, y: -4.0 / 16)
/// The water elemental's `use` point from its floor point (where a drinker stands).
private let drinkAt = HallPoint(x: 18.0 / 16, y: 0)

public func hallLayout(level: Int) -> HallLayout {
    let rules = guildLevel(level)
    let width = Double(rules.width), height = Double(rules.height), members = rules.members
    var pieces: [HallPiece] = []
    var seats: [HallPoint] = []
    var rows: [Double] = []
    // one desk per member the guild can have, in a block in the middle under the wall; the rest of the floor is for decorating
    let cols = min(desksPerRow, members)
    let left = (width / 2 - Double((cols - 1) * 3) / 2).rounded(.down)
    var r = 0
    while r * cols < members {
        rows.append(firstDeskRow + Double(r) * deskRowStep)
        r += 1
    }
    for y in rows {
        var c = 0
        while c < cols && seats.count < members {
            let x = left + Double(c * 3)
            let seat = HallPoint(x: x + deskSeat.x, y: y + deskSeat.y)
            pieces.append(HallPiece(id: "desk", x: x, y: y))
            pieces.append(HallPiece(id: "stool", x: seat.x, y: seat.y - 0.01)) // (just behind its sitter)
            seats.append(seat)
            c += 1
        }
    }
    let aisles = [(rows.first ?? .nan) - deskRowStep / 2] + rows.map { $0 + deskRowStep / 2 }
    let bottom = height - 0.9
    let bench = [HallPoint(x: 2.5, y: bottom), HallPoint(x: 3.5, y: bottom)]
    pieces += [
        HallPiece(id: "fireplace", x: width / 2, y: guildWallRows + 0.2),
        HallPiece(id: "banner", x: 3, y: guildWallRows - 0.2),
        HallPiece(id: "banner", x: width - 3, y: guildWallRows - 0.2),
        HallPiece(id: "bookshelf", x: 1.2, y: guildWallRows + 0.4),
        HallPiece(id: "water_dispenser", x: width - 2.8, y: guildWallRows + 0.6),
        HallPiece(id: "bench", x: 3, y: bottom),
        HallPiece(id: "plant", x: 0.8, y: bottom),
        HallPiece(id: "plant", x: width - 0.8, y: bottom),
        HallPiece(id: "rug", x: width / 2, y: height - 1.2),
    ]
    let drink = HallPoint(x: width - 2.8 + drinkAt.x, y: guildWallRows + 0.6 + drinkAt.y)
    return HallLayout(width: rules.width, height: rules.height, pieces: pieces, seats: seats, drink: drink, bench: bench, aisles: aisles)
}

// ── What each one is doing ───────────────────────────────────────────────────────────────────────────────────────────

public struct HallMember {
    public let id: String
    /// "focus", "online", "away" or "offline".
    public let presence: String
    /// Their place in the seat order.
    public let seat: Int
    public init(id: String, presence: String, seat: Int) { self.id = id; self.presence = presence; self.seat = seat }
}

/// What an avatar is doing right now.
public struct HallPose {
    public var x, y: Double
    /// "idle", "walk", "sit", "type", "doze", "drink", "wave", "stretch", "chat" or "cheer".
    public var anim: String
    /// "front", "back" or "side".
    public var dir: String
    /// Mirror the side frames (they face left as drawn).
    public var flip: Bool
    /// Seconds since this anim began (for its frames).
    public var t: Double
    public init(x: Double, y: Double, anim: String, dir: String, flip: Bool, t: Double) {
        self.x = x; self.y = y; self.anim = anim; self.dir = dir; self.flip = flip; self.t = t
    }
}

/// A number from 0 to 1 for these words (FNV-1a, then mixed so that "a|1" and "a|2" land far apart), the same everywhere.
/// The parts are joined by "|" over their code points (as JavaScript's `for (const ch of …)`); pass numbers written the way
/// JavaScript writes them (whole numbers with no ".0", see `jsNumber`).
public func hallHash(_ parts: [String]) -> Double {
    var h: UInt32 = 0x811c9dc5
    for ch in parts.joined(separator: "|").unicodeScalars {
        h ^= ch.value
        h = h &* 0x01000193
    }
    h ^= h >> 16
    h = h &* 0x85ebca6b
    h ^= h >> 13
    h = h &* 0xc2b2ae35
    h ^= h >> 16
    return Double(h) / 0x100000000
}

/// A whole number as JavaScript writes it (`String(k)`), for hallHash.
private func jsNumber(_ k: Double) -> String { k == 0 ? "0" : String(Int(k)) }

/// Math.hypot as JavaScript engines work it out (scaled by the largest, Kahan-summed), so distances agree to the last bit.
func jsHypot(_ a: Double, _ b: Double) -> Double {
    if a.isInfinite || b.isInfinite { return .infinity }
    if a.isNaN || b.isNaN { return .nan }
    let big = max(abs(a), abs(b))
    if big == 0 { return 0 }
    var sum = 0.0, compensation = 0.0
    for v in [abs(a), abs(b)] {
        let n = v / big
        let summand = n * n - compensation
        let preliminary = sum + summand
        compensation = (preliminary - sum) - summand
        sum = preliminary
    }
    return sum.squareRoot() * big
}

/// Truthy as a JavaScript number is (not 0, not NaN).
private func truthy(_ v: Double) -> Bool { v != 0 && !v.isNaN }

private struct Doing {
    var x, y: Double
    var anim: String
    var dir: String
    var point: HallPoint { HallPoint(x: x, y: y) }
    init(_ p: HallPoint, anim: String, dir: String) { x = p.x; y = p.y; self.anim = anim; self.dir = dir }
}

/// What someone who is there chooses to do in their `k`th activity.
private func activity(_ layout: HallLayout, _ m: HallMember, _ k: Double, _ present: [HallMember]) -> Doing {
    let seat = layout.seats[m.seat % layout.seats.count]
    let kk = jsNumber(k)
    let roll = hallHash([m.id, kk])
    let others = present.filter { $0.id != m.id }
    if roll < 0.3 { return Doing(seat, anim: "sit", dir: "front") }
    if roll < 0.45 { return Doing(layout.drink, anim: "drink", dir: "front") }
    if roll < 0.6 {
        return Doing(layout.bench[Int((hallHash([m.id, kk, "bench"]) * Double(layout.bench.count)).rounded(.down))], anim: "sit", dir: "front")
    }
    if roll < 0.8 && !others.isEmpty {
        let friend = others[Int((hallHash([m.id, kk, "who"]) * Double(others.count)).rounded(.down))]
        let at = layout.seats[friend.seat % layout.seats.count]
        return Doing(HallPoint(x: at.x + 1.1, y: at.y), anim: "chat", dir: "side")
    }
    if roll < 0.88 { return Doing(HallPoint(x: seat.x - 1.1, y: seat.y), anim: "stretch", dir: "front") }
    let aisle = layout.aisles[Int((hallHash([m.id, kk, "aisle"]) * Double(layout.aisles.count)).rounded(.down))]
    return Doing(HallPoint(x: 1.5 + hallHash([m.id, kk, "x"]) * Double(layout.width - 3), y: aisle), anim: "idle", dir: "front")
}

/// The way from `a` to `b`: to the nearest aisle, along it, then to `b` (so nobody walks through a desk).
public func hallPath(_ layout: HallLayout, from a: HallPoint, to b: HallPoint) -> [HallPoint] {
    if abs(a.y - b.y) < 0.01 { return [a, b] }
    func nearest(_ y: Double) -> Double {
        layout.aisles.dropFirst().reduce(layout.aisles[0]) { best, x in abs(x - y) < abs(best - y) ? x : best }
    }
    let ay = nearest(a.y)
    let by = nearest(b.y)
    var pts = [a, HallPoint(x: a.x, y: ay)]
    if ay != by {
        // (between aisles, go round the block of desks on whichever side is nearer)
        let desks = layout.pieces.filter { $0.id == "desk" }.map(\.x)
        let side = (a.x + b.x) / 2 < Double(layout.width) / 2 ? desks.min()! - 2 : desks.max()! + 2
        pts += [HallPoint(x: side, y: ay), HallPoint(x: side, y: by)]
    }
    pts += [HallPoint(x: b.x, y: by), b]
    return pts.indices.filter { i in i == 0 || jsHypot(pts[i].x - pts[i - 1].x, pts[i].y - pts[i - 1].y) > 0.01 }.map { pts[$0] }
}

private func length(_ path: [HallPoint]) -> Double {
    var d = 0.0
    for i in path.indices.dropFirst() { d += jsHypot(path[i].x - path[i - 1].x, path[i].y - path[i - 1].y) }
    return d
}

/// Where along `path` one is after walking `d` tiles, and which way they face.
private func along(_ path: [HallPoint], _ distance: Double) -> (at: HallPoint, dir: String, flip: Bool) {
    var d = distance
    for i in path.indices.dropFirst() {
        let p = path[i - 1], q = path[i]
        let seg = jsHypot(q.x - p.x, q.y - p.y)
        if d <= seg || i == path.count - 1 {
            let f = truthy(seg) ? min(1, d / seg) : 1
            let dx = q.x - p.x
            let dy = q.y - p.y
            let dir = abs(dx) >= abs(dy) ? "side" : dy < 0 ? "back" : "front"
            return (HallPoint(x: p.x + dx * f, y: p.y + dy * f), dir, dx > 0)
        }
        d -= seg
    }
    return (path[path.count - 1], "front", false)
}

/// What member `m` is doing at `now` (ms since 1970): nil when offline (not in the hall). `present` is everyone in the hall
/// (for visiting a friend's desk).
public func hallPose(_ layout: HallLayout, _ m: HallMember, present: [HallMember], now: Double) -> HallPose? {
    if m.presence == "offline" { return nil }
    let seat = layout.seats[m.seat % layout.seats.count]
    let secs = now / 1000
    if m.presence == "focus" { return HallPose(x: seat.x, y: seat.y, anim: "type", dir: "front", flip: false, t: secs) }
    if m.presence == "away" { return HallPose(x: seat.x, y: seat.y, anim: "doze", dir: "front", flip: false, t: secs) }
    let shifted = secs + hallHash([m.id, "offset"]) * guildActivitySeconds
    let k = (shifted / guildActivitySeconds).rounded(.down)
    let into = shifted - k * guildActivitySeconds
    let from = activity(layout, m, k - 1, present)
    let to = activity(layout, m, k, present)
    let path = hallPath(layout, from: from.point, to: to.point)
    // (a long way in a big hall: a brisker pace, so it is walked in most of the activity's time and nobody jumps)
    let far = length(path)
    let pace = max(guildWalkSpeed, far / (guildActivitySeconds * 0.8))
    let walk = far / pace
    if into < walk {
        let (at, dir, flip) = along(path, into * pace)
        return HallPose(x: at.x, y: at.y, anim: "walk", dir: dir, flip: flip, t: into)
    }
    return HallPose(x: to.x, y: to.y, anim: to.anim, dir: to.dir, flip: false, t: into - walk)
}

// ── Walking by hand (GUILD.md §3.1) ──────────────────────────────────────────────────────────────────────────────────

private struct Rect { let x0, y0, x1, y1: Double }

/// Where feet cannot go: the desks (and what stands along the back wall is out of reach anyway, below the wall's edge).
private func hallSolids(_ layout: HallLayout) -> [Rect] {
    layout.pieces.filter { $0.id == "desk" }.map { Rect(x0: $0.x - 1.25, y0: $0.y - 0.6, x1: $0.x + 1.25, y1: $0.y) }
}

private func walkable(_ layout: HallLayout, _ p: HallPoint, _ solids: [Rect]) -> Bool {
    if p.x < 0.4 || p.x > Double(layout.width) - 0.4 || p.y < guildWallRows + 0.5 || p.y > Double(layout.height) - 0.1 { return false }
    return !solids.contains { r in p.x > r.x0 && p.x < r.x1 && p.y > r.y0 && p.y < r.y1 }
}

/// Whether feet may stand at `p`.
public func hallWalkable(_ layout: HallLayout, _ p: HallPoint) -> Bool { walkable(layout, p, hallSolids(layout)) }

/// A step from `p` by (dx, dy), sliding along whatever is in the way.
public func hallStep(_ layout: HallLayout, _ p: HallPoint, dx: Double, dy: Double) -> HallPoint {
    let solids = hallSolids(layout)
    let both = HallPoint(x: p.x + dx, y: p.y + dy)
    if walkable(layout, both, solids) { return both }
    let sideways = HallPoint(x: p.x + dx, y: p.y)
    if truthy(dx) && walkable(layout, sideways, solids) { return sideways }
    let upDown = HallPoint(x: p.x, y: p.y + dy)
    if truthy(dy) && walkable(layout, upDown, solids) { return upDown }
    return p
}

/// What pressing A does near `p`: sit on a seat within reach (snapping onto it), drink at the water elemental, or wave.
public func hallInteract(_ layout: HallLayout, _ p: HallPoint, extraSeats: [HallPoint] = []) -> (anim: String, at: HallPoint) {
    // (the nearest, the first of equals, as the TypeScript's stable sort leaves it)
    var near: (s: HallPoint, d: Double)?
    for s in layout.seats + layout.bench + extraSeats {
        let d = jsHypot(s.x - p.x, s.y - p.y)
        if near == nil || d < near!.d { near = (s, d) }
    }
    if let near, near.d < 1.3 { return ("sit", near.s) }
    if jsHypot(layout.drink.x - p.x, layout.drink.y - p.y) < 1.2 { return ("drink", layout.drink) }
    return ("wave", p)
}
