import CoreGraphics

/// Which screens the goblins live on. With several monitors the player can keep them to the camp's own screen (the default),
/// let them roam all screens, or tick particular screens, so the other monitors stay clear for work.
enum ScreenChoice {
    struct Screen: Equatable {
        let name: String
        let frame: CGRect
        /// The part of the screen not taken by the menu bar and the Dock.
        var visible: CGRect

        init(name: String, frame: CGRect, visible: CGRect? = nil) {
            self.name = name
            self.frame = frame
            self.visible = visible ?? frame
        }
    }

    /// Where goblins may walk on a screen: all of it, or a strip along the bottom or a side (above the Dock, under the menu bar).
    static func range(for screen: Screen, mode: String, size: Double) -> CGRect {
        let v = screen.visible
        let s = CGFloat(size)
        switch mode {
        case "bottom": return CGRect(x: v.minX, y: v.minY, width: v.width, height: min(s, v.height))
        // down a side the strip is at least 42 wide, so the camp, the princess and the goblins fit in it
        case "right": return CGRect(x: v.maxX - min(max(s, 42), v.width), y: v.minY, width: min(max(s, 42), v.width), height: v.height)
        case "left": return CGRect(x: v.minX, y: v.minY, width: min(max(s, 42), v.width), height: v.height)
        default: return screen.frame
        }
    }

    /// Goblins walk on the meadow in front of the trees: the outer half of the strip (its screen-edge side).
    static func walkBand(of strip: CGRect, mode: String) -> CGRect {
        switch mode {
        case "bottom": return CGRect(x: strip.minX, y: strip.minY, width: strip.width, height: min(strip.height, max(30, strip.height * 0.7)))
        case "right", "left": return strip // the whole width is grass down the side, so they may walk all over it
        default: return strip
        }
    }

    /// A strip is much longer than it is wide: animals and the carriers come in from its two ends, not through its long side.
    static func isStrip(_ rect: CGRect) -> Bool { rect.width >= rect.height * 2 || rect.height >= rect.width * 2 }

    /// `mode`: "nest" (only the screen the camp is on), "all", or "list" (the screens named in `names`).
    /// Always returns at least one screen; with one screen, that one.
    static func allowed(_ screens: [Screen], nest: CGPoint?, mode: String, names: [String]) -> [Screen] {
        guard screens.count > 1 else { return screens }
        switch mode {
        case "all":
            return screens
        case "list":
            let picked = screens.filter { names.contains($0.name) }
            return picked.isEmpty ? screens : picked
        default:
            if let nest, let home = screens.first(where: { $0.frame.contains(nest) }) { return [home] }
            return [screens[0]]
        }
    }
}
