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

    static let maxFoods = 10
    /// At most this many ants work on one food at a time.
    static let maxForagers = 10

    /// Ant counts at which the queen celebrates.
    private static let milestones: Set<Int> = [10, 50, 100, 200, 300, 400, 500]

    private let settings = Settings.shared

    /// Which breeds exist. Normally the current character's; tests can put their own here.
    var breedOverride: [Breed]?
    var breeds: [Breed] { breedOverride ?? Characters.current.breeds }

    private(set) var phase: Phase = .choosingNest
    /// Set while picking a new spot for an existing colony, so Esc can put things back as they were.
    private var phaseBeforePicking: Phase?
    private(set) var nest: CGPoint?
    private var graveCache: (nest: CGPoint, count: Int, spots: [CGPoint])?
    /// Residents who walked off into the big world (their ids): when the books have them home again they walk back in.
    private var awayIDs = Set<Int>()

    /// The undead camp's graves, in a fan below the nest where there is ground: more as the camp grows (they sleep in them,
    /// AntView draws them). None for the other races.
    var graves: [CGPoint] {
        guard Characters.current.id == "undead", let nest else { return [] }
        let count = min(8, 3 + peakAnts / 30)
        if let c = graveCache, c.nest == nest, c.count == count { return c.spots }
        var spots: [CGPoint] = []
        for k in 0..<count {
            let angle = (205 + Double(k) * 130 / Double(max(1, count - 1))) * .pi / 180
            let r = 58.0 + Double(k % 2) * 16
            let p = CGPoint(x: nest.x + cos(angle) * r * 1.3, y: nest.y + sin(angle) * r * 0.75)
            if walkable.contains(where: { $0.insetBy(dx: 8, dy: 8).contains(p) }) { spots.append(p) }
        }
        graveCache = (nest, count, spots)
        return spots
    }
    var queen: Queen?
    var ants: [Ant] = []
    /// See `followsBooks`.
    fileprivate var booksDriven = false
    /// Residents the books say fell in the raid being played: they die in the fight (or when it ends), nobody else does.
    var doomed = Set<Int>()
    /// The raid being played: when it began (real seconds), and its monsters' ids.
    var raidPlaying: (began: Double, monsters: Set<Int>)?
    /// Something the player did that the books must do (craft, repair, food) while the camp follows the books.
    var onBookCommand: ((BookCommand) -> Void)?
    /// The princess had a child while the camp follows the books: the server adds it (breed id, parents).
    var onPrincessChild: ((String, String) -> Void)?
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
    /// (A story beat, `important`, pushes the oldest label out instead of being dropped.)
    func addFloater(_ text: String, _ rarity: Rarity, at pos: CGPoint, important: Bool = false) {
        if floaters.count >= 3 {
            guard important else { return }
            floaters.removeFirst()
        }
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
    var outfitIndex: Int = Int(ProcessInfo.processInfo.environment["CAMP_OUTFIT"] ?? "") ?? 0
    /// The princess's love life (see Romance.swift), and the parts of it that are only about the moment.
    var romance = RomanceState()
    var romanceRuntime = RomanceRuntime()
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
            scene?.farmLevel = farmLevel
            scene?.farmRace = farmRace
            scene?.sites = sites
            sceneStage = scene?.stage ?? 0
            obstacles = scene?.obstacles ?? []
        }
    }
    /// The farm as the books have it (server/FARM.md): the camp window draws what each level added.
    var farmLevel = 1 { didSet { scene?.farmLevel = farmLevel } }
    var farmRace = "goblin" { didSet { scene?.farmRace = farmRace } }
    var sites: [(id: Int, kind: String, level: Int)] = [] { didSet { scene?.sites = sites } }
    /// What changes in the camp window over the days (seasons, puddles, saplings, worn ground); made with the scene, kept in the save.
    /// The life of the place the goblins are in now. Each place (the camp window, the strip along the bottom, the right, the left) keeps its
    /// own, so switching between them and back never loses what was felled, dug or sown, or the paths worn into the ground.
    private(set) var life: TerrainLife?
    private var lives: [String: TerrainLife] = [:]
    private var savedLives: [String: TerrainLifeState] = [:]
    private var lifeTimer = 0.0, heatTimer = 0.0, rainTimer = 0.0

    /// The life of `place` ("window", "bottom", "right", "left") made from `seed`: the one already running, or the one from the save, or a new one.
    func terrainLife(place: String, seed: UInt64) -> TerrainLife {
        if let existing = lives[place], existing.state.seed == seed { life = existing; return existing }
        let fresh = TerrainLife(seed: seed, state: savedLives[place])
        savedLives[place] = nil
        fresh.onChange = { [weak self] in self?.lifeChanged() }
        lives[place] = fresh
        life = fresh
        return fresh
    }

    /// A line for the tests: what each place remembers.
    var lifeReport: String {
        allLives.sorted { $0.key < $1.key }.map { "\($0.key): \($0.value.cuts.count) cuts, \($0.value.plots.filter { $0.state > 0 }.count) plots worked, \($0.value.puddles.count) puddles, \($0.value.heat.count) trodden cells" }.joined(separator: " | ")
    }

    /// Every place's life as it is now, for the save.
    private var allLives: [String: TerrainLifeState] {
        var all = savedLives
        for (place, life) in lives { all[place] = life.state }
        return all
    }

    /// The camp window was resized: which trees, rocks and ponds are in it changed.
    func refreshObstacles() {
        scene?.refreshLife()
        obstacles = scene?.obstacles ?? []
        resourceTimer = 0
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
            let strip = scene.isStrip // (a strip grows no saplings of its own: they would be drawn at the camp window's size)
            life.advance(spot: { strip ? nil : scene.freeSpot(&$0, $1) }, fraction: { scene.fraction($0) })
            if strip { // ...but now and then a log falls or a stone shows, so wood and stone come back
                let alive = scene.resourceSpots().count
                life.addDrift(alive: alive, cap: max(6, Int(scene.world.width * scene.world.height / 4200)), spot: { scene.driftSpot(&$0) }, fraction: { scene.fraction($0) })
            }
        }
    }

    /// The most goblins the camp has ever had: what the camp has grown to (its tents, totem and the rest of it turn up as this grows).
    var peakAnts = 0
    /// Game time: seconds the camp has been going (only while the app runs). Things arrive by it: animals after a few minutes, the first
    /// monsters after half an hour, stronger ones later. `CAMP_WILD_SCALE` runs it faster (tests).
    private(set) var playSeconds = 0.0
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

    /// Puts the camp back at a spot it had (another walking range was left and this one is back): only if that spot can be walked on now.
    @discardableResult
    func setNest(_ point: CGPoint) -> Bool {
        guard nest != nil, isWalkable(point) else { return false }
        nest = point
        queen = Queen.settled(nest: point, walkable: walkable)
        onAntsChanged?()
        return true
    }

    /// The drag finished: let the app save the new spot.
    func nestDragEnded() {
        onAntsChanged?()
    }

    // MARK: Food

    func beginPlacingFood(_ kind: FoodKind) {
        guard phase == .running, cooldownLeft(kind) <= 0, Characters.current.placeableFoods.contains(kind) else { return }
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
        foodCooldowns[kind] = Colony.foodCooldown
        if followsBooks { onBookCommand?(.food(kind.rawValue)) } // the books start its boost and cooldown
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
        for (i, ant) in ants.enumerated() where !ant.isChild {
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
        case .delivered(let id, let kind, let pieces):
            if let material = lootMaterial[id] {
                if !followsBooks { materials[material, default: 0] += pieces } // (the books have what raids drop, and what felling and digging make: the server counts them by the hour)
                addFloater("+\(pieces) \(Materials.info(material)?.name ?? material)", Materials.info(material)?.rarity ?? .common, at: nest ?? .zero)
                if !foods.contains(where: { $0.id == id }) { lootMaterial[id] = nil }
                onAntsChanged?()
                return
            }
            foodDelivered += pieces
            if kind.grows {
                grow(kind == .bones ? "bone" : "soul", pieces: pieces)
            } else if let boost = kind.boost, Characters.current.rules.eats != false || kind.actsAs != nil {
                feed(boost, pieces: pieces)
            }
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
        case .gathered(let kind, let id, let face, _):
            finishGathering(kind: kind, id: id, foot: CGPoint(x: face.x, y: face.y - 6), by: index)
        case .caughtFish:
            // a fish goes into the larder, for the stew (if it is full the goblins simply eat it)
            if larder["fish", default: 0] < Colony.larderLimit { larder["fish", default: 0] += 1 } else { foodDelivered += 1 }
            addFloater("釣到魚了", .common, at: ants[index].pos)
        case .cooked(let pot):
            finishCooking(at: pot)
        case .tended(let child):
            tend(child: child, by: index)
        case .farmed(let plot, let action):
            finishFarming(plot: plot, action: action, by: index)
        case .carrierArrived:
            carriersArrived += 1
        case .died, .departed:
            break // removed by the caller once all events are handled
        }
    }

    /// The nearest point just past the edge of the ground a resident is on (where it walks off to).
    private func edgePoint(from p: CGPoint) -> CGPoint {
        guard let rect = walkable.first(where: { $0.contains(p) }) ?? walkable.first else { return p }
        let options = [CGPoint(x: rect.minX + 2, y: p.y), CGPoint(x: rect.maxX - 2, y: p.y), CGPoint(x: p.x, y: rect.minY + 2), CGPoint(x: p.x, y: rect.maxY - 2)]
        return options.min { hypot($0.x - p.x, $0.y - p.y) < hypot($1.x - p.x, $1.y - p.y) } ?? p
    }

    /// Everything a camp has earned is for that camp: a new camp starts with nothing: no materials or kills, an empty larder and armory, the
    /// camp back to its first tent, the princess single, the ground (what was felled, dug and worn) as it was made.
    /// (The settings, the camp window and the land itself stay.)
    private func startOver() {
        romance = RomanceState()
        romanceRuntime = RomanceRuntime()
        materials = [:]
        kills = [:]
        lootMaterial = [:]
        foodDelivered = 0
        deaths = 0
        slain = 0
        larder = [:]
        boosts = [:]
        foodCooldowns = [:]
        armory = []
        peakAnts = 0
        playSeconds = 0
        creatures = []
        eggs = []
        hits = []
        healPulses = []
        floaters = []
        outfitIndex = Int(ProcessInfo.processInfo.environment["CAMP_OUTFIT"] ?? "") ?? 0
        selectedAntID = nil
        lives = [:]
        savedLives = [:]
        life = nil
        scene?.life = nil
        scene?.growth = 0
        primeWildlifeTimers()
        onNewCamp?()
    }

    /// Called when a new camp is started (so the app can forget things that belonged to the old one).
    var onNewCamp: (() -> Void)?

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
        startOver()
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
            ant.age = max(ant.age, Ant.childSeconds + 5) // the two who carry the princess in are grown up
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
            raid = RaidInfo(nest: nest, prey: ants.filter { !$0.isHidden && !$0.isDying && !$0.isWounded && !$0.isChild }.map(\.pos))
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
            foods[i].regrow -= dt * Colony.wildScale * settings.pace
            if foods[i].regrow <= 0 {
                foods[i].amount += 1
                foods[i].regrow = Colony.treeRegrowTime
                foods[i].scouted = false
                foods[i].reported = false
            }
        }

        guard level > 0, ants.count >= 6, playSeconds >= 6 * 60, queen?.isCarried == false else { return }
        animalTimer -= dt * Colony.wildScale * settings.pace
        treeTimer -= dt * Colony.wildScale * settings.pace
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
    var princessInDanger: Bool {
        guard let queen else { return false }
        return creatures.contains { $0.kind.hostile && hypot($0.pos.x - queen.pos.x, $0.pos.y - queen.pos.y) < 190 }
    }

    /// Raids: monsters turn up now and then (only while the camp is on the screen, so nothing happens unseen), and the goblins are
    /// called out when one gets close to the camp.
    private func updateMonsters(dt: Double) {
        let level = settings.monsters
        // Nothing comes for a young camp: the game must have run a while (the first raid comes half an hour to an hour in) and the camp must
        // have had some numbers to defend itself. The first one is then after a random wait, never at once.
        guard level > 0, !campHidden, ants.count >= 12, peakAnts >= 25, playSeconds >= 30 * 60, queen?.isCarried == false else { return }
        if followsBooks { callOutAgainstMonsters(dt: dt); return } // raids come from the books (playRaid)
        if monsterTimer == -1 { monsterTimer = Colony.monsterEvery[level] * Double.random(in: 0.4...1.2) }
        monsterTimer -= dt * Colony.wildScale * settings.pace
        if monsterTimer < 0 {
            if monsterTimer < -1_000_000 || creatures.filter({ $0.kind.hostile }).count < Colony.maxMonsters[level] { spawnMonsters() }
            monsterTimer = Colony.monsterEvery[level] * Double.random(in: 0.6...1.4)
        }
        callOutAgainstMonsters(dt: dt)
    }

    /// Calls the goblins out when a monster gets close to the camp (again now and then, since the first ones may be hurt).
    private func callOutAgainstMonsters(dt: Double) {
        raidTimer -= dt
        guard raidTimer <= 0, let nest else { return }
        raidTimer = 4
        for i in creatures.indices where creatures[i].kind.hostile {
            if creatures[i].kind.monster.nightOnly, !Colony.isNight { creatures[i].stay = 0 } // (bats go home at dawn)
            let d = hypot(creatures[i].pos.x - nest.x, creatures[i].pos.y - nest.y)
            guard d < 330 else { continue }
            creatures[i].scouted = true
            creatures[i].reported = true
            recruitHunters(for: creatures[i].id, count: 7)
        }
    }

    /// A monster (or a pack of them) walks in from a screen edge, heading for the camp.
    func spawnMonsters(of kind: AnimalKind? = nil) {
        guard nest != nil, let kind = kind ?? Animals.pick(monsters: true, minutes: playSeconds / 60, ants: peakAnts, biome: scene?.biome.rawValue, night: Colony.isNight,
                                                                   water: scene.map { !$0.visiblePonds.isEmpty } ?? false) else { return }
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
        for (i, ant) in ants.enumerated() where !ant.isHidden && !ant.isDying && !ant.isWounded && !ant.isChild {
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
        for (i, ant) in ants.enumerated() where !ant.isWounded && !ant.isChild {
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
        let rules = Characters.current.rules
        creatures[ci].hp -= ants[index].might * (1 + 0.2 * boost(.meat)) * (Colony.isNight ? rules.nightMight ?? 1 : 1)
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
            // it bites back, unless the blow came from a distance (an archer race)
            if Double.random(in: 0..<1) < 0.4, (Characters.current.rules.ranged ?? 0) <= 0 { hurt(ant: index) }
        } else {
            let away = atan2(creatures[ci].pos.y - ants[index].pos.y, creatures[ci].pos.x - ants[index].pos.x)
            creatures[ci].state = .fleeing(remaining: 2.5, angle: away)
        }
    }

    /// The animal bites: the goblin loses health, limps home when it is nearly done for, and may be killed.
    private func hurt(ant index: Int) {
        if Double.random(in: 0..<1) < 0.2 * boost(.cheese) { // well fed, it shrugs the blow off
            hits.append((pos: ants[index].pos, age: 0))
            return
        }
        ants[index].health -= 1
        hits.append((pos: ants[index].pos, age: 0))
        if ants[index].health <= 0, followsBooks, doomed.remove(ants[index].id) != nil { // the books say it fell in this raid
            ants[index].ageless = false
            ants[index].mode = .dying(remaining: Ant.dyingTime)
            slain += 1
        } else if ants[index].health <= 0, followsBooks { // only the books say who dies: it faints and limps home
            ants[index].health = 1
            ants[index].mode = .returningToNest
        } else if ants[index].health <= 0 {
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
        let eats = Characters.current.rules.eats != false
        let amount = eats ? animal.kind.meat : max(3, animal.kind.meat / 2)
        var meat = FoodSource(id: nextFoodID, kind: eats ? .meat : .bones, pos: animal.pos, amount: amount) // (the undead take the bones)
        meat.origin = .meat
        meat.capacityOverride = amount
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
        if !followsBooks { kills[monster.kind.id, default: 0] += 1 }
        if Characters.current.rules.lineage != nil { releaseSoul(at: monster.pos, coloured: Double.random(in: 0..<1) < 0.3) }
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
        let first = dropLoot(Materials.roll(monster.kind.monster.drops + Materials.scraps, luck: luck).map { ($0.id, $0.count) }, at: monster.pos)
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

    /// Leaves piles of materials on the ground (one per material) for the goblins to carry home. Returns the id of the first pile.
    @discardableResult
    private func dropLoot(_ items: [(id: String, count: Int)], at position: CGPoint) -> Int? {
        var first: Int?
        for (n, drop) in items.enumerated() {
            let angle = Double(n) * 1.7 + Double.random(in: 0..<1), spread = 9 + Double(n) * 3
            var pile = FoodSource(id: nextFoodID, kind: .loot, pos: CGPoint(x: position.x + cos(angle) * spread, y: position.y + sin(angle) * spread), amount: drop.count)
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
        return first
    }

    // MARK: The larder and the cooking

    /// What is stored for cooking (fish, vegetables), and how much of each the larder holds.
    private(set) var larder: [String: Int] = [:]
    static let larderLimit = 16
    var larderTotal: Int { larder.values.reduce(0, +) }

    /// The stew is done. How it turned out is up to chance: mostly fine, sometimes wonderful, sometimes burnt, now and then the pot is tipped over.
    /// The dish is a pile of stew beside the fire ring for the goblins to carry home.
    private func finishCooking(at pot: CGPoint) {
        let used = min(larderTotal, Int.random(in: 2...4))
        guard used >= 2 else { return addFloater("沒有食材可以煮", .common, at: pot) }
        var fish = 0, veg = 0
        for _ in 0..<used {
            // take from whichever there is more of (a mixed pot when both are stocked)
            let pick = (larder["fish", default: 0] > larder["veg", default: 0]) == (Double.random(in: 0..<1) < 0.75) ? "fish" : "veg"
            let key = larder[pick, default: 0] > 0 ? pick : (pick == "fish" ? "veg" : "fish")
            guard larder[key, default: 0] > 0 else { continue }
            larder[key]! -= 1
            if larder[key] == 0 { larder[key] = nil }
            if key == "fish" { fish += 1 } else { veg += 1 }
        }
        let name = fish > 0 && veg > 0 ? "魚菜燉鍋" : fish > 0 ? "魚湯" : "蔬菜燉菜"
        var pieces = (fish + veg) * 2 + Int.random(in: 0...3)
        let roll = Double.random(in: 0..<1)
        let message: String
        if roll < 0.05 { pieces = 0; message = "打翻了鍋子…" }
        else if roll < 0.22 { pieces = max(1, pieces / 2); message = "\(name)燒焦了" }
        else if roll > 0.85 { pieces = pieces * 3 / 2; message = "香噴噴的\(name)！" }
        else { message = "煮好了\(name)" }
        addFloater(message, roll > 0.85 ? .uncommon : .common, at: pot)
        if pieces > 0 {
            var stew = FoodSource(id: nextFoodID, kind: .stew, pos: CGPoint(x: pot.x + CGFloat.random(in: -12...12), y: pot.y - 6), amount: pieces)
            stew.capacityOverride = pieces
            stew.scouted = true
            stew.reported = true
            foods.append(stew)
            let id = nextFoodID
            nextFoodID += 1
            recruit(for: id, count: min(6, pieces)) // the smell brings them
        }
        onAntsChanged?()
    }

    // MARK: The undead: souls and bones

    /// Which kind the next new one will be ("bone" after bones came home, "soul" after a soul), or nil for either.
    private var nextLineage: String?
    private var soulTimer = 30.0

    /// Bones or souls reached the soul tower: the next new one comes sooner, and of that kind.
    private func grow(_ lineage: String, pieces: Int) {
        spawnTimer += (lineage == "bone" ? 40 : 60) * Double(pieces)
        nextLineage = lineage
        if let nest, Double.random(in: 0..<1) < 0.35 { addFloater(lineage == "bone" ? "骨頭搬回了魂塔" : "魂魄飄進了靈魂之火", .common, at: nest) }
    }

    /// The breed of a new one for a race that grows from bones and souls (nil = any, by the usual roll).
    private func lineageBreed() -> Int? {
        guard let lineage = Characters.current.rules.lineage else { return nil }
        let kind = nextLineage ?? (Bool.random() ? "bone" : "soul")
        nextLineage = nil
        let ids = kind == "bone" ? lineage.bone : lineage.soul
        let candidates = breeds.indices.filter { ids.contains(breeds[$0].id) && breeds[$0].weight > 0 }
        guard !candidates.isEmpty else { return nil }
        var pick = Double.random(in: 0..<candidates.reduce(0) { $0 + breeds[$1].weight })
        for i in candidates {
            pick -= breeds[i].weight
            if pick < 0 { return i }
        }
        return candidates.last
    }

    /// A soul set loose (a monster fell): it drifts to the soul fire by itself; now and then it is a coloured one (a boost).
    private func releaseSoul(at pos: CGPoint, coloured: Bool) {
        let kind: FoodKind = coloured ? [.soulBlue, .soulGreen, .soulPurple].randomElement()! : .soul
        var soul = FoodSource(id: nextFoodID, kind: kind, pos: nearestWalkable(to: pos), amount: coloured ? 4 : 1)
        soul.capacityOverride = soul.amount
        soul.origin = .meat // (gone once taken, like what a hunt leaves)
        foods.append(soul)
        nextFoodID += 1
    }

    /// For a race that grows from bones and souls: now and then a soul turns up somewhere about and drifts toward the soul fire (it
    /// arrives by itself; carrying it is quicker), and now and then a pile of bones is found to be dug up and carried home.
    private func updateSouls(dt: Double) {
        guard Characters.current.rules.lineage != nil, let nest else { return }
        soulTimer -= dt * settings.pace
        if soulTimer <= 0 {
            soulTimer = Double.random(in: 70...150)
            let souls = foods.filter { $0.kind == .soul }.count, piles = foods.filter { $0.kind == .bones }.count
            let angle = Double.random(in: 0..<(2 * .pi)), radius = Double.random(in: 90...260)
            let spot = nearestWalkable(to: CGPoint(x: nest.x + cos(angle) * radius, y: nest.y + sin(angle) * radius))
            if Double.random(in: 0..<1) < 0.6 {
                if souls < 4 { releaseSoul(at: spot, coloured: Double.random(in: 0..<1) < 0.1) }
            } else if piles < 3 {
                var bones = FoodSource(id: nextFoodID, kind: .bones, pos: spot, amount: 6)
                bones.capacityOverride = 6
                foods.append(bones)
                nextFoodID += 1
            }
        }
        // the soul fire draws the plain souls in
        let pull = 3.0 * dt * settings.pace * (1 + boost(.honey) / 2)
        var arrived: [Int] = []
        for i in foods.indices where foods[i].kind == .soul {
            let dx = nest.x - foods[i].pos.x, dy = nest.y - foods[i].pos.y, d = hypot(dx, dy)
            if d < 14 { arrived.append(i); continue }
            foods[i].pos.x += dx / d * pull
            foods[i].pos.y += dy / d * pull
        }
        for i in arrived.sorted(by: >) {
            foods.remove(at: i)
            grow("soul", pieces: 1)
        }
    }

    // MARK: What the food does

    /// What each food brought home is still doing (seconds left, by the boost), and how long before each kind may be put down again.
    /// Both count down while the camp is running and are saved with it, so they do not run out while the app is closed.
    private(set) var boosts: [FoodKind: Double] = [:]
    private(set) var foodCooldowns: [FoodKind: Double] = [:]
    /// Every piece carried home adds this much (a pot of stew, which helps with everything, half as much), up to the cap.
    static let boostPerPiece = 240.0
    static let boostCap = 3600.0
    /// After putting a food down, the same kind cannot be put down again for this long.
    static let foodCooldown: Double = Double(ProcessInfo.processInfo.environment["CAMP_FOOD_COOLDOWN"] ?? "") ?? 1200

    /// How strongly a boost is on: 1 while its food's time lasts, a third while only stew's does, else 0; times what that food does
    /// for this race (elves: fruit 1.5, meat nothing).
    func boost(_ kind: FoodKind) -> Double {
        var best = strength(kind)
        for soul in [FoodKind.soulBlue, .soulGreen, .soulPurple] where soul.actsAs == kind { best = max(best, strength(soul)) } // the undead's souls
        return best
    }

    private func strength(_ kind: FoodKind) -> Double {
        let scale = Characters.current.rules.foodScale(kind.rawValue)
        if boosts[kind, default: 0] > 0 { return scale }
        return boosts[.stew, default: 0] > 0 ? scale / 3 : 0
    }

    func boostLeft(_ kind: FoodKind) -> Double { boosts[kind, default: 0] }
    func cooldownLeft(_ kind: FoodKind) -> Double { foodCooldowns[kind, default: 0] }

    private func feed(_ kind: FoodKind, pieces: Int) {
        if followsBooks { return } // (the books have its boost from when it was put down)
        let was = boosts[kind, default: 0]
        let per = kind == .stew ? Colony.boostPerPiece / 2 : Colony.boostPerPiece
        boosts[kind] = min(Colony.boostCap, was + per * Double(pieces))
        if was <= 0, let nest { addFloater("\(kind.emoji) \(kind.effect)", .uncommon, at: nest) } // it has just started
    }

    private func updateBoosts(dt: Double) {
        for (kind, left) in boosts { boosts[kind] = left - dt > 0 ? left - dt : nil }
        for (kind, left) in foodCooldowns { foodCooldowns[kind] = left - dt > 0 ? left - dt : nil }
    }

    /// Saved by name (an unknown name from a newer version is skipped).
    static func kinds(_ saved: [String: Double]?) -> [FoodKind: Double] {
        var result: [FoodKind: Double] = [:]
        for (name, value) in saved ?? [:] { if let kind = FoodKind(rawValue: name), value > 0 { result[kind] = value } }
        return result
    }

    static func names(_ values: [FoodKind: Double]) -> [String: Double] {
        Dictionary(uniqueKeysWithValues: values.map { ($0.key.rawValue, $0.value) })
    }

    // MARK: The young ones

    private var childTimer = 0.0
    private var knownChildren = Set<Int>()

    /// A grown one has minded a young one: it grows up a little faster, and if it has a cold it usually gets better.
    private func tend(child id: Int, by index: Int) {
        guard let c = ants.firstIndex(where: { $0.id == id }), ants[c].isChild else { return }
        ants[c].age += 45
        if ants[c].sick > 0, Double.random(in: 0..<1) < 0.7 {
            ants[c].sick = 0
            addFloater("\(ants[c].name) 退燒了", .uncommon, at: ants[c].pos)
        } else if Double.random(in: 0..<1) < 0.25 {
            addFloater("小哥布林笑了", .common, at: ants[c].pos)
        }
    }

    /// Every few seconds: a young one may catch a cold (a matter of chance; it lasts about six minutes unless it is minded), and the ones that
    /// have just grown up are noticed.
    private func updateChildren(dt: Double) {
        childTimer -= dt
        guard childTimer <= 0 else { return }
        childTimer = 5
        var now = Set<Int>()
        let berries = boost(.berries)
        for i in ants.indices where ants[i].isChild {
            now.insert(ants[i].id)
            if ants[i].sick <= 0, Double.random(in: 0..<1) < 0.001 * Ant.childCatchScale * (1 - 0.7 * berries) { ants[i].sick = Double.random(in: 300...420) }
            ants[i].age += 5 * Colony.timeScale * 0.5 * berries // berries: they grow up half as fast again
        }
        for id in knownChildren.subtracting(now) {
            if let a = ants.first(where: { $0.id == id }), Double.random(in: 0..<1) < 0.4 { addFloater("\(a.name) 長大了", .uncommon, at: a.pos) }
        }
        knownChildren = now
    }

    // MARK: The farm

    private var plotCache: [TerrainScene.PlotInfo] = []
    /// The tents a goblin can step into now (refreshed every couple of seconds).
    private var entranceCache: [CGPoint] = []

    /// A goblin has done a job at a plot. Tilling turns fallow or withered ground into a bed; sowing puts in a crop that suits the season (a
    /// poor sowing comes up thin); watering helps what grows along (usually); harvesting fills the larder (now and then a giant pumpkin).
    private func finishFarming(plot index: Int, action: Int, by ant: Int) {
        guard let scene, let life, life.state.plots.indices.contains(index) else { return }
        let spot = scene.plotSpots.indices.contains(index) ? scene.plotSpots[index].center : ants[ant].pos
        let now = TerrainClock.now
        var message = ""
        switch action {
        case 0:
            life.setPlot(index) { $0 = PlotState(state: 1, changed: now) }
            message = Double.random(in: 0..<1) < 0.1 ? "石頭好多，翻好了土" : "翻好了土"
        case 1:
            let season = scene.season
            // what suits the season: greens in spring and autumn, wheat and pumpkins in summer
            let roll = Double.random(in: 0..<1)
            let crop: Int
            switch season {
            case .spring: crop = roll < 0.6 ? 2 : 0
            case .summer: crop = roll < 0.4 ? 1 : roll < 0.8 ? 0 : 2
            default: crop = roll < 0.7 ? 2 : 0
            }
            let thin = Double.random(in: 0..<1) < 0.12
            life.setPlot(index) { $0 = PlotState(state: 2, crop: crop, density: thin ? Int.random(in: 3...4) : Int.random(in: 5...8), changed: now, progress: 0, pace: Double.random(in: 0.8...1.3)) }
            message = thin ? "種子撒得稀稀的" : "播下了種子"
        case 3:
            if life.state.plots[index].state == 3, Double.random(in: 0..<1) < 0.8 {
                life.setPlot(index) { $0.progress += Double.random(in: 1...3) * 3600 }
                message = "澆了水"
            }
        default:
            guard life.state.plots[index].state == 4 else { return }
            let plot = life.state.plots[index]
            var yield = plot.density / 2 + Int.random(in: 0...2) + (ants[ant].traits.personality == .calm ? 1 : 0)
            var giant = false
            if plot.crop == 1, Double.random(in: 0..<1) < 0.05 { yield *= 2; giant = true }
            yield = Int((Double(yield) * (1 + 0.3 * boost(.fish))).rounded())
            life.setPlot(index) { $0 = PlotState(state: 0, changed: now) }
            let room = Colony.larderLimit + 8 - larder["veg", default: 0]
            larder["veg", default: 0] += min(max(0, room), yield)
            if yield > room { foodDelivered += yield - max(0, room) }
            message = giant ? "超大的南瓜！收成 +\(yield)" : "收成 +\(yield)"
        }
        if !message.isEmpty { addFloater(message, message.contains("超大") ? .rare : .common, at: spot) }
        resourceTimer = 0
        onAntsChanged?()
    }

    // MARK: Working the land (felling and mining)

    /// The trees and rocks that may be worked, refreshed every couple of seconds.
    private var resourceCache: [TerrainScene.ResourceSpot] = []
    private var resourceTimer = 0.0

    /// A goblin has finished at a tree or a rock. What comes of it is a matter of chance: a tree may fall, give only some branches, or turn
    /// out too hard; a rock may give iron, nothing but rubble, or one big chunk; now and then there is a bees' nest or a shard of crystal,
    /// and now and then somebody gets hurt. Trees are never felled below six standing, so the place never goes bare.
    private func finishGathering(kind: Int, id: Int, foot: CGPoint, by index: Int) {
        guard let scene, let life, let spot = scene.resourceSpots().first(where: { $0.id == id }) else { return } // somebody got there first
        let strong = ants[index].traits.might >= 1.3
        var items: [(id: String, count: Int)] = []
        var message = ""
        if kind == 0, Characters.current.rules.fellsTrees == false {
            // a race that never fells a tree (the elves): what has fallen, and what grows on it
            let roll = Double.random(in: 0..<1)
            if roll < 0.45 {
                items.append(("scrap_wood", Int.random(in: 1...2)))
                message = "撿了掉下的樹枝"
            } else if roll < 0.8, !foods.contains(where: { hypot($0.pos.x - foot.x, $0.pos.y - foot.y) < 40 }) {
                var berries = FoodSource(id: nextFoodID, kind: .berries, pos: nearestWalkable(to: CGPoint(x: foot.x + 12, y: foot.y - 10)), amount: 4)
                berries.capacityOverride = 4
                berries.scouted = true
                berries.reported = true
                foods.append(berries)
                nextFoodID += 1
                message = "採了一籃野莓"
            } else {
                message = "照顧了這棵樹"
            }
        } else if kind == 0 {
            let trees = scene.resourceSpots().filter { $0.kind == .tree }.count
            let roll = Double.random(in: 0..<1)
            // the fewer trees are left, the less likely one falls (and never below six)
            let floor = scene.isStrip ? 1 : 6 // (a strip has few: it may run low, and new logs turn up)
            let plenty = min(1, Double(trees - floor) / (scene.isStrip ? 3 : 8))
            if roll < (strong ? 0.68 : 0.58) * plenty, trees > floor {
                items.append(("scrap_wood", Int.random(in: 3...6) + (strong ? 1 : 0)))
                message = "砍倒了一棵樹"
                if spot.planted { life.fellPlanting(nearFraction: scene.fraction(spot.foot)) } else { life.cut(kind: 0, at: scene.fraction(spot.foot)) }
            } else if roll < 0.9 {
                items.append(("scrap_wood", Int.random(in: 1...2)))
                message = "砍下了一些樹枝"
            } else {
                message = "木頭太硬，砍不動"
            }
            if Double.random(in: 0..<1) < 0.05, !foods.contains(where: { hypot($0.pos.x - foot.x, $0.pos.y - foot.y) < 40 }) { // a bees' nest
                var honey = FoodSource(id: nextFoodID, kind: .honey, pos: nearestWalkable(to: CGPoint(x: foot.x + 14, y: foot.y - 10)), amount: 8)
                honey.capacityOverride = 8
                honey.scouted = true
                honey.reported = true
                foods.append(honey)
                nextFoodID += 1
                message = "找到蜂巢了！"
            }
        } else {
            let roll = Double.random(in: 0..<1)
            if roll < 0.68 {
                items.append(("scrap_iron", Int.random(in: 1...3)))
                message = "敲下了一些鐵"
                if Double.random(in: 0..<1) < 0.55 { life.cut(kind: 1, at: scene.fraction(spot.foot)) } // the rock shrinks
            } else if roll < 0.9 {
                message = "只有碎石"
            } else {
                items.append(("scrap_iron", Int.random(in: 3...5)))
                message = "敲下了一大塊！"
                life.cut(kind: 1, at: scene.fraction(spot.foot))
            }
            if Double.random(in: 0..<1) < Materials.finds[0].chance {
                items.append((Materials.finds[0].id, 1))
                message = "挖到晶石了！"
            }
        }
        if !items.isEmpty { dropLoot(items, at: foot) }
        if !message.isEmpty { addFloater(message, message.contains("晶") || message.contains("蜂") ? .rare : .common, at: foot) }
        if Double.random(in: 0..<1) < 0.02 { hurt(ant: index) } // a blow on the wrong thing, a stone rolling
        resourceTimer = 0
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
            // (elves do not brawl)
            let fighters = Characters.current.id == "elf" ? [] : idle.filter { ants[$0].traits.personality != .calm && ants[$0].traits.personality != .boss }
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
        /// The camp follows the books: sent to the server, which makes it and says who got it.
        case sent(gear: Gear)
    }

    func canAfford(_ gear: Gear) -> Bool { gear.cost.allSatisfy { materials[$0.0, default: 0] >= $0.1 } }

    /// How many goblins wear this piece now.
    func wearers(of gear: Gear) -> Int { ants.filter { $0.gear[gear.slot.rawValue] == gear.id }.count }

    /// Makes a piece of gear from the stored materials and gives it to the goblin who gains most from it (see `neediest`).
    func craft(_ gear: Gear) -> CraftResult {
        guard canAfford(gear) else { return .missing }
        if followsBooks {
            onBookCommand?(.craft(gear.id))
            return .sent(gear: gear)
        }
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

    // MARK: Repairs

    /// A piece that needs mending: worn by a goblin, or in the stock.
    struct RepairJob {
        enum Place { case worn(antID: Int, slot: GearSlot), stock(index: Int) }
        let place: Place
        let item: GearItem
        let owner: String
        var gear: Gear { item.gear! }
    }

    /// What it costs to mend a piece: a third of what it was made from (rounded up, at least one of each).
    static func repairCost(_ gear: Gear) -> [(String, Int)] { gear.cost.map { ($0.0, max(1, Int((Double($0.1) / 3).rounded(.up)))) } }

    func canAffordRepair(_ gear: Gear) -> Bool { Colony.repairCost(gear).allSatisfy { materials[$0.0, default: 0] >= $0.1 } }

    /// The pieces below three quarters, worst first.
    func repairJobs() -> [RepairJob] {
        var jobs: [RepairJob] = []
        for ant in ants where !ant.isDying {
            for slot in GearSlot.allCases {
                if let item = ant.item(in: slot), item.gear != nil, item.fraction < 0.75 { jobs.append(RepairJob(place: .worn(antID: ant.id, slot: slot), item: item, owner: ant.name)) }
            }
        }
        for (i, item) in armory.enumerated() where item.gear != nil && item.fraction < 0.75 { jobs.append(RepairJob(place: .stock(index: i), item: item, owner: "庫存")) }
        return jobs.sorted { $0.item.fraction < $1.item.fraction }
    }

    /// Mends a piece for its materials: it is as good as new again.
    @discardableResult
    func repair(_ job: RepairJob) -> Bool {
        guard canAffordRepair(job.gear) else { return false }
        if followsBooks {
            switch job.place {
            case .worn(let id, let slot): onBookCommand?(.repair(resident: id, slot: slot.rawValue, stock: nil))
            case .stock(let index): onBookCommand?(.repair(resident: nil, slot: nil, stock: index))
            }
            return true
        }
        for (id, count) in Colony.repairCost(job.gear) {
            materials[id, default: 0] -= count
            if materials[id] == 0 { materials[id] = nil }
        }
        switch job.place {
        case .worn(let id, let slot):
            guard let i = ants.firstIndex(where: { $0.id == id }), var item = ants[i].item(in: slot) else { return false }
            item.left = job.gear.durability
            _ = ants[i].equip(item)
        case .stock(let index):
            guard armory.indices.contains(index) else { return false }
            armory[index].left = job.gear.durability
        }
        onAntsChanged?()
        return true
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

    /// Test aid: every worn piece is left with this fraction of its durability.
    func debugWear(fraction: Double) {
        for i in ants.indices {
            for slot in GearSlot.allCases { if let item = ants[i].item(in: slot), let g = item.gear { ants[i].gearLeft[slot.rawValue] = g.durability * fraction } }
        }
    }

    func debugStock(_ items: [String: Int]) { for (k, v) in items { larder[k, default: 0] += v } }
    /// Test aid: puts a food down at a spot (no picking, no waiting).
    func debugPlaceFood(_ kind: FoodKind, at point: CGPoint) {
        foods.append(FoodSource(id: nextFoodID, kind: kind, pos: isWalkable(point) ? point : nearestWalkable(to: point), amount: kind.initialAmount))
        nextFoodID += 1
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
        playSeconds = saved.playSeconds ?? 0
        romance = saved.romance ?? RomanceState()
        larder = saved.larder ?? [:]
        boosts = Colony.kinds(saved.boosts)
        foodCooldowns = Colony.kinds(saved.foodCooldowns)
        savedLives = saved.terrains ?? [:]
        if savedLives["window"] == nil, let older = saved.terrain { savedLives["window"] = older } // (saves from before there were strips)
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
                ant.parents = g.parents ?? ""
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
                                                    gear: savedGear(of: $0), parents: $0.parents.isEmpty ? nil : $0.parents) },
                          delivered: foodDelivered, nextID: nextAntID, princessName: princessName.isEmpty ? nil : princessName,
                          materials: materials.isEmpty ? nil : materials, kills: kills.isEmpty ? nil : kills, peak: peakAnts, playSeconds: playSeconds, larder: larder.isEmpty ? nil : larder, terrain: allLives["window"], terrains: allLives.isEmpty ? nil : allLives, armoryItems: armory.isEmpty ? nil : armory.map { SavedGear(id: $0.id, left: $0.left) },
                          romance: romance, boosts: boosts.isEmpty ? nil : Colony.names(boosts),
                          foodCooldowns: foodCooldowns.isEmpty ? nil : Colony.names(foodCooldowns), race: Characters.current.id)
    }

    private func savedGear(of ant: Ant) -> [String: SavedGear]? {
        var result: [String: SavedGear] = [:]
        for slot in GearSlot.allCases { if let item = ant.item(in: slot) { result[slot.rawValue] = SavedGear(id: item.id, left: item.left) } }
        return result.isEmpty ? nil : result
    }

    /// Births and restores both go through here so every individual gets its traits the same way.
    func makeAnt(at pos: CGPoint, breedIndex: Int? = nil, age: Double = 0, seed: UInt64? = nil, id: Int? = nil, name: String? = nil) -> Ant {
        let breeds = self.breeds
        let index = min(breedIndex ?? Breeding.roll(from: breeds, delivered: foodDelivered, luck: boost(.mushroom)), breeds.count - 1)
        var seed = seed ?? UInt64.random(in: 0...UInt64(UInt32.max))
        if id == nil { // a birth: try for a name nobody living has yet (a restored goblin keeps its seed and so its name)
            let taken = Set(ants.map(\.name))
            var tries = 0
            while taken.contains(Names.resident(seed: seed)), tries < 40 {
                seed = UInt64.random(in: 0...UInt64(UInt32.max))
                tries += 1
            }
        }
        let traits = Traits.make(for: breeds[index], seed: seed)
        var ant = Ant(at: pos, id: id ?? nextAntID, breedIndex: index, traits: traits, seed: seed, age: age, name: name)
        ant.ageless = followsBooks
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
    func relocate(into rect: CGRect, at spot: CGPoint? = nil) {
        walkable = [rect]
        guard let old = nest else { return }
        let centre = spot ?? CGPoint(x: rect.midX, y: rect.midY)
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
        for i in ants.indices {
            if ants[i].activitySpot != nil { ants[i].mode = .wandering }
            if case .huntNews = ants[i].mode { ants[i].mode = .wandering }
            if case .hunting = ants[i].mode { ants[i].mode = .wandering }
        }
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
        dropStrandedWork()
        onAntsChanged?() // saves the (possibly moved) nest
    }

    /// After the range changed: goblins working somewhere that is outside it (a pond, a tree, the fire, a field of the camp window) go back to
    /// wandering instead of walking off across the screen to it, and animals left outside are gone.
    private func dropStrandedWork() {
        for i in ants.indices {
            if let spot = ants[i].activitySpot, !isWalkable(spot) { ants[i].mode = .wandering }
            if case .huntNews = ants[i].mode { ants[i].mode = .wandering }
            if case .hunting = ants[i].mode { ants[i].mode = .wandering }
        }
        creatures.removeAll { !isWalkable($0.pos) }
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
        let boosted = boosts.sorted { $0.key.rawValue < $1.key.rawValue }.map { "\($0.key.rawValue):\(Int($0.value))s" }.joined(separator: ",")
        return "ants=\(ants.count) inNest=\(hidden) foods=[\(amounts)] foragers=\(working) delivered=\(foodDelivered) boosts=[\(boosted)]"
    }

    private func clearDecorations() {
        eggs = []
    }

    /// The player renamed a goblin (empty puts back the name it was born with).
    func rename(antID: Int, to text: String) {
        guard let i = ants.firstIndex(where: { $0.id == antID }) else { return }
        let name = Names.clean(text)
        ants[i].name = name.isEmpty ? Names.resident(seed: ants[i].seed) : name
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
                                  outfit: outfits.isEmpty ? "" : outfits[min(outfitIndex, outfits.count - 1)].id, danger: princessInDanger,
                                  pregnant: romance.pregnancy != nil)
        if let event = queen?.update(dt: dt, walkable: walkable, around: around) {
            switch event {
            case .outfitChange(let wanted):
                let outfits = Characters.current.outfits
                if romance.pregnancy != nil {
                    // expecting: she keeps the maternity dress (the twirl was only for show)
                } else if let wanted, let index = outfits.firstIndex(where: { $0.id == wanted }) {
                    outfitIndex = index
                } else if outfits.count > 1 {
                    // always a different one (and never a maternity dress when she is not expecting)
                    let others = outfits.indices.filter { $0 != outfitIndex && !outfits[$0].id.hasPrefix("maternity") }
                    if let pick = others.randomElement() { outfitIndex = pick }
                }
            case .layEgg:
                // she plants a flower next to her feet
                if let queen { eggs.append(Egg(pos: CGPoint(x: queen.pos.x + [-14, 14].randomElement()!, y: queen.pos.y - 7))) }
            }
        }
        for i in eggs.indices { eggs[i].age += dt }
        eggs.removeAll { $0.age >= Egg.lifetime }

        // The clock only starts once the queen has crawled out.
        if !followsBooks, queen?.arrived == true, ants.count < settings.maxAnts {
            spawnTimer += dt * (1 + boost(.honey) / 3) // honey: a quarter less waiting
            if spawnTimer >= settings.spawnInterval * (Characters.current.rules.spawnScale ?? 1) { // (elves come half as often)
                spawnTimer = 0
                let jitter = { CGFloat.random(in: -4...4) }
                var born = makeAnt(at: CGPoint(x: nest.x + jitter(), y: nest.y + jitter()), breedIndex: lineageBreed())
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
        world.ponds = scene?.visiblePonds ?? []
        world.crowd = Double(visibleCount) / Double(visibleCap)
        world.night = Colony.isNight
        world.pit = peakAnts >= 5 && fire == nil ? scene?.firePit : nil
        world.tents = entranceCache
        world.race = Characters.current.id
        world.graves = graves
        let cooking = ants.contains { if case .activity(.cook, _) = $0.mode { return true } else { return false } }
        world.cookSlots = larderTotal >= 2 && !cooking ? 1 : 0
        resourceTimer -= dt
        if resourceTimer <= 0 {
            resourceTimer = 2
            resourceCache = scene?.resourceSpots() ?? []
            entranceCache = (scene?.tentEntrances() ?? []).filter { p in walkable.contains { $0.contains(p) } }
            plotCache = scene?.plotInfos() ?? []
        }
        var minded = Set<Int>()
        for ant in ants { if case .activity(.mind(let child), _) = ant.mode { minded.insert(child) } }
        var childInfo: [Int: (pos: CGPoint, sick: Bool)] = [:]
        for ant in ants where ant.isChild && !ant.isHidden { childInfo[ant.id] = (ant.pos, ant.sick > 0) }
        if !childInfo.isEmpty {
            world.children = childInfo
            world.unminded = Set(childInfo.keys).subtracting(minded)
        }
        var busyPlots = Set<Int>()
        for ant in ants { if case .activity(.farm(let plot, _, _, _), _) = ant.mode { busyPlots.insert(plot) } }
        if !plotCache.isEmpty {
            world.plots = plotCache.filter { !busyPlots.contains($0.index) }
            world.farmSlots = max(0, max(1, ants.count / 30) - busyPlots.count)
            world.canSow = scene?.season != .winter
        }
        let working = Set(ants.compactMap { ant -> Int? in
            if case .activity(.gather(_, _, _, let id, _), _) = ant.mode { return id }
            return nil
        })
        if !working.isEmpty || !resourceCache.isEmpty {
            world.resources = resourceCache.filter { !working.contains($0.id) }
            world.gatherSlots = peakAnts >= 12 ? max(0, max(1, ants.count / 25) - working.count) : 0 // (a tiny camp has no time for it)
        }
        world.activitiesOn = !isRaining && fire == nil && world.crowd < 1.2
        updateRomance(dt: dt, world: &world)
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
        world.healRate = (tending ? 0.4 : 0.05) * (1 + 0.5 * boost(.water))
        let raceRules = Characters.current.rules
        world.speedBoost = (1 + 0.15 * boost(.carrot)) * (Colony.isNight ? raceRules.nightSpeed ?? 1 : raceRules.daySpeed ?? 1)
        world.workBoost = 1 + 0.3 * boost(.bread)
        world.fishBoost = 1 + 0.3 * boost(.fish)
        world.rangedReach = Characters.current.rules.ranged ?? 0
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
        if followsBooks { finishRaidIfOver() }
        updateTerrainLife(dt: dt)
        updateChildren(dt: dt)
        updateBoosts(dt: dt)
        updateSouls(dt: dt)
        playSeconds += dt * Colony.wildScale * settings.pace
        // the dead leave the colony (highest index first so the others keep their places)
        let gone = events.filter { if case .died = $0.event { return true } else { return false } }.map(\.index)
        // (those who walked off into the big world take what they wear with them, and are not dead)
        let left = events.filter { if case .departed = $0.event { return true } else { return false } }.map(\.index)
        for index in (gone + left).sorted(by: >) {
            if ants[index].id == selectedAntID { selectedAntID = nil }
            if gone.contains(index) { returnGear(of: index) } // old age or killed in a fight: what it wore comes back to the nest
            ants.remove(at: index)
        }
        if !left.isEmpty, gone.isEmpty { onAntsChanged?() }
        if !gone.isEmpty, !armory.isEmpty { redistributeArmory() }
        deaths += gone.count
        if !gone.isEmpty { onAntsChanged?() }
    }
}

// MARK: Following the server's books (server/CAMP.md §7, stage C2)

/// One resident as the books have it.
struct BookResident {
    let id: Int
    let breed: String
    let seed: UInt64
    let name: String?
    let parents: String?
    /// How far through its life it is (0…1; nil: it never ages, the undead).
    let lifeShare: Double?
    let gear: [String: GearItem]
}

/// A player's action the server does when the camp follows the books (shared/src/camp/api.ts `campCommand`).
enum BookCommand {
    case craft(String)
    case repair(resident: Int?, slot: String?, stock: Int?)
    case food(String)
    case princessName(String)
    case story(RomanceState)
}

/// What the camp owns, as the books have it.
struct BookStores {
    let materials: [String: Int]
    let kills: [String: Int]
    let larder: [String: Int]
    let armory: [GearItem]
    let peak: Int
    let delivered: Int
    /// Food boosts and cooldowns: seconds left, by food id.
    let boosts: [String: Double]
    let cooldowns: [String: Double]
    /// The farm's level (server/FARM.md), drawn round the plots.
    var farmLevel = 1
    var race = "goblin"
    /// The camp's other sites (server/FARM.md §11), drawn round the camp.
    var sites: [(id: Int, kind: String, level: Int)] = []
}

extension Colony {
    /// Whether the camp follows the server's books: no births or deaths of its own (see `applyBooks`).
    var followsBooks: Bool {
        get { booksDriven }
        set {
            booksDriven = newValue
            for i in ants.indices { ants[i].ageless = newValue }
        }
    }

    /// Brings the camp in line with the books: newcomers walk out of the camp, those the books no longer have die where
    /// they stand, and everyone wears what the books say. What the camp owns is the books' too.
    func applyBooks(_ residents: [BookResident], stores: BookStores, away: Set<Int> = []) {
        guard let nest else { return }
        let wanted = Set(residents.map(\.id))
        var changed = false
        for i in ants.indices where !wanted.contains(ants[i].id) && !ants[i].isDying && !ants[i].isDeparting && !doomed.contains(ants[i].id) {
            if away.contains(ants[i].id) { // gone out into the big world: it walks off (out of the nest first if it was inside)
                if ants[i].isHidden { ants[i].pos = nest }
                ants[i].mode = .departing(target: edgePoint(from: ants[i].pos))
                awayIDs.insert(ants[i].id)
                changed = true
                continue
            }
            ants[i].ageless = false
            if ants[i].isHidden { ants[i].age = ants[i].traits.lifespan } else { ants[i].mode = .dying(remaining: Ant.dyingTime) }
            changed = true
        }
        let have = Set(ants.map(\.id))
        let breeds = self.breeds
        for r in residents where !have.contains(r.id) {
            let index = breeds.firstIndex { $0.id == r.breed } ?? 0
            let jitter = { CGFloat.random(in: -4...4) }
            // back from the big world: it walks in from the edge; anyone else is new, born at the nest
            let back = awayIDs.remove(r.id) != nil
            let start = back ? edgePoint(from: CGPoint(x: nest.x + jitter() * 40, y: nest.y + jitter() * 20)) : CGPoint(x: nest.x + jitter(), y: nest.y + jitter())
            var born = makeAnt(at: start, breedIndex: index, age: 0, seed: r.seed, id: r.id, name: r.name)
            if let share = r.lifeShare { born.age = share * born.traits.lifespan }
            born.parents = r.parents ?? ""
            if back { born.mode = .returningToNest } else if visibleCount >= visibleCap { born.mode = .inNest(remaining: Double.random(in: 25...60), thenForage: nil) }
            ants.append(born)
            nextAntID = max(nextAntID, r.id + 1)
            changed = true
        }
        // what everyone wears
        let byID = Dictionary(uniqueKeysWithValues: residents.map { ($0.id, $0) })
        for i in ants.indices {
            guard let r = byID[ants[i].id] else { continue }
            for slot in GearSlot.allCases {
                let want = r.gear[slot.rawValue]
                let now = ants[i].item(in: slot)
                if want?.id == now?.id, want?.left == now?.left { continue }
                _ = ants[i].takeOff(slot)
                if let want, want.gear != nil { _ = ants[i].equip(want) }
                changed = true
            }
        }
        materials = stores.materials
        kills = stores.kills
        larder = stores.larder
        armory = stores.armory.filter { $0.gear != nil }
        foodDelivered = stores.delivered
        boosts = Colony.kinds(stores.boosts)
        foodCooldowns = Colony.kinds(stores.cooldowns)
        farmLevel = stores.farmLevel
        farmRace = stores.race
        sites = stores.sites
        if stores.peak > peakAnts {
            peakAnts = stores.peak
            if let scene {
                scene.growth = peakAnts
                if scene.stage != sceneStage {
                    sceneStage = scene.stage
                    obstacles = scene.obstacles
                }
            }
        }
        if changed { onAntsChanged?() }
    }
}

// MARK: Raids from the books (server/CAMP.md §3.2, stage C3)

extension Colony {
    /// Plays a raid the server fought: its monsters walk in and fight, those the books say fell die in it, and when it is
    /// over (every monster down, or two and a half minutes) the rest of the fallen go down and the monsters left walk off.
    func playRaid(monsters: [(id: String, count: Int)], fallen: Set<Int>) {
        let before = creatures.count
        for (id, count) in monsters {
            guard let kind = Animals.all.first(where: { $0.id == id }) else { continue }
            for _ in 0..<count { spawnAnimal(of: kind) }
        }
        for i in before..<creatures.count { // a raid comes all at once, spread out a little, and heads for the camp
            creatures[i].pos.x += CGFloat.random(in: -22...22)
            creatures[i].pos.y += CGFloat.random(in: -22...22)
            creatures[i].stay = Double.random(in: 200...320)
        }
        doomed.formUnion(fallen.filter { id in ants.contains { $0.id == id } })
        raidPlaying = (Date().timeIntervalSinceReferenceDate, Set(creatures[before...].map(\.id)))
        if ProcessInfo.processInfo.environment["CAMP_DEBUG"] != nil { NSLog("GoblinCamp: raid: \(creatures.count - before) monsters, \(doomed.count) will fall") }
    }

    /// Ends a raid being played once its monsters are gone or after two and a half minutes (slimes are slow). Call every frame.
    func finishRaidIfOver() {
        guard let raid = raidPlaying else { return }
        let left = creatures.indices.filter { raid.monsters.contains(creatures[$0].id) }
        guard left.isEmpty || Date().timeIntervalSinceReferenceDate - raid.began > 150 else { return }
        for i in left { creatures[i].stay = 0 } // the rest walk off
        for i in ants.indices where doomed.contains(ants[i].id) && !ants[i].isDying {
            ants[i].ageless = false
            ants[i].mode = .dying(remaining: Ant.dyingTime)
        }
        if ProcessInfo.processInfo.environment["CAMP_DEBUG"] != nil {
            NSLog("GoblinCamp: raid over: \(left.count) monsters walked off, fell at the end \(doomed.sorted()), dying now \(ants.filter(\.isDying).map(\.id).sorted())")
        }
        doomed = []
        raidPlaying = nil
        onAntsChanged?()
    }

    /// Floating words over the camp (what a raid left, and the like).
    func announce(_ text: String) {
        guard let nest else { return }
        addFloater(text, .uncommon, at: nest)
    }
}
