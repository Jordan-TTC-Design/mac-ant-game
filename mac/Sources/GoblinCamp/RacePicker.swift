import AppKit

/// "Pick a race": one card per race, each with its plain resident and its princess walking on the spot, a line on what they are like
/// and a few points on how they play. Shown on the very first launch and when a new world is started (see RACES.md). A race still
/// being made is shown greyed out.
final class RacePicker: NSObject, NSWindowDelegate {
    private let window: NSPanel
    private var onPick: ((Character) -> Void)?
    private var picked = false
    private var timer: Timer?
    private var sprites: [SpriteCell] = []
    private static var current: RacePicker?

    /// Races that are planned but not playable yet: shown greyed out so it is clear more are coming.
    private static let coming: [(name: String, tagline: String)] = [("死靈", "不吃東西、不會老死；魂塔收集魂魄、骨頭長出同伴。製作中。")]

    static func show(current id: String?, onPick: @escaping (Character) -> Void) {
        Self.current?.close()
        let picker = RacePicker(current: id, onPick: onPick)
        Self.current = picker
        NSApp.activate(ignoringOtherApps: true)
        picker.window.center()
        picker.window.makeKeyAndOrderFront(nil)
    }

    private init(current id: String?, onPick: @escaping (Character) -> Void) {
        self.onPick = onPick
        // the goblins first (the race everyone knows), then the others as they were found
        let races = Characters.all.filter { $0.id != "none" }.sorted { ($0.id == "goblin" ? 0 : 1) < ($1.id == "goblin" ? 0 : 1) }
        let cardW: CGFloat = 240, cardH: CGFloat = 420, gap: CGFloat = 14
        let count = CGFloat(races.count + Self.coming.count)
        let size = NSSize(width: count * cardW + (count + 1) * gap, height: cardH + 70)
        window = NSPanel(contentRect: NSRect(origin: .zero, size: size), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        super.init()
        window.title = "選擇種族"
        window.level = Levels.dialog
        window.isReleasedWhenClosed = false
        window.hidesOnDeactivate = false // (a panel would vanish as soon as another app is clicked, leaving no way to pick)
        window.delegate = self
        let content = NSView(frame: NSRect(origin: .zero, size: size))
        let header = NSTextField(labelWithString: id == nil ? "你想從哪個種族開始？（開新世界時可以再換）" : "新的世界要由哪個種族開始？")
        header.font = .boldSystemFont(ofSize: 15)
        header.frame = NSRect(x: gap, y: size.height - 42, width: size.width - 2 * gap, height: 24)
        content.addSubview(header)
        var x = gap
        for race in races {
            content.addSubview(card(race: race, current: race.id == id, frame: NSRect(x: x, y: gap, width: cardW, height: cardH)))
            x += cardW + gap
        }
        for coming in Self.coming {
            content.addSubview(comingCard(name: coming.name, tagline: coming.tagline, frame: NSRect(x: x, y: gap, width: cardW, height: cardH)))
            x += cardW + gap
        }
        window.contentView = content
        timer = Timer.scheduledTimer(withTimeInterval: 0.18, repeats: true) { [weak self] _ in
            self?.sprites.forEach { $0.step() }
        }
    }

    private func box(_ frame: NSRect, dim: Bool = false) -> NSView {
        let view = NSView(frame: frame)
        view.wantsLayer = true
        view.layer?.cornerRadius = 10
        view.layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(dim ? 0.4 : 1).cgColor
        view.layer?.borderWidth = 1
        view.layer?.borderColor = NSColor.separatorColor.cgColor
        return view
    }

    private func label(_ text: String, size: CGFloat, bold: Bool = false, color: NSColor = .labelColor, frame: NSRect) -> NSTextField {
        let field = NSTextField(wrappingLabelWithString: text)
        field.font = bold ? .boldSystemFont(ofSize: size) : .systemFont(ofSize: size)
        field.textColor = color
        field.frame = frame
        return field
    }

    private func card(race: Character, current: Bool, frame: NSRect) -> NSView {
        let view = box(frame)
        let w = frame.width
        let cell = SpriteCell(frame: NSRect(x: 10, y: frame.height - 118, width: w - 20, height: 104),
                              roles: [race.breeds.first?.sprites, race.queen].compactMap { $0 })
        sprites.append(cell)
        view.addSubview(cell)
        view.addSubview(label(race.name, size: 18, bold: true, frame: NSRect(x: 14, y: frame.height - 148, width: w - 28, height: 24)))
        view.addSubview(label(race.tagline, size: 12, color: .secondaryLabelColor, frame: NSRect(x: 14, y: frame.height - 196, width: w - 28, height: 46)))
        let points = race.features.map { "• " + $0 }.joined(separator: "\n")
        view.addSubview(label(points, size: 12, frame: NSRect(x: 14, y: 52, width: w - 28, height: frame.height - 252)))
        let button = NSButton(title: current ? "繼續用\(race.name)" : "選\(race.name)", target: self, action: #selector(choose(_:)))
        button.bezelStyle = .rounded
        button.identifier = NSUserInterfaceItemIdentifier(race.id)
        button.frame = NSRect(x: 14, y: 12, width: w - 28, height: 32)
        if current { button.keyEquivalent = "\r" }
        view.addSubview(button)
        return view
    }

    private func comingCard(name: String, tagline: String, frame: NSRect) -> NSView {
        let view = box(frame, dim: true)
        let w = frame.width
        view.addSubview(label(name, size: 18, bold: true, color: .tertiaryLabelColor, frame: NSRect(x: 14, y: frame.height - 148, width: w - 28, height: 24)))
        view.addSubview(label(tagline, size: 12, color: .tertiaryLabelColor, frame: NSRect(x: 14, y: frame.height - 210, width: w - 28, height: 60)))
        let button = NSButton(title: "製作中", target: nil, action: nil)
        button.bezelStyle = .rounded
        button.isEnabled = false
        button.frame = NSRect(x: 14, y: 12, width: w - 28, height: 32)
        view.addSubview(button)
        return view
    }

    /// Test aid: a picture of the open picker, and picking a race as if its button were pressed.
    static func testCapture(to path: String) -> Bool {
        guard let picker = current, let cg = CGWindowListCreateImage(.null, .optionIncludingWindow, CGWindowID(picker.window.windowNumber), [.boundsIgnoreFraming, .bestResolution]),
              let png = NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:]) else { return false }
        return (try? png.write(to: URL(fileURLWithPath: path))) != nil
    }

    static func testChoose(_ id: String) {
        guard let picker = current else { return }
        let button = NSButton()
        button.identifier = NSUserInterfaceItemIdentifier(id)
        picker.choose(button)
    }

    @objc private func choose(_ sender: NSButton) {
        guard let id = sender.identifier?.rawValue, let race = Characters.all.first(where: { $0.id == id }) else { return }
        picked = true
        let pick = onPick
        close()
        pick?(race)
    }

    private func close() {
        timer?.invalidate()
        timer = nil
        onPick = nil
        window.orderOut(nil)
        if Self.current === self { Self.current = nil }
    }

    func windowWillClose(_ notification: Notification) {
        timer?.invalidate()
        timer = nil
        if Self.current === self { Self.current = nil }
    }
}

/// A resident and a princess walking toward the viewer, drawn big and crisp.
private final class SpriteCell: NSView {
    private let roles: [SpriteRole]
    private var phase = 0.0

    init(frame: NSRect, roles: [SpriteRole]) {
        self.roles = roles
        super.init(frame: frame)
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    func step() {
        phase += 1
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext, !roles.isEmpty else { return }
        ctx.interpolationQuality = .none
        let scale: CGFloat = 5
        let widths = roles.map { CGFloat($0.frameSize) * scale }
        var x = (bounds.width - widths.reduce(0, +) - CGFloat(roles.count - 1) * 8) / 2
        for (role, w) in zip(roles, widths) {
            if let image = role.image(direction: .down, phase: phase) {
                ctx.draw(image, in: CGRect(x: x, y: (bounds.height - w) / 2, width: w, height: w))
            }
            x += w + 8
        }
    }
}
