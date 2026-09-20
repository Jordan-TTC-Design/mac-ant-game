import Foundation
import CoreGraphics

/// The camp window's place keeps changing, day and night, whether or not anybody is watching: the seasons turn (a season is three days,
/// so a year is twelve), rain leaves puddles that dry up, saplings come up and grow into trees (and now and then one falls), and the ground the
/// goblins tread most is worn bare. Every change is a matter of chance, so no two camps go the same way. It is all kept as timestamps, so
/// the camp comes back after a night off with what would have happened in the meantime.

enum Season: Int, CaseIterable {
    case spring, summer, autumn, winter

    var name: String {
        switch self {
        case .spring: return "春天"
        case .summer: return "夏天"
        case .autumn: return "秋天"
        case .winter: return "冬天"
        }
    }
}

/// The clock the changes run on. `CAMP_TERRAIN_SPEED` makes it run faster (tests: 2000 makes a day last about 45 seconds) and
/// `CAMP_SEASON_DAYS` changes how long a season is (3 days).
enum TerrainClock {
    static let speed = Double(ProcessInfo.processInfo.environment["CAMP_TERRAIN_SPEED"] ?? "") ?? 1
    static let secondsPerSeason = (Double(ProcessInfo.processInfo.environment["CAMP_SEASON_DAYS"] ?? "") ?? 3) * 86_400
    private static let start = Date.timeIntervalSinceReferenceDate

    static var now: Double { start + (Date.timeIntervalSinceReferenceDate - start) * speed }
}

struct Puddle: Codable {
    /// Where it is, as a fraction of the clearing (so it stays put when the window is resized), and how wide, in points.
    var fx: Double
    var fy: Double
    var radius: Double
    var born: Double
    /// Seconds until it has dried up.
    var life: Double
}

struct Planting: Codable {
    var fx: Double
    var fy: Double
    /// Round or pointed (0 or 1), which of that shape's trees it grows into, and how fast it grows (0.7 to 1.4 times).
    var variant: Int
    var kind: Int
    var pace: Double
    var planted: Double
    /// Set once it has fallen: when.
    var fell: Double?
}

struct TerrainLifeState: Codable {
    var seed: UInt64
    var epoch: Double
    /// Where in the year the camp began, in seasons (0 to 4): camps do not all start in spring.
    var seasonOffset: Double
    var lastRoll: Double
    var puddles: [Puddle] = []
    var plantings: [Planting] = []
    /// How much the goblins have trodden each cell of the ground (by `cell(at:)`), in tenths of a second of company, thinned out as it goes.
    var heat: [Int: Int] = [:]
    var heatTime: Double = 0
}

/// How grown a planting is.
enum GrowthStage: Int, Comparable {
    case sprout, sapling, young, tree, fallen
    static func < (a: GrowthStage, b: GrowthStage) -> Bool { a.rawValue < b.rawValue }
}

final class TerrainLife {
    private(set) var state: TerrainLifeState
    /// Goes up whenever something you can see has changed (a puddle, a plant growing, the season moving on, a new trail), so the baked picture is redone.
    private(set) var version = 0
    private var lastSeasonStep = -1
    private var lastTrailSignature = 0
    private var stages: [Int: GrowthStage] = [:]
    var onChange: (() -> Void)?

    static let cellSize: CGFloat = 14
    private static let maxPlantings = 14
    private static let maxPuddles = 8
    private static let step = 600.0

    init(seed: UInt64, now: Double = TerrainClock.now, state: TerrainLifeState? = nil) {
        if let state, state.seed == seed {
            self.state = state
        } else {
            var rng = TerrainRandom(seed: seed &+ 4242)
            self.state = TerrainLifeState(seed: seed, epoch: now, seasonOffset: rng.range(0, 4), lastRoll: now)
        }
    }

    // MARK: The seasons

    /// Which season it is and how far through it (0 to 1).
    func season(at now: Double = TerrainClock.now) -> (season: Season, progress: Double) {
        // `CAMP_SEASON=spring|summer|autumn|winter` holds the season still (tests)
        if let forced = ProcessInfo.processInfo.environment["CAMP_SEASON"], let index = ["spring", "summer", "autumn", "winter"].firstIndex(of: forced) {
            return (Season(rawValue: index) ?? .summer, 0.5)
        }
        let seasons = (now - state.epoch) / TerrainClock.secondsPerSeason + state.seasonOffset
        let wrapped = seasons.truncatingRemainder(dividingBy: 4)
        let positive = wrapped < 0 ? wrapped + 4 : wrapped
        let index = min(3, Int(positive))
        return (Season(rawValue: index) ?? .spring, positive - Double(index))
    }

    // MARK: Trees

    func stage(of plant: Planting, at now: Double = TerrainClock.now) -> GrowthStage {
        if plant.fell != nil { return .fallen }
        let age = (now - plant.planted) * plant.pace / 3600 // hours, at its own pace
        return age < 3 ? .sprout : age < 14 ? .sapling : age < 36 ? .young : .tree
    }

    // MARK: Events

    /// Rolls what chance would have done since the last time (in ten-minute steps, at most four days' worth). `spot` finds a free place for
    /// something of the given size, as a point in the clearing, or nil. Returns true if anything visible changed.
    @discardableResult
    func advance(now: Double = TerrainClock.now, spot: (inout TerrainRandom, CGFloat) -> CGPoint?, fraction: (CGPoint) -> CGPoint) -> Bool {
        var changed = false
        let from = max(state.lastRoll, now - 4 * 86_400)
        var t = from
        while t + TerrainLife.step <= now {
            t += TerrainLife.step
            var rng = TerrainRandom(seed: state.seed &* 31 &+ UInt64(bitPattern: Int64(t / TerrainLife.step)))
            let (season, _) = self.season(at: t)
            // a sapling comes up (most in spring), fewer the more trees there already are
            let rate: Double = [0.016, 0.011, 0.008, 0.002][season.rawValue]
            let alive = state.plantings.filter { $0.fell == nil }.count
            if alive < TerrainLife.maxPlantings, rng.chance(rate * (1 - Double(alive) / Double(TerrainLife.maxPlantings + 2))) {
                if let p = spot(&rng, 12) {
                    let f = fraction(p)
                    let variant = rng.chance(0.5) ? 0 : 1
                    state.plantings.append(Planting(fx: Double(f.x), fy: Double(f.y), variant: variant, kind: rng.int(0...2), pace: rng.range(0.7, 1.4), planted: t))
                    changed = true
                }
            }
            // an old tree falls, or a seedling does not make it (rare)
            for i in state.plantings.indices where state.plantings[i].fell == nil {
                let stage = self.stage(of: state.plantings[i], at: t)
                if (stage == .tree && rng.chance(0.00022)) || (stage <= .young && rng.chance(0.00012)) {
                    state.plantings[i].fell = t
                    changed = true
                }
            }
            // a wet night: a few puddles, if they have not dried by now
            if rng.chance(0.004) {
                for _ in 0..<rng.int(1...3) {
                    if let p = spot(&rng, 18) {
                        let f = fraction(p)
                        let puddle = Puddle(fx: Double(f.x), fy: Double(f.y), radius: rng.range(12, 34), born: t, life: rng.range(2, 9) * 3600)
                        if puddle.born + puddle.life > now, state.puddles.count < TerrainLife.maxPuddles { state.puddles.append(puddle); changed = true }
                    }
                }
            }
        }
        state.lastRoll = t
        // fallen trees rot away after a couple of days; puddles dry
        let before = state.plantings.count + state.puddles.count
        state.plantings.removeAll { ($0.fell.map { now - $0 > 2 * 86_400 }) ?? false }
        state.puddles.removeAll { $0.born + $0.life < now }
        if state.plantings.count + state.puddles.count != before { changed = true }
        // the trodden ground slowly grows back
        if state.heatTime > 0, now - state.heatTime > 60 {
            let factor = pow(0.5, (now - state.heatTime) / (30 * 3600))
            state.heat = state.heat.compactMapValues { let v = Int(Double($0) * factor); return v >= 3 ? v : nil }
            state.heatTime = now
        }
        // has anything you can see moved on?
        for plant in state.plantings {
            let s = stage(of: plant, at: now)
            let key = Int(plant.planted)
            if stages[key] != s { stages[key] = s; changed = true }
        }
        let seasons = season(at: now)
        let seasonStep = seasons.season.rawValue * 8 + Int(seasons.progress * 8)
        if seasonStep != lastSeasonStep { lastSeasonStep = seasonStep; changed = true }
        let signature = trailSignature()
        if signature != lastTrailSignature { lastTrailSignature = signature; changed = true }
        if changed { version += 1; onChange?() }
        return changed
    }

    /// Rain is falling right now: now and then it leaves a puddle. `dt` is the time since the last call.
    func rain(dt: Double, now: Double = TerrainClock.now, spot: (inout TerrainRandom, CGFloat) -> CGPoint?, fraction: (CGPoint) -> CGPoint) {
        var rng = TerrainRandom(seed: UInt64(bitPattern: Int64(now * 1000)) &+ state.seed)
        guard state.puddles.count < TerrainLife.maxPuddles, rng.chance(dt / 45) else { return }
        guard let p = spot(&rng, 18) else { return }
        let f = fraction(p)
        state.puddles.append(Puddle(fx: Double(f.x), fy: Double(f.y), radius: rng.range(12, 36), born: now, life: rng.range(1.5, 7) * 3600))
        version += 1
        onChange?()
    }

    // MARK: Trodden ground

    /// Which cell of the ground a point is in (relative to the clearing's corner).
    static func cell(at p: CGPoint, in world: CGRect) -> Int {
        let cx = Int((p.x - world.minX) / cellSize), cy = Int((p.y - world.minY) / cellSize)
        return cy * 1000 + cx
    }

    static func center(of cell: Int, in world: CGRect) -> CGPoint {
        CGPoint(x: world.minX + (CGFloat(cell % 1000) + 0.5) * cellSize, y: world.minY + (CGFloat(cell / 1000) + 0.5) * cellSize)
    }

    /// Goblins were standing here for `seconds`.
    func tread(_ points: [CGPoint], seconds: Double, in world: CGRect, now: Double = TerrainClock.now) {
        if state.heatTime == 0 { state.heatTime = now }
        let add = Int(seconds * 10)
        for p in points where world.contains(p) { state.heat[TerrainLife.cell(at: p, in: world), default: 0] += add }
    }

    /// The cells that are worn: lightly and heavily. Worn means well above the average of the cells that are trodden at all.
    func worn() -> (light: [Int], heavy: [Int]) {
        guard state.heat.count > 30 else { return ([], []) }
        let mean = Double(state.heat.values.reduce(0, +)) / Double(state.heat.count)
        var light: [Int] = [], heavy: [Int] = []
        for (cell, value) in state.heat {
            let v = Double(value)
            if v > max(600, mean * 6) { heavy.append(cell) } else if v > max(300, mean * 3) { light.append(cell) }
        }
        return (light.sorted(), heavy.sorted())
    }

    private func trailSignature() -> Int {
        let (light, heavy) = worn()
        var h = Hasher()
        h.combine(light.count / 4)
        h.combine(heavy.count / 4)
        return h.finalize()
    }

    // MARK: Puddles

    func puddlePoints(in world: CGRect, now: Double = TerrainClock.now) -> [(center: CGPoint, radius: CGFloat, wetness: Double)] {
        state.puddles.compactMap { p in
            let age = now - p.born
            guard age >= 0, age < p.life else { return nil }
            // it grows while it is filling and shrinks as it dries
            let fill = min(1, age / 600), dry = max(0, 1 - max(0, age - p.life * 0.55) / (p.life * 0.45))
            let wetness = min(fill, dry)
            return (CGPoint(x: world.minX + CGFloat(p.fx) * world.width, y: world.minY + CGFloat(p.fy) * world.height), CGFloat(p.radius * (0.4 + 0.6 * wetness)), wetness)
        }
    }
}
