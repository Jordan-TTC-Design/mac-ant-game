import AppKit

/// What kind of place the camp window is: the ground, the trees, the rocks and the water all follow it.
enum Biome: String, CaseIterable {
    case meadow, forest, snow, swamp

    var name: String {
        switch self {
        case .meadow: return "草地"
        case .forest: return "森林空地"
        case .snow: return "雪地"
        case .swamp: return "沼澤"
        }
    }

    /// What a random seed turns into (a meadow or a forest most often).
    static func pick(seed: UInt64) -> Biome {
        var rng = TerrainRandom(seed: seed &+ 77)
        let roll = rng.next() * 100
        return roll < 35 ? .meadow : roll < 65 ? .forest : roll < 82 ? .snow : .swamp
    }

    var waterStyle: WaterStyle { self == .snow ? .ice : self == .swamp ? .murk : .clear }

    /// A colour over the ring of forest round the clearing, so the edge matches the ground.
    var ringTint: (NSColor, CGFloat)? {
        switch self {
        case .snow: return (NSColor(calibratedRed: 0.93, green: 0.96, blue: 1, alpha: 1), 0.32)
        case .swamp: return (NSColor(calibratedRed: 0.16, green: 0.24, blue: 0.14, alpha: 1), 0.25)
        case .forest: return (NSColor(calibratedRed: 0.02, green: 0.08, blue: 0.04, alpha: 1), 0.12)
        case .meadow: return nil
        }
    }
}

/// Something goblins walk round: a pond, a rock, the foot of a tree.
protocol Obstacle: AnyObject {
    func blocks(_ p: CGPoint, margin: CGFloat) -> Bool
}

extension Obstacle {
    func blocks(_ p: CGPoint) -> Bool { blocks(p, margin: 3) }
}

/// A round obstacle (a tree trunk, a boulder, a bit of stream).
final class Solid: Obstacle {
    let center: CGPoint
    let radius: CGFloat
    /// The camp's belongings only turn up as the camp grows: this is the size (most goblins it has ever had) it takes.
    let unlock: Int
    /// For trees (1) and rocks (2) the goblins may fell or mine: where it stands, and (rocks) which size it started as.
    var resource = 0
    var foot: CGPoint?
    var size = 0

    init(center: CGPoint, radius: CGFloat, unlock: Int = 0, resource: Int = 0, foot: CGPoint? = nil, size: Int = 0) {
        self.center = center
        self.radius = radius
        self.unlock = unlock
        self.resource = resource
        self.foot = foot
        self.size = size
    }

    func blocks(_ p: CGPoint, margin: CGFloat) -> Bool {
        let r = radius + margin
        let dx = p.x - center.x, dy = p.y - center.y
        return dx * dx + dy * dy < r * r
    }
}

struct TerrainRandom {
    var state: UInt64

    init(seed: UInt64) { state = seed &* 6364136223846793005 &+ 1442695040888963407 }

    mutating func next() -> Double {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        var z = state
        z = (z ^ (z >> 33)) &* 0xff51afd7ed558ccd
        z = (z ^ (z >> 33)) &* 0xc4ceb9fe1a85ec53
        return Double((z ^ (z >> 33)) >> 11) / Double(1 << 53)
    }

    mutating func range(_ a: Double, _ b: Double) -> Double { a + (b - a) * next() }
    mutating func int(_ range: ClosedRange<Int>) -> Int { range.lowerBound + Int(next() * Double(range.count)) }
    mutating func chance(_ p: Double) -> Bool { next() < p }
}

/// A sprite (see `TerrainArt`) standing with its foot at `foot`.
struct TerrainItem {
    let sprite: String
    let foot: CGPoint
    /// See `Solid.unlock`.
    var unlock = 0
}

/// Which strip of the screen a strip-shaped place lies along.
enum StripEdge: String {
    case bottom, right, left
}

/// A place in the camp window: the biome and everything on it, made from a seed. The place is a fixed, large canvas centred on the nest,
/// and the camp window only shows part of it: making the window bigger or smaller reveals or hides things but never changes them (so a
/// felled tree stays felled). The same seed and nest always give the same place. `render` bakes the still parts into one picture.
final class TerrainScene {
    let biome: Biome
    let seed: UInt64
    /// The part goblins may walk in (the camp window), which changes as the window is resized.
    var world: CGRect
    /// The whole place: a fixed size round `nest`.
    let canvas: CGRect
    /// The point the place was made round and is measured from (where the camp was when the place was first made). It never changes, so
    /// the land stays exactly as it is even when the camp is moved.
    let nest: CGPoint
    /// Where the camp really is now (the same as `nest` until the player moves it).
    private(set) var campNest: CGPoint
    /// Set when the place is a strip along the screen edge (`world` is then the band goblins walk in): the strip's land is made for its
    /// shape, long and thin, and drawn over the forest or meadow of the strip.
    let stripEdge: StripEdge?
    var isStrip: Bool { stripEdge != nil }
    /// What a strip's picture covers: the band and the room behind it for trees and tents (the camp window's is the whole canvas).
    private(set) var paintRect: CGRect
    /// About how many camp windows' worth of ground the canvas is, to scale how many things there are on it.
    private var areaFactor: Double { Double(canvas.width * canvas.height) / 900_000 }
    /// What is drawn now (set by `render`), so blobs that are off the screen are skipped.
    private var renderBounds = CGRect.infinite

    private(set) var ponds: [Pond] = []
    private(set) var solids: [Solid] = []
    /// Trees and rocks, sorted so that the ones further down the screen are drawn over the ones behind them.
    private(set) var standing: [TerrainItem] = []
    /// Things lying on the ground (bushes, logs), drawn under the standing ones.
    private(set) var lying: [TerrainItem] = []
    private var paths: [[CGPoint]] = []
    private var streams: [(points: [CGPoint], width: CGFloat)] = []
    private var bridges: [(center: CGPoint, angle: CGFloat, length: CGFloat)] = []
    private var dots: [(CGPoint, NSColor)] = []
    private var mounds: [(center: CGPoint, rx: CGFloat, ry: CGFloat)] = []
    private var mud: [(center: CGPoint, rx: CGFloat, ry: CGFloat)] = []
    private var rings: [(center: CGPoint, radius: CGFloat)] = []
    /// Mushrooms lying about, in clumps of a few near trees and stumps, or alone (never a neat pattern, except now and then a fairy ring).
    private var mushrooms: [(pos: CGPoint, size: Int, kind: Int)] = []
    /// Farm plots near the camp (where their bottom edge is centred), and the size of camp at which each is dug.
    private(set) var plotSpots: [(center: CGPoint, unlock: Int)] = []
    /// Big soft patches that break up the ground (lighter and darker grass, bare earth, moss, mud…).
    private var patches: [(center: CGPoint, rx: CGFloat, ry: CGFloat, color: NSColor)] = []
    /// The bare trampled earth round the camp.
    private var clearing: (center: CGPoint, radius: CGFloat)?
    /// The ring of stones where the campfire party is lit (see `Colony.fireSpot`).
    private(set) var firePit: CGPoint?

    /// The changes over the days (see `TerrainLife`); nil in tests that draw a still scene.
    var life: TerrainLife? {
        didSet { refreshLife() }
    }
    /// Trees that have been growing on their own (past sprouting), as things to walk round.
    private(set) var plantedSolids: [Solid] = []

    /// Where in the year it is: 0 to 4 (spring 0, summer 1, autumn 2, winter 3), or nil without `life` (a still scene is midsummer).
    /// The time to draw the scene at (tests set it); nil = now.
    var clock: Double?

    var seasonPosition: Double {
        guard let life else { return 1.4 }
        let (season, progress) = life.season(at: clock ?? TerrainClock.now)
        return Double(season.rawValue) + progress
    }
    var season: Season { Season(rawValue: min(3, Int(seasonPosition))) ?? .summer }

    /// How big the camp has been (most goblins ever): the camp grows with it. A young camp is only a nest and a patch of trampled earth.
    var growth = 0

    /// Changes whenever the camp gains something to draw or a bigger clearing, so a baked picture knows when to be made again.
    var stage: Int {
        var h = Hasher()
        h.combine(standing.filter { $0.unlock <= growth }.count)
        h.combine(lying.filter { $0.unlock <= growth }.count)
        h.combine(min(growth, 110) / 6)
        h.combine(life?.version ?? 0)
        h.combine(Int(campNest.x)) // (the picture is made again when the camp is moved)
        h.combine(Int(campNest.y))
        return h.finalize()
    }

    /// What goblins must walk round now.
    var obstacles: [Obstacle] {
        let near = world.insetBy(dx: -80, dy: -80) // (only what is in or near the window matters to the goblins)
        return ponds.filter { world.insetBy(dx: -80, dy: -80).intersects($0.picture) } as [Obstacle]
            + solids.filter { $0.unlock <= growth && near.contains($0.center) && !isCut($0) } as [Obstacle]
            + plantedSolids.filter { near.contains($0.center) } as [Obstacle]
    }

    // MARK: What turns up on a strip

    /// The logs and stones that have arrived on the path since the place was made, that nobody has taken.
    var driftItems: [(item: TerrainItem, kind: Int)] {
        guard isStrip, let life else { return [] }
        return life.state.drift.compactMap { d in
            let foot = point(d.fx, d.fy)
            if cut(at: foot) != nil { return nil }
            return (TerrainItem(sprite: d.kind == 0 ? "log-\(biome.rawValue)" : "rock-\(biome.rawValue)-0", foot: foot), d.kind)
        }
    }

    /// A free place at the back of the path for something new to lie (not in a pond, not on the camp).
    func driftSpot(_ rng: inout TerrainRandom) -> CGPoint? {
        guard let edge = stripEdge else { return nil }
        let horizontal = edge == .bottom
        let length = horizontal ? world.width : world.height, across = horizontal ? world.height : world.width
        for _ in 0..<30 {
            let u = CGFloat(rng.range(24, Double(max(30, length - 24)))), v = CGFloat(rng.range(Double(across * 0.6), Double(across - 3)))
            let p: CGPoint
            switch edge {
            case .bottom: p = CGPoint(x: world.minX + u, y: world.minY + v)
            case .right: p = CGPoint(x: world.maxX - v, y: world.minY + u)
            case .left: p = CGPoint(x: world.minX + v, y: world.minY + u)
            }
            if ponds.contains(where: { $0.picture.insetBy(dx: -6, dy: -6).contains(p) }) { continue }
            if solids.contains(where: { $0.blocks(p, margin: 6) }) { continue }
            if hypot(p.x - campNest.x, p.y - campNest.y) < 60 { continue }
            return p
        }
        return nil
    }

    // MARK: The tents

    /// Where a goblin steps into each tent that is up: just in front of it (outside the tent's own bulk, so it can be reached).
    func tentEntrances() -> [CGPoint] {
        let across = stripEdge == .bottom ? world.height : world.width
        let radius = min(15, max(4, across * 0.24)) + 3
        return standing.filter { $0.sprite.hasPrefix("tent-") && $0.unlock <= growth }.map { tent in
            switch stripEdge {
            case .bottom?: return CGPoint(x: tent.foot.x, y: tent.foot.y - radius)
            case .right?: return CGPoint(x: tent.foot.x + radius, y: tent.foot.y)
            case .left?: return CGPoint(x: tent.foot.x - radius, y: tent.foot.y)
            case nil: return CGPoint(x: tent.foot.x, y: tent.foot.y - 12)
            }
        }
    }

    // MARK: What the goblins take

    /// What the goblins have taken from where `foot` is, if anything.
    func cut(at foot: CGPoint) -> Cut? {
        guard let life else { return nil }
        let f = fraction(foot)
        return life.state.cuts.first { abs($0.fx - Double(f.x)) < 3 && abs($0.fy - Double(f.y)) < 3 }
    }

    private func isCut(_ solid: Solid) -> Bool {
        guard solid.resource != 0, let foot = solid.foot, let c = cut(at: foot) else { return false }
        return solid.resource == 1 ? c.kind == 0 : (c.kind == 1 && c.taken > solid.size)
    }

    struct ResourceSpot {
        enum Kind { case tree, rock }
        let id: Int
        let kind: Kind
        let foot: CGPoint
        /// Where a goblin stands to work at it.
        let standAt: CGPoint
        let planted: Bool
    }

    /// The trees and rocks goblins may work at now: not felled, not used up, and standing (a sapling is not a tree yet).
    func resourceSpots() -> [ResourceSpot] {
        func id(_ p: CGPoint) -> Int { let f = fraction(p); return (Int(f.x) + 5_000) * 10_000 + Int(f.y) + 5_000 }
        func stand(_ p: CGPoint, _ radius: CGFloat) -> CGPoint {
            let side: CGFloat = TerrainScene.hash(p) % 2 == 0 ? 1 : -1
            let spot = CGPoint(x: p.x + side * (radius + 9), y: p.y - 3)
            guard isStrip else { return spot }
            // (in a strip the goblin stands on the path: pulled in to it from the back)
            return CGPoint(x: min(max(spot.x, world.minX + 5), world.maxX - 5), y: min(max(spot.y, world.minY + 5), world.maxY - 5))
        }
        var spots: [ResourceSpot] = []
        for solid in solids where solid.resource != 0 && solid.unlock <= growth && !isCut(solid) {
            guard let foot = solid.foot, visible(foot) else { continue }
            spots.append(ResourceSpot(id: id(foot), kind: solid.resource == 1 ? .tree : .rock, foot: foot, standAt: stand(foot, solid.radius), planted: false))
        }
        for (drift, kind) in driftItems {
            guard visible(drift.foot) else { continue }
            spots.append(ResourceSpot(id: id(drift.foot), kind: kind == 0 ? .tree : .rock, foot: drift.foot, standAt: stand(drift.foot, kind == 0 ? 6 : 8), planted: false))
        }
        if let life {
            let now = clock ?? TerrainClock.now
            for plant in life.state.plantings where plant.fell == nil && life.stage(of: plant, at: now) == .tree {
                let foot = point(plant.fx, plant.fy)
                guard visible(foot) else { continue }
                spots.append(ResourceSpot(id: id(foot), kind: .tree, foot: foot, standAt: stand(foot, 7), planted: true))
            }
        }
        return spots
    }

    /// The scene item for a static thing that has been cut: nothing, a stump, or a smaller rock.
    private func afterCut(_ item: TerrainItem) -> (item: TerrainItem?, stump: TerrainItem?) {
        guard let c = cut(at: item.foot) else { return (item, nil) }
        if item.sprite.hasPrefix("tree-"), c.kind == 0 { return (nil, TerrainItem(sprite: "stump-\(biome.rawValue)", foot: item.foot)) }
        if item.sprite.hasPrefix("rock-"), c.kind == 1, let size = Int(item.sprite.suffix(1)) {
            let left = size - c.taken
            return left < 0 ? (nil, nil) : (TerrainItem(sprite: "rock-\(biome.rawValue)-\(left)", foot: item.foot, unlock: item.unlock), nil)
        }
        return (item, nil)
    }

    /// A point (in the clearing) that is free for something `radius` wide, or nil. Used to plant saplings and to leave puddles.
    func freeSpot(_ rng: inout TerrainRandom, _ radius: CGFloat) -> CGPoint? {
        let area = isStrip ? world.insetBy(dx: 6, dy: 5) : canvas.insetBy(dx: 44, dy: 56) // (a strip's puddles lie on its path)
        for _ in 0..<30 {
            let p = CGPoint(x: area.minX + CGFloat(rng.next()) * area.width, y: area.minY + CGFloat(rng.next()) * area.height)
            if let clearing, hypot(p.x - clearing.center.x, p.y - clearing.center.y) < clearing.radius + radius + 12 { continue }
            if ponds.contains(where: { $0.blocks(p, margin: radius + 6) }) || solids.contains(where: { $0.blocks(p, margin: radius) }) { continue }
            return p
        }
        return nil
    }

    /// A point as an offset from the nest (that is how things the goblins changed are remembered, so they stay put when the window is resized).
    func fraction(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x - nest.x, y: p.y - nest.y) }

    private func point(_ fx: Double, _ fy: Double) -> CGPoint { CGPoint(x: nest.x + CGFloat(fx), y: nest.y + CGFloat(fy)) }

    /// Whether something at `p` is inside the camp window (a little way in).
    private func visible(_ p: CGPoint, margin: CGFloat = 16) -> Bool { (isStrip ? paintRect : world).insetBy(dx: margin, dy: margin).contains(p) }

    /// The ponds in the camp window.
    var visiblePonds: [Pond] { ponds.filter { world.intersects($0.picture) } }

    /// Called when the life changed: the trees that are up are obstacles now.
    func refreshLife() {
        guard let life else { plantedSolids = []; return }
        life.ensurePlots(plotSpots.count)
        let now = clock ?? TerrainClock.now
        plantedSolids = life.state.plantings.compactMap { plant in
            guard plant.planted <= now else { return nil }
            let s = life.stage(of: plant, at: now)
            guard s == .young || s == .tree else { return nil }
            let at = point(plant.fx, plant.fy)
            return Solid(center: CGPoint(x: at.x, y: at.y + 3), radius: s == .tree ? 7 : 5)
        }
    }

    /// A short description for the menu and the notes ("雪地，2 個池塘").
    var summary: String {
        var parts = [biome.name]
        if !ponds.isEmpty { parts.append("\(ponds.count) 個池塘") }
        if !streams.isEmpty { parts.append(biome == .snow ? "結冰的小溪" : "小溪與木橋") }
        return parts.joined(separator: "，")
    }

    /// `world` is the clearing (where goblins may walk); `nest` is kept clear.
    init(seed: UInt64, biome: Biome, world: CGRect, nest: CGPoint, campNest: CGPoint? = nil) {
        self.seed = seed
        self.biome = biome
        self.world = world
        self.nest = nest
        self.campNest = nest
        stripEdge = nil
        canvas = CGRect(x: nest.x - 1100, y: nest.y - 750, width: 2200, height: 1500)
        paintRect = canvas
        generate(nest: nest)
        if let campNest { moveCamp(to: campNest) }
    }

    /// A place along a strip of the screen. `band` is where the goblins walk; `nest` is where the place is measured from (see `campNest`).
    init(seed: UInt64, biome: Biome, band: CGRect, edge: StripEdge, nest: CGPoint, campNest: CGPoint? = nil) {
        self.seed = seed
        self.biome = biome
        world = band
        self.nest = nest
        self.campNest = nest
        stripEdge = edge
        let room: CGFloat = 58 // for trees and tents that stand behind the path
        switch edge {
        case .bottom: paintRect = CGRect(x: band.minX, y: band.minY, width: band.width, height: band.height + room)
        case .right: paintRect = CGRect(x: band.minX - room, y: band.minY, width: band.width + room, height: band.height)
        case .left: paintRect = CGRect(x: band.minX, y: band.minY, width: band.width + room, height: band.height)
        }
        canvas = paintRect
        generateStrip(band: band, edge: edge, nest: nest)
        if let campNest { moveCamp(to: campNest) }
    }

    /// The camp is somewhere else now: its tents, fire ring, trampled earth and farm plots move with it and the land stays as it was, except
    /// that the trees, rocks and bushes where it now stands are cleared away (always the same ones for the same place). Camp things are
    /// the ones that turn up with the camp's size (`unlock` above zero).
    func moveCamp(to point: CGPoint) {
        guard hypot(point.x - campNest.x, point.y - campNest.y) > 0.5 else { return }
        let dx = point.x - campNest.x, dy = point.y - campNest.y
        func shifted(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x + dx, y: p.y + dy) }
        standing = standing.map { $0.unlock > 0 ? TerrainItem(sprite: $0.sprite, foot: shifted($0.foot), unlock: $0.unlock) : $0 }
        lying = lying.map { $0.unlock > 0 ? TerrainItem(sprite: $0.sprite, foot: shifted($0.foot), unlock: $0.unlock) : $0 }
        solids = solids.map { $0.unlock > 0 ? Solid(center: shifted($0.center), radius: $0.radius, unlock: $0.unlock) : $0 }
        if let c = clearing { clearing = (shifted(c.center), c.radius) }
        if let pit = firePit { firePit = shifted(pit) }
        // the worn paths start at the camp: the camp end follows it and the far end stays where it was, so they still lead to the camp
        paths = paths.map { path in
            path.enumerated().map { i, p in
                let along = CGFloat(i) / CGFloat(max(1, path.count - 1)), pull = 1 - along
                return CGPoint(x: p.x + dx * pull, y: p.y + dy * pull)
            }
        }
        campNest = point
        // clear the ground where the camp stands now
        let bare: CGFloat = 112
        func away(_ p: CGPoint) -> Bool { hypot(p.x - point.x, p.y - point.y) < bare }
        let felled = standing.filter { $0.unlock == 0 && away($0.foot) }.map(\.foot) // trees, rocks and standing stones there
        standing.removeAll { $0.unlock == 0 && away($0.foot) }
        solids.removeAll { solid in solid.unlock == 0 && felled.contains { hypot($0.x - solid.center.x, $0.y - solid.center.y) < 14 } }
        mushrooms.removeAll { away($0.pos) }
        standing.sort { $0.foot.y > $1.foot.y }
        // the farm plots move too, to spots round the new camp that are not in a pond or among trees
        var rng = TerrainRandom(seed: seed &+ 4242)
        var placed: [CGPoint] = []
        var next: [(center: CGPoint, unlock: Int)] = []
        let inner = canvas.insetBy(dx: 36, dy: 36)
        for plot in plotSpots {
            var spot = shifted(plot.center)
            for _ in 0..<40 {
                let a = rng.range(0, 2 * .pi), r = rng.range(135, 230)
                let p = CGPoint(x: point.x + CGFloat(cos(a) * r), y: point.y + CGFloat(sin(a) * r) * 0.8)
                guard inner.contains(p), !ponds.contains(where: { $0.blocks(p, margin: 52) }), !solids.contains(where: { $0.unlock == 0 && $0.blocks(p, margin: 46) }),
                      placed.allSatisfy({ hypot($0.x - p.x, $0.y - p.y) > 100 }) else { continue }
                spot = p
                break
            }
            placed.append(spot)
            next.append((spot, plot.unlock))
        }
        plotSpots = next
    }

    // MARK: Making a strip

    /// The land of a strip: made for a long thin band. Everything is placed by its distance along the strip (`u`) and how far back from
    /// the screen edge it stands (`v`, 0 = the front of the path, `across` = the back, where the forest is), so the same recipe works
    /// along the bottom and down either side. The path in front stays clear: only small things stand on it, ponds and stream banks are
    /// at the back, and a stream always has a bridge.
    /// The bottom is a riverside meadow (more water, fewer trees); the sides are the edge of the forest (trees, rocks, mushrooms, dry leaves).
    private func generateStrip(band: CGRect, edge: StripEdge, nest: CGPoint) {
        var rng = TerrainRandom(seed: seed)
        let horizontal = edge == .bottom
        let length = horizontal ? band.width : band.height
        let across = horizontal ? band.height : band.width
        func at(_ u: CGFloat, _ v: CGFloat) -> CGPoint {
            switch edge {
            case .bottom: return CGPoint(x: band.minX + u, y: band.minY + v)
            case .right: return CGPoint(x: band.maxX - v, y: band.minY + u)
            case .left: return CGPoint(x: band.minX + v, y: band.minY + u)
            }
        }
        let u0 = horizontal ? nest.x - band.minX : nest.y - band.minY
        let back = across
        var taken: [(u: CGFloat, half: CGFloat)] = [(u0, 130)]
        func free(_ u: CGFloat, _ half: CGFloat) -> Bool {
            u > half + 12 && u < length - half - 12 && taken.allSatisfy { abs($0.u - u) > $0.half + half }
        }
        func place(_ half: CGFloat) -> CGFloat? {
            guard length > 2 * half + 30 else { return nil }
            for _ in 0..<60 {
                let u = CGFloat(rng.range(Double(half + 14), Double(length - half - 14)))
                if free(u, half) { return u }
            }
            return nil
        }
        let riverside = edge == .bottom

        // the camp: trampled earth round the nest, the fire ring beside it, and its belongings in a row along the back of the path
        clearing = (nest, min(across * 0.62, 40) + CGFloat(rng.range(0, 6)))
        let pitU = u0 + 74 < length - 24 ? u0 + 74 : u0 - 74
        let pit = at(pitU, max(across * 0.55, 19)) // (cooks stand 17 in front of it, and still on the path)
        firePit = pit
        lying.append(TerrainItem(sprite: "firepit-\(biome.rawValue)", foot: CGPoint(x: pit.x, y: pit.y - 4), unlock: 5))
        var plan: [(kind: String, unlock: Int)] = [("bones-0", 8), ("stump", 12), ("firewood", 16), ("tent", 22), ("skull", 30), ("spears", 38),
                                                   ("rack", 48), ("tent", 60), ("bones-1", 68), ("totem", 85)]
        if rng.chance(0.5) { plan.append(("tent", 105)) }
        // on both sides of the nest, going outward, but not on top of the fire ring
        var offsets: [CGFloat] = [-64, 132, -118, 178, -172, 226, -226, 274, -280, 322, -334]
        offsets = offsets.map { abs($0 - (pitU - u0)) < 30 ? $0 + ($0 < 0 ? -34 : 34) : $0 }
        for (entry, du) in zip(plan, offsets) {
            let u = u0 + du + CGFloat(rng.range(-8, 8))
            guard u > 20, u < length - 20 else { continue }
            let kind = entry.kind, unlock = entry.unlock
            let p = at(u, back - CGFloat(rng.range(3, 9)))
            let name = kind.contains("-") ? "\(kind.split(separator: "-")[0])-\(biome.rawValue)-\(kind.split(separator: "-")[1])" : "\(kind)-\(biome.rawValue)"
            let item = TerrainItem(sprite: name, foot: p, unlock: unlock)
            // (it stands at the back of the path and only its own foot blocks: the front stays clear)
            func block(_ radius: CGFloat) { solids.append(Solid(center: p, radius: min(radius, max(4, across * 0.24)), unlock: unlock)) }
            switch kind {
            case "tent": standing.append(item); block(15)
            case "rack": standing.append(item); block(14)
            case "totem": standing.append(item); block(5)
            case "firewood": standing.append(item); block(8)
            case "skull": standing.append(item); block(3)
            case "spears": standing.append(item)
            case "stump": lying.append(item); block(6)
            default: lying.append(item)
            }
        }

        // farm plots along the back of the path, a little way from the camp, dug as it grows (one, two or three)
        for k in 0..<rng.int(1...3) {
            guard let u = place(32) else { continue }
            plotSpots.append((at(u, across * 0.55), [26, 52, 88][k]))
            taken.append((u, 34))
        }

        // water: ponds against the back of the path (with a bank all round), more on the bottom
        let pondCount = riverside ? Int(length / 640) + (rng.chance(0.6) ? 1 : 0) : (rng.chance(0.3) ? 1 : 0) + Int(length / 1500)
        for i in 0..<pondCount {
            let along = CGFloat(rng.range(riverside ? 72 : 56, riverside ? 132 : 96))
            let depth = min(across * 0.5, CGFloat(rng.range(16, 26)))
            guard depth >= 12, let u = place(along / 2 + 22) else { continue }
            let a = at(u - along / 2, back - depth), b = at(u + along / 2, back)
            let box = CGRect(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(a.x - b.x), height: abs(a.y - b.y))
            ponds.append(Pond(seed: seed &* 31 &+ UInt64(i) &+ 5, rect: box, style: biome.waterStyle))
            taken.append((u, along / 2 + 22))
        }

        // a stream across the path, with a plank bridge: the goblins cross only at the bridge (ice can be walked on)
        if across >= 34 {
            for _ in 0..<(Int(length / (riverside ? 800 : 1300)) + (rng.chance(0.4) ? 1 : 0)) {
                guard let u = place(38) else { continue }
                var points: [CGPoint] = []
                let phase = rng.range(0, 6.28)
                let steps = Int((across + 24) / 4)
                for k in 0...steps {
                    let v = -8 + CGFloat(k) / CGFloat(steps) * (across + 24)
                    points.append(at(u + sin(v / 9 + CGFloat(phase)) * 3, v))
                }
                streams.append((points, 11))
                let bridgeV = across * 0.42
                bridges.append((at(u, bridgeV), horizontal ? 0 : .pi / 2, 25))
                if biome != .snow {
                    for (k, p) in points.enumerated() {
                        let v = -8 + CGFloat(k) / CGFloat(steps) * (across + 24)
                        if abs(v - bridgeV) > 13 { solids.append(Solid(center: p, radius: 4.5)) }
                    }
                }
                taken.append((u, 38))
            }
        }

        // rocks at the back of the path (small ones only where it is narrow)
        for _ in 0..<(Int(length / (riverside ? 420 : 230)) + (rng.chance(0.5) ? 1 : 0)) {
            guard let u = place(22) else { continue }
            let size = across >= 40 ? rng.int(0...1) : 0
            let foot = at(u, back - 5 - CGFloat(size) * 2)
            standing.append(TerrainItem(sprite: "rock-\(biome.rawValue)-\(size)", foot: foot))
            solids.append(Solid(center: foot, radius: CGFloat([8, 12][size]), resource: 2, foot: foot, size: size))
            taken.append((u, 24))
        }

        // (no big trees of its own: the forest behind the path is the strip's trees, and the sprites here are drawn at the camp window's scale)

        // fallen logs at the back of the path: what the goblins chop (the strip's trees are only scenery)
        for _ in 0..<(Int(length / 190) + 1) {
            guard let u = place(14) else { continue }
            let p = at(u, CGFloat(rng.range(Double(across * 0.6), Double(back - 3))))
            if ponds.contains(where: { $0.picture.insetBy(dx: -6, dy: -6).contains(p) }) { continue }
            lying.append(TerrainItem(sprite: "log-\(biome.rawValue)", foot: p))
            solids.append(Solid(center: p, radius: 6, resource: 1, foot: p))
            taken.append((u, 16))
        }

        // bushes, ferns and tufts in the back half of the path
        for _ in 0..<Int(length / 90) {
            let u = CGFloat(rng.range(16, Double(max(20, length - 16))))
            if abs(u - u0) < 120 { continue } // (the camp's own things stand there)
            let p = at(u, CGFloat(rng.range(Double(across * 0.6), Double(back - 2))))
            if ponds.contains(where: { $0.picture.insetBy(dx: -6, dy: -6).contains(p) }) { continue } // (not in the water)
            let roll = rng.int(0...9)
            if roll < 4 { lying.append(TerrainItem(sprite: "bush-\(biome.rawValue)-\(rng.int(0...1))", foot: p)) }
            else if roll < 7 { lying.append(TerrainItem(sprite: "fern-\(biome.rawValue)-\(rng.int(0...1))", foot: p)) }
            else { lying.append(TerrainItem(sprite: "tuft-\(biome.rawValue)", foot: p)) }
        }

        // mushrooms, one clump or two at the foot of a tree, a log or a rock, and the rest in the open
        let hosts = (standing + lying).filter { item in ["tree-", "stump-", "log-", "rock-"].contains { item.sprite.hasPrefix($0) } }
        for _ in 0..<Int(length / (riverside ? 260 : 130)) {
            var anchor = at(CGFloat(rng.range(20, Double(max(24, length - 20)))), CGFloat(rng.range(Double(across * 0.5), Double(back - 2))))
            if !hosts.isEmpty, rng.chance(0.65) {
                let host = hosts[rng.int(0...(hosts.count - 1))]
                anchor = CGPoint(x: host.foot.x + CGFloat(rng.range(-18, 18)), y: host.foot.y + CGFloat(rng.range(-6, 4)))
            }
            let kind = rng.int(0...3)
            for _ in 0..<rng.int(1...5) {
                mushrooms.append((CGPoint(x: anchor.x + CGFloat(rng.range(-9, 9)), y: anchor.y + CGFloat(rng.range(-5, 5))), rng.int(0...2), rng.chance(0.75) ? kind : rng.int(0...3)))
            }
        }

        // little flowers over the meadow, dry leaves under the forest
        let flowerColors: [NSColor] = [NSColor(calibratedRed: 0.95, green: 0.55, blue: 0.7, alpha: 1), NSColor(calibratedWhite: 0.96, alpha: 1),
                                       NSColor(calibratedRed: 0.98, green: 0.85, blue: 0.3, alpha: 1), NSColor(calibratedRed: 0.72, green: 0.6, blue: 0.95, alpha: 1)]
        let leafColors: [NSColor] = [NSColor(calibratedRed: 0.72, green: 0.5, blue: 0.2, alpha: 1), NSColor(calibratedRed: 0.56, green: 0.4, blue: 0.16, alpha: 1)]
        let dotColors = biome == .meadow ? flowerColors : biome == .snow ? [] : leafColors
        if !dotColors.isEmpty {
            for _ in 0..<Int(length / (biome == .meadow ? 6 : 10)) {
                let p = at(CGFloat(rng.range(8, Double(max(12, length - 8)))), CGFloat(rng.range(2, Double(back))))
                dots.append((p, dotColors[rng.int(0...(dotColors.count - 1))]))
            }
        }
        standing.sort { $0.foot.y > $1.foot.y }
    }

    // MARK: Making a place

    private func generate(nest: CGPoint) {
        var rng = TerrainRandom(seed: seed)
        let inner = canvas.insetBy(dx: 36, dy: 36)
        let big = true
        // where things may not go: the camp itself, and what is already there
        var taken: [(CGPoint, CGFloat)] = [(nest, 105)]
        func free(_ p: CGPoint, _ radius: CGFloat) -> Bool {
            inner.insetBy(dx: -8, dy: -8).contains(p) && taken.allSatisfy { hypot($0.0.x - p.x, $0.0.y - p.y) > $0.1 + radius }
        }
        /// A free spot for something `radius` wide, wholly inside `area` (the clearing, by default kept off the forest edge).
        func spot(_ radius: CGFloat, tries: Int = 40, in area: CGRect? = nil) -> CGPoint? {
            let everywhere = area == nil
            let area = area ?? inner
            guard area.width > 1, area.height > 1 else { return nil }
            // a window's worth of things should land near the nest, where the camp window looks; the rest is spread over the whole canvas
            let central = CGRect(x: nest.x - 600, y: nest.y - 420, width: 1200, height: 840).intersection(area)
            for _ in 0..<tries {
                let pick = (everywhere && !central.isNull && rng.chance(0.4)) ? central : area
                let p = CGPoint(x: pick.minX + CGFloat(rng.next()) * pick.width, y: pick.minY + CGFloat(rng.next()) * pick.height)
                if free(p, radius) { return p }
            }
            return nil
        }

        // a stream across the clearing, with a bridge (frozen in the snow: walk right over it)
        if biome != .swamp, rng.chance(0.45) { makeStream(&rng, nest: nest, taken: &taken) }

        makeCamp(&rng, nest: nest, inner: inner)

        // farm plots a little way from the camp, dug as it grows (one, two or three)
        if big {
            for k in 0..<rng.int(1...3) {
                for _ in 0..<25 {
                    let a = rng.range(0, 2 * .pi), r = rng.range(135, 230)
                    let p = CGPoint(x: nest.x + CGFloat(cos(a) * r), y: nest.y + CGFloat(sin(a) * r) * 0.8)
                    if free(p, 46) {
                        plotSpots.append((p, [26, 52, 88][k]))
                        taken.append((p, 46))
                        break
                    }
                }
            }
        }

        // big soft patches over the ground so it is not one flat colour
        let patchColors: [NSColor]
        switch biome {
        case .meadow: patchColors = [NSColor(calibratedRed: 0.5, green: 0.78, blue: 0.4, alpha: 0.16), NSColor(calibratedRed: 0.1, green: 0.3, blue: 0.14, alpha: 0.2),
                                     NSColor(calibratedRed: 0.62, green: 0.5, blue: 0.3, alpha: 0.28)]
        case .forest: patchColors = [NSColor(calibratedRed: 0.08, green: 0.22, blue: 0.1, alpha: 0.24), NSColor(calibratedRed: 0.5, green: 0.36, blue: 0.14, alpha: 0.22),
                                     NSColor(calibratedRed: 0.5, green: 0.56, blue: 0.2, alpha: 0.16)]
        case .snow: patchColors = [NSColor(calibratedRed: 0.6, green: 0.72, blue: 0.92, alpha: 0.24), NSColor(calibratedRed: 0.66, green: 0.66, blue: 0.68, alpha: 0.2),
                                   NSColor(calibratedRed: 1, green: 1, blue: 1, alpha: 0.5)]
        case .swamp: patchColors = [NSColor(calibratedRed: 0.3, green: 0.24, blue: 0.13, alpha: 0.3), NSColor(calibratedRed: 0.46, green: 0.54, blue: 0.26, alpha: 0.22),
                                    NSColor(calibratedRed: 0.14, green: 0.2, blue: 0.12, alpha: 0.3)]
        }
        for _ in 0..<Int(canvas.width * canvas.height / 14000) {
            let c = CGPoint(x: canvas.minX + CGFloat(rng.next()) * canvas.width, y: canvas.minY + CGFloat(rng.next()) * canvas.height)
            patches.append((c, CGFloat(rng.range(28, 90)), CGFloat(rng.range(16, 48)), patchColors[rng.int(0...(patchColors.count - 1))]))
        }

        // ponds: none to a few, small to big, anywhere (a swamp has several small murky ones)
        let pondCount: Int
        switch biome {
        case .swamp: pondCount = Int(Double(rng.int(2...4)) * areaFactor * 0.8)
        case .meadow: pondCount = Int(Double([0, 1, 1, 2][rng.int(0...3)]) * areaFactor * 0.85 + (rng.chance(0.5) ? 1 : 0))
        case .forest: pondCount = Int(Double([0, 0, 1, 2][rng.int(0...3)]) * areaFactor * 0.85 + (rng.chance(0.4) ? 1 : 0))
        case .snow: pondCount = Int(Double([0, 1, 1, 2][rng.int(0...3)]) * areaFactor * 0.85 + (rng.chance(0.5) ? 1 : 0))
        }
        if big {
            for i in 0..<pondCount {
                let maxW: CGFloat = biome == .swamp ? 150 : 270
                let w = CGFloat(rng.range(biome == .swamp ? 70 : 90, Double(max(100, maxW))))
                let h = w * CGFloat(rng.range(0.5, 0.95))
                let radius = max(w, h) / 2 + 24
                guard let c = spot(radius, in: inner.insetBy(dx: w / 2 + 6, dy: h / 2 + 6)) else { continue }
                let box = CGRect(x: c.x - w / 2, y: c.y - h / 2, width: w, height: h)
                let pond = Pond(seed: seed &* 31 &+ UInt64(i) &+ 5, rect: box, style: biome.waterStyle)
                ponds.append(pond)
                taken.append((c, radius))
                if biome == .swamp { // reeds and cattails along the edge
                    for _ in 0..<rng.int(4...8) {
                        let a = rng.range(0, 2 * .pi)
                        let p = CGPoint(x: c.x + CGFloat(cos(a)) * w * 0.5, y: c.y + CGFloat(sin(a)) * h * 0.5)
                        lying.append(TerrainItem(sprite: "cattail-swamp-\(rng.int(0...1))", foot: p))
                    }
                }
            }
        }

        // rocks: single boulders and little heaps of two or three
        let rockGroups = Int(Double(biome == .snow ? rng.int(3...6) : biome == .swamp ? rng.int(1...3) : rng.int(2...5)) * areaFactor)
        for _ in 0..<rockGroups {
            guard let c = spot(34) else { continue }
            for k in 0..<rng.int(1...3) {
                let size = rng.int(0...2)
                let foot = CGPoint(x: c.x + CGFloat(rng.range(-22, 22)) * (k > 0 ? 1 : 0), y: c.y + CGFloat(rng.range(-10, 10)) * (k > 0 ? 1 : 0))
                standing.append(TerrainItem(sprite: "rock-\(biome.rawValue)-\(size)", foot: foot))
                solids.append(Solid(center: CGPoint(x: foot.x, y: foot.y + 4), radius: CGFloat([9, 14, 20][size]), resource: 2, foot: foot, size: size))
            }
            taken.append((c, 30))
        }

        // groves of trees, dense in a forest and thin in a swamp
        let groves: Int
        switch biome {
        case .forest: groves = Int(Double(rng.int(3...6)) * areaFactor)
        case .meadow: groves = Int(Double(rng.int(1...3)) * areaFactor)
        case .snow: groves = Int(Double(rng.int(2...5)) * areaFactor)
        case .swamp: groves = Int(Double(rng.int(2...4)) * areaFactor)
        }
        let treeKinds = biome == .forest ? 4 : biome == .swamp ? 5 : 3
        for _ in 0..<groves {
            guard let c = spot(46, in: CGRect(x: inner.minX + 30, y: inner.minY + 10, width: inner.width - 60, height: inner.height - 70)) else { continue }
            let count = biome == .swamp ? rng.int(2...5) : rng.int(3...9)
            var placed: [CGPoint] = []
            for _ in 0..<count {
                for _ in 0..<12 {
                    let a = rng.range(0, 2 * .pi), r = rng.range(0, 70).squareRoot() * 8.4
                    let p = CGPoint(x: c.x + CGFloat(cos(a) * r), y: c.y + CGFloat(sin(a) * r) * 0.8)
                    if free(p, 8), placed.allSatisfy({ hypot($0.x - p.x, $0.y - p.y) > 26 }) {
                        placed.append(p)
                        standing.append(TerrainItem(sprite: "tree-\(biome.rawValue)-\(rng.int(0...(treeKinds - 1)))", foot: p))
                        solids.append(Solid(center: p, radius: 6, resource: 1, foot: p))
                        break
                    }
                }
            }
            taken.append((c, 40))
        }

        // bushes and logs lying about
        for _ in 0..<Int(Double(rng.int(5...12)) * areaFactor) {
            guard let c = spot(10, tries: 12) else { continue }
            lying.append(TerrainItem(sprite: "bush-\(biome.rawValue)-\(rng.int(0...1))", foot: c))
        }
        for _ in 0..<Int(Double(rng.int(0...3)) * areaFactor) {
            guard let c = spot(14, tries: 12) else { continue }
            lying.append(TerrainItem(sprite: "log-\(biome.rawValue)", foot: c))
        }

        // undergrowth: ferns and tufts of grass, stumps, and (now and then) a ring of standing stones
        let fernCount = Int(Double(biome == .forest ? rng.int(14...28) : biome == .swamp ? rng.int(8...16) : biome == .meadow ? rng.int(4...10) : rng.int(2...5)) * areaFactor)
        for _ in 0..<fernCount {
            guard let c = spot(8, tries: 8) else { continue }
            lying.append(TerrainItem(sprite: "fern-\(biome.rawValue)-\(rng.int(0...1))", foot: c))
        }
        for _ in 0..<Int(canvas.width * canvas.height / 9000) {
            guard let c = spot(4, tries: 4) else { continue }
            lying.append(TerrainItem(sprite: "tuft-\(biome.rawValue)", foot: c))
        }
        for _ in 0..<Int(Double(biome == .forest ? rng.int(2...5) : rng.int(0...2)) * areaFactor) {
            guard let c = spot(10, tries: 10) else { continue }
            lying.append(TerrainItem(sprite: "stump-\(biome.rawValue)", foot: c))
            solids.append(Solid(center: CGPoint(x: c.x, y: c.y + 4), radius: 7))
        }
        for _ in 0..<(rng.chance(0.85) ? Int(areaFactor * 0.6) : 0) { // landmarks: standing stones in a ring
            guard let c = spot(50, tries: 20, in: inner.insetBy(dx: 40, dy: 40)) else { continue }
            let count = rng.int(3...5)
            for k in 0..<count {
                let a = Double(k) / Double(count) * 2 * .pi + rng.range(-0.2, 0.2)
                let p = CGPoint(x: c.x + CGFloat(cos(a)) * 30, y: c.y + CGFloat(sin(a)) * 20)
                standing.append(TerrainItem(sprite: "menhir-\(biome.rawValue)", foot: p))
                solids.append(Solid(center: CGPoint(x: p.x, y: p.y + 3), radius: 7))
            }
            taken.append((c, 52))
        }

        // things drawn flat on the ground, by biome
        switch biome {
        case .meadow:
            scatterMushrooms(&rng, clumps: Int(Double(rng.int(0...3)) * areaFactor), inner: inner)
            let colors = [NSColor(calibratedRed: 0.95, green: 0.86, blue: 0.35, alpha: 1), NSColor(calibratedRed: 0.94, green: 0.47, blue: 0.6, alpha: 1),
                          NSColor.white, NSColor(calibratedRed: 0.6, green: 0.65, blue: 0.95, alpha: 1)]
            for _ in 0..<rng.int(3...7) { // flower patches
                let c = CGPoint(x: inner.minX + CGFloat(rng.next()) * inner.width, y: inner.minY + CGFloat(rng.next()) * inner.height)
                let color = colors[rng.int(0...(colors.count - 1))]
                for _ in 0..<rng.int(14...36) {
                    let a = rng.range(0, 2 * .pi), r = rng.range(0, 1).squareRoot() * 26
                    dots.append((CGPoint(x: c.x + CGFloat(cos(a) * r), y: c.y + CGFloat(sin(a) * r) * 0.7), rng.chance(0.2) ? colors[0] : color))
                }
            }
        case .forest:
            scatterMushrooms(&rng, clumps: Int(Double(rng.int(5...11)) * areaFactor), inner: inner)
            for _ in 0..<rng.int(30...70) { // fallen leaves
                dots.append((CGPoint(x: inner.minX + CGFloat(rng.next()) * inner.width, y: inner.minY + CGFloat(rng.next()) * inner.height),
                             rng.chance(0.5) ? NSColor(calibratedRed: 0.72, green: 0.5, blue: 0.2, alpha: 1) : NSColor(calibratedRed: 0.56, green: 0.4, blue: 0.16, alpha: 1)))
            }
        case .snow:
            for _ in 0..<rng.int(4...9) { // drifts
                let c = CGPoint(x: inner.minX + CGFloat(rng.next()) * inner.width, y: inner.minY + CGFloat(rng.next()) * inner.height)
                mounds.append((c, CGFloat(rng.range(18, 44)), CGFloat(rng.range(7, 14))))
            }
        case .swamp:
            scatterMushrooms(&rng, clumps: Int(Double(rng.int(3...6)) * areaFactor), inner: inner)
            for _ in 0..<rng.int(5...10) { // mud
                let c = CGPoint(x: inner.minX + CGFloat(rng.next()) * inner.width, y: inner.minY + CGFloat(rng.next()) * inner.height)
                mud.append((c, CGFloat(rng.range(14, 40)), CGFloat(rng.range(8, 18))))
            }
        }

        // a worn path from the camp toward a far edge (one or two)
        for _ in 0..<(rng.chance(0.6) ? 1 : 0) + (rng.chance(0.25) ? 1 : 0) {
            let target = CGPoint(x: inner.minX + CGFloat(rng.next()) * inner.width, y: rng.chance(0.5) ? inner.minY + 10 : inner.maxY - 10)
            var points: [CGPoint] = []
            let phase = rng.range(0, 6.28), sway = CGFloat(rng.range(40, 78))
            let steps = 30
            for k in 0...steps {
                let t = CGFloat(k) / CGFloat(steps)
                let dx = target.x - nest.x, dy = target.y - nest.y, len = max(1, hypot(dx, dy))
                let normal = CGPoint(x: -dy / len, y: dx / len)
                let w = (sin(t * 5.2 + CGFloat(phase)) * sway + sin(t * 11.3 + CGFloat(phase) * 1.7) * sway * 0.3) * sin(t * .pi)
                points.append(CGPoint(x: nest.x + dx * t + normal.x * w, y: nest.y + dy * t + normal.y * w))
            }
            paths.append(points)
        }

        standing.sort { $0.foot.y > $1.foot.y } // from the top of the screen down, so the nearer ones are drawn last
    }

    /// Mushrooms in clumps of one to six, each of its own size and mostly one colour, most of them at the foot of a tree, a stump, a log or a rock
    /// (that is where they grow), the rest in the open. Only about one place in eight has a fairy ring.
    private func scatterMushrooms(_ rng: inout TerrainRandom, clumps: Int, inner: CGRect) {
        let prefixes = ["tree-", "stump-", "log-", "rock-"]
        let hosts = (standing + lying).filter { item in prefixes.contains { item.sprite.hasPrefix($0) } }
        for _ in 0..<clumps {
            var anchor = CGPoint(x: inner.minX + CGFloat(rng.next()) * inner.width, y: inner.minY + CGFloat(rng.next()) * inner.height)
            if !hosts.isEmpty, rng.chance(0.65) {
                let host = hosts[rng.int(0...(hosts.count - 1))]
                anchor = CGPoint(x: host.foot.x + CGFloat(rng.range(-24, 24)), y: host.foot.y + CGFloat(rng.range(-10, 6)))
            }
            let kind = rng.int(0...3)
            for _ in 0..<rng.int(1...6) {
                let p = CGPoint(x: anchor.x + CGFloat(rng.range(-12, 12)), y: anchor.y + CGFloat(rng.range(-7, 7)))
                mushrooms.append((p, rng.int(0...2), rng.chance(0.75) ? kind : rng.int(0...3)))
            }
        }
        if rng.chance(0.12), let c = self.freeCentre(&rng, inner: inner) { rings.append((c, CGFloat(rng.range(14, 24)))) }
    }

    private func freeCentre(_ rng: inout TerrainRandom, inner: CGRect) -> CGPoint? {
        for _ in 0..<12 {
            let p = CGPoint(x: inner.minX + 40 + CGFloat(rng.next()) * (inner.width - 80), y: inner.minY + 40 + CGFloat(rng.next()) * (inner.height - 80))
            if !solids.contains(where: { $0.blocks(p, margin: 26) }) && !ponds.contains(where: { $0.blocks(p, margin: 30) }) { return p }
        }
        return nil
    }

    /// The goblins' camp: trampled earth round the nest, a stone fire ring, hide tents, a totem, a drying rack, wood, bones and spears.
    /// It is not there all at once: each thing has a size of camp it turns up at (`unlock`), from a fire ring to the totem pole.
    private func makeCamp(_ rng: inout TerrainRandom, nest: CGPoint, inner: CGRect) {
        clearing = (nest, CGFloat(rng.range(70, 88)))
        // the fire ring where the campfire party is lit, to the right of the nest (see Colony.fireSpot)
        let pit = CGPoint(x: nest.x + 90, y: nest.y - 10)
        if inner.insetBy(dx: -20, dy: -20).contains(pit) {
            firePit = pit
            lying.append(TerrainItem(sprite: "firepit-\(biome.rawValue)", foot: CGPoint(x: pit.x, y: pit.y - 4), unlock: 5))
        }
        var plan: [(kind: String, unlock: Int)] = [("bones-0", 8), ("stump", 12), ("firewood", 16), ("tent", 22), ("skull", 30), ("spears", 38),
                                                   ("rack", 48), ("tent", 60), ("bones-1", 68), ("totem", 85)]
        if rng.chance(0.5) { plan.append(("tent", 105)) }
        // slots round the nest, except the one on the right (the princess's side, and the fire ring)
        var slots: [Double] = []
        for k in 0..<12 {
            let angle: Double = Double(k) / 12.0 * 2.0 * Double.pi + 0.26
            let wrapped: Double = atan2(sin(angle), cos(angle))
            if abs(wrapped) > 0.9 { slots.append(angle) }
        }
        for k in stride(from: slots.count - 1, to: 0, by: -1) { slots.swapAt(k, rng.int(0...k)) }
        for (entry, angle) in zip(plan, slots) {
            let kind = entry.kind, unlock = entry.unlock
            let r = CGFloat(rng.range(64, 100))
            let a: Double = angle + rng.range(-0.15, 0.15)
            let dx: CGFloat = CGFloat(cos(a)) * r
            let dy: CGFloat = CGFloat(sin(a)) * r * 0.85
            let p = CGPoint(x: nest.x + dx, y: nest.y + dy)
            guard inner.insetBy(dx: 8, dy: 8).contains(p) else { continue }
            let name = kind.contains("-") ? "\(kind.split(separator: "-")[0])-\(biome.rawValue)-\(kind.split(separator: "-")[1])" : "\(kind)-\(biome.rawValue)"
            let item = TerrainItem(sprite: name, foot: p, unlock: unlock)
            func block(_ radius: CGFloat, _ lift: CGFloat) { solids.append(Solid(center: CGPoint(x: p.x, y: p.y + lift), radius: radius, unlock: unlock)) }
            switch kind {
            case "tent": standing.append(item); block(15, 6)
            case "rack": standing.append(item); block(14, 4)
            case "totem": standing.append(item); block(5, 2)
            case "firewood": standing.append(item); block(8, 3)
            case "skull": standing.append(item); block(3, 2)
            case "spears": standing.append(item)
            case "stump": lying.append(item); block(6, 3)
            default: lying.append(item)
            }
        }
    }

    /// A winding stream across the clearing (left to right, or top to bottom), passable only at the bridge (frozen ones are all passable).
    private func makeStream(_ rng: inout TerrainRandom, nest: CGPoint, taken: inout [(CGPoint, CGFloat)]) {
        let horizontal = rng.chance(0.5)
        let width = CGFloat(rng.range(16, 26))
        // the line must pass well clear of the camp
        let across = horizontal ? canvas.height : canvas.width
        let lo = across * 0.15, hi = across * 0.85
        var offset = CGFloat(rng.range(Double(lo), Double(hi)))
        let nestOffset = horizontal ? nest.y - canvas.minY : nest.x - canvas.minX
        if abs(offset - nestOffset) < 130 { offset = nestOffset + (offset < nestOffset ? -1 : 1) * 130 }
        guard offset > lo * 0.8, offset < across - lo * 0.8 else { return }
        let phase = rng.range(0, 6.28), sway = CGFloat(rng.range(14, 34))
        let length = horizontal ? canvas.width : canvas.height
        var points: [CGPoint] = []
        let steps = Int(length / 8)
        for k in 0...steps {
            let along = CGFloat(k) / CGFloat(steps) * length
            let wobble = sin(along / 70 + CGFloat(phase)) * sway
            let p = horizontal ? CGPoint(x: canvas.minX + along, y: canvas.minY + offset + wobble) : CGPoint(x: canvas.minX + offset + wobble, y: canvas.minY + along)
            points.append(p)
        }
        streams.append((points, width))
        // the bridge, somewhere in the middle stretch
        let bridgeAt = rng.int(Int(Double(steps) * 0.25)...Int(Double(steps) * 0.75))
        let a = points[max(0, bridgeAt - 1)], b = points[min(points.count - 1, bridgeAt + 1)]
        var angle = atan2(b.y - a.y, b.x - a.x) + .pi / 2 // across the water
        if angle > .pi { angle -= 2 * .pi }
        bridges.append((points[bridgeAt], angle, width + 14))
        if biome != .snow { // (ice can be walked on)
            for (k, p) in points.enumerated() where abs(k - bridgeAt) > 4 && k % 1 == 0 {
                solids.append(Solid(center: p, radius: width / 2 - 1))
            }
        }
        for (k, p) in points.enumerated() where k % 6 == 0 { taken.append((p, width + 10)) }
    }

    // MARK: Drawing the still parts

    /// The whole ground, everything on it, tinted for the hour. `origin` is where the view's corner is in the world.
    func render(size: CGSize, origin: CGPoint, scale: CGFloat, hour: Int) -> CGImage? {
        let w = Int(size.width * scale), h = Int(size.height * scale)
        guard w > 0, h > 0,
              let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue) else { return nil }
        ctx.scaleBy(x: scale, y: scale)
        ctx.translateBy(x: -origin.x, y: -origin.y)
        ctx.interpolationQuality = .none
        let bounds = CGRect(x: origin.x, y: origin.y, width: size.width, height: size.height)
        renderBounds = bounds
        let x = seasonPosition
        let now = clock ?? TerrainClock.now

        if isStrip {
            // (a strip is drawn over its own forest or meadow: only what stands on it, and the light of the hour over just that)
        } else if let tile = TerrainArt.image("ground-\(biome.rawValue)") { Scenery.fillGround(tile, in: bounds, scale: 2, into: ctx) } else {
            ctx.setFillColor(NSColor(calibratedRed: 0.23, green: 0.45, blue: 0.24, alpha: 1).cgColor)
            ctx.fill(bounds)
        }
        // the colour of the season over the ground: spring green, summer gold, autumn orange, winter white (blended between them)
        if !isStrip {
            let (seasonColor, seasonAlpha) = seasonTint(at: x)
            ctx.setFillColor(seasonColor.withAlphaComponent(seasonAlpha).cgColor)
            ctx.fill(bounds)
        }

        let nsctx = NSGraphicsContext(cgContext: ctx, flipped: false)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = nsctx

        // flat things first: the soft patches, the trampled earth round the camp
        for patch in patches { paintBlob(patch.center, patch.rx, patch.ry, patch.color, shadow: patch.color, feather: true) }
        if isStrip { paintStripSnow(amount: snowAmount(at: x)) } else { paintSnow(amount: snowAmount(at: x)) }
        if var clearing {
            clearing.radius *= CGFloat(min(1, 0.3 + Double(growth) / 110)) // the trampled earth spreads as the camp grows
            let earth = [NSColor(calibratedRed: 0.5, green: 0.38, blue: 0.24, alpha: 1), NSColor(calibratedRed: 0.45, green: 0.34, blue: 0.21, alpha: 1), NSColor(calibratedRed: 0.55, green: 0.43, blue: 0.28, alpha: 1)]
            paintBlob(clearing.center, clearing.radius + 12, clearing.radius * 0.8 + 10, NSColor(calibratedRed: 0.42, green: 0.32, blue: 0.2, alpha: 0.35), shadow: NSColor(calibratedRed: 0.42, green: 0.32, blue: 0.2, alpha: 0.35), feather: true)
            paintBlob(clearing.center, clearing.radius, clearing.radius * 0.8, earth[0], shadow: earth[1], feather: true, speckle: earth)
        }
        for mound in mounds { paintBlob(mound.center, mound.rx, mound.ry, NSColor(calibratedRed: 0.99, green: 1, blue: 1, alpha: 1), shadow: NSColor(calibratedRed: 0.78, green: 0.86, blue: 0.94, alpha: 1)) }
        for pool in mud {
            paintBlob(pool.center, pool.rx + 3, pool.ry + 3, NSColor(calibratedRed: 0.36, green: 0.3, blue: 0.18, alpha: 0.7), shadow: NSColor(calibratedRed: 0.36, green: 0.3, blue: 0.18, alpha: 0.7), feather: true)
            paintBlob(pool.center, pool.rx, pool.ry, NSColor(calibratedRed: 0.2, green: 0.17, blue: 0.1, alpha: 1), shadow: NSColor(calibratedRed: 0.14, green: 0.12, blue: 0.08, alpha: 1))
            paintBlob(CGPoint(x: pool.center.x - pool.rx * 0.3, y: pool.center.y + pool.ry * 0.3), pool.rx * 0.35, pool.ry * 0.2, NSColor(calibratedRed: 0.5, green: 0.55, blue: 0.4, alpha: 0.5), shadow: NSColor(calibratedRed: 0.5, green: 0.55, blue: 0.4, alpha: 0.5))
        }
        let dirt: [NSColor] = biome == .snow
            ? [NSColor(calibratedRed: 0.66, green: 0.62, blue: 0.58, alpha: 1), NSColor(calibratedRed: 0.58, green: 0.54, blue: 0.5, alpha: 1)]
            : [NSColor(calibratedRed: 0.62, green: 0.5, blue: 0.32, alpha: 1), NSColor(calibratedRed: 0.55, green: 0.44, blue: 0.28, alpha: 1)]
        for path in paths { paintBand(path, width: 13, colors: dirt, edge: nil, taper: true) }
        // the ground the goblins have worn bare
        if let life {
            let worn = life.worn()
            let earth = biome == .snow ? NSColor(calibratedRed: 0.6, green: 0.56, blue: 0.52, alpha: 1) : NSColor(calibratedRed: 0.52, green: 0.4, blue: 0.25, alpha: 1)
            for cell in worn.light { paintBlob(TerrainLife.center(of: cell, in: world), 9, 8, earth.withAlphaComponent(0.42), shadow: earth.withAlphaComponent(0.42), feather: true) }
            for cell in worn.heavy { paintBlob(TerrainLife.center(of: cell, in: world), 10, 9, earth.withAlphaComponent(0.8), shadow: earth.withAlphaComponent(0.8), feather: true, speckle: [earth, earth.blended(withFraction: 0.25, of: .black) ?? earth]) }
        }
        let flowerDensity = dotDensity(at: x)
        for (point, color) in dots where Double(TerrainScene.hash(point) % 100) < flowerDensity * 100 {
            color.setFill()
            NSRect(x: point.x, y: point.y, width: 3, height: 3).fill()
        }
        for ring in rings { paintMushroomRing(ring.center, ring.radius) }
        // (more of them after summer, none under snow)
        let mushroomDensity: Double = x >= 3.05 ? 0 : x >= 2 ? 1 : x < 0.3 ? 0.2 : biome == .swamp ? 0.9 : 0.55
        for m in mushrooms where Double(TerrainScene.hash(m.pos) % 100) < mushroomDensity * 100 { paintMushroom(m.pos, size: m.size, kind: m.kind) }
        for stream in streams {
            if biome == .snow || x >= 3.05 { // (a stream freezes over in winter)
                paintBand(stream.points, width: stream.width, colors: [NSColor(calibratedRed: 0.84, green: 0.93, blue: 0.98, alpha: 1), NSColor(calibratedRed: 0.76, green: 0.88, blue: 0.96, alpha: 1)],
                          edge: NSColor(calibratedRed: 0.96, green: 0.98, blue: 1, alpha: 1))
            } else {
                paintBand(stream.points, width: stream.width, colors: [NSColor(calibratedRed: 0.33, green: 0.63, blue: 0.85, alpha: 1), NSColor(calibratedRed: 0.24, green: 0.52, blue: 0.78, alpha: 1)],
                          edge: NSColor(calibratedRed: 0.66, green: 0.85, blue: 0.9, alpha: 1), bank: NSColor(calibratedRed: 0.62, green: 0.54, blue: 0.36, alpha: 1))
            }
        }
        for bridge in bridges { paintBridge(bridge.center, bridge.angle, bridge.length) }
        // puddles left by the rain
        if let life {
            for puddle in life.puddlePoints(origin: nest, now: now) { paintPuddle(puddle.center, puddle.radius, frozen: x >= 3.05 || biome == .snow) }
        }
        // leaves lying under the trees in autumn
        let plantedItems = plantingItems(now: now)
        var stumps: [TerrainItem] = []
        var trees: [TerrainItem] = []
        for item in standing where item.unlock <= growth {
            let result = afterCut(item)
            if let kept = result.item { trees.append(kept) }
            if let stump = result.stump { stumps.append(stump) }
        }
        trees += plantedItems.standing
        if x >= 2.1, x < 3.6 { paintLeafPiles(trees, amount: min(1, (x - 2.1) / 0.9)) }
        NSGraphicsContext.restoreGraphicsState()

        let frozen = x >= 3.05 && biome != .snow
        for pond in ponds { if let image = pond.image(frozen: frozen) { ctx.draw(image, in: pond.picture) } }
        drawFarm(in: ctx)
        for item in lying where item.unlock <= growth && !(isStrip && item.sprite.hasPrefix("log-") && cut(at: item.foot) != nil) { draw(item, in: ctx, season: x) }
        for item in plantedItems.lying + stumps + seasonalCampItems(at: x) + driftItems.map(\.item) { draw(item, in: ctx, season: x) }
        for item in (trees).sorted(by: { $0.foot.y > $1.foot.y }) { draw(item, in: ctx, season: x) }

        // the light of the hour over all of it
        if let tint = Scenery.tint(hour: hour) {
            if isStrip { ctx.setBlendMode(.sourceAtop) } // only over what was drawn, not the empty parts
            ctx.setFillColor(tint.color.withAlphaComponent(tint.alpha).cgColor)
            ctx.fill(bounds)
        }
        return ctx.makeImage()
    }

    // MARK: The camp through the year

    /// Things the goblins put out at each time of year once the camp is a fair size: a snowman and a second pile of firewood in winter, a hay
    /// bale and a heap of pumpkins in autumn. Where they go is fixed by the seed (behind the camp, away from the princess's side).
    private func seasonalCampItems(at x: Double) -> [TerrainItem] {
        guard growth >= 24 else { return [] }
        var rng = TerrainRandom(seed: seed &+ 2024)
        func spot(_ radius: Double) -> CGPoint {
            let a = rng.range(2.2, 4.2) // the left and back of the camp
            return CGPoint(x: campNest.x + CGFloat(cos(a) * radius), y: campNest.y + CGFloat(sin(a) * radius * 0.8))
        }
        let snowman = spot(rng.range(105, 135)), wood = spot(rng.range(90, 115)), hay = spot(rng.range(100, 130)), pumpkins = spot(rng.range(100, 130))
        var items: [TerrainItem] = []
        if x >= 3.0 || x < 0.25 {
            items.append(TerrainItem(sprite: "snowman", foot: snowman))
            items.append(TerrainItem(sprite: "firewood-\(biome.rawValue)", foot: wood))
        }
        if x >= 2.0, x < 3.3 {
            items.append(TerrainItem(sprite: "hay", foot: hay))
            if x >= 2.4 { items.append(TerrainItem(sprite: "pumpkins", foot: pumpkins)) }
        }
        return items
    }

    // MARK: The farm

    struct PlotInfo {
        let index: Int
        let state: Int
        let crop: Int
        let standAt: CGPoint
        let face: CGPoint
    }

    /// The plots that have been dug, with what state they are in and where a goblin stands to work at them.
    func plotInfos() -> [PlotInfo] {
        guard let life else { return [] }
        return plotSpots.enumerated().compactMap { i, plot in
            guard plot.unlock <= growth, visible(plot.center), life.state.plots.indices.contains(i) else { return nil }
            let side: CGFloat = TerrainScene.hash(plot.center) % 2 == 0 ? 1 : -1
            return PlotInfo(index: i, state: life.state.plots[i].state, crop: life.state.plots[i].crop,
                            standAt: CGPoint(x: plot.center.x + side * 14, y: plot.center.y - 7), face: CGPoint(x: plot.center.x + side * 6, y: plot.center.y + 10))
        }
    }

    /// Where the n-th plant of a plot stands (two rows of up to four).
    private func cropSpot(_ plot: CGPoint, _ n: Int) -> CGPoint {
        CGPoint(x: plot.x - 17 + CGFloat(n % 4) * 11.5 + (n >= 4 ? 5 : 0), y: plot.y + 3 + CGFloat(n / 4) * 11)
    }

    private func drawFarm(in ctx: CGContext) {
        guard !plotSpots.isEmpty else { return }
        for (i, plot) in plotSpots.enumerated() where plot.unlock <= growth {
            draw(TerrainItem(sprite: "plot-\(biome.rawValue)", foot: plot.center), in: ctx)
            guard let life, life.state.plots.indices.contains(i) else { continue }
            let s = life.state.plots[i]
            switch s.state {
            case 0: // fallow: weeds coming up
                ctx.setFillColor(NSColor(calibratedRed: 0.36, green: 0.62, blue: 0.3, alpha: 1).cgColor)
                for n in 0..<7 { ctx.fill(CGRect(x: plot.center.x - 18 + CGFloat(n) * 6 + CGFloat(TerrainScene.hash(CGPoint(x: n, y: i)) % 3), y: plot.center.y + 5 + CGFloat(n % 3) * 6, width: 2, height: 3)) }
            case 2: // sown: seeds on the earth
                ctx.setFillColor(NSColor(calibratedRed: 0.86, green: 0.78, blue: 0.5, alpha: 1).cgColor)
                for n in 0..<s.density * 2 { ctx.fill(CGRect(x: plot.center.x - 17 + CGFloat(n % 8) * 5 + CGFloat(n % 3), y: plot.center.y + 4 + CGFloat(n / 8) * 9 + CGFloat(n % 2) * 2, width: 2, height: 2)) }
            case 3, 4, 5:
                let fraction = s.state == 3 ? s.progress / max(1, s.hoursNeeded * 3600) : 1
                let stage = s.state == 4 ? 2 : (fraction < 0.4 ? 0 : 1)
                let name = "crop-\(s.crop)-\(s.state == 5 ? 1 : stage)"
                guard let image = s.state == 5 ? TerrainArt.image(name, mode: .bare) : TerrainArt.image(name) else { continue }
                for n in 0..<s.density {
                    let at = cropSpot(plot.center, n)
                    ctx.draw(image, in: CGRect(x: at.x - CGFloat(image.width) * 0.625, y: at.y, width: CGFloat(image.width) * 1.25, height: CGFloat(image.height) * 1.25))
                }
            default: break
            }
        }
    }

    // MARK: Seasons

    static func hash(_ p: CGPoint) -> Int { abs(Int(p.x) &* 73856093 ^ Int(p.y) &* 19349663) }

    /// The colour laid over the ground for a place in the year (0 to 4), blended between the season's own colours.
    private func seasonTint(at x: Double) -> (NSColor, CGFloat) {
        typealias K = (Double, Double, Double, Double)
        let keys: [K]
        switch biome {
        case .snow: keys = [(0.6, 0.85, 0.7, 0.06), (0.4, 0.75, 0.5, 0.14), (0.9, 0.6, 0.3, 0.06), (0.9, 0.95, 1, 0.10)]
        case .swamp: keys = [(0.5, 0.85, 0.45, 0.10), (0.8, 0.85, 0.35, 0.10), (0.7, 0.42, 0.15, 0.24), (0.85, 0.92, 0.98, 0.26)]
        default: keys = [(0.55, 0.9, 0.4, 0.10), (0.95, 0.9, 0.4, 0.06), (0.88, 0.5, 0.15, 0.20), (0.9, 0.95, 1, 0.32)]
        }
        // the keys are at the middle of each season
        let p = x - 0.5
        let i = Int((p < 0 ? p + 4 : p).rounded(.down)) % 4, j = (i + 1) % 4
        var f = (p < 0 ? p + 4 : p) - Double(i)
        f = f * f * (3 - 2 * f)
        let a = keys[i], b = keys[j]
        let color = NSColor(calibratedRed: CGFloat(a.0 + (b.0 - a.0) * f), green: CGFloat(a.1 + (b.1 - a.1) * f), blue: CGFloat(a.2 + (b.2 - a.2) * f), alpha: 1)
        return (color, CGFloat(a.3 + (b.3 - a.3) * f))
    }

    /// How much snow lies on the ground: none in summer, all over in winter, thawing away in spring (the snow biome is never bare).
    private func snowAmount(at x: Double) -> Double {
        var amount = 0.0
        if x >= 3 { amount = min(1, 0.4 + (x - 3) * 0.7) } else if x < 0.5 { amount = 0.8 * (1 - x / 0.5) } else if x >= 2.85 { amount = (x - 2.85) * 2 }
        return biome == .snow ? max(0.55, amount) : amount
    }

    /// How many of the flowers (or leaves) that lie about are out.
    private func dotDensity(at x: Double) -> Double {
        switch biome {
        case .meadow: return x < 0.3 ? 0.3 + x : x < 2 ? 1 : x < 3 ? max(0, 1 - (x - 2) * 0.8) : 0
        case .forest: return x >= 2 && x < 3.4 ? 1 : 0.35
        default: return 1
        }
    }

    private func paintSnow(amount: Double) {
        guard amount > 0.02 else { return }
        var rng = TerrainRandom(seed: seed &+ 999)
        // low, ragged drifts that run together as more falls: a blue shadow under a white top, so it reads as snow lying on the ground
        let count = Int(amount * Double(canvas.width * canvas.height) / 2600)
        for _ in 0..<count {
            let c = CGPoint(x: canvas.minX + CGFloat(rng.next()) * canvas.width, y: canvas.minY + CGFloat(rng.next()) * canvas.height)
            let rx = CGFloat(rng.range(14, 38)), ry = rx * CGFloat(rng.range(0.22, 0.4))
            guard renderBounds.insetBy(dx: -60, dy: -60).contains(c) else { continue } // (off the screen)
            let alpha = CGFloat(min(0.85, 0.3 + amount * 0.55))
            paintBlob(CGPoint(x: c.x, y: c.y - 2), rx + 2, ry + 1, NSColor(calibratedRed: 0.62, green: 0.74, blue: 0.9, alpha: alpha * 0.7), shadow: NSColor(calibratedRed: 0.62, green: 0.74, blue: 0.9, alpha: alpha * 0.7), feather: true)
            paintBlob(c, rx, ry, NSColor(calibratedRed: 0.98, green: 0.99, blue: 1, alpha: alpha), shadow: NSColor(calibratedRed: 0.9, green: 0.95, blue: 1, alpha: alpha), feather: true)
        }
    }

    /// Snow lying on a strip's path: low drifts along it, thicker toward the back, more of them the deeper the winter.
    private func paintStripSnow(amount: Double) {
        guard amount > 0.02 else { return }
        var rng = TerrainRandom(seed: seed &+ 999)
        let horizontal = stripEdge == .bottom
        let length = horizontal ? world.width : world.height, across = horizontal ? world.height : world.width
        let count = Int(amount * Double(length) / 9)
        for _ in 0..<count {
            let along = CGFloat(rng.next()) * length, depth = CGFloat(rng.next()) * across
            let c = horizontal ? CGPoint(x: world.minX + along, y: world.minY + depth) : CGPoint(x: world.minX + depth, y: world.minY + along)
            let r = CGFloat(rng.range(8, 22))
            let rx = horizontal ? r : r * 0.5, ry = horizontal ? r * 0.32 : r * 0.9
            guard renderBounds.insetBy(dx: -40, dy: -40).contains(c) else { continue }
            let alpha = CGFloat(min(0.85, 0.35 + amount * 0.5))
            paintBlob(CGPoint(x: c.x, y: c.y - 1), rx + 1.5, ry + 1, NSColor(calibratedRed: 0.62, green: 0.74, blue: 0.9, alpha: alpha * 0.7), shadow: NSColor(calibratedRed: 0.62, green: 0.74, blue: 0.9, alpha: alpha * 0.7), feather: true)
            paintBlob(c, rx, ry, NSColor(calibratedRed: 0.98, green: 0.99, blue: 1, alpha: alpha), shadow: NSColor(calibratedRed: 0.9, green: 0.95, blue: 1, alpha: alpha), feather: true)
        }
    }

    private func paintPuddle(_ c: CGPoint, _ radius: CGFloat, frozen: Bool) {
        guard radius > 3 else { return }
        let rim = NSColor(calibratedRed: 0.3, green: 0.24, blue: 0.16, alpha: 0.45)
        paintBlob(c, radius + 3, radius * 0.62 + 3, rim, shadow: rim, feather: true)
        let water = frozen ? NSColor(calibratedRed: 0.86, green: 0.94, blue: 0.99, alpha: 1)
                           : (biome == .swamp ? NSColor(calibratedRed: 0.3, green: 0.4, blue: 0.28, alpha: 1) : NSColor(calibratedRed: 0.3, green: 0.55, blue: 0.82, alpha: 1))
        let deep = frozen ? NSColor(calibratedRed: 0.72, green: 0.86, blue: 0.95, alpha: 1) : water.blended(withFraction: 0.3, of: .black) ?? water
        paintBlob(c, radius, radius * 0.62, water, shadow: deep)
        paintBlob(CGPoint(x: c.x - radius * 0.25, y: c.y + radius * 0.2), radius * 0.4, radius * 0.14, NSColor(calibratedWhite: 1, alpha: 0.4), shadow: NSColor(calibratedWhite: 1, alpha: 0.4)) // sky in the water
    }

    private func paintLeafPiles(_ trees: [TerrainItem], amount: Double) {
        let colors = [NSColor(calibratedRed: 0.92, green: 0.55, blue: 0.16, alpha: 1), NSColor(calibratedRed: 0.8, green: 0.28, blue: 0.14, alpha: 1), NSColor(calibratedRed: 0.94, green: 0.78, blue: 0.24, alpha: 1)]
        for tree in trees where TerrainArt.isRound(tree.sprite) {
            var rng = TerrainRandom(seed: UInt64(TerrainScene.hash(tree.foot)))
            for _ in 0..<(3 + Int(amount * 16)) {
                let a = rng.range(0, 2 * .pi), r = rng.range(4, 24)
                colors[rng.int(0...2)].setFill()
                NSRect(x: tree.foot.x + CGFloat(cos(a) * r), y: tree.foot.y + CGFloat(sin(a) * r * 0.6) - 4, width: 3, height: 3).fill()
            }
        }
    }

    /// The saplings and trees that have grown on their own, as things to draw: standing ones, and fallen ones lying down.
    private func plantingItems(now: Double) -> (standing: [TerrainItem], lying: [TerrainItem]) {
        guard let life else { return ([], []) }
        var up: [TerrainItem] = [], down: [TerrainItem] = []
        for plant in life.state.plantings where plant.planted <= now {
            let foot = point(plant.fx, plant.fy)
            let b = biome.rawValue
            switch life.stage(of: plant, at: now) {
            case .sprout: up.append(TerrainItem(sprite: "sprout-\(b)-\(plant.variant)", foot: foot))
            case .sapling: up.append(TerrainItem(sprite: "sapling-\(b)-\(plant.variant)", foot: foot))
            case .young: up.append(TerrainItem(sprite: "young-\(b)-\(plant.variant)", foot: foot))
            case .tree:
                let name: String
                switch biome {
                case .meadow, .forest: name = plant.variant == 0 ? "tree-\(b)-\(plant.kind % 2)" : "tree-\(b)-\(biome == .forest && plant.kind == 2 ? 3 : 2)"
                case .snow: name = "tree-snow-\(plant.kind % 3)"
                case .swamp: name = plant.variant == 0 ? "tree-swamp-\(plant.kind % 3)" : "tree-swamp-\(3 + plant.kind % 2)"
                }
                up.append(TerrainItem(sprite: name, foot: foot))
            case .fallen:
                down.append(TerrainItem(sprite: "log-\(b)", foot: CGPoint(x: foot.x, y: foot.y - 3)))
                down.append(TerrainItem(sprite: "stump-\(b)", foot: CGPoint(x: foot.x + 20, y: foot.y)))
            }
        }
        return (up, down)
    }

    private func draw(_ item: TerrainItem, in ctx: CGContext, season x: Double = 1.4) {
        guard let image = TerrainArt.image(item.sprite, mode: TerrainArt.mode(for: item, biome: biome, season: x, snow: snowAmount(at: x))) else { return }
        // (on a strip the things are drawn a quarter smaller: the same size of pixel as the goblins, so tents and rocks are not crowding a path only
        // thirty or forty points wide)
        let scale = TerrainArt.scale(item.sprite) * (isStrip ? 0.75 : 1)
        let w = CGFloat(image.width) * scale, h = CGFloat(image.height) * scale
        ctx.draw(image, in: CGRect(x: item.foot.x - w / 2, y: item.foot.y - 2, width: w, height: h))
    }

    /// A blocky ellipse (whole 2-point squares) with a darker underside. `feather` thins its edge out, `speckle` mixes in other colours.
    private func paintBlob(_ c: CGPoint, _ rx: CGFloat, _ ry: CGFloat, _ color: NSColor, shadow: NSColor, feather: Bool = false, speckle: [NSColor] = []) {
        guard renderBounds.insetBy(dx: -(rx + 8), dy: -(ry + 8)).contains(c) else { return } // (nothing to draw off the screen)
        var y = -ry
        while y <= ry {
            var x = -rx
            while x <= rx {
                let d = (x / rx) * (x / rx) + (y / ry) * (y / ry)
                let cx = Int((c.x + x) / 2), cy = Int((c.y + y) / 2)
                let hash = abs(cx &* 73856093 ^ cy &* 19349663) % 100
                if d <= 1, !feather || d < 0.62 || hash < Int((1 - d) / 0.38 * 100) {
                    if !speckle.isEmpty, hash % 5 < 3 { speckle[hash % speckle.count].setFill() } else { (y < -ry * 0.3 ? shadow : color).setFill() }
                    NSRect(x: (c.x + x).rounded(.down), y: (c.y + y).rounded(.down), width: 2, height: 2).fill()
                }
                x += 2
            }
            y += 2
        }
    }

    /// A band of the given width along a line, in 2-point squares with a ragged edge (a path, a stream).
    private func paintBand(_ points: [CGPoint], width: CGFloat, colors: [NSColor], edge: NSColor?, bank: NSColor? = nil, taper: Bool = false) {
        var cells: [Int64: (CGFloat, Bool)] = [:]
        func key(_ x: Int, _ y: Int) -> Int64 { Int64(x) << 32 | Int64(UInt32(bitPattern: Int32(y))) }
        for k in 0..<max(0, points.count - 1) {
            // a worn path narrows toward its far end
            let half = width / 2 * (taper ? 0.55 + 0.45 * CGFloat(sin(Double(k) / Double(max(1, points.count - 1)) * .pi)) : 1)
            let a = points[k], b = points[k + 1]
            let steps = max(1, Int(hypot(b.x - a.x, b.y - a.y) / 2))
            for s in 0...steps {
                let t = CGFloat(s) / CGFloat(steps)
                let p = CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
                let reach = Int((half + (bank == nil ? 0 : 4)) / 2) + 1
                let cx = Int((p.x / 2).rounded(.down)), cy = Int((p.y / 2).rounded(.down))
                for dy in -reach...reach {
                    for dx in -reach...reach {
                        let d = hypot(CGFloat(dx) * 2, CGFloat(dy) * 2)
                        let wobble = CGFloat(((cx + dx) * 7 + (cy + dy) * 13) % 5) * 0.4
                        if d < half + wobble - 0.6 { cells[key(cx + dx, cy + dy)] = (d, false) }
                        else if let bank, d < half + 3.6 + wobble, cells[key(cx + dx, cy + dy)] == nil { cells[key(cx + dx, cy + dy)] = (d, true) }
                    }
                }
            }
        }
        let half = width / 2
        for (k, value) in cells {
            let x = Int(k >> 32), y = Int(Int32(truncatingIfNeeded: k))
            let cell = NSRect(x: CGFloat(x) * 2, y: CGFloat(y) * 2, width: 2, height: 2)
            if value.1, let bank { bank.setFill() } else if let edge, value.0 > half - 2.2 { edge.setFill() } else { colors[((x + y * 3) % colors.count + colors.count) % colors.count].setFill() } // (coordinates can be negative)
            cell.fill()
        }
    }

    private func paintBridge(_ c: CGPoint, _ angle: CGFloat, _ length: CGFloat) {
        // planks laid across the stream, along its way
        let wood = [NSColor(calibratedRed: 0.62, green: 0.44, blue: 0.24, alpha: 1), NSColor(calibratedRed: 0.5, green: 0.34, blue: 0.18, alpha: 1)]
        let dx = cos(angle), dy = sin(angle)
        let along = CGPoint(x: -dy, y: dx) // the way the stream runs
        for plank in -3...3 {
            let base = CGPoint(x: c.x + along.x * CGFloat(plank) * 4, y: c.y + along.y * CGFloat(plank) * 4)
            var t = -length / 2
            while t <= length / 2 {
                wood[abs(plank) % 2].setFill()
                NSRect(x: (base.x + dx * t).rounded(.down), y: (base.y + dy * t).rounded(.down), width: 3, height: 3).fill()
                t += 2
            }
        }
        NSColor(calibratedRed: 0.32, green: 0.2, blue: 0.1, alpha: 1).setFill()
        for side: CGFloat in [-1, 1] { // the two rails
            var t = -length / 2
            let base = CGPoint(x: c.x + along.x * side * 15, y: c.y + along.y * side * 15)
            while t <= length / 2 {
                NSRect(x: (base.x + dx * t).rounded(.down), y: (base.y + dy * t).rounded(.down), width: 2, height: 2).fill()
                t += 3
            }
        }
    }

    /// One mushroom: a pale stem and a cap (red with white spots, brown, tan or purple), in three sizes, with a little shadow.
    private func paintMushroom(_ p: CGPoint, size: Int, kind: Int) {
        let capW = CGFloat([5, 7, 10][size]), stem = CGFloat([2, 3, 4][size])
        NSColor(calibratedWhite: 0, alpha: 0.2).setFill()
        NSBezierPath(ovalIn: NSRect(x: p.x - capW / 2 - 1, y: p.y - 2, width: capW + 2, height: 3)).fill()
        NSColor(calibratedRed: 0.95, green: 0.92, blue: 0.83, alpha: 1).setFill()
        NSRect(x: p.x - 1, y: p.y, width: 2, height: stem).fill()
        let cap: NSColor
        switch kind {
        case 0: cap = NSColor(calibratedRed: 0.86, green: 0.2, blue: 0.2, alpha: 1)
        case 1: cap = NSColor(calibratedRed: 0.6, green: 0.4, blue: 0.22, alpha: 1)
        case 2: cap = NSColor(calibratedRed: 0.86, green: 0.76, blue: 0.56, alpha: 1)
        default: cap = NSColor(calibratedRed: 0.62, green: 0.42, blue: 0.74, alpha: 1)
        }
        cap.setFill()
        NSRect(x: p.x - capW / 2, y: p.y + stem, width: capW, height: 2).fill()
        NSRect(x: p.x - capW / 2 + 1, y: p.y + stem + 2, width: capW - 2, height: 1.5).fill()
        (cap.blended(withFraction: 0.35, of: .black) ?? cap).setFill()
        NSRect(x: p.x - capW / 2, y: p.y + stem, width: capW, height: 0.8).fill()
        if kind == 0 {
            NSColor.white.setFill()
            NSRect(x: p.x - capW / 2 + 1, y: p.y + stem + 1, width: 1, height: 1).fill()
            if size > 0 { NSRect(x: p.x + 1, y: p.y + stem + 2, width: 1, height: 1).fill() }
        }
    }

    private func paintMushroomRing(_ c: CGPoint, _ radius: CGFloat) {
        let count = Int(radius / 2.4) + 4
        for k in 0..<count {
            let a = Double(k) / Double(count) * 2 * .pi
            let p = CGPoint(x: c.x + CGFloat(cos(a)) * radius, y: c.y + CGFloat(sin(a)) * radius * 0.6)
            NSColor(calibratedRed: 0.95, green: 0.93, blue: 0.85, alpha: 1).setFill()
            NSRect(x: p.x, y: p.y, width: 2, height: 3).fill()
            NSColor(calibratedRed: 0.85, green: 0.2, blue: 0.2, alpha: 1).setFill()
            NSRect(x: p.x - 1, y: p.y + 3, width: 4, height: 2).fill()
            NSColor.white.setFill()
            NSRect(x: p.x + 1, y: p.y + 4, width: 1, height: 1).fill()
        }
    }

    /// The ring of forest round the window is tinted to match (see `Biome.ringTint`).
    var ringTint: (NSColor, CGFloat)? { biome.ringTint }
}

/// The terrain sprites (Resources/Terrain, made by tools/make_terrain.py).
enum TerrainArt {
    private static var cache: [String: CGImage] = [:]

    /// Points per art pixel: trees and rocks at 2, the small camp things a little smaller so they suit the goblins.
    static func scale(_ name: String) -> CGFloat {
        let kind = name.split(separator: "-").first.map(String.init) ?? ""
        switch kind {
        case "tent": return 1.5
        case "totem", "rack", "menhir", "spears", "firewood", "stump", "fern", "tuft", "cattail", "snowman", "hay", "pumpkins": return 1.6
        case "skull", "bones", "firepit", "log", "plot": return 1.5
        default: return name.hasPrefix("tree-swamp-3") || name.hasPrefix("tree-swamp-4") ? 1.35 : 2 // (the willows are big already)
        }
    }

    /// How a tree is dressed for the season: leaves turning, bare branches, blossom, or snow on top.
    enum Mode: Hashable {
        case normal, autumn(Int), bare, blossom, frost, bareFrost
    }

    /// Round-crowned trees (the ones whose leaves turn and fall).
    static func isRound(_ name: String) -> Bool {
        ["tree-meadow-0", "tree-meadow-1", "tree-forest-0", "tree-forest-1", "young-meadow-0", "young-forest-0", "sapling-meadow-0", "sapling-forest-0"].contains(name)
    }

    static func isTree(_ name: String) -> Bool { ["tree", "young", "sapling"].contains(name.split(separator: "-").first.map(String.init) ?? "") }

    static func mode(for item: TerrainItem, biome: Biome, season x: Double, snow: Double) -> Mode {
        guard isTree(item.sprite) else { return .normal }
        let round = isRound(item.sprite)
        let h = TerrainScene.hash(item.foot) % 100
        if x >= 3.02 { return biome == .snow ? .normal : (round ? .bareFrost : .frost) }
        if x < 0.18 { return round ? (snow > 0.15 ? .bareFrost : .bare) : (snow > 0.25 && biome != .snow ? .frost : .normal) }
        if x < 0.9 { return round && h % 3 == 0 ? .blossom : .normal }
        if x >= 2.0, round { return Double(h) < (x - 2.0) / 0.9 * 110 ? .autumn(h % 3) : .normal }
        return .normal
    }

    private static var variants: [String: CGImage] = [:]

    static func image(_ name: String, mode: Mode) -> CGImage? {
        guard mode != .normal else { return image(name) }
        let key = "\(name)|\(mode)"
        if let hit = variants[key] { return hit }
        guard let base = image(name), let ctx = CGContext(data: nil, width: base.width, height: base.height, bitsPerComponent: 8, bytesPerRow: 0,
                                                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return image(name) }
        let rect = CGRect(x: 0, y: 0, width: base.width, height: base.height)
        ctx.draw(base, in: rect)
        func recolor(_ color: NSColor, alpha: CGFloat) {
            ctx.saveGState()
            ctx.clip(to: rect, mask: base)
            ctx.setBlendMode(.color)
            ctx.setFillColor(color.withAlphaComponent(alpha).cgColor)
            ctx.fill(rect)
            ctx.restoreGState()
        }
        func snowCap() {
            ctx.saveGState()
            ctx.clip(to: rect, mask: base)
            let top = CGFloat(base.height)
            for row in 0..<Int(top * 0.5) { // snow on the upper half, thinning downward
                let f = 1 - CGFloat(row) / (top * 0.5)
                ctx.setFillColor(NSColor(calibratedRed: 0.97, green: 0.99, blue: 1, alpha: 0.92 * f).cgColor)
                ctx.fill(CGRect(x: 0, y: top - CGFloat(row) - 1, width: CGFloat(base.width), height: 1))
            }
            ctx.restoreGState()
        }
        switch mode {
        case .autumn(let i): recolor([NSColor(calibratedRed: 0.95, green: 0.55, blue: 0.14, alpha: 1), NSColor(calibratedRed: 0.86, green: 0.24, blue: 0.14, alpha: 1), NSColor(calibratedRed: 0.96, green: 0.8, blue: 0.22, alpha: 1)][i % 3], alpha: 0.9)
        case .bare: recolor(NSColor(calibratedRed: 0.5, green: 0.42, blue: 0.36, alpha: 1), alpha: 0.7)
        case .bareFrost: recolor(NSColor(calibratedRed: 0.5, green: 0.42, blue: 0.36, alpha: 1), alpha: 0.7); snowCap()
        case .blossom: recolor(NSColor(calibratedRed: 1, green: 0.74, blue: 0.86, alpha: 1), alpha: 0.9)
        case .frost: snowCap()
        case .normal: break
        }
        guard let result = ctx.makeImage() else { return image(name) }
        variants[key] = result
        return result
    }

    static func image(_ name: String) -> CGImage? {
        if let hit = cache[name] { return hit }
        guard let url = Bundle.main.resourceURL?.appendingPathComponent("Terrain/\(name).png"),
              let source = CGImageSourceCreateWithURL(url as CFURL, nil), let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
        cache[name] = image
        return image
    }
}
