import AppKit

/// How a monster attacks (the pose comes from the sheet, the motion from here). More styles will follow with more monsters.
enum AttackStyle: String {
    case none
    /// Rises in a jump and comes down flat on its target.
    case slam
    /// Crouches back, then springs forward with its jaws open.
    case bite

    /// Seconds of wind-up and of the strike itself.
    var windup: Double { self == .slam ? 0.45 : 0.3 }
    var strike: Double { self == .slam ? 0.25 : 0.2 }
}

/// What makes a wild animal a monster: it comes for the camp, hits back on its own, and leaves materials.
struct MonsterTraits {
    var hostile = false
    /// 1 is the weakest.
    var level = 1
    /// Health a goblin loses per hit.
    var damage = 1.0
    /// Seconds between its attacks.
    var attackEvery = 2.0
    /// The first monsters come after the camp has had time to grow: only once the game has run this many minutes (game time, see
    /// `Colony.playSeconds`) and the camp has had this many goblins. Stronger monsters come later.
    var appearsAfter = 0.0
    var minAnts = 0
    /// Moves in hops (a slime).
    var hops = false
    /// How it attacks: the sheet's last two frames are its wind-up and its strike, and the motion follows the style.
    var attackStyle = AttackStyle.none
    /// How many smaller ones it breaks into when killed.
    var splits = 0
    /// How many come together.
    var pack: ClosedRange<Int> = 1...1
    var drops: [DropSpec] = []
}

/// A kind of wild animal (a folder with `manifest.json` and a two-frame walk sheet), and how it behaves in the game.
final class AnimalKind {
    let id: String
    let name: String
    let hp: Double
    /// Walking speed in points per second.
    let speed: Double
    /// Pieces of meat it leaves behind.
    let meat: Int
    /// Fights back when it is hit.
    let aggressive: Bool
    /// How often it turns up compared with the others.
    let weight: Double
    /// Its size for reaching and hitting it, in points.
    let radius: Double
    let pixelScale: Double
    let monster: MonsterTraits
    var hostile: Bool { monster.hostile }
    private let right: [CGImage]
    private let left: [CGImage]
    /// How many frames of the sheet are the walk cycle (the rest are attack poses).
    let walkFrames: Int

    init(id: String, name: String, hp: Double, speed: Double, meat: Int, aggressive: Bool, weight: Double, radius: Double,
         pixelScale: Double, monster: MonsterTraits = MonsterTraits(), walkFrames: Int? = nil, right: [CGImage], left: [CGImage]) {
        self.walkFrames = min(walkFrames ?? right.count, right.count)
        self.id = id
        self.name = name
        self.hp = hp
        self.speed = speed
        self.meat = meat
        self.aggressive = aggressive
        self.weight = weight
        self.radius = radius
        self.pixelScale = pixelScale
        self.monster = monster
        self.right = right
        self.left = left
    }

    /// One frame of the walk cycle, facing the way it is heading.
    func image(facingRight: Bool, phase: Double) -> CGImage? {
        let frames = facingRight ? right : left
        return frames.isEmpty ? nil : frames[Int(max(0, phase).rounded(.down)) % max(1, walkFrames)]
    }

    /// An attack pose: 0 the wind-up, 1 the strike.
    func attackImage(facingRight: Bool, stage: Int) -> CGImage? {
        let frames = facingRight ? right : left
        let index = walkFrames + stage
        return index < frames.count ? frames[index] : nil
    }
}

enum Animals {
    static let all: [AnimalKind] = loadFolders()

    /// A random kind, weighted by how common each is: the peaceful ones (`monsters: false`) or the monsters.
    static func pick(monsters: Bool = false, minutes: Double = .infinity, ants: Int = .max) -> AnimalKind? {
        let pool = all.filter { $0.hostile == monsters && $0.monster.appearsAfter <= minutes && $0.monster.minAnts <= ants }
        let total = pool.reduce(0) { $0 + $1.weight }
        guard total > 0 else { return nil }
        var roll = Double.random(in: 0..<total)
        for kind in pool {
            roll -= kind.weight
            if roll < 0 { return kind }
        }
        return pool.last
    }

    private struct Manifest: Decodable {
        let id: String
        let name: String
        let frame: Int
        let pixelScale: Double
        let sheet: String
        let hp: Double
        let speed: Double
        let meat: Int
        let aggressive: Bool
        let weight: Double
        let radius: Double
        // only monsters have these
        let hostile: Bool?
        let level: Int?
        let damage: Double?
        let attackEvery: Double?
        let hops: Bool?
        let appearsAfter: Double?
        let minAnts: Int?
        let walkFrames: Int?
        let attackStyle: String?
        let splits: Int?
        let pack: [Int]?
        let drops: [DropSpec]?
    }

    private static func loadFolders() -> [AnimalKind] {
        var roots: [URL] = []
        if let bundled = Bundle.main.resourceURL?.appendingPathComponent("Animals") { roots.append(bundled) }
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        roots.append(support.appendingPathComponent("GoblinCamp/Animals"))

        var result: [AnimalKind] = []
        for root in roots {
            let entries = (try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)) ?? []
            for folder in entries.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
                guard let kind = load(folder: folder), !result.contains(where: { $0.id == kind.id }) else { continue }
                result.append(kind)
            }
        }
        return result
    }

    private static func load(folder: URL) -> AnimalKind? {
        guard let data = try? Data(contentsOf: folder.appendingPathComponent("manifest.json")),
              let m = try? JSONDecoder().decode(Manifest.self, from: data),
              let source = CGImageSourceCreateWithURL(folder.appendingPathComponent(m.sheet) as CFURL, nil),
              let sheet = CGImageSourceCreateImageAtIndex(source, 0, nil), m.frame > 0 else { return nil }
        let count = sheet.width / m.frame
        let frames = (0..<count).compactMap { sheet.cropping(to: CGRect(x: $0 * m.frame, y: 0, width: m.frame, height: m.frame)) }
        guard !frames.isEmpty else { return nil }
        var monster = MonsterTraits()
        monster.hostile = m.hostile ?? false
        monster.level = m.level ?? 1
        monster.damage = m.damage ?? 1
        monster.attackEvery = m.attackEvery ?? 2
        monster.hops = m.hops ?? false
        monster.appearsAfter = m.appearsAfter ?? 0
        monster.minAnts = m.minAnts ?? 0
        monster.attackStyle = AttackStyle(rawValue: m.attackStyle ?? "") ?? .none
        monster.splits = m.splits ?? 0
        if let pack = m.pack, pack.count == 2, pack[0] <= pack[1] { monster.pack = pack[0]...pack[1] }
        monster.drops = m.drops ?? []
        return AnimalKind(id: m.id, name: m.name, hp: m.hp, speed: m.speed, meat: m.meat, aggressive: m.aggressive, weight: m.weight,
                          radius: m.radius, pixelScale: m.pixelScale, monster: monster, walkFrames: m.walkFrames, right: frames, left: frames.map(mirrored))
    }

    private static func mirrored(_ image: CGImage) -> CGImage {
        guard let context = CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return image }
        context.translateBy(x: CGFloat(image.width), y: 0)
        context.scaleBy(x: -1, y: 1)
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return context.makeImage() ?? image
    }
}

/// What the goblins can see of an animal.
struct CreatureInfo {
    let id: Int
    let pos: CGPoint
    let radius: Double
    /// Somebody already knows about it, so a goblin that meets it joins in instead of running home with the news.
    let alerted: Bool
    /// A monster (goblins drop what they are doing when one comes close).
    var hostile = false
}

/// What a raiding monster can see: where the camp is and where the goblins out walking are.
struct RaidInfo {
    let nest: CGPoint
    let prey: [CGPoint]
}

/// A wild animal wandering the desktop for a while. It comes in from a screen edge, grazes, and leaves again unless
/// the goblins get it first.
struct Creature {
    enum State {
        case entering(to: CGPoint)
        case wandering
        case fleeing(remaining: Double, angle: Double)
        case leaving(to: CGPoint)
    }

    let id: Int
    let kind: AnimalKind
    var pos: CGPoint
    var heading: Double
    var hp: Double
    var state: State
    /// Seconds it will hang around before it goes away.
    var stay: Double
    var legPhase = 0.0
    private var pause = 0.0
    /// Seconds left of the red flash after a hit.
    var hurt = 0.0
    /// A goblin found it and is on the way home with the news / the news reached the nest.
    var scouted = false
    var reported = false
    private(set) var moving = false
    /// Which split it is (0 = the original) and how big it is drawn.
    var generation = 0
    var scale = 1.0
    /// Seconds it keeps standing its ground and fighting after being hit (a monster that is being beaten does not carry on walking).
    var engaged = 0.0
    /// Seconds into an attack (nil when not attacking); the hit lands when the wind-up ends.
    private(set) var attackClock: Double?
    /// Its hit lands this frame (read once by the colony with `takeStrike`).
    private var strike = false
    private var struck = false
    private var cooldown = 1.0
    /// Time inside the hop cycle (hopping monsters only), and how high off the ground it is now, in points.
    private var hopClock = 0.0
    private(set) var lift = 0.0

    init(id: Int, kind: AnimalKind, start: CGPoint, enter: CGPoint, stay: Double) {
        self.id = id
        self.kind = kind
        pos = start
        hp = kind.hp
        state = .entering(to: enter)
        self.stay = stay
        heading = atan2(enter.y - start.y, enter.x - start.x)
    }

    var info: CreatureInfo { CreatureInfo(id: id, pos: pos, radius: kind.radius, alerted: scouted || reported, hostile: kind.hostile) }

    mutating func takeStrike() -> Bool {
        defer { strike = false }
        return strike
    }

    /// True once it has walked off the screen.
    mutating func update(dt: Double, walkable: [CGRect], raid: RaidInfo? = nil) -> Bool {
        moving = false
        hurt = max(0, hurt - dt)
        switch state {
        case .entering(let target):
            if step(toward: target, speed: kind.speed, dt: dt) { state = .wandering }

        case .wandering:
            stay -= dt
            if stay <= 0 {
                state = .leaving(to: Creature.edgePoint(from: pos, walkable: walkable))
                return false
            }
            if kind.hostile, let raid {
                raidStep(dt: dt, walkable: walkable, raid: raid)
                return false
            }
            if pause > 0 {
                pause -= dt
                return false
            }
            if Double.random(in: 0..<1) < 0.25 * dt { // stops to graze
                pause = Double.random(in: 1...4)
                return false
            }
            heading += Double.random(in: -1...1) * 2.0 * dt
            move(along: heading, speed: kind.speed, dt: dt, walkable: walkable)

        case .fleeing(let remaining, let angle):
            heading = angle
            move(along: angle, speed: kind.speed * 2.2, dt: dt, walkable: walkable)
            state = remaining - dt <= 0 ? .wandering : .fleeing(remaining: remaining - dt, angle: heading)

        case .leaving(let target):
            _ = step(toward: target, speed: kind.speed * 1.4, dt: dt)
            if !walkable.contains(where: { $0.insetBy(dx: -18, dy: -18).contains(pos) }) { return true }
        }
        return false
    }

    /// Which attack pose to draw and how far along the attack is, or nil when it is not attacking.
    var attackPose: (stage: Int, progress: Double)? {
        guard let clock = attackClock else { return nil }
        let style = kind.monster.attackStyle
        return clock < style.windup ? (0, clock / style.windup) : (1, min(1, (clock - style.windup) / style.strike))
    }

    /// A monster after the camp: it goes for the nearest goblin that is out walking, or else for the nest, winds up and hits whatever
    /// is in reach, and paces around the nest.
    private mutating func raidStep(dt: Double, walkable: [CGRect], raid: RaidInfo) {
        cooldown = max(0, cooldown - (engaged > 0 ? dt * 1.5 : dt)) // it strikes back faster when it is being hit
        engaged = max(0, engaged - dt)
        let style = kind.monster.attackStyle
        var target: CGPoint?, nearest = 110.0
        for p in raid.prey {
            let d = hypot(p.x - pos.x, p.y - pos.y)
            if d < nearest { nearest = d; target = p }
        }
        let reach = kind.radius * scale + 9
        // in the middle of an attack: stay put, face the target, and land the hit when the wind-up is over
        if let clock = attackClock {
            if let target { heading = atan2(target.y - pos.y, target.x - pos.x) }
            attackClock = clock + dt
            if !struck, clock + dt >= style.windup { struck = true; strike = true }
            if clock + dt >= style.windup + style.strike {
                attackClock = nil
                struck = false
                cooldown = kind.monster.attackEvery * Double.random(in: 0.85...1.15)
            }
            lift = 0
            return
        }
        if hurt > 0.2 { return } // flinches for a moment when it is hit
        // being hit: stop, face the nearest goblin and fight it; step in only if nobody is within reach
        if engaged > 0 {
            if let target {
                heading = atan2(target.y - pos.y, target.x - pos.x)
                if nearest < reach, cooldown <= 0, style != .none {
                    attackClock = 0
                    struck = false
                } else if nearest > reach * 0.9 {
                    move(along: heading, speed: kind.speed * 0.8, dt: dt, walkable: walkable)
                    if kind.monster.hops { moving = true }
                    return
                }
            }
            lift = kind.monster.hops ? 1.2 * scale * (1 + sin(hopClock * 9)) / 2 : 0 // a little bounce on the spot
            hopClock += dt
            legPhase = 0
            return
        }
        var speed = kind.speed
        if let target {
            speed *= 1.25
            heading = atan2(target.y - pos.y, target.x - pos.x)
            if nearest < reach, cooldown <= 0, style != .none {
                attackClock = 0
                struck = false
                return
            }
        } else if hypot(raid.nest.x - pos.x, raid.nest.y - pos.y) < 36 {
            heading += Double.random(in: -1...1) * 3 * dt // at the nest: pace around it
            speed *= 0.4
        } else {
            heading = atan2(raid.nest.y - pos.y, raid.nest.x - pos.x)
        }
        if target != nil, nearest < reach * 0.8 { // close enough: stand and wait for the next attack
            if kind.monster.hops { legPhase = 0; lift = 0 }
            return
        }
        if kind.monster.hops {
            hopClock += dt
            let frame = Int(hopClock.truncatingRemainder(dividingBy: 0.9) / 0.9 * 4)
            legPhase = Double(frame)
            lift = frame == 1 || frame == 2 ? 3 * scale : 0
            speed *= [0.15, 1.9, 1.9, 0.15][frame]
        }
        move(along: heading, speed: speed, dt: dt, walkable: walkable)
        if kind.monster.hops { moving = true }
    }

    /// A point just outside the nearest screen edge.
    static func edgePoint(from p: CGPoint, walkable: [CGRect]) -> CGPoint {
        let rect = walkable.first { $0.contains(p) } ?? walkable.first ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
        let sides: [(CGFloat, CGPoint)] = [(p.x - rect.minX, CGPoint(x: rect.minX - 40, y: p.y)), (rect.maxX - p.x, CGPoint(x: rect.maxX + 40, y: p.y)),
                                           (p.y - rect.minY, CGPoint(x: p.x, y: rect.minY - 40)), (rect.maxY - p.y, CGPoint(x: p.x, y: rect.maxY + 40))]
        let allowed = Colony.entrySides(of: rect)
        return sides.enumerated().filter { allowed.contains($0.offset) }.map(\.element).min { $0.0 < $1.0 }!.1
    }

    /// Steps toward a point; true once there.
    private mutating func step(toward target: CGPoint, speed: Double, dt: Double) -> Bool {
        let dx = target.x - pos.x, dy = target.y - pos.y, distance = hypot(dx, dy)
        heading = atan2(dy, dx)
        let length = min(speed * dt, distance)
        pos.x += cos(heading) * length
        pos.y += sin(heading) * length
        legPhase += length * 0.25
        moving = true
        return distance <= max(speed * dt, 2)
    }

    private mutating func move(along angle: Double, speed: Double, dt: Double, walkable: [CGRect]) {
        let length = speed * dt
        let next = CGPoint(x: pos.x + cos(angle) * length, y: pos.y + sin(angle) * length)
        if walkable.contains(where: { $0.insetBy(dx: 24, dy: 24).contains(next) }) {
            pos = next
            legPhase += length * 0.25
            moving = true
        } else {
            heading += .pi + Double.random(in: -0.6...0.6) // turn back from the screen edge
        }
    }
}
