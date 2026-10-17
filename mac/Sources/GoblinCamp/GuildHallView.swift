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
    /// The hall's shape (which tiles are floor). Drawn anew, everything may have moved: one's own avatar goes back to wandering.
    var area = defaultHallArea {
        didSet {
            guard area != oldValue else { return }
            groundVersion += 1
            mine = nil
            path = []
            furnish()
        }
    }
    var members: [Member] = [] { didSet { ways = HallWays() } }
    var me: String?
    /// Everything in the hall (the desks too: all of it is decoration, GUILD.md §4.2).
    var decor: [GuildInfo.Decor] = [] { didSet { if editing { furnishDirty = true } else { furnish() } } }
    var floorBase = "oak" { didSet { groundVersion += 1 } }
    var floorTiles: [String: String] = [:] { didSet { groundVersion += 1 } }
    var wall = "stone" { didSet { groundVersion += 1 } }
    /// The wall brushed a segment at a time: "x,y" of the floor tile a column stands on → its style (the rest are `wall`).
    var walls: [String: String] = [:] { didSet { if walls != oldValue { groundVersion += 1 } } }
    /// The floor given to members ("x,y" → their id), shown while decorating.
    var plots: [String: String] = [:]
    /// The guild (its id places the merchant) and whether the guild merchant is visiting; a click on him calls `onMerchant`.
    var guildId = ""
    /// His visit (this one, or the next): he is in the hall from `from` until `until`, by the clock.
    var merchantVisit: (from: Date, until: Date)?
    var onMerchant: (() -> Void)?
    /// Where the merchant stands while he visits (not while decorating: the floor is the editor's then); shared/src/guild-merchant.ts.
    private var merchantSpot: HallPoint? {
        guard let v = merchantVisit, (v.from..<v.until).contains(Date()), !editing, art.merchant != nil else { return nil }
        return hallFreeSpot(layout, [guildId, "merchant"])
    }
    /// The box he is drawn in (hall tiles), for clicks.
    private func merchantBox(_ p: HallPoint) -> CGRect? {
        guard let m = art.merchant else { return nil }
        let px = 1 / Double(art.tile)
        return CGRect(x: p.x - m.anchorX * px, y: p.y - m.anchorY * px, width: Double(m.w) * px, height: Double(m.h) * px)
    }
    /// The floor and the wall are drawn once into a picture and put on at every frame (a hall has over a thousand tiles; putting
    /// each one on thirty times a second was what made decorating slow). Made again when any of these change.
    private var groundVersion = 0
    private var ground: (image: CGImage, version: Int, tile: CGFloat, scale: CGFloat, width: Int, height: Int)?
    /// Others walked by hand, as last heard (and when).
    var others: [String: (move: GuildMove, heard: Date)] = [:]
    /// What each member said last, over their head until then.
    var bubbles: [String: (text: String, until: Date)] = [:]
    /// Tells the others where this one's avatar is (a JSON message for the WebSocket).
    var send: (([String: Any]) -> Void)?
    /// Return was pressed (GuildPane focuses the chat box).
    var onTalk: (() -> Void)?

    // decorating (GuildDecorEditor): the hall is not walked in then; pieces are picked and dragged, or a floor brush paints
    var editing = false {
        didSet {
            if editing {
                releaseHand()
            } else {
                selected = []
                box = nil
                hover = nil
                brush = nil
                wallBrush = nil
                plotting = false
                stamp = nil
                shaping = false
                if furnishDirty { furnish() } // (the pieces moved meanwhile: the ways are worked out once, now)
            }
        }
    }
    /// The pieces changed while decorating: the hall's ways are looked at again afterwards, not at every drag.
    private var furnishDirty = false
    /// The pieces picked (one clicked, more with ⇧ or a box dragged round them): they move, turn and go together.
    var selected = Set<String>() { didSet { if selected != oldValue { needsDisplay = true } } }
    /// A floor style to lay tile by tile (nil: picking pieces).
    var brush: String?
    var onSelect: (() -> Void)?
    /// A piece dragged to (x, y): the editor moves the others picked with it.
    var onMove: ((String, Double, Double) -> Void)?
    /// Dragging on empty floor draws a box that picks what it touches (the 🪑 tab; elsewhere a drag there looks round).
    var boxSelects = false
    private var box: (from: HallPoint, to: HallPoint, base: Set<String>)?
    /// A press in the hall began (true) or ended (false): what changes meanwhile is one step to undo.
    var onStroke: ((Bool) -> Void)?
    var onUndo: (() -> Void)?
    var onRedo: (() -> Void)?
    var canUndo: (() -> (undo: Bool, redo: Bool))?
    /// Where the held piece would go with its middle at (x, its bottom y), and whether it can (for its picture under the pointer).
    var stampLook: ((String, Double, Double) -> (x: Double, y: Double, ok: Bool))?
    /// The pointer over the hall while a piece is held (nil: away, or nothing held).
    private var hover: HallPoint?
    var onPaint: ((Int, Int) -> Void)?
    /// A piece to put down like a floor brush (nil: picking pieces): one where clicked, and more along a drag, a piece's
    /// width apart. `onStamp` puts one at (x, its bottom y) and says whether it went down.
    var stamp: String? { didSet { if stamp != oldValue { lastStamp = nil; needsDisplay = true } } }
    var onStamp: ((String, Double, Double) -> Bool)?
    private var lastStamp: HallPoint?
    /// A wall style to brush a segment at a time (nil: none): a click or a drag on the wall gives `onWall` the floor tile its
    /// column stands on.
    var wallBrush: String?
    var onWall: ((Int, Int) -> Void)?
    /// Giving floor to members (the 🏠 tab): a click or a drag gives `onPlot` each floor tile, and the places show strongly.
    var plotting = false
    var onPlot: ((Int, Int) -> Void)?
    /// Drawing the hall's shape (the leader and officers): a click or a drag gives every tile under it, off the floor too,
    /// once a stroke; a margin shows round the hall to grow into.
    var shaping = false { didSet { if shaping != oldValue { clampCam(); needsDisplay = true } } }
    var onShape: ((Int, Int) -> Void)?
    private var lastShaped: [Int]?
    private static let shapeMargin: CGFloat = 6
    /// Delete pressed: the picked pieces go.
    var onRemove: (() -> Void)?
    var onEscape: (() -> Void)?
    private var carrying: (uid: String, dx: Double, dy: Double)?
    private var painting = false

    private(set) var layout = hallLayout()
    /// The ways the wanderers walk, kept while the hall and who is in it stay the same.
    private var ways = HallWays()
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
    /// A click on the hall acts at once, also when the window was behind (it would only have brought the window forward).
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

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

    /// Where a tile point of the hall is in this view (a test sends mouse events there).
    func debugViewPoint(x: Double, y: Double) -> NSPoint { NSPoint(x: (CGFloat(x) - cam.x) * tilePoints, y: (CGFloat(y) - cam.y) * tilePoints) }

    private func fitTiles() {
        let scale = window?.backingScaleFactor ?? 2
        let want = GuildHallView.tileTarget
        let px = max(1, (want * scale / CGFloat(art.tile)).rounded())
        tilePoints = px * CGFloat(art.tile) / scale
    }
    private var viewTiles: CGSize { CGSize(width: bounds.width / tilePoints, height: bounds.height / tilePoints) }
    /// Room on the right a panel covers (GuildPane): the hall is looked at, and centred, in what is left.
    var rightInset: CGFloat = 0
    private var seenTiles: CGSize { CGSize(width: max(1, bounds.width - rightInset) / tilePoints, height: bounds.height / tilePoints) }
    private func clampCam() {
        let v = seenTiles
        let w = CGFloat(layout.width), h = CGFloat(layout.height)
        let m = editing && shaping ? GuildHallView.shapeMargin : 0
        cam.x = v.width >= w + 2 * m ? (w - v.width) / 2 : min(max(-m, cam.x), w + m - v.width)
        cam.y = v.height >= h + 2 * m ? (h - v.height) / 2 : min(max(-m, cam.y), h + m - v.height)
    }
    /// Everything in the hall moved by (dx, dy) tiles (its shape grew up or to the left): the view moves with it, so nothing jumps.
    func nudge(dx: Int, dy: Int) {
        cam.x += CGFloat(dx)
        cam.y += CGFloat(dy)
        if var d = drag {
            d.cam.x += CGFloat(dx)
            d.cam.y += CGFloat(dy)
            drag = d
        }
    }
    private func tiles(at p: CGPoint) -> HallPoint { HallPoint(x: Double(cam.x + p.x / tilePoints), y: Double(cam.y + p.y / tilePoints)) }

    /// The hall as the pieces put down make it: where one works, sits, drinks and cannot go (shared/src/guild-decor.ts
    /// guildFurnishing).
    private func furnish() {
        let pieces = decor.compactMap { d -> HallPlacedPiece? in
            guard let k = art.decorPiece(d.kind) else { return nil }
            let spec = HallPieceSpec(w: Double(k.w), h: Double(k.h), flat: k.flat, wall: k.wall, ceiling: k.ceiling, living: k.living,
                                     seat: k.seat.map { HallPoint(x: $0.x, y: $0.y) }, desk: k.desk, drink: k.drink)
            return HallPlacedPiece(x: d.x, y: d.y, flip: d.flip ?? false, spec: spec)
        }
        layout = hallLayout(area: area, furnishing: hallFurnishing(pieces))
        ways = HallWays()
    }

    // MARK: Each frame

    /// Where each one was last put (kept so a frame that has no time left, or decorating, can show them where they were).
    private var posesKept: [String: HallPose] = [:]
    private var frameStart = Date()
    /// What a frame may spend on working out the wanderers' ways (seconds); a way round many pieces is a search, and when
    /// the hall changes every one of them is needed again.
    private let wayBudget = 0.008

    private func autoPose(_ m: Member, _ now: Date) -> HallPose? {
        // (no wandering while decorating: they stay where they were, and the pieces can be dragged without a search at each step)
        if editing, let kept = posesKept[m.id] { return kept }
        if Date().timeIntervalSince(frameStart) > wayBudget, let kept = posesKept[m.id] { return kept }
        let all = members.map { HallMember(id: $0.id, presence: $0.presence, seat: $0.seat) }
        let pose = hallPose(layout, HallMember(id: m.id, presence: m.presence, seat: m.seat), present: all.filter { $0.presence != "offline" }, now: now.timeIntervalSince1970 * 1000, ways: ways)
        posesKept[m.id] = pose
        return pose
    }

    private func tick() {
        let now = Date()
        frameStart = now
        let dt = min(0.1, now.timeIntervalSince(lastFrame))
        lastFrame = now
        stepHand(dt: dt, now: now)
        fitTiles()
        // the camera keeps to this one's avatar (unless someone is looking round)
        if !editing, now > lookingUntil, drag?.panning != true, let f = followPoint(now) {
            let v = seenTiles
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

        // off the floor (round the hall, and in its corners if it is not a rectangle): the floor goes on, darkened, so
        // there is no black frame
        let v = viewTiles
        let x0 = Int(floor(cam.x)), x1 = max(x0, Int(ceil(cam.x + v.width))), y0 = Int(floor(cam.y)), y1 = max(y0, Int(ceil(cam.y + v.height)))
        if let tile = art.floorTile(floorBase) {
            let off = CGMutablePath()
            for y in y0..<y1 {
                for x in x0..<x1 where !layout.floorAt(x, y) {
                    put(tile, CGFloat(x) * T, CGFloat(y) * T, art.tile, art.tile)
                    off.addRect(CGRect(x: CGFloat(x) * T, y: CGFloat(y) * T, width: T, height: T))
                }
            }
            g.addPath(off)
            g.setFillColor(NSColor(calibratedRed: 0.08, green: 0.06, blue: 0.04, alpha: 0.72).cgColor)
            g.fillPath()
        }

        // floor and wall: one picture of the whole hall (made again when it changed)
        let scale = window?.backingScaleFactor ?? 2
        if ground == nil || ground!.version != groundVersion || ground!.tile != T || ground!.scale != scale || ground!.width != layout.width || ground!.height != layout.height,
           let image = makeGround(tile: T, scale: scale) {
            ground = (image, groundVersion, T, scale, layout.width, layout.height)
        }
        if let ground {
            put(ground.image, 0, 0, Int(CGFloat(layout.width) * T / px), Int(CGFloat(layout.height) * T / px))
        }
        if editing, !plots.isEmpty { // (the members' places: faint, strong while they are being given)
            var named: [String: HallPoint] = [:]
            for (key, who) in plots {
                let at = key.split(separator: ",").compactMap { Int($0) }
                guard at.count == 2, let colour = plotColour(who) else { continue }
                g.setFillColor(colour.withAlphaComponent(plotting ? 0.38 : 0.14).cgColor)
                g.fill(CGRect(x: CGFloat(at[0]) * T, y: CGFloat(at[1]) * T, width: T, height: T))
                let p = HallPoint(x: Double(at[0]), y: Double(at[1]))
                if let was = named[who], (was.y, was.x) <= (p.y, p.x) { continue }
                named[who] = p
            }
            plotNames = named.compactMap { who, p in members.first { $0.id == who }.map { ($0.name, p, plotColour(who)!) } }
        } else {
            plotNames = []
        }
        if editing, shaping { // (every tile in view, to see where the floor can go)
            g.setStrokeColor(NSColor(calibratedRed: 1, green: 0.88, blue: 0.4, alpha: 0.38).cgColor)
            g.setLineWidth(1)
            for x in x0...x1 { g.stroke(CGRect(x: CGFloat(x) * T, y: CGFloat(y0) * T, width: 0, height: CGFloat(y1 - y0) * T)) }
            for y in y0...y1 { g.stroke(CGRect(x: CGFloat(x0) * T, y: CGFloat(y) * T, width: CGFloat(x1 - x0) * T, height: 0)) }
        }

        // decorations and avatars, back to front by where their feet are
        var items: [(y: Double, paint: () -> Void)] = []
        var overhead: [() -> Void] = []
        for d in decor {
            guard let k = art.decorPiece(d.kind), let img = art.frame(of: k, at: t) else { continue }
            let paint = { put(img, CGFloat(d.x) * T - CGFloat(k.w) / 2 * px, CGFloat(d.y) * T - CGFloat(k.h) * px, k.w, k.h, flip: d.flip ?? false) }
            if k.ceiling { overhead.append(paint) } else { items.append((k.flat ? -1 : k.wall ? -0.5 + d.y / 100 : d.y, paint)) }
        }
        var labels: [() -> Void] = []
        if let spot = merchantSpot, let m = art.merchant, let img = art.frame(of: m, at: t) { // (the guild merchant at his cart, a 🛒 over him)
            let fx = CGFloat(spot.x) * T, fy = CGFloat(spot.y) * T
            items.append((spot.y, { put(img, fx - CGFloat(m.anchorX) * px, fy - CGFloat(m.anchorY) * px, m.w, m.h) }))
            labels.append { self.bubble(g, "🛒 公會商人", x: fx, top: fy - CGFloat(m.anchorY + 4) * px, size: max(10, T * 0.32)) }
        }
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
            let atDesk = layout.desks.contains { abs($0.x - pose.x) < 0.01 && abs($0.y - pose.y) < 0.01 }
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
        for (name, p, colour) in plotNames { // (each member's place: their name on its top left tile)
            let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: max(9, T * 0.32), weight: .semibold), .foregroundColor: NSColor.white]
            let s = "🏠 \(name)" as NSString
            let size = s.size(withAttributes: attrs)
            let box = NSRect(x: CGFloat(p.x) * T + 2, y: CGFloat(p.y) * T + 2, width: size.width + 8, height: size.height + 2)
            colour.withAlphaComponent(plotting ? 0.9 : 0.6).setFill()
            NSBezierPath(roundedRect: box, xRadius: 3, yRadius: 3).fill()
            s.draw(at: NSPoint(x: box.minX + 4, y: box.minY + 1), withAttributes: attrs)
        }
        if editing, !selected.isEmpty {
            g.setStrokeColor(NSColor(calibratedRed: 0.91, green: 0.77, blue: 0.28, alpha: 1).cgColor)
            g.setLineWidth(2)
            g.setLineDash(phase: CGFloat((t * 12).truncatingRemainder(dividingBy: 10)), lengths: [6, 4]) // (not t * 12 itself: t is seconds since 1970, and the dasher counts its way to the phase, which took about a second per stroke)
            for d in decor where selected.contains(d.uid) {
                guard let k = art.decorPiece(d.kind) else { continue }
                g.stroke(CGRect(x: CGFloat(d.x) * T - CGFloat(k.w) / 2 * px, y: CGFloat(d.y) * T - CGFloat(k.h) * px, width: CGFloat(k.w) * px, height: CGFloat(k.h) * px).insetBy(dx: -2, dy: -2))
            }
            g.setLineDash(phase: 0, lengths: [])
        }
        if editing, let b = box { // (the box being dragged)
            let r = CGRect(x: CGFloat(min(b.from.x, b.to.x)) * T, y: CGFloat(min(b.from.y, b.to.y)) * T, width: CGFloat(abs(b.to.x - b.from.x)) * T, height: CGFloat(abs(b.to.y - b.from.y)) * T)
            g.setFillColor(NSColor(calibratedRed: 1, green: 0.88, blue: 0.4, alpha: 0.12).cgColor)
            g.fill(r)
            g.setStrokeColor(NSColor(calibratedRed: 1, green: 0.88, blue: 0.4, alpha: 0.9).cgColor)
            g.setLineWidth(1)
            g.stroke(r)
        }
        // the held piece under the pointer: green where it can go, red where it cannot
        if editing, let kind = stamp, let at = hover, let k = art.decorPiece(kind), let img = art.frame(of: k, at: t),
           let look = stampLook?(kind, at.x, at.y + Double(k.h) / 32) {
            let r = CGRect(x: CGFloat(look.x) * T - CGFloat(k.w) / 2 * px, y: CGFloat(look.y) * T - CGFloat(k.h) * px, width: CGFloat(k.w) * px, height: CGFloat(k.h) * px)
            g.saveGState()
            g.setAlpha(0.6)
            put(img, r.minX, r.minY, k.w, k.h)
            g.restoreGState()
            let tint = look.ok ? NSColor(calibratedRed: 0.4, green: 0.9, blue: 0.45, alpha: 1) : NSColor(calibratedRed: 1, green: 0.4, blue: 0.35, alpha: 1)
            g.setFillColor(tint.withAlphaComponent(0.18).cgColor)
            g.fill(r.insetBy(dx: -2, dy: -2))
            g.setStrokeColor(tint.cgColor)
            g.setLineWidth(1.5)
            g.stroke(r.insetBy(dx: -2, dy: -2))
        }
        g.restoreGState()
    }

    /// The members' places to label this frame: a name, where, and the member's colour.
    private var plotNames: [(String, HallPoint, NSColor)] = []

    /// A colour for each member (by when they joined), the same in the 🏠 tab's cards.
    static let plotColours: [NSColor] = [(0.95, 0.55, 0.25), (0.35, 0.7, 0.95), (0.55, 0.85, 0.35), (0.9, 0.4, 0.7), (0.95, 0.85, 0.3), (0.6, 0.5, 0.95), (0.3, 0.85, 0.75), (0.95, 0.4, 0.4)]
        .map { NSColor(calibratedRed: $0.0, green: $0.1, blue: $0.2, alpha: 1) }
    func plotColour(_ who: String) -> NSColor? {
        members.firstIndex { $0.id == who }.map { GuildHallView.plotColours[$0 % GuildHallView.plotColours.count] }
    }

    /// The floor and the wall of the whole hall as one picture, `tile` points to a tile, `scale` pixels to a point.
    private func makeGround(tile T: CGFloat, scale: CGFloat) -> CGImage? {
        let wPts = CGFloat(layout.width) * T, hPts = CGFloat(layout.height) * T
        guard wPts > 0, hPts > 0, let g = CGContext(data: nil, width: Int((wPts * scale).rounded()), height: Int((hPts * scale).rounded()), bitsPerComponent: 8, bytesPerRow: 0,
                                                    space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue) else { return nil }
        g.interpolationQuality = .none
        g.scaleBy(x: scale, y: scale)
        g.translateBy(x: 0, y: hPts) // (so that y runs down, like the hall's)
        g.scaleBy(x: 1, y: -1)
        let px = T / CGFloat(art.tile)
        func put(_ img: CGImage, _ x: CGFloat, _ y: CGFloat, _ w: Int, _ h: Int) {
            g.saveGState()
            g.translateBy(x: x, y: y + CGFloat(h) * px)
            g.scaleBy(x: 1, y: -1)
            g.draw(img, in: CGRect(x: 0, y: 0, width: CGFloat(w) * px, height: CGFloat(h) * px))
            g.restoreGState()
        }
        // a wall over every top edge of the floor, then the floor (over the top of a wall that has floor right behind it);
        // off the floor the picture is clear (the darkened floor round the hall shows through)
        for t in layout.floorTiles where !layout.floorAt(Int(t.x), Int(t.y) - 1) {
            guard let w = art.wallPiece(walls["\(Int(t.x)),\(Int(t.y))"] ?? wall) ?? art.wallPiece(wall) else { continue }
            put(w, CGFloat(t.x) * T, (CGFloat(t.y) - CGFloat(w.height) / CGFloat(art.tile)) * T, w.width, w.height)
        }
        for t in layout.floorTiles {
            if let tile = art.floorTile(floorTiles["\(Int(t.x)),\(Int(t.y))"] ?? floorBase) { put(tile, CGFloat(t.x) * T, CGFloat(t.y) * T, art.tile, art.tile) }
        }
        return g.makeImage()
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
        let p = convert(event.locationInWindow, from: nil)
        drag = (p, cam, false)
        carrying = nil
        painting = false
        guard editing else { return }
        onStroke?(true)
        let at = tiles(at: p)
        let shift = event.modifierFlags.contains(.shift)
        if shaping {
            painting = true
            lastShaped = nil
            shape(at)
            followEdge(p)
        } else if brush != nil {
            painting = true
            paint(at)
        } else if wallBrush != nil {
            painting = true
            paintWall(at)
        } else if plotting {
            painting = true
            paintPlot(at)
        } else if stamp != nil {
            painting = true
            lastStamp = nil
            stampAt(at)
        } else if let d = pieceAt(at) {
            if shift { // (⇧: in or out of the pick, nothing carried)
                if selected.contains(d.uid) { selected.remove(d.uid) } else { selected.insert(d.uid) }
                onSelect?()
                return
            }
            if !selected.contains(d.uid) { selected = [d.uid] } // (one of several picked: they all go with it)
            onSelect?()
            carrying = (d.uid, d.x - at.x, d.y - at.y)
        } else if boxSelects {
            box = (at, at, shift ? selected : [])
            if !shift, !selected.isEmpty { // (a click on nothing puts the pick down)
                selected = []
                onSelect?()
            }
        }
    }

    /// The pieces whose pictures touch the box from a to b (tiles).
    private func pieces(in a: HallPoint, _ b: HallPoint) -> Set<String> {
        let x0 = min(a.x, b.x), x1 = max(a.x, b.x), y0 = min(a.y, b.y), y1 = max(a.y, b.y)
        var hit = Set<String>()
        for d in decor {
            guard let k = art.decorPiece(d.kind) else { continue }
            let halfW = Double(k.w) / 32, h = Double(k.h) / 16
            if d.x + halfW >= x0, d.x - halfW <= x1, d.y >= y0, d.y - h <= y1 { hit.insert(d.uid) }
        }
        return hit
    }

    /// The piece standing at this point of the hall (the one in front, where several overlap).
    private func pieceAt(_ p: HallPoint) -> GuildInfo.Decor? {
        var best: (d: GuildInfo.Decor, rank: Double)?
        for d in decor {
            guard let k = art.decorPiece(d.kind) else { continue }
            let halfW = Double(k.w) / 32, h = Double(k.h) / 16
            guard p.x >= d.x - halfW, p.x <= d.x + halfW, p.y >= d.y - h, p.y <= d.y else { continue }
            let rank = k.flat ? -1 : k.ceiling ? 1000 : d.y
            if best == nil || rank >= best!.rank { best = (d, rank) }
        }
        return best?.d
    }

    private func shape(_ p: HallPoint) {
        let tile = [Int(floor(p.x)), Int(floor(p.y))]
        guard tile != lastShaped else { return }
        lastShaped = tile
        onShape?(tile[0], tile[1])
    }

    /// Drawing the shape at the edge of what is seen: the view moves a tile that way, so the drawing can go on.
    private func followEdge(_ p: CGPoint) {
        let edge = tilePoints * 1.5
        let seen = CGSize(width: max(1, bounds.width - rightInset), height: bounds.height)
        if p.x < edge { cam.x -= 1 } else if p.x > seen.width - edge { cam.x += 1 }
        if p.y < edge { cam.y -= 1 } else if p.y > seen.height - edge { cam.y += 1 }
        clampCam()
    }

    /// Two fingers on the trackpad, or the wheel: looks round the hall (while decorating a drag is taken, so this is the way).
    override func scrollWheel(with event: NSEvent) {
        let k: CGFloat = event.hasPreciseScrollingDeltas ? 1 : 8
        cam.x -= event.scrollingDeltaX * k / tilePoints
        cam.y -= event.scrollingDeltaY * k / tilePoints
        clampCam()
        lookingUntil = Date().addingTimeInterval(10)
        needsDisplay = true
    }

    /// Puts the stamp's piece with its middle under the pointer, if the last one is a piece's width (a tile at least) away.
    private func stampAt(_ p: HallPoint) {
        guard let kind = stamp, let piece = art.decorPiece(kind) else { return }
        let w = max(1, Double(piece.w) / 16), h = Double(piece.h) / 16
        if let last = lastStamp, abs(p.x - last.x) < w, abs(p.y - last.y) < max(1, h * 0.6) { return }
        if onStamp?(kind, p.x, p.y + h / 2) == true { lastStamp = p }
    }

    /// The wall column under the point (its rows, or the floor tile it stands on): the floor tile it stands on.
    private func paintWall(_ p: HallPoint) {
        let x = Int(floor(p.x)), y = Int(floor(p.y))
        guard let r = (y...y + Int(guildWallRows)).first(where: { layout.wallAt(x, $0) }) else { return }
        onWall?(x, r)
    }

    private func paintPlot(_ p: HallPoint) {
        let x = Int(floor(p.x)), y = Int(floor(p.y))
        guard layout.floorAt(x, y) else { return }
        onPlot?(x, y)
    }

    private func paint(_ p: HallPoint) {
        let x = Int(floor(p.x)), y = Int(floor(p.y))
        guard layout.floorAt(x, y) else { return }
        onPaint?(x, y)
    }

    override func mouseDragged(with event: NSEvent) {
        if editing, painting {
            let p = convert(event.locationInWindow, from: nil)
            let at = tiles(at: p)
            if shaping {
                let was = lastShaped
                shape(at)
                if lastShaped != was { followEdge(p) }
            } else if wallBrush != nil {
                paintWall(at)
            } else if plotting {
                paintPlot(at)
            } else if stamp != nil {
                hover = at
                let was = lastStamp
                stampAt(at)
                if lastStamp != was { followEdge(p) }
            } else {
                paint(at)
            }
            return
        }
        if editing, let c = carrying {
            let at = tiles(at: convert(event.locationInWindow, from: nil))
            onMove?(c.uid, at.x + c.dx, at.y + c.dy)
            return
        }
        if editing, var b = box {
            let p = convert(event.locationInWindow, from: nil)
            b.to = tiles(at: p)
            box = b
            let now = b.base.union(pieces(in: b.from, b.to))
            if now != selected {
                selected = now
                onSelect?()
            }
            followEdge(p)
            return
        }
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
        defer {
            if editing, drag != nil { onStroke?(false) }
            drag = nil
            carrying = nil
            painting = false
            box = nil
        }
        guard let d = drag, !d.panning else { return }
        if editing { return }
        let at = tiles(at: convert(event.locationInWindow, from: nil))
        if let spot = merchantSpot, let box = merchantBox(spot), box.contains(CGPoint(x: at.x, y: at.y)) { // (a click on the merchant: his wares)
            onMerchant?()
            return
        }
        walk(to: at)
    }

    private static let pads: [UInt16: String] = [126: "up", 125: "down", 123: "left", 124: "right", 13: "up", 1: "down", 0: "left", 2: "right"] // arrows, W S A D

    override func keyDown(with event: NSEvent) {
        if editing {
            if event.keyCode == 51 || event.keyCode == 117, !selected.isEmpty { onRemove?() } // delete
            else if event.keyCode == 53 { onEscape?() }
            else if let pad = GuildHallView.pads[event.keyCode] { // (the arrows and W A S D look round)
                cam.x += pad == "left" ? -2 : pad == "right" ? 2 : 0
                cam.y += pad == "up" ? -2 : pad == "down" ? 2 : 0
                clampCam()
                needsDisplay = true
            } else { super.keyDown(with: event) }
            return
        }
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

    // ⌘Z, ⇧⌘Z and ⌘A come from the 編輯 menu (AppDelegate) down the responder chain
    @objc func undo(_ sender: Any?) { if editing { onUndo?() } }
    @objc func redo(_ sender: Any?) { if editing { onRedo?() } }
    override func selectAll(_ sender: Any?) {
        guard editing, boxSelects else { return }
        selected = Set(decor.map(\.uid))
        onSelect?()
    }

    /// The pointer is followed while a piece is held, to show it where it would go.
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseMoved, .mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect], owner: self))
    }

    override func mouseMoved(with event: NSEvent) {
        hover = editing && stamp != nil ? tiles(at: convert(event.locationInWindow, from: nil)) : nil
    }

    override func mouseExited(with event: NSEvent) { hover = nil }

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
        let from = autoPose(m, Date()).map { HallPoint(x: $0.x, y: $0.y) } ?? hallFreeSpot(layout, [me, "start"])
        let at = hallWalkable(layout, from) ? from : standUp(from)
        mine = Mine(move: GuildMove(x: at.x, y: at.y, dir: "front", flip: false, anim: "idle"), since: Date())
        return true
    }

    /// Somewhere free to stand up to from a seat: beside it, else the first place a way out of it reaches.
    private func standUp(_ p: HallPoint) -> HallPoint {
        let spots = [-1.0, 1.0].flatMap { s in [HallPoint(x: p.x, y: p.y + s * 0.9), HallPoint(x: p.x + s * 0.9, y: p.y)] } + [HallPoint(x: p.x, y: p.y - 1.1)]
        return spots.first { hallWalkable(layout, $0) } ?? hallRoute(layout, from: p, to: HallPoint(x: p.x, y: p.y + 3)).first ?? p
    }

    private func act(_ anim: String, at: HallPoint? = nil) {
        guard var m = mine else { return }
        m.move = GuildMove(x: at?.x ?? m.move.x, y: at?.y ?? m.move.y, dir: "front", flip: false, anim: anim)
        m.since = Date()
        mine = m
    }

    func pressA() {
        guard take(), let m = mine else { return }
        let r = hallInteract(layout, HallPoint(x: m.move.x, y: m.move.y))
        act(r.anim, at: r.at)
    }

    func pressB() {
        if take() { act("cheer") }
    }

    /// Walks there round everything; a click on something to sit on (or its desk) walks up to it and sits.
    private func walk(to target: HallPoint) {
        guard take(), let m = mine else { return }
        thenSit = false
        var goal = target
        if !hallWalkable(layout, target) {
            let near = hallInteract(layout, target)
            guard near.anim == "sit" else { return }
            goal = near.at
            thenSit = true
        }
        // (the way ends with a step onto the seat, which is inside its piece: the walk stops short and sits from there)
        path = hallRoute(layout, from: HallPoint(x: m.move.x, y: m.move.y), to: goal)
        if thenSit { _ = path.popLast() }
        if thenSit && path.isEmpty {
            // (already beside it)
            thenSit = false
            let r = hallInteract(layout, HallPoint(x: m.move.x, y: m.move.y))
            act(r.anim, at: r.at)
        }
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
                    let r = hallInteract(layout, p)
                    act(r.anim, at: r.at)
                    return tell(now)
                }
            } else {
                dx = (next.x - p.x) / d
                dy = (next.y - p.y) / d
            }
        }
        if dx != 0 || dy != 0, !hallWalkable(layout, p) {
            // (sitting: stand up beside the seat first)
            let up = standUp(p)
            m.move = GuildMove(x: up.x, y: up.y, dir: "front", flip: false, anim: "walk")
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

extension GuildHallView: NSMenuItemValidation {
    /// 還原 and 重做 light up only while decorating with something to undo or redo (else they go on down the chain, to a text box).
    func validateMenuItem(_ item: NSMenuItem) -> Bool {
        switch item.action {
        case Selector(("undo:")): return editing && canUndo?().undo == true
        case Selector(("redo:")): return editing && canUndo?().redo == true
        case #selector(selectAll(_:)): return editing && boxSelects
        default: return true
        }
    }
}

extension HallLayout {
    /// Whether floor tile (x, y) has wall over it: it is floor and the tile above is not (shared/src/guild-decor.ts hallWallAt).
    func wallAt(_ x: Int, _ y: Int) -> Bool { floorAt(x, y) && !floorAt(x, y - 1) }
}
