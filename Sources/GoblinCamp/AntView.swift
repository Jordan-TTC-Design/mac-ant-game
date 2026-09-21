import AppKit

final class AntView: NSView {
    let colony: Colony

    init(frame: NSRect, colony: Colony) {
        self.colony = colony
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override var isFlipped: Bool { false }
    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    /// Set for the camp window: it shows the camp's own little world (fixed origin) instead of a piece of the screen.
    var originOverride: CGPoint?
    var isMap = false
    /// This view only draws the pomodoro and the popups (the tools overlay), not the camp.
    var toolsOnly = false
    /// The strip of this screen the goblins walk in (global coordinates), when they are limited to one; drawn with scenery.
    var rangeRect: CGRect?
    var rangeSide: Scenery.Side = .bottom

    /// Global position of this view's bottom-left corner.
    private var origin: CGPoint { originOverride ?? window?.frame.origin ?? .zero }

    // MARK: Input

    override func resetCursorRects() {
        switch colony.phase {
        case .choosingNest: addCursorRect(bounds, cursor: .crosshair)
        case .editing: addCursorRect(bounds, cursor: .openHand)
        case .placingFood: addCursorRect(bounds, cursor: .crosshair)
        default: break
        }
    }

    private var draggingNest = false
    private var dragOffset = CGSize.zero

    /// How close to the nest a click must be to grab it.
    private var nestGrabRadius: CGFloat {
        if Settings.shared.campID == Camps.customID, NestImageStore.image != nil { return CGFloat(Settings.shared.nestImageWidth) / 2 + 10 }
        if let style = Camps.current {
            let stage = style.stage(forCount: colony.ants.count)
            return max(34, CGFloat(stage.image.width) * CGFloat(style.pixelScale) / 2 + 8)
        }
        return 34
    }

    /// Event position in global screen coordinates. Uses the window the drag started in, so it stays correct
    /// even when the pointer has moved onto another screen.
    private func screenLocation(of event: NSEvent) -> CGPoint {
        if let override = originOverride {
            let local = convert(event.locationInWindow, from: nil)
            return CGPoint(x: override.x + local.x, y: override.y + local.y)
        }
        return window?.convertPoint(toScreen: event.locationInWindow) ?? NSEvent.mouseLocation
    }

    override func mouseDown(with event: NSEvent) {
        switch colony.phase {
        case .choosingNest:
            let local = convert(event.locationInWindow, from: nil)
            colony.placeNest(at: CGPoint(x: origin.x + local.x, y: origin.y + local.y))
        case .placingFood:
            colony.placeFood(at: screenLocation(of: event))
        case .editing:
            guard let nest = colony.nest else { return }
            let mouse = screenLocation(of: event)
            if hypot(mouse.x - nest.x, mouse.y - nest.y) <= nestGrabRadius + 6 {
                draggingNest = true
                dragOffset = CGSize(width: nest.x - mouse.x, height: nest.y - mouse.y)
                NSCursor.closedHand.set()
            }
        default:
            break
        }
    }

    override func mouseDragged(with event: NSEvent) {
        guard draggingNest else { return }
        let mouse = screenLocation(of: event)
        colony.moveNest(to: CGPoint(x: mouse.x + dragOffset.width, y: mouse.y + dragOffset.height))
    }

    override func mouseUp(with event: NSEvent) {
        guard draggingNest else { return }
        draggingNest = false
        NSCursor.openHand.set()
        colony.nestDragEnded()
    }

    // MARK: Drawing

    /// False while this screen is on a desktop the player did not pick for the goblins.
    var showsCamp = true {
        didSet { if showsCamp != oldValue { needsDisplay = true } }
    }

    override func draw(_ dirtyRect: NSRect) {
        let drawStart = CACurrentMediaTime()
        defer { PerfGovernor.shared.recordDraw(CACurrentMediaTime() - drawStart) }
        if toolsOnly {
            drawMessage()
            drawPomodoro()
            return
        }
        if isMap {
            drawMapBackground()
            drawAtmosphere()
        }
        if colony.campHidden || !showsCamp { return } // the goblins are away
        defer { drawRain() } // over everything else
        switch colony.phase {
        case .idle:
            break
        case .choosingNest:
            if colony.nest != nil { drawColony() } // an existing colony stays visible (frozen) while picking
            drawPickHint()
        case .running:
            drawColony()
        case .editing:
            drawColony()
            drawEditOverlay()
        case .placingFood:
            drawColony()
            drawFoodHint()
        }
    }

    /// Grass and a forest edge for the camp window.
    /// The ground and everything on it is drawn once into a picture (`TerrainScene.render`) and only made again when the place, the window
    /// size or the hour of the day changes; the water sparkle is drawn over it each frame.
    private var terrainCache: (key: String, image: CGImage)?

    private func drawMapBackground() {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        if let scene = colony.scene {
            let scale = window?.backingScaleFactor ?? 2
            let hour = Scenery.currentHour
            let key = "\(ObjectIdentifier(scene).hashValue)-\(Int(bounds.width))x\(Int(bounds.height))-\(scale)-\(hour)-\(scene.stage)"
            if terrainCache?.key != key { terrainCache = scene.render(size: bounds.size, origin: origin, scale: scale, hour: hour).map { (key, $0) } }
            if let image = terrainCache?.image {
                ctx.saveGState()
                ctx.interpolationQuality = .none
                ctx.draw(image, in: bounds)
                ctx.restoreGState()
            }
            for pond in scene.ponds { drawPond(pond) }
        } else if let ground = Scenery.ground() { Scenery.fillGround(ground, in: bounds, scale: 2, into: ctx) } else { NSColor(calibratedRed: 0.23, green: 0.45, blue: 0.24, alpha: 1).setFill(); bounds.fill() }
        let style = Settings.shared.scenery
        guard style != "none" else { return }
        // a forest all around the clearing, however big the window is: a row of trees behind at the top, a column down each side, and
        // the edge with the grass along the bottom
        let size = 54
        if let tile = Scenery.tile(style: "forest", size: size, side: .bottom) {
            let h = CGFloat(tile.height)
            // the top row: the same trees with their grass cut off, standing at the top edge
            ctx.saveGState()
            ctx.clip(to: CGRect(x: 0, y: bounds.maxY - (h - 12), width: bounds.width, height: h - 12))
            Scenery.drawStrip(tile, in: CGRect(x: 0, y: bounds.maxY - h + 12, width: bounds.width, height: h), side: .bottom, into: ctx)
            ctx.restoreGState()
            Scenery.drawStrip(tile, in: CGRect(x: 0, y: 0, width: bounds.width, height: h), side: .bottom, into: ctx)
        }
        if let left = Scenery.tile(style: "forest", size: 42, side: .left), let right = Scenery.tile(style: "forest", size: 42, side: .right) {
            Scenery.drawStrip(left, in: CGRect(x: 0, y: 0, width: CGFloat(left.width), height: bounds.height), side: .left, into: ctx)
            Scenery.drawStrip(right, in: CGRect(x: bounds.maxX - CGFloat(right.width), y: 0, width: CGFloat(right.width), height: bounds.height), side: .right, into: ctx)
        }
        if let scene = colony.scene, scene.life != nil { // the forest round the clearing turns with the seasons too
            let x = scene.seasonPosition
            let tint: (NSColor, CGFloat)? = x >= 3.0 ? (NSColor(calibratedRed: 0.95, green: 0.98, blue: 1, alpha: 1), scene.biome == .snow ? 0.06 : 0.3)
                : x >= 2.1 ? (NSColor(calibratedRed: 0.9, green: 0.5, blue: 0.12, alpha: 1), CGFloat(min(0.3, (x - 2.1) * 0.35)))
                : x < 0.4 ? (NSColor(calibratedRed: 0.95, green: 0.98, blue: 1, alpha: 1), CGFloat((0.4 - x) * 0.5)) : nil
            if let (color, alpha) = tint, alpha > 0.01 {
                color.withAlphaComponent(alpha).setFill()
                NSRect(x: 0, y: 0, width: bounds.width, height: 54).fill()
                NSRect(x: 0, y: bounds.maxY - 42, width: bounds.width, height: 42).fill()
                NSRect(x: 0, y: 0, width: 42, height: bounds.height).fill()
                NSRect(x: bounds.maxX - 42, y: 0, width: 42, height: bounds.height).fill()
            }
        }
        if let (color, alpha) = colony.scene?.ringTint { // snow on the trees, murk in the swamp
            color.withAlphaComponent(alpha).setFill()
            NSRect(x: 0, y: 0, width: bounds.width, height: 54).fill()
            NSRect(x: 0, y: bounds.maxY - 42, width: bounds.width, height: 42).fill()
            NSRect(x: 0, y: 0, width: 42, height: bounds.height).fill()
            NSRect(x: bounds.maxX - 42, y: 0, width: 42, height: bounds.height).fill()
        }
    }

    /// Things in the air that go with the season and the hour: fog on a cool morning, fireflies on a warm night, falling leaves in autumn,
    /// petals in spring, snow in winter. A few dozen specks at most, drawn over the ground and under the goblins.
    private func drawAtmosphere() {
        guard let scene = colony.scene, scene.life != nil, !colony.campHidden, let ctx = NSGraphicsContext.current?.cgContext else { return }
        let x = scene.seasonPosition, hour = Scenery.currentHour
        let t = Date().timeIntervalSinceReferenceDate
        func unit(_ i: Int, _ salt: Double) -> CGFloat { CGFloat((sin(Double(i) * 12.9898 + salt * 78.233) * 43758.5453).truncatingRemainder(dividingBy: 1).magnitude) }
        let area = bounds.insetBy(dx: 44, dy: 54)

        // fog: on a cool morning, thickest in a swamp and in autumn and spring
        if (5...9).contains(hour) {
            let base: CGFloat = hour == 5 || hour == 9 ? 0.5 : 1
            let kind: CGFloat = scene.biome == .swamp ? 1 : (x >= 2 && x < 3.2) || x < 0.9 ? 0.75 : 0.35
            for i in 0..<7 {
                let w = 320 + unit(i, 1) * 260, h = 70 + unit(i, 2) * 70
                let cx = area.minX + ((unit(i, 3) * (area.width + w) + CGFloat(t) * (3 + unit(i, 4) * 3)).truncatingRemainder(dividingBy: area.width + w)) - w / 2
                let cy = area.minY + unit(i, 5) * area.height
                NSColor(calibratedWhite: 1, alpha: 0.11 * base * kind).setFill()
                NSBezierPath(ovalIn: NSRect(x: cx - w / 2, y: cy - h / 2, width: w, height: h)).fill()
                NSColor(calibratedWhite: 1, alpha: 0.07 * base * kind).setFill()
                NSBezierPath(ovalIn: NSRect(x: cx - w * 0.36, y: cy - h * 0.3, width: w * 0.72, height: h * 0.6)).fill()
            }
        }
        // fireflies: warm nights, near the water and the trees
        if hour >= 19 || hour < 5, x >= 0.3, x < 2.9, scene.biome != .snow {
            let count = x >= 0.9 && x < 2.0 ? 22 : 11
            for i in 0..<count {
                let bx = area.minX + unit(i, 6) * area.width, by = area.minY + unit(i, 7) * area.height
                let px = bx + CGFloat(sin(t * 0.5 + Double(i))) * 26, py = by + CGFloat(cos(t * 0.37 + Double(i) * 1.7)) * 18
                let blink = pow(max(0, sin(t * 1.1 + Double(i) * 2.3)), 3)
                guard blink > 0.05 else { continue }
                NSColor(calibratedRed: 0.85, green: 1, blue: 0.4, alpha: CGFloat(0.16 * blink)).setFill()
                NSBezierPath(ovalIn: NSRect(x: px - 5, y: py - 5, width: 10, height: 10)).fill()
                NSColor(calibratedRed: 0.95, green: 1, blue: 0.6, alpha: CGFloat(0.9 * blink)).setFill()
                NSRect(x: px - 1, y: py - 1, width: 2, height: 2).fill()
            }
        }
        // falling leaves (autumn) and petals (spring)
        let autumn = x >= 2.05 && x < 3.1, spring = x >= 0.25 && x < 0.95 && scene.biome != .snow
        if autumn || spring, hour >= 6, hour < 20 {
            let colors: [NSColor] = autumn
                ? [NSColor(calibratedRed: 0.92, green: 0.55, blue: 0.16, alpha: 1), NSColor(calibratedRed: 0.8, green: 0.28, blue: 0.14, alpha: 1), NSColor(calibratedRed: 0.94, green: 0.78, blue: 0.24, alpha: 1)]
                : [NSColor(calibratedRed: 1, green: 0.78, blue: 0.86, alpha: 1), NSColor.white]
            for i in 0..<(autumn ? 16 : 9) {
                let speed = 16 + unit(i, 8) * 14
                let y = bounds.maxY - 50 - CGFloat((Double(unit(i, 9)) * Double(bounds.height) + t * Double(speed)).truncatingRemainder(dividingBy: Double(bounds.height - 100)))
                let px = area.minX + unit(i, 10) * area.width + CGFloat(sin(t * 0.9 + Double(i))) * 16
                colors[i % colors.count].setFill()
                NSRect(x: px, y: y, width: 3, height: 3).fill()
            }
        }
        // snow: a gentle fall in winter (and in the snow country when it is cold enough)
        if (x >= 3.0 || (scene.biome == .snow && x >= 2.6)) && !colony.isRaining { drawSnowfall(count: 34, speed: 26, t: t) }
        _ = ctx
    }

    private func drawSnowfall(count: Int, speed: Double, t: Double) {
        func unit(_ i: Int, _ salt: Double) -> CGFloat { CGFloat((sin(Double(i) * 12.9898 + salt * 78.233) * 43758.5453).truncatingRemainder(dividingBy: 1).magnitude) }
        for i in 0..<count {
            let v = speed * (0.6 + Double(unit(i, 11)))
            let y = bounds.maxY - CGFloat((Double(unit(i, 12)) * Double(bounds.height) + t * v).truncatingRemainder(dividingBy: Double(bounds.height)))
            let px = unit(i, 13) * bounds.width + CGFloat(sin(t * 0.7 + Double(i) * 1.3)) * 10
            NSColor(calibratedWhite: 1, alpha: 0.85).setFill()
            NSRect(x: px, y: y, width: i % 4 == 0 ? 3 : 2, height: i % 4 == 0 ? 3 : 2).fill()
        }
    }

    /// The pond's twinkles and ripples that move (its picture is part of the baked ground).
    private func drawPond(_ pond: Pond) {
        let pic = pond.picture.offsetBy(dx: -origin.x, dy: -origin.y)
        guard bounds.intersects(pic) else { return }
        let t = Date().timeIntervalSinceReferenceDate
        for (k, g) in pond.glints.enumerated() {
            let at = CGPoint(x: pic.minX + g.x, y: pic.minY + g.y)
            let phase = (t * 0.35 + Double(k) * 0.37).truncatingRemainder(dividingBy: 1)
            if k % 2 == 0 { // a ring that grows and fades
                let w = 4 + CGFloat(phase) * 12, h = w * 0.45
                NSColor(calibratedWhite: 1, alpha: 0.55 * (1 - phase)).setStroke()
                let ring = NSBezierPath(ovalIn: NSRect(x: at.x - w / 2, y: at.y - h / 2, width: w, height: h))
                ring.lineWidth = 1
                ring.stroke()
            } else if phase < 0.25 { // a quick twinkle
                NSColor.white.setFill()
                NSRect(x: at.x, y: at.y, width: 2, height: 2).fill()
            }
        }
    }

    /// The campfire party: logs, a flickering flame, a warm glow and a few sparks.
    private func drawFire(at p: CGPoint) {
        guard bounds.insetBy(dx: -80, dy: -80).contains(p) else { return }
        let t = Date().timeIntervalSinceReferenceDate
        for (radius, alpha) in [(52.0, 0.07), (36.0, 0.10), (22.0, 0.14)] {
            NSColor(calibratedRed: 1, green: 0.62, blue: 0.2, alpha: CGFloat(alpha)).setFill()
            NSBezierPath(ovalIn: NSRect(x: p.x - CGFloat(radius), y: p.y - CGFloat(radius) * 0.6 + 6, width: CGFloat(radius) * 2, height: CGFloat(radius) * 1.2)).fill()
        }
        NSColor(calibratedRed: 0.36, green: 0.23, blue: 0.13, alpha: 1).setFill()
        NSRect(x: p.x - 9, y: p.y - 3, width: 18, height: 3).fill()
        NSRect(x: p.x - 7, y: p.y - 1, width: 14, height: 3).fill()
        let frame = Int(t * 8) % 3
        func flame(_ dx: CGFloat, _ h: CGFloat, _ w: CGFloat, _ c: NSColor) { c.setFill(); NSRect(x: p.x + dx - w / 2, y: p.y + 1, width: w, height: h).fill() }
        flame(-4, [9, 7, 10][frame], 5, NSColor(calibratedRed: 0.94, green: 0.47, blue: 0.12, alpha: 1))
        flame(4, [7, 10, 8][frame], 5, NSColor(calibratedRed: 0.94, green: 0.47, blue: 0.12, alpha: 1))
        flame(0, [12, 14, 11][frame], 6, NSColor(calibratedRed: 0.98, green: 0.65, blue: 0.16, alpha: 1))
        flame(0, [6, 7, 8][frame], 3, NSColor(calibratedRed: 1, green: 0.92, blue: 0.55, alpha: 1))
        NSColor(calibratedRed: 1, green: 0.85, blue: 0.4, alpha: 1).setFill()
        for k in 0..<3 { // sparks
            let phase = (t * 0.9 + Double(k) * 0.33).truncatingRemainder(dividingBy: 1)
            NSRect(x: p.x + CGFloat(k - 1) * 6 + CGFloat(sin(t * 3 + Double(k))) * 3, y: p.y + 12 + CGFloat(phase) * 26, width: 2, height: 2).fill()
        }
    }

    /// Rain falling on the camp window or on the strip along the screen (not across a whole screen, where it would hide your work).
    private func drawRain() {
        guard colony.isRaining, colony.phase != .idle else { return }
        if isMap, let scene = colony.scene, scene.life != nil, scene.season == .winter || (scene.biome == .snow && scene.seasonPosition >= 2.6) {
            NSColor(calibratedRed: 0.5, green: 0.6, blue: 0.75, alpha: 0.10).setFill() // it snows instead
            bounds.fill()
            drawSnowfall(count: 130, speed: 60, t: colony.weatherAge)
            return
        }
        var rect: CGRect
        if isMap { rect = bounds } else if let strip = rangeRect {
            rect = CGRect(x: strip.minX - origin.x, y: strip.minY - origin.y, width: strip.width, height: strip.height)
            if rangeSide == .bottom { rect.size.height += 70 } // the rain comes down from above the trees
        } else { return }
        guard bounds.intersects(rect), let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.saveGState()
        ctx.clip(to: rect)
        NSColor(calibratedRed: 0.08, green: 0.12, blue: 0.28, alpha: 0.16).setFill()
        rect.fill()
        let t = colony.weatherAge
        let count = min(240, max(20, Int(rect.width * rect.height / 2600)))
        ctx.setLineWidth(1.2)
        ctx.setStrokeColor(NSColor(calibratedRed: 0.65, green: 0.78, blue: 0.96, alpha: 0.75).cgColor)
        func unit(_ i: Int, _ salt: Double) -> CGFloat { CGFloat((sin(Double(i) * 12.9898 + salt) * 43758.5453).truncatingRemainder(dividingBy: 1).magnitude) }
        for i in 0..<count {
            let speed = 240 + 90 * unit(i, 1)
            let x = rect.minX + unit(i, 0) * rect.width
            let y = rect.maxY - CGFloat((Double(unit(i, 2) * rect.height) + t * Double(speed)).truncatingRemainder(dividingBy: Double(rect.height)))
            ctx.move(to: CGPoint(x: x, y: y))
            ctx.addLine(to: CGPoint(x: x - 2, y: y - 7))
        }
        ctx.strokePath()
        ctx.restoreGState()
    }

    /// The forest or meadow along the strip the goblins walk in.
    private func drawStripScenery() {
        guard let rect = rangeRect, Settings.shared.scenery != "none", let ctx = NSGraphicsContext.current?.cgContext,
              let tile = Scenery.tile(style: Settings.shared.scenery, size: Int(rangeSide == .bottom ? rect.height : rect.width), side: rangeSide) else { return }
        let local = CGRect(x: rect.minX - origin.x, y: rect.minY - origin.y, width: rect.width, height: rect.height)
        guard bounds.intersects(local) else { return }
        Scenery.drawStrip(tile, in: local, side: rangeSide, into: ctx)
        if let scene = colony.scene, scene.isStrip { drawStripScene(scene, ctx: ctx) }
    }

    private var stripCache: (key: String, image: CGImage)?

    /// What stands on the strip: ponds, a stream and bridge, rocks, trees, the camp, drawn once into a picture over the strip's forest.
    private func drawStripScene(_ scene: TerrainScene, ctx: CGContext) {
        let paint = scene.paintRect
        let local = CGRect(x: paint.minX - origin.x, y: paint.minY - origin.y, width: paint.width, height: paint.height)
        guard bounds.intersects(local) else { return }
        let scale = window?.backingScaleFactor ?? 2
        let hour = Scenery.currentHour
        let key = "\(ObjectIdentifier(scene).hashValue)-\(Int(paint.width))x\(Int(paint.height))-\(scale)-\(hour)-\(scene.stage)"
        if stripCache?.key != key { stripCache = scene.render(size: paint.size, origin: paint.origin, scale: scale, hour: hour).map { (key, $0) } }
        if let image = stripCache?.image {
            ctx.saveGState()
            ctx.interpolationQuality = .none
            ctx.draw(image, in: local)
            ctx.restoreGState()
        }
        for pond in scene.ponds { drawPond(pond) }
        // the seasons over the strip's forest: snow in winter, orange leaves in autumn, a little frost in early spring
        if scene.life != nil, let strip = rangeRect {
            let x = scene.seasonPosition
            // (stronger than in the camp window: here the whole strip is forest, and it has to read as winter or autumn at a glance)
            let tint: (NSColor, CGFloat)? = x >= 3.0 ? (NSColor(calibratedRed: 0.96, green: 0.98, blue: 1, alpha: 1), 0.42)
                : x >= 2.1 ? (NSColor(calibratedRed: 0.92, green: 0.5, blue: 0.1, alpha: 1), CGFloat(min(0.34, (x - 2.1) * 0.7)))
                : x < 0.4 ? (NSColor(calibratedRed: 0.95, green: 0.98, blue: 1, alpha: 1), CGFloat((0.4 - x) * 0.8)) : nil
            if let (color, alpha) = tint, alpha > 0.01 {
                color.withAlphaComponent(alpha).setFill() // (only over what is there, not the empty screen: `.sourceAtop`)
                NSRect(x: strip.minX - origin.x, y: strip.minY - origin.y, width: strip.width, height: strip.height).fill(using: .sourceAtop)
            }
        }
    }

    /// Seven-segment digit layouts: top, top-left, top-right, middle, bottom-left, bottom-right, bottom.
    private static let segments: [[Bool]] = [
        [true, true, true, false, true, true, true], [false, false, true, false, false, true, false],
        [true, false, true, true, true, false, true], [true, false, true, true, false, true, true],
        [false, true, true, true, false, true, false], [true, true, false, true, false, true, true],
        [true, true, false, true, true, true, true], [true, false, true, false, false, true, false],
        [true, true, true, true, true, true, true], [true, true, true, true, false, true, true],
    ]

    /// The pomodoro: a goblin at the top right holding up an electronic clock that counts down.
    private func drawPomodoro() {
        let pomodoro = colony.pomodoro
        guard pomodoro.isVisible, let ctx = NSGraphicsContext.current?.cgContext else { return }
        let p = local(pomodoro.pos)
        guard bounds.insetBy(dx: -200, dy: -200).contains(p) else { return }
        let character = Characters.current
        guard let role = character.breeds[min(pomodoro.breedIndex, character.breeds.count - 1)].sprites else { return }
        let pixel = role.pixelSize(scale: 1.6)
        let size = CGFloat(role.frameSize) * pixel
        let walking = pomodoro.arriving || pomodoro.leaving
        let resting = pomodoro.isRest
        // the goblin hops when the rest starts
        let hop: CGFloat = pomodoro.shake > 0 || resting ? abs(CGFloat(sin(Date().timeIntervalSinceReferenceDate * (pomodoro.shake > 0 ? 10 : 3)))) * (pomodoro.shake > 0 ? 6 : 2) : 0
        let direction: SpriteDirection = walking ? (pomodoro.leaving ? .right : .left) : .down
        NSColor(calibratedWhite: 0, alpha: 0.18).setFill()
        NSBezierPath(ovalIn: NSRect(x: p.x - size * 0.3, y: p.y - 4, width: size * 0.6, height: 8)).fill()
        if let image = role.image(direction: direction, phase: walking ? pomodoro.walked / 16 : 0) {
            ctx.saveGState()
            ctx.interpolationQuality = .none
            ctx.draw(image, in: CGRect(x: p.x - size / 2, y: p.y - size * 0.2 + hop, width: size, height: size))
            ctx.restoreGState()
        }
        guard pomodoro.phase != nil else { return } // walking away: the clock is put down

        // the clock, held up over the head
        let seconds = Int(pomodoro.remaining.rounded(.up))
        let u: CGFloat = 2 // one LCD "pixel"
        let bodyW: CGFloat = 92, bodyH: CGFloat = 48
        let shakeX = pomodoro.shake > 0 ? CGFloat(sin(Date().timeIntervalSinceReferenceDate * 40)) * 2 : 0
        let body = NSRect(x: p.x - bodyW / 2 + shakeX, y: p.y + size * 0.8 + hop, width: bodyW, height: bodyH)
        NSColor(calibratedWhite: 0.14, alpha: 1).setFill()
        NSBezierPath(roundedRect: body, xRadius: 6, yRadius: 6).fill()
        let lit = pomodoro.paused ? NSColor(calibratedWhite: 0.30, alpha: 1)
                          : resting ? NSColor(calibratedRed: 0.10, green: 0.30, blue: 0.45, alpha: 1)
                          : (seconds <= 60 ? NSColor(calibratedRed: 0.70, green: 0.08, blue: 0.08, alpha: 1)
                                           : NSColor(calibratedRed: 0.10, green: 0.22, blue: 0.10, alpha: 1))
        let glass = NSRect(x: body.minX + 5, y: body.minY + 5, width: bodyW - 10, height: bodyH - 20)
        (pomodoro.paused ? NSColor(calibratedWhite: 0.80, alpha: 1) : resting ? NSColor(calibratedRed: 0.70, green: 0.86, blue: 0.95, alpha: 1) : NSColor(calibratedRed: 0.74, green: 0.84, blue: 0.62, alpha: 1)).setFill()
        NSBezierPath(roundedRect: glass, xRadius: 3, yRadius: 3).fill()

        // label on the bezel: what the clock is counting
        let title: String
        if pomodoro.paused { title = "暫停" } else if pomodoro.phase == .longRest { title = "長休息" } else if resting { title = "休息" }
        else { title = pomodoro.rounds > 1 ? "專注\(pomodoro.round)/\(pomodoro.rounds)" : "專注" }
        let label = title as NSString
        let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 10, weight: .bold), .foregroundColor: NSColor.white]
        label.draw(at: NSPoint(x: body.minX + 7, y: body.maxY - 15), withAttributes: attrs)
        // progress along the top edge, after the label (which is longer with "2/4" or "長休息")
        let barX = body.minX + 7 + ceil(label.size(withAttributes: attrs).width) + 5
        let barW = max(8, body.maxX - 7 - barX)
        let progress = CGFloat(max(0, min(1, 1 - pomodoro.remaining / pomodoro.phaseLength)))
        NSColor(calibratedWhite: 0.35, alpha: 1).setFill()
        NSRect(x: barX, y: body.maxY - 10, width: barW, height: 3).fill()
        (resting ? NSColor(calibratedRed: 0.4, green: 0.75, blue: 0.95, alpha: 1) : NSColor(calibratedRed: 0.5, green: 0.85, blue: 0.4, alpha: 1)).setFill()
        NSRect(x: barX, y: body.maxY - 10, width: barW * progress, height: 3).fill()

        // MM:SS in seven segments
        let minutes = min(99, seconds / 60), rest = seconds % 60
        let digits = [minutes / 10, minutes % 10, rest / 10, rest % 10]
        let digitW: CGFloat = 5 * u, digitH: CGFloat = 9 * u, gap: CGFloat = 1.5 * u, colonW: CGFloat = 2.5 * u
        let total = digitW * 4 + gap * 4 + colonW
        var x = glass.midX - total / 2
        let y = glass.midY - digitH / 2
        lit.setFill()
        func segment(_ i: Int, _ dx: CGFloat) {
            let t = u // thickness
            let rects: [NSRect] = [
                NSRect(x: dx + t, y: y + digitH - t, width: digitW - 2 * t, height: t),
                NSRect(x: dx, y: y + digitH / 2, width: t, height: digitH / 2 - t / 2),
                NSRect(x: dx + digitW - t, y: y + digitH / 2, width: t, height: digitH / 2 - t / 2),
                NSRect(x: dx + t, y: y + digitH / 2 - t / 2, width: digitW - 2 * t, height: t),
                NSRect(x: dx, y: y + t / 2, width: t, height: digitH / 2 - t / 2 - 0.5),
                NSRect(x: dx + digitW - t, y: y + t / 2, width: t, height: digitH / 2 - t / 2 - 0.5),
                NSRect(x: dx + t, y: y, width: digitW - 2 * t, height: t),
            ]
            rects[i].fill()
        }
        for (index, digit) in digits.enumerated() {
            for (i, on) in AntView.segments[digit].enumerated() where on { segment(i, x) }
            x += digitW + gap
            if index == 1 {
                if Int(Date().timeIntervalSinceReferenceDate * 2) % 2 == 0 { // blinking colon
                    NSRect(x: x, y: y + digitH * 0.3, width: u, height: u).fill()
                    NSRect(x: x, y: y + digitH * 0.65, width: u, height: u).fill()
                }
                x += colonW
            }
        }
        // hands holding the clock
        NSColor(calibratedRed: 0.36, green: 0.62, blue: 0.24, alpha: 1).setFill()
        NSRect(x: body.minX - 1, y: body.minY - 3, width: 9, height: 7).fill()
        NSRect(x: body.maxX - 8, y: body.minY - 3, width: 9, height: 7).fill()
    }

    /// The Claude notification: a goblin (or the princess) hops in from the screen edge with a speech bubble.
    private func drawMessage() {
        guard let m = colony.stage.current, let ctx = NSGraphicsContext.current?.cgContext else { return }
        let p = local(m.pos)
        guard bounds.insetBy(dx: -320, dy: -200).contains(p) else { return }
        let character = Characters.current
        let role = m.speaker.isPrincess ? character.queenRole(outfit: colony.outfitIndex)
                                        : character.breeds[min(m.breedIndex, character.breeds.count - 1)].sprites
        guard let role else { return }
        let pixel = role.pixelSize(scale: 1.6)
        let size = CGFloat(role.frameSize) * pixel
        let hop: CGFloat = m.phase == .talking ? abs(CGFloat(sin(m.timer * 8))) * 5 : 0
        let direction: SpriteDirection = m.phase == .talking ? .down : (m.phase == .leaving ? .right : .left)
        let phase = m.phase == .talking ? 0 : m.walked / 16
        NSColor(calibratedWhite: 0, alpha: 0.18).setFill()
        NSBezierPath(ovalIn: NSRect(x: p.x - size * 0.3, y: p.y - 4, width: size * 0.6, height: 8)).fill()
        if let image = role.image(direction: direction, phase: phase) {
            ctx.saveGState()
            ctx.interpolationQuality = .none
            ctx.draw(image, in: CGRect(x: p.x - size / 2, y: p.y - size * 0.2 + hop, width: size, height: size))
            ctx.restoreGState()
        }
        if m.phase == .talking, m.interaction == nil { drawBubble(m, above: CGPoint(x: p.x, y: p.y + size * 0.8 + hop)) }
    }

    private func drawBubble(_ m: Message, above p: CGPoint) {
        let size = m.bubbleTextSize, pad = Message.bubblePadding
        var rect = m.bubbleRect(headTop: p)
        rect.origin.x = max(rect.origin.x, bounds.minX + 8)
        let bubble = NSBezierPath(roundedRect: rect, xRadius: 10, yRadius: 10)
        NSColor.white.setFill()
        bubble.fill()
        // tail pointing at the speaker's head
        let tail = NSBezierPath()
        tail.move(to: NSPoint(x: p.x - 8, y: rect.minY + 1))
        tail.line(to: NSPoint(x: p.x + 2, y: p.y + 2))
        tail.line(to: NSPoint(x: p.x + 8, y: rect.minY + 1))
        tail.fill()
        m.accent.setStroke()
        bubble.lineWidth = 2.5
        bubble.stroke()
        NSColor.white.setFill()
        NSRect(x: p.x - 7, y: rect.minY - 1, width: 14, height: 4).fill() // hide the border where the tail joins
        m.attributed.draw(with: NSRect(x: rect.minX + pad, y: rect.minY + pad, width: size.width, height: size.height),
                          options: [.usesLineFragmentOrigin])
    }

    private func drawColony() {
        if !isMap { drawStripScenery() }
        if let nest = colony.nest {
            drawNest(at: CGPoint(x: nest.x - origin.x, y: nest.y - origin.y), antCount: colony.ants.count)
        }
        if let fire = colony.fire { drawFire(at: CGPoint(x: fire.x - origin.x, y: fire.y - origin.y)) }
        let scale = CGFloat(Settings.shared.antScale)
        let onScreen = bounds.insetBy(dx: -20, dy: -20)
        let foodScale = CGFloat(Colony.foodScale(Settings.shared.antScale))

        for food in colony.foods {
            let p = CGPoint(x: food.pos.x - origin.x, y: food.pos.y - origin.y)
            if bounds.insetBy(dx: -40, dy: -40).contains(p) { drawFood(food, at: p, scale: foodScale) }
        }

        for creature in colony.creatures {
            let p = local(creature.pos)
            if bounds.insetBy(dx: -60, dy: -60).contains(p) { drawCreature(creature, at: p) }
        }

        let character = Characters.current
        if character.worker != nil {
            drawSpriteWorkers(character, scale: scale, onScreen: onScreen)
        } else {
            // no sprites for this character (its folder is missing): plain dots so something still shows
            for ant in colony.ants where !ant.isHidden {
                let p = local(ant.pos)
                if onScreen.contains(p) { drawSpeck(at: p, radius: 5, color: NSColor(calibratedRed: 0.42, green: 0.7, blue: 0.25, alpha: 1)) }
            }
        }

        drawHealPulses()
        drawFloaters()

        if let id = colony.selectedAntID, let ant = colony.ants.first(where: { $0.id == id }) {
            let p = local(ant.pos)
            if onScreen.contains(p) {
                drawSelectionRing(at: p)
                let gearText = ant.wornGear.map(\.name).joined(separator: "、")
                drawPill(gearText.isEmpty ? ant.name : "\(ant.name)　\(gearText)", center: NSPoint(x: p.x, y: p.y + 34), fontSize: 11)
            }
        }

        drawWoundedMarks(onScreen: onScreen)
        for hit in colony.hits {
            let p = local(hit.pos)
            if onScreen.contains(p) { drawHitBurst(at: p, age: hit.age) }
        }

        for egg in colony.eggs {
            let p = CGPoint(x: egg.pos.x - origin.x, y: egg.pos.y - origin.y)
            if onScreen.contains(p) {
                drawFlower(at: p, alpha: egg.alpha, scale: scale)
            }
        }
        if let q = colony.queen, q.alpha > 0, let role = character.queenRole(outfit: colony.outfitIndex) {
            drawSpriteQueen(q, role: role, scale: scale, onScreen: onScreen)
            drawPartnerInBed(character, scale: scale, onScreen: onScreen)
        }
}

    // MARK: Pixel-art characters

    private func local(_ p: CGPoint) -> CGPoint { CGPoint(x: p.x - origin.x, y: p.y - origin.y) }

    /// A marching dashed ring around the goblin picked in the roster.
    private func drawSelectionRing(at p: CGPoint) {
        let center = CGPoint(x: p.x, y: p.y + 7)
        let r: CGFloat = 17
        let ring = NSBezierPath(ovalIn: NSRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2))
        ring.lineWidth = 3
        NSColor.black.withAlphaComponent(0.4).setStroke()
        ring.stroke()
        ring.lineWidth = 1.5
        // the phase must stay small: CoreGraphics walks the dash pattern from the start, so a phase of billions (seconds since 2001 times 12) takes seconds per frame
        ring.setLineDash([4, 3], count: 2, phase: CGFloat((Date().timeIntervalSinceReferenceDate * 12).truncatingRemainder(dividingBy: 7)))
        NSColor(calibratedRed: 1, green: 0.9, blue: 0.3, alpha: 1).setStroke()
        ring.stroke()
    }

    private func drawSpriteWorkers(_ character: Character, scale: CGFloat, onScreen: CGRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let lastBreed = character.breeds.count - 1
        ctx.saveGState()
        ctx.interpolationQuality = .none // keep the pixels sharp
        var minded = Set<Int>() // young ones being minded (they get a heart)
        for other in colony.ants { if case .activity(.mind(let child), _) = other.mode { minded.insert(child) } }
        for ant in colony.ants where !ant.isHidden {
            var p = local(ant.pos)
            guard onScreen.contains(p), let role = character.breeds[min(ant.breedIndex, lastBreed)].sprites else { continue }
            // an attack: it lunges toward what it hits, and a slash flashes there
            let swingProgress = ant.swing > 0 ? CGFloat(1 - ant.swing / Ant.swingTime) : 0
            if ant.swing > 0 {
                let lunge = 4.5 * sin(swingProgress * .pi)
                p.x += CGFloat(cos(ant.swingHeading)) * lunge
                p.y += CGFloat(sin(ant.swingHeading)) * lunge
            }
            let pixel = role.pixelSize(scale: Double(scale)) * (ant.isChild ? 0.62 : 1) // the young ones are small
            let size = CGFloat(role.frameSize) * pixel
            let activity = ant.activity
            if case .play? = activity { p.y += CGFloat(abs(sin(ant.activityClock * 7))) * 4 } // hops about
            if ant.lying { continue } // (in bed beside the princess: drawn with the bed, over it)
            if activity == .sleep { // lying on its side, and turning over now and then; nothing else to draw
                guard let lying = role.image(direction: .down, phase: 0) else { continue }
                ctx.saveGState()
                ctx.translateBy(x: p.x, y: p.y + size * 0.05)
                ctx.rotate(by: ant.sleepFlip ? -.pi / 2 : .pi / 2)
                ctx.draw(lying, in: CGRect(x: -size / 2, y: -size / 2, width: size, height: size))
                ctx.restoreGState()
                continue
            }
            // the walk cycle advances with distance walked; standing still shows the first frame
            let phase = ant.moving ? ant.legPhase / 4 : 0
            guard let image = role.image(direction: ant.facing, phase: phase) else { continue }
            ctx.setAlpha(CGFloat(ant.fadeAlpha)) // the dying fade out
            ctx.draw(image, in: CGRect(x: p.x - size / 2, y: p.y - size * 0.2, width: size, height: size))
            ctx.setAlpha(1)
            if ant.female, ant.fadeAlpha > 0.5 { // a little pink bow at the top of the head
                let bx = p.x + size * 0.14, by = p.y + size * (ant.isChild ? 0.62 : 0.66)
                NSColor(calibratedRed: 0.96, green: 0.45, blue: 0.62, alpha: 1).setFill()
                NSRect(x: bx - pixel * 1.6, y: by, width: pixel * 1.4, height: pixel * 1.4).fill()
                NSRect(x: bx + pixel * 0.2, y: by, width: pixel * 1.4, height: pixel * 1.4).fill()
                NSColor(calibratedRed: 0.99, green: 0.8, blue: 0.86, alpha: 1).setFill()
                NSRect(x: bx - pixel * 0.2, y: by + pixel * 0.1, width: pixel * 0.9, height: pixel * 1.1).fill()
            }
            if ant.isChild {
                if ant.sick > 0 { // a cold: a green tinge, a drip at the nose and now and then a sneeze
                    NSColor(calibratedRed: 0.5, green: 0.85, blue: 0.4, alpha: 0.25).setFill()
                    NSBezierPath(ovalIn: NSRect(x: p.x - size * 0.4, y: p.y - size * 0.1, width: size * 0.8, height: size * 0.9)).fill()
                    NSColor(calibratedRed: 0.6, green: 0.85, blue: 0.5, alpha: 1).setFill()
                    NSRect(x: p.x + size * 0.15, y: p.y + size * 0.35, width: 1.5, height: 2.5).fill()
                    if Int(Date().timeIntervalSinceReferenceDate * 1.5 + Double(ant.id)) % 5 == 0 {
                        NSColor(calibratedWhite: 1, alpha: 0.7).setFill()
                        NSRect(x: p.x + size * 0.45, y: p.y + size * 0.3, width: 3, height: 2).fill()
                        NSRect(x: p.x + size * 0.6, y: p.y + size * 0.4, width: 2, height: 2).fill()
                    }
                }
                if minded.contains(ant.id) { // a heart floating up
                    let bob = CGFloat(sin(Date().timeIntervalSinceReferenceDate * 3 + Double(ant.id))) * 1.5
                    NSColor(calibratedRed: 0.95, green: 0.3, blue: 0.4, alpha: 1).setFill()
                    let hx = p.x - 2.5, hy = p.y + size * 0.85 + bob
                    NSRect(x: hx, y: hy + 1.5, width: 2, height: 2).fill(); NSRect(x: hx + 3, y: hy + 1.5, width: 2, height: 2).fill()
                    NSRect(x: hx, y: hy + 0.5, width: 5, height: 1.5).fill(); NSRect(x: hx + 1, y: hy - 0.5, width: 3, height: 1).fill()
                }
            }
            if PerfGovernor.shared.showsDetail, !ant.isChild {
                if !ant.gear.isEmpty || ant.swing > 0 { drawGear(ant, at: p, size: size, pixel: pixel) }
                if ant.swing > 0 { drawSlash(ant, at: p, size: size, progress: swingProgress) }
            }
            if activity != nil || ant.catchShow > 0 { drawActivity(ant, at: p, size: size, pixel: pixel) }
            if let kind = ant.carrying { // held up over the head, side by side if it carries more than one
                let pieces = max(1, ant.carriedPieces)
                for k in 0..<pieces {
                    let dx = (CGFloat(k) - CGFloat(pieces - 1) / 2) * pixel * 2.4
                    drawSpeck(at: CGPoint(x: p.x + dx, y: p.y + size * 0.86), radius: max(1.5, pixel * 1.1), color: kind.pieceColor)
                }
            }
        }
        ctx.restoreGState()
    }

    /// What goes with an activity: a fishing rod and line, a book, dust from a scuffle, a crown over a golden goblin, a fish held up.
    private func dirSign(_ ant: Ant) -> CGFloat { cos(ant.heading) >= 0 ? 1 : -1 }

    private func drawActivity(_ ant: Ant, at p: CGPoint, size: CGFloat, pixel u: CGFloat) {
        let t = ant.activityClock
        func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ color: NSColor) {
            color.setFill()
            NSRect(x: x - w * u / 2, y: y, width: w * u, height: h * u).fill()
        }
        switch ant.activity {
        case .fish(let spot, let water)?:
            // (only once it is sitting at its spot; on the way it just walks)
            guard hypot(spot.x - ant.pos.x, spot.y - ant.pos.y) < 6 else { break }
            // the rod points out over the water, the line drops to a bobber that bobs, and a ring spreads now and then
            let h = CGFloat(ant.heading)
            let base = CGPoint(x: p.x + cos(h) * size * 0.28, y: p.y + size * 0.34)
            let tip = CGPoint(x: base.x + cos(h) * 11, y: base.y + 10)
            let bob = local(water)
            let bobber = CGPoint(x: bob.x, y: bob.y + CGFloat(sin(t * 3)) * 0.8)
            NSColor(calibratedRed: 0.45, green: 0.3, blue: 0.16, alpha: 1).setStroke()
            let rod = NSBezierPath()
            rod.move(to: base)
            rod.line(to: tip)
            rod.lineWidth = 1.4
            rod.stroke()
            NSColor(calibratedWhite: 0.95, alpha: 0.85).setStroke()
            let line = NSBezierPath()
            line.move(to: tip)
            line.line(to: bobber)
            line.lineWidth = 0.6
            line.stroke()
            NSColor.white.setFill()
            NSBezierPath(ovalIn: NSRect(x: bobber.x - 2, y: bobber.y - 1, width: 4, height: 4)).fill()
            NSColor(calibratedRed: 0.9, green: 0.2, blue: 0.2, alpha: 1).setFill()
            NSBezierPath(ovalIn: NSRect(x: bobber.x - 1.6, y: bobber.y + 0.4, width: 3.2, height: 2.4)).fill()
            let ring = CGFloat((t * 0.5).truncatingRemainder(dividingBy: 1))
            NSColor(calibratedWhite: 1, alpha: 0.5 * (1 - ring)).setStroke()
            let spread = NSBezierPath(ovalIn: NSRect(x: bobber.x - 2 - ring * 7, y: bobber.y - 1 - ring * 3, width: 4 + ring * 14, height: 3 + ring * 6))
            spread.lineWidth = 0.8
            spread.stroke()
        case .gather(let job, let spot, let face, _, _)?:
            // the tool: an axe or a pickaxe, raised and brought down at each blow; chips or sparks fly from where it lands
            guard hypot(spot.x - ant.pos.x, spot.y - ant.pos.y) < 8, let ctx = NSGraphicsContext.current?.cgContext else { break }
            let dir: CGFloat = cos(ant.heading) >= 0 ? 1 : -1
            let progress = ant.swing > 0 ? CGFloat(1 - ant.swing / Ant.swingTime) : 0
            ctx.saveGState()
            ctx.translateBy(x: p.x + dir * size * 0.3, y: p.y + size * 0.3)
            ctx.rotate(by: dir * (0.9 - 2.3 * progress))
            let steel = NSColor(calibratedRed: 0.72, green: 0.75, blue: 0.82, alpha: 1)
            rect(0, 0, 1.3, 7, NSColor(calibratedRed: 0.5, green: 0.34, blue: 0.18, alpha: 1))
            if job == 0 { // an axe: the head on one side, its edge lit
                rect(dir * 1.5 * u, 5 * u, 3, 2.6, steel)
                rect(dir * 2.6 * u, 5 * u, 1, 2.6, NSColor.white)
            } else { // a pickaxe: a curved bar across the top
                rect(0, 6 * u, 6, 1.4, steel)
                rect(-2.6 * u, 5.4 * u, 1, 1.4, steel); rect(2.6 * u, 5.4 * u, 1, 1.4, steel)
            }
            ctx.restoreGState()
            if progress > 0.55, progress < 0.95 {
                let hit = local(face)
                let fly = (progress - 0.55) / 0.4
                for k in 0..<5 {
                    let a = Double(k) * 1.3 + Double(ant.gatherHits)
                    let x = hit.x + CGFloat(cos(a)) * (3 + fly * 9) * (k % 2 == 0 ? 1 : -1)
                    let y = hit.y - 6 + CGFloat(sin(a)) * (2 + fly * 8) + CGFloat(fly) * 4
                    (job == 0 ? (k % 2 == 0 ? NSColor(calibratedRed: 0.72, green: 0.52, blue: 0.3, alpha: 1) : NSColor(calibratedRed: 0.86, green: 0.72, blue: 0.5, alpha: 1))
                        : (k % 2 == 0 ? NSColor(calibratedRed: 1, green: 0.88, blue: 0.4, alpha: 1) : NSColor(calibratedWhite: 0.8, alpha: 1))).withAlphaComponent(1 - fly * 0.6).setFill()
                    NSRect(x: x, y: y, width: 2, height: 2).fill()
                }
            }
        case .farm(let plot, let action, let spot, let face)?:
            // hoe, seed, basket or watering can: the tool for the job, and what flies up or falls from it
            guard hypot(spot.x - ant.pos.x, spot.y - ant.pos.y) < 8, let ctx = NSGraphicsContext.current?.cgContext else { break }
            let dir: CGFloat = cos(ant.heading) >= 0 ? 1 : -1
            let progress = ant.swing > 0 ? CGFloat(1 - ant.swing / Ant.swingTime) : 0
            let target = local(face)
            let hand = CGPoint(x: p.x + dir * size * 0.3, y: p.y + size * 0.3)
            switch action {
            case 0: // a hoe
                ctx.saveGState()
                ctx.translateBy(x: hand.x, y: hand.y)
                ctx.rotate(by: dir * (0.9 - 2.2 * progress))
                rect(0, 0, 1.3, 7, NSColor(calibratedRed: 0.5, green: 0.34, blue: 0.18, alpha: 1))
                rect(dir * 1.4 * u, 6 * u, 3.2, 1.4, NSColor(calibratedRed: 0.62, green: 0.65, blue: 0.7, alpha: 1))
                ctx.restoreGState()
                if progress > 0.55, progress < 0.95 {
                    for k in 0..<4 {
                        let a = Double(k) * 1.6 + Double(ant.id)
                        NSColor(calibratedRed: 0.5, green: 0.36, blue: 0.22, alpha: 0.9).setFill()
                        NSRect(x: target.x + CGFloat(cos(a)) * (3 + (progress - 0.55) * 14), y: target.y + CGFloat(sin(a)) * 3 + (progress - 0.55) * 10, width: 2, height: 2).fill()
                    }
                }
            case 1: // sowing: a handful of seed thrown out
                if progress > 0.15 {
                    let f = (progress - 0.15) / 0.85
                    for k in 0..<6 {
                        let t2 = f + CGFloat(k) * 0.04
                        NSColor(calibratedRed: 0.9, green: 0.82, blue: 0.5, alpha: 1 - f * 0.4).setFill()
                        NSRect(x: hand.x + (target.x - hand.x) * min(1, t2) + CGFloat(k % 3 - 1) * 3, y: hand.y + (target.y - hand.y) * min(1, t2) + CGFloat(sin(Double(t2) * .pi)) * 8, width: 2, height: 2).fill()
                    }
                }
            case 3: // a watering can
                let tilt = CGFloat(0.6)
                ctx.saveGState()
                ctx.translateBy(x: hand.x + dir * 2, y: hand.y)
                ctx.rotate(by: -dir * tilt)
                rect(0, 0, 6, 4, NSColor(calibratedRed: 0.55, green: 0.6, blue: 0.68, alpha: 1))
                rect(dir * 4.4 * u, 2 * u, 1.2, 4, NSColor(calibratedRed: 0.45, green: 0.5, blue: 0.58, alpha: 1))
                ctx.restoreGState()
                for k in 0..<7 {
                    let phase = (t * 1.6 + Double(k) / 7).truncatingRemainder(dividingBy: 1)
                    NSColor(calibratedRed: 0.5, green: 0.74, blue: 0.96, alpha: 0.9).setFill()
                    NSRect(x: hand.x + dir * 9 + (target.x - hand.x - dir * 9) * CGFloat(phase), y: hand.y + 3 - CGFloat(phase) * (hand.y - target.y + 3), width: 1.6, height: 2.4).fill()
                }
            default: // harvest: a basket at its side, and what it pulls up
                NSColor(calibratedRed: 0.66, green: 0.48, blue: 0.26, alpha: 1).setFill()
                NSRect(x: p.x - dir * size * 0.42 - 4, y: p.y + size * 0.05, width: 8, height: 5).fill()
                NSColor(calibratedRed: 0.42, green: 0.3, blue: 0.16, alpha: 1).setFill()
                NSRect(x: p.x - dir * size * 0.42 - 4, y: p.y + size * 0.05 + 4, width: 8, height: 1).fill()
                let colors = [NSColor(calibratedRed: 0.92, green: 0.78, blue: 0.3, alpha: 1), NSColor(calibratedRed: 0.95, green: 0.55, blue: 0.16, alpha: 1), NSColor(calibratedRed: 0.4, green: 0.72, blue: 0.4, alpha: 1)]
                if progress > 0.2, progress < 0.95 {
                    colors[plot % 3].setFill()
                    NSRect(x: target.x - 2 + (p.x - target.x) * progress * 0.4, y: target.y + progress * 14, width: 4, height: 4).fill()
                }
            }
        case .cook(let spot, let pot)?:
            // a little fire under the pot, the pot itself, steam, and the spoon the cook stirs with
            guard hypot(spot.x - ant.pos.x, spot.y - ant.pos.y) < 8 else { break }
            let c = local(pot)
            for (k, flame) in [(-6.0, 4.0), (-2.0, 7.0), (2.0, 5.0), (6.0, 3.5)].enumerated() {
                let wag = CGFloat(sin(t * 9 + Double(k) * 2)) * 1.2
                NSColor(calibratedRed: 0.98, green: 0.5, blue: 0.12, alpha: 1).setFill()
                NSRect(x: c.x + CGFloat(flame.0) - 1.5, y: c.y - 2, width: 3, height: CGFloat(flame.1) + wag).fill()
                NSColor(calibratedRed: 1, green: 0.85, blue: 0.3, alpha: 1).setFill()
                NSRect(x: c.x + CGFloat(flame.0) - 0.5, y: c.y - 2, width: 1.2, height: CGFloat(flame.1) * 0.5).fill()
            }
            NSColor(calibratedRed: 0.16, green: 0.15, blue: 0.18, alpha: 1).setFill()
            NSBezierPath(ovalIn: NSRect(x: c.x - 9, y: c.y + 2, width: 18, height: 11)).fill()
            NSColor(calibratedRed: 0.86, green: 0.5, blue: 0.2, alpha: 1).setFill()
            NSBezierPath(ovalIn: NSRect(x: c.x - 7, y: c.y + 8, width: 14, height: 5)).fill()
            NSColor(calibratedRed: 0.3, green: 0.28, blue: 0.32, alpha: 1).setFill()
            NSRect(x: c.x - 11, y: c.y + 8, width: 3, height: 2).fill(); NSRect(x: c.x + 8, y: c.y + 8, width: 3, height: 2).fill()
            for k in 0..<4 {
                let phase = (t * 0.7 + Double(k) * 0.25).truncatingRemainder(dividingBy: 1)
                NSColor(calibratedWhite: 1, alpha: 0.45 * CGFloat(1 - phase)).setFill()
                NSBezierPath(ovalIn: NSRect(x: c.x - 6 + CGFloat(k) * 4 + CGFloat(sin(t * 2 + Double(k))) * 2, y: c.y + 14 + CGFloat(phase) * 18, width: 5, height: 4)).fill()
            }
            let stir = CGFloat(sin(t * 4)) * 5
            NSColor(calibratedRed: 0.6, green: 0.42, blue: 0.22, alpha: 1).setStroke()
            let spoon = NSBezierPath()
            spoon.move(to: CGPoint(x: p.x + dirSign(ant) * 6, y: p.y + size * 0.4))
            spoon.line(to: CGPoint(x: c.x + stir, y: c.y + 10))
            spoon.lineWidth = 1.5
            spoon.stroke()
        case .read?:
            let book = CGPoint(x: p.x, y: p.y + size * 0.12)
            rect(book.x, book.y, 7, 4.5, NSColor(calibratedRed: 0.35, green: 0.3, blue: 0.62, alpha: 1))
            rect(book.x - 1.6 * u, book.y + 0.4 * u, 2.6, 3.6, NSColor(calibratedRed: 0.95, green: 0.92, blue: 0.82, alpha: 1))
            rect(book.x + 1.6 * u, book.y + 0.4 * u, 2.6, 3.6, NSColor(calibratedRed: 0.95, green: 0.92, blue: 0.82, alpha: 1))
            if Int(t * 0.6) % 3 == 0 { drawSpeck(at: CGPoint(x: p.x + size * 0.34, y: p.y + size * 0.95), radius: 1.3, color: NSColor.white.withAlphaComponent(0.8)) } // a thought
        case .scuffle?:
            // a little dust cloud between the two that puffs in and out
            let h = CGFloat(ant.heading)
            let centre = CGPoint(x: p.x + cos(h) * size * 0.4, y: p.y + size * 0.2 + sin(h) * size * 0.3)
            for k in 0..<4 {
                let a = CGFloat(t * 4) + CGFloat(k) * 1.6, r = 3 + CGFloat(sin(t * 6 + Double(k))) * 1.5
                NSColor(calibratedWhite: 0.9, alpha: 0.5).setFill()
                NSBezierPath(ovalIn: NSRect(x: centre.x + cos(a) * 5 - r, y: centre.y + sin(a) * 3 - r, width: r * 2, height: r * 2)).fill()
            }
        case .stroll?:
            // a small gold crown
            let crown = CGPoint(x: p.x, y: p.y + size * 0.88)
            let gold = NSColor(calibratedRed: 0.98, green: 0.82, blue: 0.2, alpha: 1)
            rect(crown.x, crown.y, 6, 1.6, gold)
            for dx: CGFloat in [-2, 0, 2] { rect(crown.x + dx * u, crown.y + 1.6 * u, 1, 1.6, gold) }
            rect(crown.x, crown.y + 0.4 * u, 1, 1, NSColor(calibratedRed: 0.85, green: 0.15, blue: 0.2, alpha: 1))
        default: break
        }
        if ant.catchShow > 0 { // a fish held up
            let fish = CGPoint(x: p.x, y: p.y + size * 0.95 + CGFloat(min(1, ant.catchShow)) * 2)
            let silver = NSColor(calibratedRed: 0.72, green: 0.82, blue: 0.9, alpha: 1)
            rect(fish.x, fish.y, 6, 2.4, silver)
            rect(fish.x + 3.4 * u, fish.y + 0.2 * u, 2, 2, silver)
            rect(fish.x - 1.6 * u, fish.y + 0.4 * u, 0.8, 0.8, NSColor(calibratedRed: 0.1, green: 0.1, blue: 0.15, alpha: 1))
        }
    }

    /// The flash of a hit, by weapon: a curved slash (claws and blades), an arrow (bow) or a bolt of light (staff) flying to the target.
    private func drawSlash(_ ant: Ant, at p: CGPoint, size: CGFloat, progress: CGFloat) {
        let weapon = ant.wornGear.first { $0.slot == .weapon }
        let color = weapon?.color ?? .white
        let h = CGFloat(ant.swingHeading)
        let from = CGPoint(x: p.x, y: p.y + size * 0.3)
        switch weapon?.look {
        case .bow?:
            guard progress > 0.3 else { return } // drawing the string first
            let t = (progress - 0.3) / 0.7, d = max(20, CGFloat(ant.gearReach) + 30) * t
            NSColor(calibratedRed: 0.55, green: 0.38, blue: 0.2, alpha: 1).setFill()
            for k in 0..<4 { NSRect(x: from.x + cos(h) * (d - CGFloat(k) * 2.2) - 0.9, y: from.y + sin(h) * (d - CGFloat(k) * 2.2) - 0.9, width: 1.8, height: 1.8).fill() }
            NSColor.white.setFill()
            NSRect(x: from.x + cos(h) * (d + 2) - 1.2, y: from.y + sin(h) * (d + 2) - 1.2, width: 2.4, height: 2.4).fill()
        case .staff?:
            guard progress > 0.35 else { return }
            let t = (progress - 0.35) / 0.65, d = max(16, CGFloat(ant.gearReach) + 8) * t
            for (r, alpha) in [(4.0, 0.35), (2.6, 0.8)] as [(CGFloat, CGFloat)] {
                color.withAlphaComponent(alpha * (1 - t * 0.5)).setFill()
                NSBezierPath(ovalIn: NSRect(x: from.x + cos(h) * d - r, y: from.y + sin(h) * d - r, width: r * 2, height: r * 2)).fill()
            }
        default:
            let reach = size * 0.62 + CGFloat(ant.gearReach) * 0.5
            let centre = CGPoint(x: p.x + cos(h) * reach, y: p.y + size * 0.3 + sin(h) * reach)
            let sweep = -0.9 + 1.8 * progress // the arc turns as it goes
            for k in 0..<5 {
                let a = h + sweep + (CGFloat(k) - 2) * 0.28
                let r = size * 0.28
                color.withAlphaComponent(0.85 * (1 - progress)).setFill()
                NSRect(x: centre.x + cos(a) * r - 1.2, y: centre.y + sin(a) * r - 1.2, width: 2.4, height: 2.4).fill()
            }
        }
    }

    /// What a goblin wears, drawn over its sprite: a few pixels each. The weapon is in the front hand, the shield on the other side;
    /// the hat, armour, trousers, shoes and gloves sit where they belong on the body. While it fights, the weapon swings (or thrusts).
    private func drawGear(_ ant: Ant, at p: CGPoint, size: CGFloat, pixel u: CGFloat) {
        let worn = ant.wornGear
        guard !worn.isEmpty else { return }
        let dir = ant.facing
        let sideView = dir == .left || dir == .right
        // +1 = the way the front hand is; sideways the weapon is always the front hand
        let hand: CGFloat = dir == .left ? -1 : dir == .up ? -1 : 1
        let back: CGFloat = -hand
        let base = p.y - size * 0.2 // the feet
        let y0 = p.y + size * 0.16
        let facingX: CGFloat = dir == .left ? -1 : dir == .right ? 1 : 0
        let swingProgress = ant.swing > 0 ? CGFloat(1 - ant.swing / Ant.swingTime) : nil
        let t = Date().timeIntervalSinceReferenceDate
        let ctx = NSGraphicsContext.current?.cgContext
        func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ color: NSColor) {
            color.setFill()
            NSRect(x: x - w * u / 2, y: y, width: w * u, height: h * u).fill()
        }
        let wood = NSColor(calibratedRed: 0.45, green: 0.3, blue: 0.16, alpha: 1)
        // While it swings, a blade turns about its hand (raised, then chopped down); a spear thrusts along the way it points.
        func beginWeapon(_ x: CGFloat, thrust: Bool = false) -> (x: CGFloat, y: CGFloat) {
            guard let swingProgress, let ctx else { return (x, y0) }
            ctx.saveGState()
            if thrust {
                let out = 9 * sin(swingProgress * .pi)
                ctx.translateBy(x: x + cos(ant.swingHeading) * out, y: y0 + sin(ant.swingHeading) * out)
                ctx.rotate(by: ant.swingHeading - .pi / 2)
            } else {
                ctx.translateBy(x: x, y: y0)
                ctx.rotate(by: -hand * (0.9 - 2.3 * swingProgress))
            }
            return (0, 0)
        }
        func endWeapon() { if swingProgress != nil { ctx?.restoreGState() } }
        func blade(_ x: CGFloat, _ y: CGFloat, width: CGFloat, length: CGFloat, guardWidth: CGFloat, _ gear: Gear) {
            let dark = gear.color.blended(withFraction: 0.45, of: .black) ?? gear.color
            let light = gear.color.blended(withFraction: 0.55, of: .white) ?? gear.color
            rect(x, y - u, 1.4, 2, wood)
            rect(x, y + u, guardWidth, 1, dark)
            rect(x, y + 2 * u, width, length, gear.color)
            rect(x - width * u * 0.2, y + 2 * u, width * 0.35, length, light)
            rect(x, y + (2 + length) * u, max(0.8, width * 0.5), 1, light)
        }

        // the clothes first (they are under the weapon), then what is held
        for gear in worn where gear.slot != .weapon && gear.slot != .shield {
            let dark = gear.color.blended(withFraction: 0.45, of: .black) ?? gear.color
            let light = gear.color.blended(withFraction: 0.5, of: .white) ?? gear.color
            let bodyW: CGFloat = sideView ? 0.34 : 0.5
            switch gear.look {
            case .cap:
                rect(p.x + facingX * size * 0.03, base + size * 0.86, sideView ? 7 : 8, 2.6, gear.color)
                rect(p.x + facingX * size * 0.03, base + size * 0.86, sideView ? 7 : 8, 0.8, dark)
                if gear.id == "leather_cap" { rect(p.x - back * size * 0.28, base + size * 0.68, 1.6, 3, gear.color) } // ear flap
            case .helm:
                rect(p.x + facingX * size * 0.03, base + size * 0.84, sideView ? 7.6 : 8.6, 3.4, gear.color)
                rect(p.x + facingX * size * 0.03, base + size * 0.84, sideView ? 7.6 : 8.6, 0.9, dark)
                rect(p.x + facingX * size * 0.03, base + size * 0.98, 1, 1.4, light) // a small crest
            case .tunic, .plate:
                let y = base + size * 0.3
                rect(p.x, y, bodyW * 16, 3.2, gear.color)
                rect(p.x, y, bodyW * 16, 0.9, dark)
                rect(p.x, y + 2.6 * u, bodyW * 16 * 0.7, 0.7, light)
                if gear.look == .plate { rect(p.x, y + 1.2 * u, 1, 1, light) }
            case .cloak:
                for s in sideView ? [back] : [-1, 1] as [CGFloat] {
                    let x = p.x + s * size * (sideView ? 0.24 : 0.3)
                    rect(x, y0 - 0.5 * u, 2, 6, dark)
                    rect(x, y0 - 0.5 * u, 1.2, 6, gear.color)
                }
            case .pants:
                for s in sideView ? [0] as [CGFloat] : [-1, 1] as [CGFloat] {
                    rect(p.x + s * size * 0.1, base + size * 0.1, sideView ? 3.4 : 2.8, 3, gear.color)
                }
            case .boots:
                for s in sideView ? [0] as [CGFloat] : [-1, 1] as [CGFloat] {
                    rect(p.x + s * size * 0.11 + facingX * size * 0.03, base - 0.3 * u, sideView ? 4 : 3, 2.2, gear.color)
                    rect(p.x + s * size * 0.11 + facingX * size * 0.03, base - 0.3 * u, sideView ? 4 : 3, 0.7, dark)
                }
            case .gloves, .gauntlet:
                for s in sideView ? [hand] : [-1, 1] as [CGFloat] {
                    let x = p.x + s * size * (sideView ? 0.3 : 0.34)
                    rect(x, base + size * 0.36, 2.6, 1.8, gear.color)
                    rect(x, base + size * 0.36, 2.6, 0.7, gear.look == .gauntlet ? light : dark)
                }
            default: break
            }
        }

        // the shield on the far side
        if let shield = worn.first(where: { $0.slot == .shield }) {
            let dark = shield.color.blended(withFraction: 0.45, of: .black) ?? shield.color
            let light = shield.color.blended(withFraction: 0.5, of: .white) ?? shield.color
            let x = p.x + back * size * (sideView ? 0.3 : 0.42)
            rect(x, y0 - u, 5, 5, dark)
            rect(x, y0 - 0.5 * u, 4, 4, shield.color)
            if shield.look == .woodShield {
                rect(x, y0 + 0.5 * u, 4, 0.6, dark) // planks
                rect(x, y0 - 0.5 * u, 0.6, 4, dark)
            } else {
                rect(x, y0 + 0.5 * u, 1.6, 1.6, light)
            }
        }

        // the weapon
        if let weapon = worn.first(where: { $0.slot == .weapon }) {
            let dark = weapon.color.blended(withFraction: 0.45, of: .black) ?? weapon.color
            let light = weapon.color.blended(withFraction: 0.5, of: .white) ?? weapon.color
            let x = p.x + hand * size * 0.44
            switch weapon.look {
            case .knife:
                let (x, y) = beginWeapon(x)
                blade(x, y, width: 1.6, length: 4, guardWidth: 3, weapon)
                endWeapon()
            case .dagger:
                let (x, y) = beginWeapon(x)
                blade(x, y, width: 1.8, length: 4, guardWidth: 4, weapon)
                endWeapon()
            case .shortSword:
                let (x, y) = beginWeapon(x)
                blade(x, y, width: 1.8, length: 5.5, guardWidth: 4, weapon)
                endWeapon()
            case .longSword:
                let (x, y) = beginWeapon(x)
                blade(x, y, width: 1.8, length: 8, guardWidth: 4.5, weapon)
                endWeapon()
            case .greatSword:
                let (x, y) = beginWeapon(p.x + hand * size * 0.46)
                blade(x, y, width: 2.8, length: 10, guardWidth: 6, weapon)
                endWeapon()
            case .twinBlades:
                for s in [hand, back] {
                    let (x, y) = beginWeapon(p.x + s * size * 0.44)
                    blade(x, y, width: 1.6, length: 5, guardWidth: 3.6, weapon)
                    endWeapon()
                }
            case .spear:
                let (x, y) = beginWeapon(p.x + hand * size * 0.46, thrust: true)
                rect(x, y - 3 * u, 1.2, 14, wood)
                rect(x, y + 10 * u, 3, 1.4, dark)
                rect(x, y + 11 * u, 2, 2.4, weapon.color)
                rect(x, y + 13 * u, 1, 1.4, light)
                endWeapon()
            case .bow:
                let x = p.x + hand * size * 0.46
                let pull: CGFloat = swingProgress.map { $0 < 0.3 ? $0 / 0.3 : 0 } ?? 0 // the string is drawn back before the shot
                for (dy, dx) in [(0.0, 1.4), (2.0, 0.6), (4.0, 0), (6.0, 0.6), (8.0, 1.4)] as [(CGFloat, CGFloat)] {
                    rect(x + hand * dx * u, y0 + (dy - 1) * u, 1.2, 2, weapon.color)
                }
                rect(x - hand * (0.2 + pull * 1.6) * u, y0 - 0.2 * u, 0.5, 8.6, NSColor(calibratedWhite: 0.92, alpha: 0.9)) // string
            case .staff:
                let (x, y) = beginWeapon(p.x + hand * size * 0.46)
                rect(x, y - 2 * u, 1.2, 9, wood)
                rect(x, y + 6 * u, 3.4, 3.4, dark)
                rect(x, y + 6.5 * u, 2.4, 2.4, weapon.color)
                rect(x - 0.4 * u, y + 7.4 * u, 0.9, 0.9, light)
                if Int(t * 3 + Double(ant.id)) % 4 == 0 || swingProgress != nil { rect(x + 2 * u, y + 9 * u, 0.9, 0.9, .white) } // a twinkle
                endWeapon()
            default: break
            }
        }
    }

    private func drawSpriteQueen(_ q: Queen, role: SpriteRole, scale: CGFloat, onScreen: CGRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let p = local(q.pos)
        if q.isCarried {
            drawCarriedPrincess(q, role: role, scale: scale, at: p)
            return
        }
        guard onScreen.contains(p) else { return }
        let pixel = role.pixelSize(scale: Double(scale))
        let size = CGFloat(role.frameSize) * pixel

        // props sit behind her
        if let prop = q.prop { drawProp(prop, at: p, pixel: pixel, size: size) }

        if q.isLying, let image = role.image(direction: .down, phase: 0) {
            // asleep: lying on her back with her head on the pillow, and the blanket pulled up
            ctx.saveGState()
            ctx.interpolationQuality = .none
            ctx.translateBy(x: p.x, y: p.y + size * 0.3)
            ctx.rotate(by: .pi / 2)
            ctx.draw(image, in: CGRect(x: -size / 2, y: -size / 2, width: size, height: size))
            ctx.restoreGState()
            drawBlanket(at: p, size: size)
            if let decoration = q.decoration { drawDecoration(decoration, at: CGPoint(x: p.x, y: p.y + size * 0.3), scale: size / 16) }
            return
        }

        // a pose of her own (tea, exercise…) if she has one, otherwise the walking frames
        let image: CGImage
        if let pose = q.pose, let posed = role.poseImage(pose.name, frame: pose.frame) {
            image = posed
        } else {
            let phase = q.walking ? q.legPhase / 3 : 0
            guard let walking = role.image(direction: q.facing, phase: phase) else { return }
            image = walking
        }
        var rect = CGRect(x: p.x - size / 2, y: p.y - size * 0.2, width: size, height: size)

        ctx.saveGState()
        ctx.interpolationQuality = .none
        ctx.setAlpha(q.alpha)
        if q.emergence < 1 {
            // peeking: she rises out of the hole, so everything below the hole line is cut off
            let rise = min(1, CGFloat(q.emergence) / 0.65)
            rect.origin.y -= (1 - rise) * size * 0.75
            ctx.clip(to: CGRect(x: p.x - size, y: p.y - size * 0.15, width: size * 2, height: size * 2))
        }
        ctx.draw(image, in: rect)
        ctx.restoreGState()

        if let decoration = q.decoration {
            drawDecoration(decoration, at: p, scale: size / 16)
        } else if colony.romanceRuntime.glow > 0 {
            drawDecoration(.hearts(clock: Date().timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1000)), at: p, scale: size / 16)
        } else if colony.romanceRuntime.sulk > 0 {
            drawDecoration(.anger(clock: Date().timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1000)), at: p, scale: size / 16)
        }
    }

    /// The one who shares her bed, lying with his head on the far pillow, over the mattress (so it is drawn after the princess and her bed).
    private func drawPartnerInBed(_ character: Character, scale: CGFloat, onScreen: CGRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext, let ant = colony.ants.first(where: { $0.lying && !$0.isHidden }) else { return }
        let p = local(ant.pos)
        guard onScreen.contains(p), let role = character.breeds[min(ant.breedIndex, character.breeds.count - 1)].sprites,
              let lying = role.image(direction: .down, phase: 0) else { return }
        let size = CGFloat(role.frameSize) * role.pixelSize(scale: Double(scale)) * (ant.isChild ? 0.62 : 1)
        ctx.saveGState()
        ctx.interpolationQuality = .none
        ctx.translateBy(x: p.x, y: p.y + size * 0.05)
        ctx.rotate(by: -.pi / 2)
        ctx.draw(lying, in: CGRect(x: -size / 2, y: -size / 2, width: size, height: size))
        ctx.restoreGState()
        drawBlanket(at: CGPoint(x: p.x, y: p.y - size * 0.05), size: size * 1.05, mirrored: true)
    }

    // MARK: Props

    /// Draws rows of characters as pixels (`.` is empty), the bottom-left of the grid at `origin`.
    private func drawPixelGrid(_ rows: [String], palette: [Swift.Character: NSColor], origin: CGPoint, pixel: CGFloat) {
        for (r, row) in rows.enumerated() {
            for (c, symbol) in row.enumerated() {
                guard let color = palette[symbol] else { continue }
                color.setFill()
                NSBezierPath(rect: NSRect(x: origin.x + CGFloat(c) * pixel, y: origin.y + CGFloat(rows.count - 1 - r) * pixel,
                                          width: pixel, height: pixel)).fill()
            }
        }
    }

    private func drawProp(_ prop: Prop, at p: CGPoint, pixel: CGFloat, size: CGFloat) {
        let ground = p.y - size * 0.2 // where her feet are
        switch prop {
        case .teaTable:
            let palette: [Swift.Character: NSColor] = [
                "o": NSColor(calibratedRed: 0.27, green: 0.17, blue: 0.13, alpha: 1), "w": NSColor(calibratedWhite: 0.98, alpha: 1),
                "r": NSColor(calibratedRed: 0.84, green: 0.31, blue: 0.38, alpha: 1), "p": NSColor(calibratedRed: 0.47, green: 0.67, blue: 0.86, alpha: 1),
                "t": NSColor(calibratedWhite: 0.94, alpha: 1), "v": NSColor(calibratedRed: 0.77, green: 0.45, blue: 0.2, alpha: 1),
                "c": NSColor(calibratedWhite: 1, alpha: 1),
            ]
            drawPixelGrid(["...tt.....", "..pppp.vv.", "..pppp.cc.", ".oooooooo.", ".orrrrrro.", ".owwwwwwo.", "..o....o..", "..o....o.."],
                          palette: palette, origin: CGPoint(x: p.x + size * 0.95, y: ground), pixel: pixel)
        case .mat:
            NSColor(calibratedRed: 0.27, green: 0.17, blue: 0.13, alpha: 1).setFill()
            NSBezierPath(rect: NSRect(x: p.x - size * 0.7, y: ground - pixel * 2, width: size * 1.4, height: pixel * 3)).fill()
            NSColor(calibratedRed: 0.45, green: 0.76, blue: 0.5, alpha: 1).setFill()
            NSBezierPath(rect: NSRect(x: p.x - size * 0.7 + pixel * 0.5, y: ground - pixel * 1.5, width: size * 1.4 - pixel, height: pixel * 2)).fill()
        case .flowerPots:
            for k in 0..<3 {
                let x = p.x + size * 1.05 + CGFloat(k) * pixel * 5
                NSColor(calibratedRed: 0.6, green: 0.38, blue: 0.24, alpha: 1).setFill()
                NSBezierPath(rect: NSRect(x: x, y: ground, width: pixel * 3.5, height: pixel * 2.5)).fill()
                NSColor(calibratedRed: 0.35, green: 0.62, blue: 0.3, alpha: 1).setFill()
                NSBezierPath(rect: NSRect(x: x + pixel * 1.5, y: ground + pixel * 2.5, width: pixel * 0.8, height: pixel * 3)).fill()
                [NSColor(calibratedRed: 0.95, green: 0.4, blue: 0.5, alpha: 1), NSColor(calibratedRed: 1, green: 0.85, blue: 0.3, alpha: 1),
                 NSColor(calibratedRed: 0.85, green: 0.6, blue: 0.95, alpha: 1)][k].setFill()
                NSBezierPath(ovalIn: NSRect(x: x + pixel * 0.5, y: ground + pixel * 5, width: pixel * 2.8, height: pixel * 2.8)).fill()
            }
        case .bed:
            drawMattress(centerX: p.x, y: p.y, size: size, pixel: pixel, pillowOnLeft: true)
            if colony.romance.stage != .single { // a bed for two: a second mattress beside hers, its pillow at the far end
                drawMattress(centerX: p.x + Romance.bedOffset.x, y: p.y, size: size, pixel: pixel, pillowOnLeft: false)
            }
        case .arch:
            // the wedding arch: two posts and a bow of flowers, behind the two of them
            let post = NSColor(calibratedRed: 0.62, green: 0.45, blue: 0.3, alpha: 1)
            let colors = [NSColor(calibratedRed: 0.95, green: 0.45, blue: 0.6, alpha: 1), NSColor(calibratedWhite: 1, alpha: 1),
                          NSColor(calibratedRed: 0.98, green: 0.82, blue: 0.35, alpha: 1)]
            let left = p.x - size * 0.7, right = p.x + size * 0.7 + 8
            post.setFill()
            NSRect(x: left, y: ground, width: pixel * 1.4, height: size * 1.2).fill()
            NSRect(x: right, y: ground, width: pixel * 1.4, height: size * 1.2).fill()
            for k in 0...8 {
                let t = CGFloat(k) / 8
                let x = left + (right - left) * t
                let y = ground + size * 1.2 + sin(t * .pi) * size * 0.32
                colors[k % 3].setFill()
                NSBezierPath(ovalIn: NSRect(x: x - pixel * 1.2, y: y - pixel * 1.2, width: pixel * 2.4, height: pixel * 2.4)).fill()
            }
            for k in 0..<4 {
                colors[(k + 1) % 3].setFill()
                NSBezierPath(ovalIn: NSRect(x: left - pixel * 0.3, y: ground + CGFloat(k) * size * 0.28, width: pixel * 2, height: pixel * 2)).fill()
                NSBezierPath(ovalIn: NSRect(x: right - pixel * 0.3, y: ground + CGFloat(k) * size * 0.28, width: pixel * 2, height: pixel * 2)).fill()
            }
        }
    }

    /// A mattress and a pillow: the pillow at the head end.
    private func drawMattress(centerX x: CGFloat, y: CGFloat, size: CGFloat, pixel: CGFloat, pillowOnLeft: Bool) {
        let outline = NSColor(calibratedRed: 0.27, green: 0.17, blue: 0.13, alpha: 1)
        let mattress = NSRect(x: x - size * 0.72, y: y + size * 0.05, width: size * 1.44, height: size * 0.62)
        outline.setFill()
        NSBezierPath(roundedRect: mattress.insetBy(dx: -pixel * 0.6, dy: -pixel * 0.6), xRadius: pixel * 2, yRadius: pixel * 2).fill()
        NSColor(calibratedRed: 0.82, green: 0.87, blue: 0.95, alpha: 1).setFill()
        NSBezierPath(roundedRect: mattress, xRadius: pixel * 1.5, yRadius: pixel * 1.5).fill()
        let pillowX = pillowOnLeft ? x - size * 0.7 : x + size * 0.28
        let pillow = NSRect(x: pillowX, y: y + size * 0.16, width: size * 0.42, height: size * 0.42)
        outline.setFill()
        NSBezierPath(roundedRect: pillow.insetBy(dx: -pixel * 0.5, dy: -pixel * 0.5), xRadius: pixel * 1.5, yRadius: pixel * 1.5).fill()
        NSColor.white.setFill()
        NSBezierPath(roundedRect: pillow, xRadius: pixel * 1.2, yRadius: pixel * 1.2).fill()
    }

    /// The blanket over a sleeping princess, from her waist down (or, mirrored, over the one beside her).
    private func drawBlanket(at p: CGPoint, size: CGFloat, mirrored: Bool = false) {
        let pixel = size / 16
        let blanket = NSRect(x: mirrored ? p.x - size * 0.68 : p.x - size * 0.02, y: p.y + size * 0.06, width: size * 0.7, height: size * 0.6)
        NSColor(calibratedRed: 0.27, green: 0.17, blue: 0.13, alpha: 1).setFill()
        NSBezierPath(roundedRect: blanket.insetBy(dx: -pixel * 0.5, dy: -pixel * 0.5), xRadius: pixel, yRadius: pixel).fill()
        NSColor(calibratedRed: 0.55, green: 0.68, blue: 0.9, alpha: 1).setFill()
        NSBezierPath(roundedRect: blanket, xRadius: pixel * 0.8, yRadius: pixel * 0.8).fill()
        NSColor(calibratedWhite: 1, alpha: 0.9).setFill() // a folded-over edge
        NSBezierPath(rect: NSRect(x: mirrored ? blanket.maxX - pixel * 1.6 : blanket.minX, y: blanket.minY, width: pixel * 1.6, height: blanket.height)).fill()
    }

    /// The princess lying across the two goblins carrying her, head toward where they are going.
    private func drawCarriedPrincess(_ q: Queen, role: SpriteRole, scale: CGFloat, at p: CGPoint) {
        guard let ctx = NSGraphicsContext.current?.cgContext, let image = role.image(direction: .down, phase: 0) else { return }
        let size = CGFloat(role.frameSize) * role.pixelSize(scale: Double(scale))
        ctx.saveGState()
        ctx.interpolationQuality = .none
        ctx.translateBy(x: p.x, y: p.y + size * 0.6) // lifted over their heads
        ctx.rotate(by: CGFloat(q.heading) - .pi / 2)
        ctx.draw(image, in: CGRect(x: -size / 2, y: -size / 2, width: size, height: size))
        ctx.restoreGState()
    }

    /// Dark rounded label with white text, centred on `center`.
    private func drawPill(_ string: String, center: NSPoint, fontSize: CGFloat, tint: NSColor? = nil, alpha: CGFloat = 1) {
        let text = string as NSString
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: fontSize, weight: .medium),
            .foregroundColor: NSColor.white.withAlphaComponent(alpha),
        ]
        let size = text.size(withAttributes: attrs)
        let padX = fontSize * 0.9, padY = fontSize * 0.45
        let pill = NSRect(x: center.x - size.width / 2 - padX, y: center.y - size.height / 2 - padY,
                          width: size.width + padX * 2, height: size.height + padY * 2)
        (tint?.blended(withFraction: 0.55, of: .black) ?? NSColor.black).withAlphaComponent(0.6 * alpha).setFill()
        NSBezierPath(roundedRect: pill, xRadius: pill.height / 2, yRadius: pill.height / 2).fill()
        text.draw(at: NSPoint(x: pill.minX + padX, y: pill.minY + padY), withAttributes: attrs)
    }

    private func drawPickHint() {
        NSColor.black.withAlphaComponent(0.12).setFill()
        bounds.fill()
        drawPill("\(Characters.current.icon == nil ? Characters.current.emoji + " " : "")點一下，選擇\(Characters.current.nestName)的位置", center: NSPoint(x: bounds.midX, y: bounds.midY), fontSize: 22)
        drawPill("按 Esc 取消", center: NSPoint(x: bounds.midX, y: bounds.midY - 46), fontSize: 14)
    }

    private func drawFoodHint() {
        NSColor.black.withAlphaComponent(0.06).setFill()
        bounds.fill()
        guard let kind = colony.pendingFood else { return }
        drawPill("\(kind.emoji) 點一下，放下\(kind.label)　·　按 Esc 取消", center: NSPoint(x: bounds.midX, y: bounds.maxY - 70), fontSize: 16)
    }

    /// A puddle of water or a blob of honey, shrinking as the ants carry it off.
    private func drawFood(_ food: FoodSource, at p: CGPoint, scale: CGFloat) {
        let r = CGFloat(food.radius(scale: Double(scale)))
        let w = r * 1.25, h = r * 0.95 // a little wider than tall, like something spilled
        let body = NSRect(x: p.x - w, y: p.y - h, width: w * 2, height: h * 2)

        // soft shadow underneath
        NSColor(calibratedWhite: 0, alpha: 0.12).setFill()
        NSBezierPath(ovalIn: body.offsetBy(dx: 0.6, dy: -1.2)).fill()

        switch food.kind {
        case .water:
            NSColor(calibratedRed: 0.42, green: 0.70, blue: 0.95, alpha: 0.62).setFill()
            NSBezierPath(ovalIn: body).fill()
            NSColor(calibratedRed: 0.25, green: 0.52, blue: 0.85, alpha: 0.75).setStroke()
            let rim = NSBezierPath(ovalIn: body)
            rim.lineWidth = 0.8
            rim.stroke()
            NSColor(calibratedWhite: 1, alpha: 0.75).setFill() // highlight
            NSBezierPath(ovalIn: NSRect(x: p.x - w * 0.55, y: p.y + h * 0.15, width: w * 0.6, height: h * 0.32)).fill()
        case .fruit:
            drawTree(food, at: p)
        case .meat:
            drawMeat(food, at: p, w: w, h: h)
        case .loot:
            drawLoot(food, at: p)
        case .stew:
            drawStew(food, at: p)
        case .honey:
            // a main blob with a smaller drip beside it, so it looks gooey
            let drip = NSRect(x: p.x + w * 0.45, y: p.y - h * 0.95, width: w * 0.85, height: h * 0.75)
            for shape in [body, drip] {
                NSColor(calibratedRed: 0.93, green: 0.64, blue: 0.08, alpha: 0.96).setFill()
                NSBezierPath(ovalIn: shape).fill()
            }
            NSColor(calibratedRed: 0.70, green: 0.42, blue: 0.04, alpha: 0.85).setStroke()
            let rim = NSBezierPath(ovalIn: body)
            rim.lineWidth = 0.8
            rim.stroke()
            NSColor(calibratedRed: 1, green: 0.90, blue: 0.55, alpha: 0.9).setFill() // shine
            NSBezierPath(ovalIn: NSRect(x: p.x - w * 0.5, y: p.y + h * 0.2, width: w * 0.55, height: h * 0.3)).fill()
        }
    }

    /// A small pixel-style fruit tree; the red dots are the fruit still on it.
    private func drawTree(_ food: FoodSource, at p: CGPoint) {
        let u: CGFloat = 2 // one "pixel"
        func px(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ c: NSColor) {
            c.setFill()
            NSRect(x: p.x + x * u, y: p.y + y * u, width: w * u, height: h * u).fill()
        }
        let trunk = NSColor(calibratedRed: 0.42, green: 0.27, blue: 0.14, alpha: 1)
        let dark = NSColor(calibratedRed: 0.16, green: 0.42, blue: 0.20, alpha: 1)
        let leaf = NSColor(calibratedRed: 0.27, green: 0.62, blue: 0.27, alpha: 1)
        let light = NSColor(calibratedRed: 0.42, green: 0.76, blue: 0.36, alpha: 1)
        px(-1, 0, 2, 4, trunk)
        px(-4, 4, 8, 5, dark)
        px(-5, 5, 10, 3, dark)
        px(-3, 8, 6, 3, dark)
        px(-4, 5, 7, 4, leaf)
        px(-3, 8, 5, 2, leaf)
        px(-3, 8, 2, 1, light)
        px(-4, 7, 1, 1, light)
        let spots: [(CGFloat, CGFloat)] = [(-3, 5), (2, 6), (0, 8), (-1, 6), (3, 4), (-4, 7)]
        let fruit = NSColor(calibratedRed: 0.90, green: 0.18, blue: 0.16, alpha: 1)
        for i in 0..<min(food.amount, spots.count) { px(spots[i].0, spots[i].1, 1.4, 1.4, fruit) }
    }

    private func drawMeat(_ food: FoodSource, at p: CGPoint, w: CGFloat, h: CGFloat) {
        let bone = NSColor(calibratedRed: 0.96, green: 0.93, blue: 0.84, alpha: 1)
        bone.setFill()
        NSBezierPath(ovalIn: NSRect(x: p.x + w * 0.5, y: p.y + h * 0.1, width: w * 0.5, height: h * 0.5)).fill()
        NSBezierPath(ovalIn: NSRect(x: p.x + w * 0.5, y: p.y - h * 0.5, width: w * 0.5, height: h * 0.5)).fill()
        NSColor(calibratedRed: 0.78, green: 0.32, blue: 0.24, alpha: 1).setFill()
        NSBezierPath(ovalIn: NSRect(x: p.x - w, y: p.y - h, width: w * 1.7, height: h * 2)).fill()
        NSColor(calibratedRed: 0.55, green: 0.18, blue: 0.14, alpha: 0.9).setStroke()
        let rim = NSBezierPath(ovalIn: NSRect(x: p.x - w, y: p.y - h, width: w * 1.7, height: h * 2))
        rim.lineWidth = 0.8
        rim.stroke()
        NSColor(calibratedRed: 0.95, green: 0.6, blue: 0.5, alpha: 0.9).setFill()
        NSBezierPath(ovalIn: NSRect(x: p.x - w * 0.6, y: p.y + h * 0.1, width: w * 0.6, height: h * 0.5)).fill()
    }

    /// A pot of stew set down for the goblins: a dark iron pot, the stew inside, and steam while it is hot.
    private func drawStew(_ food: FoodSource, at p: CGPoint) {
        let t = Date().timeIntervalSinceReferenceDate
        NSColor(calibratedWhite: 0, alpha: 0.2).setFill()
        NSBezierPath(ovalIn: NSRect(x: p.x - 9, y: p.y - 5, width: 18, height: 6)).fill()
        NSColor(calibratedRed: 0.2, green: 0.18, blue: 0.2, alpha: 1).setFill()
        NSBezierPath(ovalIn: NSRect(x: p.x - 8, y: p.y - 4, width: 16, height: 10)).fill()
        NSColor(calibratedRed: 0.86, green: 0.5, blue: 0.2, alpha: 1).setFill()
        NSBezierPath(ovalIn: NSRect(x: p.x - 6.5, y: p.y - 0.5, width: 13, height: 6)).fill()
        NSColor(calibratedRed: 0.98, green: 0.74, blue: 0.4, alpha: 1).setFill()
        NSRect(x: p.x - 3, y: p.y + 2, width: 2, height: 1.5).fill()
        NSRect(x: p.x + 1.5, y: p.y + 3, width: 2, height: 1.5).fill()
        NSColor(calibratedRed: 0.28, green: 0.25, blue: 0.28, alpha: 1).setFill()
        NSRect(x: p.x - 9, y: p.y + 3, width: 2, height: 2).fill()
        NSRect(x: p.x + 7, y: p.y + 3, width: 2, height: 2).fill()
        for k in 0..<3 { // steam
            let phase = (t * 0.6 + Double(k) * 0.33).truncatingRemainder(dividingBy: 1)
            NSColor(calibratedWhite: 1, alpha: 0.4 * CGFloat(1 - phase)).setFill()
            NSBezierPath(ovalIn: NSRect(x: p.x - 4 + CGFloat(k) * 4 + CGFloat(sin(t * 2 + Double(k))) * 1.5, y: p.y + 6 + CGFloat(phase) * 14, width: 4, height: 3)).fill()
        }
        if food.amount > 1 { drawPill("×\(food.amount)", center: NSPoint(x: p.x, y: p.y + 24), fontSize: 8) }
    }

    /// A monster's leavings: a small gem in the colour of the material, with a sparkle that is brighter the rarer it is.
    private func drawLoot(_ food: FoodSource, at p: CGPoint) {
        let info = food.material.flatMap(Materials.info)
        let color = info?.color ?? NSColor.systemYellow
        let rarity = info?.rarity ?? .common
        let t = Date().timeIntervalSinceReferenceDate
        let bob = CGFloat(sin(t * 3 + Double(food.id))) * 0.8
        NSColor(calibratedWhite: 0, alpha: 0.18).setFill()
        NSBezierPath(ovalIn: NSRect(x: p.x - 5, y: p.y - 5, width: 10, height: 4)).fill()
        let dark = color.blended(withFraction: 0.4, of: .black) ?? color, light = color.blended(withFraction: 0.55, of: .white) ?? color
        let y = p.y - 1 + bob
        dark.setFill()
        NSRect(x: p.x - 4, y: y, width: 8, height: 6).fill()
        NSRect(x: p.x - 2, y: y - 2, width: 4, height: 2).fill()
        NSRect(x: p.x - 2, y: y + 6, width: 4, height: 2).fill()
        color.setFill()
        NSRect(x: p.x - 3, y: y + 1, width: 6, height: 5).fill()
        NSRect(x: p.x - 1, y: y - 1, width: 2, height: 1).fill()
        light.setFill()
        NSRect(x: p.x - 2, y: y + 4, width: 2, height: 2).fill()
        if rarity != .common, Int(t * 2 + Double(food.id)) % 3 == 0 { // twinkle
            NSColor.white.setFill()
            NSRect(x: p.x + 4, y: y + 6, width: 2, height: 2).fill()
            if rarity == .rare { NSRect(x: p.x - 6, y: y + 2, width: 2, height: 2).fill() }
        }
        if food.amount > 1 { drawPill("×\(food.amount)", center: NSPoint(x: p.x, y: p.y + 14), fontSize: 8) }
    }

    /// "+2 黏液" labels rising from where things were delivered.
    private func drawFloaters() {
        for (n, f) in colony.floaters.enumerated() {
            let p = local(f.pos)
            guard bounds.insetBy(dx: -60, dy: -60).contains(p) else { continue }
            drawPill(f.text, center: NSPoint(x: p.x, y: p.y + 24 + CGFloat(n) * 20 + CGFloat(f.age) * 14), fontSize: 11, tint: f.rarity.color, alpha: CGFloat(max(0, min(1, 2.2 - f.age))))
        }
    }

    /// Green pluses drifting up around the princess while she tends the wounded.
    private func drawHealPulses() {
        guard let queen = colony.queen, !colony.healPulses.isEmpty else { return }
        let base = local(queen.pos)
        guard bounds.insetBy(dx: -60, dy: -60).contains(base) else { return }
        for (n, age) in colony.healPulses.enumerated() {
            let fade = CGFloat(max(0, 1 - age / 1.2))
            for k in 0..<3 {
                let x = base.x + CGFloat(k - 1) * 11 + CGFloat(n % 2) * 4, y = base.y + 26 + CGFloat(age) * 18 + CGFloat(k % 2) * 5
                NSColor(calibratedRed: 0.35, green: 0.85, blue: 0.45, alpha: fade).setFill()
                NSRect(x: x - 0.75, y: y - 3, width: 1.5, height: 6).fill()
                NSRect(x: x - 3, y: y - 0.75, width: 6, height: 1.5).fill()
            }
        }
    }

    /// A wandering animal: its walk frame, a shadow, and a red flash when it has just been hit.
    private func drawCreature(_ c: Creature, at p: CGPoint) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let kind = c.kind
        let facingRight = cos(c.heading) >= 0
        // an attack has its own poses and its own motion (a slime jumps and slams down, a rat crouches and springs)
        var attackLift: CGFloat = 0, attackForward: CGFloat = 0, squashX: CGFloat = 1, squashY: CGFloat = 1
        var pose = kind.image(facingRight: facingRight, phase: c.legPhase)
        if let attack = c.attackPose, let image = kind.attackImage(facingRight: facingRight, stage: attack.stage) {
            pose = image
            let p = CGFloat(attack.progress)
            switch (kind.monster.attackStyle, attack.stage) {
            case (.slam, 0): attackLift = 9 * sin(p * .pi / 2)
            case (.slam, _): attackLift = 9 * (1 - p) * (1 - p); squashX = 1 + 0.18 * p; squashY = 1 - 0.14 * p
            case (.bite, 0): attackForward = -3 * p
            case (.bite, _): attackForward = -3 + 10 * sin(p * .pi)
            default: break
            }
        }
        guard let image = pose else { return }
        let s = CGFloat(c.scale)
        let w = CGFloat(image.width) * CGFloat(kind.pixelScale) * s * squashX, h = CGFloat(image.height) * CGFloat(kind.pixelScale) * s * squashY
        NSColor(calibratedWhite: 0, alpha: 0.16).setFill()
        let shadow = w * 0.8 * (1 - (CGFloat(c.lift) + attackLift) * 0.04)
        NSBezierPath(ovalIn: NSRect(x: p.x - shadow / 2, y: p.y - 3, width: shadow, height: 6)).fill()
        ctx.interpolationQuality = .none
        let forward = CGFloat(facingRight ? 1 : -1) * attackForward
        let rect = CGRect(x: p.x - w / 2 + forward, y: p.y - h * 0.12 + CGFloat(c.lift) + attackLift, width: w, height: h)
        ctx.draw(image, in: rect)
        if c.hurt > 0 {
            ctx.saveGState()
            ctx.clip(to: rect, mask: image)
            ctx.setFillColor(NSColor(calibratedRed: 1, green: 0.15, blue: 0.1, alpha: 0.55).cgColor)
            ctx.fill(rect)
            ctx.restoreGState()
        }
        if kind.hostile, c.hp < kind.hp * (c.generation == 0 ? 1 : 0.4) { // a little health bar once it has been hurt
            let full = kind.hp * (c.generation == 0 ? 1 : 0.4), bar = w * 0.8
            NSColor(calibratedWhite: 0, alpha: 0.55).setFill()
            NSRect(x: p.x - bar / 2 - 0.5, y: rect.maxY + 2.5, width: bar + 1, height: 3).fill()
            NSColor(calibratedRed: 0.85, green: 0.2, blue: 0.2, alpha: 1).setFill()
            NSRect(x: p.x - bar / 2, y: rect.maxY + 3, width: bar * CGFloat(max(0, c.hp / full)), height: 2).fill()
        }
    }

    /// A red "+" over goblins that got bitten and are limping home.
    private func drawWoundedMarks(onScreen: NSRect) {
        for ant in colony.ants where ant.isWounded && !ant.isHidden {
            let p = local(ant.pos)
            guard onScreen.contains(p) else { continue }
            NSColor.white.setFill()
            NSRect(x: p.x - 3, y: p.y + 12, width: 6, height: 6).fill()
            NSColor(calibratedRed: 0.85, green: 0.1, blue: 0.1, alpha: 1).setFill()
            NSRect(x: p.x - 0.75, y: p.y + 12.5, width: 1.5, height: 5).fill()
            NSRect(x: p.x - 2.5, y: p.y + 14.25, width: 5, height: 1.5).fill()
        }
    }

    /// Yellow sparks where something was hit.
    private func drawHitBurst(at p: CGPoint, age: Double) {
        let t = CGFloat(min(1, age / 0.35))
        NSColor(calibratedRed: 1, green: 0.85, blue: 0.2, alpha: 1 - t).setFill()
        for i in 0..<6 {
            let a = CGFloat(i) * .pi / 3 + 0.4
            let d = 4 + 9 * t
            NSRect(x: p.x + cos(a) * d - 1.25, y: p.y + 6 + sin(a) * d - 1.25, width: 2.5, height: 2.5).fill()
        }
    }

    /// Edit mode: a faint dim, a dashed ring around the nest as the handle, and a hint on the nest's screen.
    private func drawEditOverlay() {
        NSColor.black.withAlphaComponent(0.08).setFill()
        bounds.fill()
        guard let nest = colony.nest else { return }
        let p = CGPoint(x: nest.x - origin.x, y: nest.y - origin.y)
        guard bounds.insetBy(dx: -60, dy: -60).contains(p) else { return }

        let r = nestGrabRadius
        let ring = NSBezierPath(ovalIn: NSRect(x: p.x - r, y: p.y - r, width: r * 2, height: r * 2))
        ring.lineWidth = 3
        NSColor.black.withAlphaComponent(0.35).setStroke()
        ring.stroke()
        ring.lineWidth = 1.5
        ring.setLineDash([5, 4], count: 2, phase: 0)
        NSColor.white.withAlphaComponent(0.95).setStroke()
        ring.stroke()

        drawPill("拖曳\(Characters.current.nestName)到新位置　·　Esc 或 Return 完成", center: NSPoint(x: bounds.midX, y: bounds.maxY - 70), fontSize: 16)
    }

    private func drawNest(at p: CGPoint, antCount: Int) {
        guard bounds.insetBy(dx: -100, dy: -100).contains(p) else { return }
        let f: CGFloat = 1
        if Settings.shared.campID == Camps.customID, let image = NestImageStore.image {
            let width = CGFloat(Settings.shared.nestImageWidth) * f
            let height = width * image.size.height / max(image.size.width, 1)
            image.draw(in: NSRect(x: p.x - width / 2, y: p.y - height / 2, width: width, height: height),
                       from: .zero, operation: .sourceOver, fraction: 1)
        } else if let style = Camps.current, let ctx = NSGraphicsContext.current?.cgContext {
            // the camp grows in stages as more goblins live in it; the entrance sits exactly on the nest spot
            let stage = style.stage(forCount: antCount)
            let pixel = CGFloat(style.pixelScale) * f
            let width = CGFloat(stage.image.width) * pixel, height = CGFloat(stage.image.height) * pixel
            ctx.saveGState()
            ctx.interpolationQuality = .none
            ctx.draw(stage.image, in: CGRect(x: p.x - stage.entrance.x * pixel, y: p.y - (CGFloat(stage.image.height) - stage.entrance.y) * pixel,
                                             width: width, height: height))
            ctx.restoreGState()
        } else {
            // no camp pictures could be found: a plain patch of earth
            NSColor(calibratedRed: 0.55, green: 0.40, blue: 0.26, alpha: 0.9).setFill()
            NSBezierPath(ovalIn: NSRect(x: p.x - 14 * f, y: p.y - 8 * f, width: 28 * f, height: 16 * f)).fill()
            NSColor(calibratedWhite: 0.08, alpha: 1).setFill()
            NSBezierPath(ovalIn: NSRect(x: p.x - 6 * f, y: p.y - 3 * f, width: 12 * f, height: 6 * f)).fill()
        }
    }

    private func drawSpeck(at p: CGPoint, radius: CGFloat, color: NSColor) {
        color.setFill()
        NSBezierPath(ovalIn: NSRect(x: p.x - radius, y: p.y - radius, width: radius * 2, height: radius * 2)).fill()
    }

    private func drawHeart(at c: CGPoint, size s: CGFloat, alpha: CGFloat) {
        NSColor(calibratedRed: 0.95, green: 0.3, blue: 0.42, alpha: max(0, alpha)).setFill()
        NSRect(x: c.x - 2 * s, y: c.y + 0.5 * s, width: 1.6 * s, height: 1.6 * s).fill()
        NSRect(x: c.x + 0.4 * s, y: c.y + 0.5 * s, width: 1.6 * s, height: 1.6 * s).fill()
        NSRect(x: c.x - 2 * s, y: c.y - 0.6 * s, width: 4 * s, height: 1.3 * s).fill()
        NSRect(x: c.x - 1 * s, y: c.y - 1.5 * s, width: 2 * s, height: 1 * s).fill()
    }

    /// A speech bubble, with "…" in it while somebody speaks (or a heart).
    private func drawBubble(at c: CGPoint, size s: CGFloat, dots: Int, heart: Bool) {
        let box = NSRect(x: c.x - 4 * s, y: c.y, width: 8 * s, height: 5 * s)
        NSColor(calibratedRed: 0.27, green: 0.17, blue: 0.13, alpha: 0.9).setFill()
        NSBezierPath(roundedRect: box.insetBy(dx: -0.6 * s, dy: -0.6 * s), xRadius: 2 * s, yRadius: 2 * s).fill()
        NSColor.white.setFill()
        NSBezierPath(roundedRect: box, xRadius: 1.6 * s, yRadius: 1.6 * s).fill()
        NSBezierPath(rect: NSRect(x: c.x - 0.8 * s, y: c.y - 1.4 * s, width: 1.6 * s, height: 1.6 * s)).fill()
        if heart {
            drawHeart(at: CGPoint(x: c.x, y: c.y + 2.6 * s), size: s * 0.7, alpha: 1)
        } else if dots > 0 {
            NSColor(calibratedWhite: 0.3, alpha: 1).setFill()
            for k in 0..<dots { NSRect(x: c.x + (CGFloat(k) - 1) * 2.2 * s - 0.5 * s, y: c.y + 2 * s, width: 1 * s, height: 1 * s).fill() }
        }
    }

    /// Floating "z z z", yawn bubbles and thought bubbles beside the queen's head.
    private func drawDecoration(_ decoration: Queen.Decoration, at p: CGPoint, scale s: CGFloat) {
        switch decoration {
        case .steam(let clock):
            // wisps rising from the cup in her hand (about art pixel (11, 7))
            let cup = CGPoint(x: p.x + 3 * s, y: p.y + 5.8 * s)
            for k in 0..<3 {
                let t = (clock * 0.8 + Double(k) / 3).truncatingRemainder(dividingBy: 1)
                NSColor(calibratedWhite: 1, alpha: CGFloat(0.85 * sin(t * .pi))).setFill()
                let x = cup.x + CGFloat(sin(t * 6 + Double(k))) * s * 0.8 + CGFloat(k - 1) * s * 0.8
                NSBezierPath(rect: NSRect(x: x, y: cup.y + CGFloat(t) * 7 * s, width: s * 0.9, height: s * 0.9)).fill()
            }
        case .hearts(let clock):
            for k in 0..<3 {
                let t = (clock * 0.5 + Double(k) / 3).truncatingRemainder(dividingBy: 1)
                drawHeart(at: CGPoint(x: p.x + (CGFloat(k) - 1) * 6 * s + CGFloat(sin(t * 6 + Double(k) * 2)) * 1.5 * s, y: p.y + (13 + 10 * CGFloat(t)) * s),
                          size: s * 0.9, alpha: CGFloat(sin(t * .pi)))
            }
        case .anger(let clock):
            let pulse = 1 + 0.15 * CGFloat(sin(clock * 9))
            NSColor(calibratedRed: 0.9, green: 0.15, blue: 0.15, alpha: 1).setStroke()
            let path = NSBezierPath()
            let c = CGPoint(x: p.x + 5 * s, y: p.y + 14.5 * s), r = 2.2 * s * pulse
            for (dx, dy) in [(-1.0, 1.0), (1.0, 1.0), (-1.0, -1.0), (1.0, -1.0)] {
                path.move(to: CGPoint(x: c.x + CGFloat(dx) * r * 0.35, y: c.y + CGFloat(dy) * r * 0.35))
                path.line(to: CGPoint(x: c.x + CGFloat(dx) * r, y: c.y + CGFloat(dy) * r))
            }
            path.lineWidth = max(1, s * 0.6)
            path.stroke()
        case .chat(let clock):
            // two speech bubbles taking turns: over her head (she lies down, so a little to the side) and over his
            let turn = Int(clock / 2.2) % 2
            drawBubble(at: CGPoint(x: p.x - 4 * s, y: p.y + 13 * s), size: s, dots: turn == 0 ? 3 : 0, heart: turn == 0 && Int(clock / 2.2) % 4 == 0)
            drawBubble(at: CGPoint(x: p.x + Romance.bedOffset.x + 4 * s, y: p.y + 12 * s), size: s, dots: turn == 1 ? 3 : 0, heart: false)
        case .confetti(let clock):
            let colors: [NSColor] = [.systemPink, .systemYellow, .white, .systemTeal]
            for k in 0..<14 {
                let t = (clock * 0.6 + Double(k) * 0.137).truncatingRemainder(dividingBy: 1)
                let x = p.x + (CGFloat(k) - 7) * 4.5 * s * 0.6 + CGFloat(sin(t * 8 + Double(k))) * 2 * s
                colors[k % colors.count].withAlphaComponent(CGFloat(1 - t * 0.6)).setFill()
                NSRect(x: x, y: p.y + (26 - 26 * CGFloat(t)) * s, width: s * 1.1, height: s * 1.1).fill()
            }
        case .notes(let clock):
            let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 7 * s, weight: .bold),
                                                        .foregroundColor: NSColor(calibratedRed: 0.35, green: 0.3, blue: 0.7, alpha: 1)]
            for (k, note) in ["♪", "♫", "♪"].enumerated() {
                let t = (clock * 0.6 + Double(k) / 3).truncatingRemainder(dividingBy: 1)
                let x = p.x + (k == 1 ? -9 : 8) * s + CGFloat(sin(t * 5)) * 2 * s
                (note as NSString).draw(at: NSPoint(x: x, y: p.y + (12 + 12 * CGFloat(t)) * s),
                                        withAttributes: attrs.merging([.foregroundColor: NSColor(calibratedRed: 0.35, green: 0.3, blue: 0.7, alpha: CGFloat(sin(t * .pi)))]) { $1 })
            }
        case .zzz(let clock):
            for k in 0..<3 {
                let t = (clock * 0.35 + Double(k) / 3).truncatingRemainder(dividingBy: 1)
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: CGFloat(6 + t * 5) * s, weight: .bold),
                    .foregroundColor: NSColor(calibratedWhite: 0.25, alpha: CGFloat(sin(t * .pi))),
                ]
                ("z" as NSString).draw(at: NSPoint(x: p.x + CGFloat(7 + t * 9) * s, y: p.y + CGFloat(6 + t * 14) * s), withAttributes: attrs)
            }
        case .yawnBubble(let progress):
            for (delay, dx) in [(0.0, 9.0), (0.25, 12.0)] {
                let t = max(0, progress - delay) / (1 - delay)
                guard t > 0 else { continue }
                let r = CGFloat(1.3 + 1.4 * t) * s
                let center = CGPoint(x: p.x + CGFloat(dx) * s, y: p.y + CGFloat(6 + t * 10) * s)
                let rect = NSRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)
                NSColor(calibratedWhite: 1, alpha: 0.6 * CGFloat(1 - t)).setFill()
                NSColor(calibratedWhite: 0.35, alpha: 0.8 * CGFloat(1 - t)).setStroke()
                let bubble = NSBezierPath(ovalIn: rect)
                bubble.lineWidth = 0.5
                bubble.fill()
                bubble.stroke()
            }
        case .sparkles(let progress):
            // little four-point stars twinkling around her while she changes
            for k in 0..<9 {
                let seed = Double(k) * 2.399
                let t = (progress * 1.3 + Double(k) / 9).truncatingRemainder(dividingBy: 1)
                let x = p.x + CGFloat(cos(seed) * (10 + 7 * t)) * s
                let y = p.y + 8 * s + CGFloat(sin(seed) * (10 + 7 * t)) * s + CGFloat(t * 6) * s
                let a = CGFloat(sin(t * .pi))
                (k % 2 == 0 ? NSColor(calibratedRed: 1, green: 0.95, blue: 0.55, alpha: a) : NSColor(calibratedWhite: 1, alpha: a)).setFill()
                let u = 1.2 * s
                NSBezierPath(rect: NSRect(x: x - u / 2, y: y - u * 1.5, width: u, height: u * 3)).fill()
                NSBezierPath(rect: NSRect(x: x - u * 1.5, y: y - u / 2, width: u * 3, height: u)).fill()
            }
        case .thought(let emoji, let progress):
            let a = CGFloat(min(1, progress / 0.15, (1 - progress) / 0.15))
            NSColor(calibratedWhite: 1, alpha: 0.92 * a).setFill()
            NSColor(calibratedWhite: 0.35, alpha: 0.8 * a).setStroke()
            func circle(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat) {
                let path = NSBezierPath(ovalIn: NSRect(x: p.x + x * s - r * s, y: p.y + y * s - r * s, width: r * 2 * s, height: r * 2 * s))
                path.lineWidth = 0.5
                path.fill()
                path.stroke()
            }
            circle(6, 9, 1.4)
            circle(8.5, 12.5, 2.2)
            circle(13, 19, 8)
            guard let ctx = NSGraphicsContext.current?.cgContext else { return }
            ctx.saveGState()
            ctx.setAlpha(a)
            let text = emoji as NSString
            let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 10 * s)]
            let size = text.size(withAttributes: attrs)
            text.draw(at: NSPoint(x: p.x + 13 * s - size.width / 2, y: p.y + 19 * s - size.height / 2), withAttributes: attrs)
            ctx.restoreGState()
        }
    }

    /// A small five-petal flower with a yellow heart.
    private func drawFlower(at p: CGPoint, alpha: Double, scale: CGFloat) {
        let petal = 2.0 * max(1, scale), ring = 2.4 * max(1, scale)
        NSColor(calibratedWhite: 0.25, alpha: 0.5 * alpha).setFill() // tiny stem shadow
        NSBezierPath(rect: NSRect(x: p.x - 0.5, y: p.y - ring - 2.5, width: 1, height: 2.5)).fill()
        for k in 0..<5 {
            let angle = CGFloat(k) * 2 * .pi / 5 + .pi / 2
            NSColor(calibratedRed: 1, green: 0.78, blue: 0.86, alpha: alpha).setFill()
            NSBezierPath(ovalIn: NSRect(x: p.x + cos(angle) * ring - petal / 2, y: p.y + sin(angle) * ring - petal / 2, width: petal, height: petal)).fill()
        }
        NSColor(calibratedRed: 0.98, green: 0.82, blue: 0.25, alpha: alpha).setFill()
        NSBezierPath(ovalIn: NSRect(x: p.x - petal * 0.45, y: p.y - petal * 0.45, width: petal * 0.9, height: petal * 0.9)).fill()
    }

}
