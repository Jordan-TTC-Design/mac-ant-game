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
        let phase = q.walking ? q.legPhase / 3 : 0
        guard let image = role.image(direction: SpriteDirection(heading: q.heading), phase: phase) else { return }
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
