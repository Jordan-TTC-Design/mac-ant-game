import AppKit

/// Borderless, transparent window covering one screen. Mouse-transparent by default;
/// while `acceptsInput` is on (nest-picking) it captures clicks and can become key so the cursor rect applies.
final class OverlayWindow: NSWindow {
    var acceptsInput = false {
        didSet {
            ignoresMouseEvents = !acceptsInput
            invalidateCursorRects(for: contentView ?? NSView())
        }
    }

    init(screen: NSScreen) {
        super.init(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
        setFrame(screen.frame, display: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .statusBar
        ignoresMouseEvents = true
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
    }

    override var canBecomeKey: Bool { acceptsInput }
    override var canBecomeMain: Bool { false }
}
