import AppKit

/// A pond with a natural outline: a random blob (no two are alike) with a sandy bank, stones, reeds, lily pads, and now and then a
/// little island in the middle. Made from a seed; the goblins walk around it (`blocks`). Drawn as a small pixel picture.
/// What the water looks like: clear (blue), frozen over (snow biome) or murky (swamp).
enum WaterStyle {
    case clear, ice, murk

    typealias RGB = (UInt8, UInt8, UInt8)
    /// Shallow to deep, and the pale line where the water meets the land.
    var shades: (RGB, RGB, RGB, RGB) {
        switch self {
        case .clear: return ((128, 196, 208), (84, 160, 200), (58, 128, 188), (40, 100, 168))
        case .ice: return ((226, 242, 250), (200, 228, 244), (176, 214, 238), (156, 200, 230))
        case .murk: return ((112, 142, 98), (82, 114, 84), (58, 88, 66), (44, 68, 54))
        }
    }
    var edge: RGB { self == .ice ? (250, 253, 255) : self == .murk ? (150, 176, 120) : (170, 218, 222) }
    /// The bank: sand, snow, or mud.
    var bank: (RGB, RGB) { self == .ice ? ((236, 242, 248), (206, 218, 232)) : self == .murk ? ((104, 92, 62), (80, 70, 48)) : ((168, 148, 100), (128, 106, 70)) }
    var padColor: RGB { self == .murk ? (70, 130, 60) : (46, 148, 72) }
}

final class Pond: Obstacle {
    let rect: CGRect
    /// One art pixel, in points.
    static let cell: CGFloat = 2
    private static let margin = 5 // cells of bank around the water

    let cols: Int
    let rows: Int
    private(set) var water: [Bool]
    private(set) var island: [Bool]
    private var depth: [Int]
    private var bank: [Bool]
    private let seed: UInt64
    private(set) var image: CGImage?
    /// Where lily pads and ripples are (in points, relative to the padded picture).
    private(set) var glints: [CGPoint] = []

    /// The area the picture covers: the water's box plus a margin for the bank.
    var picture: CGRect { rect.insetBy(dx: -CGFloat(Pond.margin) * Pond.cell, dy: -CGFloat(Pond.margin) * Pond.cell) }

    private struct Random {
        var state: UInt64
        mutating func next() -> Double {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            var z = state
            z = (z ^ (z >> 33)) &* 0xff51afd7ed558ccd
            z = (z ^ (z >> 33)) &* 0xc4ceb9fe1a85ec53
            return Double((z ^ (z >> 33)) >> 11) / Double(1 << 53)
        }
        mutating func range(_ a: Double, _ b: Double) -> Double { a + (b - a) * next() }
    }

    let style: WaterStyle

    init(seed: UInt64, rect: CGRect, style: WaterStyle = .clear) {
        self.style = style
        self.seed = seed
        self.rect = rect
        cols = max(8, Int(rect.width / Pond.cell)) + 2 * Pond.margin
        rows = max(8, Int(rect.height / Pond.cell)) + 2 * Pond.margin
        water = [Bool](repeating: false, count: cols * rows)
        island = water
        bank = water
        depth = [Int](repeating: 0, count: cols * rows)
        build()
    }

    private func idx(_ c: Int, _ r: Int) -> Int { r * cols + c }
    private func inside(_ c: Int, _ r: Int) -> Bool { c >= 0 && r >= 0 && c < cols && r < rows }

    /// A wobbly radius around the middle: a few waves of different sizes plus one bump (a bay or a point).
    private func blob(_ rng: inout Random, base: Double, waves: Int, wobble: Double) -> (Double) -> Double {
        var amps: [(Double, Double, Double)] = []
        for k in 2...(waves + 1) { amps.append((Double(k), rng.range(0, 2 * .pi), rng.range(0.4, 1) * wobble / Double(k - 1))) }
        let bumpAt = rng.range(0, 2 * .pi), bump = rng.range(-0.22, 0.28) * wobble * 4
        return { theta in
            var r = base
            for (k, phase, a) in amps { r += a * cos(k * theta + phase) }
            let d = atan2(sin(theta - bumpAt), cos(theta - bumpAt))
            return r + bump * exp(-d * d / 0.35)
        }
    }

    private func build() {
        var rng = Random(state: seed &* 2685821657736338717 &+ 12345)
        let m = Pond.margin
        let innerCols = cols - 2 * m, innerRows = rows - 2 * m
        let radius = blob(&rng, base: 0.80, waves: 5, wobble: 0.16)
        for r in 0..<innerRows {
            for c in 0..<innerCols {
                let nx = (Double(c) + 0.5 - Double(innerCols) / 2) / (Double(innerCols) / 2)
                let ny = (Double(r) + 0.5 - Double(innerRows) / 2) / (Double(innerRows) / 2)
                if (nx * nx + ny * ny).squareRoot() < radius(atan2(ny, nx)) { water[idx(c + m, r + m)] = true }
            }
        }
        smooth(times: 2)
        keepLargest()
        distances()
        // sometimes a little island in the middle (only if the pond is wide and deep enough)
        if rng.next() < 0.5, let deepest = depth.enumerated().max(by: { $0.element < $1.element }), deepest.element >= 8 {
            let cx = Double(deepest.offset % cols), cy = Double(deepest.offset / cols)
            let size = min(Double(deepest.element) * 0.6, 12)
            let shape = blob(&rng, base: 1, waves: 3, wobble: 0.22)
            for r in 0..<rows {
                for c in 0..<cols where water[idx(c, r)] {
                    let dx = Double(c) - cx, dy = (Double(r) - cy) * 1.15
                    if (dx * dx + dy * dy).squareRoot() < size * shape(atan2(dy, dx)) { water[idx(c, r)] = false; island[idx(c, r)] = true }
                }
            }
            distances()
        }
        // the bank: the ring of cells around the water (and around the island), a little wider in places
        for r in 0..<rows {
            for c in 0..<cols where !water[idx(c, r)] && !island[idx(c, r)] {
                var near = 99
                for dr in -3...3 { for dc in -3...3 where inside(c + dc, r + dr) && water[idx(c + dc, r + dr)] { near = min(near, max(abs(dr), abs(dc))) } }
                let reach = 1 + Int(rng.next() * 2.4)
                bank[idx(c, r)] = near <= reach
            }
        }
        for r in 0..<rows { for c in 0..<cols where island[idx(c, r)] {
            // the water around an island is shallow
            depth[idx(c, r)] = 0
        } }
        var pads: [CGPoint] = []
        for _ in 0..<(style == .ice ? 0 : Int(rng.range(2, 5))) {
            for _ in 0..<30 {
                let c = Int(rng.range(0, Double(cols))), r = Int(rng.range(0, Double(rows)))
                if inside(c, r), water[idx(c, r)], depth[idx(c, r)] >= 3 { pads.append(CGPoint(x: c, y: r)); break }
            }
        }
        renderState = (rng, pads)
        var copy = rng
        render(&copy, pads: pads, style: style, keep: true)
    }

    private var renderState: (Random, [CGPoint])?
    private var frozenImage: CGImage?

    /// The picture with another kind of water (a pond that freezes over in winter): the same shape, stones and reeds, just iced.
    func image(frozen: Bool) -> CGImage? {
        guard frozen, style != .ice else { return image }
        if let frozenImage { return frozenImage }
        guard let (state, pads) = renderState else { return image }
        var copy = state
        render(&copy, pads: pads, style: .ice, keep: false)
        return frozenImage
    }

    /// Fills in single-cell dents and removes single-cell spits.
    private func smooth(times: Int) {
        for _ in 0..<times {
            var next = water
            for r in 0..<rows {
                for c in 0..<cols {
                    var n = 0
                    for dr in -1...1 { for dc in -1...1 where (dr != 0 || dc != 0) && inside(c + dc, r + dr) && water[idx(c + dc, r + dr)] { n += 1 } }
                    if n >= 5 { next[idx(c, r)] = true } else if n <= 2 { next[idx(c, r)] = false }
                }
            }
            water = next
        }
    }

    /// Only the biggest piece of water stays.
    private func keepLargest() {
        var seen = [Int](repeating: -1, count: cols * rows)
        var sizes: [Int] = []
        for start in 0..<(cols * rows) where water[start] && seen[start] < 0 {
            var stack = [start], count = 0
            seen[start] = sizes.count
            while let i = stack.popLast() {
                count += 1
                let c = i % cols, r = i / cols
                for (dc, dr) in [(1, 0), (-1, 0), (0, 1), (0, -1)] where inside(c + dc, r + dr) {
                    let j = idx(c + dc, r + dr)
                    if water[j], seen[j] < 0 { seen[j] = sizes.count; stack.append(j) }
                }
            }
            sizes.append(count)
        }
        guard let best = sizes.enumerated().max(by: { $0.element < $1.element })?.offset else { return }
        for i in 0..<(cols * rows) where water[i] && seen[i] != best { water[i] = false }
    }

    /// How far each water cell is from the shore.
    private func distances() {
        var queue: [Int] = []
        for i in 0..<(cols * rows) { depth[i] = water[i] ? 999 : 0 }
        for i in 0..<(cols * rows) where water[i] {
            let c = i % cols, r = i / cols
            for (dc, dr) in [(1, 0), (-1, 0), (0, 1), (0, -1)] where !inside(c + dc, r + dr) || !water[idx(c + dc, r + dr)] { depth[i] = 1; queue.append(i); break }
        }
        var head = 0
        while head < queue.count {
            let i = queue[head]; head += 1
            let c = i % cols, r = i / cols
            for (dc, dr) in [(1, 0), (-1, 0), (0, 1), (0, -1)] where inside(c + dc, r + dr) {
                let j = idx(c + dc, r + dr)
                if water[j], depth[j] > depth[i] + 1 { depth[j] = depth[i] + 1; queue.append(j) }
            }
        }
    }

    private func render(_ rng: inout Random, pads: [CGPoint], style: WaterStyle, keep: Bool) {
        var pixels = [UInt8](repeating: 0, count: cols * rows * 4)
        func put(_ c: Int, _ r: Int, _ rgb: (UInt8, UInt8, UInt8), _ a: UInt8 = 255) {
            guard inside(c, r) else { return }
            // image rows run from the top
            let o = ((rows - 1 - r) * cols + c) * 4
            pixels[o] = rgb.0; pixels[o + 1] = rgb.1; pixels[o + 2] = rgb.2; pixels[o + 3] = a
        }
        for r in 0..<rows {
            for c in 0..<cols {
                let i = idx(c, r)
                if water[i] {
                    let d = depth[i]
                    let shades = style.shades
                    put(c, r, d <= 1 ? shades.0 : d <= 3 ? shades.1 : d <= 6 ? shades.2 : shades.3)
                    if d == 1 { put(c, r, style.edge) } // a pale line where the water meets the land
                } else if island[i] {
                    var edge = false
                    for (dc, dr) in [(1, 0), (-1, 0), (0, 1), (0, -1)] where inside(c + dc, r + dr) && !island[idx(c + dc, r + dr)] { edge = true }
                    put(c, r, edge ? (150, 132, 88) : ((c + r * 3) % 7 == 0 ? (92, 160, 84) : (70, 140, 74)))
                } else if bank[i] {
                    put(c, r, (c * 5 + r * 3) % 9 == 0 ? style.bank.1 : style.bank.0, 255)
                }
            }
        }
        // stones: a few on the bank and in the shallows, some in little groups, with a shadow underneath
        var spots: [(Int, Int)] = []
        for r in 1..<(rows - 1) { for c in 1..<(cols - 1) where bank[idx(c, r)] || (water[idx(c, r)] && depth[idx(c, r)] <= 2) { spots.append((c, r)) } }
        for k in stride(from: spots.count - 1, to: 0, by: -1) { spots.swapAt(k, Int(rng.next() * Double(k + 1))) }
        var placed: [(Int, Int)] = []
        for (c, r) in spots where placed.count < 3 + Int(rng.range(0, 5)) {
            if placed.contains(where: { abs($0.0 - c) < 7 && abs($0.1 - r) < 7 }) { continue }
            placed.append((c, r))
            let group = rng.next() < 0.4 ? 3 : 1
            for g in 0..<group {
                let gc = c + g * 3 - (group - 1) * 1, gr = r + (g % 2)
                let w = 2 + Int(rng.next() * 3), h = w > 2 ? 2 : 1 + Int(rng.next() * 2)
                for dr in 0..<h { for dc in 0..<w where inside(gc + dc, gr + dr) && !island[idx(gc + dc, gr + dr)] {
                    let top = dr == h - 1
                    put(gc + dc, gr + dr, top ? (176, 176, 182) : (128, 128, 136))
                } }
                for dc in 0..<w where inside(gc + dc, gr - 1) && !island[idx(gc + dc, gr - 1)] { put(gc + dc, gr - 1, (70, 78, 70), 150) }
                put(gc, gr + h - 1, (206, 206, 210))
            }
        }
        // reeds along the bank
        var reeds: [(Int, Int)] = []
        for r in 0..<rows { for c in 0..<cols where bank[idx(c, r)] {
            var touches = false
            for (dc, dr) in [(1, 0), (-1, 0), (0, 1), (0, -1)] where inside(c + dc, r + dr) && water[idx(c + dc, r + dr)] { touches = true }
            if touches, rng.next() < 0.12 { reeds.append((c, r)) }
        } }
        for (c, r) in reeds.prefix(12) {
            let h = 3 + Int(rng.next() * 3)
            for k in 0..<h { put(c, r + k, (58, 118, 60)) }
            put(c, r + h, (140, 96, 54)) // the brown head
            if rng.next() < 0.5 { for k in 0..<max(2, h - 1) { put(c + 1, r + k, (72, 140, 72)) } }
        }
        for p in pads {
            let c = Int(p.x), r = Int(p.y)
            for (dc, dr) in [(0, 0), (1, 0), (2, 0), (0, 1), (1, 1)] where inside(c + dc, r + dr) && water[idx(c + dc, r + dr)] { put(c + dc, r + dr, style.padColor) }
            if style != .ice { put(c + 1, r + 1, (240, 140, 170)) }
            if keep { glints.append(CGPoint(x: CGFloat(c) * Pond.cell, y: CGFloat(r) * Pond.cell)) }
        }
        // a few bushes on the island
        if island.contains(true) {
            let cells = island.enumerated().filter { $0.element }.map { $0.offset }
            for i in cells where rng.next() < 0.05 {
                let c = i % cols, r = i / cols
                for (dc, dr) in [(0, 0), (1, 0), (0, 1), (1, 1), (0, 2)] where inside(c + dc, r + dr) && island[idx(c + dc, r + dr)] { put(c + dc, r + dr, (30, 100, 50)) }
                put(c, r + 2, (140, 96, 54))
            }
        }
        // the glints that twinkle
        for _ in 0..<10 {
            let c = Int(rng.range(0, Double(cols))), r = Int(rng.range(0, Double(rows)))
            if inside(c, r), water[idx(c, r)], depth[idx(c, r)] >= 3, keep { glints.append(CGPoint(x: CGFloat(c) * Pond.cell, y: CGFloat(r) * Pond.cell)) }
        }
        pixels.withUnsafeMutableBytes { buffer in
            let ctx = CGContext(data: buffer.baseAddress, width: cols, height: rows, bitsPerComponent: 8, bytesPerRow: cols * 4,
                                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            if keep { image = ctx?.makeImage() } else { frozenImage = ctx?.makeImage() }
        }
    }

    /// Places to fish from: a spot on the bank right at the water's edge and the water point to cast at (a few steps out), spread round the shore.
    private(set) lazy var fishingSpots: [(spot: CGPoint, water: CGPoint)] = {
        let pic = picture
        var found: [(CGPoint, CGPoint)] = []
        for r in 1..<(rows - 1) {
            for c in 1..<(cols - 1) where bank[idx(c, r)] {
                for (dc, dr) in [(1, 0), (-1, 0), (0, 1), (0, -1)] where water[idx(c + dc, r + dr)] {
                    // only where it is deep a few cells out, and not too many (every 4th cell of the shore)
                    guard (c + r) % 4 == 0, inside(c + dc * 4, r + dr * 4), water[idx(c + dc * 4, r + dr * 4)] else { continue }
                    let spot = CGPoint(x: pic.minX + (CGFloat(c) + 0.5) * Pond.cell, y: pic.minY + (CGFloat(r) + 0.5) * Pond.cell)
                    let target = CGPoint(x: pic.minX + (CGFloat(c + dc * 4) + 0.5) * Pond.cell, y: pic.minY + (CGFloat(r + dr * 4) + 0.5) * Pond.cell)
                    found.append((spot, target))
                    break
                }
            }
        }
        return found
    }()

    /// Whether a goblin at `p` (in the same coordinates as `rect`) would be in the water or on the island (keeping a cell or two away).
    func blocks(_ p: CGPoint, margin: CGFloat = 3) -> Bool {
        let pic = picture
        guard pic.insetBy(dx: -margin, dy: -margin).contains(p) else { return false }
        let steps = [(0.0, 0.0), (1.0, 0.0), (-1.0, 0.0), (0.0, 1.0), (0.0, -1.0)]
        for (dx, dy) in steps {
            let c = Int((p.x + CGFloat(dx) * margin - pic.minX) / Pond.cell), r = Int((p.y + CGFloat(dy) * margin - pic.minY) / Pond.cell)
            if inside(c, r), water[idx(c, r)] || island[idx(c, r)] { return true }
        }
        return false
    }
}
