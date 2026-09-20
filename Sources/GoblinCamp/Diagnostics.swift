import AppKit

/// A short memory of what changed on screen (goblins shown or hidden, full screen, modes), so that "they flickered" can be looked into:
/// the menu copies it to the clipboard.
enum Diagnostics {
    private static var lines: [String] = []

    static func note(_ text: String) {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        lines.append("\(f.string(from: Date())) \(text)")
        if lines.count > 120 { lines.removeFirst(lines.count - 120) }
        if ProcessInfo.processInfo.environment["CAMP_DEBUG"] != nil { NSLog("GoblinCamp: \(text)") }
    }

    static func report(settings: Settings, extra: [String]) -> String {
        var out = ["GoblinCamp \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?")",
                   "macOS \(ProcessInfo.processInfo.operatingSystemVersionString)"]
        for (i, screen) in NSScreen.screens.enumerated() {
            let info = Spaces.info(for: screen)
            out.append("screen \(i) \(screen.localizedName) frame \(NSStringFromRect(screen.frame)) desktop \(info?.desktop.map(String.init) ?? "-") fullscreen \(info?.isFullScreen == true)")
        }
        out.append("settings: range \(settings.rangeMode)/\(Int(settings.rangeSize)) scenery \(settings.scenery) screens \(settings.screenMode) \(settings.screenNames) desktops \(settings.desktopsAll ? "all" : "\(settings.desktops)") fullscreenFocus \(settings.fullscreenFocus)")
        out += extra
        out.append("--- recent changes")
        out += lines.suffix(80)
        return out.joined(separator: "\n")
    }
}
