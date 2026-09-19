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
        if colony.phase == .choosingNest {
            addCursorRect(bounds, cursor: .crosshair)
        }
    }

    override func mouseDown(with event: NSEvent) {
        guard colony.phase == .choosingNest else { return }
        let local = convert(event.locationInWindow, from: nil)
        colony.placeNest(at: CGPoint(x: origin.x + local.x, y: origin.y + local.y))
    }

    // MARK: Drawing

    override func draw(_ dirtyRect: NSRect) {
        switch colony.phase {
        case .choosingNest:
            drawPickHint()
        case .running:
            if let nest = colony.nest {
                drawNest(at: CGPoint(x: nest.x - origin.x, y: nest.y - origin.y), pulse: colony.nestPulse,
                         antCount: colony.ants.count, seed: UInt64(abs(nest.x * 7 + nest.y * 13)))
            }
            let scale = CGFloat(Settings.shared.antScale)
            let theme = Settings.shared.colorTheme
            let onScreen = bounds.insetBy(dx: -20, dy: -20)

            // All workers go into one body path and one limb path: two draw calls no matter how many ants.
            let body = CGMutablePath(), limbs = CGMutablePath()
            for ant in colony.ants {
                let p = CGPoint(x: ant.pos.x - origin.x, y: ant.pos.y - origin.y)
                if onScreen.contains(p) {
                    addAnt(to: body, limbs: limbs, at: p, heading: ant.heading, legPhase: ant.legPhase, scale: scale, queen: false)
                }
            }
            paint(body: body, limbs: limbs, color: theme.worker, lineWidth: 0.6 * scale, alpha: 1)

            for egg in colony.eggs {
                let p = CGPoint(x: egg.pos.x - origin.x, y: egg.pos.y - origin.y)
                if onScreen.contains(p) { drawEgg(at: p, alpha: egg.alpha, scale: scale) }
            }
            for d in colony.dirt {
                let p = CGPoint(x: d.pos.x - origin.x, y: d.pos.y - origin.y)
                if onScreen.contains(p) {
                    drawSpeck(at: p, radius: 1.3 * scale, color: NSColor(calibratedRed: 0.5, green: 0.36, blue: 0.22, alpha: d.alpha))
                }
            }
            for pebble in colony.pebbles {
                let p = CGPoint(x: pebble.pos.x - origin.x, y: pebble.pos.y - origin.y)
                if onScreen.contains(p) {
                    drawSpeck(at: p, radius: 1.6 * scale, color: NSColor(calibratedWhite: 0.5, alpha: pebble.alpha))
                }
            }

            if let q = colony.queen, q.alpha > 0 {
                let p = CGPoint(x: q.pos.x - origin.x, y: q.pos.y - origin.y)
                if onScreen.contains(p) {
                    let qs = 1.9 * scale
                    let qBody = CGMutablePath(), qLimbs = CGMutablePath()
                    addAnt(to: qBody, limbs: qLimbs, at: p, heading: q.heading, legPhase: q.legPhase, scale: qs,
                           queen: true, antennae: q.antennae, headScale: CGFloat(q.headScale))
                    // peeking out of the hole: only the front part of her body shows
                    var clip: CGPath?
                    if let line = q.clipLine {
                        // crawling out of the hole: hide whatever is still behind the hole's edge
                        let t = CGAffineTransform(translationX: line.origin.x - origin.x, y: line.origin.y - origin.y).rotated(by: line.angle)
                        clip = CGPath(rect: CGRect(x: 0, y: -60, width: 120, height: 120), transform: [t])
                    } else if q.emergence < 1 {
                        let cutX = 4.0 - CGFloat(q.emergence) * 9.5
                        clip = CGPath(rect: CGRect(x: cutX, y: -8, width: 30, height: 16), transform: [antTransform(at: p, heading: q.heading, scale: qs)])
                    }
                    paint(body: qBody, limbs: qLimbs, color: theme.queen, lineWidth: 0.6 * qs, alpha: q.alpha, clip: clip)
                    if q.carryingPebble {
                        drawSpeck(at: CGPoint(x: p.x + CGFloat(cos(q.heading)) * 3.9 * qs, y: p.y + CGFloat(sin(q.heading)) * 3.9 * qs),
                                  radius: 1.1 * qs, color: NSColor(calibratedWhite: 0.5, alpha: 1))
                    }
                    if let decoration = q.decoration { drawDecoration(decoration, at: p, scale: scale) }
                }
            }
        }
    }

    private func drawPickHint() {
        NSColor.black.withAlphaComponent(0.12).setFill()
        bounds.fill()

        let text = "🐜 點一下，選擇蟻窩的位置" as NSString
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 22, weight: .medium),
            .foregroundColor: NSColor.white,
        ]
        let size = text.size(withAttributes: attrs)
        let pill = NSRect(x: bounds.midX - size.width / 2 - 20, y: bounds.midY - size.height / 2 - 10,
                          width: size.width + 40, height: size.height + 20)
        NSColor.black.withAlphaComponent(0.6).setFill()
        NSBezierPath(roundedRect: pill, xRadius: pill.height / 2, yRadius: pill.height / 2).fill()
        text.draw(at: NSPoint(x: pill.minX + 20, y: pill.minY + 10), withAttributes: attrs)
    }

    private func drawNest(at p: CGPoint, pulse: Double, antCount: Int, seed: UInt64) {
        guard bounds.insetBy(dx: -100, dy: -100).contains(p) else { return }
        let f = CGFloat(1 + 0.35 * pulse) // swells briefly after the queen patches it
        if let image = NestImageStore.image {
            let width = CGFloat(Settings.shared.nestImageWidth) * f
            let height = width * image.size.height / max(image.size.width, 1)
            image.draw(in: NSRect(x: p.x - width / 2, y: p.y - height / 2, width: width, height: height),
                       from: .zero, operation: .sourceOver, fraction: 1)
            return
        }

        // The mound starts small and grows with the colony, easing toward a firm cap (about 34 pt wide at 500
        // ants) so it never gets in the way of work.
        let growth = 1 - exp(-Double(antCount) / 120)
        let width = CGFloat(18 + 16 * growth) * f
        var rng = SeededRandom(seed: seed)

        drawMound(center: p, width: width, rng: &rng, hole: true)
        // side mounds appear as the colony grows
        if antCount >= 60 { drawMound(center: CGPoint(x: p.x - width * 0.62, y: p.y - width * 0.10), width: width * 0.42, rng: &rng, hole: false) }
        if antCount >= 200 { drawMound(center: CGPoint(x: p.x + width * 0.58, y: p.y - width * 0.14), width: width * 0.36, rng: &rng, hole: false) }

        // loose crumbs of soil around the base
        let crumbs = 5 + min(antCount / 40, 5)
        for _ in 0..<crumbs {
            let angle = rng.next() * 2 * .pi
            let radius = width * CGFloat(0.62 + rng.next() * 0.35)
            let r = CGFloat(0.7 + rng.next() * 0.7)
            drawSpeck(at: CGPoint(x: p.x + cos(CGFloat(angle)) * radius, y: p.y - width * 0.1 + sin(CGFloat(angle)) * radius * 0.55),
                      radius: r, color: NSColor(calibratedRed: 0.52, green: 0.38, blue: 0.24, alpha: 0.85))
        }
    }

    /// One dome of soil: soft ground shadow, shaded dome, a few grains, and optionally the entrance hole at `center`.
    private func drawMound(center p: CGPoint, width w: CGFloat, rng: inout SeededRandom, hole: Bool) {
        let h = w * 0.58
        // with a hole the entrance sits exactly at `center`, so the dome's base sits a little below it
        let baseY = hole ? p.y - h * 0.32 : p.y - h * 0.3

        NSColor(calibratedWhite: 0, alpha: 0.13).setFill()
        NSBezierPath(ovalIn: NSRect(x: p.x - w * 0.6, y: baseY - h * 0.22, width: w * 1.2, height: h * 0.5)).fill()

        let dome = NSBezierPath()
        dome.move(to: NSPoint(x: p.x - w / 2, y: baseY))
        dome.curve(to: NSPoint(x: p.x, y: baseY + h), controlPoint1: NSPoint(x: p.x - w * 0.46, y: baseY + h * 0.75),
                   controlPoint2: NSPoint(x: p.x - w * 0.2, y: baseY + h))
        dome.curve(to: NSPoint(x: p.x + w / 2, y: baseY), controlPoint1: NSPoint(x: p.x + w * 0.2, y: baseY + h),
                   controlPoint2: NSPoint(x: p.x + w * 0.46, y: baseY + h * 0.75))
        dome.curve(to: NSPoint(x: p.x - w / 2, y: baseY), controlPoint1: NSPoint(x: p.x + w * 0.3, y: baseY - h * 0.22),
                   controlPoint2: NSPoint(x: p.x - w * 0.3, y: baseY - h * 0.22))
        dome.close()
        NSGradient(colors: [NSColor(calibratedRed: 0.42, green: 0.29, blue: 0.18, alpha: 1),
                            NSColor(calibratedRed: 0.60, green: 0.44, blue: 0.29, alpha: 1),
                            NSColor(calibratedRed: 0.74, green: 0.58, blue: 0.40, alpha: 1)])?.draw(in: dome, angle: 90)

        // grains of soil on the dome
        for _ in 0..<Int(4 + w / 5) {
            let gx = p.x + (CGFloat(rng.next()) - 0.5) * w * 0.8
            let gy = baseY + h * CGFloat(0.1 + rng.next() * 0.55)
            let light = rng.next() > 0.5
            drawSpeck(at: CGPoint(x: gx, y: gy), radius: 0.5,
                      color: light ? NSColor(calibratedRed: 0.82, green: 0.68, blue: 0.5, alpha: 0.7)
                                   : NSColor(calibratedRed: 0.33, green: 0.22, blue: 0.13, alpha: 0.6))
        }

        guard hole else { return }
        let hw = max(6, w * 0.3), hh = hw * 0.55
        NSColor(calibratedRed: 0.78, green: 0.62, blue: 0.44, alpha: 0.9).setFill() // lit lower rim
        NSBezierPath(ovalIn: NSRect(x: p.x - hw / 2 - 0.6, y: p.y - hh / 2 - 1.1, width: hw + 1.2, height: hh + 0.8)).fill()
        NSColor(calibratedRed: 0.09, green: 0.06, blue: 0.04, alpha: 1).setFill()
        NSBezierPath(ovalIn: NSRect(x: p.x - hw / 2, y: p.y - hh / 2, width: hw, height: hh)).fill()
    }

    /// Adds a tiny ant (head / thorax / abdomen, six legs, antennae) facing `heading` to the shared paths.
    private func addAnt(to body: CGMutablePath, limbs: CGMutablePath, at p: CGPoint, heading: Double, legPhase: Double,
                        scale: CGFloat, queen: Bool, antennae: (left: Double, right: Double) = (0, 0),
                        headScale: CGFloat = 1) {
        let c = CGFloat(cos(heading)), s = CGFloat(sin(heading))
        // ant-local (x forward, y left) -> view coordinates
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: p.x + (x * c - y * s) * scale, y: p.y + (x * s + y * c) * scale)
        }

        for i in 0..<3 {
            let x = CGFloat(i) - 1.0
            let swing = CGFloat(sin(legPhase + Double(i) * 2.1)) * 1.1
            for side: CGFloat in [-1, 1] {
                limbs.move(to: point(x, 0))
                limbs.addLine(to: point(x + swing * side, side * 3))
            }
        }
        let leftAngle = 0.65 + antennae.left, rightAngle = 0.65 + antennae.right
        limbs.move(to: point(1.8, 0.4))
        limbs.addLine(to: point(1.8 + 1.9 * CGFloat(cos(leftAngle)), 0.4 + 1.9 * CGFloat(sin(leftAngle))))
        limbs.move(to: point(1.8, -0.4))
        limbs.addLine(to: point(1.8 + 1.9 * CGFloat(cos(rightAngle)), -0.4 - 1.9 * CGFloat(sin(rightAngle))))

        let transform = antTransform(at: p, heading: heading, scale: scale)
        let abdomen: CGFloat = queen ? 2.4 : 1.8
        body.addEllipse(in: CGRect(x: -2.6 - abdomen, y: -abdomen * 0.8, width: abdomen * 2, height: abdomen * 1.6), transform: transform)
        body.addEllipse(in: CGRect(x: -1.2, y: -1.0, width: 2.4, height: 2.0), transform: transform)
        body.addEllipse(in: CGRect(x: 1.0, y: -1.1 * headScale, width: 2.2 * headScale, height: 2.2 * headScale), transform: transform)
    }

    /// Ant-local coordinates (x forward) to view coordinates.
    private func antTransform(at p: CGPoint, heading: Double, scale: CGFloat) -> CGAffineTransform {
        let c = CGFloat(cos(heading)), s = CGFloat(sin(heading))
        return CGAffineTransform(a: c * scale, b: s * scale, c: -s * scale, d: c * scale, tx: p.x, ty: p.y)
    }

    private func paint(body: CGPath, limbs: CGPath, color: NSColor, lineWidth: CGFloat, alpha: CGFloat, clip: CGPath? = nil) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.saveGState()
        if let clip {
            ctx.addPath(clip)
            ctx.clip()
        }
        ctx.setAlpha(alpha)
        ctx.setFillColor(color.cgColor)
        ctx.setStrokeColor(color.cgColor)
        ctx.setLineWidth(lineWidth)
        ctx.setLineCap(.round)
        ctx.addPath(limbs)
        ctx.strokePath()
        ctx.addPath(body)
        ctx.fillPath()
        ctx.restoreGState()
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

    private func drawEgg(at p: CGPoint, alpha: Double, scale: CGFloat) {
        let rect = NSRect(x: p.x - 1.3 * scale, y: p.y - 1.7 * scale, width: 2.6 * scale, height: 3.4 * scale)
        NSColor(calibratedRed: 0.98, green: 0.96, blue: 0.86, alpha: alpha).setFill()
        NSColor(calibratedWhite: 0.45, alpha: 0.6 * alpha).setStroke()
        let path = NSBezierPath(ovalIn: rect)
        path.lineWidth = 0.4
        path.fill()
        path.stroke()
    }
}

/// Tiny deterministic random source so the nest's grains and crumbs stay put from frame to frame.
struct SeededRandom {
    private var state: UInt64
    init(seed: UInt64) { state = seed &* 6364136223846793005 &+ 1442695040888963407 }

    /// Uniform in 0..<1.
    mutating func next() -> Double {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return Double(state >> 11) / Double(1 << 53)
    }
}
