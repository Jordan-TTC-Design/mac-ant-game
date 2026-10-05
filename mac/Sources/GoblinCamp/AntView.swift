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
    /// The camp's own view (MapWindow), wherever it is now (the main window's page, or its small window).
    static weak var campView: AntView?
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
        case .running where isMap && colony.decorating:
            decorDown(at: screenLocation(of: event), shift: event.modifierFlags.contains(.shift))
        case .running where isMap:
            let p = screenLocation(of: event)
            colony.handDown(at: p, on: handTarget(at: p))
            needsDisplay = true
        default:
            break
        }
    }

    override func mouseDragged(with event: NSEvent) {
        if colony.phase == .running, isMap, colony.decorating {
            decorDragged(to: screenLocation(of: event))
            return
        }
        if colony.phase == .running, isMap, colony.hand.press != nil {
            colony.handDragged(to: screenLocation(of: event))
            return
        }
        guard draggingNest else { return }
        let mouse = screenLocation(of: event)
        colony.moveNest(to: CGPoint(x: mouse.x + dragOffset.width, y: mouse.y + dragOffset.height))
    }

    override func mouseUp(with event: NSEvent) {
        if colony.phase == .running, isMap, colony.decorating {
            decorUp()
            return
        }
        if colony.phase == .running, isMap, colony.hand.press != nil {
            colony.handUp(at: screenLocation(of: event))
            return
        }
        guard draggingNest else { return }
        draggingNest = false
        NSCursor.openHand.set()
        colony.nestDragEnded()
    }

    // MARK: The hand (Touch.swift)

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        guard isMap else { return }
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseMoved, .mouseEnteredAndExited, .activeAlways, .inVisibleRect], owner: self))
    }

    override func mouseMoved(with event: NSEvent) {
        guard isMap, colony.phase == .running else { return }
        let p = screenLocation(of: event)
        if colony.decorating { colony.hand.track(p); colony.hand.hover = nil; return }
        colony.handMoved(to: p, over: handTarget(at: p))
    }

    override func mouseExited(with event: NSEvent) {
        guard isMap else { return }
        colony.handMoved(to: nil, over: nil)
    }

    override func rightMouseDown(with event: NSEvent) {
        guard isMap, colony.phase == .running else { return super.rightMouseDown(with: event) }
        let p = screenLocation(of: event)
        if colony.decorating { // a right-click takes a decoration (a fence piece) away
            if let i = colony.decorAt(p) { colony.removeDecor(i); DecorPalette.shared.refresh("收回了。"); needsDisplay = true }
            return
        }
        if case .beast(let id)? = handTarget(at: p), let beast = colony.ranch.beasts.first(where: { $0.id == id }) { // an animal of the ranch
            let menu = NSMenu()
            let title = NSMenuItem(title: colony.beastLine(id) ?? "", action: nil, keyEquivalent: "")
            title.isEnabled = false
            menu.addItem(title)
            menu.addItem(.separator())
            if colony.canButcher(id) {
                let meat = NSMenuItem(title: "宰了（烤肉 ×3）", action: #selector(beastPicked(_:)), keyEquivalent: "")
                meat.target = self
                meat.representedObject = BeastPick(id: id, butcher: true)
                menu.addItem(meat)
            }
            let call = NSMenuItem(title: beast.name.isEmpty ? "取名字…" : "改名字…（\(beast.name)）", action: #selector(beastNamed(_:)), keyEquivalent: "")
            call.target = self
            call.representedObject = BeastPick(id: beast.id, butcher: false)
            menu.addItem(call)
            let free = NSMenuItem(title: "放走", action: #selector(beastPicked(_:)), keyEquivalent: "")
            free.target = self
            free.representedObject = BeastPick(id: beast.id, butcher: false)
            menu.addItem(free)
            NSMenu.popUpContextMenu(menu, with: event, for: self)
            return
        }
        guard case .ant(let id)? = handTarget(at: p), let ant = colony.ants.first(where: { $0.id == id }) else { return }
        let orders = colony.orders(for: id)
        guard !orders.isEmpty else { return }
        let breeds = Characters.current.breeds
        let breed = breeds.isEmpty ? "" : breeds[min(ant.breedIndex, breeds.count - 1)].name
        let menu = NSMenu()
        let title = NSMenuItem(title: "\(ant.name)（\(breed)）", action: nil, keyEquivalent: "")
        title.isEnabled = false
        menu.addItem(title)
        menu.addItem(.separator())
        for (order, label) in orders {
            let item = NSMenuItem(title: label, action: #selector(orderPicked(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = OrderPick(id: id, order: order)
            menu.addItem(item)
        }
        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }

    private final class BeastPick {
        let id: Int
        let butcher: Bool
        init(id: Int, butcher: Bool) { self.id = id; self.butcher = butcher }
    }

    @objc private func beastNamed(_ sender: NSMenuItem) {
        guard let pick = sender.representedObject as? BeastPick, let beast = colony.ranch.beasts.first(where: { $0.id == pick.id }) else { return }
        let alert = NSAlert()
        alert.messageText = "幫牠取個名字"
        alert.informativeText = "最多 8 個字；留空白就是不取名。"
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        field.stringValue = beast.name
        alert.accessoryView = field
        alert.addButton(withTitle: "好")
        alert.addButton(withTitle: "取消")
        alert.window.initialFirstResponder = field
        if alert.runInFront() == .alertFirstButtonReturn { colony.name(beast: pick.id, field.stringValue) }
    }

    @objc private func beastPicked(_ sender: NSMenuItem) {
        guard let pick = sender.representedObject as? BeastPick else { return }
        if pick.butcher { colony.butcher(pick.id) } else { colony.release(beast: pick.id) }
    }

    private final class OrderPick {
        let id: Int
        let order: HandOrder
        init(id: Int, order: HandOrder) { self.id = id; self.order = order }
    }

    @objc private func orderPicked(_ sender: NSMenuItem) {
        guard let pick = sender.representedObject as? OrderPick else { return }
        colony.order(pick.id, pick.order)
    }

    /// The sprite box of a goblin (camp coordinates): what a click must land in.
    private func spriteBox(_ ant: Ant, role: SpriteRole, scale: CGFloat) -> CGRect {
        let pixel = role.pixelSize(scale: Double(scale)) * (ant.isChild ? 0.62 : 1)
        let size = CGFloat(role.frameSize) * pixel
        let lift = CGFloat(ant.touch?.lift ?? 0)
        // the drawn figure fills only the middle of its frame: a little narrower than the frame, from the feet to the top of the head
        return CGRect(x: ant.pos.x - size * 0.32, y: ant.pos.y - size * 0.2 + lift, width: size * 0.64, height: size * 0.85)
    }

    /// What is under the pointer: a goblin (the one drawn on top), the princess, or an animal.
    func handTarget(at p: CGPoint) -> HandTarget? {
        let character = Characters.current
        let scale = CGFloat(Settings.shared.antScale)
        if let held = colony.hand.press?.target { if case .ant = held { return held } }
        if colony.merchant.visit != nil, colony.merchant.phase != .away,
           CGRect(x: colony.merchant.pos.x - 26, y: colony.merchant.pos.y - 4, width: 52, height: 42).contains(p) { return .merchant }
        let breeds = character.breeds
        if !breeds.isEmpty {
            for ant in colony.ants.sorted(by: { $0.pos.y < $1.pos.y }) where colony.canTouch(ant) { // (the nearest is drawn on top)
                guard let role = breeds[min(ant.breedIndex, breeds.count - 1)].sprites else { continue }
                if spriteBox(ant, role: role, scale: scale).insetBy(dx: -2, dy: -2).contains(p) { return .ant(ant.id) }
            }
        }
        if let id = colony.wispAt(p) { return .wisp(id) }
        if let id = colony.beastAt(p) { return .beast(id) }
        if let q = colony.queen, q.arrived, q.alpha > 0.5, !q.isCarried, let role = character.queenRole(outfit: colony.outfitIndex) {
            let size = CGFloat(role.frameSize) * role.pixelSize(scale: Double(scale))
            if CGRect(x: q.pos.x - size * 0.3, y: q.pos.y - size * 0.2, width: size * 0.6, height: size * 0.9).contains(p) { return .queen }
        }
        for c in colony.creatures.reversed() {
            let r = c.kind.radius * c.scale + 6
            if hypot(c.pos.x - p.x, c.pos.y + r * 0.4 - p.y) < r { return .creature(c.id) }
        }
        return nil
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
            if colony.hand.shake > 0, let ctx = NSGraphicsContext.current?.cgContext { // a punch or a heavy landing shakes the window
                ctx.translateBy(x: .random(in: -2.5...2.5), y: .random(in: -2...2))
            }
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
        if let scene = colony.scene, scene.isStrip {
            tintStripForest(scene, strip: rect)
            drawStripScene(scene, ctx: ctx)
        }
    }

    /// The seasons over the strip's forest (just the forest: the camp stands over it in its own colours): a light frost in winter, orange
    /// leaves in autumn, a little frost in early spring. Winter's snow lies on the path (see `TerrainScene.paintStripSnow`).
    private func tintStripForest(_ scene: TerrainScene, strip: CGRect) {
        guard scene.life != nil else { return }
        let x = scene.seasonPosition
        let tint: (NSColor, CGFloat)? = x >= 3.0 ? (NSColor(calibratedRed: 0.88, green: 0.94, blue: 1, alpha: 1), 0.24)
            : x >= 2.1 ? (NSColor(calibratedRed: 0.92, green: 0.5, blue: 0.1, alpha: 1), CGFloat(min(0.34, (x - 2.1) * 0.7)))
            : x < 0.4 ? (NSColor(calibratedRed: 0.9, green: 0.96, blue: 1, alpha: 1), CGFloat((0.4 - x) * 0.6)) : nil
        guard let (color, alpha) = tint, alpha > 0.01 else { return }
        color.withAlphaComponent(alpha).setFill()
        NSRect(x: strip.minX - origin.x, y: strip.minY - origin.y, width: strip.width, height: strip.height).fill(using: .sourceAtop) // (only over the forest, not the empty screen)
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
        if isMap, Holidays.today == Holidays.christmas, let nest = colony.nest { drawChristmasTree(at: local(colony.nearestWalkable(to: CGPoint(x: nest.x - 70, y: nest.y + 30)))) }
        if let fire = colony.fire { drawFire(at: CGPoint(x: fire.x - origin.x, y: fire.y - origin.y)) }
        else if let pit = colony.ants.lazy.compactMap({ ant -> CGPoint? in // somebody sits round the fire pit: it is lit
            if case .activity(.fireside(let spot, let fire), _) = ant.mode, hypot(spot.x - ant.pos.x, spot.y - ant.pos.y) < 40 { return fire }
            return nil
        }).first { drawFire(at: local(pit)) }
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
        drawGraves(scale: scale, onScreen: onScreen)
        if isMap { for k in colony.decorFlat() { drawDecorItem(k) } } // (what lies on the ground; the standing ones are drawn among the residents)
        if character.worker != nil {
            drawSpriteWorkers(character, scale: scale, onScreen: onScreen)
        } else {
            // no sprites for this character (its folder is missing): plain dots so something still shows
            for ant in colony.ants where !ant.isHidden {
                let p = local(ant.pos)
                if onScreen.contains(p) { drawSpeck(at: p, radius: 5, color: NSColor(calibratedRed: 0.42, green: 0.7, blue: 0.25, alpha: 1)) }
            }
        }

        if isMap { drawDesks() } // (in front of the scribes sitting behind them)
        if isMap, colony.merchant.visit != nil, colony.merchant.phase != .away { drawMerchant() }
        if isMap { drawRanchAir() }
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

        drawHandEffects()
        if isMap { drawHoliday() }
        if isMap, colony.decorating { drawDecorMode() }
        if colony.hand.press == nil, let target = colony.hand.hover {
            switch target {
            case .ant(let id):
                if id != colony.selectedAntID, let ant = colony.ants.first(where: { $0.id == id }), ant.touch == nil {
                    let p = local(ant.pos)
                    drawPill("\(ant.name)・\(ant.stateLabel)", center: NSPoint(x: p.x, y: p.y + 30 * scale), fontSize: 10)
                }
            case .queen:
                if let q = colony.queen { drawPill(colony.princessName.isEmpty ? "公主" : colony.princessName, center: NSPoint(x: local(q.pos).x, y: local(q.pos).y + 36 * scale), fontSize: 10) }
            case .creature(let id):
                if let c = colony.creatures.first(where: { $0.id == id }) {
                    let p = local(c.pos)
                    let hint = colony.canCatch(c) ? (colony.ranch.pens.isEmpty ? "・圍一圈柵欄就能養" : "・拎起來丟進牧場") : ""
                    drawPill(c.kind.name + hint, center: NSPoint(x: p.x, y: p.y + CGFloat(c.kind.radius * c.scale) + 16), fontSize: 10)
                }
            case .beast(let id):
                if id == 0, let v = colony.ranch.visitor, let line = colony.beastLine(0) {
                    drawPill(line, center: NSPoint(x: local(v.perch).x, y: local(v.perch).y + RanchRules.perchTop + 30), fontSize: 10)
                } else if let b = colony.ranch.beasts.first(where: { $0.id == id }), let line = colony.beastLine(id) {
                    drawPill(line, center: NSPoint(x: local(b.pos).x, y: local(b.pos).y + 28), fontSize: 10)
                }
            case .wisp(let id):
                if let w = colony.ranch.wisps.first(where: { $0.id == id }) {
                    drawPill("獸魂・拎起來放到養魂燈旁", center: NSPoint(x: local(w.pos).x, y: local(w.pos).y + 28), fontSize: 10)
                }
            case .merchant:
                if let visit = colony.merchant.visit {
                    let p = local(colony.merchant.pos)
                    drawPill("\(visit.merchant)・點一下交易", center: NSPoint(x: p.x, y: p.y + 46), fontSize: 10)
                }
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

    private func isDigging(_ activity: Ant.Activity?) -> Bool {
        if case .dig? = activity { return true }
        return false
    }

    /// The undead camp's graves: a small headstone on a mound of earth; one with somebody asleep in it has a soul-fire
    /// drifting over it and a "z" now and then.
    private func drawGraves(scale: CGFloat, onScreen: CGRect) {
        let graves = colony.graves
        guard !graves.isEmpty else { return }
        let u = max(1, (1.5 * scale).rounded())
        let sleepers = colony.ants.filter(\.inGrave).compactMap { ant -> CGPoint? in
            if case .activity(.grave(let spot), _) = ant.mode { return spot }
            return nil
        }
        let t = Date().timeIntervalSinceReferenceDate
        func px(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ c: NSColor) {
            c.setFill()
            NSRect(x: x, y: y, width: w * u, height: h * u).fill()
        }
        for (k, g) in graves.enumerated() {
            let p = local(g)
            guard onScreen.insetBy(dx: -30, dy: -30).contains(p) else { continue }
            let x = p.x - 4 * u, y = p.y - 2 * u
            // the mound
            px(x - u, y, 10, 2, NSColor(calibratedRed: 0.36, green: 0.27, blue: 0.2, alpha: 1))
            px(x, y + 2 * u, 8, 1, NSColor(calibratedRed: 0.44, green: 0.33, blue: 0.24, alpha: 1))
            // the headstone behind it, rounded at the top, with a crack or a cross
            let stone = NSColor(calibratedRed: 0.58, green: 0.6, blue: 0.64, alpha: 1)
            px(x + u, y + 3 * u, 6, 6, stone)
            px(x + 2 * u, y + 9 * u, 4, 1, stone)
            px(x + u, y + 3 * u, 1, 6, NSColor(calibratedRed: 0.44, green: 0.46, blue: 0.5, alpha: 1))
            let mark = NSColor(calibratedRed: 0.36, green: 0.38, blue: 0.42, alpha: 1)
            if k % 2 == 0 { px(x + 3.5 * u, y + 4.5 * u, 1, 4, mark); px(x + 2.5 * u, y + 6.5 * u, 3, 1, mark) }
            else { px(x + 3 * u, y + 5 * u, 1, 1, mark); px(x + 4 * u, y + 6 * u, 1, 1, mark); px(x + 3 * u, y + 7 * u, 1, 1, mark) }
            guard sleepers.contains(where: { hypot($0.x - g.x, $0.y - g.y) < 4 }) else { continue }
            // somebody is in there
            let bob = CGFloat(sin(t * 2 + Double(k))) * 2 * u
            let fire = NSColor(calibratedRed: 0.45, green: 0.95, blue: 0.85, alpha: 0.9)
            NSColor(calibratedRed: 0.45, green: 0.95, blue: 0.85, alpha: 0.18).setFill() // its glow
            NSBezierPath(ovalIn: NSRect(x: x + 0.5 * u, y: y + 10 * u + bob, width: 7 * u, height: 7 * u)).fill()
            px(x + 2.5 * u, y + 11.5 * u + bob, 3, 3, fire)
            px(x + 3 * u, y + 14.5 * u + bob, 2, 1, fire)
            px(x + 3.5 * u, y + 15.5 * u + bob, 1, 1, fire.withAlphaComponent(0.6))
            if Int(t + Double(k)) % 3 == 0 {
                let z = NSAttributedString(string: "z", attributes: [.font: NSFont.boldSystemFont(ofSize: 6 * u), .foregroundColor: NSColor.white.withAlphaComponent(0.8)])
                z.draw(at: CGPoint(x: x + 7 * u, y: y + 11 * u + bob))
            }
        }
    }

    private func drawSpriteWorkers(_ character: Character, scale: CGFloat, onScreen: CGRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let lastBreed = character.breeds.count - 1
        ctx.saveGState()
        ctx.interpolationQuality = .none // keep the pixels sharp
        var minded = Set<Int>() // young ones being minded (they get a heart)
        for other in colony.ants { if case .activity(.mind(let child), _) = other.mode { minded.insert(child) } }
        var said: [(text: String, at: CGPoint)] = [] // what the touched ones say, drawn over everything
        defer { drawSaid(said) }
        // far to near (the lower on the screen, the later), with the standing decorations in between: nobody walks "over" a house behind them
        var standing: [(y: CGFloat, draw: () -> Void)] = []
        if isMap {
            standing = colony.decorStanding().map { k in (colony.decorPoint(colony.decor[k]).y, { [unowned self] in self.drawDecorItem(k) }) }
            standing += colony.ranch.beasts.filter { $0.pen >= 0 }.map { b in (b.pos.y, { [unowned self] in self.drawBeast(b) }) }
            standing.sort { $0.y > $1.y }
        }
        defer { for item in standing { item.draw() } } // (those nearer than everybody)
        for ant in colony.ants.sorted(by: { $0.pos.y > $1.pos.y }) where !ant.isHidden {
            while let item = standing.first, item.y >= ant.pos.y {
                item.draw()
                standing.removeFirst()
            }
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
            if ant.lying || ant.inGrave { continue } // (in bed beside the princess: drawn with the bed; in a grave: the grave shows it)
            if let touch = ant.touch {
                if touch.lift > 0.5 { // its shadow stays on the ground
                    NSColor.black.withAlphaComponent(0.22).setFill()
                    NSBezierPath(ovalIn: NSRect(x: p.x - size * 0.22, y: p.y - size * 0.2, width: size * 0.44, height: size * 0.14)).fill()
                }
                p.y += CGFloat(touch.lift)
                if touch.anim == .shake { p.x += CGFloat(sin(touch.clock * 40)) * 1.3 }
                if touch.anim == .punch, let cursor = colony.hand.cursor { // a lunge at the pointer
                    let a = atan2(cursor.y - ant.pos.y, cursor.x - ant.pos.x), k = CGFloat(sin(min(1, touch.clock / 0.3) * .pi)) * 6
                    p.x += CGFloat(cos(a)) * k
                    p.y += CGFloat(sin(a)) * k
                }
                if let line = touch.line, touch.isHeld || touch.isFlying || touch.clock < 2.6 { said.append((line, CGPoint(x: p.x, y: p.y + size * 0.95))) }
                if touch.kind == .react, touch.anim == .collapse {
                    drawCollapse(touch, at: p, size: size, pixel: pixel)
                    continue
                }
                if touch.kind == .react, touch.anim == .dizzy, let lying = role.image(direction: .down, phase: 0) {
                    ctx.saveGState()
                    ctx.translateBy(x: p.x, y: p.y + size * 0.05)
                    ctx.rotate(by: .pi / 2)
                    ctx.draw(lying, in: CGRect(x: -size / 2, y: -size / 2, width: size, height: size))
                    ctx.restoreGState()
                    drawTouchMarks(ant, touch, at: p, size: size, pixel: pixel)
                    continue
                }
            }
            if activity == .sleep, ant.touch == nil { // lying on its side, and turning over now and then; nothing else to draw
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
            ctx.setAlpha(CGFloat(ant.fadeAlpha) * touchAlpha(ant)) // the dying fade out
            if let touch = ant.touch, touch.spin != 0 || touch.anim == .proud || touch.anim == .bow {
                // turned in the air, puffed up or bowing: drawn about its middle
                let sx: CGFloat = touch.anim == .proud ? 1.12 : 1, sy: CGFloat = touch.anim == .proud ? 1.12 : touch.anim == .bow ? 0.86 : 1
                ctx.saveGState()
                ctx.translateBy(x: p.x, y: p.y + size * 0.3)
                ctx.rotate(by: CGFloat(touch.spin))
                ctx.scaleBy(x: sx, y: sy)
                ctx.draw(image, in: CGRect(x: -size / 2, y: -size / 2, width: size, height: size))
                ctx.restoreGState()
            } else {
                ctx.draw(image, in: CGRect(x: p.x - size / 2, y: p.y - size * 0.2, width: size, height: size))
            }
            ctx.setAlpha(1)
            if let touch = ant.touch { drawTouchMarks(ant, touch, at: p, size: size, pixel: pixel) }
            if ant.wet > 0 { drawDrips(ant, at: p, size: size) }
            if isMap, let day = Holidays.today { drawHolidayWear(ant, day: day, at: p, size: size, pixel: pixel) }
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
                if ant.swing > 0, !isDigging(activity) { drawSlash(ant, at: p, size: size, progress: swingProgress) } // (digging throws earth instead)
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
        case .meditate?:
            // sitting still; a few leaves and little lights drift slowly around it
            for k in 0..<4 {
                let a = t * 0.8 + Double(k) * .pi / 2
                let q = CGPoint(x: p.x + CGFloat(cos(a)) * size * 0.55, y: p.y + size * 0.4 + CGFloat(sin(a * 1.3)) * size * 0.25)
                if k % 2 == 0 { rect(q.x, q.y, 1.6, 1, NSColor(calibratedRed: 0.45, green: 0.78, blue: 0.35, alpha: 0.9)) }
                else { drawSpeck(at: q, radius: 1.1, color: NSColor(calibratedRed: 1, green: 0.95, blue: 0.6, alpha: 0.5 + 0.4 * CGFloat(sin(t * 3 + Double(k))))) }
            }
        case .dig(let spot)?:
            guard hypot(spot.x - ant.pos.x, spot.y - ant.pos.y) < 6 else { break }
            // a hole at its feet, and earth thrown up with each scoop
            let hole = CGPoint(x: p.x, y: p.y - size * 0.18)
            NSColor(calibratedRed: 0.22, green: 0.16, blue: 0.12, alpha: 0.85).setFill()
            NSBezierPath(ovalIn: NSRect(x: hole.x - 5 * u, y: hole.y - 1.2 * u, width: 10 * u, height: 3 * u)).fill()
            if ant.swing > 0 {
                let k = CGFloat(1 - ant.swing / Ant.swingTime)
                for i in 0..<3 {
                    let dx = CGFloat(i - 1) * 4 * u * k, dy = sin(k * .pi) * 7 * u + CGFloat(i) * u
                    rect(hole.x + dx, hole.y + dy, 1.4, 1.4, NSColor(calibratedRed: 0.42, green: 0.3, blue: 0.2, alpha: 1))
                }
            }
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
        case .haul(let load, _)?:
            // carried on the shoulder: a log (or a bundle of twigs, for elves), a stone, a bone
            let top = CGPoint(x: p.x, y: p.y + size * 0.78)
            switch load {
            case 0 where Characters.current.rules.fellsTrees == false:
                for k in -1...1 { rect(top.x + CGFloat(k) * 1.2 * u, top.y + CGFloat(abs(k)) * 0.4 * u, 7, 0.8, NSColor(calibratedRed: 0.55, green: 0.38, blue: 0.2, alpha: 1)) }
                rect(top.x, top.y - 0.2 * u, 1.2, 1.6, NSColor(calibratedRed: 0.35, green: 0.6, blue: 0.3, alpha: 1)) // the tie
            case 0:
                rect(top.x, top.y, 10, 2.4, NSColor(calibratedRed: 0.5, green: 0.32, blue: 0.17, alpha: 1))
                rect(top.x + 4.4 * u, top.y + 0.3 * u, 1.4, 1.8, NSColor(calibratedRed: 0.86, green: 0.7, blue: 0.45, alpha: 1)) // the cut end
            case 1:
                rect(top.x, top.y, 5, 3.4, NSColor(calibratedRed: 0.55, green: 0.56, blue: 0.6, alpha: 1))
                rect(top.x - 0.6 * u, top.y + 2.2 * u, 2.4, 1, NSColor(calibratedRed: 0.72, green: 0.73, blue: 0.76, alpha: 1))
            case 2:
                let bone = NSColor(calibratedRed: 0.93, green: 0.91, blue: 0.84, alpha: 1)
                rect(top.x, top.y + 0.4 * u, 6, 1, bone)
                rect(top.x - 3 * u, top.y, 1.6, 1.8, bone)
                rect(top.x + 3 * u, top.y, 1.6, 1.8, bone)
            case 4: // a sack of what the ranch gave
                rect(top.x, top.y, 6, 4, NSColor(calibratedRed: 0.8, green: 0.72, blue: 0.55, alpha: 1))
                rect(top.x, top.y + 4 * u, 2, 1, NSColor(calibratedRed: 0.55, green: 0.4, blue: 0.25, alpha: 1))
            default: // a scroll from the scribe's desk
                rect(top.x, top.y, 6, 2, NSColor(calibratedRed: 0.97, green: 0.93, blue: 0.8, alpha: 1))
                rect(top.x - 3.2 * u, top.y - 0.2 * u, 1, 2.4, NSColor(calibratedRed: 0.55, green: 0.35, blue: 0.2, alpha: 1))
                rect(top.x + 3.2 * u, top.y - 0.2 * u, 1, 2.4, NSColor(calibratedRed: 0.55, green: 0.35, blue: 0.2, alpha: 1))
                rect(top.x, top.y + 0.6 * u, 1, 0.8, NSColor(calibratedRed: 0.8, green: 0.2, blue: 0.2, alpha: 1)) // the seal
            }
        case .patrol?:
            // a light held out: a torch (goblins), a lantern (elves), a soul-lamp (the undead); it lights the ground round it
            let race = Characters.current.id
            let side = dirSign(ant)
            let hand = CGPoint(x: p.x + side * size * 0.32, y: p.y + size * 0.42)
            let flicker = CGFloat(sin(Date().timeIntervalSinceReferenceDate * 9 + Double(ant.id))) * 0.06
            let glow = race == "undead" ? NSColor(calibratedRed: 0.4, green: 0.95, blue: 0.85, alpha: 1) : race == "elf" ? NSColor(calibratedRed: 0.85, green: 1, blue: 0.75, alpha: 1) : NSColor(calibratedRed: 1, green: 0.66, blue: 0.25, alpha: 1)
            for (r, a) in [(30.0, 0.07), (18.0, 0.11)] {
                glow.withAlphaComponent(CGFloat(a) + flicker * 0.5).setFill()
                let rr = CGFloat(r) * (1 + flicker)
                NSBezierPath(ovalIn: NSRect(x: hand.x - rr, y: hand.y - rr * 0.8, width: rr * 2, height: rr * 1.6)).fill()
            }
            if race == "goblin" {
                rect(hand.x, hand.y - 3 * u, 1, 4, NSColor(calibratedRed: 0.45, green: 0.3, blue: 0.16, alpha: 1))
                rect(hand.x, hand.y + u, 2, 2 + flicker * 10, NSColor(calibratedRed: 0.98, green: 0.6, blue: 0.15, alpha: 1))
                rect(hand.x, hand.y + 1.6 * u, 1, 1.2, NSColor(calibratedRed: 1, green: 0.92, blue: 0.55, alpha: 1))
            } else {
                rect(hand.x, hand.y + 2 * u, 0.6, 1.4, NSColor(calibratedWhite: 0.3, alpha: 1))
                rect(hand.x, hand.y - 0.4 * u, 2.4, 2.6, NSColor(calibratedWhite: 0.25, alpha: 1))
                rect(hand.x, hand.y, 1.6, 1.8, glow)
            }
        case .fireside(let spot, _)? where hypot(spot.x - ant.pos.x, spot.y - ant.pos.y) < 6:
            // sat by the fire: a goblin holds something over it on a stick, an elf sings now and then
            if Characters.current.id == "elf" {
                if Int(t / 3 + Double(ant.id)) % 3 == 0 {
                    let rise = CGFloat((t / 3).truncatingRemainder(dividingBy: 1))
                    ("♪" as NSString).draw(at: NSPoint(x: p.x + 4, y: p.y + size * 0.8 + rise * 10), withAttributes: [.font: NSFont.systemFont(ofSize: 9), .foregroundColor: NSColor(calibratedWhite: 1, alpha: 1 - rise)])
                }
            } else if ant.id % 2 == 0 {
                let side = dirSign(ant)
                let from = CGPoint(x: p.x + side * size * 0.25, y: p.y + size * 0.35)
                let tip = CGPoint(x: from.x + side * 10, y: from.y + 3)
                let stick = NSBezierPath()
                stick.move(to: from)
                stick.line(to: tip)
                stick.lineWidth = 1
                NSColor(calibratedRed: 0.45, green: 0.3, blue: 0.16, alpha: 1).setStroke()
                stick.stroke()
                NSColor(calibratedRed: 0.62, green: 0.3, blue: 0.2, alpha: 1).setFill()
                NSBezierPath(ovalIn: NSRect(x: tip.x - 2, y: tip.y - 1.5, width: 4, height: 3)).fill()
            }
        case .scribe(let desk, let dozing)?:
            // Claude is waiting for the player's leave: the scribes at their desks hold a sheet up and wave it
            let asking = colony.stage.current.map { $0.kind == .permission && $0.askID?.hasPrefix(AppDelegate.noteAskPrefix) != true } ?? false
            if asking, hypot(desk.x - ant.pos.x, desk.y + 7 - ant.pos.y) < 6 {
                let wave = CGFloat(sin(Date().timeIntervalSinceReferenceDate * 9)) * 2
                let hand = CGPoint(x: p.x + size * 0.3 + wave, y: p.y + size * 0.92)
                rect(hand.x, hand.y, 4, 5, NSColor(calibratedRed: 0.97, green: 0.94, blue: 0.84, alpha: 1))
                rect(hand.x, hand.y + 1.5 * u, 2.4, 0.6, NSColor(calibratedWhite: 0.4, alpha: 1))
                rect(hand.x, hand.y + 3 * u, 2.4, 0.6, NSColor(calibratedWhite: 0.4, alpha: 1))
                rect(p.x + size * 0.24, p.y + size * 0.62, 1, 3.5, NSColor(calibratedRed: 0.5, green: 0.75, blue: 0.4, alpha: 1)) // the arm up
                ("！" as NSString).draw(at: NSPoint(x: hand.x + 4, y: hand.y + 2), withAttributes: [.font: NSFont.boldSystemFont(ofSize: 10), .foregroundColor: NSColor(calibratedRed: 1, green: 0.75, blue: 0.2, alpha: 1)])
            } else if dozing, Int(Date().timeIntervalSinceReferenceDate) % 3 != 0 {
                ("z" as NSString).draw(at: NSPoint(x: p.x + size * 0.3, y: p.y + size * 0.8), withAttributes: [.font: NSFont.boldSystemFont(ofSize: 9), .foregroundColor: NSColor.white])
            }
        case .carryBeast(let kind, _, _)?:
            // what it caught, held up over its head (kicking)
            if let animal = Animals.all.first(where: { $0.id == kind }), let image = animal.image(facingRight: dirSign(ant) > 0, phase: t * 6),
               let ctx = NSGraphicsContext.current?.cgContext {
                let w = CGFloat(image.width) * 1.2, h = CGFloat(image.height) * 1.2
                ctx.saveGState()
                ctx.interpolationQuality = .none
                if kind == "soul_beast" { ctx.setAlpha(0.7) }
                ctx.draw(image, in: CGRect(x: p.x - w / 2, y: p.y + size * 0.72, width: w, height: h))
                ctx.restoreGState()
            }
        case .herd?:
            ("！" as NSString).draw(at: NSPoint(x: p.x + size * 0.25, y: p.y + size * 0.8), withAttributes: [.font: NSFont.boldSystemFont(ofSize: 9), .foregroundColor: NSColor.white])
        case .tend(let spot, let face)? where hypot(spot.x - ant.pos.x, spot.y - ant.pos.y) < 6:
            // feed thrown over the fence: a few grains in the air toward the pen
            let to = local(face)
            for k in 0..<4 {
                let f = CGFloat((t * 0.8 + Double(k) * 0.25).truncatingRemainder(dividingBy: 1))
                let x = p.x + (to.x - p.x) * f, y = p.y + size * 0.5 + (to.y - p.y - size * 0.3) * f + sin(f * .pi) * 8
                rect(x, y, 1, 1, NSColor(calibratedRed: 0.95, green: 0.85, blue: 0.45, alpha: 1 - f * 0.5))
            }
        case .chat(let partner)?:
            // the two take turns: a bubble over whoever is talking now
            let turn = Int(t / 2.2) % 2 == (ant.id < partner ? 0 : 1)
            if turn { drawBubble(at: CGPoint(x: p.x + 3, y: p.y + size * 0.82), size: max(1.6, u * 0.9), dots: 1 + Int(t * 2) % 3, heart: Holidays.today == Holidays.qixi) } // (七夕: sweet nothings)
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
        // an archer race shoots even with no bow
        let look = weapon?.look ?? ((Characters.current.rules.ranged ?? 0) > 0 ? .bow : nil)
        let reachAdd = CGFloat(ant.gearReach + (Characters.current.rules.ranged ?? 0))
        switch look {
        case .bow?:
            guard progress > 0.3 else { return } // drawing the string first
            let t = (progress - 0.3) / 0.7, d = max(20, reachAdd + 30) * t
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

    /// A food on the ground: the fruit tree, a monster's leavings, the stew pot, or one of the pixel pictures of what the player put down
    /// (it changes to the "little left" picture once most of it has been carried off).
    private func drawFood(_ food: FoodSource, at p: CGPoint, scale: CGFloat) {
        switch food.kind {
        case .fruit: drawTree(food, at: p)
        case .loot: drawLoot(food, at: p)
        case .stew: drawStew(food, at: p)
        default: drawFoodSprite(food, at: p, scale: scale)
        }
    }

    private func drawFoodSprite(_ food: FoodSource, at p: CGPoint, scale: CGFloat) {
        let low = Double(food.amount) < Double(food.capacity) * 0.4
        guard let image = FoodSprites.image(food.kind, low: low), let ctx = NSGraphicsContext.current?.cgContext else { return }
        let u = max(1, (2 * scale).rounded()) // one art pixel, in points (whole points keep the pixels crisp)
        let w = CGFloat(image.width) * u, h = CGFloat(image.height) * u
        let rect = CGRect(x: (p.x - w / 2).rounded(), y: (p.y - h * 0.35).rounded(), width: w, height: h)
        NSColor(calibratedWhite: 0, alpha: 0.18).setFill() // a soft shadow under it
        NSBezierPath(ovalIn: NSRect(x: rect.minX + u, y: rect.minY - u * 1.5, width: w - 2 * u, height: u * 3)).fill()
        ctx.saveGState()
        ctx.interpolationQuality = .none
        ctx.draw(image, in: rect)
        ctx.restoreGState()
        drawFoodLife(food, in: rect, pixel: u, low: low)
    }

    /// The little things that move: a glint on the water, a drop of honey falling, the candle, a wisp of steam off what is still warm.
    private func drawFoodLife(_ food: FoodSource, in rect: CGRect, pixel u: CGFloat, low: Bool) {
        let t = Date().timeIntervalSinceReferenceDate + Double(food.id) * 0.7
        func px(_ x: CGFloat, _ yFromTop: CGFloat, _ color: NSColor) { // in art pixels from the picture's top left
            color.setFill()
            NSRect(x: rect.minX + x * u, y: rect.maxY - (yFromTop + 1) * u, width: u, height: u).fill()
        }
        switch food.kind {
        case .water where !low:
            if Int(t * 1.5) % 3 == 0 { px(CGFloat(4 + Int(t * 1.5) % 5), 1, .white) }
        case .honey where !low:
            let phase = CGFloat((t * 0.5).truncatingRemainder(dividingBy: 1))
            let drop = NSColor(calibratedRed: 1, green: 0.72, blue: 0.1, alpha: 1 - phase * 0.6)
            px(3, 6 + phase * 6, drop)
        case .cake:
            if !low { px(7, 0, Int(t * 6) % 2 == 0 ? NSColor(calibratedRed: 1, green: 0.95, blue: 0.6, alpha: 1) : NSColor(calibratedRed: 1, green: 0.62, blue: 0.2, alpha: 1)) }
        case .meat, .fish, .bread:
            for k in 0..<2 {
                let phase = (t * 0.5 + Double(k) * 0.5).truncatingRemainder(dividingBy: 1)
                NSColor(calibratedWhite: 1, alpha: 0.35 * CGFloat(1 - phase)).setFill()
                let x = rect.midX - u * 2 + CGFloat(k) * u * 4 + CGFloat(sin(t * 2 + Double(k))) * u
                NSBezierPath(ovalIn: NSRect(x: x, y: rect.maxY - u * 2 + CGFloat(phase) * u * 7, width: u * 2, height: u * 1.5)).fill()
            }
        default:
            break
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

// MARK: - The hand's marks (Touch.swift)

extension AntView {
    /// See-through while the pointer goes through it (a shade), or while a shade follows the pointer.
    fileprivate func touchAlpha(_ ant: Ant) -> CGFloat {
        guard let touch = ant.touch else { return 1 }
        if touch.anim == .fade { return 0.35 }
        if touch.anim == .chase, Characters.current.id == "undead" { return 0.55 + 0.2 * CGFloat(sin(touch.clock * 6)) }
        return 1
    }

    private func px(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ color: NSColor) {
        color.setFill()
        NSRect(x: x, y: y, width: w, height: h).fill()
    }

    /// What goes with a reaction: hearts, pink cheeks, stars, a flower on the head, red eyes, a flame, little lights, a book, roots, tears, a sign.
    fileprivate func drawTouchMarks(_ ant: Ant, _ touch: Touch, at p: CGPoint, size: CGFloat, pixel u: CGFloat) {
        let t = touch.clock
        let head = CGPoint(x: p.x, y: p.y + size * 0.62)
        switch touch.anim {
        case .hearts:
            for k in 0..<2 {
                let rise = CGFloat((t * 0.9 + Double(k) * 0.5).truncatingRemainder(dividingBy: 1))
                drawHeart(at: CGPoint(x: p.x + (k == 0 ? -5 : 6), y: head.y + 6 + rise * 14), size: max(1, u * 0.8), alpha: 1 - rise)
            }
        case .blush:
            let pink = NSColor(calibratedRed: 1, green: 0.45, blue: 0.55, alpha: 0.75)
            px(head.x - size * 0.2, head.y - u * 1.5, u * 1.6, u, pink)
            px(head.x + size * 0.2 - u * 1.6, head.y - u * 1.5, u * 1.6, u, pink)
        case .dizzy:
            for k in 0..<3 {
                let a = t * 5 + Double(k) * 2.1
                px(p.x + CGFloat(cos(a)) * size * 0.3 - u / 2, p.y + size * 0.3 + CGFloat(sin(a)) * size * 0.1, u * 1.2, u * 1.2, NSColor(calibratedRed: 1, green: 0.9, blue: 0.3, alpha: 1))
            }
        case .flower:
            drawFlower(at: CGPoint(x: head.x + u, y: head.y + size * 0.22), alpha: min(1, t * 3), scale: u / 2)
        case .leaf:
            let green = NSColor(calibratedRed: 0.35, green: 0.75, blue: 0.3, alpha: 1)
            px(head.x, head.y + size * 0.2, u, u * 2, NSColor(calibratedRed: 0.4, green: 0.3, blue: 0.2, alpha: 1))
            px(head.x + u, head.y + size * 0.2 + u * 1.5, u * 2.5, u * 1.5, green)
        case .glowEyes:
            let red = NSColor(calibratedRed: 1, green: 0.15, blue: 0.1, alpha: 0.6 + 0.4 * CGFloat(sin(t * 8)))
            NSColor(calibratedRed: 1, green: 0.1, blue: 0.1, alpha: 0.18).setFill()
            NSBezierPath(ovalIn: NSRect(x: head.x - size * 0.25, y: head.y - size * 0.12, width: size * 0.5, height: size * 0.24)).fill()
            px(head.x - u * 2.5, head.y - u * 0.5, u * 1.2, u, red)
            px(head.x + u * 1.3, head.y - u * 0.5, u * 1.2, u, red)
        case .flare:
            let r = size * (0.45 + 0.08 * CGFloat(sin(t * 10)))
            NSColor(calibratedRed: 0.35, green: 0.6, blue: 1, alpha: 0.28).setFill()
            NSBezierPath(ovalIn: NSRect(x: p.x - r, y: p.y + size * 0.3 - r, width: r * 2, height: r * 2)).fill()
        case .sparkle:
            for k in 0..<5 {
                let a = t * 2 + Double(k) * 1.26, r = size * (0.35 + 0.1 * CGFloat(sin(t * 3 + Double(k))))
                px(p.x + CGFloat(cos(a)) * r, p.y + size * 0.35 + CGFloat(sin(a)) * r, u, u, NSColor(calibratedRed: 1, green: 0.95, blue: 0.6, alpha: 0.9))
            }
        case .cover: // a book (or a hood's edge) held in front of the face
            let brown = Characters.current.id == "elf" ? NSColor(calibratedRed: 0.25, green: 0.5, blue: 0.3, alpha: 1) : NSColor(calibratedRed: 0.55, green: 0.3, blue: 0.2, alpha: 1)
            px(head.x - u * 3, head.y - u * 2, u * 6, u * 4, brown)
            px(head.x - u * 0.3, head.y - u * 2, u * 0.6, u * 4, NSColor(calibratedWhite: 0.95, alpha: 1))
        case .rooted:
            let root = NSColor(calibratedRed: 0.45, green: 0.32, blue: 0.2, alpha: 1)
            for k in -2...2 {
                px(p.x + CGFloat(k) * u * 2, p.y - size * 0.2 - u * CGFloat(abs(k) + 1), u, u * CGFloat(abs(k) + 2), root)
            }
        case .cry:
            for k in 0..<2 {
                let fall = CGFloat((t * 2 + Double(k) * 0.5).truncatingRemainder(dividingBy: 1))
                px(head.x + (k == 0 ? -size * 0.18 : size * 0.15), head.y - fall * size * 0.3, u, u * 1.5, NSColor(calibratedRed: 0.5, green: 0.75, blue: 1, alpha: 1 - fall))
            }
        case .think where t < 1.2:
            drawPill("?", center: NSPoint(x: p.x + size * 0.35, y: head.y + size * 0.3), fontSize: 10)
        default: break
        }
        if let emote = touch.emote, t < 2.2 {
            let text = emote as NSString
            text.draw(at: NSPoint(x: p.x + size * 0.3, y: head.y + size * 0.15), withAttributes: [.font: NSFont.systemFont(ofSize: 11)])
        }
    }

    /// A skeleton in pieces: bones scattered on the ground that crawl back together toward the end.
    fileprivate func drawCollapse(_ touch: Touch, at p: CGPoint, size: CGFloat, pixel u: CGFloat) {
        let whole = touch.clock + touch.left
        let apart = touch.clock < 0.25 ? touch.clock / 0.25 : max(0, min(1, touch.left / max(0.1, whole * 0.4)))
        let bone = NSColor(calibratedRed: 0.93, green: 0.91, blue: 0.84, alpha: 1)
        for k in 0..<6 {
            let a = Double(k) * 1.05 + 0.4
            let r = size * 0.42 * CGFloat(apart)
            let x = p.x + CGFloat(cos(a)) * r, y = p.y + CGFloat(sin(a)) * r * 0.5
            if k == 0 { // the skull
                px(x - u * 2, y, u * 4, u * 3, bone)
                px(x - u * 1.2, y + u, u, u, .black)
                px(x + u * 0.2, y + u, u, u, .black)
            } else {
                px(x - u * 2, y, u * 4, u, bone)
                px(x - u * 2.5, y - u * 0.4, u, u * 1.8, bone)
                px(x + u * 1.5, y - u * 0.4, u, u * 1.8, bone)
            }
        }
    }

    /// What the touched ones say: pills over their heads, moved up out of each other's way when the camp is crowded.
    fileprivate func drawSaid(_ said: [(text: String, at: CGPoint)]) {
        let font = NSFont.systemFont(ofSize: 10, weight: .medium)
        var placed: [CGRect] = []
        for note in said {
            let size = (note.text as NSString).size(withAttributes: [.font: font])
            var box = CGRect(x: note.at.x - size.width / 2 - 9, y: note.at.y - size.height / 2 - 4.5, width: size.width + 18, height: size.height + 9)
            for _ in 0..<4 where placed.contains(where: { $0.intersects(box) }) { box.origin.y += box.height + 2 }
            placed.append(box)
            drawPill(note.text, center: NSPoint(x: box.midX, y: box.midY), fontSize: 10)
        }
    }

    /// Wet from the pond: drops falling off it.
    fileprivate func drawDrips(_ ant: Ant, at p: CGPoint, size: CGFloat) {
        let t = Date().timeIntervalSinceReferenceDate
        for k in 0..<3 {
            let fall = CGFloat((t * 1.5 + Double(k) * 0.33 + Double(ant.id) * 0.1).truncatingRemainder(dividingBy: 1))
            px(p.x + CGFloat(k - 1) * size * 0.2, p.y + size * 0.4 - fall * size * 0.5, 1.5, 2.5, NSColor(calibratedRed: 0.55, green: 0.8, blue: 1, alpha: 0.9 * (1 - fall)))
        }
    }

    /// The shows at the pointer and on the ground: a fist, an arrow, little lights, a bony hand, a coin, a splash, grass, flowers, a healing ring.
    fileprivate func drawHandEffects() {
        for e in colony.hand.effects {
            let p = CGPoint(x: e.pos.x - (originOverride ?? .zero).x, y: e.pos.y - (originOverride ?? .zero).y)
            let k = CGFloat(e.age / e.life), fade = 1 - k
            switch e.kind {
            case .fist:
                let s = 16 + 10 * CGFloat(sin(min(1, e.age / 0.2) * .pi / 2))
                ("👊" as NSString).draw(at: NSPoint(x: p.x - s / 2, y: p.y - s / 2), withAttributes: [.font: NSFont.systemFont(ofSize: s)])
            case .arrow(let from):
                let start = CGPoint(x: from.x - (originOverride ?? .zero).x, y: from.y - (originOverride ?? .zero).y)
                let flight = min(1, CGFloat(e.age / 0.15))
                let tip = CGPoint(x: start.x + (p.x - start.x) * flight, y: start.y + (p.y - start.y) * flight)
                let a = atan2(p.y - start.y, p.x - start.x)
                let tail = CGPoint(x: tip.x - cos(a) * 12, y: tip.y - sin(a) * 12)
                let shaft = NSBezierPath()
                shaft.move(to: tail)
                shaft.line(to: tip)
                shaft.lineWidth = 1.5
                NSColor(calibratedRed: 0.55, green: 0.38, blue: 0.2, alpha: fade + 0.2).setStroke()
                shaft.stroke()
                px(tail.x - 2, tail.y - 1, 3, 3, NSColor(calibratedWhite: 0.95, alpha: fade + 0.2)) // the feathers
                if flight >= 1 { px(tip.x - 1, tip.y - 1, 2, 2, NSColor(calibratedWhite: 0.3, alpha: 1)) }
            case .sparkles:
                for j in 0..<6 {
                    let a = e.age * 3 + Double(j) * 1.05, r = 10 + 4 * sin(e.age * 5 + Double(j))
                    px(p.x + CGFloat(cos(a) * r), p.y + CGFloat(sin(a) * r), 2, 2, NSColor(calibratedRed: 1, green: 0.95, blue: 0.6, alpha: fade))
                }
            case .boneHand:
                let bone = NSColor(calibratedRed: 0.93, green: 0.91, blue: 0.84, alpha: 1)
                px(p.x - 5, p.y - 12, 10, 6, bone) // the palm, fingers closed over the pointer
                for j in 0..<4 { px(p.x - 5 + CGFloat(j) * 2.6, p.y - 6, 2, 7, bone) }
                px(p.x - 8, p.y - 10, 3, 5, bone) // the thumb
            case .coin:
                let hop = CGFloat(abs(sin(e.age * 6))) * 8 * fade
                NSColor(calibratedRed: 1, green: 0.82, blue: 0.2, alpha: 1).setFill()
                NSBezierPath(ovalIn: NSRect(x: p.x - 3, y: p.y + hop, width: 6, height: 6)).fill()
                px(p.x - 0.5, p.y + hop + 1.5, 1, 3, NSColor(calibratedRed: 0.8, green: 0.6, blue: 0.1, alpha: 1))
            case .splash:
                for j in 0..<8 {
                    let a = Double(j) * .pi / 4, r = 4 + 16 * k
                    px(p.x + CGFloat(cos(a)) * r, p.y + CGFloat(sin(a)) * r * 0.6 + 10 * sin(k * .pi), 2, 2, NSColor(calibratedRed: 0.6, green: 0.85, blue: 1, alpha: fade))
                }
            case .grass:
                for j in 0..<7 {
                    let a = Double(j) * 0.9, r: CGFloat = 12
                    let x = p.x + CGFloat(cos(a)) * r, y = p.y + CGFloat(sin(a)) * r * 0.5
                    let h = 4 * min(1, CGFloat(e.age * 3))
                    px(x, y, 1.5, h, NSColor(calibratedRed: 0.35, green: 0.7, blue: 0.3, alpha: min(1, fade * 3)))
                    px(x + 2, y, 1.5, h * 0.7, NSColor(calibratedRed: 0.45, green: 0.8, blue: 0.35, alpha: min(1, fade * 3)))
                }
            case .bloom:
                for j in 0..<5 {
                    let a = Double(j) * 1.26
                    drawFlower(at: CGPoint(x: p.x + CGFloat(cos(a)) * 14, y: p.y + CGFloat(sin(a)) * 7), alpha: Double(min(1, fade * 3)), scale: 0.8)
                }
            case .heal:
                let r = 10 + 50 * k
                let ring = NSBezierPath(ovalIn: NSRect(x: p.x - r, y: p.y - r * 0.5, width: r * 2, height: r))
                ring.lineWidth = 2
                NSColor(calibratedRed: 0.5, green: 1, blue: 0.6, alpha: fade * 0.8).setStroke()
                ring.stroke()
            }
        }
    }
}

// MARK: - Holidays (Holidays.swift)

extension AntView {
    fileprivate static let holidayIcons: [String: String] = [
        "new_years_eve": "🎆", "new_year": "🎉", "lunar_eve": "🧧", "spring_festival": "🧧", "lantern": "🏮", "children": "🎈",
        "qingming": "🌿", "children_qingming": "🎈", "labor": "🛠", "dragon_boat": "🐉", "qixi": "💕", "ghost": "🏮", "mid_autumn": "🌕",
        "teachers": "📚", "double_ninth": "⛰", "national": "🎆", "dongzhi": "🥣", "weiya": "🍻", "christmas": "🎄",
    ]

    /// The day's name in the corner of the camp window, and the fireworks over the camp on a fireworks night.
    fileprivate func drawHoliday() {
        for shell in colony.fireworks.shells { drawShell(shell) }
        guard let day = Holidays.today else { return }
        drawHolidayScene(day)
        let text = day.quiet ? "\(day.name)・放假" : "\(AntView.holidayIcons[day.id] ?? "🎉") \(day.name)"
        let font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        let width = (text as NSString).size(withAttributes: [.font: font]).width
        drawPill(text, center: NSPoint(x: bounds.minX + 22 + width / 2, y: bounds.maxY - 16), fontSize: 11,
                 tint: day.quiet ? nil : NSColor(calibratedRed: 0.85, green: 0.3, blue: 0.25, alpha: 1))
    }

    /// One firework: a trail going up, then a ring of sparks that spreads, droops and fades.
    private func drawShell(_ shell: Fireworks.Shell) {
        let from = local(shell.from), to = local(shell.to)
        if shell.age < shell.rise {
            let k = CGFloat(shell.age / shell.rise)
            let head = CGPoint(x: from.x + (to.x - from.x) * k, y: from.y + (to.y - from.y) * (1 - (1 - k) * (1 - k)))
            NSColor(calibratedRed: 1, green: 0.9, blue: 0.7, alpha: 0.9).setFill()
            NSRect(x: head.x - 1, y: head.y - 1, width: 2, height: 3).fill()
            NSColor(calibratedRed: 1, green: 0.8, blue: 0.5, alpha: 0.35).setFill()
            NSRect(x: head.x - 0.5, y: head.y - 10, width: 1, height: 9).fill()
            return
        }
        let k = CGFloat((shell.age - shell.rise) / Fireworks.burstTime)
        let r = CGFloat(shell.size) * (1 - (1 - min(1, k * 1.6)) * (1 - min(1, k * 1.6)))
        let fade = max(0, 1 - k)
        if k < 0.15 { // the flash
            shell.color.withAlphaComponent(0.25 * (1 - k / 0.15)).setFill()
            NSBezierPath(ovalIn: NSRect(x: to.x - r * 1.2, y: to.y - r * 1.2, width: r * 2.4, height: r * 2.4)).fill()
        }
        for j in 0..<shell.sparks {
            let a = Double(j) / Double(shell.sparks) * 2 * .pi
            let x = to.x + CGFloat(cos(a)) * r, y = to.y + CGFloat(sin(a)) * r - k * k * 14 // they droop as they fade
            shell.color.withAlphaComponent(fade).setFill()
            NSRect(x: x - 1.5, y: y - 1.5, width: 3, height: 3).fill()
            if k < 0.6 { // a tail toward the middle
                shell.color.withAlphaComponent(fade * 0.45).setFill()
                NSRect(x: x - CGFloat(cos(a)) * 5 - 1, y: y - CGFloat(sin(a)) * 5 - 1, width: 2, height: 2).fill()
                NSRect(x: x - CGFloat(cos(a)) * 10 - 0.5, y: y - CGFloat(sin(a)) * 10 - 0.5, width: 1, height: 1).fill()
            }
            if j % 2 == 0, k < 0.8 { // an inner ring, half as far
                NSColor.white.withAlphaComponent(fade * 0.7).setFill()
                NSRect(x: to.x + CGFloat(cos(a + 0.2)) * r * 0.5 - 1, y: to.y + CGFloat(sin(a + 0.2)) * r * 0.5 - k * k * 8 - 1, width: 2, height: 2).fill()
            }
        }
    }

    /// A Christmas tree beside the camp: a pixel fir with baubles that twinkle, a star on top, and presents under it.
    fileprivate func drawChristmasTree(at p: CGPoint) {
        guard bounds.insetBy(dx: -40, dy: -40).contains(p) else { return }
        let u: CGFloat = 2
        func px(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ c: NSColor) { c.setFill(); NSRect(x: p.x + x * u, y: p.y + y * u, width: w * u, height: h * u).fill() }
        let dark = NSColor(calibratedRed: 0.1, green: 0.38, blue: 0.2, alpha: 1), light = NSColor(calibratedRed: 0.18, green: 0.52, blue: 0.27, alpha: 1)
        px(-1, 0, 2, 3, NSColor(calibratedRed: 0.42, green: 0.27, blue: 0.14, alpha: 1)) // the trunk
        for (row, half) in [(3, 7), (5, 6), (7, 5), (9, 5), (11, 4), (13, 3), (15, 2), (17, 1)] as [(CGFloat, CGFloat)] {
            px(-half, row, half * 2, 2, row.truncatingRemainder(dividingBy: 4) == 3 ? dark : light)
        }
        let t = Date().timeIntervalSinceReferenceDate
        let baubles: [(CGFloat, CGFloat)] = [(-5, 4), (3, 5), (-2, 7), (4, 9), (-4, 10), (1, 12), (-1, 15), (2, 3)]
        for (k, b) in baubles.enumerated() {
            let on = Int(t * 2 + Double(k)) % 3 != 0
            let color = [NSColor.systemRed, NSColor.systemYellow, NSColor(calibratedRed: 0.4, green: 0.7, blue: 1, alpha: 1)][k % 3]
            px(b.0, b.1, 1, 1, on ? color : color.blended(withFraction: 0.5, of: .black) ?? color)
        }
        px(-1, 19, 2, 1, .systemYellow); px(-0.5, 18.5, 1, 2, .systemYellow) // the star
        px(-9, -1, 4, 3, NSColor(calibratedRed: 0.85, green: 0.2, blue: 0.25, alpha: 1)); px(-7.5, -1, 1, 3, .systemYellow)
        px(5, -1, 3, 2, NSColor(calibratedRed: 0.25, green: 0.5, blue: 0.9, alpha: 1)); px(6, -1, 1, 2, .white)
    }
}

// MARK: - The scribe's desks (Scribe.swift)

extension AntView {
    /// A desk for each of Claude Code's sessions at work: a goblin's has papers and an ink pot, an elf's an open book and a quill,
    /// the undead's a typewriter; the project's name on a little card in front.
    fileprivate func drawDesks() {
        let u: CGFloat = 1.5
        let race = Characters.current.id
        for session in colony.claudeDesk.sessions.values where session.desk != .zero {
            let p = local(session.desk)
            guard bounds.insetBy(dx: -30, dy: -30).contains(p) else { continue }
            func px(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ c: NSColor) { c.setFill(); NSRect(x: p.x + x * u, y: p.y + y * u, width: w * u, height: h * u).fill() }
            let wood = NSColor(calibratedRed: 0.55, green: 0.36, blue: 0.2, alpha: 1), top = NSColor(calibratedRed: 0.68, green: 0.47, blue: 0.27, alpha: 1)
            px(-7, -1, 1, 4, wood); px(6, -1, 1, 4, wood) // legs
            px(-8, 3, 16, 2, top); px(-8, 3, 16, 0.6, wood)
            switch race {
            case "elf":
                px(-4, 5, 4, 1.2, NSColor(calibratedWhite: 0.97, alpha: 1)); px(0, 5, 4, 1.2, NSColor(calibratedWhite: 0.92, alpha: 1)) // the open book
                px(4.5, 5, 0.6, 4, NSColor(calibratedWhite: 0.95, alpha: 1)); px(5, 8, 1, 1.4, NSColor(calibratedRed: 0.4, green: 0.7, blue: 0.5, alpha: 1)) // the quill
            case "undead":
                px(-4, 5, 8, 2.5, NSColor(calibratedWhite: 0.22, alpha: 1)); px(-3, 7.5, 6, 2, NSColor(calibratedWhite: 0.95, alpha: 1)) // typewriter and its sheet
                for k in 0..<4 { px(-3 + CGFloat(k) * 1.8, 5.6, 1, 0.8, NSColor(calibratedWhite: 0.7, alpha: 1)) }
            default:
                px(-5, 5, 6, 1, NSColor(calibratedRed: 0.96, green: 0.92, blue: 0.8, alpha: 1)); px(-4.5, 6, 5, 0.8, NSColor(calibratedRed: 0.9, green: 0.85, blue: 0.72, alpha: 1)) // papers
                px(3, 5, 2, 2, NSColor(calibratedWhite: 0.15, alpha: 1)); px(3.6, 7, 0.6, 2.5, NSColor(calibratedRed: 0.9, green: 0.9, blue: 0.85, alpha: 1)) // ink and pen
            }
            if !session.project.isEmpty {
                drawPill(session.project, center: NSPoint(x: p.x, y: p.y - 9), fontSize: 8)
            }
        }
    }
}

// MARK: - The wandering merchant (Merchant.swift)

extension AntView {
    /// The merchant, drawn in pixels: a kobold peddler leading a donkey with packs (goblins), a big squirrel in a hat with three
    /// little ones (elves), a hooded ferryman with a lantern and an oar (the undead). At its stall a sign and a cloth with wares.
    fileprivate func drawMerchant() {
        let desk = colony.merchant
        let p = local(desk.pos)
        guard bounds.insetBy(dx: -60, dy: -60).contains(p) else { return }
        let u: CGFloat = 2
        let flip: CGFloat = desk.facingRight ? 1 : -1
        let step = desk.phase == .here ? 0 : CGFloat(Int(desk.legPhase) % 2)
        func px(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ c: NSColor) {
            c.setFill()
            let left = flip > 0 ? x : -x - w
            NSRect(x: p.x + left * u, y: p.y + y * u, width: w * u, height: h * u).fill()
        }
        func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> NSColor { NSColor(calibratedRed: r / 255, green: g / 255, blue: b / 255, alpha: 1) }
        if desk.phase == .here { // the stall: a cloth on the ground with wares, and a little sign
            px(-16, -3, 12, 2, rgb(180, 60, 60)); px(-15, -1, 2, 2, rgb(240, 200, 60)); px(-11, -1, 2, 1, rgb(110, 200, 230)); px(-8, -1, 2, 2, rgb(200, 200, 210))
            px(10, 0, 1, 9, rgb(120, 80, 45)); px(7, 8, 8, 4, rgb(225, 200, 150)); px(8, 9, 6, 1, rgb(120, 80, 45)); px(8, 10.5, 4, 0.8, rgb(120, 80, 45))
        }
        NSColor.black.withAlphaComponent(0.2).setFill()
        NSBezierPath(ovalIn: NSRect(x: p.x - 14 * u, y: p.y - 2 * u, width: 28 * u, height: 4 * u)).fill()
        switch Characters.current.id {
        case "elf": // a squirrel caravan (drawn facing left, so mirrored: it looks the way it walks)
            func pm(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ c: NSColor) { px(-x - w, y, w, h, c) }
            let fur = rgb(196, 112, 52), light = rgb(240, 200, 150), dark = rgb(120, 62, 28)
            pm(1, 2, 4, 7, fur); pm(3, 6, 5, 9, fur); pm(4, 14, 6, 6, fur); pm(2, 19, 6, 3, fur); pm(5, 9, 1.5, 9, dark) // the big tail curling up behind
            pm(1, 20, 3, 2, light) // its tip
            pm(-6, 0 + step, 2, 3, dark); pm(-1, 0, 2, 3, dark)
            pm(-7, 2, 8, 9, fur); pm(-6, 3, 5, 6, light) // body and belly
            pm(-8, 11, 8, 6, fur); pm(-7, 16, 2, 2, fur); pm(-3, 16, 2, 2, fur) // head and ears
            pm(-7, 13, 1, 1, .black); pm(-8.5, 12, 1.5, 1, dark) // eye, nose
            pm(-9, 17, 10, 1.4, rgb(70, 110, 60)); pm(-7, 18.4, 6, 2.5, rgb(70, 110, 60)); pm(-6.5, 18.5, 5, 0.8, rgb(230, 190, 70)) // the hat
            pm(1, 5, 4, 4, rgb(150, 110, 70)); pm(1.5, 8, 3, 1, rgb(120, 80, 45)) // a sack of nuts
            for k in 0..<3 { // the little ones behind
                let x = -20 - CGFloat(k) * 7, b = CGFloat((Int(desk.legPhase) + k) % 2)
                px(x, 0 + b, 4, 4, fur); px(x + 3, 3 + b, 3, 3, fur); px(x - 2, 3 + b, 2, 4, fur); px(x + 4.7, 4.5 + b, 0.8, 0.8, .black) // (head forward, tail behind)
            }
        case "undead": // the ferryman
            let cloak = rgb(40, 38, 58), edge = rgb(70, 66, 96)
            px(-6, 0, 12, 20, cloak); px(-5, 0, 1, 18, edge); px(-4, 20, 8, 4, cloak); px(-3, 18, 6, 4, rgb(18, 16, 26)) // the hood's dark
            px(-2, 19.5, 1, 1, rgb(140, 255, 220)); px(1, 19.5, 1, 1, rgb(140, 255, 220)) // eyes in the dark
            px(8, -2, 1, 26, rgb(110, 80, 50)); px(7, -3, 3, 4, rgb(110, 80, 50)) // the oar
            let glow = rgb(120, 255, 220)
            glow.withAlphaComponent(0.18).setFill()
            NSBezierPath(ovalIn: NSRect(x: p.x + flip * (-14) * u - 8 * u, y: p.y + 2 * u, width: 16 * u, height: 16 * u)).fill()
            px(-15, 13, 1, 3, rgb(60, 60, 60)); px(-16, 8, 3, 5, rgb(40, 40, 40)); px(-15.5, 9, 2, 3, glow) // the lantern
            px(-8, 10, 2, 3, cloak)
        default: // a kobold peddler and its donkey
            let hide = rgb(170, 110, 60), snout = rgb(210, 160, 110), pack = rgb(150, 100, 60)
            // the donkey behind
            let grey = rgb(150, 145, 150)
            px(-26, 2, 14, 7, grey); px(-28, 7, 4, 8, grey); px(-30, 13, 4, 3, grey); px(-27, 15, 1, 3, grey); px(-25, 15, 1, 3, grey) // body, neck, head, ears
            px(-25, 0 + step, 2, 3, rgb(90, 85, 90)); px(-15, 0, 2, 3, rgb(90, 85, 90)); px(-20, 0 + (1 - step), 2, 3, rgb(90, 85, 90))
            px(-24, 9, 10, 5, pack); px(-22, 14, 6, 3, rgb(120, 80, 45)); px(-21, 17, 2, 2, rgb(240, 200, 60)); px(-17, 16, 2, 3, rgb(110, 200, 230)) // packs and shiny things
            px(-29, 14.5, 0.8, 0.8, .black)
            // the kobold
            px(-3, 0 + step, 2, 3, rgb(110, 70, 40)); px(1, 0, 2, 3, rgb(110, 70, 40))
            px(-4, 3, 8, 8, hide); px(-3, 4, 6, 2, rgb(120, 60, 50)) // body and belt
            px(-4, 11, 7, 6, hide); px(2, 12, 4, 3, snout); px(5, 13.5, 1, 1, .black); px(1, 14, 1, 1, .black) // head, snout, nose, eye
            px(-4, 17, 2, 3, hide); px(0, 17, 2, 2, hide) // ears
            px(-8, 5, 4, 9, pack); px(-8, 14, 4, 2, rgb(200, 60, 60)) // the backpack, a red bedroll on top
            px(4, 7, 3, 1.2, hide) // an arm, waving the goods
        }
    }
}

// MARK: - Decorations (Decor.swift)

extension AntView {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard isMap, subviews.first(where: { $0.identifier?.rawValue == "decor-button" }) == nil else { return }
        let button = NSButton(title: "🏡 裝飾", target: self, action: #selector(decorButton(_:)))
        button.identifier = NSUserInterfaceItemIdentifier("decor-button")
        button.bezelStyle = .rounded
        button.controlSize = .small
        button.font = .systemFont(ofSize: 11)
        button.sizeToFit()
        button.frame.origin = NSPoint(x: bounds.maxX - button.frame.width - 10, y: bounds.maxY - button.frame.height - 8)
        button.autoresizingMask = [.minXMargin, .minYMargin]
        button.toolTip = "自己擺營地的裝飾"
        addSubview(button)
    }

    @objc private func decorButton(_ sender: NSButton) {
        guard colony.phase == .running else { return }
        DecorPalette.shared.toggle(colony: colony, near: window)
        window?.makeFirstResponder(self)
        needsDisplay = true
    }

    override func keyDown(with event: NSEvent) {
        guard isMap, colony.decorating else { return super.keyDown(with: event) }
        switch event.keyCode {
        case 53: // Esc: stop putting down, then leave the mode
            if colony.decorPlacing != nil { colony.decorPlacing = nil; DecorPalette.shared.refresh("") }
            else if colony.decorSelected != nil { colony.decorSelected = nil }
            else { DecorPalette.shared.close() }
        case 51, 117: // Delete
            if let i = colony.decorSelected { colony.removeDecor(i); DecorPalette.shared.refresh("收回了。") }
        case 3: // F
            if let i = colony.decorSelected { colony.flipDecor(i) }
        default: super.keyDown(with: event)
        }
        needsDisplay = true
    }

    fileprivate func decorDown(at p: CGPoint, shift: Bool) {
        window?.makeFirstResponder(self)
        if let kind = colony.decorPlacing, DecorCatalog.isFence(kind) { // a fence: this piece, and more as the pointer is dragged
            colony.decorLaying = true
            if let problem = colony.placeDecor(kind, at: p) { DecorPalette.shared.refresh(problem) } else { DecorPalette.shared.refresh("") }
        } else if let kind = colony.decorPlacing {
            if let problem = colony.placeDecor(kind, at: p) {
                DecorPalette.shared.refresh(problem)
            } else {
                DecorPalette.shared.refresh("放好了，可以繼續放。") // (it stays picked: click again for another; Esc, or its button again, to stop)
            }
        } else if let i = colony.decorAt(p) {
            colony.decorSelected = i
            let at = colony.decorPoint(colony.decor[i])
            colony.decorDrag = (i, CGSize(width: at.x - p.x, height: at.y - p.y), colony.decor[i])
        } else {
            colony.decorSelected = nil
        }
        needsDisplay = true
    }

    fileprivate func decorDragged(to p: CGPoint) {
        colony.hand.track(p)
        if colony.decorLaying, let kind = colony.decorPlacing, DecorCatalog.isFence(kind) {
            if colony.placeDecor(kind, at: p) == nil { DecorPalette.shared.refresh(""); needsDisplay = true }
            return
        }
        guard let drag = colony.decorDrag else { return }
        _ = colony.moveDecor(drag.index, to: CGPoint(x: p.x + drag.offset.width, y: p.y + drag.offset.height))
        needsDisplay = true
    }

    fileprivate func decorUp() {
        if colony.decorLaying {
            colony.decorLaying = false
            let pens = colony.ranch.pensDirty ? nil : colony.ranch.pens.count
            _ = pens
        }
        if let drag = colony.decorDrag, colony.decor.indices.contains(drag.index), colony.decor[drag.index] != drag.from { colony.decorChanged() }
        colony.decorDrag = nil
    }

    /// One decoration on its spot (the ones that move change frame twice a second; the roaming ones are where they have got to).
    fileprivate func drawDecorItem(_ k: Int) {
        guard colony.decor.indices.contains(k), let ctx = NSGraphicsContext.current?.cgContext else { return }
        let d = colony.decor[k]
        if DecorCatalog.isFence(d.kind) { return drawFence(d) }
        let roam = colony.decorating ? .zero : (colony.decorRoam[k]?.at ?? .zero)
        let box = colony.decorBox(d)
        let o = originOverride ?? .zero
        let r = CGRect(x: box.minX - o.x + roam.x, y: box.minY - o.y + roam.y, width: box.width, height: box.height)
        guard bounds.insetBy(dx: -60, dy: -60).intersects(r) else { return }
        let frames = DecorCatalog.frames(d.kind)
        guard !frames.isEmpty else { return }
        let image = frames[(Int(Date().timeIntervalSinceReferenceDate * 2) + k) % frames.count]
        ctx.saveGState()
        ctx.interpolationQuality = .none
        let turned = (d.flip == true) != (colony.decorRoam[k]?.left == true && !colony.decorating)
        if turned {
            ctx.translateBy(x: r.midX, y: 0)
            ctx.scaleBy(x: -1, y: 1)
            ctx.translateBy(x: -r.midX, y: 0)
        }
        ctx.draw(image, in: r)
        ctx.restoreGState()
    }

    /// In decoration mode: a banner, the picked decoration ringed, and the one being put down under the pointer (red where it cannot go).
    fileprivate func drawDecorMode() {
        drawPill("裝飾模式・點右邊的目錄挑一樣，再點營地放下", center: NSPoint(x: bounds.midX, y: bounds.maxY - 16), fontSize: 11,
                 tint: NSColor(calibratedRed: 0.3, green: 0.55, blue: 0.85, alpha: 1))
        let o = originOverride ?? .zero
        if let i = colony.decorSelected, colony.decor.indices.contains(i) {
            let box = colony.decorBox(colony.decor[i]).offsetBy(dx: -o.x, dy: -o.y).insetBy(dx: -3, dy: -3)
            let path = NSBezierPath(rect: box)
            path.lineWidth = 1.5
            path.setLineDash([4, 3], count: 2, phase: 0)
            NSColor(calibratedRed: 1, green: 0.9, blue: 0.3, alpha: 1).setStroke()
            path.stroke()
            let fence = DecorCatalog.isFence(colony.decor[i].kind)
            drawPill((DecorCatalog.kind(colony.decor[i].kind)?.name ?? "") + (fence ? (colony.decor[i].flip == true ? "（柵門）・F 改回柵欄" : "・F 改成柵門") : "・F 翻面") + "・Delete 收回", center: NSPoint(x: box.midX, y: box.maxY + 10), fontSize: 10)
        }
        for (k, pen) in colony.ranch.pens.enumerated() { // the pens: their ground tinted, and how many each holds
            NSColor(calibratedRed: 0.5, green: 0.9, blue: 0.5, alpha: 0.18).setFill()
            for cell in pen { colony.cellRect(cell).offsetBy(dx: -o.x, dy: -o.y).fill() }
            if let first = pen.first {
                let mid = pen.reduce(CGPoint.zero) { CGPoint(x: $0.x + colony.cellRect($1).midX, y: $0.y + colony.cellRect($1).midY) }
                _ = first
                drawPill("牧場 \(colony.penCount(k))／\(colony.penRoom(k))", center: NSPoint(x: mid.x / CGFloat(pen.count) - o.x, y: mid.y / CGFloat(pen.count) - o.y), fontSize: 9)
            }
        }
        guard let kind = colony.decorPlacing, var cursor = colony.hand.cursor, let image = DecorCatalog.frames(kind).first,
              let ctx = NSGraphicsContext.current?.cgContext else { return }
        if DecorCatalog.isFence(kind) { cursor = colony.fenceSnap(cursor) }
        let size = DecorCatalog.isFence(kind) ? CGSize(width: DecorCatalog.fenceCell, height: DecorCatalog.fenceCell) : DecorCatalog.size(kind)
        let r = CGRect(x: cursor.x - o.x - size.width / 2, y: cursor.y - o.y, width: size.width, height: size.height)
        let ok = colony.decorProblem(kind, at: cursor) == nil
        ctx.saveGState()
        ctx.interpolationQuality = .none
        ctx.setAlpha(0.65)
        ctx.draw(image, in: r)
        ctx.restoreGState()
        if !ok {
            NSColor(calibratedRed: 1, green: 0.2, blue: 0.2, alpha: 0.3).setFill()
            NSBezierPath(rect: r).fill()
            if let why = colony.decorProblem(kind, at: cursor) { drawPill(why, center: NSPoint(x: r.midX, y: r.maxY + 10), fontSize: 10) }
        }
    }
}

// MARK: - What the holidays look like (Holidays.swift)

extension AntView {
    private func hpx(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ c: NSColor) {
        c.setFill()
        NSRect(x: x, y: y, width: w, height: h).fill()
    }
    private func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> NSColor { NSColor(calibratedRed: r / 255, green: g / 255, blue: b / 255, alpha: a) }
    private var holidayNight: Bool { Scenery.currentHour >= 18 || Scenery.currentHour < 5 }

    /// What a resident wears or carries for the day: a pomelo-peel hat on 中秋, a little red lantern after dark on 元宵.
    fileprivate func drawHolidayWear(_ ant: Ant, day: Holiday, at p: CGPoint, size: CGFloat, pixel u: CGFloat) {
        guard ant.touch?.isHeld != true, !ant.isDying else { return }
        switch day.id {
        case "mid_autumn": // half a pomelo peel, cut into petals, upside down on the head
            let top = p.y + size * (ant.isChild ? 0.68 : 0.72)
            hpx(p.x - 3.5 * u, top, 7 * u, 2 * u, rgb(226, 214, 110))
            hpx(p.x - 2.5 * u, top + 2 * u, 5 * u, 1.5 * u, rgb(206, 196, 96))
            for k in -1...1 { hpx(p.x + CGFloat(k) * 2.4 * u - 0.6 * u, top - u, 1.2 * u, u, rgb(244, 236, 190)) } // the petals' white inside
            hpx(p.x - 0.5 * u, top + 3.5 * u, u, u, rgb(120, 150, 70))
        case "lantern" where holidayNight && ant.moving && !ant.isChild:
            let side: CGFloat = cos(ant.heading) >= 0 ? 1 : -1
            let hand = CGPoint(x: p.x + side * size * 0.34, y: p.y + size * 0.3)
            rgb(255, 150, 60, 0.14).setFill()
            NSBezierPath(ovalIn: NSRect(x: hand.x - 9, y: hand.y - 8, width: 18, height: 16)).fill()
            hpx(hand.x - 0.3 * u, hand.y + 2 * u, 0.6 * u, 2 * u, rgb(90, 60, 40))
            hpx(hand.x - 1.2 * u, hand.y - u, 2.4 * u, 3 * u, rgb(226, 60, 50))
            hpx(hand.x - 0.4 * u, hand.y - 0.2 * u, 0.8 * u, 1.4 * u, rgb(255, 220, 120))
        default: break
        }
    }

    /// What the camp looks like for the day (drawn over the camp, under the day's name).
    fileprivate func drawHolidayScene(_ day: Holiday) {
        let t = Date().timeIntervalSinceReferenceDate
        let o = originOverride ?? .zero
        switch day.id {
        case "mid_autumn" where holidayNight: // the full moon in the corner, the jade rabbit on it
            let c = CGPoint(x: bounds.maxX - 130, y: bounds.maxY - 52)
            rgb(255, 244, 190, 0.16).setFill()
            NSBezierPath(ovalIn: NSRect(x: c.x - 30, y: c.y - 30, width: 60, height: 60)).fill()
            rgb(250, 240, 200).setFill()
            NSBezierPath(ovalIn: NSRect(x: c.x - 18, y: c.y - 18, width: 36, height: 36)).fill()
            let grey = rgb(214, 204, 170)
            hpx(c.x - 6, c.y - 6, 8, 6, grey); hpx(c.x, c.y, 5, 5, grey) // the rabbit: body, head
            hpx(c.x + 1, c.y + 5, 1.5, 5, grey); hpx(c.x + 3.5, c.y + 5, 1.5, 4, grey) // ears
            hpx(c.x - 9, c.y - 7, 4, 3, grey) // the mortar
        case "lantern":
            for l in colony.fireworks.lanterns { // sky lanterns: a paper box with a flame under it, smaller as it goes up
                let p = CGPoint(x: l.pos.x - o.x, y: l.pos.y - o.y)
                let fade = CGFloat(max(0.25, 1 - l.age / 90))
                rgb(255, 170, 70, 0.16 * fade).setFill()
                NSBezierPath(ovalIn: NSRect(x: p.x - 10, y: p.y - 8, width: 20, height: 20)).fill()
                hpx(p.x - 3, p.y, 6, 8, rgb(250, 200, 120, fade)); hpx(p.x - 2, p.y + 8, 4, 1.5, rgb(240, 170, 90, fade))
                hpx(p.x - 1, p.y - 1.5, 2, 2, rgb(255, 240, 160, fade))
            }
        case "dragon_boat": // a dragon boat rowed up and down the first pond
            guard let pond = colony.scene?.visiblePonds.max(by: { $0.rect.width * $0.rect.height < $1.rect.width * $1.rect.height }) else { break } // (the biggest pond)
            let r = pond.rect.insetBy(dx: 10, dy: 6)
            guard r.width > 50 else { break }
            let span = Double(r.width - 44), phase = (t * 14).truncatingRemainder(dividingBy: span * 2)
            let going = phase < span, x = r.minX + 22 + CGFloat(going ? phase : span * 2 - phase) - o.x, y = r.midY - o.y
            let dir: CGFloat = going ? 1 : -1
            hpx(x - 20, y - 1, 40, 4, rgb(190, 50, 40)); hpx(x - 18, y - 2, 36, 1.5, rgb(240, 200, 70))
            hpx(x + dir * 20 - 2, y + 2, 5, 5, rgb(60, 150, 80)); hpx(x + dir * 23 - 1, y + 5, 2, 2, rgb(240, 200, 70)) // the head
            hpx(x - dir * 22 - 1, y + 2, 3, 4, rgb(60, 150, 80)) // the tail
            for k in 0..<5 { // paddlers and their paddles, in time
                let px = x - 14 + CGFloat(k) * 7
                hpx(px, y + 3, 3, 4, rgb(110, 170, 80))
                let dip = CGFloat(sin(t * 5 + Double(k) * 0.3)) * 2
                hpx(px + 1 - dir * 3, y - 3 + dip, 1, 5, rgb(120, 80, 45))
            }
            hpx(x - 2, y + 3, 4, 5, rgb(200, 60, 50)); hpx(x - 1, y + 8, 2, 2, rgb(250, 240, 220)) // the drummer in the middle
        case "ghost":
            if let nest = colony.nest { // the offering table for 普渡: dishes, fruit, incense smoking
                let p = CGPoint(x: nest.x + 78 - o.x, y: nest.y + 34 - o.y)
                hpx(p.x - 14, p.y, 28, 3, rgb(170, 60, 50)); hpx(p.x - 13, p.y - 8, 2, 8, rgb(120, 80, 45)); hpx(p.x + 11, p.y - 8, 2, 8, rgb(120, 80, 45))
                for (dx, c) in [(-10.0, rgb(240, 200, 60)), (-4, rgb(230, 120, 60)), (2, rgb(250, 250, 240)), (8, rgb(120, 190, 90))] as [(CGFloat, NSColor)] { hpx(p.x + dx, p.y + 3, 4, 3, c) }
                for k in 0..<3 {
                    hpx(p.x - 6 + CGFloat(k) * 6, p.y + 6, 1, 6, rgb(200, 60, 60))
                    let rise = CGFloat((t * 0.5 + Double(k) * 0.3).truncatingRemainder(dividingBy: 1))
                    hpx(p.x - 6 + CGFloat(k) * 6 + CGFloat(sin(t + Double(k))) * 2, p.y + 12 + rise * 10, 1.5, 1.5, rgb(230, 230, 230, 0.7 * (1 - rise)))
                }
            }
            guard holidayNight, let ctx = NSGraphicsContext.current?.cgContext else { break } // the gate is open: ghosts drift across the camp
            let frames = DecorCatalog.frames("u_ghost")
            guard !frames.isEmpty else { break }
            ctx.saveGState()
            ctx.interpolationQuality = .none
            ctx.setAlpha(0.55)
            for k in 0..<5 {
                let along = (t * (0.012 + Double(k) * 0.003) + Double(k) * 0.23).truncatingRemainder(dividingBy: 1)
                let x = bounds.minX - 20 + CGFloat(along) * (bounds.width + 40)
                let y = bounds.minY + bounds.height * (0.2 + 0.15 * CGFloat(k)) + CGFloat(sin(t * 0.8 + Double(k) * 2)) * 10
                let image = frames[(Int(t * 2) + k) % frames.count]
                ctx.draw(image, in: CGRect(x: x, y: y, width: CGFloat(image.width) * 2, height: CGFloat(image.height) * 2))
            }
            ctx.restoreGState()
        case "spring_festival", "lunar_eve": // red lanterns strung by the camp, and couplets either side of the way in
            guard let nest = colony.nest else { break }
            let c = CGPoint(x: nest.x - o.x, y: nest.y - o.y)
            for k in -2...2 {
                let x = c.x + CGFloat(k) * 16, y = c.y + 44 - CGFloat(k * k) * 2 + CGFloat(sin(t * 2 + Double(k))) * 0.8
                hpx(x - 0.5, y + 6, 1, 3, rgb(90, 60, 40))
                hpx(x - 4, y - 1, 8, 7, rgb(214, 46, 40)); hpx(x - 3, y - 2, 6, 1, rgb(240, 200, 70)); hpx(x - 3, y + 6, 6, 1, rgb(240, 200, 70))
                hpx(x - 0.5, y - 5, 1, 3, rgb(240, 200, 70))
            }
            for side: CGFloat in [-1, 1] {
                let x = c.x + side * 30
                hpx(x - 3, c.y - 6, 6, 26, rgb(206, 40, 36))
                for k in 0..<4 { hpx(x - 1.5, c.y - 3 + CGFloat(k) * 6, 3, 3, rgb(40, 24, 20)) }
            }
        case "qixi": // magpies crossing the sky, one after another: the bridge
            for k in 0..<6 {
                let along = (t * 0.03 + Double(k) * 0.05).truncatingRemainder(dividingBy: 1.6)
                guard along < 1 else { continue }
                let x = bounds.minX + CGFloat(along) * bounds.width, y = bounds.maxY - 50 - CGFloat(sin(along * .pi)) * 24
                let flap = Int(t * 6 + Double(k)) % 2 == 0
                hpx(x - 3, y, 6, 3, rgb(30, 30, 44)); hpx(x - 1, y, 3, 1.5, rgb(240, 240, 250)); hpx(x + 3, y + 1, 2, 1, rgb(230, 170, 60))
                hpx(x - 4, y + (flap ? 3 : -2), 5, 2, rgb(40, 50, 90))
            }
        case "qingming", "children_qingming": // the undead's graves, swept clean, shine
            for (k, g) in colony.graves.enumerated() where Int(t * 2 + Double(k)) % 3 != 0 {
                hpx(g.x - o.x - 5 + CGFloat(k % 3) * 4, g.y - o.y + 10 + CGFloat(k % 2) * 4, 2, 2, rgb(255, 255, 230, 0.9))
            }
        default: break
        }
    }
}

// MARK: - The ranch (Ranch.swift)

extension AntView {
    /// A fence piece on its grid cell, joined to its neighbours: a post, rails to the pieces left and right, and a run up to the piece behind.
    fileprivate func drawFence(_ d: DecorPlaced) {
        let cell = colony.fenceCell(d), cells = colony.ranch.pensDirty ? Set(colony.decor.filter { DecorCatalog.isFence($0.kind) }.map(colony.fenceCell)) : colony.ranch.fenceCells
        let o = originOverride ?? .zero
        let r = colony.cellRect(cell).offsetBy(dx: -o.x, dy: -o.y)
        guard bounds.insetBy(dx: -30, dy: -30).intersects(r) else { return }
        let race = Characters.current.id
        func c(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> NSColor { NSColor(calibratedRed: r / 255, green: g / 255, blue: b / 255, alpha: 1) }
        let post = race == "undead" ? c(60, 60, 72) : race == "elf" ? c(110, 150, 90) : c(110, 74, 40)
        let rail = race == "undead" ? c(84, 84, 98) : race == "elf" ? c(140, 180, 110) : c(150, 104, 60)
        let dark = c(40, 28, 20)
        func px(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ col: NSColor) { col.setFill(); NSRect(x: x, y: y, width: w, height: h).fill() }
        let mid = r.midX, base = r.minY + 2
        let left = cells.contains(GridCell(x: cell.x - 1, y: cell.y)), right = cells.contains(GridCell(x: cell.x + 1, y: cell.y))
        let up = cells.contains(GridCell(x: cell.x, y: cell.y + 1))
        if up { // the run going back to the piece behind: two rails, seen from above
            px(mid - 3, base + 8, 2, r.height, rail); px(mid + 1, base + 8, 2, r.height, rail)
        }
        for (on, x0, w) in [(left, r.minX, r.width / 2), (right, mid, r.width / 2)] as [(Bool, CGFloat, CGFloat)] where on {
            px(x0, base + 5, w, 2, rail); px(x0, base + 11, w, 2, rail)
            if race == "undead" { px(x0 + w / 2, base + 2, 1, 14, post) } // (iron bars between the posts)
        }
        if d.flip == true { // a gate: two taller posts, a bar across the top and a board hung between
            for x in [r.minX + 1, r.maxX - 4] { px(x - 1, base - 1, 5, 23, dark); px(x, base, 3, 21, post) }
            px(r.minX + 1, base + 19, r.width - 2, 2, rail)
            px(r.minX + 4, base + 3, r.width - 8, 11, rail); px(r.minX + 5, base + 4, r.width - 10, 9, post)
            px(r.maxX - 7, base + 8, 2, 2, c(240, 200, 70)) // the latch
            return
        }
        px(mid - 2.5, base - 1, 5, 19, dark); px(mid - 1.5, base, 3, 17, post)
        if race == "undead" { px(mid - 0.5, base + 17, 1, 3, c(110, 110, 124)) } // a spike
        if race == "elf" { px(mid - 2, base + 15, 2, 2, c(246, 190, 210)); px(mid + 1, base + 9, 2, 2, c(250, 240, 150)) } // flowers in the hedge
    }

    /// What of the ranch is up in the air, over everybody: the eagle (on its perch, or on the wing), the wild one on a visit,
    /// the souls round their lamps, and the beasts' souls drifting through.
    fileprivate func drawRanchAir() {
        for b in colony.ranch.beasts where b.pen < 0 { drawBeast(b) }
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        if let v = colony.ranch.visitor, let eagle = Animals.all.first(where: { $0.id == "eagle" }), let image = eagle.image(facingRight: true, phase: 0) {
            let p = local(v.perch), s = CGFloat(eagle.pixelScale)
            ctx.saveGState()
            ctx.interpolationQuality = .none
            ctx.draw(image, in: CGRect(x: p.x - CGFloat(image.width) * s / 2, y: p.y + RanchRules.perchTop - 1, width: CGFloat(image.width) * s, height: CGFloat(image.height) * s))
            ctx.restoreGState()
        }
        guard let soul = Animals.all.first(where: { $0.id == "soul_beast" }) else { return }
        for w in colony.ranch.wisps {
            guard let image = soul.image(facingRight: w.vel.dx >= 0, phase: w.life * 2) else { continue }
            let p = local(w.pos), s = CGFloat(soul.pixelScale)
            NSColor(calibratedRed: 0.5, green: 1, blue: 0.86, alpha: 0.18).setFill()
            NSBezierPath(ovalIn: NSRect(x: p.x - 14, y: p.y - 4, width: 28, height: 26)).fill()
            ctx.saveGState()
            ctx.interpolationQuality = .none
            ctx.setAlpha(0.65)
            ctx.draw(image, in: CGRect(x: p.x - CGFloat(image.width) * s / 2, y: p.y - 1, width: CGFloat(image.width) * s, height: CGFloat(image.height) * s))
            ctx.restoreGState()
        }
    }

    /// A ranch animal: its own sprite (a young one smaller), with its shadow.
    fileprivate func drawBeast(_ b: RanchBeast) {
        let phase = b.kind == "eagle" ? (b.flight > 0 ? 1 : 0) : b.legPhase // (the eagle's two pictures: perched, and wings out)
        guard let ctx = NSGraphicsContext.current?.cgContext, let kind = Animals.all.first(where: { $0.id == b.kind }),
              let image = kind.image(facingRight: b.facingRight, phase: phase) else { return }
        let p = local(b.pos)
        guard bounds.insetBy(dx: -30, dy: -30).contains(p) else { return }
        let s = CGFloat(kind.pixelScale) * (b.grown ? 1 : 0.6)
        let w = CGFloat(image.width) * s, h = CGFloat(image.height) * s
        if b.pen >= 0 {
            NSColor(calibratedWhite: 0, alpha: 0.16).setFill()
            NSBezierPath(ovalIn: NSRect(x: p.x - w * 0.4, y: p.y - 2, width: w * 0.8, height: 4)).fill()
        }
        ctx.saveGState()
        ctx.interpolationQuality = .none
        if b.kind == "soul_beast" { // a soul: its glow, and half there
            NSColor(calibratedRed: 0.5, green: 1, blue: 0.86, alpha: 0.16).setFill()
            NSBezierPath(ovalIn: NSRect(x: p.x - w * 0.6, y: p.y - 2, width: w * 1.2, height: h * 1.1)).fill()
            ctx.setAlpha(0.75)
        }
        ctx.draw(image, in: CGRect(x: p.x - w / 2, y: p.y - 1, width: w, height: h))
        ctx.restoreGState()
    }
}
