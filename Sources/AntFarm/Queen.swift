import CoreGraphics
import Foundation

/// What the queen can sense each frame besides her own state.
struct Surroundings {
    var cursor: CGPoint = CGPoint(x: -10_000, y: -10_000)
    /// Recent mouse speed in points per second (peak-held so a quick flick is noticed).
    var cursorSpeed: Double = 0
    /// Position of the most recently born ant, if any.
    var newestAnt: CGPoint?
}

/// The queen: crawls out of the nest hole, then lives beside it as a state machine.
/// See QUEEN_BEHAVIORS.md for the full list of things she does.
struct Queen {
    enum State {
        case emerging
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
        case digging
        case fetching(to: CGPoint)
        case carrying(to: CGPoint)
        case patchApproach
        case patching
        case sleeping
        case yawning
        case thinking
        case dancing
        case curious
    }

    /// Things the colony has to react to.
    enum Event {
        case layEgg(at: CGPoint)
        case dropDirt(at: CGPoint)
        case dropPebble(at: CGPoint)
        case patched
    }

    /// Little drawings floating near her head.
    enum Decoration {
        case zzz(clock: Double)
        case yawnBubble(progress: Double)
        case thought(emoji: String, progress: Double)
    }

    private(set) var pos: CGPoint
    private(set) var heading: Double
    private(set) var legPhase: Double = 0
    private(set) var state: State = .emerging { didSet { walkTime = 0 } }
    private(set) var carryingPebble = false

    private let nest: CGPoint
    private let home: CGPoint // where she stands when idle
    private var clock: Double = 0
    private var timer: Double = 0
    private var duration: Double = 0
    private var baseHeading: Double = 0
    private var eggLaid = false
    private var peekPending = false
    private var hideSpeed: Double = 18
    private var startledHide = false
    private var dirtClock: Double = 0
    private var patchAngle: Double = 0
    private var thoughtEmoji = "💭"
    private var reactCooldown: Double = 0
    private var walkTime: Double = 0 // time spent walking in the current state (safety net)

    private static let patchRadius: Double = 12

    var arrived: Bool {
        if case .emerging = state { return false }
        return true
    }

    /// While crawling out, only the part of her body past the hole is visible: everything beyond the line
    /// through `origin` (the hole) perpendicular to `angle` (the direction she is heading out).
    var clipLine: (origin: CGPoint, angle: Double)? {
        guard case .emerging = state else { return nil }
        return (nest, atan2(home.y - nest.y, home.x - nest.x))
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

    /// Head size multiplier (grows while yawning).
    var headScale: Double {
        guard case .yawning = state else { return 1 }
        return 1 + 0.6 * sin(progress * .pi)
    }

    var decoration: Decoration? {
        switch state {
        case .sleeping: return .zzz(clock: clock)
        case .yawning: return .yawnBubble(progress: progress)
        case .thinking: return .thought(emoji: thoughtEmoji, progress: progress)
        default: return nil
        }
    }

    /// Antenna offsets in radians from the resting pose (positive = outward). Left / right.
    var antennae: (left: Double, right: Double) {
        switch state {
        case .grooming:
            let t = clock * 5
            return (-0.9 * max(0, sin(t)), -0.9 * max(0, sin(t + .pi)))
        case .greeting:
            let wave = 0.35 * sin(clock * 12) - 0.3
            return (wave, wave)
        case .dancing:
            let wave = 0.5 * sin(clock * 14)
            return (wave, -wave)
        case .sleeping:
            return (-0.7, -0.7)
        case .peeking, .curious:
            let wave = 0.25 * sin(clock * 7)
            return (wave, -wave)
        case .watching, .thinking:
            let wave = 0.1 * sin(clock * 3)
            return (wave, wave)
        case .resting:
            let twitch = sin(clock * 0.7) > 0.85 ? 0.18 * sin(clock * 9) : 0
            return (twitch, -twitch)
        default:
            return (0, 0)
        }
    }

    var stateName: String {
        switch state {
        case .emerging: return "emerging"
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
        case .digging: return "digging"
        case .fetching: return "fetching"
        case .carrying: return "carrying"
        case .patchApproach: return "patchApproach"
        case .patching: return "patching"
        case .sleeping: return "sleeping"
        case .yawning: return "yawning"
        case .thinking: return "thinking"
        case .dancing: return "dancing"
        case .curious: return "curious"
        }
    }

    /// 0...1 through the current timed state.
    private var progress: Double {
        duration > 0 ? min(1, max(0, 1 - timer / duration)) : 0
    }

    static func homeSpot(for nest: CGPoint) -> CGPoint { CGPoint(x: nest.x + 10, y: nest.y + 5) }

    /// Starts hidden just behind the hole and crawls out to her spot beside the nest.
    init(emergingFrom nest: CGPoint) {
        self.nest = nest
        home = Queen.homeSpot(for: nest)
        heading = atan2(home.y - nest.y, home.x - nest.x)
        // far enough behind the hole that no part of her shows, whatever the ant size setting
        pos = CGPoint(x: nest.x - cos(heading) * 18, y: nest.y - sin(heading) * 18)
    }

    /// Already at home (restored colony).
    static func settled(nest: CGPoint) -> Queen {
        var q = Queen(emergingFrom: nest)
        q.pos = q.home
        q.beginResting()
        return q
    }

    // MARK: Update

    mutating func update(dt: Double, walkable: [CGRect], around: Surroundings = Surroundings()) -> Event? {
        clock += dt
        reactCooldown = max(0, reactCooldown - dt)
        var event: Event?

        switch state {
        case .emerging:
            if walk(to: home, speed: 10, dt: dt) { beginResting() } // slow crawl out of the hole

        case .resting:
            timer -= dt
            if reactCooldown == 0, react(to: around, dt: dt) { break }
            if timer <= 0 { pickNextAction(walkable: walkable) }

        case .wandering(let target):
            if walk(to: target, speed: 22, dt: dt) { beginResting() }

        case .grooming, .yawning, .thinking, .sleeping:
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
            if timer <= 0 { beginResting() }

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

        case .digging:
            timer -= dt
            turn(toward: atan2(nest.y - pos.y, nest.x - pos.x), rate: 4, dt: dt)
            dirtClock += dt
            if dirtClock >= 0.8 {
                dirtClock = 0
                let angle = Double.random(in: 0..<(2 * .pi)), radius = Double.random(in: 9...18)
                event = .dropDirt(at: CGPoint(x: nest.x + cos(angle) * radius, y: nest.y + sin(angle) * radius))
            }
            if timer <= 0 { beginResting() }

        case .fetching(let target):
            if walk(to: target, speed: 25, dt: dt) {
                carryingPebble = true
                let angle = Double.random(in: 0..<(2 * .pi)), radius = Double.random(in: 14...22)
                state = .carrying(to: CGPoint(x: nest.x + cos(angle) * radius, y: nest.y + sin(angle) * radius))
            }

        case .carrying(let target):
            if walk(to: target, speed: 20, dt: dt) {
                carryingPebble = false
                event = .dropPebble(at: CGPoint(x: pos.x + cos(heading) * 3, y: pos.y + sin(heading) * 3))
                beginResting()
            }

        case .patchApproach:
            let start = CGPoint(x: nest.x + Queen.patchRadius, y: nest.y)
            if walk(to: start, speed: 22, dt: dt) {
                patchAngle = 0
                state = .patching
            }

        case .patching:
            // One lap around the hole, pressing the soil flat.
            patchAngle += 20 / Queen.patchRadius * dt
            pos = CGPoint(x: nest.x + cos(patchAngle) * Queen.patchRadius, y: nest.y + sin(patchAngle) * Queen.patchRadius)
            heading = patchAngle + .pi / 2
            legPhase += dt * 8
            if patchAngle >= 2 * .pi {
                event = .patched
                state = .wandering(to: home)
            }

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

    /// A newborn appeared: turn to face it and touch antennae for a moment.
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

    /// Somebody clicked on the nest: duck into the hole and peek out.
    mutating func poke() {
        switch state {
        case .emerging, .enteringHole, .leavingHole, .peeking: return
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

    /// Test hook (`ANT_QUEEN_FORCE`): jump straight into a named action so it can be inspected.
    mutating func debugForce(_ name: String) {
        pos = home
        switch name {
        case "sleeping": begin(.sleeping, duration: 30)
        case "yawning": begin(.yawning, duration: 4)
        case "thinking": thoughtEmoji = "🍰"; begin(.thinking, duration: 6)
        case "dancing": begin(.dancing, duration: 6)
        case "digging": dirtClock = 0; begin(.digging, duration: 12)
        case "carrying":
            carryingPebble = true
            state = .carrying(to: CGPoint(x: home.x + 400, y: home.y))
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
        case .emerging, .enteringHole, .inHole, .leavingHole, .peeking: return false
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
        carryingPebble = false
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

        if chance(20) {
            let target = point(around: home, radius: 12...30)
            if isWalkable(target) { state = .wandering(to: target) } else { beginResting() }
        } else if chance(12) {
            begin(.grooming, duration: 2.5)
        } else if chance(8) {
            peekPending = false
            hideSpeed = 18
            state = .enteringHole
        } else if chance(8) {
            begin(.layingEgg, duration: 2.6)
            eggLaid = false
        } else if chance(5) {
            begin(.spinning, duration: 1.3)
        } else if chance(6) {
            begin(.lookingAround, duration: 2.6)
        } else if chance(6) {
            peekPending = true
            hideSpeed = 18
            state = .enteringHole
        } else if chance(7) {
            dirtClock = 0
            begin(.digging, duration: 5)
        } else if chance(6) {
            let target = point(around: nest, radius: 35...50)
            if isWalkable(target) { state = .fetching(to: target) } else { beginResting() }
        } else if chance(5) {
            state = .patchApproach
        } else if chance(5) {
            begin(.sleeping, duration: Double.random(in: 8...14))
        } else if chance(4) {
            begin(.yawning, duration: 2.2)
        } else if chance(5) {
            thoughtEmoji = ["🍎", "🍰", "💭", "🍯", "🌿"].randomElement() ?? "💭"
            begin(.thinking, duration: 3.5)
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
        return false
    }
}
