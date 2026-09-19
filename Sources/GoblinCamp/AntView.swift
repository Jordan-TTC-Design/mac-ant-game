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

    /// Global position of this view's bottom-left corner.
    private var origin: CGPoint { window?.frame.origin ?? .zero }

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
        window?.convertPoint(toScreen: event.locationInWindow) ?? NSEvent.mouseLocation
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

    override func draw(_ dirtyRect: NSRect) {
        if colony.campHidden { // the goblins are away, but the pomodoro and the popups stay
            drawMessage()
            drawPomodoro()
            return
        }
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
        drawMessage()
        drawPomodoro()
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
        let resting = pomodoro.phase == .rest
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
        let lit = resting ? NSColor(calibratedRed: 0.10, green: 0.30, blue: 0.45, alpha: 1)
                          : (seconds <= 60 ? NSColor(calibratedRed: 0.70, green: 0.08, blue: 0.08, alpha: 1)
                                           : NSColor(calibratedRed: 0.10, green: 0.22, blue: 0.10, alpha: 1))
        let glass = NSRect(x: body.minX + 5, y: body.minY + 5, width: bodyW - 10, height: bodyH - 20)
        (resting ? NSColor(calibratedRed: 0.70, green: 0.86, blue: 0.95, alpha: 1) : NSColor(calibratedRed: 0.74, green: 0.84, blue: 0.62, alpha: 1)).setFill()
        NSBezierPath(roundedRect: glass, xRadius: 3, yRadius: 3).fill()

        // label on the bezel: what the clock is counting
        let label = (resting ? "休息" : "專注") as NSString
        let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 10, weight: .bold), .foregroundColor: NSColor.white]
        label.draw(at: NSPoint(x: body.minX + 7, y: body.maxY - 15), withAttributes: attrs)
        // progress along the top edge
        let progress = CGFloat(max(0, min(1, 1 - pomodoro.remaining / pomodoro.phaseLength)))
        NSColor(calibratedWhite: 0.35, alpha: 1).setFill()
        NSRect(x: body.minX + 40, y: body.maxY - 10, width: bodyW - 47, height: 3).fill()
        (resting ? NSColor(calibratedRed: 0.4, green: 0.75, blue: 0.95, alpha: 1) : NSColor(calibratedRed: 0.5, green: 0.85, blue: 0.4, alpha: 1)).setFill()
        NSRect(x: body.minX + 40, y: body.maxY - 10, width: (bodyW - 47) * progress, height: 3).fill()

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
        if let nest = colony.nest {
            drawNest(at: CGPoint(x: nest.x - origin.x, y: nest.y - origin.y), antCount: colony.ants.count)
        }
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

        if let id = colony.selectedAntID, let ant = colony.ants.first(where: { $0.id == id }) {
            let p = local(ant.pos)
            if onScreen.contains(p) { drawSelectionRing(at: p) }
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
        ring.setLineDash([4, 3], count: 2, phase: CGFloat(Date().timeIntervalSinceReferenceDate * 12))
        NSColor(calibratedRed: 1, green: 0.9, blue: 0.3, alpha: 1).setStroke()
        ring.stroke()
    }

    private func drawSpriteWorkers(_ character: Character, scale: CGFloat, onScreen: CGRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let lastBreed = character.breeds.count - 1
        ctx.saveGState()
        ctx.interpolationQuality = .none // keep the pixels sharp
        for ant in colony.ants where !ant.isHidden {
            let p = local(ant.pos)
            guard onScreen.contains(p), let role = character.breeds[min(ant.breedIndex, lastBreed)].sprites else { continue }
            let pixel = role.pixelSize(scale: Double(scale))
            let size = CGFloat(role.frameSize) * pixel
            // the walk cycle advances with distance walked; standing still shows the first frame
            let phase = ant.moving ? ant.legPhase / 4 : 0
            guard let image = role.image(direction: SpriteDirection(heading: ant.heading), phase: phase) else { continue }
            ctx.setAlpha(CGFloat(ant.fadeAlpha)) // the dying fade out
            ctx.draw(image, in: CGRect(x: p.x - size / 2, y: p.y - size * 0.2, width: size, height: size))
            ctx.setAlpha(1)
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
            guard let walking = role.image(direction: SpriteDirection(heading: q.heading), phase: phase) else { return }
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

        if let decoration = q.decoration { drawDecoration(decoration, at: p, scale: size / 16) }
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
            // a mattress and a pillow, the pillow under her head on the left
            let outline = NSColor(calibratedRed: 0.27, green: 0.17, blue: 0.13, alpha: 1)
            let mattress = NSRect(x: p.x - size * 0.72, y: p.y + size * 0.05, width: size * 1.44, height: size * 0.62)
            outline.setFill()
            NSBezierPath(roundedRect: mattress.insetBy(dx: -pixel * 0.6, dy: -pixel * 0.6), xRadius: pixel * 2, yRadius: pixel * 2).fill()
            NSColor(calibratedRed: 0.82, green: 0.87, blue: 0.95, alpha: 1).setFill()
            NSBezierPath(roundedRect: mattress, xRadius: pixel * 1.5, yRadius: pixel * 1.5).fill()
            outline.setFill()
            NSBezierPath(roundedRect: NSRect(x: p.x - size * 0.7, y: p.y + size * 0.16, width: size * 0.42, height: size * 0.42).insetBy(dx: -pixel * 0.5, dy: -pixel * 0.5),
                         xRadius: pixel * 1.5, yRadius: pixel * 1.5).fill()
            NSColor.white.setFill()
            NSBezierPath(roundedRect: NSRect(x: p.x - size * 0.7, y: p.y + size * 0.16, width: size * 0.42, height: size * 0.42),
                         xRadius: pixel * 1.2, yRadius: pixel * 1.2).fill()
        }
    }

    /// The blanket over a sleeping princess, from her waist down.
    private func drawBlanket(at p: CGPoint, size: CGFloat) {
        let pixel = size / 16
        let blanket = NSRect(x: p.x - size * 0.02, y: p.y + size * 0.06, width: size * 0.7, height: size * 0.6)
        NSColor(calibratedRed: 0.27, green: 0.17, blue: 0.13, alpha: 1).setFill()
        NSBezierPath(roundedRect: blanket.insetBy(dx: -pixel * 0.5, dy: -pixel * 0.5), xRadius: pixel, yRadius: pixel).fill()
        NSColor(calibratedRed: 0.55, green: 0.68, blue: 0.9, alpha: 1).setFill()
        NSBezierPath(roundedRect: blanket, xRadius: pixel * 0.8, yRadius: pixel * 0.8).fill()
        NSColor(calibratedWhite: 1, alpha: 0.9).setFill() // a folded-over edge
        NSBezierPath(rect: NSRect(x: blanket.minX, y: blanket.minY, width: pixel * 1.6, height: blanket.height)).fill()
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
    private func drawPill(_ string: String, center: NSPoint, fontSize: CGFloat) {
        let text = string as NSString
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: fontSize, weight: .medium),
            .foregroundColor: NSColor.white,
        ]
        let size = text.size(withAttributes: attrs)
        let padX = fontSize * 0.9, padY = fontSize * 0.45
        let pill = NSRect(x: center.x - size.width / 2 - padX, y: center.y - size.height / 2 - padY,
                          width: size.width + padX * 2, height: size.height + padY * 2)
        NSColor.black.withAlphaComponent(0.6).setFill()
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

    /// A wandering animal: its walk frame, a shadow, and a red flash when it has just been hit.
    private func drawCreature(_ c: Creature, at p: CGPoint) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let kind = c.kind
        let facingRight = cos(c.heading) >= 0
        guard let image = kind.image(facingRight: facingRight, phase: c.legPhase) else { return }
        let w = CGFloat(image.width) * CGFloat(kind.pixelScale), h = CGFloat(image.height) * CGFloat(kind.pixelScale)
        NSColor(calibratedWhite: 0, alpha: 0.16).setFill()
        NSBezierPath(ovalIn: NSRect(x: p.x - w * 0.4, y: p.y - 3, width: w * 0.8, height: 6)).fill()
        ctx.interpolationQuality = .none
        let rect = CGRect(x: p.x - w / 2, y: p.y - h * 0.12, width: w, height: h)
        ctx.draw(image, in: rect)
        if c.hurt > 0 {
            ctx.saveGState()
            ctx.clip(to: rect, mask: image)
            ctx.setFillColor(NSColor(calibratedRed: 1, green: 0.15, blue: 0.1, alpha: 0.55).cgColor)
            ctx.fill(rect)
            ctx.restoreGState()
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
