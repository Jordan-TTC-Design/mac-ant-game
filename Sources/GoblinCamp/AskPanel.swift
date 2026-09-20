import AppKit

/// What the player answered on a question popup.
enum AskAnswer {
    case allow
    case deny
    case reply(String)
    /// "I'll look myself": bring the terminal forward and let Claude Code's own prompt handle it.
    case look
    /// Closed without an answer.
    case dismiss
}

/// A button drawn by hand, so its label is always readable whatever the system appearance is (dark mode made the
/// standard buttons white on white).
final class PillButton: NSView {
    private let title: String
    private let fill: NSColor
    private let textColor: NSColor
    private let onClick: () -> Void
    private var pressed = false

    init(title: String, fill: NSColor, textColor: NSColor, onClick: @escaping () -> Void) {
        self.title = title
        self.fill = fill
        self.textColor = textColor
        self.onClick = onClick
        let font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        let width = ceil((title as NSString).size(withAttributes: [.font: font]).width) + 26
        super.init(frame: NSRect(x: 0, y: 0, width: max(width, 64), height: 26))
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override func draw(_ dirtyRect: NSRect) {
        let path = NSBezierPath(roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5), xRadius: 8, yRadius: 8)
        (pressed ? fill.blended(withFraction: 0.25, of: .black) ?? fill : fill).setFill()
        path.fill()
        NSColor(calibratedWhite: 0, alpha: 0.18).setStroke()
        path.lineWidth = 1
        path.stroke()
        let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 13, weight: .semibold), .foregroundColor: textColor]
        let size = (title as NSString).size(withAttributes: attrs)
        (title as NSString).draw(at: NSPoint(x: bounds.midX - size.width / 2, y: bounds.midY - size.height / 2), withAttributes: attrs)
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func mouseDown(with event: NSEvent) { pressed = true; needsDisplay = true }
    override func mouseUp(with event: NSEvent) {
        pressed = false
        needsDisplay = true
        if bounds.contains(convert(event.locationInWindow, from: nil)) { onClick() }
    }
    override func resetCursorRects() { addCursorRect(bounds, cursor: .pointingHand) }
}

/// The interactive speech bubble: the words, what Claude wants to do, and buttons or a text field.
/// A real window (the overlay lets every click through), non-activating so it does not pull focus from the terminal
/// until the player clicks into the text field.
final class AskPanel: NSPanel {
    static let width: CGFloat = 280
    private let onAnswer: (AskAnswer) -> Void
    private var field: NSTextField?

    override var canBecomeKey: Bool { true }

    /// The panel's size for a message (before it is placed).
    static func size(for message: Message) -> NSSize {
        let padding: CGFloat = 12
        let textWidth = width - padding * 2
        var height = padding * 2 + 16 // title
        height += textHeight(message.text, font: .systemFont(ofSize: 14, weight: .semibold), width: textWidth) + 4
        if !message.context.isEmpty { height += textHeight(message.context, font: .monospacedSystemFont(ofSize: 11, weight: .regular), width: textWidth, lines: 3) + 4 }
        height += message.interaction == .reply ? 28 + 8 : 0
        height += 28 + 4 // button row
        return NSSize(width: width, height: ceil(height))
    }

    private static func textHeight(_ string: String, font: NSFont, width: CGFloat, lines: Int = 6) -> CGFloat {
        let box = (string as NSString).boundingRect(with: NSSize(width: width, height: 1000), options: [.usesLineFragmentOrigin], attributes: [.font: font])
        return min(ceil(box.height), ceil(font.boundingRectForFont.height) * CGFloat(lines))
    }

    init(message: Message, frame: NSRect, onAnswer: @escaping (AskAnswer) -> Void) {
        self.onAnswer = onAnswer
        super.init(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        isFloatingPanel = true
        hidesOnDeactivate = false
        contentView = build(message, size: frame.size)
    }

    private func label(_ string: String, font: NSFont, color: NSColor, frame: NSRect, lines: Int = 0) -> NSTextField {
        let l = NSTextField(labelWithString: string)
        l.font = font
        l.textColor = color
        l.frame = frame
        l.lineBreakMode = .byTruncatingTail
        l.maximumNumberOfLines = lines
        l.cell?.wraps = true
        return l
    }

    private func build(_ message: Message, size: NSSize) -> NSView {
        let padding: CGFloat = 12
        let textWidth = size.width - padding * 2
        let root = NSView(frame: NSRect(origin: .zero, size: size))
        root.wantsLayer = true
        root.layer?.backgroundColor = NSColor.white.cgColor
        root.layer?.cornerRadius = 10
        root.layer?.borderWidth = 2.5
        root.layer?.borderColor = message.accent.cgColor
        root.appearance = NSAppearance(named: .aqua) // always light, like the game's other bubbles

        // laid out from the top down
        var y = size.height - padding
        y -= 16
        root.addSubview(label(message.title, font: .systemFont(ofSize: 11, weight: .semibold), color: message.accent, frame: NSRect(x: padding, y: y, width: textWidth, height: 16)))
        let mainFont = NSFont.systemFont(ofSize: 14, weight: .semibold)
        let mainHeight = AskPanel.textHeight(message.text, font: mainFont, width: textWidth)
        y -= mainHeight + 4
        root.addSubview(label(message.text, font: mainFont, color: NSColor(calibratedWhite: 0.12, alpha: 1), frame: NSRect(x: padding, y: y, width: textWidth, height: mainHeight)))
        if !message.context.isEmpty {
            let font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
            let h = AskPanel.textHeight(message.context, font: font, width: textWidth, lines: 3)
            y -= h + 4
            root.addSubview(label(message.context, font: font, color: NSColor(calibratedWhite: 0.38, alpha: 1), frame: NSRect(x: padding, y: y, width: textWidth, height: h), lines: 3))
        }
        if message.interaction == .reply {
            y -= 28 + 8
            let f = NSTextField(frame: NSRect(x: padding, y: y + 4, width: textWidth, height: 24))
            f.placeholderString = "回覆 Claude…（Return 送出）"
            f.bezelStyle = .roundedBezel
            f.font = .systemFont(ofSize: 13)
            f.target = self
            f.action = #selector(sendReply)
            root.addSubview(f)
            field = f
        }
        y -= 28 + 4
        let green = NSColor(calibratedRed: 0.20, green: 0.60, blue: 0.28, alpha: 1)
        let red = NSColor(calibratedRed: 0.78, green: 0.22, blue: 0.20, alpha: 1)
        let grey = NSColor(calibratedWhite: 0.90, alpha: 1)
        let ink = NSColor(calibratedWhite: 0.12, alpha: 1)
        let specs: [(String, NSColor, NSColor, () -> Void)]
        if message.interaction == .decision {
            specs = [("允許", green, .white, { [weak self] in self?.onAnswer(.allow) }),
                     ("拒絕", red, .white, { [weak self] in self?.onAnswer(.deny) }),
                     ("自己去看", grey, ink, { [weak self] in self?.onAnswer(.look) })]
        } else {
            specs = [("送出", green, .white, { [weak self] in self?.sendReply() }),
                     ("自己去看", grey, ink, { [weak self] in self?.onAnswer(.look) }),
                     ("不用了", grey, ink, { [weak self] in self?.onAnswer(.dismiss) })]
        }
        var x = padding
        for (title, fill, text, action) in specs {
            let b = PillButton(title: title, fill: fill, textColor: text, onClick: action)
            b.frame.origin = NSPoint(x: x, y: y + 2)
            root.addSubview(b)
            x += b.frame.width + 8
        }
        return root
    }

    /// For tests and shortcuts: answer as if the button was pressed.
    func answer(_ a: AskAnswer) { onAnswer(a) }

    @objc private func sendReply() {
        let text = (field?.stringValue ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        onAnswer(text.isEmpty ? .dismiss : .reply(text))
    }
}
