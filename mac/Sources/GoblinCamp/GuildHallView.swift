import AppKit
import GuildRules

/// The guild hall on the Mac (GUILD.md §3–4), drawn natively like the camp: the floor, walls, furniture and decorations, and
/// every member who is in, doing what GuildRules says they are doing now (the same as on the phones), or walked by hand.
/// This one's own avatar walks where the hall is clicked (round the desks), with the arrow keys or WASD; space or E sits /
/// drinks / waves, Q cheers, Return asks to talk. The camera keeps to the avatar when the hall is bigger than the view, and
/// dragging the floor looks round.
final class GuildHallView: NSView {
    struct Member {
        let id: String
        let name: String
        let avatar: GuildInfo.Avatar
        let presence: String
        let seat: Int
    }

    // what to draw (GuildPane keeps these up to date)
    var level = 1 { didSet { if level != oldValue { layout = hallLayout(level: level) } } }
    var members: [Member] = []
    var me: String?
    var decor: [GuildInfo.Decor] = []
    var floorBase = "oak"
    var floorTiles: [String: String] = [:]
    var wall = "stone"
    /// Others walked by hand, as last heard (and when).
    var others: [String: (move: GuildMove, heard: Date)] = [:]
    /// What each member said last, over their head until then.
    var bubbles: [String: (text: String, until: Date)] = [:]
    /// Tells the others where this one's avatar is (a JSON message for the WebSocket).
    var send: (([String: Any]) -> Void)?
    /// Return was pressed (GuildPane focuses the chat box).
    var onTalk: (() -> Void)?

    private(set) var layout = hallLayout(level: 1)
    private let art = GuildArt.shared
    private var timer: Timer?

    // MARK: Walking by hand (pwa/app/composables/useHallControl.ts)

    private struct Mine { var move: GuildMove; var since: Date }
    private var mine: Mine?
    private var held = Set<String>()
    private var path: [HallPoint] = []
    private var thenSit = false
    private var lastInput = Date.distantPast
    private var lastSent = Date.distantPast
    private var sentKey = ""
    private var lastFrame = Date()
    private let speed = guildWalkSpeed * 1.3

    // MARK: The camera

    private var cam = CGPoint.zero
    private var tilePoints: CGFloat = 32
    private var lookingUntil = Date.distantPast
    private var drag: (start: CGPoint, cam: CGPoint, panning: Bool)?
    /// Smoothed positions of others' hand-walked avatars (their moves come a few times a second).
    private var shown: [String: CGPoint] = [:]

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        timer?.invalidate()
        guard window != nil else { return releaseHand() }
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(timer!, forMode: .common)
    }

    /// A tile is this many points: between the camp's little goblins and the avatars drawn big (2026-10-08 使用者：「取跟營地
    /// 大小的中間值」), in whole pixels of the art for the screen.
    static let tileTarget: CGFloat = 24

    private func fitTiles() {
        let scale = window?.backingScaleFactor ?? 2
        let want = GuildHallView.tileTarget
        let px = max(1, (want * scale / CGFloat(art.tile)).rounded())
        tilePoints = px * CGFloat(art.tile) / scale
    }
    private var viewTiles: CGSize { CGSize(width: bounds.width / tilePoints, height: bounds.height / tilePoints) }
    private func clampCam() {
        let v = viewTiles
        let w = CGFloat(layout.width), h = CGFloat(layout.height)
        cam.x = v.width >= w ? (w - v.width) / 2 : min(max(0, cam.x), w - v.width)
        cam.y = v.height >= h ? (h - v.height) / 2 : min(max(0, cam.y), h - v.height)
    }
    private func tiles(at p: CGPoint) -> HallPoint { HallPoint(x: Double(cam.x + p.x / tilePoints), y: Double(cam.y + p.y / tilePoints)) }

    // MARK: Each frame

    private func autoPose(_ m: Member, _ now: Date) -> HallPose? {
        let all = members.map { HallMember(id: $0.id, presence: $0.presence, seat: $0.seat) }
        return hallPose(layout, HallMember(id: m.id, presence: m.presence, seat: m.seat), present: all.filter { $0.presence != "offline" }, now: now.timeIntervalSince1970 * 1000)
    }

    private func tick() {
        let now = Date()
        let dt = min(0.1, now.timeIntervalSince(lastFrame))
        lastFrame = now
        stepHand(dt: dt, now: now)
        fitTiles()
        // the camera keeps to this one's avatar (unless someone is looking round)
        if now > lookingUntil, drag?.panning != true, let f = followPoint(now) {
            let v = viewTiles
            cam.x += (CGFloat(f.x) - v.width / 2 - cam.x) * 0.15
            cam.y += (CGFloat(f.y) - 1 - v.height / 2 - cam.y) * 0.15
        }
        clampCam()
        needsDisplay = true
    }

    private func followPoint(_ now: Date) -> HallPoint? {
        if let m = mine { return HallPoint(x: m.move.x, y: m.move.y) }
        guard let me, let m = members.first(where: { $0.id == me }), let p = autoPose(m, now) else { return nil }
        return HallPoint(x: p.x, y: p.y)
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let g = NSGraphicsContext.current?.cgContext else { return }
        g.setFillColor(NSColor(calibratedRed: 0.118, green: 0.098, blue: 0.071, alpha: 1).cgColor)
        g.fill(bounds)
        guard art.ready else {
            let text = "據點的圖還沒準備好。" as NSString
            text.draw(at: NSPoint(x: 20, y: 20), withAttributes: [.foregroundColor: NSColor.white, .font: NSFont.systemFont(ofSize: 14)])
            return
        }
        let now = Date()
        let t = now.timeIntervalSince1970
        let T = tilePoints
        let px = T / CGFloat(art.tile) // (points per pixel of the art)
        g.interpolationQuality = .none
        g.saveGState()
        g.translateBy(x: -cam.x * T, y: -cam.y * T)

        /// Draws an image with its top left at (x, y) in points, `w`×`h` pixels of art, the right way up, maybe mirrored.
        func put(_ img: CGImage, _ x: CGFloat, _ y: CGFloat, _ w: Int, _ h: Int, flip: Bool = false) {
            g.saveGState()
            g.translateBy(x: x, y: y + CGFloat(h) * px)
            g.scaleBy(x: flip ? -1 : 1, y: -1)
            g.draw(img, in: CGRect(x: flip ? -CGFloat(w) * px : 0, y: 0, width: CGFloat(w) * px, height: CGFloat(h) * px))
            g.restoreGState()
        }

        // floor and wall
        for y in Int(guildWallRows)..<layout.height {
            for x in 0..<layout.width {
                if let tile = art.floorTile(floorTiles["\(x),\(y)"] ?? floorBase) { put(tile, CGFloat(x) * T, CGFloat(y) * T, art.tile, art.tile) }
            }
        }
        if let w = art.wallPiece(wall) {
            let step = CGFloat(w.width) / CGFloat(art.tile)
            var x: CGFloat = 0
            while x < CGFloat(layout.width) {
                put(w, x * T, 0, w.width, w.height)
                x += step
            }
        }

        // furniture, decorations and avatars, back to front by where their feet are
        var items: [(y: Double, paint: () -> Void)] = []
        var overhead: [() -> Void] = []
        for p in layout.pieces {
            guard let f = art.furniturePiece(p.id), let img = art.frame(of: f, at: t) else { continue }
            items.append((f.flat ? -1 : p.y, { put(img, CGFloat(p.x) * T - CGFloat(f.anchorX) * px, CGFloat(p.y) * T - CGFloat(f.anchorY) * px, f.w, f.h) }))
        }
        for d in decor {
            guard let k = art.decorPiece(d.kind), let img = art.frame(of: k, at: t) else { continue }
            let paint = { put(img, CGFloat(d.x) * T - CGFloat(k.w) / 2 * px, CGFloat(d.y) * T - CGFloat(k.h) * px, k.w, k.h, flip: d.flip ?? false) }
            if k.ceiling { overhead.append(paint) } else { items.append((k.flat ? -1 : k.wall ? -0.5 + d.y / 100 : d.y, paint)) }
        }
        var labels: [() -> Void] = []
        for m in members {
            var pose: HallPose?
            if m.id == me, let mine {
                pose = HallPose(x: mine.move.x, y: mine.move.y, anim: mine.move.anim, dir: mine.move.dir, flip: mine.move.flip, t: now.timeIntervalSince(mine.since))
            } else if let o = others[m.id], now.timeIntervalSince(o.heard) < GuildTiming.moveStale {
                let was = shown[m.id] ?? CGPoint(x: o.move.x, y: o.move.y)
                let far = hypot(was.x - o.move.x, was.y - o.move.y) > 3
                let p = far ? CGPoint(x: o.move.x, y: o.move.y) : CGPoint(x: was.x + (o.move.x - was.x) * 0.35, y: was.y + (o.move.y - was.y) * 0.35)
                shown[m.id] = p
                pose = HallPose(x: Double(p.x), y: Double(p.y), anim: o.move.anim, dir: o.move.dir, flip: o.move.flip, t: now.timeIntervalSince(o.heard))
            } else {
                shown[m.id] = nil
                pose = autoPose(m, now)
            }
            guard let pose else { continue }
            let fx = CGFloat(pose.x) * T, fy = CGFloat(pose.y) * T
            let frame = art.frameIndex(anim: pose.anim, dir: pose.dir, t: pose.t)
            if let img = art.avatarFrame(m.avatar, frame) {
                items.append((pose.y, { put(img, fx - CGFloat(self.art.anchorX) * px, fy - CGFloat(self.art.anchorY) * px, self.art.frameW, self.art.frameH, flip: pose.flip) }))
            }
            let atDesk = layout.seats.contains { abs($0.x - pose.x) < 0.01 && abs($0.y - pose.y) < 0.01 }
            let mineToo = m.id == me
            labels.append { self.label(g, m.name, x: fx, y: fy + (atDesk ? 0.3 * T : 0) + 2, mine: mineToo, size: max(9, T * 0.3)) }
            if let said = bubbles[m.id], said.until > now {
                labels.append { self.bubble(g, said.text, x: fx, top: fy - CGFloat(self.art.anchorY + 4) * px, size: max(10, T * 0.34)) }
            }
        }
        items.sort { $0.y < $1.y }
        for item in items { item.paint() }
        for paint in overhead { paint() }
        for paint in labels { paint() }
        g.restoreGState()
    }

    private func label(_ g: CGContext, _ text: String, x: CGFloat, y: CGFloat, mine: Bool, size: CGFloat) {
        let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: size, weight: .semibold), .foregroundColor: mine ? NSColor(calibratedRed: 0.17, green: 0.11, blue: 0, alpha: 1) : NSColor.white]
        let s = text as NSString
        let w = s.size(withAttributes: attrs).width + 8
        let box = NSRect(x: x - w / 2, y: y, width: w, height: size + 4)
        (mine ? NSColor(calibratedRed: 0.91, green: 0.77, blue: 0.28, alpha: 0.92) : NSColor(white: 0, alpha: 0.55)).setFill()
        NSBezierPath(roundedRect: box, xRadius: 3, yRadius: 3).fill()
        s.draw(at: NSPoint(x: box.minX + 4, y: box.minY + 1), withAttributes: attrs)
    }

    private func bubble(_ g: CGContext, _ text: String, x: CGFloat, top: CGFloat, size: CGFloat) {
        let shown = text.count > 24 ? String(text.prefix(23)) + "…" : text
        let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: size), .foregroundColor: NSColor(white: 0.12, alpha: 1)]
        let s = shown as NSString
        let w = s.size(withAttributes: attrs).width + 14
        let h = size + 10
        let box = NSRect(x: x - w / 2, y: top - h, width: w, height: h)
        let path = NSBezierPath(roundedRect: box, xRadius: 6, yRadius: 6)
        path.move(to: NSPoint(x: x - 4, y: box.maxY))
        path.line(to: NSPoint(x: x, y: box.maxY + 5))
        path.line(to: NSPoint(x: x + 4, y: box.maxY))
        NSColor(calibratedRed: 1, green: 0.99, blue: 0.965, alpha: 0.96).setFill()
        path.fill()
        NSColor(white: 0.12, alpha: 1).setStroke()
        path.lineWidth = 1.5
        path.stroke()
        s.draw(at: NSPoint(x: box.minX + 7, y: box.minY + 5), withAttributes: attrs)
    }

    // MARK: Input

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        drag = (convert(event.locationInWindow, from: nil), cam, false)
    }

    override func mouseDragged(with event: NSEvent) {
        guard var d = drag else { return }
        let p = convert(event.locationInWindow, from: nil)
        if !d.panning && hypot(p.x - d.start.x, p.y - d.start.y) < 6 { return }
        d.panning = true
        drag = d
        cam = CGPoint(x: d.cam.x - (p.x - d.start.x) / tilePoints, y: d.cam.y - (p.y - d.start.y) / tilePoints)
        clampCam()
        lookingUntil = Date().addingTimeInterval(10)
    }

    override func mouseUp(with event: NSEvent) {
        defer { drag = nil }
        guard let d = drag, !d.panning else { return }
        walk(to: tiles(at: convert(event.locationInWindow, from: nil)))
    }

    private static let pads: [UInt16: String] = [126: "up", 125: "down", 123: "left", 124: "right", 13: "up", 1: "down", 0: "left", 2: "right"] // arrows, W S A D

    override func keyDown(with event: NSEvent) {
        if let pad = GuildHallView.pads[event.keyCode] {
            if !event.isARepeat, take() {
                held.insert(pad)
                path = []
            }
            return
        }
        switch event.charactersIgnoringModifiers?.lowercased() {
        case " ", "e": pressA()
        case "q": pressB()
        case "\r": onTalk?()
        default: super.keyDown(with: event)
        }
    }

    override func keyUp(with event: NSEvent) {
        if let pad = GuildHallView.pads[event.keyCode] { held.remove(pad) } else { super.keyUp(with: event) }
    }

    override func resignFirstResponder() -> Bool {
        held.removeAll()
        return super.resignFirstResponder()
    }

    // MARK: Walking by hand

    /// Takes the avatar over (from where it was wandering) on the first input.
    private func take() -> Bool {
        lastInput = Date()
        lookingUntil = .distantPast
        if mine != nil { return true }
        guard let me, let m = members.first(where: { $0.id == me }) else { return false }
        let from = autoPose(m, Date()).map { HallPoint(x: $0.x, y: $0.y) } ?? HallPoint(x: Double(layout.width) / 2, y: layout.aisles.last ?? 4)
        let at = hallWalkable(layout, from) ? from : HallPoint(x: from.x, y: layout.aisles.min { abs($0 - from.y) < abs($1 - from.y) } ?? from.y)
        mine = Mine(move: GuildMove(x: at.x, y: at.y, dir: "front", flip: false, anim: "idle"), since: Date())
        return true
    }

    private func act(_ anim: String, at: HallPoint? = nil) {
        guard var m = mine else { return }
        m.move = GuildMove(x: at?.x ?? m.move.x, y: at?.y ?? m.move.y, dir: "front", flip: false, anim: anim)
        m.since = Date()
        mine = m
    }

    func pressA() {
        guard take(), let m = mine else { return }
        let r = hallInteract(layout, HallPoint(x: m.move.x, y: m.move.y), extraSeats: [])
        act(r.anim, at: r.at)
    }

    func pressB() {
        if take() { act("cheer") }
    }

    /// Walks there round the desks; a click on a desk or its seat walks behind it and sits.
    private func walk(to target: HallPoint) {
        guard take(), let m = mine else { return }
        thenSit = false
        var goal = target
        if !hallWalkable(layout, target) {
            let near = hallInteract(layout, target, extraSeats: [])
            guard near.anim == "sit" else { return }
            goal = HallPoint(x: near.at.x, y: layout.aisles.last(where: { $0 < near.at.y }) ?? layout.aisles.first ?? near.at.y)
            thenSit = true
        }
        path = Array(hallPath(layout, from: HallPoint(x: m.move.x, y: m.move.y), to: goal).dropFirst())
    }

    private func stepHand(dt: Double, now: Date) {
        guard var m = mine else { return }
        var dx = (held.contains("right") ? 1.0 : 0) - (held.contains("left") ? 1 : 0)
        var dy = (held.contains("down") ? 1.0 : 0) - (held.contains("up") ? 1 : 0)
        let p = HallPoint(x: m.move.x, y: m.move.y)
        if dx == 0, dy == 0, let next = path.first {
            let d = hypot(next.x - p.x, next.y - p.y)
            if d < 0.08 {
                path.removeFirst()
                if path.isEmpty, thenSit {
                    thenSit = false
                    let r = hallInteract(layout, p, extraSeats: [])
                    act(r.anim, at: r.at)
                    return tell(now)
                }
            } else {
                dx = (next.x - p.x) / d
                dy = (next.y - p.y) / d
            }
        }
        if dx != 0 || dy != 0, !hallWalkable(layout, p) {
            // (sitting at a desk: stand up into the aisle behind it first)
            let aisle = layout.aisles.last(where: { $0 < p.y }) ?? layout.aisles.first ?? p.y
            m.move = GuildMove(x: p.x, y: aisle, dir: "back", flip: false, anim: "walk")
            m.since = now
        } else if dx != 0 || dy != 0 {
            let len = hypot(dx, dy)
            let room = path.first.map { hypot($0.x - p.x, $0.y - p.y) } ?? .infinity
            let step = min(speed * dt, room)
            let to = hallStep(layout, p, dx: dx / len * step, dy: dy / len * step)
            let dir = abs(dx) >= abs(dy) ? "side" : dy < 0 ? "back" : "front"
            if m.move.anim != "walk" { m.since = now }
            m.move = GuildMove(x: to.x, y: to.y, dir: dir, flip: dx > 0, anim: "walk")
            if to == p { path = [] } // (stuck: give up on the way)
        } else if m.move.anim == "walk" || (["wave", "cheer", "drink", "stretch"].contains(m.move.anim) && now.timeIntervalSince(m.since) > 3) {
            m.move.anim = "idle"
            m.since = now
        }
        mine = m
        tell(now)
        if now.timeIntervalSince(lastInput) > GuildTiming.moveIdle { releaseHand() }
    }

    /// Tells the others where it is: when it changed (at most every moveEvery), and every moveHeartbeat anyway.
    private func tell(_ now: Date) {
        guard let m = mine?.move else { return }
        let key = String(format: "%.2f,%.2f,%@,%@,%d", m.x, m.y, m.anim, m.dir, m.flip ? 1 : 0)
        let since = now.timeIntervalSince(lastSent)
        if (key != sentKey && since >= GuildTiming.moveEvery) || since >= GuildTiming.moveHeartbeat {
            send?(m.json)
            sentKey = key
            lastSent = now
        }
    }

    /// Lets the avatar go back to wandering by itself.
    func releaseHand() {
        guard mine != nil else { return }
        mine = nil
        held.removeAll()
        path = []
        sentKey = ""
        send?(["type": "guild.release"])
    }
}
