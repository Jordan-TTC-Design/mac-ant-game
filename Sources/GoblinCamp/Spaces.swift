import AppKit

@_silgen_name("CGSMainConnectionID") private func CGSMainConnectionID() -> Int32
@_silgen_name("CGSCopyManagedDisplaySpaces") private func CGSCopyManagedDisplaySpaces(_ connection: Int32) -> CFArray?

/// Which macOS desktop ("桌面 1", "桌面 2"…) each screen is showing, so the goblins can stay on the desktops the player picked.
/// macOS has no public API for this; these are read-only calls into the window server that many utilities use. If they ever
/// stop working, everything answers "unknown" and the goblins simply show on every desktop.
/// `CAMP_FAKE_SPACE` (1, 2, 3… or `fs`) pretends every screen is on that desktop (for tests).
enum Spaces {
    struct Info {
        /// 1, 2, 3… for a normal desktop; nil when the screen is showing a full-screen app's own Space.
        let desktop: Int?
        let isFullScreen: Bool
    }

    private static var fake: String? { ProcessInfo.processInfo.environment["CAMP_FAKE_SPACE"] }

    private static func displays() -> [[String: Any]] {
        (CGSCopyManagedDisplaySpaces(CGSMainConnectionID()) as? [[String: Any]]) ?? []
    }

    private static func entry(for screen: NSScreen, in all: [[String: Any]]) -> [String: Any]? {
        if all.count == 1 { return all[0] } // one shared Space list (or a single display)
        if let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID,
           let uuid = CGDisplayCreateUUIDFromDisplayID(number)?.takeRetainedValue(),
           let text = CFUUIDCreateString(nil, uuid) as String? {
            return all.first { (($0["Display Identifier"] as? String) ?? "").caseInsensitiveCompare(text) == .orderedSame }
        }
        return nil
    }

    /// The desktop this screen is on now, or nil if that cannot be found out.
    static func info(for screen: NSScreen) -> Info? {
        if let fake { return fake == "fs" ? Info(desktop: nil, isFullScreen: true) : Info(desktop: Int(fake) ?? 1, isFullScreen: false) }
        let all = displays()
        guard let entry = entry(for: screen, in: all), let current = entry["Current Space"] as? [String: Any],
              let id = current["ManagedSpaceID"] as? Int else { return nil }
        if ((current["type"] as? Int) ?? 0) != 0 { return Info(desktop: nil, isFullScreen: true) }
        let desktops = ((entry["Spaces"] as? [[String: Any]]) ?? []).filter { (($0["type"] as? Int) ?? 0) == 0 }
        guard let index = desktops.firstIndex(where: { ($0["ManagedSpaceID"] as? Int) == id }) else { return nil }
        return Info(desktop: index + 1, isFullScreen: false)
    }

    /// How many normal desktops there are (the most on any display); 0 if unknown.
    static var desktopCount: Int {
        if fake != nil { return 3 }
        return displays().map { display in ((display["Spaces"] as? [[String: Any]]) ?? []).filter { (($0["type"] as? Int) ?? 0) == 0 }.count }.max() ?? 0
    }

    /// Some screen is showing a full-screen app (a video, a slideshow).
    static var anyFullScreen: Bool {
        NSScreen.screens.contains { info(for: $0)?.isFullScreen == true }
    }
}
