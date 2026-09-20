import AppKit

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
    private let right: [CGImage]
    private let left: [CGImage]

    init(id: String, name: String, hp: Double, speed: Double, meat: Int, aggressive: Bool, weight: Double, radius: Double,
         pixelScale: Double, right: [CGImage], left: [CGImage]) {
        self.id = id
        self.name = name
        self.hp = hp
        self.speed = speed
        self.meat = meat
        self.aggressive = aggressive
        self.weight = weight
        self.radius = radius
        self.pixelScale = pixelScale
        self.right = right
        self.left = left
    }

    /// One frame of the walk cycle, facing the way it is heading.
    func image(facingRight: Bool, phase: Double) -> CGImage? {
        let frames = facingRight ? right : left
        return frames.isEmpty ? nil : frames[Int(max(0, phase).rounded(.down)) % frames.count]
    }
}

enum Animals {
    static let all: [AnimalKind] = loadFolders()

    /// A random kind, weighted by how common each is.
    static func pick() -> AnimalKind? {
        let total = all.reduce(0) { $0 + $1.weight }
        guard total > 0 else { return nil }
        var roll = Double.random(in: 0..<total)
        for kind in all {
            roll -= kind.weight
            if roll < 0 { return kind }
        }
        return all.last
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
        return AnimalKind(id: m.id, name: m.name, hp: m.hp, speed: m.speed, meat: m.meat, aggressive: m.aggressive, weight: m.weight,
                          radius: m.radius, pixelScale: m.pixelScale, right: frames, left: frames.map(mirrored))
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

    init(id: Int, kind: AnimalKind, start: CGPoint, enter: CGPoint, stay: Double) {
        self.id = id
        self.kind = kind
        pos = start
        hp = kind.hp
        state = .entering(to: enter)
        self.stay = stay
        heading = atan2(enter.y - start.y, enter.x - start.x)
    }

    var info: CreatureInfo { CreatureInfo(id: id, pos: pos, radius: kind.radius, alerted: scouted || reported) }

    /// True once it has walked off the screen.
    mutating func update(dt: Double, walkable: [CGRect]) -> Bool {
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
