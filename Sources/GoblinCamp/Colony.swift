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

    static let maxFoods = 6
    /// At most this many ants work on one food at a time.
    static let maxForagers = 10

    /// Ant counts at which the queen celebrates.
    private static let milestones: Set<Int> = [10, 50, 100, 200, 300, 400, 500]

    private let settings = Settings.shared

    /// Which breeds exist. Normally the current character's; tests can put their own here.
    var breedOverride: [Breed]?
    private var breeds: [Breed] { breedOverride ?? Characters.current.breeds }

    private(set) var phase: Phase = .choosingNest
    /// Set while picking a new spot for an existing colony, so Esc can put things back as they were.
    private var phaseBeforePicking: Phase?
    private(set) var nest: CGPoint?
    private(set) var queen: Queen?
    private(set) var ants: [Ant] = []
    private(set) var eggs: [Egg] = []
    private(set) var foods: [FoodSource] = []
    private(set) var pendingFood: FoodKind?
    /// Pieces of food the ants have carried into the nest so far.
    private(set) var foodDelivered = 0
    /// How many have died of old age.
    private(set) var deaths = 0
    /// How many goblins wild animals have killed.
    private(set) var slain = 0
    /// Popups for Claude notifications (not part of the simulation, so they work while paused).
    let stage = MessageStage()
    /// The pomodoro goblin with the clock.
    let pomodoro = Pomodoro()
    /// The camp is not drawn (work, energy-saving or focus mode); only the pomodoro and the popups still are.
    var campHidden = false
    private(set) var creatures: [Creature] = []
    /// Little sparks where something was just hit.
    private(set) var hits: [(pos: CGPoint, age: Double)] = []
    private var nextCreatureID = 1
    private var animalTimer: Double = -1
    private var treeTimer: Double = -1
    /// Which of the princess's outfits she wears now. `CAMP_OUTFIT` picks the first one (for testing).
    private(set) var outfitIndex: Int = Int(ProcessInfo.processInfo.environment["CAMP_OUTFIT"] ?? "") ?? 0
    /// The individual highlighted from the roster, if any.
    var selectedAntID: Int?
    private var nextFoodID = 1
    private var nextAntID = 1
    /// The two goblins carrying the princess in at the start, and how many have arrived.
    private var carrierIDs: [Int] = []
    private var carriersArrived = 0
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
        if foods.filter({ $0.origin == .placed }).count > Colony.maxFoods, let oldest = foods.firstIndex(where: { $0.origin == .placed }) {
            foods.remove(at: oldest)
        }
        pendingFood = nil
        phase = .running
        onChange?()
    }

    /// Puts away the food the player put down and any meat; fruit trees stay.
    func clearFoods() {
        foods.removeAll { $0.origin != .tree }
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
            recruit(for: id, count: 4 + foods[i].amount / 6 + ants[index].traits.recruit)
        case .tookPiece(let id):
            guard let i = foods.firstIndex(where: { $0.id == id && $0.amount > 0 }) else {
                ants[index].mode = .wandering // somebody else took the last piece
                return
            }
            // a strong one carries more than one piece (never more than is left)
            let pieces = min(ants[index].traits.carry, foods[i].amount)
            ants[index].mode = .hauling(food: id, kind: foods[i].kind, pieces: pieces)
            foods[i].amount -= pieces
            if foods[i].amount == 0 {
                if foods[i].isTree {
                    foods[i].scouted = false // nobody knows about it until it has fruit again
                    foods[i].reported = false
                    foods[i].regrow = Colony.treeRegrowTime
                } else {
                    foods.remove(at: i)
                }
            }
        case .delivered(let id, let pieces):
            foodDelivered += pieces
            // every successful trip can bring one or two more helpers
            if Double.random(in: 0..<1) < 0.5 { recruit(for: id, count: Int.random(in: 1...2)) }
        case .foundCreature(let id):
            if let i = creatures.firstIndex(where: { $0.id == id }) { creatures[i].scouted = true }
        case .huntNewsDelivered(let id):
            guard let i = creatures.firstIndex(where: { $0.id == id }) else { return }
            creatures[i].reported = true
            recruitHunters(for: id, count: 5 + Int(creatures[i].hp / 3) + ants[index].traits.recruit)
        case .attack(let id):
            attack(creature: id, by: index)
        case .carrierArrived:
            carriersArrived += 1
        case .died:
            break // removed by the caller once all events are handled
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
        clearDecorations()
        ants = []
        spawnTimer = 0
        beginCarrying(to: point)
        primeWildlifeTimers()
        onChange?()
    }

    /// Where the screen edge nearest to `point` is, a little outside the screen.
    private func nearestEdgePoint(to point: CGPoint) -> CGPoint {
        let rect = walkable.first { $0.contains(point) } ?? walkable.first ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
        let sides: [(distance: CGFloat, spot: CGPoint)] = [
            (point.x - rect.minX, CGPoint(x: rect.minX - 30, y: point.y)),
            (rect.maxX - point.x, CGPoint(x: rect.maxX + 30, y: point.y)),
            (point.y - rect.minY, CGPoint(x: point.x, y: rect.minY - 30)),
            (rect.maxY - point.y, CGPoint(x: point.x, y: rect.maxY + 30)),
        ]
        return sides.min { $0.distance < $1.distance }!.spot
    }

    /// The opening: two goblins come in from the nearest screen edge carrying the princess (a captive, over their
    /// heads) to the camp. They become the camp's first two inhabitants once they set her down.
    private func beginCarrying(to nest: CGPoint) {
        let home = Queen.homeSpot(for: nest)
        let start = nearestEdgePoint(to: nest)
        let dx = home.x - start.x, dy = home.y - start.y, length = max(1, hypot(dx, dy))
        let direction = CGPoint(x: dx / length, y: dy / length)
        queen = Queen(carriedTo: nest)
        carrierIDs = []
        carriersArrived = 0
        for offset in [CGFloat(9), CGFloat(-9)] { // one in front, one behind, along the way they walk
            var ant = makeAnt(at: CGPoint(x: start.x + direction.x * offset, y: start.y + direction.y * offset), breedIndex: 0)
            ant.mode = .carryingPrincess(target: CGPoint(x: home.x + direction.x * offset, y: home.y + direction.y * offset))
            ants.append(ant)
            carrierIDs.append(ant.id)
        }
    }

    // MARK: Wildlife

    static let treeRegrowTime = 70.0
    static let maxHunters = 8

    /// Seconds between new animals / new trees, and how many may be about, for each level of the "nature" setting.
    private static let animalEvery: [Double] = [0, 480, 240, 120]
    private static let treeEvery: [Double] = [0, 600, 300, 150]
    private static let maxAnimals = [0, 1, 2, 3]
    private static let maxTrees = [0, 2, 3, 4]

    /// `CAMP_WILD_SCALE` makes nature happen faster (for testing).
    private static let wildScale: Double = {
        if let s = ProcessInfo.processInfo.environment["CAMP_WILD_SCALE"], let v = Double(s), v > 0 { return v }
        return 1
    }()

    /// Animals come and go, trees grow fruit back, and new animals and trees turn up on their own.
    private func updateWildlife(dt: Double) {
        let level = settings.wildlife
        for i in hits.indices { hits[i].age += dt }
        hits.removeAll { $0.age > 0.35 }

        // animals
        for i in creatures.indices.reversed() where creatures[i].update(dt: dt, walkable: walkable) {
            creatures.remove(at: i) // walked off the screen
        }
        // trees grow fruit
        for i in foods.indices where foods[i].isTree && foods[i].amount < foods[i].capacity {
            foods[i].regrow -= dt * Colony.wildScale
            if foods[i].regrow <= 0 {
                foods[i].amount += 1
                foods[i].regrow = Colony.treeRegrowTime
                foods[i].scouted = false
                foods[i].reported = false
            }
        }

        guard level > 0, ants.count >= 6, queen?.isCarried == false else { return }
        animalTimer -= dt * Colony.wildScale
        treeTimer -= dt * Colony.wildScale
        if animalTimer < 0 {
            if animalTimer < -1_000_000 || creatures.count < Colony.maxAnimals[level] { spawnAnimal() }
            animalTimer = Colony.animalEvery[level] * Double.random(in: 0.6...1.4)
        }
        if treeTimer < 0 {
            if foods.filter(\.isTree).count < Colony.maxTrees[level] { spawnTree() }
            treeTimer = Colony.treeEvery[level] * Double.random(in: 0.6...1.4)
        }
    }

    /// A first-time countdown: an animal and a tree turn up fairly soon after the colony gets going.
    private func primeWildlifeTimers() {
        let level = settings.wildlife
        guard level > 0 else { return }
        if animalTimer == -1 { animalTimer = Colony.animalEvery[level] * Double.random(in: 0.25...0.5) }
        if treeTimer == -1 { treeTimer = Colony.treeEvery[level] * Double.random(in: 0.1...0.3) }
    }

    func spawnAnimal(of kind: AnimalKind? = nil) {
        guard let nest, let kind = kind ?? Animals.pick() else { return }
        let rect = walkable.randomElement() ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
        // it walks in from a random edge toward somewhere inside
        let start: CGPoint, inward: CGPoint
        switch Int.random(in: 0..<4) {
        case 0: start = CGPoint(x: rect.minX - 30, y: CGFloat.random(in: rect.minY + 80...rect.maxY - 80)); inward = CGPoint(x: 1, y: 0)
        case 1: start = CGPoint(x: rect.maxX + 30, y: CGFloat.random(in: rect.minY + 80...rect.maxY - 80)); inward = CGPoint(x: -1, y: 0)
        case 2: start = CGPoint(x: CGFloat.random(in: rect.minX + 80...rect.maxX - 80), y: rect.minY - 30); inward = CGPoint(x: 0, y: 1)
        default: start = CGPoint(x: CGFloat.random(in: rect.minX + 80...rect.maxX - 80), y: rect.maxY + 30); inward = CGPoint(x: 0, y: -1)
        }
        let depth = CGFloat.random(in: 140...320)
        var target = CGPoint(x: start.x + inward.x * depth, y: start.y + inward.y * depth)
        if hypot(target.x - nest.x, target.y - nest.y) < 60 { target.x += 120 }
        if ProcessInfo.processInfo.environment["CAMP_DEBUG"] != nil { NSLog("GoblinCamp: a \(kind.id) walks in from \(start)") }
        creatures.append(Creature(id: nextCreatureID, kind: kind, start: start, enter: target, stay: Double.random(in: 120...240)))
        nextCreatureID += 1
    }

    func spawnTree(at point: CGPoint? = nil) {
        guard let nest else { return }
        for _ in 0..<30 {
            let angle = Double.random(in: 0..<(2 * .pi)), radius = Double.random(in: 90...260)
            let spot = point ?? CGPoint(x: nest.x + cos(angle) * radius, y: nest.y + sin(angle) * radius)
            let clear = foods.allSatisfy { hypot($0.pos.x - spot.x, $0.pos.y - spot.y) > 60 }
            if walkable.contains(where: { $0.insetBy(dx: 40, dy: 40).contains(spot) }), hypot(spot.x - nest.x, spot.y - nest.y) > 50, clear {
                var tree = FoodSource(id: nextFoodID, kind: .fruit, pos: spot, amount: 4)
                tree.origin = .tree
                tree.regrow = Colony.treeRegrowTime
                foods.append(tree)
                nextFoodID += 1
                if ProcessInfo.processInfo.environment["CAMP_DEBUG"] != nil { NSLog("GoblinCamp: a fruit tree grows at \(spot)") }
                return
            }
            if point != nil { return }
        }
    }

    private func hunters(of id: Int) -> Int {
        ants.reduce(0) {
            switch $1.mode {
            case .hunting(let target, _), .inNestForHunt(_, let target), .huntNews(let target): return $0 + (target == id ? 1 : 0)
            default: return $0
            }
        }
    }

    /// The news of an animal reached the nest: hunters set out (those resting in the nest one by one).
    private func recruitHunters(for id: Int, count: Int) {
        guard let nest, let creature = creatures.first(where: { $0.id == id }) else { return }
        let want = min(count, Colony.maxHunters - hunters(of: id))
        guard want > 0 else { return }
        var inside: [Int] = [], nearby: [(index: Int, distance: Double)] = []
        for (i, ant) in ants.enumerated() where !ant.isWounded {
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
            ants[i].mode = .inNestForHunt(remaining: Double(chosen) * 0.6 + 0.2, creature: id)
            chosen += 1
        }
        for entry in nearby.sorted(by: { $0.distance < $1.distance }).prefix(want - chosen) {
            ants[entry.index].mode = .hunting(creature: id, cooldown: 0)
        }
        _ = creature
    }

    /// A goblin hits an animal. A fighting one hits back now and then; a timid one runs.
    private func attack(creature id: Int, by index: Int) {
        guard let ci = creatures.firstIndex(where: { $0.id == id }) else { return }
        creatures[ci].hp -= ants[index].traits.might
        creatures[ci].hurt = 0.35
        hits.append((pos: creatures[ci].pos, age: 0))
        if creatures[ci].hp <= 0 {
            kill(creatureAt: ci)
        } else if creatures[ci].kind.aggressive {
            if Double.random(in: 0..<1) < 0.4 { hurt(ant: index) }
        } else {
            let away = atan2(creatures[ci].pos.y - ants[index].pos.y, creatures[ci].pos.x - ants[index].pos.x)
            creatures[ci].state = .fleeing(remaining: 2.5, angle: away)
        }
    }

    /// The animal bites: the goblin loses health, limps home when it is nearly done for, and may be killed.
    private func hurt(ant index: Int) {
        ants[index].health -= 1
        hits.append((pos: ants[index].pos, age: 0))
        if ants[index].health <= 0 {
            ants[index].mode = .dying(remaining: Ant.dyingTime)
            slain += 1
        } else if ants[index].isWounded {
            ants[index].mode = .returningToNest
        }
    }

    /// The animal is down: it leaves a pile of meat, and the hunters start carrying it home.
    private func kill(creatureAt index: Int) {
        let animal = creatures.remove(at: index)
        var meat = FoodSource(id: nextFoodID, kind: .meat, pos: animal.pos, amount: animal.kind.meat)
        meat.origin = .meat
        meat.capacityOverride = animal.kind.meat
        meat.scouted = true
        meat.reported = true
        foods.append(meat)
        let meatID = nextFoodID
        nextFoodID += 1
        for i in ants.indices {
            switch ants[i].mode {
            case .hunting(let target, _), .inNestForHunt(_, let target), .huntNews(let target):
                if target == animal.id { ants[i].mode = .foraging(food: meatID, slot: Double.random(in: 0..<(2 * .pi))) }
            default: break
            }
        }
    }

    /// Test aids.
    func debugSpawnCreature(kind: AnimalKind, at point: CGPoint) {
        var c = Creature(id: nextCreatureID, kind: kind, start: point, enter: point, stay: 600)
        c.state = .wandering
        creatures.append(c)
        nextCreatureID += 1
    }

    /// Keeps the princess between her carriers, and sets her down once both have arrived.
    private func moveCarriedPrincess() {
        guard queen?.isCarried == true else { return }
        let carriers = ants.filter { carrierIDs.contains($0.id) }
        if carriers.count < 2 || carriersArrived >= 2 {
            queen?.setDown()
            for i in ants.indices where carrierIDs.contains(ants[i].id) { ants[i].mode = .wandering }
            carrierIDs = []
            return
        }
        let mid = CGPoint(x: carriers.map(\.pos.x).reduce(0, +) / 2, y: carriers.map(\.pos.y).reduce(0, +) / 2)
        queen?.carry(at: mid, heading: carriers[0].heading)
    }

    /// Resume a saved colony: queen already home, ants scattered around the nest.
    func restore(nest: CGPoint, saved: SavedState) {
        self.nest = nest
        phase = .running
        queen = Queen.settled(nest: nest)
        foodDelivered = saved.delivered ?? 0

        func scattered() -> CGPoint {
            let angle = Double.random(in: 0..<(2 * .pi))
            let radius = Double.random(in: 0...1).squareRoot() * 200
            let p = CGPoint(x: nest.x + cos(angle) * radius, y: nest.y + sin(angle) * radius)
            return walkable.contains(where: { $0.contains(p) }) ? p : nest
        }
        if let goblins = saved.goblins {
            ants = goblins.prefix(settings.maxAnts).map { g in
                makeAnt(at: scattered(), breedIndex: breeds.firstIndex { $0.id == g.breed } ?? 0, age: g.age, seed: g.seed, id: g.id)
            }
            nextAntID = max(saved.nextID ?? 1, (goblins.map(\.id).max() ?? 0) + 1)
        } else {
            // an older save that only knew how many there were: they are all plain, and young
            ants = (0..<min(saved.antCount, settings.maxAnts)).map { _ in
                makeAnt(at: scattered(), breedIndex: 0, age: Double.random(in: 0...(Traits.baseLifespan * 0.3)))
            }
        }
        spawnTimer = 0
        primeWildlifeTimers()
    }

    /// What to write to disk: where the nest is and who lives there.
    func savedState() -> SavedState? {
        guard let nest else { return nil }
        let breeds = self.breeds
        return SavedState(nestX: nest.x, nestY: nest.y, antCount: ants.count,
                          goblins: ants.map { SavedGoblin(id: $0.id, breed: breeds[min($0.breedIndex, breeds.count - 1)].id, age: $0.age, seed: $0.seed) },
                          delivered: foodDelivered, nextID: nextAntID)
    }

    /// Births and restores both go through here so every individual gets its traits the same way.
    private func makeAnt(at pos: CGPoint, breedIndex: Int? = nil, age: Double = 0, seed: UInt64? = nil, id: Int? = nil) -> Ant {
        let breeds = self.breeds
        let index = min(breedIndex ?? Breeding.roll(from: breeds, delivered: foodDelivered), breeds.count - 1)
        let seed = seed ?? UInt64.random(in: 0...UInt64(UInt32.max))
        let traits = Traits.make(for: breeds[index], seed: seed)
        let ant = Ant(at: pos, id: id ?? nextAntID, breedIndex: index, traits: traits, seed: seed, age: age)
        if id == nil { nextAntID += 1 }
        return ant
    }

    /// `CAMP_TIME_SCALE` makes life go faster (for testing ageing without waiting a day).
    static let timeScale: Double = {
        if let s = ProcessInfo.processInfo.environment["CAMP_TIME_SCALE"], let v = Double(s), v > 0 { return v }
        return 1
    }()

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
        let outfits = Characters.current.outfits
        let around = Surroundings(cursor: cursor, cursorSpeed: cursorSpeed, newestAnt: ants.last?.pos,
                                  outfit: outfits.isEmpty ? "" : outfits[min(outfitIndex, outfits.count - 1)].id)
        if let event = queen?.update(dt: dt, walkable: walkable, around: around) {
            switch event {
            case .outfitChange(let wanted):
                let outfits = Characters.current.outfits
                if let wanted, let index = outfits.firstIndex(where: { $0.id == wanted }) {
                    outfitIndex = index
                } else if outfits.count > 1 {
                    outfitIndex = (outfitIndex + Int.random(in: 1..<outfits.count)) % outfits.count // always a different one
                }
            case .layEgg:
                // she plants a flower next to her feet
                if let queen { eggs.append(Egg(pos: CGPoint(x: queen.pos.x + [-14, 14].randomElement()!, y: queen.pos.y - 7))) }
            }
        }
        for i in eggs.indices { eggs[i].age += dt }
        eggs.removeAll { $0.age >= Egg.lifetime }

        // The clock only starts once the queen has crawled out.
        if queen?.arrived == true, ants.count < settings.maxAnts {
            spawnTimer += dt
            if spawnTimer >= settings.spawnInterval {
                spawnTimer = 0
                let jitter = { CGFloat.random(in: -4...4) }
                ants.append(makeAnt(at: CGPoint(x: nest.x + jitter(), y: nest.y + jitter())))
                if ProcessInfo.processInfo.environment["CAMP_DEBUG"] != nil { NSLog("GoblinCamp: ants=\(ants.count)") }
                queen?.greet(toward: nest)
                if Colony.milestones.contains(ants.count) { queen?.celebrate() }
                onAntsChanged?()
            }
        }
        let antDt = dt * settings.speedMultiplier
        let world = AntWorld(nest: nest, walkable: walkable, foods: foods, creatures: creatures.map(\.info), foodScale: Colony.foodScale(settings.antScale))
        let ageDt = dt * Colony.timeScale
        var events: [(index: Int, event: Ant.Event)] = []
        for i in ants.indices {
            if let event = ants[i].update(dt: antDt, ageDt: ageDt, world: world) { events.append((i, event)) }
        }
        for (index, event) in events { handle(event, from: index) }
        moveCarriedPrincess()
        updateWildlife(dt: dt)
        // the dead leave the colony (highest index first so the others keep their places)
        let gone = events.filter { if case .died = $0.event { return true } else { return false } }.map(\.index)
        for index in gone.sorted(by: >) {
            if ants[index].id == selectedAntID { selectedAntID = nil }
            ants.remove(at: index)
        }
        deaths += gone.count
        if !gone.isEmpty { onAntsChanged?() }
    }
}
