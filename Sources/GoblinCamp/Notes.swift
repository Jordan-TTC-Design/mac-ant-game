import AppKit

/// One sticky note. Everything here is meant to be synced between the player's devices later, so each note has its own id,
/// the time it last changed and a deletion mark (a deleted note is kept as a tombstone, not wiped). Where it sits on the
/// screen is not part of it: that is kept per Mac (`NoteStore.frames`), since every Mac has different screens.
struct StickyNote: Codable, Equatable {
    var id: String = UUID().uuidString
    var text = ""
    /// Paper colour, one of `NotePaper.all`.
    var color = "yellow"
    /// The goblin that lives on the note (a breed id) and its name.
    var breed = "common"
    var goblinName = ""
    /// The target time: the goblin gets nervous as it comes near and holds its head once it has passed.
    var dueAt: Date?
    /// When the goblin jumps out to remind you.
    var remindAt: Date?
    /// The reminder has been shown (but nobody said 知道了 yet): the goblin on the note rings its bell until someone does.
    var remindFired = false
    var done = false
    var createdAt = Date()
    var updatedAt = Date()
    var deleted = false

    /// Whether the reminder should pop up now.
    func reminderDue(at now: Date) -> Bool { !deleted && !remindFired && (remindAt.map { $0 <= now } ?? false) }
    var ringing: Bool { !deleted && remindFired && remindAt != nil }
}

/// The paper colours: fill, the darker edge, and the ink.
struct NotePaper {
    let id: String
    let name: String
    let fill: NSColor
    let edge: NSColor

    static func rgb(_ r: Int, _ g: Int, _ b: Int) -> NSColor {
        NSColor(calibratedRed: CGFloat(r) / 255, green: CGFloat(g) / 255, blue: CGFloat(b) / 255, alpha: 1)
    }

    static let all: [NotePaper] = [
        NotePaper(id: "yellow", name: "黃色", fill: rgb(255, 234, 140), edge: rgb(214, 180, 72)),
        NotePaper(id: "pink", name: "粉紅", fill: rgb(255, 196, 214), edge: rgb(214, 134, 160)),
        NotePaper(id: "blue", name: "藍色", fill: rgb(190, 222, 255), edge: rgb(120, 162, 214)),
        NotePaper(id: "green", name: "綠色", fill: rgb(200, 240, 180), edge: rgb(132, 186, 112)),
        NotePaper(id: "purple", name: "紫色", fill: rgb(222, 206, 255), edge: rgb(160, 138, 214)),
    ]

    static func named(_ id: String) -> NotePaper { all.first { $0.id == id } ?? all[0] }
    static let ink = NSColor(calibratedWhite: 0.16, alpha: 1)
}

/// The notes and where they sit, in ~/Library/Application Support/GoblinCamp/notes.json.
final class NoteStore {
    struct Frame: Codable { var x, y, w, h: Double }
    private struct File: Codable {
        var version = 1
        var notes: [StickyNote] = []
        var frames: [String: Frame] = [:]
    }

    private(set) var notes: [StickyNote] = []
    private(set) var frames: [String: Frame] = [:]
    private let url: URL
    private let noDisk: Bool

    init() {
        let env = ProcessInfo.processInfo.environment
        let base = env["CAMP_DATA_DIR"].map { URL(fileURLWithPath: $0) }
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("GoblinCamp")
        url = base.appendingPathComponent("notes.json")
        noDisk = env["CAMP_NO_SAVE"] != nil && env["CAMP_DATA_DIR"] == nil // (a test's own data folder is written to, never the real one)
        guard !noDisk, let data = try? Data(contentsOf: url) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let file = try? decoder.decode(File.self, from: data) else {
            // keep the unreadable file aside instead of writing over it with an empty list
            NSLog("GoblinCamp: notes.json could not be read; kept aside as notes-unreadable-<time>.json")
            try? FileManager.default.moveItem(at: url, to: base.appendingPathComponent("notes-unreadable-\(Int(Date().timeIntervalSince1970)).json"))
            return
        }
        // tombstones are only needed until the notes can sync; a month is plenty
        let cutoff = Date().addingTimeInterval(-30 * 86400)
        notes = file.notes.filter { !$0.deleted || $0.updatedAt > cutoff }
        frames = file.frames
    }

    var live: [StickyNote] { notes.filter { !$0.deleted } }

    func note(_ id: String) -> StickyNote? { notes.first { $0.id == id } }

    /// Changes a note (and marks it changed). Nothing happens for a note that is not there.
    func update(_ id: String, _ body: (inout StickyNote) -> Void) {
        guard let i = notes.firstIndex(where: { $0.id == id }) else { return }
        var note = notes[i]
        body(&note)
        guard note != notes[i] else { return }
        note.updatedAt = Date()
        notes[i] = note
        save()
    }

    func add(_ note: StickyNote, frame: NSRect) {
        notes.append(note)
        setFrame(frame, for: note.id)
    }

    func delete(_ id: String) {
        update(id) {
            $0.deleted = true
            $0.text = "" // what was written goes; the tombstone only has to say that it was deleted
        }
        frames[id] = nil
        save()
    }

    func frame(for id: String) -> NSRect? {
        frames[id].map { NSRect(x: $0.x, y: $0.y, width: $0.w, height: $0.h) }
    }

    func setFrame(_ rect: NSRect, for id: String) {
        frames[id] = Frame(x: Double(rect.minX), y: Double(rect.minY), w: Double(rect.width), h: Double(rect.height))
        save()
    }

    private func save() {
        guard !noDisk else { return }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try encoder.encode(File(notes: notes, frames: frames)).write(to: url, options: .atomic)
        } catch {
            NSLog("GoblinCamp: saving notes failed: \(error)")
        }
    }
}

/// How times read on a note: 今天 15:30, 明天 09:00, 10/3 18:00.
enum NoteTime {
    static func text(_ date: Date, now: Date = Date()) -> String {
        let calendar = Calendar.current
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        let time = f.string(from: date)
        if calendar.isDate(date, inSameDayAs: now) { return "今天 \(time)" }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now), calendar.isDate(date, inSameDayAs: tomorrow) { return "明天 \(time)" }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now), calendar.isDate(date, inSameDayAs: yesterday) { return "昨天 \(time)" }
        f.dateFormat = "M/d HH:mm"
        return f.string(from: date)
    }

    /// `hour` o'clock `days` days from today.
    static func at(hour: Int, days: Int = 0, from now: Date = Date()) -> Date {
        let calendar = Calendar.current
        let day = calendar.date(byAdding: .day, value: days, to: now) ?? now
        return calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day) ?? day
    }

    /// 18:00 on the coming Friday (today if it is Friday before six).
    static func fridayEvening(from now: Date = Date()) -> Date {
        let weekday = Calendar.current.component(.weekday, from: now) // Sunday = 1 … Friday = 6
        var days = (6 - weekday + 7) % 7
        if days == 0, now >= at(hour: 18, from: now) { days = 7 }
        return at(hour: 18, days: days, from: now)
    }
}

// MARK: The goblin on the note

/// What the goblin on a note is up to. Its mood follows the note (done, ringing, late, soon); when there is nothing
/// pressing it idles through a few small things of its own.
enum NoteGoblinMood: Equatable {
    case idle, soon, late, ringing, done, frozen
}

struct NoteGoblin {
    enum Idle { case stand, walk, sleep, peek, doodle }

    var idle: Idle = .stand
    var clock = 0.0
    var idleLength = 4.0
    /// Where it stands along the bottom of the note, 0 (left) to 1.
    var x = 0.0
    var walkTarget = 0.0
    var legPhase = 0.0

    mutating func step(_ dt: Double, mood: NoteGoblinMood) {
        clock += dt
        guard mood == .idle else { return }
        if clock >= idleLength { pickIdle() }
        if idle == .walk {
            let speed = 0.12 * dt
            if abs(walkTarget - x) <= speed { x = walkTarget; idle = .stand; clock = 0; idleLength = Double.random(in: 2...5) }
            else { x += walkTarget > x ? speed : -speed }
            legPhase += dt * 6
        }
    }

    private mutating func pickIdle() {
        clock = 0
        let roll = Double.random(in: 0..<1)
        switch roll {
        case ..<0.35:
            idle = .walk
            walkTarget = Double.random(in: 0...1)
            idleLength = 30
        case ..<0.55:
            idle = .doodle
            idleLength = Double.random(in: 4...8)
        case ..<0.7:
            idle = .peek
            idleLength = 3.2
        case ..<0.85:
            idle = .sleep
            idleLength = Double.random(in: 8...16)
        default:
            idle = .stand
            idleLength = Double.random(in: 3...6)
        }
    }
}

// MARK: The note's view

/// The paper itself: tape, the words, the times, the goblin, a ⋯ button and a corner to resize by.
/// Drags anywhere on the paper move the note; a double-click writes on it; a right-click (or ⋯) opens its menu.
final class NoteView: NSView {
    var note: StickyNote { didSet { needsDisplay = true } }
    var goblin = NoteGoblin()
    var mood: NoteGoblinMood = .idle
    /// Set by the controller; the view asks it for the menu and reports what the player did.
    weak var controller: NoteController?
    private var dragStart: (mouse: NSPoint, frame: NSRect, resizing: Bool)?
    private(set) var editor: NSTextView?

    static let header: CGFloat = 22
    static let footer: CGFloat = 54
    static let minSize = NSSize(width: 160, height: 140)
    static let maxSize = NSSize(width: 460, height: 460)
    static let defaultSize = NSSize(width: 210, height: 180)

    init(note: StickyNote, frame: NSRect) {
        self.note = note
        super.init(frame: frame)
        goblin.x = Double.random(in: 0.05...0.4)
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override var isFlipped: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    private var paper: NotePaper { NotePaper.named(note.color) }
    private var sheet: NSRect { bounds.insetBy(dx: 4, dy: 4) } // room for the shadow
    private var menuButton: NSRect { NSRect(x: sheet.maxX - 26, y: sheet.maxY - 22, width: 22, height: 18) }
    private var grip: NSRect { NSRect(x: sheet.maxX - 16, y: sheet.minY, width: 16, height: 16) }
    var textRect: NSRect {
        NSRect(x: sheet.minX + 10, y: sheet.minY + NoteView.footer, width: sheet.width - 20, height: sheet.height - NoteView.header - NoteView.footer)
    }

    // MARK: Drawing

    override func draw(_ dirtyRect: NSRect) {
        let paper = self.paper
        // a pixel shadow, the sheet with a darker edge, and a folded corner
        NSColor(calibratedWhite: 0, alpha: 0.18).setFill()
        NSRect(x: sheet.minX + 3, y: sheet.minY - 3, width: sheet.width, height: sheet.height).fill()
        paper.edge.setFill()
        sheet.fill()
        paper.fill.setFill()
        sheet.insetBy(dx: 2, dy: 2).fill()
        // the tape
        NSColor(calibratedWhite: 1, alpha: 0.55).setFill()
        let tape = NSRect(x: sheet.midX - 26, y: sheet.maxY - 9, width: 52, height: 14)
        tape.fill()
        NSColor(calibratedWhite: 0.6, alpha: 0.25).setFill()
        NSRect(x: tape.minX, y: tape.minY, width: tape.width, height: 1).fill()
        // ⋯
        let dots = NSColor(calibratedWhite: 0, alpha: 0.35)
        dots.setFill()
        for i in 0..<3 { NSRect(x: menuButton.midX - 7 + CGFloat(i) * 6, y: menuButton.midY - 1, width: 3, height: 3).fill() }
        // the corner you pull
        paper.edge.setFill()
        for i in 0..<3 { NSRect(x: grip.maxX - 5 - CGFloat(i) * 4, y: grip.minY + 3, width: 2, height: 2 + CGFloat(i) * 4).fill() }

        if editor == nil { drawText() }
        drawTimes()
        drawGoblin()
    }

    private func drawText() {
        let rect = textRect
        if note.text.isEmpty {
            let hint = NSAttributedString(string: "雙擊寫點什麼…", attributes: [
                .font: NSFont.systemFont(ofSize: 13), .foregroundColor: NSColor(calibratedWhite: 0, alpha: 0.3)])
            hint.draw(with: rect, options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine])
            return
        }
        let style = NSMutableParagraphStyle()
        style.lineBreakMode = .byWordWrapping
        var attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 13, weight: .medium), .foregroundColor: NotePaper.ink, .paragraphStyle: style]
        if note.done {
            attrs[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
            attrs[.foregroundColor] = NSColor(calibratedWhite: 0.16, alpha: 0.5)
        }
        NSAttributedString(string: note.text, attributes: attrs).draw(with: rect, options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine])
    }

    /// 截止 and 提醒, at the bottom right beside the goblin.
    private func drawTimes() {
        var lines: [(String, NSColor)] = []
        let now = Date()
        if let due = note.dueAt {
            let late = due < now && !note.done
            lines.append(("截止 " + NoteTime.text(due, now: now), late ? NSColor(calibratedRed: 0.78, green: 0.15, blue: 0.12, alpha: 1) : NSColor(calibratedWhite: 0.25, alpha: 1)))
        }
        if let remind = note.remindAt {
            lines.append(((note.ringing ? "提醒 響了！" : "提醒 ") + (note.ringing ? "" : NoteTime.text(remind, now: now)),
                          note.ringing ? NSColor(calibratedRed: 0.85, green: 0.45, blue: 0.05, alpha: 1) : NSColor(calibratedWhite: 0.25, alpha: 1)))
        }
        if note.done { lines = [("完成了！", NSColor(calibratedRed: 0.2, green: 0.55, blue: 0.25, alpha: 1))] }
        var y = sheet.minY + 8
        for (text, color) in lines.reversed() {
            let s = NSAttributedString(string: text, attributes: [.font: NSFont.systemFont(ofSize: 10.5, weight: .semibold), .foregroundColor: color])
            let w = s.size().width
            s.draw(at: NSPoint(x: sheet.maxX - 18 - w, y: y))
            y += 14
        }
    }

    private var goblinRole: SpriteRole? {
        let character = Characters.current
        return character.breeds[character.breedIndex(id: note.breed)].sprites
    }

    private func drawGoblin() {
        guard let role = goblinRole, let ctx = NSGraphicsContext.current?.cgContext else { return }
        let pixel: CGFloat = 2.5
        let size = CGFloat(role.frameSize) * pixel
        let t = goblin.clock
        let lane = max(0, sheet.width * 0.5 - size) // it keeps to the left half; the times are on the right
        var p = CGPoint(x: sheet.minX + 8 + size / 2 + lane * CGFloat(goblin.x), y: sheet.minY + 8)
        var direction = SpriteDirection.down
        var phase = 0.0
        var rotate: CGFloat = 0
        var clip: CGFloat? = nil
        func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ c: NSColor) { c.setFill(); NSRect(x: x, y: y, width: w, height: h).fill() }

        switch mood {
        case .frozen:
            rotate = .pi / 2 // asleep while the app is quiet
        case .done:
            p.y += abs(CGFloat(sin(t * 6))) * 6
        case .ringing:
            p.y += abs(CGFloat(sin(t * 12))) * 5
            direction = Int(t * 6) % 2 == 0 ? .left : .right
        case .late:
            p.x += CGFloat(sin(t * 30)) * 1.5 // trembling
            direction = Int(t * 3) % 2 == 0 ? .left : .right
        case .soon:
            direction = Int(t * 1.5) % 2 == 0 ? .left : .right
            p.y += Int(t * 4) % 4 == 0 ? 2 : 0 // tapping its foot
        case .idle:
            switch goblin.idle {
            case .stand: direction = Int(t / 2.5) % 3 == 1 ? .left : (Int(t / 2.5) % 3 == 2 ? .right : .down)
            case .walk:
                direction = goblin.walkTarget > goblin.x ? .right : .left
                phase = goblin.legPhase
            case .sleep: rotate = .pi / 2
            case .peek: // ducks below the edge of the paper and pops back up
                let k = min(1, max(0, abs(t - 1.6) - 0.4)) // 0 hidden … 1 up
                clip = size * (0.25 + 0.75 * CGFloat(k))
                p.y -= size * (1 - (0.25 + 0.75 * CGFloat(k)))
            case .doodle: direction = .up
            }
        }

        ctx.saveGState()
        ctx.interpolationQuality = .none
        NSColor(calibratedWhite: 0, alpha: 0.12).setFill()
        if rotate == 0, clip == nil { NSBezierPath(ovalIn: NSRect(x: p.x - size * 0.28, y: sheet.minY + 5, width: size * 0.56, height: 6)).fill() }
        if let clip { ctx.clip(to: CGRect(x: p.x - size, y: sheet.minY + 3, width: size * 2, height: clip + 4)) }
        if rotate != 0, let image = role.image(direction: .down, phase: 0) {
            ctx.translateBy(x: p.x, y: p.y + size * 0.2)
            ctx.rotate(by: rotate)
            ctx.draw(image, in: CGRect(x: -size / 2, y: -size / 2, width: size, height: size))
        } else if let image = role.image(direction: direction, phase: phase) {
            ctx.draw(image, in: CGRect(x: p.x - size / 2, y: p.y - size * 0.2, width: size, height: size))
        }
        ctx.restoreGState()

        let head = CGPoint(x: p.x, y: p.y + size * 0.75)
        switch mood {
        case .frozen:
            drawZ(near: CGPoint(x: p.x + size * 0.3, y: p.y + size * 0.35), t: 0)
        case .done: // sparkles
            for (i, dx) in [-0.45, 0.45].enumerated() where Int(t * 4 + Double(i)) % 2 == 0 {
                let c = NSColor(calibratedRed: 1, green: 0.85, blue: 0.2, alpha: 1)
                let x = p.x + size * CGFloat(dx), y = head.y + 2
                rect(x - 1, y - 3, 2, 8, c); rect(x - 4, y, 8, 2, c)
            }
        case .ringing: // a bell held up, and lines to say it is loud
            let bx = head.x + size * 0.1, by = head.y + 10 + CGFloat(sin(t * 20)) * 1.5
            let gold = NSColor(calibratedRed: 0.95, green: 0.72, blue: 0.1, alpha: 1)
            rect(bx - 5, by, 10, 7, gold); rect(bx - 7, by, 14, 2, gold); rect(bx - 1, by + 7, 2, 2, gold)
            rect(bx - 1, by - 3, 2, 2, NSColor(calibratedRed: 0.55, green: 0.35, blue: 0.1, alpha: 1))
            let lines = NSColor(calibratedRed: 0.85, green: 0.45, blue: 0.05, alpha: 1)
            if Int(t * 6) % 2 == 0 { rect(bx - 12, by + 4, 3, 2, lines); rect(bx + 9, by + 4, 3, 2, lines); rect(bx - 11, by + 8, 2, 2, lines); rect(bx + 9, by + 8, 2, 2, lines) }
        case .late: // "!!" and a drop of sweat
            let red = NSColor(calibratedRed: 0.85, green: 0.15, blue: 0.12, alpha: 1)
            for dx: CGFloat in [-3, 3] { rect(head.x + dx - 1, head.y + 6, 2.5, 7, red); rect(head.x + dx - 1, head.y + 2, 2.5, 2.5, red) }
            let drop = CGFloat((t * 1.2).truncatingRemainder(dividingBy: 1))
            rect(p.x + size * 0.32, head.y - 4 - drop * 10, 3, 4, NSColor(calibratedRed: 0.5, green: 0.75, blue: 1, alpha: 1 - drop))
        case .soon: // a "!" that blinks
            if Int(t * 2) % 2 == 0 {
                let amber = NSColor(calibratedRed: 0.9, green: 0.55, blue: 0.05, alpha: 1)
                rect(head.x - 1, head.y + 6, 2.5, 7, amber); rect(head.x - 1, head.y + 2, 2.5, 2.5, amber)
            }
        case .idle:
            switch goblin.idle {
            case .sleep: drawZ(near: CGPoint(x: p.x + size * 0.3, y: p.y + size * 0.35), t: t)
            case .doodle: // a pencil going, and scribbles appearing on the paper beside it
                let pen = CGPoint(x: p.x + size * 0.35 + CGFloat(sin(t * 9)) * 3, y: p.y + size * 0.45)
                rect(pen.x, pen.y, 2, 7, NSColor(calibratedRed: 0.95, green: 0.7, blue: 0.2, alpha: 1))
                rect(pen.x, pen.y - 2, 2, 2, NSColor(calibratedWhite: 0.25, alpha: 1))
                let marks = min(6, Int(t * 1.5))
                for i in 0..<marks {
                    let mx = p.x + size * 0.55 + CGFloat(i % 3) * 5, my = p.y + size * 0.2 + CGFloat(i / 3) * 5
                    rect(mx, my, 4, 1.5, NSColor(calibratedWhite: 0.3, alpha: 0.55))
                }
            default: break
            }
        }
    }

    private func drawZ(near p: CGPoint, t: Double) {
        let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 10, weight: .heavy), .foregroundColor: NSColor(calibratedWhite: 0.3, alpha: 0.7)]
        let rise = CGFloat((t * 0.6).truncatingRemainder(dividingBy: 1)) * 8
        NSAttributedString(string: "z", attributes: attrs).draw(at: NSPoint(x: p.x, y: p.y + rise))
        NSAttributedString(string: "Z", attributes: attrs).draw(at: NSPoint(x: p.x + 6, y: p.y + 8 + rise))
    }

    // MARK: Mouse

    override func resetCursorRects() {
        addCursorRect(grip, cursor: .crosshair)
        addCursorRect(menuButton, cursor: .pointingHand)
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if menuButton.contains(point) { return showMenu(event) }
        if event.clickCount == 2 { return beginEditing() }
        if let window { dragStart = (NSEvent.mouseLocation, window.frame, grip.contains(point)) }
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start = dragStart, let window else { return }
        let now = NSEvent.mouseLocation
        let dx = now.x - start.mouse.x, dy = now.y - start.mouse.y
        if start.resizing { // the grip is bottom right: the top left stays where it is
            let w = min(NoteView.maxSize.width, max(NoteView.minSize.width, start.frame.width + dx))
            let h = min(NoteView.maxSize.height, max(NoteView.minSize.height, start.frame.height - dy))
            window.setFrame(NSRect(x: start.frame.minX, y: start.frame.maxY - h, width: w, height: h), display: true)
        } else {
            window.setFrameOrigin(NSPoint(x: start.frame.minX + dx, y: start.frame.minY + dy))
        }
    }

    override func mouseUp(with event: NSEvent) {
        guard let start = dragStart, let window else { return }
        dragStart = nil
        if window.frame != start.frame { controller?.moved(self, to: window.frame) }
        else if event.clickCount == 1 { controller?.clicked(self) }
    }

    override func rightMouseDown(with event: NSEvent) { showMenu(event) }

    private func showMenu(_ event: NSEvent) {
        guard let menu = controller?.menu(for: self) else { return }
        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }

    // MARK: Writing

    func beginEditing() {
        guard editor == nil, let window else { return }
        let scroll = NSScrollView(frame: textRect)
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = false
        scroll.borderType = .noBorder
        let text = NSTextView(frame: NSRect(origin: .zero, size: textRect.size))
        text.drawsBackground = false
        text.isRichText = false
        text.allowsUndo = true
        text.font = .systemFont(ofSize: 13, weight: .medium)
        text.textColor = NotePaper.ink
        text.insertionPointColor = NotePaper.ink
        text.textContainerInset = .zero
        text.textContainer?.lineFragmentPadding = 0
        text.textContainer?.widthTracksTextView = true
        text.isVerticallyResizable = true
        text.autoresizingMask = [.width]
        text.string = note.text
        text.delegate = controller
        scroll.documentView = text
        scroll.autoresizingMask = [.width, .height]
        addSubview(scroll)
        editor = text
        needsDisplay = true
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(text)
        text.setSelectedRange(NSRange(location: (text.string as NSString).length, length: 0))
    }

    /// Stops writing and hands back what was written (nil if it was not being written on).
    @discardableResult
    func endEditing() -> String? {
        guard let text = editor else { return nil }
        let written = text.string
        text.enclosingScrollView?.removeFromSuperview()
        editor = nil
        needsDisplay = true
        return written
    }
}

// MARK: The note's window

/// A window at the desktop's level: over the wallpaper and its icons, under every ordinary window, and on every desktop.
final class NoteWindow: NSPanel {
    static let desktopLevel = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)

    init(frame: NSRect) {
        super.init(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = NoteWindow.desktopLevel
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        becomesKeyOnlyIfNeeded = true
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

// MARK: The controller

/// Keeps a window per note, animates the goblins, and watches for reminders.
final class NoteController: NSObject, NSTextViewDelegate, NSWindowDelegate {
    let store = NoteStore()
    private var windows: [String: NoteWindow] = [:]
    private var timer: Timer?
    private var lastTick = Date()
    /// Called when a note's reminder is due. Returns whether it could be shown (the app is not in focus mode, there is room).
    var onReminder: ((StickyNote) -> Bool)?
    /// The goblins sleep while the app is in focus or energy-saving mode.
    var frozen = false {
        didSet {
            guard frozen != oldValue else { return }
            for view in views {
                view.mood = frozen ? .frozen : .idle // (the real mood comes with the next tick)
                view.needsDisplay = true
            }
        }
    }
    /// The notes have been called above the other windows (⌃⌥M) and go back down when another app is used.
    private(set) var raised = false
    private var activationObserver: Any?

    var count: Int { store.live.count }
    private var views: [NoteView] { windows.values.compactMap { $0.contentView as? NoteView } }

    func start() {
        for note in store.live { open(note) }
        if ProcessInfo.processInfo.environment["CAMP_DEBUG"] != nil { NSLog("GoblinCamp: notes: \(windows.count) opened") }
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 8, repeats: true) { [weak self] _ in self?.tick() }
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            if app?.processIdentifier != ProcessInfo.processInfo.processIdentifier { self?.setRaised(false) }
        }
    }

    // MARK: Notes

    /// A new note in the middle of the screen under the mouse, ready to write on.
    @discardableResult
    func newNote(text: String = "", at origin: NSPoint? = nil, edit: Bool = true) -> StickyNote {
        var note = StickyNote()
        note.text = text
        note.color = NotePaper.all[store.live.count % NotePaper.all.count].id
        note.breed = NoteController.randomBreed()
        note.goblinName = Names.goblin(seed: UInt64.random(in: 1...UInt64.max))
        let screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main ?? NSScreen.screens[0]
        let size = NoteView.defaultSize
        let spread = CGFloat(store.live.count % 6) * 24 // new notes step down a little so they do not land exactly on each other
        let o = origin ?? NSPoint(x: screen.visibleFrame.midX - size.width / 2 + spread, y: screen.visibleFrame.midY - size.height / 2 - spread)
        store.add(note, frame: NSRect(origin: o, size: size))
        open(note)
        if edit { (windows[note.id]?.contentView as? NoteView)?.beginEditing() }
        return note
    }

    /// Plain goblins mostly, now and then a rarer one.
    private static func randomBreed() -> String {
        let roll = Double.random(in: 0..<1)
        switch roll {
        case ..<0.55: return "common"
        case ..<0.7: return "scout"
        case ..<0.85: return "brute"
        case ..<0.96: return "sage"
        default: return "golden"
        }
    }

    private func open(_ note: StickyNote) {
        var frame = store.frame(for: note.id) ?? NSRect(origin: NSPoint(x: 200, y: 200), size: NoteView.defaultSize)
        // a screen that is gone (unplugged): bring the note back where it can be seen
        if !NSScreen.screens.contains(where: { $0.visibleFrame.intersects(frame.insetBy(dx: 30, dy: 30)) }), let main = NSScreen.screens.first {
            frame.origin = NSPoint(x: main.visibleFrame.midX - frame.width / 2, y: main.visibleFrame.midY - frame.height / 2)
        }
        let window = NoteWindow(frame: frame)
        let view = NoteView(note: note, frame: NSRect(origin: .zero, size: frame.size))
        view.autoresizingMask = [.width, .height]
        view.controller = self
        view.mood = mood(of: note, now: Date())
        window.contentView = view
        window.delegate = self
        if raised { window.level = Levels.panel }
        window.orderFrontRegardless()
        windows[note.id] = window
    }

    func view(_ id: String) -> NoteView? { windows[id]?.contentView as? NoteView }

    func change(_ id: String, _ body: (inout StickyNote) -> Void) {
        store.update(id, body)
        if let note = store.note(id) { view(id)?.note = note }
    }

    func delete(_ id: String) {
        view(id)?.endEditing()
        windows[id]?.orderOut(nil)
        windows[id] = nil
        store.delete(id)
    }

    /// 知道了: the reminder is over.
    func acknowledge(_ id: String) {
        change(id) { $0.remindAt = nil; $0.remindFired = false }
    }

    /// 再等一下: the reminder comes back at `date`.
    func snooze(_ id: String, until date: Date) {
        change(id) { $0.remindAt = date; $0.remindFired = false }
    }

    /// Every note to the screen under the mouse, fanned out (for when they got lost behind a screen that changed).
    func gather() {
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) }) ?? NSScreen.screens.first else { return }
        let area = screen.visibleFrame
        for (i, note) in store.live.enumerated() {
            guard let window = windows[note.id] else { continue }
            let size = window.frame.size
            let origin = NSPoint(x: area.minX + 40 + CGFloat(i % 5) * (size.width * 0.6), y: area.maxY - size.height - 40 - CGFloat(i / 5 % 4) * 60)
            window.setFrameOrigin(origin)
            store.setFrame(window.frame, for: note.id)
        }
        setRaised(true)
    }

    /// ⌃⌥M: every note above the other windows, and back down again.
    func setRaised(_ on: Bool) {
        guard on != raised else { return }
        raised = on
        for window in windows.values {
            window.level = on ? Levels.panel : NoteWindow.desktopLevel
            window.orderFrontRegardless()
        }
    }

    // MARK: Ticking

    private func mood(of note: StickyNote, now: Date) -> NoteGoblinMood {
        if frozen { return .frozen }
        if note.done { return .done }
        if note.ringing { return .ringing }
        if let due = note.dueAt {
            if due < now { return .late }
            if due.timeIntervalSince(now) < 3600 { return .soon }
        }
        return .idle
    }

    private var lastReminderCheck = Date.distantPast

    private func tick() {
        let now = Date()
        let dt = min(0.5, now.timeIntervalSince(lastTick))
        lastTick = now
        if now.timeIntervalSince(lastReminderCheck) >= 2 { checkReminders() }
        guard !frozen else { return }
        for (id, window) in windows {
            guard let view = window.contentView as? NoteView, let note = store.note(id) else { continue }
            view.mood = mood(of: note, now: now)
            guard window.occlusionState.contains(.visible) else { continue } // covered by windows: no need to animate it
            view.goblin.step(dt, mood: view.mood)
            view.needsDisplay = true
        }
    }

    /// Hands every reminder that is due to the app (which shows it unless it is in focus mode; then it stays due and is tried again).
    func checkReminders() {
        lastReminderCheck = Date()
        for note in store.live where note.reminderDue(at: lastReminderCheck) {
            if onReminder?(note) == true { change(note.id) { $0.remindFired = true } }
        }
    }

    // MARK: From the views

    fileprivate func moved(_ view: NoteView, to frame: NSRect) { store.setFrame(frame, for: view.note.id) }

    /// A plain click on a ringing note stops the bell.
    fileprivate func clicked(_ view: NoteView) {
        if view.note.ringing { acknowledge(view.note.id) }
    }

    fileprivate func menu(for view: NoteView) -> NSMenu {
        let id = view.note.id
        let note = view.note
        let menu = NSMenu()
        func item(_ title: String, _ action: @escaping () -> Void) -> ClosureMenuItem {
            let i = ClosureMenuItem(title: title, handler: action)
            menu.addItem(i)
            return i
        }
        func sub(_ title: String, _ build: (NSMenu) -> Void) {
            let parent = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            let m = NSMenu(title: title)
            build(m)
            parent.submenu = m
            menu.addItem(parent)
        }
        func add(_ m: NSMenu, _ title: String, _ action: @escaping () -> Void) { m.addItem(ClosureMenuItem(title: title, handler: action)) }

        if !note.goblinName.isEmpty {
            let who = NSMenuItem(title: "住著：\(note.goblinName)（\(Characters.current.breeds[Characters.current.breedIndex(id: note.breed)].name)哥布林）", action: nil, keyEquivalent: "")
            who.isEnabled = false
            menu.addItem(who)
            menu.addItem(.separator())
        }
        if note.ringing { _ = item("知道了（停止提醒）") { [weak self] in self?.acknowledge(id) } }
        _ = item("編輯文字") { [weak view] in view?.beginEditing() }
        _ = item(note.done ? "標成還沒完成" : "標成完成") { [weak self] in self?.change(id) { $0.done.toggle() } }
        menu.addItem(.separator())
        sub("提醒時間" + (note.remindAt.map { "：" + NoteTime.text($0) } ?? "")) { m in
            add(m, "30 分鐘後") { [weak self] in self?.snooze(id, until: Date().addingTimeInterval(1800)) }
            add(m, "1 小時後") { [weak self] in self?.snooze(id, until: Date().addingTimeInterval(3600)) }
            add(m, "今天下午 5 點") { [weak self] in self?.snooze(id, until: NoteTime.at(hour: 17)) }
            add(m, "明天早上 9 點") { [weak self] in self?.snooze(id, until: NoteTime.at(hour: 9, days: 1)) }
            add(m, "自訂…") { [weak self] in self?.pickTime(for: id, reminder: true) }
            if note.remindAt != nil {
                m.addItem(.separator())
                add(m, "取消提醒") { [weak self] in self?.acknowledge(id) }
            }
        }
        sub("目標時間" + (note.dueAt.map { "：" + NoteTime.text($0) } ?? "")) { m in
            add(m, "今天下班前（18:00）") { [weak self] in self?.change(id) { $0.dueAt = NoteTime.at(hour: 18) } }
            add(m, "明天下班前（18:00）") { [weak self] in self?.change(id) { $0.dueAt = NoteTime.at(hour: 18, days: 1) } }
            add(m, "這週五下班前") { [weak self] in self?.change(id) { $0.dueAt = NoteTime.fridayEvening() } }
            add(m, "自訂…") { [weak self] in self?.pickTime(for: id, reminder: false) }
            if note.dueAt != nil {
                m.addItem(.separator())
                add(m, "取消目標時間") { [weak self] in self?.change(id) { $0.dueAt = nil } }
            }
        }
        sub("紙的顏色") { m in
            for paper in NotePaper.all {
                let i = ClosureMenuItem(title: paper.name) { [weak self] in self?.change(id) { $0.color = paper.id } }
                i.state = paper.id == note.color ? .on : .off
                m.addItem(i)
            }
        }
        menu.addItem(.separator())
        _ = item("刪除便利貼") { [weak self] in self?.confirmDelete(id) }
        return menu
    }

    /// A date and time picker for the reminder or the target time.
    private func pickTime(for id: String, reminder: Bool) {
        guard let note = store.note(id) else { return }
        let alert = NSAlert()
        alert.messageText = reminder ? "什麼時候提醒你？" : "目標時間是什麼時候？"
        alert.informativeText = reminder ? "時間到了，哥布林會從便利貼跳出來叫你（專注模式時會等你回來）。" : "越接近，便利貼上的哥布林會越緊張。"
        let picker = NSDatePicker(frame: NSRect(x: 0, y: 0, width: 220, height: 28))
        picker.datePickerStyle = .textFieldAndStepper
        picker.datePickerElements = [.yearMonthDay, .hourMinute]
        picker.minDate = reminder ? Date() : nil
        picker.dateValue = (reminder ? note.remindAt : note.dueAt) ?? Date().addingTimeInterval(3600)
        alert.accessoryView = picker
        alert.addButton(withTitle: "設定")
        alert.addButton(withTitle: "取消")
        guard alert.runInFront() == .alertFirstButtonReturn else { return }
        let date = picker.dateValue
        if reminder { snooze(id, until: date) } else { change(id) { $0.dueAt = date } }
    }

    private func confirmDelete(_ id: String) {
        guard let note = store.note(id) else { return }
        if !note.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let alert = NSAlert()
            alert.messageText = "刪除這張便利貼？"
            alert.informativeText = String(note.text.prefix(80))
            alert.addButton(withTitle: "刪除")
            alert.addButton(withTitle: "取消")
            guard alert.runInFront() == .alertFirstButtonReturn else { return }
        }
        delete(id)
    }

    // MARK: Writing (NSTextViewDelegate, NSWindowDelegate)

    /// Esc stops writing.
    func textView(_ textView: NSTextView, doCommandBy selector: Selector) -> Bool {
        guard selector == #selector(NSResponder.cancelOperation(_:)) else { return false }
        textView.window?.makeFirstResponder(nil)
        if let window = textView.window { finishWriting(in: window) }
        return true
    }

    func windowDidResignKey(_ notification: Notification) {
        guard let window = notification.object as? NoteWindow else { return }
        finishWriting(in: window)
    }

    private func finishWriting(in window: NSWindow) {
        guard let view = window.contentView as? NoteView, let text = view.endEditing() else { return }
        change(view.note.id) { $0.text = text.trimmingCharacters(in: .whitespacesAndNewlines) == "" ? "" : text }
    }

    func windowDidResize(_ notification: Notification) {
        guard let window = notification.object as? NoteWindow, let view = window.contentView as? NoteView else { return }
        view.editor?.enclosingScrollView?.frame = view.textRect
    }
}
