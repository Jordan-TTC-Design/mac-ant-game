import AppKit

/// The little pieces the guild page's panels are built from (捐獻、成員、設定、角色、建立或加入公會), all on the page itself.
enum GuildUI {
    static let gold = NSColor(calibratedRed: 0.91, green: 0.77, blue: 0.28, alpha: 1)

    static func label(_ text: String, size: CGFloat = 12, bold: Bool = false, color: NSColor = .labelColor, width: CGFloat? = nil) -> NSTextField {
        let l = NSTextField(wrappingLabelWithString: text)
        l.font = bold ? .boldSystemFont(ofSize: size) : .systemFont(ofSize: size)
        l.textColor = color
        l.isSelectable = false
        if let width { l.preferredMaxLayoutWidth = width }
        return l
    }

    static func heading(_ text: String) -> NSTextField { label(text, size: 13, bold: true) }

    static func note(_ text: String, width: CGFloat? = nil) -> NSTextField { label(text, size: 11, color: .secondaryLabelColor, width: width) }

    static func button(_ title: String, prominent: Bool = false, _ action: @escaping () -> Void) -> ClosureButton {
        let b = ClosureButton(title: title, action: action)
        b.bezelStyle = .rounded
        b.controlSize = .small
        if prominent { b.bezelColor = gold }
        return b
    }

    static func row(_ views: [NSView], spacing: CGFloat = 8) -> NSStackView {
        let s = NSStackView(views: views)
        s.orientation = .horizontal
        s.alignment = .centerY
        s.spacing = spacing
        return s
    }

    static func separator() -> NSView {
        let b = NSBox()
        b.boxType = .separator
        return b
    }

    /// The first frame (or a given one) of an avatar as a picture, for a list.
    static func face(_ avatar: GuildInfo.Avatar, size: CGFloat = 36) -> NSView {
        let v = NSImageView(frame: NSRect(x: 0, y: 0, width: size, height: size))
        let art = GuildArt.shared
        if let img = art.avatarFrame(avatar, art.frameIndex(anim: "idle", dir: "front", t: 0)) {
            // (just the head and shoulders of the figure)
            let w = art.frameW
            let crop = img.cropping(to: CGRect(x: 0, y: 0, width: w, height: min(art.frameH, w))) ?? img
            v.image = NSImage(cgImage: crop, size: NSSize(width: size, height: size))
        }
        v.imageScaling = .scaleProportionallyUpOrDown
        v.wantsLayer = true
        v.layer?.magnificationFilter = .nearest
        v.translatesAutoresizingMaskIntoConstraints = false
        v.widthAnchor.constraint(equalToConstant: size).isActive = true
        v.heightAnchor.constraint(equalToConstant: size).isActive = true
        return v
    }

    /// A button that asks again before doing something one cannot take back.
    static func sure(_ title: String, _ action: @escaping () -> Void) -> ClosureButton {
        var asked = false
        var button: ClosureButton!
        button = ClosureButton(title: title) {
            if asked {
                asked = false
                button.title = title
                action()
            } else {
                asked = true
                button.title = "再按一次確定"
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    if asked {
                        asked = false
                        button.title = title
                    }
                }
            }
        }
        button.bezelStyle = .rounded
        button.controlSize = .small
        return button
    }

    /// "3 分鐘前" and so on, for the server's times.
    static func ago(_ iso: String?) -> String {
        guard let iso, let at = ISO8601DateFormatter.guild.date(from: iso) else { return "" }
        let f = RelativeDateTimeFormatter()
        f.locale = Locale(identifier: "zh_TW")
        f.unitsStyle = .short
        return f.localizedString(for: at, relativeTo: Date())
    }
}

/// A panel on the right of the guild page: a title, a ✕, and a list that scrolls. Filled with `show`.
final class GuildPanel: NSVisualEffectView {
    let width: CGFloat
    private let stack = NSStackView()
    private let doc = TopDownView()
    private let scroll = NSScrollView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let subLabel = NSTextField(labelWithString: "")
    var inner: CGFloat { width - 24 }

    init(title: String, sub: String = "", width: CGFloat = 380, close: @escaping () -> Void) {
        self.width = width
        super.init(frame: .zero)
        material = .hudWindow
        blendingMode = .withinWindow
        state = .active
        wantsLayer = true
        layer?.cornerRadius = 12
        layer?.backgroundColor = NSColor(white: 0.06, alpha: 0.6).cgColor

        titleLabel.stringValue = title
        titleLabel.font = .boldSystemFont(ofSize: 15)
        subLabel.stringValue = sub
        subLabel.font = .systemFont(ofSize: 11)
        subLabel.textColor = .secondaryLabelColor
        subLabel.isHidden = sub.isEmpty
        let names = NSStackView(views: [titleLabel, subLabel])
        names.orientation = .vertical
        names.alignment = .leading
        names.spacing = 1
        let x = ClosureButton(title: "✕", action: close)
        x.bezelStyle = .inline
        x.isBordered = false
        x.font = .systemFont(ofSize: 14)
        x.toolTip = "關起來"
        let head = NSStackView(views: [names, NSView(), x])
        head.distribution = .fill
        head.alignment = .top
        addSubview(head)
        head.translatesAutoresizingMaskIntoConstraints = false

        doc.translatesAutoresizingMaskIntoConstraints = false
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.edgeInsets = NSEdgeInsets(top: 4, left: 12, bottom: 12, right: 12)
        stack.translatesAutoresizingMaskIntoConstraints = false
        doc.addSubview(stack)
        scroll.documentView = doc
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        scroll.borderType = .noBorder
        scroll.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scroll)
        NSLayoutConstraint.activate([
            head.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12), head.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
            head.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            scroll.leadingAnchor.constraint(equalTo: leadingAnchor), scroll.trailingAnchor.constraint(equalTo: trailingAnchor),
            scroll.topAnchor.constraint(equalTo: head.bottomAnchor, constant: 6), scroll.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
            doc.leadingAnchor.constraint(equalTo: scroll.contentView.leadingAnchor), doc.trailingAnchor.constraint(equalTo: scroll.contentView.trailingAnchor),
            doc.topAnchor.constraint(equalTo: scroll.contentView.topAnchor),
            stack.leadingAnchor.constraint(equalTo: doc.leadingAnchor), stack.trailingAnchor.constraint(equalTo: doc.trailingAnchor),
            stack.topAnchor.constraint(equalTo: doc.topAnchor), stack.bottomAnchor.constraint(equalTo: doc.bottomAnchor),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func setSub(_ text: String) {
        subLabel.stringValue = text
        subLabel.isHidden = text.isEmpty
    }

    /// Replaces what the panel lists; each view is as wide as the panel unless it says (`fill: false`).
    func show(_ views: [NSView], fill: Bool = true) {
        for v in stack.arrangedSubviews { stack.removeArrangedSubview(v); v.removeFromSuperview() }
        for v in views {
            stack.addArrangedSubview(v)
            if v is NSBox || (fill && v is NSStackView) { v.widthAnchor.constraint(equalToConstant: inner).isActive = true }
            if let l = v as? NSTextField, l.preferredMaxLayoutWidth == 0 { l.preferredMaxLayoutWidth = inner }
        }
    }
}

// MARK: The badge

enum GuildBadgeArt {
    static let size = 16
    /// Index 0 is see-through (shared/src/guild.ts BADGE_PALETTE).
    static let palette: [NSColor?] = [
        nil, "#f4e9cf", "#e8c547", "#b8862b", "#c9ced6", "#6d7480", "#c0392b", "#7a1f1f", "#2e6fbf", "#1f3b6e", "#3f9a4a", "#1f5a2c", "#7b4fa8", "#d9822b", "#6b4226", "#1b1b22",
    ].map { $0.map { hex in
        let v = UInt32(hex.dropFirst(), radix: 16) ?? 0
        return NSColor(calibratedRed: CGFloat(v >> 16 & 0xff) / 255, green: CGFloat(v >> 8 & 0xff) / 255, blue: CGFloat(v & 0xff) / 255, alpha: 1)
    } }

    /// A plain badge: a blue shield with a gold edge and a gold star (DEFAULT_BADGE).
    static let standard: String = {
        var out = ""
        for y in 0..<16 {
            for x in 0..<16 {
                let half = y < 9 ? 6.5 : 6.5 - Double(y - 8) * 0.9
                let dx = abs(Double(x) - 7.5)
                let inside = y >= 1 && y <= 15 && dx <= half
                let edge = inside && (y == 1 || dx > half - 1 || y == 15)
                let star = (dx < 1 && y >= 4 && y <= 10) || (abs(Double(y) - 7) < 1 && x >= 4 && x <= 11)
                out += !inside ? "0" : edge ? "2" : star ? "2" : "8"
            }
        }
        return out
    }()

    static func draw(_ badge: String, in rect: NSRect) {
        let cells = Array(badge)
        guard cells.count == size * size else { return }
        let s = rect.width / CGFloat(size)
        for (i, c) in cells.enumerated() {
            guard let idx = Int(String(c), radix: 16), idx > 0, idx < palette.count, let color = palette[idx] else { continue }
            color.setFill()
            NSRect(x: rect.minX + CGFloat(i % size) * s, y: rect.minY + CGFloat(i / size) * s, width: s + 0.5, height: s + 0.5).fill()
        }
    }
}

/// The guild's badge as a small picture.
final class BadgeView: NSView {
    var badge: String { didSet { needsDisplay = true } }
    init(_ badge: String, size: CGFloat) {
        self.badge = badge
        super.init(frame: NSRect(x: 0, y: 0, width: size, height: size))
        translatesAutoresizingMaskIntoConstraints = false
        widthAnchor.constraint(equalToConstant: size).isActive = true
        heightAnchor.constraint(equalToConstant: size).isActive = true
    }

    required init?(coder: NSCoder) { fatalError() }
    override var isFlipped: Bool { true }
    override func draw(_ dirtyRect: NSRect) { GuildBadgeArt.draw(badge, in: bounds) }
}

/// Drawing a badge (GUILD.md §5.4): 16 × 16, the heraldic palette, pencil, eraser and fill, a mirror that draws both halves,
/// and undo.
final class BadgeEditorView: NSView {
    private(set) var badge: String { didSet { needsDisplay = true; onChange?(badge) } }
    var onChange: ((String) -> Void)?
    private var color = 2
    private enum Tool: Int { case pen, erase, fill }
    private var tool = Tool.pen
    private var mirror = true
    private var history: [String] = []
    private let cell: CGFloat = 12
    private let canvas = NSView()
    private var drawing = false

    init(_ badge: String) {
        self.badge = badge
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        let grid = BadgeCanvas(owner: self, cell: cell)
        canvas.addSubview(grid)
        let tools = NSSegmentedControl(labels: ["筆", "橡皮擦", "填滿"], trackingMode: .selectOne, target: self, action: #selector(toolChanged(_:)))
        tools.selectedSegment = 0
        tools.controlSize = .small
        let mirrorBox = NSButton(checkboxWithTitle: "鏡像", target: self, action: #selector(mirrorChanged(_:)))
        mirrorBox.state = .on
        mirrorBox.controlSize = .small
        let undo = ClosureButton(title: "復原") { [weak self] in self?.undo() }
        undo.bezelStyle = .rounded
        undo.controlSize = .small
        let swatches = NSStackView()
        swatches.spacing = 3
        for i in 1..<GuildBadgeArt.palette.count { swatches.addArrangedSubview(Swatch(index: i, owner: self)) }
        let preview = BadgeView(badge, size: 48)
        self.preview = preview
        let top = GuildUI.row([grid, preview], spacing: 12)
        top.alignment = .top
        let stack = NSStackView(views: [top, swatches, GuildUI.row([tools, mirrorBox, undo])])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo: leadingAnchor), stack.trailingAnchor.constraint(equalTo: trailingAnchor),
                                     stack.topAnchor.constraint(equalTo: topAnchor), stack.bottomAnchor.constraint(equalTo: bottomAnchor)])
        self.grid = grid
        grid.translatesAutoresizingMaskIntoConstraints = false
        grid.widthAnchor.constraint(equalToConstant: cell * 16).isActive = true
        grid.heightAnchor.constraint(equalToConstant: cell * 16).isActive = true
    }

    required init?(coder: NSCoder) { fatalError() }

    private weak var grid: NSView?
    private weak var preview: BadgeView?

    /// Replaces the badge from outside (a new one loaded).
    func set(_ new: String) {
        badge = new
        history = []
    }

    fileprivate func refreshViews() {
        grid?.needsDisplay = true
        preview?.badge = badge
        subviews.compactMap { $0 as? NSStackView }.forEach { $0.needsLayout = true }
    }

    @objc private func toolChanged(_ s: NSSegmentedControl) { tool = Tool(rawValue: s.selectedSegment) ?? .pen }
    @objc private func mirrorChanged(_ b: NSButton) { mirror = b.state == .on }

    private func undo() {
        guard let last = history.popLast() else { return }
        badge = last
        refreshViews()
    }

    fileprivate var selectedColor: Int {
        get { color }
        set {
            color = newValue
            allSwatches.forEach { $0.needsDisplay = true }
        }
    }

    private var allSwatches: [NSView] {
        func walk(_ v: NSView) -> [NSView] { (v is Swatch ? [v] : []) + v.subviews.flatMap(walk) }
        return walk(self)
    }

    fileprivate func begin(at i: Int) {
        history.append(badge)
        if history.count > 50 { history.removeFirst() }
        drawing = tool != .fill
        paint(i)
    }

    fileprivate func drag(to i: Int) { if drawing { paint(i) } }
    fileprivate func end() { drawing = false }

    private func paint(_ i: Int) {
        var px = Array(badge).map { Int(String($0), radix: 16) ?? 0 }
        guard px.count == 256, i >= 0, i < 256 else { return }
        let x = i % 16, y = i / 16
        if tool == .fill {
            let from = px[i], to = color
            guard from != to else { return }
            var todo = [(x, y)]
            while let (cx, cy) = todo.popLast() {
                guard cx >= 0, cy >= 0, cx < 16, cy < 16, px[cy * 16 + cx] == from else { continue }
                px[cy * 16 + cx] = to
                todo += [(cx + 1, cy), (cx - 1, cy), (cx, cy + 1), (cx, cy - 1)]
            }
        } else {
            let c = tool == .erase ? 0 : color
            px[i] = c
            if mirror { px[y * 16 + (15 - x)] = c }
        }
        badge = px.map { String($0, radix: 16) }.joined()
        refreshViews()
    }

    private final class BadgeCanvas: NSView {
        unowned let owner: BadgeEditorView
        let cell: CGFloat
        init(owner: BadgeEditorView, cell: CGFloat) {
            self.owner = owner
            self.cell = cell
            super.init(frame: NSRect(x: 0, y: 0, width: cell * 16, height: cell * 16))
        }
        required init?(coder: NSCoder) { fatalError() }
        override var isFlipped: Bool { true }
        override func draw(_ dirtyRect: NSRect) {
            for y in 0..<16 {
                for x in 0..<16 {
                    ((x + y) % 2 == 0 ? NSColor(white: 0.85, alpha: 1) : NSColor(white: 0.7, alpha: 1)).setFill()
                    NSRect(x: CGFloat(x) * cell, y: CGFloat(y) * cell, width: cell, height: cell).fill()
                }
            }
            GuildBadgeArt.draw(owner.badge, in: bounds)
        }
        private func index(_ e: NSEvent) -> Int? {
            let p = convert(e.locationInWindow, from: nil)
            let x = Int(p.x / cell), y = Int(p.y / cell)
            return x >= 0 && y >= 0 && x < 16 && y < 16 ? y * 16 + x : nil
        }
        override func mouseDown(with event: NSEvent) { if let i = index(event) { owner.begin(at: i) } }
        override func mouseDragged(with event: NSEvent) { if let i = index(event) { owner.drag(to: i) } }
        override func mouseUp(with event: NSEvent) { owner.end() }
    }

    private final class Swatch: NSView {
        let index: Int
        unowned let owner: BadgeEditorView
        init(index: Int, owner: BadgeEditorView) {
            self.index = index
            self.owner = owner
            super.init(frame: NSRect(x: 0, y: 0, width: 18, height: 18))
            translatesAutoresizingMaskIntoConstraints = false
            widthAnchor.constraint(equalToConstant: 18).isActive = true
            heightAnchor.constraint(equalToConstant: 18).isActive = true
        }
        required init?(coder: NSCoder) { fatalError() }
        override func draw(_ dirtyRect: NSRect) {
            let on = owner.selectedColor == index
            let box = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 4, yRadius: 4)
            (GuildBadgeArt.palette[index] ?? .clear).setFill()
            box.fill()
            (on ? NSColor.white : NSColor(white: 0, alpha: 0.4)).setStroke()
            box.lineWidth = on ? 2.5 : 1
            box.stroke()
        }
        override func mouseDown(with event: NSEvent) { owner.selectedColor = index }
    }
}
