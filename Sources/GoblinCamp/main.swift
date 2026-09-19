import AppKit

Migration.runIfNeeded() // before anything reads settings or saved files
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
