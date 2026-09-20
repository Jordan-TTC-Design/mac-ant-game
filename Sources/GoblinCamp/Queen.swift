import CoreGraphics
import Foundation

/// What the queen can sense each frame besides her own state.
struct Surroundings {
    var cursor: CGPoint = CGPoint(x: -10_000, y: -10_000)
    /// Recent mouse speed in points per second (peak-held so a quick flick is noticed).
    var cursorSpeed: Double = 0
    /// Position of the most recently born ant, if any.
    var newestAnt: CGPoint?
    /// The id of the outfit she is wearing, so she can change into one that suits what she is about to do.
    var outfit: String = ""
    /// A monster is close: she goes into the hole and stays there until it is gone.
    var danger = false
}

/// Things the princess does that come with a pose of their own (and sometimes a prop and an outfit that suits it).
enum Activity: String, CaseIterable {
    case tea, exercise, read, water, comb, sing

    /// How long it lasts, in seconds.
    var duration: ClosedRange<Double> {
        switch self {
        case .tea: return 9...12
        case .exercise: return 7...9
        case .read: return 10...14
        case .water: return 6...8
        case .comb: return 5...6
        case .sing: return 6...8
        }
    }

    /// Frames of the pose animation per second.
    var fps: Double {
        switch self {
        case .tea: return 0.7
        case .exercise: return 3.5
        case .read: return 0.5
        case .water: return 1.6
        case .comb: return 2.5
        case .sing: return 2.5
        }
    }

    /// Outfits that suit it (by id). Empty = anything goes.
    var preferredOutfits: [String] {
        switch self {
        case .tea: return ["gown", "dress"]
        case .exercise: return ["sport"]
        case .read: return ["skirt", "dress", "winter"]
        case .water: return ["sunny"]
        case .comb: return []
        case .sing: return ["gown", "dress"]
        }
    }

    var prop: Prop? {
        switch self {
        case .tea: return .teaTable
        case .exercise: return .mat
        case .water: return .flowerPots
        default: return nil
        }
    }
}

/// Something drawn next to her while she does it.
enum Prop { case teaTable, mat, flowerPots, bed }

/// The queen: crawls out of the nest hole, then lives beside it as a state machine.
/// See QUEEN_BEHAVIORS.md for the full list of things she does.
struct Queen {
    enum State {
        /// Being carried into the camp by two goblins; the colony moves her along with them.
        case carried
        case resting
        case wandering(to: CGPoint)
        case grooming
        case enteringHole
        case inHole
        case leavingHole
        case peeking
        case layingEgg
        case greeting
        case watching
        case spinning
        case lookingAround
        case sleeping
        case yawning
        case thinking
        case dancing
        /// A twirl and a shower of sparkles, and she is wearing something else.
        case changingOutfit
        case doing(Activity)
        case curious
    }

    /// Things the colony has to react to.
    enum Event {
        case layEgg(at: CGPoint)
        /// She has changed; `to` is the outfit she wants (nil = any other one).
        case outfitChange(to: String?)
    }

    /// Little drawings floating near her head.
    enum Decoration {
        case zzz(clock: Double)
        case yawnBubble(progress: Double)
        case thought(emoji: String, progress: Double)
        case sparkles(progress: Double)
        case steam(clock: Double)
        case notes(clock: Double)
    }

    private(set) var pos: CGPoint
    private(set) var heading: Double
    private(set) var legPhase: Double = 0
    private(set) var state: State = .carried { didSet { walkTime = 0 } }
    /// Whether her legs moved during the last update (sprites stand still otherwise).
    private(set) var walking = false

    private let nest: CGPoint
    private let home: CGPoint // where she stands when idle
    private var clock: Double = 0
    private var timer: Double = 0
    private var duration: Double = 0
    private var baseHeading: Double = 0
    private var eggLaid = false
    private var outfitSwapped = false
    /// What she wants to wear and what she will do once she has changed.
    private var desiredOutfit: String?
    private var pending: Pending?
    private var currentOutfit = ""

    private enum Pending {
        case doing(Activity)
        case sleeping
    }
    private var peekPending = false
    private var hideSpeed: Double = 18
    private var startledHide = false
    private var thoughtEmoji = "💭"
    private var reactCooldown: Double = 0
    private var walkTime: Double = 0 // time spent walking in the current state (safety net)

    var arrived: Bool {
        if case .carried = state { return false }
        return true
    }

    var isCarried: Bool {
        if case .carried = state { return true }
        return false
    }

    /// 0 while she is inside the hole, fading in as she walks out.
    var alpha: CGFloat {
        switch state {
        case .inHole: return 0
        case .enteringHole, .leavingHole: return CGFloat(min(1, hypot(pos.x - nest.x, pos.y - nest.y) / 7))
        default: return 1
        }
    }

    /// How much of her body is out of the hole (1 = all of it). Only below 1 while peeking.
    var emergence: Double {
        guard case .peeking = state else { return 1 }
        let u = progress
        let out = 0.65
        if u < 0.25 { return u / 0.25 * out }
        if u < 0.75 { return out }
        return (1 - u) / 0.25 * out
    }

    var decoration: Decoration? {
        switch state {
        case .sleeping: return .zzz(clock: clock)
        case .yawning: return .yawnBubble(progress: progress)
        case .thinking: return .thought(emoji: thoughtEmoji, progress: progress)
        case .changingOutfit: return .sparkles(progress: progress)
        case .doing(.tea): return .steam(clock: clock)
        case .doing(.sing): return .notes(clock: clock)
        default: return nil
        }
    }

    /// A pose of her own instead of the walking frames: its name in the sheet and the (unwrapped) frame number.
    var pose: (name: String, frame: Int)? {
        switch state {
        case .doing(let activity): return (activity.rawValue, Int(clock * activity.fps))
        case .grooming: return ("comb", Int(clock * 2.5))
        case .yawning: return ("yawn", progress > 0.5 ? 1 : 0)
        case .thinking: return ("think", Int(clock * 1.2))
        case .dancing: return ("dance", Int(clock * 4))
        case .greeting: return ("wave", Int(clock * 4))
        default: return nil
        }
    }

    var prop: Prop? {
        switch state {
        case .doing(let activity): return activity.prop
        case .sleeping: return .bed
        default: return nil
        }
    }

    /// Lying down to sleep.
    var isLying: Bool {
        if case .sleeping = state { return true }
        return false
    }

    var stateName: String {
        switch state {
        case .carried: return "carried"
        case .resting: return "resting"
        case .wandering: return "wandering"
        case .grooming: return "grooming"
        case .enteringHole: return "enteringHole"
        case .inHole: return "inHole"
        case .leavingHole: return "leavingHole"
        case .peeking: return "peeking"
        case .layingEgg: return "layingEgg"
        case .greeting: return "greeting"
        case .watching: return "watching"
        case .spinning: return "spinning"
        case .lookingAround: return "lookingAround"
        case .sleeping: return "sleeping"
        case .yawning: return "yawning"
        case .thinking: return "thinking"
        case .dancing: return "dancing"
        case .changingOutfit: return "changingOutfit"
        case .doing(let activity): return "doing:\(activity.rawValue)"
        case .curious: return "curious"
        }
    }

    /// 0...1 through the current timed state.
    private var progress: Double {
        duration > 0 ? min(1, max(0, 1 - timer / duration)) : 0
    }

    /// Where she stands when idle: beside the camp, not in front of its entrance.
    /// Beside the camp on the right when there is room; if that would be off the screen or outside a narrow range (a strip down the
    /// screen edge), on the left, below or above it. Always somewhere she can be seen.
    static func homeSpot(for nest: CGPoint, walkable: [CGRect] = []) -> CGPoint {
        let candidates = [CGPoint(x: nest.x + 30, y: nest.y - 6), CGPoint(x: nest.x - 30, y: nest.y - 6),
                          CGPoint(x: nest.x, y: nest.y - 34), CGPoint(x: nest.x, y: nest.y + 34)]
        if walkable.isEmpty { return candidates[0] }
        return candidates.first { p in walkable.contains { $0.insetBy(dx: 12, dy: 12).contains(p) } } ?? candidates[0]
    }

    /// Starts out being carried toward `nest`; `Colony` moves her with her carriers until they set her down.
    init(carriedTo nest: CGPoint, walkable: [CGRect] = []) {
        self.nest = nest
        home = Queen.homeSpot(for: nest, walkable: walkable)
        heading = 0
        pos = nest
    }

    /// Already at home (restored colony).
    static func settled(nest: CGPoint, walkable: [CGRect] = []) -> Queen {
        var q = Queen(carriedTo: nest, walkable: walkable)
        q.setDown()
        return q
    }

    /// Follow the carriers.
    mutating func carry(at point: CGPoint, heading: Double) {
        guard isCarried else { return }
        pos = point
        self.heading = heading
    }

    /// The carriers arrived: she stands up beside the camp.
    mutating func setDown() {
        pos = home
        beginResting()
    }

    // MARK: Update

    /// Which way she faces, with a little stickiness so she does not flick between sideways and front while turning.
    private(set) var facing = SpriteDirection.down

    mutating func update(dt: Double, walkable: [CGRect], around: Surroundings = Surroundings()) -> Event? {
        facing = SpriteDirection(heading: heading, previous: facing)
        clock += dt
        walking = false
        currentOutfit = around.outfit
        reactCooldown = max(0, reactCooldown - dt)
        var event: Event?

        if around.danger {
            switch state {
            case .carried, .enteringHole: break
            case .inHole: timer = max(timer, 2)
            case .leavingHole, .peeking:
                pos = nest
                state = .inHole
                duration = 0
                timer = 3
            default: takeCover()
            }
        }

        switch state {
        case .carried:
            break // her position comes from the carriers (see `carry`)

        case .resting:
            timer -= dt
            if reactCooldown == 0, react(to: around, dt: dt) { break }
            if timer <= 0 { pickNextAction(walkable: walkable) }

        case .wandering(let target):
            if walk(to: target, speed: 22, dt: dt) { beginResting() }

        case .grooming, .yawning, .thinking, .sleeping, .doing:
            timer -= dt
            if timer <= 0 { beginResting() }

        case .greeting:
            timer -= dt
            if timer <= 0 {
                if around.newestAnt != nil { begin(.watching, duration: 4) } else { beginResting() }
            }

        case .watching:
            timer -= dt
            if let ant = around.newestAnt { turn(toward: atan2(ant.y - pos.y, ant.x - pos.x), rate: 3, dt: dt) }
            if timer <= 0 { beginResting() }

        case .spinning:
            timer -= dt
            heading += 4 * .pi / duration * dt
            legPhase += dt * 8
            walking = true
            if timer <= 0 { beginResting() }

        case .changingOutfit:
            timer -= dt
            heading += 4 * .pi / duration * dt // twirls twice
            legPhase += dt * 8
            walking = true
            if !outfitSwapped, progress >= 0.5 { // in the middle of the twirl, unseen behind the sparkles
                outfitSwapped = true
                event = .outfitChange(to: desiredOutfit)
                desiredOutfit = nil
            }
            if timer <= 0 {
                if let next = pending {
                    pending = nil
                    start(next)
                } else {
                    beginResting()
                }
            }

        case .lookingAround:
            timer -= dt
            heading = baseHeading + 0.52 * sin(progress * 2 * .pi)
            if timer <= 0 {
                heading = baseHeading
                beginResting()
            }

        case .dancing:
            timer -= dt
            heading = baseHeading + 0.6 * sin(clock * 14)
            legPhase += dt * 10
            walking = true
            if timer <= 0 {
                heading = baseHeading
                beginResting()
            }

        case .layingEgg:
            timer -= dt
            if !eggLaid, timer < 1.0 {
                eggLaid = true
                event = .layEgg(at: CGPoint(x: pos.x - cos(heading) * 5, y: pos.y - sin(heading) * 5))
            }
            if timer <= 0 { beginResting() }

        case .enteringHole:
            if walk(to: nest, speed: hideSpeed, dt: dt) {
                state = .inHole
                duration = 0
                timer = startledHide ? Double.random(in: 6...10) : Double.random(in: 3...6)
                startledHide = false
            }

        case .inHole:
            timer -= dt
            if timer <= 0 {
                pos = nest
                if peekPending {
                    peekPending = false
                    heading = atan2(home.y - nest.y, home.x - nest.x)
                    begin(.peeking, duration: 3.2)
                } else {
                    state = .leavingHole
                }
            }

        case .peeking:
            timer -= dt
            if timer <= 0 {
                state = .inHole
                duration = 0
                timer = 1.2
            }

        case .leavingHole:
            if walk(to: home, speed: 18, dt: dt) { beginResting() }

        case .curious:
            timer -= dt
            let d = hypot(around.cursor.x - nest.x, around.cursor.y - nest.y)
            if timer <= 0 || d > 340 {
                reactCooldown = 12
                state = .wandering(to: home)
                break
            }
            // Walk part of the way toward the cursor, then face it and sniff.
            let dir = atan2(around.cursor.y - nest.y, around.cursor.x - nest.x)
            let stop = CGPoint(x: nest.x + cos(dir) * min(26, d * 0.4), y: nest.y + sin(dir) * min(26, d * 0.4))
            if walk(to: stop, speed: 26, dt: dt) {
                turn(toward: atan2(around.cursor.y - pos.y, around.cursor.x - pos.x), rate: 5, dt: dt)
            }
        }
        return event
    }

    // MARK: Outside triggers

    /// A newborn appeared: turn to face it for a moment.
    mutating func greet(toward point: CGPoint) {
        guard canBeInterrupted else { return }
        heading = atan2(point.y - pos.y, point.x - pos.x)
        begin(.greeting, duration: 1.8)
    }

    /// The colony hit a milestone: wiggle.
    mutating func celebrate() {
        guard canBeInterrupted else { return }
        begin(.dancing, duration: 2.5)
    }

    /// A monster is near: bolt into the hole.
    mutating func takeCover() {
        startledHide = true
        hideSpeed = 70
        peekPending = false
        state = .enteringHole
    }

    /// Somebody clicked on the nest: duck into the hole and peek out.
    mutating func poke() {
        switch state {
        case .carried, .enteringHole, .leavingHole, .peeking: return
        case .inHole:
            peekPending = false
            pos = nest
            heading = atan2(home.y - nest.y, home.x - nest.x)
            begin(.peeking, duration: 3.2)
        default:
            peekPending = true
            hideSpeed = 40
            state = .enteringHole
        }
    }

    /// Test hook (`CAMP_QUEEN_FORCE`): jump straight into a named action so it can be inspected.
    mutating func debugForce(_ name: String) {
        pos = home
        switch name {
        case "outfit": outfitSwapped = false; begin(.changingOutfit, duration: 1.8)
        case "tea", "exercise", "read", "water", "comb", "sing": begin(.doing(Activity(rawValue: name)!), duration: 60)
        case "sleeping": begin(.sleeping, duration: 30)
        case "yawning": begin(.yawning, duration: 4)
        case "thinking": thoughtEmoji = "🍰"; begin(.thinking, duration: 6)
        case "dancing": begin(.dancing, duration: 6)
        case "peeking":
            pos = nest
            heading = atan2(home.y - nest.y, home.x - nest.x)
            begin(.peeking, duration: 30)
            timer = 30 * 0.6 // hold phase
        default: break
        }
    }

    // MARK: Private

    private var canBeInterrupted: Bool {
        switch state {
        case .carried, .enteringHole, .inHole, .leavingHole, .peeking: return false
        default: return true
        }
    }

    private mutating func begin(_ next: State, duration: Double = 0) {
        state = next
        timer = duration
        self.duration = duration
        baseHeading = heading
    }

    private mutating func beginResting(long: Bool = false) {
        begin(.resting, duration: long ? Double.random(in: 6...12) : Double.random(in: 2...6))
    }

    private func preferredOutfits(for pending: Pending) -> [String] {
        switch pending {
        case .doing(let activity): return activity.preferredOutfits
        case .sleeping: return ["pajamas"]
        }
    }

    private mutating func start(_ pending: Pending) {
        switch pending {
        case .doing(let activity): begin(.doing(activity), duration: Double.random(in: activity.duration))
        case .sleeping: begin(.sleeping, duration: Double.random(in: 8...14))
        }
    }

    /// Starts `pending`, first changing into something that suits it (most of the time) if she is not wearing it yet.
    private mutating func startOrChange(_ pending: Pending) {
        let wanted = preferredOutfits(for: pending)
        if !wanted.isEmpty, !wanted.contains(currentOutfit), Double.random(in: 0..<1) < 0.3 {
            self.pending = pending
            desiredOutfit = wanted.first
            outfitSwapped = false
            begin(.changingOutfit, duration: 1.8)
        } else {
            start(pending)
        }
    }

    /// Reactions to the mouse cursor while idle. Returns true if she changed state.
    private mutating func react(to around: Surroundings, dt: Double) -> Bool {
        let d = hypot(around.cursor.x - pos.x, around.cursor.y - pos.y)
        if d < 120, around.cursorSpeed > 1200 {
            // startled by a fast flick: bolt into the hole and hide longer
            startledHide = true
            hideSpeed = 70
            peekPending = false
            reactCooldown = 20
            state = .enteringHole
            return true
        }
        if d < 220, around.cursorSpeed < 500, Double.random(in: 0..<1) < 0.15 * dt {
            begin(.curious, duration: 6)
            return true
        }
        return false
    }

    private mutating func pickNextAction(walkable: [CGRect]) {
        func isWalkable(_ p: CGPoint) -> Bool { walkable.contains { $0.insetBy(dx: 8, dy: 8).contains(p) } }
        func point(around center: CGPoint, radius: ClosedRange<Double>) -> CGPoint {
            let angle = Double.random(in: 0..<(2 * .pi)), r = Double.random(in: radius)
            return CGPoint(x: center.x + cos(angle) * r, y: center.y + sin(angle) * r)
        }

        let roll = Double.random(in: 0..<100)
        var acc = 0.0
        func chance(_ weight: Double) -> Bool { acc += weight; return roll < acc }

        if chance(16) {
            let target = point(around: home, radius: 12...30)
            if isWalkable(target) { state = .wandering(to: target) } else { beginResting() }
        } else if chance(8) {
            startOrChange(.doing(.comb))
        } else if chance(5) {
            peekPending = false
            hideSpeed = 18
            state = .enteringHole
        } else if chance(5) {
            begin(.layingEgg, duration: 2.6)
            eggLaid = false
        } else if chance(3) {
            begin(.spinning, duration: 1.3)
        } else if chance(5) {
            begin(.lookingAround, duration: 2.6)
        } else if chance(4) {
            peekPending = true
            hideSpeed = 18
            state = .enteringHole
        } else if chance(6) {
            startOrChange(.sleeping)
        } else if chance(4) {
            begin(.yawning, duration: 2.2)
        } else if chance(5) {
            thoughtEmoji = ["🍎", "🍰", "💭", "🍯", "🌿"].randomElement() ?? "💭"
            begin(.thinking, duration: 3.5)
        } else if chance(1) {
            outfitSwapped = false
            begin(.changingOutfit, duration: 1.8)
        } else if chance(9) {
            startOrChange(.doing(.tea))
        } else if chance(7) {
            startOrChange(.doing(.exercise))
        } else if chance(7) {
            startOrChange(.doing(.read))
        } else if chance(5) {
            startOrChange(.doing(.water))
        } else if chance(7) {
            startOrChange(.doing(.sing))
        } else {
            beginResting(long: true)
        }
    }

    /// Rotates the heading toward `angle` by at most `rate` rad/s.
    private mutating func turn(toward angle: Double, rate: Double, dt: Double) {
        var diff = angle - heading
        while diff > .pi { diff -= 2 * .pi }
        while diff < -.pi { diff += 2 * .pi }
        let maxTurn = rate * dt
        heading += max(-maxTurn, min(maxTurn, diff))
    }

    /// Turns smoothly toward `target` and steps toward it. Returns true once there.
    private mutating func walk(to target: CGPoint, speed: Double, dt: Double) -> Bool {
        let dx = target.x - pos.x, dy = target.y - pos.y
        let dist = hypot(dx, dy)
        let step = speed * dt
        walkTime += dt
        // Safety net: never let a walk go on forever.
        if dist <= step || walkTime > 20 {
            pos = target
            return true
        }
        // A target closer than the turning circle (speed / rate) could never be reached, so turn faster up close.
        turn(toward: atan2(dy, dx), rate: max(6, 2.5 * speed / dist), dt: dt)
        pos.x += cos(heading) * step
        pos.y += sin(heading) * step
        legPhase += speed * dt * 0.6
        walking = true
        return false
    }
}
