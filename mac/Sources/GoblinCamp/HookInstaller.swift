import Foundation

struct HookError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

/// Connects Claude Code to the game from the menu: writes a small wrapper script and adds hooks to
/// `~/.claude/settings.json` (after backing it up); can take them out again. Nothing else in the file is touched.
enum HookInstaller {
    enum Style { case interactive, simple }
    enum Status: Equatable {
        case notInstalled
        case interactive
        case simple
        /// Installed, but the game has moved or an older version wrote it: installing again fixes it.
        case needsUpdate
    }

    private static let markers = ["goblincamp-hook.sh", "goblin-notify.sh", "goblin-ask.sh"]
    private static let events = ["Notification", "Stop", "PermissionRequest", "UserPromptSubmit", "PreToolUse"]

    /// `CAMP_CLAUDE_DIR` points tests at another folder, so the real settings are never touched.
    static var claudeDir: URL {
        if let custom = ProcessInfo.processInfo.environment["CAMP_CLAUDE_DIR"] { return URL(fileURLWithPath: custom) }
        return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude")
    }
    static var settingsURL: URL { claudeDir.appendingPathComponent("settings.json") }
    static var backupURL: URL { claudeDir.appendingPathComponent("settings.json.bak-goblincamp") }
    static var wrapperURL: URL { claudeDir.appendingPathComponent("hooks/goblincamp-hook.sh") }

    private static func shellQuote(_ s: String) -> String { "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'" }

    private static func wrapperText(executable: String) -> String {
        """
        #!/bin/sh
        # Written by GoblinCamp (menu: 連接 Claude Code). Hands Claude Code's hook events to the game; does nothing if the game is gone.
        # "pulse": Claude is at work (start / a tool / stop) for the camp's scribe. Shell built-ins only (no program is started), so it
        # costs Claude Code nothing: one small file per session in the game's folder, which the game looks at.
        if [ "$1" = "pulse" ]; then
          D="$HOME/Library/Application Support/GoblinCamp/claude"
          [ -d "$D" ] || exit 0
          IFS= read -r line
          q='"'
          s=${line#*${q}session_id${q}:${q}}
          [ "$s" = "$line" ] && s=${line#*${q}session_id${q}: ${q}}
          [ "$s" = "$line" ] && exit 0
          s=${s%%${q}*}
          case "$s" in ""|*/*|*" "*|.*) exit 0 ;; esac
          case "$2" in
            start) echo "$PWD" > "$D/$s" ;;
            tool) [ -f "$D/$s" ] || echo "$PWD" > "$D/$s"; : > "$D/$s.tool" ;;
            stop) [ -f "$D/$s" ] && : > "$D/$s.done" ;;
          esac
          exit 0
        fi
        APP=\(shellQuote(executable))
        [ -x "$APP" ] || exit 0
        exec "$APP" --hook "$@"
        """ + "\n"
    }

    private static func readSettings() throws -> [String: Any] {
        guard FileManager.default.fileExists(atPath: settingsURL.path) else { return [:] }
        let data = try Data(contentsOf: settingsURL)
        if data.allSatisfy({ $0 == 0x20 || $0 == 0x0A || $0 == 0x0D || $0 == 0x09 }) { return [:] }
        guard let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            throw HookError(message: "\(settingsURL.path) 不是正確的 JSON，為了安全起見我沒有修改它。請先修好或刪掉再試一次。")
        }
        return object
    }

    private static func write(_ root: [String: Any]) throws {
        try FileManager.default.createDirectory(at: claudeDir, withIntermediateDirectories: true)
        let data = try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
        try data.write(to: settingsURL, options: .atomic)
    }

    /// Takes our hooks out of a `hooks` dictionary, leaving everyone else's alone.
    private static func stripOurs(_ hooks: inout [String: Any]) {
        for event in events {
            guard var groups = hooks[event] as? [[String: Any]] else { continue }
            for i in groups.indices {
                let inner = (groups[i]["hooks"] as? [[String: Any]]) ?? []
                groups[i]["hooks"] = inner.filter { hook in !markers.contains { ((hook["command"] as? String) ?? "").contains($0) } }
            }
            groups.removeAll { (($0["hooks"] as? [[String: Any]]) ?? []).isEmpty }
            if groups.isEmpty { hooks.removeValue(forKey: event) } else { hooks[event] = groups }
        }
    }

    static func install(_ style: Style, executable: String? = nil) throws {
        guard let exe = executable ?? Bundle.main.executablePath else { throw HookError(message: "找不到遊戲的執行檔位置") }
        var root = try readSettings()
        let fm = FileManager.default
        if fm.fileExists(atPath: settingsURL.path) {
            try? fm.removeItem(at: backupURL)
            try fm.copyItem(at: settingsURL, to: backupURL)
        }
        try fm.createDirectory(at: wrapperURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try wrapperText(executable: exe).write(to: wrapperURL, atomically: true, encoding: .utf8)
        try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: wrapperURL.path)

        var hooks = (root["hooks"] as? [String: Any]) ?? [:]
        stripOurs(&hooks)
        let wrapper = shellQuote(wrapperURL.path)
        var plan: [(event: String, matcher: String?, command: String, timeout: Int?)]
        switch style {
        case .interactive:
            // (a question may be passed to the phone and wait up to 10 minutes: AppDelegate.relayWait)
            plan = [("PermissionRequest", nil, "\(wrapper) ask permission", askTimeout), ("Stop", nil, "\(wrapper) ask reply", askTimeout),
                    ("Notification", "idle_prompt|elicitation_dialog", "\(wrapper) notify permission", nil)]
        case .simple:
            plan = [("Notification", nil, "\(wrapper) notify permission", nil), ("Stop", nil, "\(wrapper) notify done", nil)]
        }
        // the scribe at its desk in the camp (Scribe.swift): quick, waits for nothing
        plan += [("UserPromptSubmit", nil, "\(wrapper) pulse start", 5), ("PreToolUse", nil, "\(wrapper) pulse tool", 5), ("Stop", nil, "\(wrapper) pulse stop", 5)]
        for item in plan {
            var hook: [String: Any] = ["type": "command", "command": item.command]
            if let timeout = item.timeout { hook["timeout"] = timeout }
            var group: [String: Any] = ["hooks": [hook]]
            if let matcher = item.matcher { group["matcher"] = matcher }
            hooks[item.event] = ((hooks[item.event] as? [[String: Any]]) ?? []) + [group]
        }
        root["hooks"] = hooks
        try write(root)
    }

    /// Claude Code's time limit for our question hooks (seconds): long enough for an answer from the phone.
    static let askTimeout = 620

    /// The time limit the installed question hook has (nil: none installed); older versions set 70.
    static func installedAskTimeout() -> Int? {
        guard let root = try? readSettings(), let hooks = root["hooks"] as? [String: Any] else { return nil }
        for group in (hooks["PermissionRequest"] as? [[String: Any]]) ?? [] {
            for hook in (group["hooks"] as? [[String: Any]]) ?? [] {
                if let command = hook["command"] as? String, markers.contains(where: { command.contains($0) }) { return hook["timeout"] as? Int }
            }
        }
        return nil
    }

    static func uninstall() throws {
        var root = try readSettings()
        if FileManager.default.fileExists(atPath: settingsURL.path) {
            try? FileManager.default.removeItem(at: backupURL)
            try FileManager.default.copyItem(at: settingsURL, to: backupURL)
            var hooks = (root["hooks"] as? [String: Any]) ?? [:]
            stripOurs(&hooks)
            if hooks.isEmpty { root.removeValue(forKey: "hooks") } else { root["hooks"] = hooks }
            try write(root)
        }
        try? FileManager.default.removeItem(at: wrapperURL)
    }

    static func status(executable: String? = nil) -> Status {
        guard let root = try? readSettings(), let hooks = root["hooks"] as? [String: Any] else { return .notInstalled }
        var commands: [(event: String, command: String)] = []
        for event in events {
            for group in (hooks[event] as? [[String: Any]]) ?? [] {
                for hook in (group["hooks"] as? [[String: Any]]) ?? [] {
                    if let command = hook["command"] as? String, markers.contains(where: { command.contains($0) }) { commands.append((event, command)) }
                }
            }
        }
        guard !commands.isEmpty else { return .notInstalled }
        // an older version wrote the project's scripts: install again to switch to the current wrapper
        guard commands.allSatisfy({ $0.command.contains("goblincamp-hook.sh") }) else { return .needsUpdate }
        let exe = executable ?? Bundle.main.executablePath ?? ""
        let wrapper = (try? String(contentsOf: wrapperURL, encoding: .utf8)) ?? ""
        guard wrapper.contains(shellQuote(exe)), wrapper.contains("pulse"), commands.contains(where: { $0.command.hasSuffix("pulse tool") }) else { return .needsUpdate } // (the scribe came later)
        return commands.contains { $0.event == "PermissionRequest" } ? .interactive : .simple
    }
}
