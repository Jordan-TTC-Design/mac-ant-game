import AppKit

/// The camp in a window of its own: a small map (grass and a forest edge) where all the goblins live. It can be moved, resized,
/// folded away (the close button, or the menu) and brought back, and the goblins keep living while it is away.
/// The camp has its own little world at a fixed spot (origin 0,0), so moving the window does not disturb anyone.
final class MapWindow: NSObject, NSWindowDelegate {
    let window: NSWindow
    let view: AntView
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
    var isVisible: Bool { window.isVisible }

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
        super.init()
        window.title = "哥布林營地"
        window.contentMinSize = NSSize(width: 300, height: 200)
        window.isReleasedWhenClosed = false
        window.hidesOnDeactivate = false
        window.collectionBehavior = []  // put on the chosen desktops by hand
        window.delegate = self
        view.isMap = true
        view.originOverride = .zero
        view.showsCamp = true
        view.autoresizingMask = [.width, .height]
        window.contentView = view
        window.setFrame(frame, display: false)
        applyLevel()
    }

    func applyLevel() {
        window.level = Settings.shared.mapOnTop ? Levels.panel : .normal
    }

    func show() {
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
        Settings.shared.mapFrame = NSStringFromRect(window.frame)
        onResize?()
    }
}
