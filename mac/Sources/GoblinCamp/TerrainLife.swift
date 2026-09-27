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

/// Something the goblins took from the place: a tree they felled (a stump is left, and rots away after a few days) or a chunk of a rock (a
/// rock shrinks with each one and is gone when it has none left). Found again by where it stood, as a fraction of the clearing.
/// A log or a stone that has turned up on a strip's path since the place was made (fallen from the trees behind, washed up by the rain).
struct Drift: Codable {
    var fx: Double
    var fy: Double
    /// 0 a log, 1 a small rock.
    var kind: Int
    var born: Double
}

struct Cut: Codable {
    var fx: Double
    var fy: Double
    /// 0 a tree, 1 a rock.
    var kind: Int
    var time: Double
    /// Rocks: how many chunks have been taken.
    var taken: Int
    /// Trees: how long until the stump has rotted away, in seconds.
    var rot: Double
}

/// One farm plot: fallow (0), tilled (1), sown (2), growing (3), ripe (4) or withered (5), and what is in it.
struct PlotState: Codable {
    var state = 0
    /// 0 wheat, 1 pumpkin, 2 greens.
    var crop = 0
    /// How many plants (4 to 8): more if it was sown well.
    var density = 6
    var changed = 0.0
    /// Seconds of good growing weather it has had, and how quickly this crop goes (0.8 to 1.3).
    var progress = 0.0
    var pace = 1.0

    /// Hours of growing it needs before it is ripe.
    var hoursNeeded: Double { [14, 22, 9][min(2, max(0, crop))] * pace }
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
    /// What the goblins have felled and mined.
    var cuts: [Cut] = []
    /// The state of each farm plot (by its number in the scene).
    var plots: [PlotState] = []
    /// New logs and stones on a strip's path (the strip grows no saplings; these are how wood and stone come back).
    var drift: [Drift] = []
    /// How places are recorded: 2 = as offsets in points from the nest (earlier saves used fractions of the window, which no longer mean anything).
    var layout = 2

    init(seed: UInt64, epoch: Double, seasonOffset: Double, lastRoll: Double) {
        self.seed = seed
        self.epoch = epoch
        self.seasonOffset = seasonOffset
        self.lastRoll = lastRoll
    }

    // (written by hand so that saves from before a field was added still load)
    private enum Keys: String, CodingKey { case seed, epoch, seasonOffset, lastRoll, puddles, plantings, heat, heatTime, cuts, plots, layout, drift }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        seed = try c.decode(UInt64.self, forKey: .seed)
        epoch = try c.decode(Double.self, forKey: .epoch)
        seasonOffset = try c.decode(Double.self, forKey: .seasonOffset)
        lastRoll = try c.decode(Double.self, forKey: .lastRoll)
        puddles = try c.decodeIfPresent([Puddle].self, forKey: .puddles) ?? []
        plantings = try c.decodeIfPresent([Planting].self, forKey: .plantings) ?? []
        heat = try c.decodeIfPresent([Int: Int].self, forKey: .heat) ?? [:]
        heatTime = try c.decodeIfPresent(Double.self, forKey: .heatTime) ?? 0
        cuts = try c.decodeIfPresent([Cut].self, forKey: .cuts) ?? []
        plots = try c.decodeIfPresent([PlotState].self, forKey: .plots) ?? []
        drift = try c.decodeIfPresent([Drift].self, forKey: .drift) ?? []
        layout = try c.decodeIfPresent(Int.self, forKey: .layout) ?? 1
        if layout < 2 { // positions from before the canvas mean nothing now: start those over
            puddles = []
            plantings = []
            cuts = []
            layout = 2
        }
    }
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
        let age = (now - plant.planted) * plant.pace * Settings.shared.pace / 3600 // hours, at its own pace (and the game's)
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
            let rate: Double = [0.016, 0.011, 0.008, 0.002][season.rawValue] * Settings.shared.pace
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
            // the crops: seeds come up, plants grow in good weather (not in winter), pests and frost take some, and what is not picked rots
            for i in state.plots.indices {
                var plot = state.plots[i]
                switch plot.state {
                case 2 where t - plot.changed > 1.5 * 3600:
                    plot.state = rng.chance(0.9) ? 3 : 5 // most seeds come up
                    plot.changed = t
                case 3:
                    let factor: Double = [1.0, 1.2, 0.8, 0][season.rawValue]
                    plot.progress += TerrainLife.step * factor * Settings.shared.pace
                    if plot.progress >= plot.hoursNeeded * 3600 { plot.state = 4; plot.changed = t }
                    else if rng.chance(season == .winter ? 0.012 : 0.0007) { plot.state = 5; plot.changed = t } // frost or pests
                case 4 where t - plot.changed > 30 * 3600:
                    plot.state = 5
                    plot.changed = t
                default: break
                }
                if plot.state != state.plots[i].state { changed = true }
                state.plots[i] = plot
            }
            // a used-up rock: after a while a new stone works its way up out of the ground (frost and rain do that), so the iron never runs out for good
            for i in state.cuts.indices.reversed() where state.cuts[i].kind == 1 && rng.chance(0.0006 * Settings.shared.pace) {
                state.cuts[i].taken -= 1
                if state.cuts[i].taken <= 0 { state.cuts.remove(at: i) }
                changed = true
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
        state.cuts.removeAll { $0.kind == 0 && now - $0.time > $0.rot / Settings.shared.pace }
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

    // MARK: Logs and stones that turn up

    /// Now and then a log falls or a stone comes to light on a strip's path (about one in a quarter of an hour), while there are fewer than `cap`.
    func addDrift(alive: Int, cap: Int, now: Double = TerrainClock.now, spot: (inout TerrainRandom) -> CGPoint?, fraction: (CGPoint) -> CGPoint) {
        var rng = TerrainRandom(seed: state.seed &* 131 &+ UInt64(bitPattern: Int64(now)))
        // (`CAMP_DRIFT_SCALE` makes them come faster: tests)
        guard alive < cap, rng.chance(0.035 * Settings.shared.pace * (Double(ProcessInfo.processInfo.environment["CAMP_DRIFT_SCALE"] ?? "") ?? 1)) else { return }
        guard let p = spot(&rng) else { return }
        let f = fraction(p)
        state.drift.append(Drift(fx: Double(f.x), fy: Double(f.y), kind: rng.chance(0.75) ? 0 : 1, born: now))
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

    // MARK: What the goblins take

    /// A goblin felled a tree or took a piece of a rock at this spot (a fraction of the clearing). Returns the cut.
    @discardableResult
    func cut(kind: Int, at f: CGPoint, now: Double = TerrainClock.now) -> Cut {
        if kind == 1, let i = state.cuts.firstIndex(where: { $0.kind == 1 && abs($0.fx - Double(f.x)) < 3 && abs($0.fy - Double(f.y)) < 3 }) {
            state.cuts[i].taken += 1
            version += 1
            onChange?()
            return state.cuts[i]
        }
        var rng = TerrainRandom(seed: UInt64(bitPattern: Int64(now * 100)) &+ state.seed)
        let cut = Cut(fx: Double(f.x), fy: Double(f.y), kind: kind, time: now, taken: kind == 1 ? 1 : 0, rot: rng.range(1.5, 5) * 86_400)
        state.cuts.append(cut)
        version += 1
        onChange?()
        return cut
    }

    /// A planted tree that was felled falls like the ones that die: it lies there for a while and rots.
    func fellPlanting(nearFraction f: CGPoint, now: Double = TerrainClock.now) {
        guard let i = state.plantings.firstIndex(where: { $0.fell == nil && abs($0.fx - Double(f.x)) < 3 && abs($0.fy - Double(f.y)) < 3 }) else { return }
        state.plantings[i].fell = now
        version += 1
        onChange?()
    }

    // MARK: The farm

    /// Makes sure there is a state for each of `count` plots.
    func ensurePlots(_ count: Int) {
        while state.plots.count < count { state.plots.append(PlotState()) }
    }

    func setPlot(_ index: Int, _ change: (inout PlotState) -> Void) {
        guard state.plots.indices.contains(index) else { return }
        change(&state.plots[index])
        version += 1
        onChange?()
    }

    // MARK: Puddles

    func puddlePoints(origin: CGPoint, now: Double = TerrainClock.now) -> [(center: CGPoint, radius: CGFloat, wetness: Double)] {
        state.puddles.compactMap { p in
            let age = now - p.born
            guard age >= 0, age < p.life else { return nil }
            // it grows while it is filling and shrinks as it dries
            let fill = min(1, age / 600), dry = max(0, 1 - max(0, age - p.life * 0.55) / (p.life * 0.45))
            let wetness = min(fill, dry)
            return (CGPoint(x: origin.x + CGFloat(p.fx), y: origin.y + CGFloat(p.fy)), CGFloat(p.radius * (0.4 + 0.6 * wetness)), wetness)
        }
    }
}
