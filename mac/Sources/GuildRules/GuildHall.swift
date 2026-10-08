/// The guild hall, bit for bit the same as shared/src/guild-hall.ts (and the level table in shared/src/guild.ts): what each
/// member's avatar is doing at a moment, worked out from the time, the members and what stands in the hall, so the Mac shows
/// the same hall at the same moment as every phone, without the server sending positions.
///
/// Everything in the hall is a decoration the members put down, so the desks, the water and the seats are wherever the
/// members put them: `hallFurnishing` works out from the pieces where one works, drinks and sits, and what is in the way.
/// Nobody walks through anything: every way is found round it (`hallRoute`).
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

// ── What stands in the hall ──────────────────────────────────────────────────────────────────────────────────────────

public struct HallPoint: Equatable {
    public var x: Double
    public var y: Double
    public init(x: Double, y: Double) { self.x = x; self.y = y }
}

/// Somewhere feet cannot go (tiles).
public struct HallRect {
    public let x0, y0, x1, y1: Double
    public init(x0: Double, y0: Double, x1: Double, y1: Double) { self.x0 = x0; self.y0 = y0; self.x1 = x1; self.y1 = y1 }
}

/// What the pieces in the hall make of it: where one works (a desk's sitter, in the hall's order), sits, drinks, cannot go.
public struct HallFurnishing {
    public var desks: [HallPoint]
    public var seats: [HallPoint]
    public var drinks: [HallPoint]
    public var solids: [HallRect]
    public init(desks: [HallPoint], seats: [HallPoint], drinks: [HallPoint], solids: [HallRect]) {
        self.desks = desks; self.seats = seats; self.drinks = drinks; self.solids = solids
    }
    public static let empty = HallFurnishing(desks: [], seats: [], drinks: [], solids: [])
}

public struct HallLayout {
    public let width, height: Int
    public let desks, seats, drinks: [HallPoint]
    public let solids: [HallRect]
    /// For each tile of the hall, the solids that reach into it: a point is only checked against those (a hall can have hundreds
    /// of pieces, and the routes ask about thousands of points). The answers are the same as checking every solid.
    fileprivate let solidsAt: [[Int]]

    fileprivate init(width: Int, height: Int, desks: [HallPoint], seats: [HallPoint], drinks: [HallPoint], solids: [HallRect]) {
        self.width = width; self.height = height; self.desks = desks; self.seats = seats; self.drinks = drinks; self.solids = solids
        var at = [[Int]](repeating: [], count: max(0, width * height))
        for (i, r) in solids.enumerated() {
            let x0 = max(0, Int(floor(r.x0))), x1 = min(width - 1, Int(floor(r.x1)))
            let y0 = max(0, Int(floor(r.y0))), y1 = min(height - 1, Int(floor(r.y1)))
            if x0 > x1 || y0 > y1 { continue }
            for ty in y0...y1 { for tx in x0...x1 { at[ty * width + tx].append(i) } }
        }
        solidsAt = at
    }
}

public func hallLayout(level: Int, furnishing: HallFurnishing = .empty) -> HallLayout {
    let rules = guildLevel(level)
    return HallLayout(width: rules.width, height: rules.height, desks: furnishing.desks, seats: furnishing.seats, drinks: furnishing.drinks, solids: furnishing.solids)
}

/// What a piece is, as far as the hall's life goes (its art's size in pixels, and what it is for).
public struct HallPieceSpec {
    public var w, h: Double
    /// `living`: one of the little living things (they are not in the way).
    public var flat, wall, ceiling, living: Bool
    /// Where a sitter's feet go on it (sprite pixels), for things to sit on.
    public var seat: HallPoint?
    /// A desk: one works sitting behind it. A water source: one drinks beside it.
    public var desk, drink: Bool
    public init(w: Double, h: Double, flat: Bool, wall: Bool, ceiling: Bool, living: Bool, seat: HallPoint?, desk: Bool, drink: Bool) {
        self.w = w; self.h = h; self.flat = flat; self.wall = wall; self.ceiling = ceiling; self.living = living
        self.seat = seat; self.desk = desk; self.drink = drink
    }
}

/// A piece put down (where its feet are, in tiles; turned or not).
public struct HallPlacedPiece {
    public var x, y: Double
    public var flip: Bool
    public var spec: HallPieceSpec
    public init(x: Double, y: Double, flip: Bool, spec: HallPieceSpec) { self.x = x; self.y = y; self.flip = flip; self.spec = spec }
}

/// From a desk's floor point to where its sitter's feet go, and from a water source to where a drinker stands (tiles).
private let deskSeat = HallPoint(x: -3.0 / 16, y: -4.0 / 16)
private let drinkAt = 1.1

/// Where one works, sits and drinks among these pieces, and what of them is in the way, in their order.
public func hallFurnishing(_ pieces: [HallPlacedPiece]) -> HallFurnishing {
    var out = HallFurnishing.empty
    for piece in pieces {
        let x = piece.x, y = piece.y, flip = piece.flip, spec = piece.spec
        if spec.desk { out.desks.append(HallPoint(x: x + (flip ? -deskSeat.x : deskSeat.x), y: y + deskSeat.y)) }
        if let seat = spec.seat {
            let dx = (seat.x - spec.w / 2) / 16
            out.seats.append(HallPoint(x: x + (flip ? -dx : dx), y: y + (seat.y - spec.h) / 16))
        }
        if spec.drink { out.drinks.append(HallPoint(x: x + (flip ? -drinkAt : drinkAt), y: y)) }
        if spec.flat || spec.wall || spec.ceiling || spec.living { continue }
        let half = max(0.2, (spec.w / 2 - 2) / 16)
        out.solids.append(HallRect(x0: x - half, y0: y - min(spec.h, 10) / 16, x1: x + half, y1: y))
    }
    return out
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

public struct HallMember {
    public let id: String
    /// "focus", "online", "away" or "offline".
    public let presence: String
    /// Their place in the desk order (by when they joined): the desk they work at, if there are that many.
    public let seat: Int
    public init(id: String, presence: String, seat: Int) { self.id = id; self.presence = presence; self.seat = seat }
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

/// `list[i]`, or nil where JavaScript's would be undefined.
private func item<T>(_ list: [T], _ i: Int) -> T? { list.indices.contains(i) ? list[i] : nil }

// ── Where feet may go ────────────────────────────────────────────────────────────────────────────────────────────────

/// Whether feet may stand at `p`.
public func hallWalkable(_ L: HallLayout, _ p: HallPoint) -> Bool {
    if p.x < 0.4 || p.x > Double(L.width) - 0.4 || p.y < guildWallRows + 0.5 || p.y > Double(L.height) - 0.1 { return false }
    let tx = min(L.width - 1, max(0, Int(floor(p.x)))), ty = min(L.height - 1, max(0, Int(floor(p.y))))
    for i in L.solidsAt[ty * L.width + tx] {
        let r = L.solids[i]
        if p.x > r.x0 && p.x < r.x1 && p.y > r.y0 && p.y < r.y1 { return false }
    }
    return true
}

/// A step from `p` by (dx, dy), sliding along whatever is in the way.
public func hallStep(_ L: HallLayout, _ p: HallPoint, dx: Double, dy: Double) -> HallPoint {
    let both = HallPoint(x: p.x + dx, y: p.y + dy)
    if hallWalkable(L, both) { return both }
    let sideways = HallPoint(x: p.x + dx, y: p.y)
    if truthy(dx) && hallWalkable(L, sideways) { return sideways }
    let upDown = HallPoint(x: p.x, y: p.y + dy)
    if truthy(dy) && hallWalkable(L, upDown) { return upDown }
    return p
}

/// What pressing A does near `p`: sit at a desk or on a seat within reach (snapping onto it), drink beside water, or wave.
public func hallInteract(_ L: HallLayout, _ p: HallPoint) -> (anim: String, at: HallPoint) {
    var near: (s: HallPoint, d: Double)?
    for s in L.desks + L.seats {
        let d = jsHypot(s.x - p.x, s.y - p.y)
        if near == nil || d < near!.d { near = (s, d) }
    }
    if let near, near.d < 1.3 { return ("sit", near.s) }
    for w in L.drinks where jsHypot(w.x - p.x, w.y - p.y) < 1.2 { return ("drink", w) }
    return ("wave", p)
}

/// A way from `from` to `to` round whatever is in the way: a breadth-first search over half-tile steps (starting even from
/// inside a piece, like a seat), shortened wherever a straight line is clear. Where `to` cannot be reached (inside a desk, a
/// sofa) it goes to the nearest place that can, then the last step onto it. The points after `from`.
public func hallRoute(_ L: HallLayout, from: HallPoint, to: HallPoint) -> [HallPoint] {
    let step = 0.5
    let cols = Int((Double(L.width) / step).rounded(.up))
    let rows = Int((Double(L.height) / step).rounded(.up))
    func clamped(_ v: Double, _ count: Int) -> Int {
        let i = min(Double(count - 1), max(0, (v / step).rounded(.down)))
        return i.isNaN ? 0 : Int(i)
    }
    func cell(_ p: HallPoint) -> Int { clamped(p.y, rows) * cols + clamped(p.x, cols) }
    func centre(_ k: Int) -> HallPoint { HallPoint(x: (Double(k % cols) + 0.5) * step, y: (Double(k / cols) + 0.5) * step) }
    let start = cell(from)
    let goal = cell(to)
    let unseen = -2
    var came = [Int](repeating: unseen, count: cols * rows)
    came[start] = -1
    var queue = [start]
    let neighbours = [(1, 0), (-1, 0), (0, 1), (0, -1)]
    var reached = false
    var next = 0
    while next < queue.count {
        let at = queue[next]
        next += 1
        if at == goal {
            reached = true
            break
        }
        let c = at % cols
        let r = at / cols
        for (dc, dr) in neighbours {
            let nc = c + dc
            let nr = r + dr
            if nc < 0 || nr < 0 || nc >= cols || nr >= rows { continue }
            let key = nr * cols + nc
            if came[key] != unseen || !hallWalkable(L, centre(key)) { continue }
            came[key] = at
            queue.append(key)
        }
    }
    var end = goal
    if !reached {
        // (the reachable place nearest `to`, the first of equals in the search's order)
        var best = Double.infinity
        for k in queue {
            let c = centre(k)
            let d = jsHypot(c.x - to.x, c.y - to.y)
            if d < best {
                best = d
                end = k
            }
        }
    }
    var cells: [HallPoint] = []
    var k = end
    while k != -1 && k != unseen {
        cells.append(centre(k))
        k = came[k]
    }
    cells.reverse()
    if !cells.isEmpty { cells.removeFirst() } // (the cell one starts in: one starts at `from` itself)
    if reached && !cells.isEmpty { cells[cells.count - 1] = to } else { cells.append(to) }
    // straight lines wherever nothing is in between
    func clear(_ a: HallPoint, _ b: HallPoint) -> Bool {
        let n = (jsHypot(b.x - a.x, b.y - a.y) / 0.2).rounded(.up)
        var i = 1.0
        while i < n {
            if !hallWalkable(L, HallPoint(x: a.x + ((b.x - a.x) * i) / n, y: a.y + ((b.y - a.y) * i) / n)) { return false }
            i += 1
        }
        return true
    }
    var out: [HallPoint] = []
    var a = from
    var i = 0
    while i < cells.count {
        var j = cells.count - 1
        while j > i && !clear(a, cells[j]) { j -= 1 }
        out.append(cells[j])
        a = cells[j]
        i = j + 1
    }
    return out
}

// ── What each one is doing ───────────────────────────────────────────────────────────────────────────────────────────

private struct Doing {
    var x, y: Double
    var anim: String
    var dir: String
    var point: HallPoint { HallPoint(x: x, y: y) }
    init(_ p: HallPoint, anim: String, dir: String) { x = p.x; y = p.y; self.anim = anim; self.dir = dir }
}

/// Somewhere free to stand, picked by these words (a few tries; else the middle of the hall).
private func freeSpot(_ L: HallLayout, _ parts: [String]) -> HallPoint {
    for i in 0..<8 {
        let n = jsNumber(Double(i))
        let p = HallPoint(
            x: 1 + hallHash(parts + ["x", n]) * Double(L.width - 2),
            y: guildWallRows + 1 + hallHash(parts + ["y", n]) * (Double(L.height) - guildWallRows - 1.5))
        if hallWalkable(L, p) { return p }
    }
    return HallPoint(x: Double(L.width) / 2, y: Double(L.height) - 1)
}

/// One of `list`, picked by `roll` (0 to 1) as `list[Math.floor(roll * list.length)]`.
private func pick<T>(_ list: [T], _ roll: Double) -> T { list[Int((roll * Double(list.count)).rounded(.down))] }

/// What someone who is there chooses to do in their `k`th activity.
private func activity(_ L: HallLayout, _ m: HallMember, _ k: Double, _ present: [HallMember]) -> Doing {
    let desk = item(L.desks, m.seat)
    let kk = jsNumber(k)
    let roll = hallHash([m.id, kk])
    let others = present.filter { $0.id != m.id }
    func idle() -> Doing { Doing(freeSpot(L, [m.id, kk]), anim: "idle", dir: "front") }
    if roll < 0.3 { return desk.map { Doing($0, anim: "sit", dir: "front") } ?? idle() }
    if roll < 0.45 { return L.drinks.isEmpty ? idle() : Doing(pick(L.drinks, hallHash([m.id, kk, "drink"])), anim: "drink", dir: "front") }
    if roll < 0.6 { return L.seats.isEmpty ? idle() : Doing(pick(L.seats, hallHash([m.id, kk, "bench"])), anim: "sit", dir: "front") }
    if roll < 0.8 && !others.isEmpty {
        let friend = pick(others, hallHash([m.id, kk, "who"]))
        guard let at = item(L.desks, friend.seat) else { return idle() }
        return Doing(HallPoint(x: at.x + 1.1, y: at.y), anim: "chat", dir: "side")
    }
    if roll < 0.88 { return desk.map { Doing(HallPoint(x: $0.x - 1.1, y: $0.y), anim: "stretch", dir: "front") } ?? idle() }
    return idle()
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

/// The ways walked, kept between frames (one per layout: a new one when the hall changes), keyed "<id>|<k>".
public final class HallWays {
    fileprivate var ways: [String: [HallPoint]] = [:]
    public init() {}
}

/// What member `m` is doing at `now` (ms since 1970): nil when offline (not in the hall). `present` is everyone in the hall
/// (for visiting a friend's desk). The ways walked are found anew for each activity; `ways` keeps them (one per layout: a
/// new one when the hall changes), since this is asked every frame.
public func hallPose(_ L: HallLayout, _ m: HallMember, present: [HallMember], now: Double, ways: HallWays? = nil) -> HallPose? {
    if m.presence == "offline" { return nil }
    let secs = now / 1000
    let desk = item(L.desks, m.seat)
    if m.presence == "focus" || m.presence == "away" {
        // (no desk for them: they stand by the wall)
        guard let desk else {
            let p = freeSpot(L, [m.id, "wall"])
            return HallPose(x: p.x, y: p.y, anim: "idle", dir: "front", flip: false, t: secs)
        }
        return HallPose(x: desk.x, y: desk.y, anim: m.presence == "focus" ? "type" : "doze", dir: "front", flip: false, t: secs)
    }
    let shifted = secs + hallHash([m.id, "offset"]) * guildActivitySeconds
    let k = (shifted / guildActivitySeconds).rounded(.down)
    let into = shifted - k * guildActivitySeconds
    let from = activity(L, m, k - 1, present)
    let to = activity(L, m, k, present)
    let key = "\(m.id)|\(jsNumber(k))"
    let path: [HallPoint]
    if let kept = ways?.ways[key] {
        path = kept
    } else {
        path = [from.point] + hallRoute(L, from: from.point, to: to.point)
        ways?.ways[key] = path
    }
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
