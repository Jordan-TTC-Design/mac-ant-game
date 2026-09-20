import AppKit

/// Window levels. Everything of ours sits just under the Dock (level 20), so the Dock, the menu bar, Spotlight, Mission Control,
/// notifications and the like are always on top of the goblins and never fight with them.
enum Levels {
    static let dock = Int(CGWindowLevelForKey(.dockWindow))
    /// The see-through overlays the goblins walk in.
    static let overlay = NSWindow.Level(rawValue: dock - 2)
    /// Our panels, popups and dialogs: above the overlays and above ordinary windows, still under the system's own.
    static let panel = NSWindow.Level(rawValue: dock - 1)
}

/// Borderless, transparent window covering one screen. Mouse-transparent by default;
/// while `acceptsInput` is on (nest-picking) it captures clicks and can become key so the cursor rect applies.
final class OverlayWindow: NSWindow {
    var acceptsInput = false {
        didSet {
            ignoresMouseEvents = !acceptsInput
            invalidateCursorRects(for: contentView ?? NSView())
        }
    }

    /// The camp overlay lives only on the desktops the player picked (see `Spaces.assign`); the tools overlay (pomodoro, popups) is on all.
    let showsTools: Bool
    /// The desktops this window was last put on, so it is only moved when they change.
    var placedOn = ""

    init(screen: NSScreen, tools: Bool = false) {
        showsTools = tools
        super.init(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
        setFrame(screen.frame, display: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = Levels.overlay
        ignoresMouseEvents = true
        isReleasedWhenClosed = false
        // the camp overlay is placed on chosen desktops by hand; the tools overlay follows you everywhere
        collectionBehavior = tools ? [.canJoinAllSpaces, .stationary, .ignoresCycle] : [.stationary, .ignoresCycle]
    }

    override var canBecomeKey: Bool { acceptsInput }
    override var canBecomeMain: Bool { false }
}
