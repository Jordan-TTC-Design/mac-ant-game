import AppKit

enum AntColorTheme: String, CaseIterable {
    case black, brown, red

    var label: String {
        switch self {
        case .black: return "黑色"
        case .brown: return "褐色"
        case .red: return "紅色（火蟻）"
        }
    }

    var worker: NSColor {
        switch self {
        case .black: return NSColor(calibratedWhite: 0.06, alpha: 1)
        case .brown: return NSColor(calibratedRed: 0.36, green: 0.22, blue: 0.10, alpha: 1)
        case .red: return NSColor(calibratedRed: 0.72, green: 0.14, blue: 0.08, alpha: 1)
        }
    }

    var queen: NSColor {
        switch self {
        case .black: return NSColor(calibratedRed: 0.30, green: 0.08, blue: 0.08, alpha: 1)
        case .brown: return NSColor(calibratedRed: 0.22, green: 0.10, blue: 0.04, alpha: 1)
        case .red: return NSColor(calibratedRed: 0.45, green: 0.05, blue: 0.03, alpha: 1)
        }
    }
}

/// User-tunable options from the menu bar, persisted in UserDefaults.
final class Settings {
    static let shared = Settings()
    private let defaults = UserDefaults.standard

    /// Seconds between newborn ants. `ANT_SPAWN_INTERVAL` overrides it for quick testing.
    var spawnInterval: Double {
        get {
            if let s = ProcessInfo.processInfo.environment["ANT_SPAWN_INTERVAL"], let v = Double(s), v > 0 { return v }
            return defaults.object(forKey: "spawnInterval") as? Double ?? 10
        }
        set { defaults.set(newValue, forKey: "spawnInterval") }
    }

    var maxAnts: Int {
        get { defaults.object(forKey: "maxAnts") as? Int ?? 500 }
        set { defaults.set(newValue, forKey: "maxAnts") }
    }

    /// Multiplier on drawn ant size.
    var antScale: Double {
        get { defaults.object(forKey: "antScale") as? Double ?? 1.0 }
        set { defaults.set(newValue, forKey: "antScale") }
    }

    /// Multiplier on walking speed.
    var speedMultiplier: Double {
        get { defaults.object(forKey: "speedMultiplier") as? Double ?? 1.0 }
        set { defaults.set(newValue, forKey: "speedMultiplier") }
    }

    var colorTheme: AntColorTheme {
        get { AntColorTheme(rawValue: defaults.string(forKey: "colorTheme") ?? "") ?? .black }
        set { defaults.set(newValue.rawValue, forKey: "colorTheme") }
    }

    /// Drawn width in points of the custom nest picture.
    var nestImageWidth: Double {
        get { defaults.object(forKey: "nestImageWidth") as? Double ?? 48 }
        set { defaults.set(newValue, forKey: "nestImageWidth") }
    }

    var saveProgress: Bool {
        // `ANT_NO_SAVE` keeps test runs away from the real save file.
        get { ProcessInfo.processInfo.environment["ANT_NO_SAVE"] == nil && (defaults.object(forKey: "saveProgress") as? Bool ?? true) }
        set { defaults.set(newValue, forKey: "saveProgress") }
    }
}
