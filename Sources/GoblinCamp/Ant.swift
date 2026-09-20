import CoreGraphics
import Foundation

/// One ant. Position is in global screen coordinates; heading in radians (0 = +x).
///
/// Ants wander at random and only notice food they happen to bump into. A finder walks straight home with the
/// news, nestmates then set out along (roughly) the same line, ring the food, and carry pieces back one by one.
/// Every so often an ant heads home to rest inside the nest for a while.
struct Ant {
    /// What a goblin does when it has nothing else to do.
    enum Activity: Equatable {
        case sleep
        /// Fishing from `spot` on the bank, casting toward `water`.
        case fish(spot: CGPoint, water: CGPoint)
        case play
        case read
        /// A friendly scuffle (no harm done) with another goblin.
        case scuffle(partner: Int)
        /// A golden goblin walking about, waited on.
        case stroll
        /// Waiting on a golden goblin, keeping `offset` away from it.
        case serve(boss: Int, offset: CGPoint)
        /// Minding a young one (`child` is its id): standing by it, feeding it and patting it.
        case mind(child: Int)
        /// Working a plot: `action` 0 tilling, 1 sowing, 2 harvesting, 3 watering.
        case farm(plot: Int, action: Int, spot: CGPoint, face: CGPoint)
        /// Cooking at the fire ring: standing at `spot`, stirring the pot at `pot`.
        case cook(spot: CGPoint, pot: CGPoint)
        /// Felling a tree (0) or mining a rock (1) at `face`, standing at `spot`; `hitsLeft` more blows to go.
        case gather(kind: Int, spot: CGPoint, face: CGPoint, id: Int, hitsLeft: Int)

        var label: String {
            switch self {
            case .sleep: return "睡覺"
            case .fish: return "釣魚"
            case .play: return "玩耍"
            case .read: return "看書"
            case .scuffle: return "打鬧"
            case .stroll: return "巡視（有人伺候）"
            case .serve: return "伺候金皮"
            case .gather(let kind, _, _, _, _): return kind == 0 ? "砍樹" : "採石"
            case .cook: return "煮飯"
            case .mind: return "照顧小哥布林"
            case .farm(_, let action, _, _): return "耕田：" + ["翻土", "播種", "收成", "澆水"][min(3, action)]
            }
        }
    }

    enum Mode {
        /// Spending its spare time: sleeping, fishing, playing, reading, scuffling, or waiting on a golden goblin.
        case activity(Activity, remaining: Double)
        case wandering
        /// Walking home to rest.
        case returningToNest
        /// Hidden inside the nest. Comes out after `remaining` seconds, straight to the food if `thenForage` is set.
        case inNest(remaining: Double, thenForage: Int?)
        /// Found food; hurrying home to tell the others.
        case carryingNews(food: Int)
        /// Heading for a spot on the rim of the food (`slot` is the angle around it).
        case foraging(food: Int, slot: Double)
        /// Standing on the rim, about to pick up a piece.
        case feeding(food: Int, slot: Double, remaining: Double)
        /// Carrying pieces home, slowly.
        case hauling(food: Int, kind: FoodKind, pieces: Int)
        /// Died of old age: stands still and fades away.
        case dying(remaining: Double)
        /// Found an animal; hurrying home to tell the others.
        case huntNews(creature: Int)
        /// Chasing an animal and hitting it every second or so.
        case hunting(creature: Int, cooldown: Double)
        /// Hidden in the nest until it is time to go and hunt.
        case inNestForHunt(remaining: Double, creature: Int)
        /// One of the two carrying the princess into the camp, walking to `target`.
        case carryingPrincess(target: CGPoint)
        /// Arrived with the princess; waiting until the other carrier gets there too.
        case waitingWithPrincess
    }

    /// Things the colony has to react to.
    enum Event {
        case foundFood(Int)
        case newsDelivered(Int)
        case tookPiece(Int)
        case delivered(Int, pieces: Int)
        case died
        case carrierArrived
        case foundCreature(Int)
        case huntNewsDelivered(Int)
        case attack(Int)
        case caughtFish
        /// Finished cooking at the pot at this point.
        case cooked(pot: CGPoint)
        /// Finished minding a young one.
        case tended(child: Int)
        /// Finished an action at a farm plot.
        case farmed(plot: Int, action: Int)
        /// Finished felling (kind 0) or mining (1) the thing at `foot`, after `hits` blows.
        case gathered(kind: Int, id: Int, foot: CGPoint, hits: Int)
    }

    /// How fast the two carriers walk the princess in, in points per second.
    static let carrySpeed = 50.0
    /// How long the fade-out after death takes, in seconds.
    static let dyingTime = 2.5
    /// The last stretch of a life (as a fraction) is spent slower.
    static let elderStart = 0.9

    /// Stable identity, so the roster and the selection ring can follow one individual.
    let id: Int
    let breedIndex: Int
    /// Seeds this individual's personal variation (see `Traits.make`); saved so it comes back the same.
    let seed: UInt64
    let traits: Traits
    /// Seconds lived.
    var age: Double
    /// What it is doing with its spare time, if anything.
    var activity: Activity? {
        if case .activity(let kind, _) = mode { return kind }
        return nil
    }
    /// Seconds a caught fish is still held up, time spent in the current activity, and (asleep) which way it lies and when it turns over next.
    var catchShow = 0.0
    var activityClock = 0.0
    var sleepFlip = false
    private var restless = Double.random(in: 6...20)
    private var biteTimer = Double.random(in: 4...9)
    private var scuffleTimer = 0.5
    private var gatherTimer = 0.8
    private var cookLeft = 20.0
    private var farmLeft = 12.0
    private var farmTimer = 0.6
    /// The blows struck at the current job (for its result and for the tool's animation).
    private(set) var gatherHits = 0

    /// A newborn is a small one for its first minutes: it plays near the nest, is minded by the grown ones, and takes no part in hunts or work.
    /// `CAMP_CHILD_MINUTES` changes how long (20).
    static var childSeconds: Double { (Double(ProcessInfo.processInfo.environment["CAMP_CHILD_MINUTES"] ?? "") ?? 20) * 60 / Settings.shared.pace }
    var isChild: Bool { age < Ant.childSeconds }
    /// `CAMP_CHILD_COLD_SCALE` makes the young catch colds more often (tests).
    static let childCatchScale = Double(ProcessInfo.processInfo.environment["CAMP_CHILD_COLD_SCALE"] ?? "") ?? 1
    /// Seconds it still has a cold (a young one may catch one; being minded usually cures it), and the same for how long it was last minded.
    var sick = 0.0
    private var mindTimer = 0.0

    /// Seconds left of the swing it makes when it hits something, and which way (the attack animation).
    static let swingTime = 0.32
    var swing = 0.0
    var swingHeading = 0.0
    /// What it wears, by slot (`GearSlot.rawValue` → `Gear.id`); made in the workshop.
    var gear: [String: String] = [:]
    /// How much wear each of those pieces has left (slot → `GearItem.left`).
    var gearLeft: [String: Double] = [:]
    /// Damage per hit, hits it can take and the chance to shrug off a monster's hit: the breed's numbers plus what it wears (a worn-out piece counts half).
    var might: Double { traits.might + wornGear.reduce(0) { $0 + $1.might * condition($1) } }
    var maxHealth: Double { traits.maxHealth + wornGear.reduce(0) { $0 + $1.health * condition($1) } }
    var blockChance: Double { min(0.6, wornGear.reduce(0) { $0 + $1.block * condition($1) }) }
    /// Walking speed bonus and hitting reach from what it wears.
    var gearSpeed: Double { max(0.7, 1 + wornGear.reduce(0) { $0 + $1.speed * condition($1) }) }
    var gearReach: Double { wornGear.reduce(0) { $0 + $1.reach } }

    func item(in slot: GearSlot) -> GearItem? {
        gear[slot.rawValue].map { GearItem(id: $0, left: gearLeft[slot.rawValue]) }
    }
    private func condition(_ gear: Gear) -> Double { item(in: gear.slot)?.isWorn == true ? 0.5 : 1 }

    /// Puts a piece on; what it wore in that slot is handed back.
    mutating func equip(_ item: GearItem) -> GearItem? {
        guard let slot = item.gear?.slot else { return nil }
        let old = self.item(in: slot)
        gear[slot.rawValue] = item.id
        gearLeft[slot.rawValue] = item.left
        return old
    }

    mutating func takeOff(_ slot: GearSlot) -> GearItem? {
        let old = item(in: slot)
        gear[slot.rawValue] = nil
        gearLeft[slot.rawValue] = nil
        return old
    }
    /// What it wears that counts: a shield is no use with a two-handed weapon in the hands.
    var wornGear: [Gear] {
        let all = gear.values.compactMap(Gears.by(id:))
        let twoHanded = all.contains { $0.slot == .weapon && $0.grip == .two }
        return twoHanded ? all.filter { $0.slot != .shield } : all
    }
    /// Hits it can still take; hunting animals that fight back wear it down. It heals slowly inside the nest.
    var health: Double
    var pos: CGPoint
    var heading: Double
    var speed: Double
    var mode: Mode = .wandering
    var pause: Double = 0
    /// Whether the legs moved during the last update (sprites stand still otherwise).
    private(set) var moving = false
    var legPhase: Double = Double.random(in: 0...(2 * .pi))
    private let wobblePhase = Double.random(in: 0...(2 * .pi))

    /// Its name: made from its seed, or what the player called it.
    var name: String

    init(at pos: CGPoint, id: Int, breedIndex: Int, traits: Traits, seed: UInt64, age: Double = 0, name: String? = nil) {
        self.id = id
        self.name = name ?? Names.goblin(seed: seed)
        self.breedIndex = breedIndex
        self.traits = traits
        self.seed = seed
        self.age = age
        health = traits.maxHealth
        self.pos = pos
        heading = Double.random(in: 0..<(2 * .pi))
        speed = Double.random(in: 15...40) * traits.speed
    }

    /// 0 at birth, 1 at the end of its life.
    var lifeFraction: Double { min(1, age / max(traits.lifespan, 1)) }

    /// Old ones walk slower.
    private var effectiveSpeed: Double { (lifeFraction > Ant.elderStart ? speed * 0.6 : speed) * gearSpeed * (isChild ? 0.85 : 1) * (sick > 0 ? 0.5 : 1) }

    var isCarryingPrincess: Bool {
        switch mode {
        case .carryingPrincess, .waitingWithPrincess: return true
        default: return false
        }
    }

    var isDying: Bool {
        if case .dying = mode { return true }
        return false
    }

    /// 1 while alive, fading to 0 as it dies.
    var fadeAlpha: Double {
        if case .dying(let remaining) = mode { return max(0, min(1, remaining / Ant.dyingTime)) }
        return 1
    }

    var isHidden: Bool {
        switch mode {
        case .inNest, .inNestForHunt: return true
        default: return false
        }
    }

    /// Badly hurt: it stays out of fights and limps home.
    var isWounded: Bool { health <= 1 && health < maxHealth }

    var isHunting: Bool {
        switch mode {
        case .hunting, .huntNews, .inNestForHunt: return true
        default: return false
        }
    }

    /// The food being carried, if any.
    var carrying: FoodKind? {
        if case .hauling(_, let kind, _) = mode { return kind }
        return nil
    }

    var carriedPieces: Int {
        if case .hauling(_, _, let pieces) = mode { return pieces }
        return 0
    }

    /// The food this ant is working on (on its way there, at it, or hauling from it).
    var targetFood: Int? {
        switch mode {
        case .foraging(let id, _), .feeding(let id, _, _), .hauling(let id, _, _): return id
        case .inNest(_, let id): return id
        default: return nil
        }
    }

    /// `ageDt` is real elapsed time (a life is counted in real time, whatever the speed setting).
    /// Which way it faces, with a little stickiness (see `SpriteDirection.init(heading:previous:)`).
    private(set) var facing = SpriteDirection.down
    /// Test aid: stand still facing a given way.
    mutating func debugPose(facing direction: SpriteDirection, swing progress: Double?) {
        facing = direction
        moving = false
        swing = progress.map { (1 - $0) * Ant.swingTime } ?? 0
        swingHeading = direction == .left ? .pi : direction == .up ? .pi / 2 : direction == .down ? -.pi / 2 : 0
    }

    mutating func update(dt: Double, ageDt: Double, world: AntWorld) -> Event? {
        facing = SpriteDirection(heading: heading, previous: facing)
        moving = false
        swing = max(0, swing - dt)
        catchShow = max(0, catchShow - dt)
        sick = max(0, sick - dt)
        age += ageDt
        if age >= traits.lifespan, !isDying, !isCarryingPrincess {
            if isHidden { return .died } // it went quietly in the nest
            mode = .dying(remaining: Ant.dyingTime)
        }
        switch mode {
        case .activity(let kind, let remaining):
            return updateActivity(kind, remaining: remaining, dt: dt, world: world)

        case .carryingPrincess(let target):
            // the two carriers walk in step, in a straight line, so the princess stays level between them
            let distance = hypot(target.x - pos.x, target.y - pos.y)
            heading = atan2(target.y - pos.y, target.x - pos.x)
            if distance < 2 {
                mode = .waitingWithPrincess
                return .carrierArrived
            }
            let step = min(Ant.carrySpeed * dt, distance)
            pos.x += cos(heading) * step
            pos.y += sin(heading) * step
            legPhase += step * 0.9
            moving = true
            return nil

        case .waitingWithPrincess:
            return nil

        case .dying(let remaining):
            let left = remaining - dt
            if left <= 0 { return .died }
            mode = .dying(remaining: left)
            return nil

        case .wandering:
            return updateWandering(dt: dt, world: world)

        case .returningToNest:
            if walkHome(dt: dt, world: world, speedFactor: 1.2) {
                mode = .inNest(remaining: Double.random(in: 10...35), thenForage: nil)
            }

        case .carryingNews(let id):
            if walkHome(dt: dt, world: world, speedFactor: 1.4) {
                mode = .inNest(remaining: Double.random(in: 2...4), thenForage: id) // she goes back with the others
                return .newsDelivered(id)
            }

        case .hauling(let id, _, let pieces):
            if walkHome(dt: dt, world: world, speedFactor: 0.7) {
                // Most ants rest a moment and go back for more while there is food left.
                let more = world.food(id) != nil && Double.random(in: 0..<1) < 0.85
                mode = .inNest(remaining: more ? Double.random(in: 3...8) : Double.random(in: 10...30), thenForage: more ? id : nil)
                return .delivered(id, pieces: pieces)
            }

        case .huntNews(let id):
            if walkHome(dt: dt, world: world, speedFactor: 1.4) {
                mode = .hunting(creature: id, cooldown: 0) // and straight back out with the others
                return .huntNewsDelivered(id)
            }

        case .inNestForHunt(let remaining, let id):
            health = min(maxHealth, health + dt * world.healRate)
            let left = remaining - dt
            if left > 0 {
                mode = .inNestForHunt(remaining: left, creature: id)
                return nil
            }
            pos = CGPoint(x: world.nest.x + CGFloat.random(in: -3...3), y: world.nest.y + CGFloat.random(in: -3...3))
            if world.creature(id) != nil { mode = .hunting(creature: id, cooldown: 0) } else { return giveUp() }

        case .hunting(let id, let cooldown):
            guard let target = world.creature(id) else { return giveUp() }
            let dx = target.pos.x - pos.x, dy = target.pos.y - pos.y, distance = hypot(dx, dy)
            heading = atan2(dy, dx)
            let reach = target.radius + 6 + gearReach
            if distance > reach { // run it down
                let step = min(effectiveSpeed * 1.3 * dt, distance - reach * 0.5)
                pos.x += cos(heading) * step
                pos.y += sin(heading) * step
                legPhase += step * 0.9
                moving = true
                mode = .hunting(creature: id, cooldown: max(0, cooldown - dt))
            } else if cooldown - dt <= 0 { // in reach: hit it
                mode = .hunting(creature: id, cooldown: Double.random(in: 0.8...1.2))
                return .attack(id)
            } else {
                mode = .hunting(creature: id, cooldown: cooldown - dt)
            }

        case .inNest(let remaining, let thenForage):
            health = min(maxHealth, health + dt * world.healRate)
            let left = remaining - dt
            if left > 0 {
                mode = .inNest(remaining: left, thenForage: thenForage)
                return nil
            }
            if world.crowded, thenForage == nil { // no room outside: stay in a while longer
                mode = .inNest(remaining: Double.random(in: 4...9), thenForage: nil)
                return nil
            }
            // step out of the hole
            pos = CGPoint(x: world.nest.x + CGFloat.random(in: -3...3), y: world.nest.y + CGFloat.random(in: -3...3))
            if let id = thenForage, let food = world.food(id) {
                mode = .foraging(food: id, slot: Double.random(in: 0..<(2 * .pi)))
                heading = atan2(food.pos.y - pos.y, food.pos.x - pos.x)
            } else {
                mode = .wandering
                heading = Double.random(in: 0..<(2 * .pi))
            }

        case .foraging(let id, let slot):
            guard let food = world.food(id) else { return giveUp() }
            let target = rimPoint(of: food, slot: slot, scale: world.foodScale)
            let distance = hypot(target.x - pos.x, target.y - pos.y)
            if distance < 2.5 {
                mode = .feeding(food: id, slot: slot, remaining: Double.random(in: 2...4))
                return nil
            }
            walk(toward: target, distance: distance, speed: effectiveSpeed * 1.15, dt: dt)

        case .feeding(let id, let slot, let remaining):
            guard let food = world.food(id) else { return giveUp() }
            turn(toward: atan2(food.pos.y - pos.y, food.pos.x - pos.x), rate: 4, dt: dt)
            // the food shrinks as it is eaten, so keep to its rim
            let target = rimPoint(of: food, slot: slot, scale: world.foodScale)
            let distance = hypot(target.x - pos.x, target.y - pos.y)
            if distance > 1 { walk(toward: target, distance: distance, speed: 8, dt: dt, turning: false) }
            let left = remaining - dt
            if left > 0 {
                mode = .feeding(food: id, slot: slot, remaining: left)
                return nil
            }
            mode = .hauling(food: id, kind: food.kind, pieces: traits.carry)
            heading = atan2(world.nest.y - pos.y, world.nest.x - pos.x)
            return .tookPiece(id)
        }
        return nil
    }

    // MARK: Wandering

    /// Something to do with its spare time, now and then: mostly sleep at night, play or fish by day, and each breed has its likes.
    private mutating func pickActivity(dt: Double, world: AntWorld) -> Activity? {
        if isChild { // the young ones do nothing but play and nap
            guard world.activitiesOn, Double.random(in: 0..<1) < dt / 22 else { return nil }
            return Double.random(in: 0..<1) < (world.night ? 0.8 : 0.3) ? .sleep : .play
        }
        guard world.activitiesOn, Double.random(in: 0..<1) < dt / 55 else { return nil }
        let personality = traits.personality
        var options: [(kind: Activity, weight: Double)] = []
        options.append((.sleep, world.night ? (personality == .boss ? 2 : 6) : 0.4))
        if !world.night {
            switch personality {
            case .boss: break // they are waited on instead (see the colony)
            case .calm:
                options.append((.read, 3.5))
                options.append((.play, 0.5))
            case .brute: options.append((.play, 0.8))
            case .lively: options.append((.play, 4))
            case .plain: options.append((.play, 2))
            }
            // work: felling trees and mining rocks (the strong ones most; the clever and the golden ones hardly at all)
            // cooking, most at meal times, by whoever likes it: the clever, then the plain
            // minding the young ones (most when one is ill)
            if let child = world.unminded.randomElement(), personality != .boss, let info = world.children[child] {
                let weight: Double
                switch personality {
                case .plain: weight = 1.5
                case .calm: weight = 1.0
                case .lively: weight = 0.8
                default: weight = 0.3
                }
                options.append((.mind(child: child), weight * (info.sick ? 4 : 0.8) * Ant.mindScale))
            }
            // farming: whatever the plot needs (till it, sow it in the right seasons, water what grows, gather what is ripe)
            if world.farmSlots > 0, personality != .boss, let plot = world.plots.randomElement() {
                var action: Int?
                switch plot.state {
                case 0, 5: action = 0
                case 1: action = world.canSow ? 1 : nil
                case 3: action = Double.random(in: 0..<1) < 0.35 ? 3 : nil
                case 4: action = 2
                default: action = nil
                }
                if let action {
                    var weight: Double
                    switch personality {
                    case .brute: weight = action == 0 ? 1.6 : 0.7
                    case .lively: weight = 0.3
                    case .calm: weight = 0.9
                    default: weight = 1.0
                    }
                    if action == 2 { weight *= 2 } // what is ripe is picked soon
                    options.append((.farm(plot: plot.index, action: action, spot: plot.standAt, face: plot.face), weight * Ant.farmScale))
                }
            }
            if world.cookSlots > 0, personality != .boss, let pit = world.pit {
                let hour = Calendar.current.component(.hour, from: Date())
                let mealTime = (11...13).contains(hour) || (17...19).contains(hour)
                let taste: Double = personality == .calm ? 2.2 : personality == .brute ? 0.8 : personality == .lively ? 0.5 : 1.5
                options.append((.cook(spot: CGPoint(x: pit.x, y: pit.y - 17), pot: pit), taste * (mealTime ? 3 : 0.6) * Ant.cookScale))
            }
            if world.gatherSlots > 0, personality != .boss, let spot = world.resources.randomElement() {
                let scale = Ant.gatherScale
                let tree = spot.kind == .tree
                let weight: Double
                switch personality {
                case .brute: weight = tree ? 2.4 : 3.0
                case .lively: weight = tree ? 0.5 : 0.3
                case .calm: weight = 0.3
                default: weight = tree ? 1.2 : 1.0
                }
                let hits = max(3, Int(Double.random(in: 6...12) / traits.might))
                let face = spot.foot
                options.append((.gather(kind: tree ? 0 : 1, spot: spot.standAt, face: CGPoint(x: face.x, y: face.y + 6), id: spot.id, hitsLeft: hits), weight * scale))
            }
            if personality != .boss, let spot = world.ponds.randomElement()?.fishingSpots.randomElement() {
                options.append((.fish(spot: spot.spot, water: spot.water), personality == .calm ? 2 : personality == .lively ? 0.4 : 0.8))
            }
        }
        var roll = Double.random(in: 0..<options.reduce(0) { $0 + $1.weight })
        for option in options {
            roll -= option.weight
            if roll < 0 { return option.kind }
        }
        return nil
    }

    /// `CAMP_MIND_SCALE` makes the grown ones mind the young more often (tests).
    static let mindScale = Double(ProcessInfo.processInfo.environment["CAMP_MIND_SCALE"] ?? "") ?? 1

    /// `CAMP_FARM_SCALE` makes goblins take up farming more often (tests).
    static let farmScale = Double(ProcessInfo.processInfo.environment["CAMP_FARM_SCALE"] ?? "") ?? 1

    /// `CAMP_COOK_SCALE` makes goblins take up cooking more often (tests).
    static let cookScale = Double(ProcessInfo.processInfo.environment["CAMP_COOK_SCALE"] ?? "") ?? 1

    /// `CAMP_GATHER_SCALE` makes goblins take up felling and mining more often (tests).
    static let gatherScale = Double(ProcessInfo.processInfo.environment["CAMP_GATHER_SCALE"] ?? "") ?? 1

    /// How long each kind of activity lasts, in seconds.
    private static func duration(of kind: Activity, night: Bool) -> Double {
        switch kind {
        case .sleep: return night ? Double.random(in: 40...90) : Double.random(in: 15...30)
        case .fish: return Double.random(in: 20...45)
        case .play: return Double.random(in: 8...16)
        case .read: return Double.random(in: 20...40)
        case .scuffle, .stroll, .serve: return Double.random(in: 8...20)
        case .gather: return 90 // (only a limit; it ends when the work is done)
        case .cook: return 200 // (a limit; see the cooking time below)
        case .farm: return 90
        case .mind: return 60
        }
    }

    /// One step of an activity. Anything that matters (a monster near, getting hurt) ends it.
    private mutating func updateActivity(_ activity: Activity, remaining: Double, dt: Double, world: AntWorld) -> Event? {
        var kind = activity
        activityClock += dt
        if isWounded || world.creatures.contains(where: { $0.hostile && hypot(pos.x - $0.pos.x, pos.y - $0.pos.y) < 150 }) { return giveUp() }
        var left = remaining - dt
        var event: Event?
        switch kind {
        case .sleep:
            // lying still costs next to nothing; it only turns over now and then
            health = min(maxHealth, health + dt * 0.08)
            restless -= dt
            if restless <= 0 {
                restless = Double.random(in: 9...22)
                sleepFlip.toggle()
            }
        case .fish(let spot, let water):
            let distance = hypot(spot.x - pos.x, spot.y - pos.y)
            if distance > 3 {
                walk(toward: spot, distance: distance, speed: effectiveSpeed * world.pace, dt: dt)
                left = remaining // the time only counts once it is sitting there
            } else {
                turn(toward: atan2(water.y - pos.y, water.x - pos.x), rate: 4, dt: dt)
                biteTimer -= dt
                if biteTimer <= 0 {
                    biteTimer = Double.random(in: 6...14)
                    if Double.random(in: 0..<1) < 0.5 {
                        catchShow = 1.8
                        event = .caughtFish
                    }
                }
            }
        case .play:
            heading += 5 * dt // spins about on the spot, hopping (see the drawing)
        case .read:
            heading = -Double.pi / 2
        case .scuffle(let partner):
            guard let other = world.partners[partner] else { return giveUp() }
            heading = atan2(other.y - pos.y, other.x - pos.x)
            scuffleTimer -= dt
            if scuffleTimer <= 0 {
                scuffleTimer = Double.random(in: 0.7...1.3)
                swing = Ant.swingTime
                swingHeading = heading
            }
        case .stroll:
            let result = updateWandering(dt: dt * 0.55, world: world, calm: true)
            guard case .activity = mode else { return result } // it noticed something and went for it
            event = result
        case .gather(let job, let spot, let face, let id, let hitsLeft):
            let distance = hypot(spot.x - pos.x, spot.y - pos.y)
            if distance > 3 {
                walk(toward: spot, distance: distance, speed: effectiveSpeed * world.pace, dt: dt)
                left = remaining // the time counts once it is at work
                gatherHits = 0
            } else {
                turn(toward: atan2(face.y - pos.y, face.x - pos.x), rate: 5, dt: dt)
                gatherTimer -= dt
                if gatherTimer <= 0 { // a blow, and a short rest before the next
                    gatherTimer = Double.random(in: 0.8...1.5)
                    swing = Ant.swingTime
                    swingHeading = atan2(face.y - pos.y, face.x - pos.x)
                    gatherHits += 1
                    if hitsLeft <= 1 {
                        let hits = gatherHits
                        mode = .wandering
                        heading = Double.random(in: 0..<(2 * .pi))
                        return .gathered(kind: job, id: id, foot: face, hits: hits)
                    }
                    kind = .gather(kind: job, spot: spot, face: face, id: id, hitsLeft: hitsLeft - 1)
                }
            }
        case .mind(let child):
            guard let target = world.children[child] else { return giveUp() }
            let distance = hypot(target.pos.x - pos.x, target.pos.y - pos.y)
            if distance > 16 {
                walk(toward: target.pos, distance: distance, speed: effectiveSpeed * world.pace * 1.1, dt: dt)
                left = remaining
                mindTimer = Double.random(in: 10...18)
            } else {
                turn(toward: atan2(target.pos.y - pos.y, target.pos.x - pos.x), rate: 5, dt: dt)
                mindTimer -= dt
                if mindTimer <= 0 {
                    mode = .wandering
                    heading = Double.random(in: 0..<(2 * .pi))
                    return .tended(child: child)
                }
            }
        case .farm(let plot, let action, let spot, let face):
            let distance = hypot(spot.x - pos.x, spot.y - pos.y)
            if distance > 3 {
                walk(toward: spot, distance: distance, speed: effectiveSpeed * world.pace, dt: dt)
                left = remaining
                farmLeft = [Double.random(in: 12...18), Double.random(in: 8...13), Double.random(in: 10...16), Double.random(in: 6...10)][min(3, action)]
            } else {
                turn(toward: atan2(face.y - pos.y, face.x - pos.x), rate: 5, dt: dt)
                farmLeft -= dt
                farmTimer -= dt
                if farmTimer <= 0 { // a swing of the hoe, a throw of seed, a pull at a plant (watering just pours)
                    farmTimer = action == 3 ? 5 : Double.random(in: 1.0...1.6)
                    if action != 3 { swing = Ant.swingTime; swingHeading = atan2(face.y - pos.y, face.x - pos.x) }
                }
                if farmLeft <= 0 {
                    mode = .wandering
                    heading = Double.random(in: 0..<(2 * .pi))
                    return .farmed(plot: plot, action: action)
                }
            }
        case .cook(let spot, let pot):
            let distance = hypot(spot.x - pos.x, spot.y - pos.y)
            if distance > 3 {
                walk(toward: spot, distance: distance, speed: effectiveSpeed * world.pace, dt: dt)
                left = remaining
                cookLeft = Double.random(in: 16...26)
            } else {
                turn(toward: atan2(pot.y - pos.y, pot.x - pos.x), rate: 5, dt: dt)
                cookLeft -= dt
                if cookLeft <= 0 {
                    mode = .wandering
                    heading = Double.random(in: 0..<(2 * .pi))
                    return .cooked(pot: pot)
                }
            }
        case .serve(let boss, let offset):
            guard let leader = world.bosses[boss] else { return giveUp() }
            // keep its place beside the boss, but never outside the range (the boss may be at the edge)
            var target = CGPoint(x: leader.x + offset.x, y: leader.y + offset.y)
            if let rect = world.walkable.first(where: { $0.contains(leader) }) ?? world.walkable.first {
                target = CGPoint(x: min(max(target.x, rect.minX + 10), rect.maxX - 10), y: min(max(target.y, rect.minY + 10), rect.maxY - 10))
            }
            let distance = hypot(target.x - pos.x, target.y - pos.y)
            if distance > 4 {
                walk(toward: target, distance: distance, speed: effectiveSpeed * 1.1, dt: dt)
            } else {
                turn(toward: atan2(leader.y - pos.y, leader.x - pos.x), rate: 4, dt: dt)
            }
        }
        if left <= 0 {
            mode = .wandering
            heading = Double.random(in: 0..<(2 * .pi))
            return event
        }
        mode = .activity(kind, remaining: left)
        return event
    }

    /// Starts an activity (the colony does this for scuffles and for the golden ones and those who wait on them).
    mutating func begin(_ kind: Activity, world: AntWorld, seconds: Double? = nil) {
        activityClock = 0
        mode = .activity(kind, remaining: seconds ?? Ant.duration(of: kind, night: world.night))
    }

    private mutating func updateWandering(dt: Double, world: AntWorld, calm: Bool = false) -> Event? {
        if isChild {
            // the young ones stay near the nest and run home from a monster; they neither forage nor hunt
            if world.creatures.contains(where: { $0.hostile && hypot(pos.x - $0.pos.x, pos.y - $0.pos.y) < 170 }) {
                mode = .returningToNest
                return nil
            }
            if hypot(pos.x - world.nest.x, pos.y - world.nest.y) > 150 { turn(toward: atan2(world.nest.y - pos.y, world.nest.x - pos.x), rate: 3, dt: dt) }
            if let kind = pickActivity(dt: dt, world: world) {
                begin(kind, world: world)
                return nil
            }
            return wanderStep(dt: dt, world: world)
        }
        return wanderCore(dt: dt, world: world, calm: calm)
    }

    private mutating func wanderCore(dt: Double, world: AntWorld, calm: Bool) -> Event? {
        // Notice food only by walking into it.
        if let food = world.foods.first(where: { $0.amount > 0 && hypot(pos.x - $0.pos.x, pos.y - $0.pos.y) < $0.senseRadius(scale: world.foodScale) * traits.sense }) {
            if food.scouted || food.reported {
                // others already know about it: just join in
                mode = .foraging(food: food.id, slot: atan2(pos.y - food.pos.y, pos.x - food.pos.x))
                return nil
            }
            mode = .carryingNews(food: food.id)
            heading = atan2(world.nest.y - pos.y, world.nest.x - pos.x)
            return .foundFood(food.id)
        }
        // Notice an animal only by walking into it (and not while hurt).
        if !isWounded, let animal = world.creatures.first(where: { hypot(pos.x - $0.pos.x, pos.y - $0.pos.y) < $0.radius + 20 * traits.sense }) {
            if animal.alerted {
                mode = .hunting(creature: animal.id, cooldown: 0) // the others know already: join in
                return nil
            }
            mode = .huntNews(creature: animal.id)
            heading = atan2(world.nest.y - pos.y, world.nest.x - pos.x)
            return .foundCreature(animal.id)
        }
        if !calm {
            // Now and then go home for a rest (a lot more often when the range is full).
            if Double.random(in: 0..<1) < dt / (world.raining ? 14 : (world.crowd > 1.5 ? 10 : (world.crowded ? 30 : 90))) * traits.rest {
                mode = .returningToNest
                return nil
            }
            if let kind = pickActivity(dt: dt, world: world) {
                begin(kind, world: world)
                return nil
            }
        }
        return wanderStep(dt: dt, world: world)
    }

    /// One step of ordinary wandering: now and then a pause, a small random turn, and the walls and the pond to keep clear of.
    private mutating func wanderStep(dt: Double, world: AntWorld) -> Event? {
        if pause > 0 {
            pause -= dt
            return nil
        }
        // Occasionally stop for a moment, otherwise wander with a small random turn each frame.
        if Double.random(in: 0..<1) < 0.15 * dt {
            pause = Double.random(in: 0.3...1.5)
            return nil
        }
        heading += Double.random(in: -1...1) * 3.0 * dt
        if let fire = world.fire {
            // the campfire party: drift toward the fire, then mill around it (a ring 30 to 75 points out)
            let d = hypot(fire.x - pos.x, fire.y - pos.y)
            if d > 75 { turn(toward: atan2(fire.y - pos.y, fire.x - pos.x), rate: 1.8, dt: dt) }
            else if d < 30 { turn(toward: atan2(pos.y - fire.y, pos.x - fire.x), rate: 2.5, dt: dt) }
        } else if let axis = world.axis(at: pos) {
            // in a long thin range (a strip along the screen) walk along it, back and forth, instead of turning every which way
            heading = Ant.keep(heading, along: axis, reach: world.thickness(at: pos) < 60 ? 0.2 : 0.45)
        }

        let step = effectiveSpeed * world.pace * dt
        // Outside the range (or right at its edge) no step counts as "inside", so it would never move again: walk back in.
        if !world.walkable.contains(where: { $0.insetBy(dx: 4, dy: 4).contains(pos) }) {
            if let rect = world.walkable.min(by: { Ant.distance(from: pos, to: $0) < Ant.distance(from: pos, to: $1) }) {
                let inside = CGPoint(x: min(max(pos.x, rect.minX + 8), rect.maxX - 8), y: min(max(pos.y, rect.minY + 8), rect.maxY - 8))
                heading = atan2(inside.y - pos.y, inside.x - pos.x)
                pos.x += cos(heading) * min(step, hypot(inside.x - pos.x, inside.y - pos.y))
                pos.y += sin(heading) * min(step, hypot(inside.x - pos.x, inside.y - pos.y))
                legPhase += step * 0.9
                moving = true
                return nil
            }
        }
        // Keep a little clear of a pond. A goblin already within that little distance (it was fishing at the edge) may go anywhere that is
        // not water, so it can get away from the shore; one that is in the water may go anywhere, to get out.
        let inWater = world.obstacles.contains { $0.blocks(pos, margin: 0) }
        let atShore = !inWater && world.obstacles.contains { $0.blocks(pos) }
        func allowed(_ p: CGPoint) -> Bool {
            guard world.walkable.contains(where: { $0.insetBy(dx: 4, dy: 4).contains(p) }) else { return false }
            if inWater { return true }
            let margin: CGFloat = atShore ? 0 : 3
            return !world.obstacles.contains { $0.blocks(p, margin: margin) }
        }
        let next = CGPoint(x: pos.x + cos(heading) * step, y: pos.y + sin(heading) * step)
        if allowed(next) {
            pos = next
            legPhase += step * 0.9
            moving = true
        } else {
            // bounce off the wall like a ball (turn round only the way that was blocked), and slide along it meanwhile;
            // turning half a circle on the spot, as it used to, made goblins spin against the walls of a small range
            let alongX = CGPoint(x: next.x, y: pos.y), alongY = CGPoint(x: pos.x, y: next.y)
            let xOK = allowed(alongX), yOK = allowed(alongY)
            if xOK && !yOK { heading = -heading } else if yOK && !xOK { heading = .pi - heading } else { heading += .pi }
            heading += Double.random(in: -0.15...0.15)
            if xOK { pos = alongX } else if yOK { pos = alongY }
            legPhase += step * 0.9
            moving = true // keep the walking animation going through the bounce (stopping for a frame made it flicker)
        }
        return nil
    }

    private static func distance(from p: CGPoint, to r: CGRect) -> CGFloat {
        hypot(max(r.minX - p.x, 0, p.x - r.maxX), max(r.minY - p.y, 0, p.y - r.maxY))
    }

    /// Keeps a heading close to the long side of a strip: forward or back along it, but never across.
    private static func keep(_ heading: Double, along axis: AntWorld.Axis, reach: Double) -> Double {
        func wrap(_ a: Double) -> Double { atan2(sin(a), cos(a)) }
        switch axis {
        case .horizontal:
            let target = cos(heading) >= 0 ? 0.0 : Double.pi
            return target + max(-reach, min(reach, wrap(heading - target)))
        case .vertical:
            let target = sin(heading) >= 0 ? Double.pi / 2 : -Double.pi / 2
            return target + max(-reach, min(reach, wrap(heading - target)))
        }
    }

    // MARK: Walking

    private mutating func giveUp() -> Event? {
        mode = .wandering
        heading = Double.random(in: 0..<(2 * .pi))
        return nil
    }

    private func rimPoint(of food: FoodSource, slot: Double, scale: Double) -> CGPoint {
        let r = food.radius(scale: scale) + 2.5
        return CGPoint(x: food.pos.x + cos(slot) * r, y: food.pos.y + sin(slot) * r)
    }

    /// Walks toward the nest with a gentle sway, so a line of ants looks like a trail. True on arrival.
    private mutating func walkHome(dt: Double, world: AntWorld, speedFactor: Double) -> Bool {
        let distance = hypot(world.nest.x - pos.x, world.nest.y - pos.y)
        if distance < 3 { return true }
        walk(toward: world.nest, distance: distance, speed: effectiveSpeed * speedFactor, dt: dt)
        return false
    }

    private mutating func walk(toward target: CGPoint, distance: Double, speed: Double, dt: Double, turning: Bool = true) {
        let sway = distance > 30 ? 0.3 * sin(legPhase * 0.35 + wobblePhase) : 0
        if turning { turn(toward: atan2(target.y - pos.y, target.x - pos.x) + sway, rate: max(5, 2.5 * speed / max(distance, 1)), dt: dt) }
        let step = min(speed * dt, distance)
        let angle = turning ? heading : atan2(target.y - pos.y, target.x - pos.x)
        pos.x += cos(angle) * step
        pos.y += sin(angle) * step
        legPhase += step * 0.9
        moving = true
    }

    private mutating func turn(toward angle: Double, rate: Double, dt: Double) {
        var diff = angle - heading
        while diff > .pi { diff -= 2 * .pi }
        while diff < -.pi { diff += 2 * .pi }
        let maxTurn = rate * dt
        heading += max(-maxTurn, min(maxTurn, diff))
    }
}
