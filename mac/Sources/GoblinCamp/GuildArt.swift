import AppKit
import ImageIO

/// The guild hall's art for the Mac's own hall (GUILD.md): the avatars' layers (mac/tools/make_avatars.py →
/// Resources/Avatars) put together per look — key colours swapped for its skin, hair and eye flame, one outline round the
/// whole figure, the effects on top, the spirit's float — and the hall's floors, walls, furniture and decorations
/// (Resources/Guild). The same steps as the phone's (pwa/app/composables/useAvatarArt.ts), so both draw the same avatar.
final class GuildArt {
    static let shared = GuildArt()

    struct Anim { let frames: [Int]; let fps: Double; let loop: Bool }
    struct Piece {
        let image: CGImage; let w: Int; let h: Int; let frames: Int; let fps: Double; let anchorX: Double; let anchorY: Double; let flat: Bool; let wall: Bool; let ceiling: Bool
        /// Where a sitter's feet go (sprite pixels; nil: not for sitting), and whether it is one of the little living things.
        var seat: (x: Double, y: Double)? = nil
        var living = false
        /// A desk one works at; water one drinks beside.
        var desk = false
        var drink = false
    }

    /// One kind of decoration as the catalog lists it (shared/src/guild-decor-catalog.ts, written for the Mac as decor.json).
    struct DecorKind {
        let id: String; let name: String; let category: String; let race: String?; let size: Int; let level: Int
        /// A holiday piece: the season it can be put down in (nil: always).
        let season: String?
    }

    private(set) var ready = false
    private(set) var kinds: [DecorKind] = []
    // the avatars
    private(set) var frameW = 32, frameH = 40, frames = 1
    private(set) var anchorX = 16.0, anchorY = 37.0
    private var layers: [String] = []
    private var anims: [String: [String: Anim]] = [:]
    private var files: [String: Any] = [:]
    private var bodyType: [String: String] = [:]
    private var outline: [String: String] = [:]
    private var frameOffset: [String: [Int]] = [:]
    private var recolor: [String: (keys: [String], options: [String: [String]])] = [:]
    // the hall
    private(set) var tile = 16
    private var floors: [String: CGImage] = [:]
    private var walls: [String: CGImage] = [:]
    private var furniture: [String: Piece] = [:]
    private var decor: [String: Piece] = [:]

    private var avatarsRoot: URL?
    private var hallRoot: URL?
    private var images: [String: CGImage] = [:]
    private var looks: [GuildInfo.Avatar: CGImage] = [:]
    private var frameCache: [String: CGImage] = [:]

    private init() {
        load()
    }

    /// Where the art is: inside the app, else next to it in the repository (`swift run` while working on it).
    private static func folder(_ name: String) -> URL? {
        var candidates: [URL] = []
        if let bundled = Bundle.main.resourceURL?.appendingPathComponent(name) { candidates.append(bundled) }
        let here = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        candidates.append(here.appendingPathComponent("../../Resources/\(name)").standardizedFileURL)
        return candidates.first { FileManager.default.fileExists(atPath: $0.appendingPathComponent("manifest.json").path) }
    }

    private func json(_ url: URL) -> [String: Any]? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }

    private func image(_ url: URL) -> CGImage? {
        if let hit = images[url.path] { return hit }
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil), let made = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
        images[url.path] = made
        return made
    }

    private func load() {
        guard let a = GuildArt.folder("Avatars"), let h = GuildArt.folder("Guild"),
              let am = json(a.appendingPathComponent("manifest.json")), let hm = json(h.appendingPathComponent("manifest.json")) else { return }
        avatarsRoot = a
        hallRoot = h
        frameW = am["frameW"] as? Int ?? 32
        frameH = am["frameH"] as? Int ?? 40
        frames = am["frames"] as? Int ?? 1
        if let anchor = am["anchor"] as? [String: Any] {
            anchorX = (anchor["x"] as? NSNumber)?.doubleValue ?? 16
            anchorY = (anchor["y"] as? NSNumber)?.doubleValue ?? 37
        }
        layers = am["layers"] as? [String] ?? []
        files = am["files"] as? [String: Any] ?? [:]
        bodyType = am["bodyType"] as? [String: String] ?? [:]
        outline = am["outline"] as? [String: String] ?? [:]
        frameOffset = am["frameOffset"] as? [String: [Int]] ?? [:]
        for (name, dirs) in am["anims"] as? [String: [String: [String: Any]]] ?? [:] {
            anims[name] = dirs.mapValues { Anim(frames: $0["frames"] as? [Int] ?? [0], fps: ($0["fps"] as? NSNumber)?.doubleValue ?? 4, loop: $0["loop"] as? Bool ?? true) }
        }
        for (channel, value) in am["recolor"] as? [String: [String: Any]] ?? [:] {
            recolor[channel] = (value["keys"] as? [String] ?? [], value["options"] as? [String: [String]] ?? [:])
        }

        tile = hm["tile"] as? Int ?? 16
        for (id, file) in hm["floors"] as? [String: String] ?? [:] { floors[id] = image(h.appendingPathComponent(file)) }
        for (id, wall) in hm["walls"] as? [String: [String: Any]] ?? [:] {
            if let file = wall["file"] as? String { walls[id] = image(h.appendingPathComponent(file)) }
        }
        for (id, f) in hm["furniture"] as? [String: [String: Any]] ?? [:] {
            guard let file = f["file"] as? String, let img = image(h.appendingPathComponent(file)) else { continue }
            let anchor = f["anchor"] as? [String: Any] ?? [:]
            furniture[id] = Piece(image: img, w: f["w"] as? Int ?? img.width, h: f["h"] as? Int ?? img.height, frames: f["frames"] as? Int ?? 1,
                                  fps: (f["fps"] as? NSNumber)?.doubleValue ?? 0, anchorX: (anchor["x"] as? NSNumber)?.doubleValue ?? 0,
                                  anchorY: (anchor["y"] as? NSNumber)?.doubleValue ?? 0, flat: f["flat"] as? Bool ?? false, wall: f["wall"] as? Bool ?? false, ceiling: false)
        }
        // the decorations stand on their bottom middle (shared/src/guild-decor-catalog.ts, written for the Mac as decor.json)
        if let data = try? Data(contentsOf: h.appendingPathComponent("decor.json")), let all = (try? JSONSerialization.jsonObject(with: data)) as? [String: [String: Any]] {
            for (id, d) in all {
                guard let file = d["file"] as? String, let img = image(h.appendingPathComponent(file)) else { continue }
                let w = d["w"] as? Int ?? img.width, hh = d["h"] as? Int ?? img.height
                let seat = (d["seat"] as? [String: Any]).flatMap { s -> (x: Double, y: Double)? in
                    guard let x = (s["x"] as? NSNumber)?.doubleValue, let y = (s["y"] as? NSNumber)?.doubleValue else { return nil }
                    return (x, y)
                }
                kinds.append(DecorKind(id: id, name: d["name"] as? String ?? id, category: d["category"] as? String ?? "", race: d["race"] as? String,
                                       size: d["size"] as? Int ?? 1, level: d["level"] as? Int ?? 1, season: d["season"] as? String))
                decor[id] = Piece(image: img, w: w, h: hh, frames: d["frames"] as? Int ?? 1, fps: (d["fps"] as? NSNumber)?.doubleValue ?? 0,
                                  anchorX: Double(w) / 2, anchorY: Double(hh), flat: d["flat"] as? Bool ?? false, wall: d["wall"] as? Bool ?? false, ceiling: d["ceiling"] as? Bool ?? false,
                                  seat: seat, living: d["living"] as? Bool ?? (d["category"] as? String == "會動的"),
                                  desk: d["desk"] as? Bool ?? false, drink: d["drink"] as? Bool ?? false)
            }
        }
        kinds.sort { $0.level != $1.level ? $0.level < $1.level : $0.name < $1.name }
        ready = !layers.isEmpty && !floors.isEmpty
    }

    /// One colour standing for a recolouring option (its middle shade), for the avatar maker's dots; `option` is as the options
    /// list it (a skin's is the race, sex and name together, as the art's manifest keys it).
    func swatch(_ channel: String, _ option: String) -> NSColor? {
        guard let hexes = recolor[channel]?.options[option], !hexes.isEmpty, let c = GuildArt.rgb(hexes[min(1, hexes.count - 1)]) else { return nil }
        return NSColor(calibratedRed: CGFloat(c.0) / 255, green: CGFloat(c.1) / 255, blue: CGFloat(c.2) / 255, alpha: 1)
    }

    func floorTile(_ id: String) -> CGImage? { floors[id] ?? floors["oak"] }
    func wallPiece(_ id: String) -> CGImage? { walls[id] ?? walls["stone"] }
    func furniturePiece(_ id: String) -> Piece? { furniture[id] }
    func decorPiece(_ id: String) -> Piece? { decor[id] }

    /// One frame of a piece's strip.
    func frame(of piece: Piece, at t: Double) -> CGImage? {
        let f = piece.frames > 1 ? Int(t * (piece.fps > 0 ? piece.fps : 3)) % piece.frames : 0
        let key = PieceFrame(image: ObjectIdentifier(piece.image), index: f)
        if let hit = pieceFrames[key] { return hit }
        let made = piece.image.cropping(to: CGRect(x: f * piece.w, y: 0, width: piece.w, height: piece.h))
        pieceFrames[key] = made
        return made
    }

    /// A frame of a decoration's strip (asked for every piece at every frame, so not a string key).
    private struct PieceFrame: Hashable { let image: ObjectIdentifier; let index: Int }
    private var pieceFrames: [PieceFrame: CGImage] = [:]

    /// Which frame of the strip `anim` facing `dir` shows `t` seconds in.
    func frameIndex(anim: String, dir: String, t: Double) -> Int {
        guard let a = anims[anim]?[dir] ?? anims[anim]?["front"] ?? anims["idle"]?["front"], !a.frames.isEmpty else { return 0 }
        let step = Int(floor(max(0, t) * a.fps))
        return a.frames[a.loop ? step % a.frames.count : min(step, a.frames.count - 1)]
    }

    /// One frame of an avatar.
    func avatarFrame(_ avatar: GuildInfo.Avatar, _ index: Int) -> CGImage? {
        let key = "\(avatar.hashValue)@\(index)"
        if let hit = frameCache[key] { return hit }
        guard let strip = look(avatar), let made = strip.cropping(to: CGRect(x: index * frameW, y: 0, width: frameW, height: frameH)) else { return nil }
        frameCache[key] = made
        return made
    }

    // MARK: Putting an avatar together

    private func file(_ layer: String, _ key: String) -> URL? {
        guard let root = avatarsRoot, let name = (files[layer] as? [String: String])?[key] else { return nil }
        return root.appendingPathComponent(name)
    }

    private static func rgb(_ hex: String) -> (UInt8, UInt8, UInt8)? {
        let s = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        guard s.count == 6, let v = UInt32(s, radix: 16) else { return nil }
        return (UInt8(v >> 16 & 0xff), UInt8(v >> 8 & 0xff), UInt8(v & 0xff))
    }

    private func look(_ a: GuildInfo.Avatar) -> CGImage? {
        if let hit = looks[a] { return hit }
        guard let root = avatarsRoot else { return nil }
        let who = "\(a.race)_\(a.sex)"
        let type = bodyType[who] ?? a.race
        let pick: [String: URL?] = [
            "hair_back": file("hair_back", "\(who)_\(a.hair)"),
            "body": file("body", "\(who)_\(a.face)"),
            "bottom": file("bottom", "\(who)_default"),
            "top": file("top", "\(who)_default"),
            "shoes": file("shoes", "\(who)_default"),
            "brows": file("brows", "\(type)_\(a.brows)"),
            "eyes": file("eyes", "\(type)_\(a.eyes)"),
            "mouth": file("mouth", "\(type)_\(a.mouth)"),
            "hair_front": file("hair_front", "\(who)_\(a.hair)"),
        ]
        let w = frameW * frames, h = frameH
        guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.interpolationQuality = .none
        for layer in layers where layer != "fx" {
            if let url = pick[layer] ?? nil, let img = image(url) { ctx.draw(img, in: CGRect(x: 0, y: 0, width: img.width, height: img.height)) }
        }
        guard let data = ctx.data?.assumingMemoryBound(to: UInt8.self) else { return nil }
        // the key colours swapped for this look's own
        var swaps: [((UInt8, UInt8, UInt8), (UInt8, UInt8, UInt8))] = []
        func add(_ channel: String, _ option: String?) {
            guard let r = recolor[channel], let option, let to = r.options[option] else { return }
            for (i, k) in r.keys.enumerated() where i < to.count {
                if let from = GuildArt.rgb(k), let into = GuildArt.rgb(to[i]) { swaps.append((from, into)) }
            }
        }
        add("skin", "\(who)_\(a.skin)")
        add("hair", a.hairColor)
        add("flame", a.flame)
        let count = w * h
        if !swaps.isEmpty {
            for i in 0..<count where data[i * 4 + 3] == 255 {
                let p = i * 4
                for (from, to) in swaps where data[p] == from.0 && data[p + 1] == from.1 && data[p + 2] == from.2 {
                    data[p] = to.0; data[p + 1] = to.1; data[p + 2] = to.2
                    break
                }
            }
        }
        // one outline round the whole figure
        if let line = outline[who].flatMap(GuildArt.rgb) {
            var edge: [Int] = []
            func solid(_ x: Int, _ y: Int) -> Bool { x >= 0 && y >= 0 && x < w && y < h && data[(y * w + x) * 4 + 3] > 0 }
            for y in 0..<h {
                for x in 0..<w where !solid(x, y) && (solid(x - 1, y) || solid(x + 1, y) || solid(x, y - 1) || solid(x, y + 1)) { edge.append((y * w + x) * 4) }
            }
            for p in edge { data[p] = line.0; data[p + 1] = line.1; data[p + 2] = line.2; data[p + 3] = 255 }
        }
        if let fx = files["fx"] as? String, let img = image(root.appendingPathComponent(fx)) {
            ctx.draw(img, in: CGRect(x: 0, y: 0, width: img.width, height: img.height))
        }
        guard var made = ctx.makeImage() else { return nil }
        // the spirit's float: whole frames moved up a pixel now and then
        if let offsets = frameOffset[who], offsets.contains(where: { $0 != 0 }),
           let moved = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: CGColorSpaceCreateDeviceRGB(),
                                 bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) {
            moved.interpolationQuality = .none
            for f in 0..<frames {
                guard let piece = made.cropping(to: CGRect(x: f * frameW, y: 0, width: frameW, height: frameH)) else { continue }
                let dy = f < offsets.count ? offsets[f] : 0
                moved.draw(piece, in: CGRect(x: f * frameW, y: -dy, width: frameW, height: frameH)) // (the offset is down the picture; here y grows upward)
            }
            if let m = moved.makeImage() { made = m }
        }
        looks[a] = made
        return made
    }
}
