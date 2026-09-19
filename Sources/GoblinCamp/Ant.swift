import CoreGraphics
import Foundation

/// One ant. Position is in global screen coordinates; heading in radians (0 = +x).
///
/// Ants wander at random and only notice food they happen to bump into. A finder walks straight home with the
/// news, nestmates then set out along (roughly) the same line, ring the food, and carry pieces back one by one.
/// Every so often an ant heads home to rest inside the nest for a while.
struct Ant {
    enum Mode {
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
    var pos: CGPoint
    var heading: Double
    var speed: Double
    var mode: Mode = .wandering
    var pause: Double = 0
    /// Whether the legs moved during the last update (sprites stand still otherwise).
    private(set) var moving = false
    var legPhase: Double = Double.random(in: 0...(2 * .pi))
    private let wobblePhase = Double.random(in: 0...(2 * .pi))

    init(at pos: CGPoint, id: Int, breedIndex: Int, traits: Traits, seed: UInt64, age: Double = 0) {
        self.id = id
        self.breedIndex = breedIndex
        self.traits = traits
        self.seed = seed
        self.age = age
        self.pos = pos
        heading = Double.random(in: 0..<(2 * .pi))
        speed = Double.random(in: 15...40) * traits.speed
    }

    /// 0 at birth, 1 at the end of its life.
    var lifeFraction: Double { min(1, age / max(traits.lifespan, 1)) }

    /// Old ones walk slower.
    private var effectiveSpeed: Double { lifeFraction > Ant.elderStart ? speed * 0.6 : speed }

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
        if case .inNest = mode { return true }
        return false
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
    mutating func update(dt: Double, ageDt: Double, world: AntWorld) -> Event? {
        moving = false
        age += ageDt
        if age >= traits.lifespan, !isDying, !isCarryingPrincess {
            if isHidden { return .died } // it went quietly in the nest
            mode = .dying(remaining: Ant.dyingTime)
        }
        switch mode {
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

        case .inNest(let remaining, let thenForage):
            let left = remaining - dt
            if left > 0 {
                mode = .inNest(remaining: left, thenForage: thenForage)
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

    private mutating func updateWandering(dt: Double, world: AntWorld) -> Event? {
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
        // Now and then go home for a rest.
        if Double.random(in: 0..<1) < dt / 90 * traits.rest {
            mode = .returningToNest
            return nil
        }

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

        let step = effectiveSpeed * dt
        let next = CGPoint(x: pos.x + cos(heading) * step, y: pos.y + sin(heading) * step)
        if world.walkable.contains(where: { $0.insetBy(dx: 4, dy: 4).contains(next) }) {
            pos = next
            legPhase += effectiveSpeed * dt * 0.9
            moving = true
        } else {
            heading += .pi + Double.random(in: -0.6...0.6) // bounce off the screen edge
        }
        return nil
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
