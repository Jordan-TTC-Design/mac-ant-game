import CoreGraphics
import Foundation

/// Game state. Coordinates are global screen coordinates (AppKit, origin bottom-left of the primary screen).
final class Colony {
    enum Phase {
        /// No nest yet and not picking one (the player pressed Esc); waiting for "choose a nest" in the menu.
        case idle
        case choosingNest
        case running
        /// Running, but the overlay captures the mouse so the nest can be dragged somewhere else.
        case editing
        /// Running, but the overlay captures the mouse: the next click puts down `pendingFood`.
        case placingFood
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

    static let maxFoods = 6
    /// At most this many ants work on one food at a time.
    static let maxForagers = 10

    /// Ant counts at which the queen celebrates.
    private static let milestones: Set<Int> = [10, 50, 100, 200, 300, 400, 500]

    private let settings = Settings.shared

    private(set) var phase: Phase = .choosingNest
    /// Set while picking a new spot for an existing colony, so Esc can put things back as they were.
    private var phaseBeforePicking: Phase?
    private(set) var nest: CGPoint?
    private(set) var queen: Queen?
    private(set) var ants: [Ant] = []
    private(set) var eggs: [Egg] = []
    private(set) var dirt: [Dirt] = []
    private(set) var pebbles: [Pebble] = []
    private(set) var foods: [FoodSource] = []
    private(set) var pendingFood: FoodKind?
    /// Pieces of food the ants have carried into the nest so far.
    private(set) var foodDelivered = 0
    private var nextFoodID = 1
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

    /// True while ants and the queen are moving (also during editing, so the colony stays alive).
    var isSimulating: Bool { phase == .running || phase == .editing || phase == .placingFood }

    /// Ask the player for a nest spot. An existing colony is left untouched until a spot is actually chosen.
    func beginPicking() {
        guard phase != .choosingNest else { return }
        phaseBeforePicking = nest != nil ? .running : nil
        pendingFood = nil
        phase = .choosingNest
        onChange?()
    }

    /// Esc while picking: go back to the previous colony, or to "no nest yet".
    func cancelPicking() {
        guard phase == .choosingNest else { return }
        phase = phaseBeforePicking ?? .idle
        phaseBeforePicking = nil
        onChange?()
    }

    func beginEditing() {
        guard phase == .running, nest != nil else { return }
        phase = .editing
        onChange?()
    }

    func endEditing() {
        guard phase == .editing else { return }
        phase = .running
        onChange?()
    }

    /// Dragging the nest: the queen moves in with it, ants stay where they are.
    func moveNest(to point: CGPoint) {
        guard phase == .editing else { return }
        let spot = isWalkable(point) ? point : nearestWalkable(to: point)
        nest = spot
        queen = Queen.settled(nest: spot)
    }

    /// The drag finished: let the app save the new spot.
    func nestDragEnded() {
        onAntsChanged?()
    }

    // MARK: Food

    func beginPlacingFood(_ kind: FoodKind) {
        guard phase == .running else { return }
        pendingFood = kind
        phase = .placingFood
        onChange?()
    }

    func cancelPlacingFood() {
        guard phase == .placingFood else { return }
        pendingFood = nil
        phase = .running
        onChange?()
    }

    func placeFood(at point: CGPoint) {
        guard phase == .placingFood, let kind = pendingFood else { return }
        let spot = isWalkable(point) ? point : nearestWalkable(to: point)
        foods.append(FoodSource(id: nextFoodID, kind: kind, pos: spot, amount: kind.initialAmount))
        nextFoodID += 1
        if foods.count > Colony.maxFoods { foods.removeFirst() }
        pendingFood = nil
        phase = .running
        onChange?()
    }

    func clearFoods() {
        foods = []
        onChange?()
    }

    /// How many ants are at work on this food (on the way, at it, hauling, or about to come out of the nest for it).
    private func foragers(of id: Int) -> Int {
        ants.reduce(0) { $0 + ($1.targetFood == id ? 1 : 0) }
    }

    /// The news reached the nest: nestmates set out for the food. Ants resting in the nest come out one after
    /// another; wanderers close to the nest turn straight toward it.
    private func recruit(for id: Int, count: Int) {
        guard let nest, let food = foods.first(where: { $0.id == id && $0.amount > 0 }) else { return }
        let want = min(count, Colony.maxForagers - foragers(of: id))
        guard want > 0 else { return }

        var inside: [Int] = [], nearby: [(index: Int, distance: Double)] = []
        for (i, ant) in ants.enumerated() {
            switch ant.mode {
            case .inNest(_, nil): inside.append(i)
            case .wandering:
                let d = hypot(ant.pos.x - nest.x, ant.pos.y - nest.y)
                if d < 110 { nearby.append((i, d)) }
            default: break
            }
        }
        var chosen = 0
        for i in inside.shuffled().prefix(want) {
            // staggered, so they stream out of the hole one by one
            ants[i].mode = .inNest(remaining: Double(chosen) * 0.7 + 0.2, thenForage: id)
            chosen += 1
        }
        for entry in nearby.sorted(by: { $0.distance < $1.distance }).prefix(want - chosen) {
            ants[entry.index].mode = .foraging(food: id, slot: Double.random(in: 0..<(2 * .pi)))
            ants[entry.index].heading = atan2(food.pos.y - ants[entry.index].pos.y, food.pos.x - ants[entry.index].pos.x)
        }
    }

    private func handle(_ event: Ant.Event, from index: Int) {
        switch event {
        case .foundFood(let id):
            if let i = foods.firstIndex(where: { $0.id == id }) { foods[i].scouted = true }
        case .newsDelivered(let id):
            guard let i = foods.firstIndex(where: { $0.id == id && $0.amount > 0 }) else { return }
            foods[i].reported = true
            recruit(for: id, count: 4 + foods[i].amount / 6)
        case .tookPiece(let id):
            guard let i = foods.firstIndex(where: { $0.id == id && $0.amount > 0 }) else {
                ants[index].mode = .wandering // somebody else took the last piece
                return
            }
            foods[i].amount -= 1
            if foods[i].amount == 0 { foods.remove(at: i) }
        case .delivered(let id):
            foodDelivered += 1
            // every successful trip can bring one or two more helpers
            if Double.random(in: 0..<1) < 0.5 { recruit(for: id, count: Int.random(in: 1...2)) }
        }
    }

    func placeNest(at point: CGPoint) {
        guard phase == .choosingNest else { return }
        phaseBeforePicking = nil
        for i in foods.indices { // nobody knows about the food any more
            foods[i].scouted = false
            foods[i].reported = false
        }
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
        guard nest != nil, !rects.isEmpty else { return }
        if let nest, !isWalkable(nest) {
            let moved = nearestWalkable(to: nest)
            self.nest = moved
            queen = Queen.settled(nest: moved)
        }
        for i in ants.indices where !isWalkable(ants[i].pos) {
            ants[i].pos = nearestWalkable(to: ants[i].pos)
        }
        for i in foods.indices where !isWalkable(foods[i].pos) {
            foods[i].pos = nearestWalkable(to: foods[i].pos)
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

    /// Food size follows the ant-size setting a little, so big ants do not swamp small food.
    static func foodScale(_ antScale: Double) -> Double { 0.6 + 0.4 * antScale }

    /// Test aid: a one-line summary of the foraging state.
    func foodSummary() -> String {
        let hidden = ants.filter(\.isHidden).count
        let amounts = foods.map { "\($0.kind.rawValue):\($0.amount)\($0.reported ? "*" : "")" }.joined(separator: ",")
        let working = foods.map { foragers(of: $0.id) }
        return "ants=\(ants.count) inNest=\(hidden) foods=[\(amounts)] foragers=\(working) delivered=\(foodDelivered)"
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
        guard isSimulating, !isPaused, let nest else { return }
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
        let world = AntWorld(nest: nest, walkable: walkable, foods: foods, foodScale: Colony.foodScale(settings.antScale))
        var events: [(index: Int, event: Ant.Event)] = []
        for i in ants.indices {
            if let event = ants[i].update(dt: antDt, world: world) { events.append((i, event)) }
        }
        for (index, event) in events { handle(event, from: index) }
    }
}
