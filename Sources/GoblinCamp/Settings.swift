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

    /// How fast the game moves along, tied to how fast goblins are born: 1 at one goblin every three minutes, faster when they are born faster
    /// (so the first monsters, the young growing up, the crops and the trees all keep pace with the size of the camp), and slower when slower.
    /// Weather and the seasons do not follow it. Kept between a quarter and four times; `CAMP_PACE` fixes it (tests).
    var pace: Double {
        // read many times a frame, so it is worked out at most once a second
        let now = CACurrentMediaTime()
        if now - Settings.paceStamp > 1 || Settings.paceStamp == 0 {
            Settings.paceStamp = now
            if let v = Settings.paceOverride { Settings.paceCache = v } else { Settings.paceCache = min(4, max(0.25, 180 / max(1, spawnInterval))) }
        }
        return Settings.paceCache
    }
    private static var paceCache = 1.0
    private static var paceStamp = 0.0
    private static let paceOverride: Double? = ProcessInfo.processInfo.environment["CAMP_PACE"].flatMap(Double.init).flatMap { $0 > 0 ? $0 : nil }

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

    /// Claude notifications: a goblin (or the princess) pops up and speaks. On by default.
    var notifyEnabled: Bool {
        get { defaults.object(forKey: "notifyEnabled") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "notifyEnabled") }
    }
    /// Which events pop up: Claude waiting for a decision / Claude finished.
    func notifies(_ kind: NotifyKind) -> Bool {
        defaults.object(forKey: "notify.\(kind.rawValue)") as? Bool ?? true
    }
    func setNotifies(_ kind: NotifyKind, _ on: Bool) { defaults.set(on, forKey: "notify.\(kind.rawValue)") }
    /// 0 = silent (popups only), 1 quiet, 2 medium, 3 loud.
    var notifyVolume: Int {
        get { min(3, max(0, defaults.object(forKey: "notifyVolume") as? Int ?? 2)) }
        set { defaults.set(newValue, forKey: "notifyVolume") }
    }

    /// The pomodoro lengths in minutes that the custom entry remembers.
    var pomodoroFocus: Double {
        get { min(99, max(1, defaults.object(forKey: "pomodoroFocus") as? Double ?? 25)) }
        set { defaults.set(newValue, forKey: "pomodoroFocus") }
    }
    var pomodoroRounds: Int {
        get { min(12, max(1, defaults.object(forKey: "pomodoroRounds") as? Int ?? 4)) }
        set { defaults.set(newValue, forKey: "pomodoroRounds") }
    }
    var pomodoroLongRest: Double {
        get { min(60, max(0, defaults.object(forKey: "pomodoroLongRest") as? Double ?? 15)) }
        set { defaults.set(newValue, forKey: "pomodoroLongRest") }
    }
    var pomodoroRest: Double {
        get { min(60, max(0, defaults.object(forKey: "pomodoroRest") as? Double ?? 5)) }
        set { defaults.set(newValue, forKey: "pomodoroRest") }
    }

    /// Where the pomodoro clock and the Claude popups appear: "cursor" (the screen the mouse is on), "main", or a screen's name.
    var alertScreen: String {
        get { defaults.string(forKey: "alertScreen") ?? "cursor" }
        set { defaults.set(newValue, forKey: "alertScreen") }
    }
    /// A full-screen window (video, slideshow) counts as focus mode: everything goes quiet.
    var fullscreenFocus: Bool {
        get {
            if let forced = ProcessInfo.processInfo.environment["CAMP_FULLSCREEN_FOCUS"] { return forced != "0" } // tests
            return defaults.object(forKey: "fullscreenFocus") as? Bool ?? true
        }
        set { defaults.set(newValue, forKey: "fullscreenFocus") }
    }

    /// The mode the app starts in (and returns to when a timed mode runs out): "normal", "work", "saver" or "focus".
    /// The environment variable `CAMP_START_MODE` overrides it (for tests).
    var startupMode: String {
        get {
            if let forced = ProcessInfo.processInfo.environment["CAMP_START_MODE"] { return forced }
            return defaults.string(forKey: "startupMode") ?? "work"
        }
        set { defaults.set(newValue, forKey: "startupMode") }
    }
    /// How long a mode chosen from the menu lasts, in seconds; 0 = until the player changes it.
    var modeDuration: Double {
        get { defaults.object(forKey: "modeDuration") as? Double ?? 0 }
        set { defaults.set(newValue, forKey: "modeDuration") }
    }
    /// Starting a pomodoro from the everything-on mode switches to work mode until it is over.
    var pomodoroWorkMode: Bool {
        get { defaults.object(forKey: "pomodoroWorkMode") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "pomodoroWorkMode") }
    }
    /// When the pomodoro rests and it switched to work mode by itself, open the camp again for the campfire party.
    var pomodoroRestParty: Bool {
        get { defaults.object(forKey: "pomodoroRestParty") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "pomodoroRestParty") }
    }
    /// The ⌃⌥1–4 shortcuts for the four modes.
    var hotkeysEnabled: Bool {
        get { defaults.object(forKey: "hotkeysEnabled") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "hotkeysEnabled") }
    }

    /// Popups can be answered right there (allow/deny, or a typed reply that goes back to Claude Code).
    var askEnabled: Bool {
        get { defaults.object(forKey: "askEnabled") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "askEnabled") }
    }
    /// How long a question popup waits for an answer, in seconds, before Claude Code's own prompt takes over.
    var askWait: Double {
        get { min(120, max(5, defaults.object(forKey: "askWait") as? Double ?? 30)) }
        set { defaults.set(newValue, forKey: "askWait") }
    }

    /// Where the goblins may walk on their screen: "screen" (all of it), "bottom", "right", "left" (a strip of `rangeSize` points),
    /// or "window" (inside the little camp window).
    var rangeMode: String {
        get { defaults.string(forKey: "rangeMode") ?? "screen" }
        set { defaults.set(newValue, forKey: "rangeMode") }
    }
    var rangeSize: Double {
        get { min(64, max(30, defaults.object(forKey: "rangeSize") as? Double ?? 42)) }
        set { defaults.set(newValue, forKey: "rangeSize") }
    }
    /// The scenery in a strip or the map window: "forest", "meadow" or "none".
    var scenery: String {
        get { defaults.string(forKey: "scenery") ?? "forest" }
        set { defaults.set(newValue, forKey: "scenery") }
    }
    /// The camp window stays above other windows.
    var mapOnTop: Bool {
        get { defaults.object(forKey: "mapOnTop") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "mapOnTop") }
    }
    /// The player closed (folded away) the camp window.
    var mapCollapsed: Bool {
        get { defaults.object(forKey: "mapCollapsed") as? Bool ?? false }
        set { defaults.set(newValue, forKey: "mapCollapsed") }
    }
    var mapFrame: String? {
        get { defaults.string(forKey: "mapFrame") }
        set { defaults.set(newValue, forKey: "mapFrame") }
    }

    /// Which screens the goblins live on: "nest" (the camp's own screen, default), "all", or "list" (`screenNames`).
    var screenMode: String {
        get { defaults.string(forKey: "screenMode") ?? "nest" }
        set { defaults.set(newValue, forKey: "screenMode") }
    }
    var screenNames: [String] {
        get { (defaults.array(forKey: "screenNames") as? [String]) ?? [] }
        set { defaults.set(newValue, forKey: "screenNames") }
    }

    /// Now and then it rains in the camp (the goblins go and shelter in the nest).
    var weatherEnabled: Bool {
        get { defaults.object(forKey: "weatherEnabled") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "weatherEnabled") }
    }

    /// The goblins show on every desktop (Space), or only on the ones in `desktops`.
    var desktopsAll: Bool {
        get { defaults.object(forKey: "desktopsAll") as? Bool ?? false }
        set { defaults.set(newValue, forKey: "desktopsAll") }
    }
    /// Which desktops (1 = "桌面 1") show the goblins when `desktopsAll` is off. Desktop 1 by default.
    var desktops: [Int] {
        get { (defaults.array(forKey: "desktops") as? [Int]) ?? [1] }
        set { defaults.set(newValue, forKey: "desktops") }
    }

    /// How often animals turn up and trees grow by themselves: 0 off, 1 rarely, 2 normal, 3 often.
    /// The camp window's place: the seed it is made from (0 = not made yet) and which biome ("auto" = whatever the seed gives).
    var terrainSeed: UInt64 {
        get { UInt64(defaults.string(forKey: "terrainSeed") ?? "") ?? 0 }
        set { defaults.set(String(newValue), forKey: "terrainSeed") }
    }
    /// The place keeps changing over the days (seasons, puddles, growing trees, worn ground).
    var terrainAlive: Bool {
        get { defaults.object(forKey: "terrainAlive") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "terrainAlive") }
    }
    var terrainBiome: String {
        get { defaults.string(forKey: "terrainBiome") ?? "auto" }
        set { defaults.set(newValue, forKey: "terrainBiome") }
    }
    /// Hold goblins back automatically when drawing gets heavy (see `PerfGovernor`).
    var perfGuard: Bool {
        get { defaults.object(forKey: "perfGuard") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "perfGuard") }
    }
    /// How often monsters raid the camp: 0 never, 1 now and then, 2 (default) sometimes, 3 often.
    var monsters: Int {
        get { number("monsters", argument: "monsters").map { min(3, max(0, Int($0))) } ?? 2 }
        set { defaults.set(newValue, forKey: "monsters") }
    }
    var wildlife: Int {
        get { number("wildlife", argument: "wildlife").map { min(3, max(0, Int($0))) } ?? 2 }
        set { defaults.set(newValue, forKey: "wildlife") }
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
