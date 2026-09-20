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
    /// What the princess is called ("" until the player names her).
    var princessName = ""
    /// A new camp was just started and the player has not named the princess yet.
    var needsPrincessName = false
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
    /// What the goblins have brought home from slain monsters (material id → how many), and how many of each monster fell.
    private(set) var materials: [String: Int] = [:]
    private(set) var kills: [String: Int] = [:]
    /// Which material a pile of loot on the ground is (by food id; kept until the last piece is home).
    private var lootMaterial: [Int: String] = [:]
    /// Little "+2 黏液" labels that rise from where something was delivered or dropped.
    struct Floater { var text: String; var rarity: Rarity; var pos: CGPoint; var age = 0.0 }
    private(set) var floaters: [Floater] = []
    /// At most a few labels at a time, so a crowd of deliveries or deaths never fills the camp with text.
    private func addFloater(_ text: String, _ rarity: Rarity, at pos: CGPoint) {
        guard floaters.count < 3 else { return }
        floaters.append(Floater(text: text, rarity: rarity, pos: pos))
    }
    /// Green pluses around the princess while she heals the wounded (their ages).
    private(set) var healPulses: [Double] = []
    private var healTimer = 0.0
    /// Gear that came back (its wearer died, or something better replaced it) and nobody needs yet: gear id → how many.
    private(set) var armory: [GearItem] = []
    private var monsterTimer = -1.0
    private var raidTimer = 0.0
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
    /// How many goblins are out walking now (not resting in the nest).
    var visibleCount: Int { ants.reduce(0) { $0 + ($1.isHidden ? 0 : 1) } }

    /// How many goblins fit out walking in the current range: about one per 2200 square points, at least 12 (a whole screen
    /// takes 600 and more, a strip along the bottom about 20). The rest wait in the nest and come out as others go in.
    var visibleCap: Int {
        let area = walkable.reduce(0) { $0 + Double($1.width * $1.height) }
        // most of them shelter in the nest while it rains; fewer when the machine is struggling (see `PerfGovernor`)
        let perf = PerfGovernor.shared.factor
        return max(Int(12 * perf), Int(Double(area / 2200) * (isRaining ? 0.35 : 1) * perf))
    }

    /// How fast goblins wander in the current range: full speed across a screen, a little slower in a strip or a small window
    /// (they would be bumping into the edges all the time).
    var pace: Double {
        if walkable.isEmpty { return 1 }
        if walkable.allSatisfy({ ScreenChoice.isStrip($0) }) { return 0.75 }
        let area = walkable.reduce(0) { $0 + Double($1.width * $1.height) }
        return area < 700_000 ? 0.85 : 1
    }

    // MARK: Weather, fire, pond

    enum Weather { case clear, rain }
    private(set) var weather = Weather.clear
    /// The first spell of clear weather after starting the app lasts 20 to 60 minutes.
    private var weatherTimer = Double.random(in: 20...60) * 60
    /// Seconds since the weather began, for the rain animation.
    private(set) var weatherAge = 0.0
    /// The campfire party (while the pomodoro is resting) and the pond in the camp window.
    var fire: CGPoint?
    var obstacles: [Obstacle] = []
    /// The place the camp window is (its ground, trees, rocks and water); nil in the other ranges. Its water and solids are the obstacles.
    var scene: TerrainScene? {
        didSet {
            scene?.growth = peakAnts
            sceneStage = scene?.stage ?? 0
            obstacles = scene?.obstacles ?? []
        }
    }
    /// What changes in the camp window over the days (seasons, puddles, saplings, worn ground); made with the scene, kept in the save.
    private(set) var life: TerrainLife?
    private var savedLife: TerrainLifeState?
    private var lifeTimer = 0.0, heatTimer = 0.0, rainTimer = 0.0

    func terrainLife(seed: UInt64) -> TerrainLife {
        if let life, life.state.seed == seed { return life }
        let fresh = TerrainLife(seed: seed, state: savedLife)
        savedLife = nil
        fresh.onChange = { [weak self] in self?.lifeChanged() }
        life = fresh
        return fresh
    }

    private func lifeChanged() {
        scene?.refreshLife()
        obstacles = scene?.obstacles ?? []
        sceneStage = scene?.stage ?? 0
        onAntsChanged?() // so it is saved
    }

    /// The life of the camp window: what the goblins tread, the rain that leaves puddles, and what chance has done since last time.
    private func updateTerrainLife(dt: Double) {
        guard let scene, let life, !campHidden else { return }
        heatTimer += dt
        if heatTimer >= 0.5 {
            life.tread(ants.filter { !$0.isHidden }.map(\.pos), seconds: heatTimer, in: scene.world)
            heatTimer = 0
        }
        if isRaining {
            rainTimer += dt
            if rainTimer >= 1 {
                life.rain(dt: rainTimer, spot: { scene.freeSpot(&$0, $1) }, fraction: { scene.fraction($0) })
                rainTimer = 0
            }
        }
        lifeTimer -= dt
        if lifeTimer <= 0 {
            lifeTimer = 30
            life.advance(spot: { scene.freeSpot(&$0, $1) }, fraction: { scene.fraction($0) })
        }
    }

    /// The most goblins the camp has ever had: what the camp has grown to (its tents, totem and the rest of it turn up as this grows).
    private(set) var peakAnts = 0
    private var sceneStage = 0
    var isRaining: Bool { weather == .rain }

    /// `CAMP_WEATHER=rain|clear` fixes the weather (tests); `CAMP_WEATHER_SCALE` makes it change faster.
    private static let forcedWeather = ProcessInfo.processInfo.environment["CAMP_WEATHER"]
    private static let weatherScale = Double(ProcessInfo.processInfo.environment["CAMP_WEATHER_SCALE"] ?? "") ?? 1

    func setWeather(_ new: Weather, forSeconds seconds: Double) {
        weather = new
        weatherTimer = seconds
        weatherAge = 0
    }

    /// Clear spells last 40 to 120 minutes, rain 8 to 20 (real time); off when the setting is off.
    private func updateWeather(dt: Double) {
        if let forced = Colony.forcedWeather { weather = forced == "rain" ? .rain : .clear; weatherAge += dt; return }
        guard settings.weatherEnabled else { weather = .clear; return }
        weatherAge += dt
        weatherTimer -= dt * Colony.weatherScale
        if weatherTimer <= 0 {
            if weather == .clear { setWeather(.rain, forSeconds: Double.random(in: 8...20) * 60) } else { setWeather(.clear, forSeconds: Double.random(in: 40...120) * 60) }
        }
    }

    /// A place near the nest, some way off, for the campfire: to the right, left, below or above, whichever is inside the range.
    func fireSpot() -> CGPoint? {
        guard let nest else { return nil }
        if let pit = scene?.firePit, walkable.contains(where: { $0.insetBy(dx: 16, dy: 16).contains(pit) }) { return pit } // the ring of stones in the camp window
        let candidates = [CGPoint(x: nest.x + 90, y: nest.y - 10), CGPoint(x: nest.x - 90, y: nest.y - 10),
                          CGPoint(x: nest.x, y: nest.y - 60), CGPoint(x: nest.x, y: nest.y + 60)]
        return candidates.first { p in walkable.contains { $0.insetBy(dx: 16, dy: 16).contains(p) } && !obstacles.contains { $0.blocks(p, margin: 10) } } ?? candidates.last
    }

    /// In the camp window, a spot outside the world means "the middle of it" (not the nearest corner).
    var centreWhenOutside = false

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
        queen = Queen.settled(nest: spot, walkable: walkable)
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
            if let material = lootMaterial[id] {
                materials[material, default: 0] += pieces
                addFloater("+\(pieces) \(Materials.info(material)?.name ?? material)", Materials.info(material)?.rarity ?? .common, at: nest ?? .zero)
                if !foods.contains(where: { $0.id == id }) { lootMaterial[id] = nil }
                onAntsChanged?()
                return
            }
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
        case .caughtFish:
            foodDelivered += 1 // a fish is food for the camp
            addFloater("釣到魚了", .common, at: ants[index].pos)
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
        let point = walkable.isEmpty ? point : snapToWalkable(point) // the carriers must head for where the camp will really be
        nest = point
        phase = .running
        clearDecorations()
        ants = []
        spawnTimer = 0
        beginCarrying(to: point)
        primeWildlifeTimers()
        needsPrincessName = true
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
        let allowed = Colony.entrySides(of: rect)
        return sides.enumerated().filter { allowed.contains($0.offset) }.map(\.element).min { $0.distance < $1.distance }!.spot
    }

    /// The opening: two goblins come in from the nearest screen edge carrying the princess (a captive, over their
    /// heads) to the camp. They become the camp's first two inhabitants once they set her down.
    private func beginCarrying(to nest: CGPoint) {
        let home = Queen.homeSpot(for: nest, walkable: walkable)
        let start = nearestEdgePoint(to: nest)
        let dx = home.x - start.x, dy = home.y - start.y, length = max(1, hypot(dx, dy))
        let direction = CGPoint(x: dx / length, y: dy / length)
        queen = Queen(carriedTo: nest, walkable: walkable)
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

        // animals and monsters (monsters go after the goblins that are out walking, or the nest)
        var raid: RaidInfo?
        if let nest, creatures.contains(where: { $0.kind.hostile }) {
            raid = RaidInfo(nest: nest, prey: ants.filter { !$0.isHidden && !$0.isDying && !$0.isWounded }.map(\.pos))
        }
        for i in creatures.indices.reversed() {
            if creatures[i].update(dt: dt, walkable: walkable, raid: raid) {
                creatures.remove(at: i) // walked off the screen
            } else if creatures[i].takeStrike() {
                strike(by: i)
            }
        }
        updateMonsters(dt: dt)
        for i in floaters.indices { floaters[i].age += dt }
        floaters.removeAll { $0.age > 2.2 }
        for i in healPulses.indices { healPulses[i] += dt }
        healPulses.removeAll { $0 > 1.2 }
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
        // it walks in from a random edge (only the ends of a strip) toward somewhere inside
        func spread(_ low: CGFloat, _ high: CGFloat) -> CGFloat { low < high ? CGFloat.random(in: low...high) : (low + high) / 2 }
        let start: CGPoint, inward: CGPoint
        switch Colony.entrySides(of: rect).randomElement() ?? 0 {
        case 0: start = CGPoint(x: rect.minX - 30, y: spread(rect.minY + 40, rect.maxY - 40)); inward = CGPoint(x: 1, y: 0)
        case 1: start = CGPoint(x: rect.maxX + 30, y: spread(rect.minY + 40, rect.maxY - 40)); inward = CGPoint(x: -1, y: 0)
        case 2: start = CGPoint(x: spread(rect.minX + 40, rect.maxX - 40), y: rect.minY - 30); inward = CGPoint(x: 0, y: 1)
        default: start = CGPoint(x: spread(rect.minX + 40, rect.maxX - 40), y: rect.maxY + 30); inward = CGPoint(x: 0, y: -1)
        }
        let depth = CGFloat.random(in: 140...320)
        var target = CGPoint(x: start.x + inward.x * depth, y: start.y + inward.y * depth)
        if hypot(target.x - nest.x, target.y - nest.y) < 60 { target.x += 120 }
        if ProcessInfo.processInfo.environment["CAMP_DEBUG"] != nil { NSLog("GoblinCamp: a \(kind.id) walks in from \(start)") }
        creatures.append(Creature(id: nextCreatureID, kind: kind, start: start, enter: target, stay: Double.random(in: 120...240)))
        nextCreatureID += 1
    }

    // MARK: Monsters

    /// Seconds between raids for each level of the "monsters" setting (0 = none), and how many may be about at once.
    private static let monsterEvery: [Double] = [0, 900, 480, 240]
    private static let maxMonsters = [0, 2, 3, 5]

    /// A monster is about (the princess ducks into her hole, the goblins turn out).
    var monsterNear: Bool { creatures.contains { $0.kind.hostile } }

    /// A monster is close enough to the princess to frighten her.
    private var princessInDanger: Bool {
        guard let queen else { return false }
        return creatures.contains { $0.kind.hostile && hypot($0.pos.x - queen.pos.x, $0.pos.y - queen.pos.y) < 190 }
    }

    /// Raids: monsters turn up now and then (only while the camp is on the screen, so nothing happens unseen), and the goblins are
    /// called out when one gets close to the camp.
    private func updateMonsters(dt: Double) {
        let level = settings.monsters
        guard level > 0, !campHidden, ants.count >= 8, queen?.isCarried == false else { return }
        monsterTimer -= dt * Colony.wildScale
        if monsterTimer < 0 {
            if monsterTimer < -1_000_000 || creatures.filter({ $0.kind.hostile }).count < Colony.maxMonsters[level] { spawnMonsters() }
            monsterTimer = Colony.monsterEvery[level] * Double.random(in: 0.6...1.4)
        }
        // call the goblins out (again now and then, since the first ones may be hurt)
        raidTimer -= dt
        guard raidTimer <= 0, let nest else { return }
        raidTimer = 4
        for i in creatures.indices where creatures[i].kind.hostile {
            let d = hypot(creatures[i].pos.x - nest.x, creatures[i].pos.y - nest.y)
            guard d < 330 else { continue }
            creatures[i].scouted = true
            creatures[i].reported = true
            recruitHunters(for: creatures[i].id, count: 7)
        }
    }

    /// A monster (or a pack of them) walks in from a screen edge, heading for the camp.
    func spawnMonsters(of kind: AnimalKind? = nil) {
        guard nest != nil, let kind = kind ?? Animals.pick(monsters: true) else { return }
        let count = Int.random(in: kind.monster.pack)
        let before = creatures.count
        for _ in 0..<count { spawnAnimal(of: kind) }
        for i in before..<creatures.count { // a pack arrives spread out a little
            creatures[i].pos.x += CGFloat.random(in: -22...22)
            creatures[i].pos.y += CGFloat.random(in: -22...22)
            creatures[i].stay = Double.random(in: 200...320)
        }
    }

    /// A monster hits the nearest goblin in reach.
    private func strike(by index: Int) {
        let monster = creatures[index]
        let reach = monster.kind.radius * monster.scale + 14
        var best: (index: Int, distance: Double)?
        for (i, ant) in ants.enumerated() where !ant.isHidden && !ant.isDying && !ant.isWounded {
            let d = Double(hypot(ant.pos.x - monster.pos.x, ant.pos.y - monster.pos.y))
            if d < reach, d < (best?.distance ?? .infinity) { best = (i, d) }
        }
        guard let best, Double.random(in: 0..<1) < 0.55 else { return } // it often misses
        if Double.random(in: 0..<1) < ants[best.index].blockChance { // a shield turned it aside
            hits.append((pos: ants[best.index].pos, age: 0))
            wearOnHit(of: best.index, blocked: true)
            return
        }
        for _ in 0..<max(1, Int(monster.kind.monster.damage.rounded())) { hurt(ant: best.index) }
        wearOnHit(of: best.index, blocked: false)
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
        creatures[ci].hp -= ants[index].might
        wear(.weapon, of: index, by: 1)
        ants[index].swing = Ant.swingTime
        ants[index].swingHeading = atan2(creatures[ci].pos.y - ants[index].pos.y, creatures[ci].pos.x - ants[index].pos.x)
        ants[index].heading = ants[index].swingHeading
        creatures[ci].hurt = 0.35
        if creatures[ci].kind.hostile { creatures[ci].engaged = 4 }
        hits.append((pos: creatures[ci].pos, age: 0))
        if creatures[ci].hp <= 0 {
            kill(creatureAt: ci)
        } else if creatures[ci].kind.hostile {
            // monsters hit back on their own (see `strike`)
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
        if animal.kind.hostile {
            killMonster(animal)
            return
        }
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

    /// A monster is down: it may split, it leaves materials (each with its own chance), and the hunters carry them home.
    private func killMonster(_ monster: Creature) {
        kills[monster.kind.id, default: 0] += 1
        if monster.generation == 0, monster.kind.monster.splits > 0 { // a slime breaks into smaller ones
            for k in 0..<monster.kind.monster.splits {
                var small = Creature(id: nextCreatureID, kind: monster.kind, start: monster.pos, enter: monster.pos, stay: 240)
                nextCreatureID += 1
                small.state = .wandering
                small.generation = 1
                small.scale = 0.65
                small.hp = max(1, monster.kind.hp * 0.4)
                small.heading = Double(k) * .pi + Double.random(in: -0.6...0.6)
                small.scouted = true
                small.reported = true
                creatures.append(small)
            }
        }
        let luck = monster.generation == 0 ? 1.0 : 0.5 // the small ones are worth less
        var first: Int?
        for (n, drop) in Materials.roll(monster.kind.monster.drops + Materials.scraps, luck: luck).enumerated() {
            let angle = Double(n) * 1.7 + Double.random(in: 0..<1), spread = 9 + Double(n) * 3
            var pile = FoodSource(id: nextFoodID, kind: .loot, pos: CGPoint(x: monster.pos.x + cos(angle) * spread, y: monster.pos.y + sin(angle) * spread), amount: drop.count)
            pile.origin = .loot
            pile.capacityOverride = drop.count
            pile.material = drop.id
            pile.scouted = true
            pile.reported = true
            pile.pos = nearestWalkable(to: pile.pos)
            lootMaterial[nextFoodID] = drop.id
            foods.append(pile)
            if first == nil { first = nextFoodID }
            nextFoodID += 1
        }
        for i in ants.indices {
            switch ants[i].mode {
            case .hunting(let target, _), .inNestForHunt(_, let target), .huntNews(let target):
                if target == monster.id, let first { ants[i].mode = .foraging(food: first, slot: Double.random(in: 0..<(2 * .pi))) }
                else if target == monster.id { ants[i].mode = .wandering }
            default: break
            }
        }
        onAntsChanged?()
    }

    // MARK: Daily life

    private var matchTimer = 0.0

    /// Dark (goblins sleep more).
    static var isNight: Bool {
        let hour = Scenery.currentHour
        return hour >= 20 || hour < 6
    }

    /// Pairs goblins up for a friendly scuffle, and gives the golden ones somebody to wait on them. Done every couple of seconds.
    private func matchmake(world: AntWorld) {
        guard world.activitiesOn, !monsterNear else { return }
        func isIdle(_ i: Int) -> Bool {
            if case .wandering = ants[i].mode { return !ants[i].isWounded && !ants[i].isCarryingPrincess }
            return false
        }
        let idle = ants.indices.filter(isIdle)
        guard idle.count >= 2 else { return }

        // a scuffle: the strong ones start it most; the clever and the golden do not take part (nobody fights a golden one)
        let scuffling = ants.filter { if case .activity(.scuffle, _) = $0.mode { return true } else { return false } }.count / 2
        if scuffling < max(1, ants.count / 60), Double.random(in: 0..<1) < 0.5 {
            let fighters = idle.filter { ants[$0].traits.personality != .calm && ants[$0].traits.personality != .boss }
            let weights = fighters.map { ants[$0].traits.personality == .brute ? 4.0 : ants[$0].traits.personality == .lively ? 1.5 : 1.0 }
            if !fighters.isEmpty {
                var roll = Double.random(in: 0..<weights.reduce(0, +))
                var starter = fighters[0]
                for (k, i) in fighters.enumerated() { roll -= weights[k]; if roll < 0 { starter = i; break } }
                let near = fighters.filter { $0 != starter && hypot(ants[$0].pos.x - ants[starter].pos.x, ants[$0].pos.y - ants[starter].pos.y) < 90 }
                if let other = near.min(by: { hypot(ants[$0].pos.x - ants[starter].pos.x, ants[$0].pos.y - ants[starter].pos.y) < hypot(ants[$1].pos.x - ants[starter].pos.x, ants[$1].pos.y - ants[starter].pos.y) }) {
                    let seconds = Double.random(in: 5...9)
                    let a = ants[starter].id, b = ants[other].id
                    ants[starter].begin(.scuffle(partner: b), world: world, seconds: seconds)
                    ants[other].begin(.scuffle(partner: a), world: world, seconds: seconds)
                }
            }
        }

        // a golden goblin gets up and takes a stroll, and up to three of the common sort wait on it
        for boss in idle where ants[boss].traits.personality == .boss && Double.random(in: 0..<1) < 0.25 {
            let servants = idle.filter { i in
                i != boss && ants[i].traits.personality != .calm && ants[i].traits.personality != .boss && isIdle(i)
                    && hypot(ants[i].pos.x - ants[boss].pos.x, ants[i].pos.y - ants[boss].pos.y) < 220
            }.sorted { hypot(ants[$0].pos.x - ants[boss].pos.x, ants[$0].pos.y - ants[boss].pos.y) < hypot(ants[$1].pos.x - ants[boss].pos.x, ants[$1].pos.y - ants[boss].pos.y) }.prefix(3)
            guard !servants.isEmpty else { continue }
            let seconds = Double.random(in: 20...40)
            ants[boss].begin(.stroll, world: world, seconds: seconds)
            let offsets = [CGPoint(x: -22, y: -8), CGPoint(x: 22, y: -8), CGPoint(x: 0, y: -26)]
            for (k, i) in servants.enumerated() { ants[i].begin(.serve(boss: ants[boss].id, offset: offsets[k]), world: world, seconds: seconds) }
            break // one court at a time is plenty
        }
    }

    // MARK: Workshop

    enum CraftResult {
        case made(gear: Gear, by: String)
        /// Not enough of these materials.
        case missing
        /// Everybody already wears something at least as good for that slot.
        case nobodyNeeds
    }

    func canAfford(_ gear: Gear) -> Bool { gear.cost.allSatisfy { materials[$0.0, default: 0] >= $0.1 } }

    /// How many goblins wear this piece now.
    func wearers(of gear: Gear) -> Int { ants.filter { $0.gear[gear.slot.rawValue] == gear.id }.count }

    /// Makes a piece of gear from the stored materials and gives it to the goblin who gains most from it (see `neediest`).
    func craft(_ gear: Gear) -> CraftResult {
        guard canAfford(gear) else { return .missing }
        let item = GearItem(gear)
        guard let pick = neediest(for: item) else { return .nobodyNeeds }
        for (id, count) in gear.cost {
            materials[id, default: 0] -= count
            if materials[id] == 0 { materials[id] = nil }
        }
        made += 1
        give(item, to: pick)
        if let nest { addFloater("製作 \(gear.name) → \(ants[pick].name)", .uncommon, at: nest) }
        selectedAntID = ants[pick].id // ring the new owner so you can see who got it
        if !armory.isEmpty { redistributeArmory() } // what it replaced goes to the next one who needs it
        onAntsChanged?()
        return .made(gear: gear, by: ants[pick].name)
    }

    /// Who gains most from this piece: the goblin whose gear in that slot is worst (none at all first, a worn-out piece counts half);
    /// among equals the strong ones get weapons, the sturdy ones shields, the rest the average of both. Nobody who already has
    /// something at least as good.
    private func neediest(for item: GearItem) -> Int? {
        guard let gear = item.gear else { return nil }
        func currentPower(_ ant: Ant) -> Double { ant.item(in: gear.slot)?.power ?? 0 }
        func twoHanded(_ ant: Ant) -> Bool { ant.item(in: .weapon)?.gear?.grip == .two }
        let candidates = ants.indices.filter { !ants[$0].isDying && currentPower(ants[$0]) < item.power && !(gear.slot == .shield && twoHanded(ants[$0])) }
        return candidates.min(by: { a, b in
            let pa = currentPower(ants[a]), pb = currentPower(ants[b])
            if pa != pb { return pa < pb }
            func fit(_ ant: Ant) -> Double { gear.slot == .weapon ? ant.traits.might : gear.slot == .shield ? ant.traits.maxHealth : ant.traits.maxHealth * 0.5 + ant.traits.might * 0.5 }
            return fit(ants[a]) > fit(ants[b])
        })
    }

    /// Puts a piece on a goblin. What it wore in that slot goes back to the camp's stock (with the wear it has).
    private func give(_ item: GearItem, to index: Int) {
        let before = ants[index].maxHealth
        if let old = ants[index].equip(item) { armory.append(old) }
        ants[index].health = min(ants[index].maxHealth, ants[index].health + max(0, ants[index].maxHealth - before))
    }

    /// A goblin is gone (old age, or killed in a fight): everything it wore comes back to the nest.
    private func returnGear(of index: Int) {
        let pieces = GearSlot.allCases.compactMap { ants[index].takeOff($0) }
        guard !pieces.isEmpty else { return }
        armory.append(contentsOf: pieces)
        if let nest { addFloater("歸還 " + pieces.compactMap { $0.gear?.name }.joined(separator: "、"), .common, at: nest) }
    }

    /// Hands the stock on: each piece to the goblin who needs it most (a newborn with nothing, a goblin with something worse), best pieces first.
    /// Pieces nobody needs stay in the stock.
    func redistributeArmory() {
        var changed = true, rounds = 0
        while changed, rounds < 200 {
            changed = false
            rounds += 1
            for index in armory.indices.sorted(by: { armory[$0].power > armory[$1].power }) {
                guard let pick = neediest(for: armory[index]) else { continue }
                give(armory.remove(at: index), to: pick)
                changed = true
                break // the stock changed: start over from the best piece
            }
        }
        onAntsChanged?()
    }

    // MARK: Wear

    /// Gear that wore out and broke, and pieces made (for tests).
    private(set) var broken = 0
    private(set) var made = 0

    /// Wears a worn piece down; at 0 it breaks: it is gone, and a third of what it was made from can be picked out of the wreck.
    private static let wearScale = Double(ProcessInfo.processInfo.environment["CAMP_WEAR_SCALE"] ?? "") ?? 1 // faster wear for tests

    private func wear(_ slot: GearSlot, of index: Int, by rawAmount: Double) {
        let amount = rawAmount * Colony.wearScale
        guard let left = ants[index].gearLeft[slot.rawValue], let gear = ants[index].item(in: slot)?.gear else { return }
        if left - amount > 0 {
            ants[index].gearLeft[slot.rawValue] = left - amount
            return
        }
        _ = ants[index].takeOff(slot)
        broken += 1
        for (id, count) in gear.cost { for _ in 0..<count where Double.random(in: 0..<1) < 0.3 { materials[id, default: 0] += 1 } }
        addFloater("\(gear.name) 壞了", .common, at: ants[index].pos)
        ants[index].health = min(ants[index].health, ants[index].maxHealth)
        if !armory.isEmpty { redistributeArmory() } // there may be a spare for it
        onAntsChanged?()
    }

    /// A goblin takes a hit: its shield (if it holds one) and one piece of what it wears take the wear.
    private func wearOnHit(of index: Int, blocked: Bool) {
        let ant = ants[index]
        if ant.wornGear.contains(where: { $0.slot == .shield }) { wear(.shield, of: index, by: blocked ? 2 : 1) }
        guard !blocked else { return }
        var pool: [GearSlot] = []
        for slot in [GearSlot.head, .chest, .chest, .legs, .feet, .hands] where ant.gear[slot.rawValue] != nil { pool.append(slot) }
        if let slot = pool.randomElement() { wear(slot, of: index, by: 1) }
    }

    /// Test aid: everybody gets a full set of gear.
    func debugEquipEveryone() {
        let ids = ["long_sword", "wood_shield", "iron_helm", "leather_armor", "leather_pants", "leather_boots", "iron_gauntlets"]
        for i in ants.indices { for id in ids { if let g = Gears.by(id: id) { _ = ants[i].equip(GearItem(g)) } } }
    }

    func debugSelect(_ id: Int?) { selectedAntID = id }

    /// Test aid: lines the goblins up in rows (one row per facing), each in a different set of gear, to look at the drawings.
    func debugGearSheet(at origin: CGPoint, swing: Double?) {
        let weapons = Gears.all.filter { $0.slot == .weapon }
        let sets: [[String]] = [["cloth_cap", "cloth_armor", "cloth_pants", "cloth_shoes", "pelt_wraps"], ["leather_cap", "leather_armor", "leather_pants", "leather_boots", "pelt_wraps"],
                                ["iron_helm", "iron_plate", "leather_pants", "leather_boots", "iron_gauntlets"], ["cloth_cap", "gold_cloak", "cloth_pants", "cloth_shoes", "iron_gauntlets"]]
        let facings: [SpriteDirection] = [.right, .left, .down, .up]
        let candidates = ants.indices.filter { !ants[$0].isCarryingPrincess }
        for (n, i) in candidates.prefix(weapons.count * facings.count).enumerated() {
            let col = n % weapons.count, row = n / weapons.count
            for slot in GearSlot.allCases { _ = ants[i].takeOff(slot) }
            _ = ants[i].equip(GearItem(weapons[col]))
            if col % 3 != 2, let shield = Gears.by(id: col % 2 == 0 ? "wood_shield" : "goo_shield") { _ = ants[i].equip(GearItem(shield)) }
            for id in sets[(col + row) % sets.count] { if let g = Gears.by(id: id) { _ = ants[i].equip(GearItem(g)) } }
            ants[i].pos = CGPoint(x: origin.x + Double(col) * 46, y: origin.y - Double(row) * 52)
            ants[i].mode = .wandering
            ants[i].debugPose(facing: facings[row], swing: swing)
        }
    }

    /// Test aids.
    func debugAddMaterials(_ amounts: [String: Int]) {
        for (id, n) in amounts { materials[id, default: 0] += n }
    }

    func debugSpawnCreature(kind: AnimalKind, at point: CGPoint) {
        var c = Creature(id: nextCreatureID, kind: kind, start: point, enter: point, stay: 600)
        c.state = .wandering
        creatures.append(c)
        nextCreatureID += 1
    }

    /// Keeps the princess between her carriers, and sets her down once both have arrived.
    private func moveCarriedPrincess() {
        guard queen?.isCarried == true else {
            // the princess was put down some other way (the camp was moved or the window resized while she was being carried in):
            // the carriers must not stand there for ever
            if !carrierIDs.isEmpty {
                for i in ants.indices where carrierIDs.contains(ants[i].id) && ants[i].isCarryingPrincess { ants[i].mode = .wandering }
                carrierIDs = []
            }
            return
        }
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
        queen = Queen.settled(nest: nest, walkable: walkable)
        foodDelivered = saved.delivered ?? 0
        princessName = saved.princessName ?? ""
        materials = saved.materials ?? [:]
        kills = saved.kills ?? [:]
        peakAnts = max(saved.peak ?? 0, saved.goblins?.count ?? saved.antCount)
        savedLife = saved.terrain
        scene?.growth = peakAnts
        armory = (saved.armoryItems ?? []).map { GearItem(id: $0.id, left: $0.left) }.filter { $0.gear != nil }
        for (id, count) in saved.armory ?? [:] where Gears.by(id: id) != nil { armory.append(contentsOf: Array(repeating: GearItem(id: id, left: nil), count: count)) }

        func scattered() -> CGPoint {
            let angle = Double.random(in: 0..<(2 * .pi))
            let radius = Double.random(in: 0...1).squareRoot() * 200
            let p = CGPoint(x: nest.x + cos(angle) * radius, y: nest.y + sin(angle) * radius)
            return walkable.contains(where: { $0.contains(p) }) ? p : nest
        }
        if let goblins = saved.goblins {
            ants = goblins.prefix(settings.maxAnts).map { g in
                var ant = makeAnt(at: scattered(), breedIndex: breeds.firstIndex { $0.id == g.breed } ?? 0, age: g.age, seed: g.seed, id: g.id, name: g.name)
                for (slot, saved) in g.gear ?? [:] where GearSlot(rawValue: slot) != nil && Gears.by(id: saved.id) != nil {
                    _ = ant.equip(GearItem(id: saved.id, left: saved.left))
                }
                ant.health = ant.maxHealth
                return ant
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
                          goblins: ants.map { SavedGoblin(id: $0.id, breed: breeds[min($0.breedIndex, breeds.count - 1)].id, age: $0.age, seed: $0.seed, name: $0.name,
                                                    gear: savedGear(of: $0)) },
                          delivered: foodDelivered, nextID: nextAntID, princessName: princessName.isEmpty ? nil : princessName,
                          materials: materials.isEmpty ? nil : materials, kills: kills.isEmpty ? nil : kills, peak: peakAnts, terrain: life?.state ?? savedLife, armoryItems: armory.isEmpty ? nil : armory.map { SavedGear(id: $0.id, left: $0.left) })
    }

    private func savedGear(of ant: Ant) -> [String: SavedGear]? {
        var result: [String: SavedGear] = [:]
        for slot in GearSlot.allCases { if let item = ant.item(in: slot) { result[slot.rawValue] = SavedGear(id: item.id, left: item.left) } }
        return result.isEmpty ? nil : result
    }

    /// Births and restores both go through here so every individual gets its traits the same way.
    private func makeAnt(at pos: CGPoint, breedIndex: Int? = nil, age: Double = 0, seed: UInt64? = nil, id: Int? = nil, name: String? = nil) -> Ant {
        let breeds = self.breeds
        let index = min(breedIndex ?? Breeding.roll(from: breeds, delivered: foodDelivered), breeds.count - 1)
        var seed = seed ?? UInt64.random(in: 0...UInt64(UInt32.max))
        if id == nil { // a birth: try for a name nobody living has yet (a restored goblin keeps its seed and so its name)
            let taken = Set(ants.map(\.name))
            var tries = 0
            while taken.contains(Names.goblin(seed: seed)), tries < 40 {
                seed = UInt64.random(in: 0...UInt64(UInt32.max))
                tries += 1
            }
        }
        let traits = Traits.make(for: breeds[index], seed: seed)
        let ant = Ant(at: pos, id: id ?? nextAntID, breedIndex: index, traits: traits, seed: seed, age: age, name: name)
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
    /// Which sides animals and the carriers may come in from: 0 left, 1 right, 2 bottom, 3 top. A strip only has its two ends.
    static func entrySides(of rect: CGRect) -> [Int] {
        if rect.width >= rect.height * 2 { return [0, 1] }
        if rect.height >= rect.width * 2 { return [2, 3] }
        return [0, 1, 2, 3]
    }

    /// The camp window (a small fixed-size world of its own): put the nest in the middle and everyone around it.
    func relocate(into rect: CGRect) {
        walkable = [rect]
        guard let old = nest else { return }
        let centre = CGPoint(x: rect.midX, y: rect.midY)
        let dx = centre.x - old.x, dy = centre.y - old.y
        nest = centre
        queen = Queen.settled(nest: centre, walkable: walkable)
        let radius = max(20, min(rect.width, rect.height) * 0.3)
        for i in ants.indices {
            let a = Double.random(in: 0..<(2 * .pi)), r = Double.random(in: 0...1).squareRoot() * radius
            ants[i].pos = CGPoint(x: centre.x + cos(a) * r, y: centre.y + sin(a) * r)
        }
        for i in foods.indices { foods[i].pos = nearestWalkable(to: CGPoint(x: foods[i].pos.x + dx, y: foods[i].pos.y + dy)) }
        creatures.removeAll()
        onAntsChanged?()
    }

    func updateWalkable(_ rects: [CGRect]) {
        walkable = rects
        guard nest != nil, !rects.isEmpty else { return }
        if let nest, !isWalkable(nest) {
            let moved = snapToWalkable(nest)
            self.nest = moved
            queen = Queen.settled(nest: moved, walkable: walkable)
        }
        for i in ants.indices where !isWalkable(ants[i].pos) {
            ants[i].pos = nearestWalkable(to: ants[i].pos)
        }
        for i in foods.indices where !isWalkable(foods[i].pos) {
            foods[i].pos = nearestWalkable(to: foods[i].pos)
        }
        onAntsChanged?() // saves the (possibly moved) nest
    }

    /// The nearest place inside the walkable areas; in a strip the camp sits in the middle of it, not on its edge.
    private func snapToWalkable(_ p: CGPoint) -> CGPoint {
        if centreWhenOutside, !isWalkable(p), let world = walkable.first { return CGPoint(x: world.midX, y: world.midY) }
        var moved = isWalkable(p) ? p : nearestWalkable(to: p)
        if !isWalkable(p), let strip = walkable.first(where: { $0.insetBy(dx: -1, dy: -1).contains(moved) }), ScreenChoice.isStrip(strip) {
            if strip.width >= strip.height { moved.y = strip.midY } else { moved.x = strip.midX }
        }
        return moved
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

    /// The player renamed a goblin (empty puts back the name it was born with).
    func rename(antID: Int, to text: String) {
        guard let i = ants.firstIndex(where: { $0.id == antID }) else { return }
        let name = Names.clean(text)
        ants[i].name = name.isEmpty ? Names.goblin(seed: ants[i].seed) : name
        onAntsChanged?()
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
                                  outfit: outfits.isEmpty ? "" : outfits[min(outfitIndex, outfits.count - 1)].id, danger: princessInDanger)
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
                var born = makeAnt(at: CGPoint(x: nest.x + jitter(), y: nest.y + jitter()))
                if visibleCount >= visibleCap { born.mode = .inNest(remaining: Double.random(in: 25...60), thenForage: nil) } // no room outside yet
                ants.append(born)
                if ants.count > peakAnts { // the camp grows: something new may turn up on the ground
                    peakAnts = ants.count
                    if let scene {
                        scene.growth = peakAnts
                        if scene.stage != sceneStage {
                            sceneStage = scene.stage
                            obstacles = scene.obstacles
                        }
                    }
                }
                if !armory.isEmpty { redistributeArmory() } // a newcomer with nothing gets a hand-me-down
                if ProcessInfo.processInfo.environment["CAMP_DEBUG"] != nil { NSLog("GoblinCamp: ants=\(ants.count)") }
                queen?.greet(toward: nest)
                if Colony.milestones.contains(ants.count) { queen?.celebrate() }
                onAntsChanged?()
            }
        }
        updateWeather(dt: dt)
        let antDt = dt * settings.speedMultiplier
        var world = AntWorld(nest: nest, walkable: walkable, foods: foods, creatures: creatures.map(\.info), foodScale: Colony.foodScale(settings.antScale))
        world.pace = pace
        world.raining = isRaining
        world.fire = fire
        world.obstacles = obstacles
        world.ponds = scene?.ponds ?? []
        world.crowd = Double(visibleCount) / Double(visibleCap)
        world.night = Colony.isNight
        world.activitiesOn = !isRaining && fire == nil && world.crowd < 1.2
        matchTimer -= dt
        if matchTimer <= 0, !campHidden {
            matchTimer = 2.5
            matchmake(world: world)
        }
        for ant in ants { // (after matchmaking, so a new pair or court finds each other on its very first step)
            switch ant.mode {
            case .activity(.scuffle, _): world.partners[ant.id] = ant.pos
            case .activity(.stroll, _): world.bosses[ant.id] = ant.pos
            default: break
            }
        }
        // while the princess is out and about she tends the wounded resting in the nest
        let tending = queen.map { $0.arrived && $0.alpha > 0.9 && !monsterNear } ?? false
        world.healRate = tending ? 0.4 : 0.05
        healTimer -= dt
        if healTimer <= 0 {
            healTimer = 1.1
            if tending, ants.contains(where: { $0.isHidden && $0.health < $0.maxHealth }) { healPulses.append(0) }
        }
        let ageDt = dt * Colony.timeScale
        var events: [(index: Int, event: Ant.Event)] = []
        for i in ants.indices {
            if let event = ants[i].update(dt: antDt, ageDt: ageDt, world: world) { events.append((i, event)) }
        }
        for (index, event) in events { handle(event, from: index) }
        moveCarriedPrincess()
        updateWildlife(dt: dt)
        updateTerrainLife(dt: dt)
        // the dead leave the colony (highest index first so the others keep their places)
        let gone = events.filter { if case .died = $0.event { return true } else { return false } }.map(\.index)
        for index in gone.sorted(by: >) {
            if ants[index].id == selectedAntID { selectedAntID = nil }
            returnGear(of: index) // old age or killed in a fight: what it wore comes back to the nest
            ants.remove(at: index)
        }
        if !gone.isEmpty, !armory.isEmpty { redistributeArmory() }
        deaths += gone.count
        if !gone.isEmpty { onAntsChanged?() }
    }
}
