import AppKit

/// The camp: a small map (grass and a forest edge) where all the goblins live. It is the main window's first page (`pane`),
/// or popped out into a small window of its own (`window`) to sit in a corner of the desktop; one button moves it from one to
/// the other (`docked`). The small window can be moved, resized, folded away (the close button, or the menu) and brought back,
/// and the goblins keep living while it is away. The camp has its own little world at a fixed spot (origin 0,0), so moving
/// the window does not disturb anyone; its size is the view's (the page's, or the small window's).
final class MapWindow: NSObject, NSWindowDelegate, MainPane {
    let window: NSWindow
    let view: AntView
    /// The main window's 營地 page: the camp, or (popped out) a line and a button to bring it back.
    let paneView = NSView(frame: NSRect(x: 0, y: 0, width: 900, height: 700))
    private let popOut = NSButton(title: "⇱ 彈出", target: nil, action: nil)
    private let placeholder = NSStackView()
    /// Asked to move the camp in or out (AppDelegate does the rest: the main window, the menu).
    var onDock: ((Bool) -> Void)?
    /// In the main window (true) or in the small window.
    private(set) var docked: Bool
    /// The world got a new size (the window was resized).
    var onResize: (() -> Void)?
    /// The desktops this window was last put on (see `Spaces.assign`).
    var placedOn = ""

    /// The area the goblins may walk on: the whole window content, in the camp's own coordinates.
    var world: CGRect { CGRect(x: 0, y: 0, width: view.bounds.width, height: view.bounds.height) }

    /// Where goblins may walk: the clearing inside the ring of trees.
    var walkArea: CGRect {
        let w = world
        let sides: CGFloat = Settings.shared.scenery == "none" ? 8 : 40, top: CGFloat = Settings.shared.scenery == "none" ? 8 : 30, bottom: CGFloat = Settings.shared.scenery == "none" ? 8 : 12
        let r = CGRect(x: w.minX + sides, y: w.minY + bottom, width: max(60, w.width - sides * 2), height: max(60, w.height - top - bottom))
        return r
    }
    /// The camp can be seen: its page is showing in the main window, or the small window is up.
    var isVisible: Bool {
        guard let host = view.window else { return false }
        return host.isVisible && !host.isMiniaturized
    }
    /// The window the camp is in now (for the screen it is on).
    var hostWindow: NSWindow { view.window ?? window }

    init(colony: Colony) {
        let settings = Settings.shared
        var frame = NSRect(x: 0, y: 0, width: 520, height: 330)
        if let saved = settings.mapFrame, !saved.isEmpty {
            let r = NSRectFromString(saved)
            if r.width >= 300, r.height >= 200, NSScreen.screens.contains(where: { $0.frame.intersects(r) }) { frame = r }
        } else if let area = NSScreen.main?.visibleFrame {
            frame.origin = NSPoint(x: area.maxX - frame.width - 24, y: area.minY + 24)
        }
        window = NSWindow(contentRect: frame, styleMask: [.titled, .closable, .resizable, .miniaturizable], backing: .buffered, defer: false)
        view = AntView(frame: NSRect(origin: .zero, size: frame.size), colony: colony)
        docked = settings.campDocked
        super.init()
        window.title = "\(Characters.current.name)營地"
        window.contentMinSize = NSSize(width: 300, height: 200)
        window.isReleasedWhenClosed = false
        window.hidesOnDeactivate = false
        window.collectionBehavior = []  // put on the chosen desktops by hand
        window.delegate = self
        view.isMap = true
        AntView.campView = view
        view.originOverride = .zero
        view.showsCamp = true
        view.autoresizingMask = [.width, .height]
        view.postsFrameChangedNotifications = true
        NotificationCenter.default.addObserver(forName: NSView.frameDidChangeNotification, object: view, queue: .main) { [weak self] _ in self?.onResize?() }
        window.setFrame(frame, display: false)
        // the small window's way back
        let back = NSButton(title: "收回主視窗", target: self, action: #selector(dockIt))
        back.bezelStyle = .recessed
        back.controlSize = .small
        let accessory = NSTitlebarAccessoryViewController()
        accessory.view = NSView(frame: NSRect(x: 0, y: 0, width: 96, height: 24))
        back.frame = NSRect(x: 0, y: 2, width: 92, height: 20)
        accessory.view.addSubview(back)
        accessory.layoutAttribute = .trailing
        window.addTitlebarAccessoryViewController(accessory)
        // the page's way out, and what it shows while the camp is out
        popOut.target = self
        popOut.action = #selector(popItOut)
        popOut.bezelStyle = .rounded // (the same as the camp's 🏡 裝飾 button, just left of it: AntView.viewDidMoveToWindow)
        popOut.controlSize = .small
        popOut.font = .systemFont(ofSize: 11)
        popOut.sizeToFit()
        popOut.autoresizingMask = [.minXMargin, .minYMargin]
        popOut.toolTip = "彈出成小視窗：營地自己一個小視窗，可以放在桌面角落；小視窗上的「收回主視窗」放回來"
        let line = NSTextField(labelWithString: "營地現在是一個小視窗。")
        line.textColor = .secondaryLabelColor
        let bring = NSButton(title: "收回主視窗", target: self, action: #selector(dockIt))
        let find = NSButton(title: "找營地視窗", target: self, action: #selector(findWindow))
        let buttons = NSStackView(views: [bring, find])
        placeholder.orientation = .vertical
        placeholder.spacing = 10
        placeholder.addArrangedSubview(line)
        placeholder.addArrangedSubview(buttons)
        placeholder.translatesAutoresizingMaskIntoConstraints = false
        paneView.addSubview(placeholder)
        NSLayoutConstraint.activate([placeholder.centerXAnchor.constraint(equalTo: paneView.centerXAnchor), placeholder.centerYAnchor.constraint(equalTo: paneView.centerYAnchor)])
        place()
        applyLevel()
    }

    /// Puts the camp's view where it belongs now: the page, or the small window.
    private func place() {
        if docked {
            window.orderOut(nil)
            window.contentView = NSView()
            view.frame = paneView.bounds
            paneView.addSubview(view, positioned: .below, relativeTo: nil)
            view.addSubview(popOut)
            let decor = view.subviews.first { $0.identifier?.rawValue == "decor-button" }?.frame.width ?? 72
            popOut.frame.origin = NSPoint(x: view.bounds.maxX - decor - 10 - 6 - popOut.frame.width, y: view.bounds.maxY - popOut.frame.height - 8)
            placeholder.isHidden = true
        } else {
            popOut.removeFromSuperview()
            view.removeFromSuperview()
            window.contentView = view
            placeholder.isHidden = false
        }
        onResize?()
    }

    /// Into the main window (true) or out into the small window.
    func setDocked(_ value: Bool) {
        guard value != docked else { return }
        docked = value
        Settings.shared.campDocked = value
        place()
    }

    @objc private func popItOut() { onDock?(false) }
    @objc private func dockIt() { onDock?(true) }
    @objc private func findWindow() {
        if window.isMiniaturized { window.deminiaturize(nil) }
        Settings.shared.mapCollapsed = false
        window.makeKeyAndOrderFront(nil)
    }

    // MARK: The main window's page

    func paneWillShow() {
        if docked { view.window?.makeFirstResponder(view) } // (keys for the camp: Esc, F…)
        view.needsDisplay = true
    }

    func applyLevel() {
        window.level = Settings.shared.mapOnTop ? Levels.panel : .normal
    }

    /// The small window up (popped out only: in the main window, the main window decides).
    func show() {
        guard !docked else { return }
        applyLevel()
        if window.isMiniaturized { return } // the player shrank it to the Dock: leave it there
        if !window.isVisible { window.orderFrontRegardless() }
    }

    func hide() {
        if window.isVisible { window.orderOut(nil) }
    }

    func resetPosition() {
        guard let area = NSScreen.main?.visibleFrame else { return }
        let size = NSSize(width: 520, height: 330)
        window.setFrame(NSRect(x: area.maxX - size.width - 24, y: area.minY + 24, width: size.width, height: size.height), display: true)
    }

    // MARK: Window delegate

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        Settings.shared.mapCollapsed = true // folded away; the menu brings it back
        return true
    }

    /// Shrinking it to the Dock counts as folding it away (and it must stay there, not pop back up).
    func windowDidMiniaturize(_ notification: Notification) { Settings.shared.mapCollapsed = true }
    func windowDidDeminiaturize(_ notification: Notification) { Settings.shared.mapCollapsed = false }

    func windowDidMove(_ notification: Notification) { Settings.shared.mapFrame = NSStringFromRect(window.frame) }

    func windowDidResize(_ notification: Notification) {
        Settings.shared.mapFrame = NSStringFromRect(window.frame) // (the world's new size: the view's frame says so)
    }
}
