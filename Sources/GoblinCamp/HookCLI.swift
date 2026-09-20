import AppKit

/// `GoblinCamp --hook ask|notify <kind>`: what Claude Code's hooks run. It hands the event to the running game
/// (through `goblincamp://` links and small files) and, for questions, prints Claude Code's answer JSON.
/// Never starts the game itself, and prints nothing (so Claude Code carries on as usual) when the game is not there,
/// is silent, or nobody answers.
enum HookCLI {
    private static let terminalApps = [
        "Apple_Terminal": "com.apple.Terminal", "iTerm.app": "com.googlecode.iterm2", "vscode": "com.microsoft.VSCode",
        "WarpTerminal": "dev.warp.Warp-Stable", "ghostty": "com.mitchellh.ghostty", "WezTerm": "com.github.wez.wezterm",
    ]
    static let maxWait = 60.0

    static func run(_ args: [String]) -> Never {
        // `CAMP_HOOK_TEST_ID`: tests write the answer files themselves, so no game is needed and no link is opened
        let testID = ProcessInfo.processInfo.environment["CAMP_HOOK_TEST_ID"]
        guard args.count >= 2, testID != nil || gameIsRunning() else { exit(0) }
        let mode = args[0], kind = args[1]
        let input = FileHandle.standardInput.readDataToEndOfFile()
        let event = (try? JSONSerialization.jsonObject(with: input)) as? [String: Any] ?? [:]
        let project = ((event["cwd"] as? String) ?? "").split(separator: "/").last.map(String.init) ?? ""
        let app = terminalApps[ProcessInfo.processInfo.environment["TERM_PROGRAM"] ?? ""] ?? ""
        if mode == "notify" {
            open("goblincamp://notify", ["kind": kind == "permission" ? "permission" : "done", "project": project, "app": app])
            exit(0)
        }
        if mode == "ask" { ask(kind: kind, event: event, project: project, app: app) }
        exit(0)
    }

    private static func gameIsRunning() -> Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "dev.goblincamp.game").isEmpty
    }

    private static func open(_ base: String, _ query: [String: String]) {
        var components = URLComponents(string: base)!
        components.queryItems = query.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
        guard let url = components.url else { return }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-g", url.absoluteString]
        try? process.run()
        process.waitUntilExit()
    }

    private static func squash(_ text: String, limit: Int = 90) -> String {
        let flat = text.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
        return flat.count <= limit ? flat : String(flat.prefix(limit - 1)) + "…"
    }

    /// A short line about what Claude wants to do.
    private static func summary(_ event: [String: Any]) -> String {
        let tool = (event["tool_name"] as? String) ?? ""
        let input = (event["tool_input"] as? [String: Any]) ?? [:]
        func name(_ key: String) -> String { ((input[key] as? String) ?? "").split(separator: "/").last.map(String.init) ?? "" }
        switch tool {
        case "Bash": return "執行：" + squash((input["command"] as? String) ?? "")
        case "Edit", "Write", "MultiEdit": return "修改：" + name("file_path")
        case "NotebookEdit": return "修改：" + name("notebook_path")
        case "Read": return "讀取：" + name("file_path")
        case "WebFetch", "WebSearch": return "上網：" + squash((input["url"] as? String) ?? (input["query"] as? String) ?? "")
        default: return squash(tool)
        }
    }

    /// What Claude Code itself would offer as "don't ask again" (its `permission_suggestions`), kept to the kinds we can describe
    /// in one line, and limited to this conversation (`session`) so nothing is written to anyone's settings files.
    private static func rememberable(_ event: [String: Any]) -> (updates: [[String: Any]], text: String) {
        var updates: [[String: Any]] = []
        var parts: [String] = []
        for suggestion in (event["permission_suggestions"] as? [[String: Any]]) ?? [] {
            switch suggestion["type"] as? String {
            case "addRules":
                guard (suggestion["behavior"] as? String) == "allow", let rules = suggestion["rules"] as? [[String: Any]], !rules.isEmpty else { continue }
                parts += rules.compactMap { rule in
                    guard let tool = rule["toolName"] as? String else { return nil }
                    if let content = rule["ruleContent"] as? String { return "\(tool)(\(content))" }
                    return tool
                }
            case "setMode":
                guard (suggestion["mode"] as? String) == "acceptEdits" else { continue }
                parts.append("自動允許修改檔案")
            case "addDirectories":
                guard let dirs = suggestion["directories"] as? [String], !dirs.isEmpty else { continue }
                parts.append("可存取 " + dirs.map { ($0 as NSString).lastPathComponent }.joined(separator: "、"))
            default:
                continue
            }
            var update = suggestion
            update["destination"] = "session"
            updates.append(update)
        }
        return (updates, squash(parts.joined(separator: "；"), limit: 60))
    }

    private static func ask(kind: String, event: [String: Any], project: String, app: String) -> Never {
        let testID = ProcessInfo.processInfo.environment["CAMP_HOOK_TEST_ID"]
        let id = testID ?? UUID().uuidString
        var dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("GoblinCamp/replies")
        if let custom = ProcessInfo.processInfo.environment["CAMP_DATA_DIR"] { dir = URL(fileURLWithPath: custom).appendingPathComponent("replies") }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let ack = dir.appendingPathComponent("\(id).ack"), answer = dir.appendingPathComponent("\(id).json")
        let remembered = kind == "permission" ? rememberable(event) : (updates: [], text: "")
        if testID == nil {
            open("goblincamp://ask", ["kind": kind == "permission" ? "permission" : "reply", "id": id, "project": project, "app": app,
                                      "text": kind == "permission" ? summary(event) : "", "remember": remembered.text, "wait": String(Int(maxWait))])
        }
        // the game must confirm quickly, otherwise do not hold Claude Code up
        var deadline = Date().addingTimeInterval(4)
        while Date() < deadline, !FileManager.default.fileExists(atPath: ack.path) { Thread.sleep(forTimeInterval: 0.1) }
        guard FileManager.default.fileExists(atPath: ack.path) else { exit(0) }
        deadline = Date().addingTimeInterval(maxWait)
        while Date() < deadline, !FileManager.default.fileExists(atPath: answer.path) { Thread.sleep(forTimeInterval: 0.2) }
        let reply = (try? Data(contentsOf: answer)).flatMap { try? JSONSerialization.jsonObject(with: $0) } as? [String: Any] ?? [:]
        try? FileManager.default.removeItem(at: ack)
        try? FileManager.default.removeItem(at: answer)

        var output: [String: Any]?
        switch (kind, (reply["action"] as? String) ?? "none") {
        case ("permission", "allow"):
            output = ["hookSpecificOutput": ["hookEventName": "PermissionRequest", "decision": ["behavior": "allow"]]]
        case ("permission", "allowRemember"):
            var decision: [String: Any] = ["behavior": "allow"]
            if !remembered.updates.isEmpty { decision["updatedPermissions"] = remembered.updates }
            output = ["hookSpecificOutput": ["hookEventName": "PermissionRequest", "decision": decision]]
        case ("permission", "deny"):
            output = ["hookSpecificOutput": ["hookEventName": "PermissionRequest",
                                             "decision": ["behavior": "deny", "message": "使用者在哥布林泡泡上拒絕了這個操作"]]]
        case (_, "reply"):
            if let text = reply["text"] as? String, !text.isEmpty, kind != "permission" {
                output = ["decision": "block", "reason": "使用者從哥布林泡泡回覆：" + text]
            }
        default: break
        }
        if let output, let data = try? JSONSerialization.data(withJSONObject: output, options: [.withoutEscapingSlashes]),
           let text = String(data: data, encoding: .utf8) {
            print(text)
        }
        exit(0)
    }
}
