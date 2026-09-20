import AppKit

/// The pixel scenery goblins walk in front of (a forest edge or a meadow along the bottom or a side of the screen, and the grass
/// of the map window), loaded from `Resources/Scenery` and tinted by the time of day.
enum Scenery {
    enum Side: String { case bottom = "", left = "_left", right = "_right" }

    private static var cache: [String: CGImage] = [:]
    private static var raw: [String: CGImage] = [:]

    private static func load(_ name: String) -> CGImage? {
        if let hit = raw[name] { return hit }
        guard let url = Bundle.main.resourceURL?.appendingPathComponent("Scenery/\(name).png"),
              let source = CGImageSourceCreateWithURL(url as CFURL, nil), let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { return nil }
        raw[name] = image
        return image
    }

    /// A colour laid over the scenery at dusk and at night (nil during the day). `CAMP_HOUR` fakes the time (tests).
    static func tint(hour: Int) -> (color: NSColor, alpha: CGFloat)? {
        switch hour {
        case 6..<17: return nil
        case 17..<19: return (NSColor(calibratedRed: 1.0, green: 0.55, blue: 0.2, alpha: 1), 0.14)
        case 19..<21: return (NSColor(calibratedRed: 0.35, green: 0.2, blue: 0.5, alpha: 1), 0.28)
        case 21..<24, 0..<5: return (NSColor(calibratedRed: 0.04, green: 0.08, blue: 0.3, alpha: 1), 0.42)
        default: return (NSColor(calibratedRed: 1.0, green: 0.6, blue: 0.6, alpha: 1), 0.10) // dawn
        }
    }

    static var currentHour: Int {
        if let forced = ProcessInfo.processInfo.environment["CAMP_HOUR"], let h = Int(forced) { return h }
        return Calendar.current.component(.hour, from: Date())
    }

    /// The strip heights (in points) the forest comes in; the meadow is one thin size.
    static let sizes = [30, 42, 54, 64]

    /// The tile for a style ("forest" or "meadow"), a strip `size` points thick and a side, tinted for the hour.
    static func tile(style: String, size: Int = 42, side: Side, hour: Int = currentHour) -> CGImage? {
        if style == "meadow" { return image(named: "meadow" + side.rawValue, hour: hour) }
        let pick = sizes.min { abs($0 - size) < abs($1 - size) } ?? 42
        return image(named: "forest-\(pick)" + side.rawValue, hour: hour)
    }

    static func ground(hour: Int = currentHour) -> CGImage? { image(named: "ground", hour: hour) }

    private static func image(named name: String, hour: Int) -> CGImage? {
        guard let base = load(name) else { return nil }
        guard let tint = tint(hour: hour) else { return base }
        let key = "\(name)@\(hour)"
        if let hit = cache[key] { return hit }
        guard let context = CGContext(data: nil, width: base.width, height: base.height, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return base }
        let rect = CGRect(x: 0, y: 0, width: base.width, height: base.height)
        context.draw(base, in: rect)
        context.setBlendMode(.sourceAtop) // colour only the pixels that exist
        context.setFillColor(tint.color.withAlphaComponent(tint.alpha).cgColor)
        context.fill(rect)
        let result = context.makeImage() ?? base
        cache[key] = result
        return result
    }

    /// Draws `tile` repeated along `rect`, one art pixel per point (the same size as the goblins), the ground on the outside edge.
    static func drawStrip(_ tile: CGImage, in rect: CGRect, side: Side, into ctx: CGContext, scale: CGFloat = 1) {
        ctx.saveGState()
        ctx.clip(to: rect)
        ctx.interpolationQuality = .none
        let vertical = side != .bottom
        let along = CGFloat(vertical ? tile.height : tile.width)
        let w = CGFloat(tile.width) * scale, h = CGFloat(tile.height) * scale
        if vertical {
            let x = side == .right ? rect.maxX - w : rect.minX
            var y = rect.minY
            while y < rect.maxY { ctx.draw(tile, in: CGRect(x: x, y: y, width: w, height: h)); y += along * scale }
        } else {
            var x = rect.minX
            while x < rect.maxX { ctx.draw(tile, in: CGRect(x: x, y: rect.minY, width: w, height: h)); x += along * scale }
        }
        ctx.restoreGState()
    }

    /// Fills `rect` with the repeated grass tile.
    static func fillGround(_ tile: CGImage, in rect: CGRect, scale: CGFloat = 2, into ctx: CGContext) {
        ctx.saveGState()
        ctx.clip(to: rect)
        ctx.interpolationQuality = .none
        let size = CGFloat(tile.width) * scale
        var y = rect.minY
        while y < rect.maxY {
            var x = rect.minX
            while x < rect.maxX { ctx.draw(tile, in: CGRect(x: x, y: y, width: size, height: size)); x += size }
            y += size
        }
        ctx.restoreGState()
    }
}
