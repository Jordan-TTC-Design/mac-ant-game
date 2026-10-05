import AppKit

// Claude Code runs "GoblinCamp --hook …" for its hooks; that is a command-line helper, not the app.
if let index = CommandLine.arguments.firstIndex(of: "--hook") {
    HookCLI.run(Array(CommandLine.arguments[(index + 1)...]))
}

ExitLog.start()
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
