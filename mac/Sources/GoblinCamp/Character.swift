import AppKit

enum SpriteDirection {
    case down, up, left, right

    /// Like `init(heading:)`, but it holds on to `previous` until the heading has clearly moved on, so a character walking along a
    /// diagonal (or swaying a little, or bumping a wall) does not flick between facing sideways and facing the screen.
    init(heading: Double, previous: SpriteDirection) {
        let c = cos(heading), s = sin(heading)
        let margin = 1.6
        switch previous {
        case .left where c < 0 && abs(s) <= abs(c) * 1.15 * margin: self = .left
        case .right where c >= 0 && abs(s) <= abs(c) * 1.15 * margin: self = .right
        case .up where s > 0 && abs(s) * margin > abs(c) * 1.15: self = .up
        case .down where s <= 0 && abs(s) * margin > abs(c) * 1.15: self = .down
        default: self.init(heading: heading)
        }
    }

    /// Which way to face for a heading (radians, 0 = +x, screen y points up). Sideways is favoured a little
    /// so a wandering character does not flicker between sideways and front/back.
    init(heading: Double) {
        let c = cos(heading), s = sin(heading)
        if abs(s) > abs(c) * 1.15 {
            self = s > 0 ? .up : .down
        } else {
            self = c >= 0 ? .right : .left
        }
    }
}

/// The sprites for one role (worker or queen) of a pixel-art character.
struct SpriteRole {
    /// Points per art pixel at the default size setting.
    let pixelScale: Double
    let frameSize: Int
    private let frames: [SpriteDirection: [CGImage]]
    /// Action poses (tea, exercise…): front-facing animations, by name.
    private let poses: [String: [CGImage]]

    init(pixelScale: Double, frameSize: Int, frames: [SpriteDirection: [CGImage]], poses: [String: [CGImage]] = [:]) {
        self.pixelScale = pixelScale
        self.frameSize = frameSize
        self.frames = frames
        self.poses = poses
    }

    /// Frame `frame` (wrapping round) of the pose called `name`, if this character has it.
    func poseImage(_ name: String, frame: Int) -> CGImage? {
        guard let list = poses[name], !list.isEmpty else { return nil }
        return list[((frame % list.count) + list.count) % list.count]
    }

    /// One frame of the walk cycle. `phase` grows with distance walked.
    func image(direction: SpriteDirection, phase: Double) -> CGImage? {
        guard let list = frames[direction], !list.isEmpty else { return nil }
        return list[Int(max(0, phase).rounded(.down)) % list.count]
    }

    /// Size on screen in points for the given size setting. Snapped to half points so every art pixel covers a
    /// whole number of device pixels on a Retina screen and stays crisp.
    func pixelSize(scale: Double) -> CGFloat {
        CGFloat(max(0.5, (pixelScale * scale * 2).rounded(.toNearestOrAwayFromZero) / 2))
    }
}

/// One set of clothes for the princess.
struct Outfit {
    let id: String
    let name: String
    let role: SpriteRole
}

/// A playable look: a pixel-art character loaded from a folder (`manifest.json` plus one PNG sprite sheet per role).
/// See PLAN.md for the format.
final class Character {
    let id: String
    let name: String
    /// What the individuals are called in the menu, e.g. 哥布林.
    let noun: String
    let emoji: String
    /// What the home is called, e.g. 營地.
    let nestName: String
    let defaultMaxCount: Int
    /// Kinds of inhabitant, the plain one first.
    let breeds: [Breed]
    /// nil for the vector ants.
    var worker: SpriteRole? { breeds.first?.sprites }
    /// The princess in her first outfit (the others are in `outfits`).
    let queen: SpriteRole?
    /// The clothes she can change into, the first being what she starts in.
    let outfits: [Outfit]
    /// Small picture for the menu bar. Characters without one use the emoji.
    let icon: NSImage?

    init(id: String, name: String, noun: String, emoji: String, nestName: String = "營地", defaultMaxCount: Int, breeds: [Breed], queen: SpriteRole?,
         outfits: [Outfit] = [], icon: NSImage? = nil) {
        self.id = id
        self.name = name
        self.noun = noun
        self.emoji = emoji
        self.nestName = nestName
        self.defaultMaxCount = defaultMaxCount
        self.breeds = breeds.isEmpty ? [Breed.plain] : breeds
        self.queen = queen
        self.outfits = outfits.isEmpty ? (queen.map { [Outfit(id: "default", name: "預設", role: $0)] } ?? []) : outfits
        self.icon = icon
    }

    /// The princess's sprites in outfit number `index`.
    func queenRole(outfit index: Int) -> SpriteRole? {
        outfits.isEmpty ? queen : outfits[min(max(index, 0), outfits.count - 1)].role
    }

    func breedIndex(id: String) -> Int { breeds.firstIndex { $0.id == id } ?? 0 }
}

enum Characters {
    /// The characters found on disk: the built-in ones first, then the user's own.
    static let all: [Character] = loadFolders()

    /// Only used if no character folder can be found at all (a broken install): no sprites, so plain dots are drawn.
    private static let fallback = Character(id: "none", name: "（找不到角色）", noun: "哥布林", emoji: "👺", nestName: "營地",
                                            defaultMaxCount: 150, breeds: [Breed.plain], queen: nil)

    static var current: Character {
        let id = Settings.shared.characterID
        return all.first { $0.id == id } ?? all.first ?? fallback
    }

    // MARK: Loading

    private struct Manifest: Decodable {
        struct Role: Decodable {
            let sheet: String
            let pixelScale: Double
            let walk: [String: [Int]]
            let outfits: [OutfitEntry]?
            let poses: [String: [Int]]?
        }

        struct OutfitEntry: Decodable {
            let id: String
            let name: String
            let sheet: String
        }
        let id: String
        let name: String
        let noun: String
        let emoji: String
        let icon: String?
        let nestName: String?
        let frame: Int
        let defaultMaxCount: Int?
        let worker: Role
        let queen: Role?
        let breeds: [BreedEntry]?
    }

    private struct BreedEntry: Decodable {
        let id: String
        let name: String
        let weight: Double
        let boost: Double?
        let sheet: String
        let blurb: String?
        let stats: BreedStats?
    }

    /// Where characters are looked for: inside the app bundle, then in the user's Application Support folder.
    private static var searchFolders: [URL] {
        var folders: [URL] = []
        if let bundled = Bundle.main.resourceURL?.appendingPathComponent("Characters") { folders.append(bundled) }
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        folders.append(support.appendingPathComponent("GoblinCamp/Characters"))
        return folders
    }

    private static func loadFolders() -> [Character] {
        var result: [Character] = []
        for root in searchFolders {
            let entries = (try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)) ?? []
            for folder in entries.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
                guard let character = load(folder: folder), !result.contains(where: { $0.id == character.id }) else { continue }
                result.append(character)
            }
        }
        return result
    }

    private static func load(folder: URL) -> Character? {
        let manifestURL = folder.appendingPathComponent("manifest.json")
        guard let data = try? Data(contentsOf: manifestURL) else { return nil }
        do {
            let manifest = try JSONDecoder().decode(Manifest.self, from: data)
            guard let worker = try role(manifest.worker, frame: manifest.frame, folder: folder) else { return nil }
            let queen = try manifest.queen.flatMap { try role($0, frame: manifest.frame, folder: folder) }
            var outfits: [Outfit] = []
            for entry in manifest.queen?.outfits ?? [] {
                let sheet = Manifest.Role(sheet: entry.sheet, pixelScale: manifest.queen?.pixelScale ?? 2, walk: manifest.queen?.walk ?? manifest.worker.walk, outfits: nil, poses: manifest.queen?.poses)
                if let sprites = try role(sheet, frame: manifest.frame, folder: folder) { outfits.append(Outfit(id: entry.id, name: entry.name, role: sprites)) }
            }
            var breeds: [Breed] = []
            for entry in manifest.breeds ?? [] {
                // a breed shares the worker's animation layout and pixel scale, and brings its own sheet
                let sheet = Manifest.Role(sheet: entry.sheet, pixelScale: manifest.worker.pixelScale, walk: manifest.worker.walk, outfits: nil, poses: nil)
                guard let sprites = try role(sheet, frame: manifest.frame, folder: folder) else { continue }
                breeds.append(Breed(id: entry.id, name: entry.name, weight: entry.weight, prosperityBoost: entry.boost ?? 0,
                                    stats: entry.stats ?? BreedStats(), sprites: sprites, blurb: entry.blurb ?? ""))
            }
            if breeds.isEmpty {
                breeds = [Breed(id: "common", name: "平民", weight: 100, prosperityBoost: 0, stats: BreedStats(), sprites: worker, blurb: "")]
            }
            let icon = manifest.icon.flatMap { NSImage(contentsOf: folder.appendingPathComponent($0)) }
            return Character(id: manifest.id, name: manifest.name, noun: manifest.noun, emoji: manifest.emoji,
                             nestName: manifest.nestName ?? "營地", defaultMaxCount: manifest.defaultMaxCount ?? 150, breeds: breeds, queen: queen ?? worker, outfits: outfits, icon: icon)
        } catch {
            NSLog("GoblinCamp: could not load character in \(folder.lastPathComponent): \(error)")
            return nil
        }
    }

    private static func role(_ role: Manifest.Role, frame: Int, folder: URL) throws -> SpriteRole? {
        let url = folder.appendingPathComponent(role.sheet)
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil), let sheet = CGImageSourceCreateImageAtIndex(source, 0, nil),
              frame > 0, sheet.width >= frame else { return nil }
        let columns = sheet.width / frame

        func slice(_ indices: [Int]) -> [CGImage] {
            indices.compactMap { index in
                sheet.cropping(to: CGRect(x: (index % columns) * frame, y: (index / columns) * frame, width: frame, height: frame))
            }
        }
        let down = slice(role.walk["down"] ?? [])
        let up = slice(role.walk["up"] ?? role.walk["down"] ?? [])
        let side = slice(role.walk["side"] ?? role.walk["down"] ?? [])
        guard !down.isEmpty else { return nil }
        var poses: [String: [CGImage]] = [:]
        for (name, indices) in role.poses ?? [:] { poses[name] = slice(indices) }
        return SpriteRole(pixelScale: role.pixelScale, frameSize: frame,
                          frames: [.down: down, .up: up.isEmpty ? down : up,
                                   .right: side.isEmpty ? down : side,
                                   .left: (side.isEmpty ? down : side).map(mirrored)],
                          poses: poses)
    }

    /// The image flipped left to right (the art faces right; left is its mirror).
    private static func mirrored(_ image: CGImage) -> CGImage {
        guard let context = CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return image }
        context.translateBy(x: CGFloat(image.width), y: 0)
        context.scaleBy(x: -1, y: 1)
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return context.makeImage() ?? image
    }
}
