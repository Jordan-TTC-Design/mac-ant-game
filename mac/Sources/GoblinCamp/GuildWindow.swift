import AppKit

/// The guild page popped out into a window of its own (the camp can be too), to sit in a corner of the desktop: the same page
/// (GuildPane), moved here from the main window and back. It can stay above the other windows.
final class GuildWindow: NSObject, NSWindowDelegate {
    let window: NSWindow
    private let pane: GuildPane
    private var isOut = false

    init(pane: GuildPane) {
        self.pane = pane
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 980, height: 680), styleMask: [.titled, .closable, .resizable, .miniaturizable], backing: .buffered, defer: false)
        super.init()
        window.title = "公會"
        window.isReleasedWhenClosed = false
        window.contentMinSize = NSSize(width: 640, height: 420)
        window.delegate = self
        if !window.setFrameUsingName("GoblinCampGuild") { window.center() }
        window.setFrameAutosaveName("GoblinCampGuild")
    }

    var isVisible: Bool { isOut && window.isVisible && !window.isMiniaturized }

    /// Takes the page into this window and brings it forward.
    func open(activate: Bool = true) {
        if !isOut {
            pane.paneView.removeFromSuperview()
            pane.paneView.translatesAutoresizingMaskIntoConstraints = true
            pane.paneView.autoresizingMask = [.width, .height]
            window.contentView = pane.paneView
            isOut = true
        }
        applyLevel()
        if window.isMiniaturized { window.deminiaturize(nil) }
        pane.paneWillShow()
        if activate {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
        } else {
            window.orderFrontRegardless()
        }
    }

    func applyLevel() { window.level = Settings.shared.guildOnTop ? .floating : .normal }

    /// Gives the page back (the main window shows it again).
    func dockBack() {
        guard isOut else { return }
        window.orderOut(nil)
        pane.paneDidHide()
        window.contentView = NSView()
        isOut = false
    }

    func windowWillClose(_ notification: Notification) { pane.paneDidHide() }
}
