import CoreGraphics
import Foundation

/// Game state. Coordinates are global screen coordinates (AppKit, origin bottom-left of the primary screen).
final class Colony {
    enum Phase {
        case choosingNest
        case running
    }

    /// A cosmetic egg the queen lays beside the nest; fades away after a few seconds.
    struct Egg {
        static let lifetime = 8.0
        let pos: CGPoint
        var age: Double = 0
        /// 1 while fresh, fading to 0 over the last two seconds.
        var alpha: Double { min(1, (Egg.lifetime - age) / 2) }
    }

    /// A speck of soil the queen digs up beside the nest; fades away, or all at once when she patches the nest.
    struct Dirt {
        static let lifetime = 40.0
        let pos: CGPoint
        var age: Double = 0
        var alpha: Double { min(1, (Dirt.lifetime - age) / 1.5) }
    }

    /// A small stone she carried over and dropped.
    struct Pebble {
        static let lifetime = 90.0
        let pos: CGPoint
        var age: Double = 0
        var alpha: Double { min(1, (Pebble.lifetime - age) / 2) }
    }

    /// Ant counts at which the queen celebrates.
    private static let milestones: Set<Int> = [10, 50, 100, 200, 300, 400, 500]

    private let settings = Settings.shared

    private(set) var phase: Phase = .choosingNest
    private(set) var nest: CGPoint?
    private(set) var queen: Queen?
    private(set) var ants: [Ant] = []
    private(set) var eggs: [Egg] = []
    private(set) var dirt: [Dirt] = []
    private(set) var pebbles: [Pebble] = []
    /// 1 right after the nest is patched, easing back to 0; the nest is drawn a little bigger meanwhile.
    private(set) var nestPulse: Double = 0
    var isPaused = false

    /// Screen frames ants may walk on. Change it through `updateWalkable`.
    private(set) var walkable: [CGRect] = []

    /// Called on phase changes so the app can switch input mode and redraw.
    var onChange: (() -> Void)?
    /// Called when the number of ants changes.
    var onAntsChanged: (() -> Void)?

    private var spawnTimer: Double = 0

    func placeNest(at point: CGPoint) {
        guard phase == .choosingNest else { return }
        nest = point
        phase = .running
        queen = Queen(emergingFrom: point) // crawls out of the hole
        clearDecorations()
        ants = []
        spawnTimer = 0
        onChange?()
    }

    /// Resume a saved colony: queen already home, ants scattered around the nest.
    func restore(nest: CGPoint, antCount: Int) {
        self.nest = nest
        phase = .running
        queen = Queen.settled(nest: nest)
        ants = (0..<min(antCount, settings.maxAnts)).map { _ in
            let angle = Double.random(in: 0..<(2 * .pi))
            let radius = Double.random(in: 0...1).squareRoot() * 200
            let p = CGPoint(x: nest.x + cos(angle) * radius, y: nest.y + sin(angle) * radius)
            return Ant(at: walkable.contains(where: { $0.contains(p) }) ? p : nest)
        }
        spawnTimer = 0
    }

    /// Screens were added or removed: anything left outside the new screens is moved to the nearest one,
    /// so the nest and its ants survive unplugging a monitor.
    func updateWalkable(_ rects: [CGRect]) {
        walkable = rects
        guard phase == .running, !rects.isEmpty else { return }
        if let nest, !isWalkable(nest) {
            let moved = nearestWalkable(to: nest)
            self.nest = moved
            queen = Queen.settled(nest: moved)
        }
        for i in ants.indices where !isWalkable(ants[i].pos) {
            ants[i].pos = nearestWalkable(to: ants[i].pos)
        }
        onAntsChanged?() // saves the (possibly moved) nest
    }

    private func isWalkable(_ p: CGPoint) -> Bool {
        walkable.contains { $0.contains(p) }
    }

    /// The closest point inside any screen (kept 12pt away from the edge).
    private func nearestWalkable(to p: CGPoint) -> CGPoint {
        func distance(_ r: CGRect) -> CGFloat {
            hypot(max(r.minX - p.x, 0, p.x - r.maxX), max(r.minY - p.y, 0, p.y - r.maxY))
        }
        guard let screen = walkable.min(by: { distance($0) < distance($1) }) else { return p }
        let r = screen.insetBy(dx: 12, dy: 12)
        return CGPoint(x: min(max(p.x, r.minX), r.maxX), y: min(max(p.y, r.minY), r.maxY))
    }

    func reset() {
        nest = nil
        queen = nil
        ants = []
        clearDecorations()
        phase = .choosingNest
        onChange?()
    }

    private func clearDecorations() {
        eggs = []
        dirt = []
        pebbles = []
        nestPulse = 0
    }

    func debugForceQueen(_ name: String) {
        queen?.debugForce(name)
    }

    /// Somebody clicked the nest.
    func pokeNest() {
        queen?.poke()
    }

    func tick(dt: Double, cursor: CGPoint = CGPoint(x: -10_000, y: -10_000), cursorSpeed: Double = 0) {
        guard phase == .running, !isPaused, let nest else { return }
        let around = Surroundings(cursor: cursor, cursorSpeed: cursorSpeed, newestAnt: ants.last?.pos)
        if let event = queen?.update(dt: dt, walkable: walkable, around: around) {
            switch event {
            case .layEgg(let at):
                eggs.append(Egg(pos: at))
            case .dropDirt(let at):
                dirt.append(Dirt(pos: at))
                if dirt.count > 10 { dirt.removeFirst() }
            case .dropPebble(let at):
                pebbles.append(Pebble(pos: at))
                if pebbles.count > 6 { pebbles.removeFirst() }
            case .patched:
                // press the soil flat: everything fades out quickly
                for i in dirt.indices { dirt[i].age = max(dirt[i].age, Dirt.lifetime - 1.5) }
                nestPulse = 1
            }
        }
        for i in eggs.indices { eggs[i].age += dt }
        for i in dirt.indices { dirt[i].age += dt }
        for i in pebbles.indices { pebbles[i].age += dt }
        eggs.removeAll { $0.age >= Egg.lifetime }
        dirt.removeAll { $0.age >= Dirt.lifetime }
        pebbles.removeAll { $0.age >= Pebble.lifetime }
        nestPulse = max(0, nestPulse - dt / 1.2)

        // The clock only starts once the queen has crawled out.
        if queen?.arrived == true, ants.count < settings.maxAnts {
            spawnTimer += dt
            if spawnTimer >= settings.spawnInterval {
                spawnTimer = 0
                let jitter = { CGFloat.random(in: -4...4) }
                ants.append(Ant(at: CGPoint(x: nest.x + jitter(), y: nest.y + jitter())))
                if ProcessInfo.processInfo.environment["ANT_DEBUG"] != nil { NSLog("AntFarm: ants=\(ants.count)") }
                queen?.greet(toward: nest)
                if Colony.milestones.contains(ants.count) { queen?.celebrate() }
                onAntsChanged?()
            }
        }
        let antDt = dt * settings.speedMultiplier
        for i in ants.indices { ants[i].update(dt: antDt, walkable: walkable) }
    }
}
