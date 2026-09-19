import AppKit

/// Turning seconds into "30 秒" / "5 分鐘" / "2 小時" and back.
enum IntervalFormat {
    static func text(_ seconds: Double) -> String {
        func number(_ v: Double) -> String { v == v.rounded() ? String(Int(v)) : String(format: "%.1f", v) }
        if seconds < 60 { return "\(number(seconds)) 秒" }
        if seconds < 3600 {
            let minutes = Int(seconds) / 60, rest = Int(seconds) % 60
            return rest == 0 ? "\(minutes) 分鐘" : "\(minutes) 分 \(rest) 秒"
        }
        let hours = Int(seconds) / 3600, minutes = (Int(seconds) % 3600) / 60
        return minutes == 0 ? "\(hours) 小時" : "\(hours) 小時 \(minutes) 分"
    }

    /// "45" (seconds), "30s", "5m", "1.5h", "90秒", "3分", "2小時". Nil if it does not make sense.
    static func parse(_ raw: String) -> Double? {
        var text = raw.trimmingCharacters(in: .whitespaces).lowercased()
        guard !text.isEmpty else { return nil }
        var unit = 1.0
        for (suffix, factor) in [("小時", 3600.0), ("分鐘", 60.0), ("小时", 3600.0), ("分钟", 60.0), ("hours", 3600), ("hour", 3600), ("hrs", 3600),
                                 ("hr", 3600), ("mins", 60), ("min", 60), ("秒鐘", 1), ("秒", 1), ("分", 60), ("時", 3600), ("h", 3600),
                                 ("m", 60), ("s", 1)] as [(String, Double)] where text.hasSuffix(suffix) {
            unit = factor
            text.removeLast(suffix.count)
            break
        }
        guard let value = Double(text.trimmingCharacters(in: .whitespaces)), value.isFinite else { return nil }
        let seconds = value * unit
        return (1...86_400).contains(seconds) ? seconds : nil
    }
}

/// User-tunable options from the menu bar, persisted in UserDefaults.
final class Settings {
    static let shared = Settings()
    private let defaults = UserDefaults.standard

    /// A number setting, or nil if unset. Values passed on the command line (`-maxAnts 200`) arrive as strings,
    /// which `double(forKey:)` converts, so this works for both stored and command-line values.
    private func number(_ key: String, argument: String? = nil, storedIgnored: Bool = false) -> Double? {
        if let name = argument, let raw = defaults.volatileDomain(forName: UserDefaults.argumentDomain)[name] {
            return (raw as? NSNumber)?.doubleValue ?? Double("\(raw)")
        }
        if storedIgnored { return nil }
        return defaults.object(forKey: key) == nil ? nil : defaults.double(forKey: key)
    }

    /// Seconds between newborn ants. `CAMP_SPAWN_INTERVAL` overrides it for quick testing.
    var spawnInterval: Double {
        get {
            if let s = ProcessInfo.processInfo.environment["CAMP_SPAWN_INTERVAL"], let v = Double(s), v > 0 { return v }
            return number("spawnInterval") ?? 10
        }
        set { defaults.set(newValue, forKey: "spawnInterval") }
    }

    /// The cap is remembered per character.
    private var maxAntsKey: String { "maxAnts.\(Characters.current.id)" }

    var maxAnts: Int {
        get { number(maxAntsKey, argument: "maxAnts").map { Int($0) } ?? Characters.current.defaultMaxCount }
        set { defaults.set(newValue, forKey: maxAntsKey) }
    }

    /// Size and walking speed are fixed at their defaults; only a command-line override (`-antScale 1.5`,
    /// `-speedMultiplier 2`) changes them, which is handy for testing. Stored values are ignored.
    var antScale: Double { number("antScale", argument: "antScale", storedIgnored: true) ?? 1.0 }
    var speedMultiplier: Double { number("speedMultiplier", argument: "speedMultiplier", storedIgnored: true) ?? 1.0 }

    /// Drawn width in points of the custom nest picture.
    var nestImageWidth: Double {
        get { number("nestImageWidth") ?? 48 }
        set { defaults.set(newValue, forKey: "nestImageWidth") }
    }

    /// Which camp look is in use: one of the built-in ids ("mound", "cave", "stump", "tent") or "custom" for the
    /// player's own picture. Someone who already had their own picture keeps it.
    var campID: String {
        get { defaults.string(forKey: "camp") ?? (NestImageStore.image != nil ? Camps.customID : "mound") }
        set { defaults.set(newValue, forKey: "camp") }
    }

    /// Which character is on screen ("goblin", "ants", or a user-made one).
    var characterID: String {
        get { defaults.string(forKey: "character") ?? "goblin" }
        set { defaults.set(newValue, forKey: "character") }
    }

    var saveProgress: Bool {
        // `CAMP_NO_SAVE` keeps test runs away from the real save file.
        get { ProcessInfo.processInfo.environment["CAMP_NO_SAVE"] == nil && (defaults.object(forKey: "saveProgress") as? Bool ?? true) }
        set { defaults.set(newValue, forKey: "saveProgress") }
    }
}
