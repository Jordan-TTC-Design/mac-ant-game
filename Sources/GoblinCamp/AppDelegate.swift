import AppKit
import UniformTypeIdentifiers
import ServiceManagement

/// Menu item that runs a closure and can report a checkmark state.
final class ClosureMenuItem: NSMenuItem {
    var handler: (() -> Void)?
    var stateProvider: (() -> Bool)?

    init(title: String, handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(fire), keyEquivalent: "")
        target = self
    }

    required init(coder: NSCoder) { fatalError("not used") }

    @objc private func fire() { handler?() }
}

/// A see-through view that reports clicks (and shows a pointing hand).
final class ClickCatcher: NSView {
    var onClick: (() -> Void)?
    override func mouseDown(with event: NSEvent) { onClick?() }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func resetCursorRects() { addCursorRect(bounds, cursor: .pointingHand) }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private var windows: [OverlayWindow] = []
    private let colony = Colony()
    private let settings = Settings.shared
    private var frameTimer: Timer?
    private var lastTick = Date()
    private var currentFPS = 30.0
    private var lastCursor: CGPoint?
    private var cursorSpeed = 0.0
    private var clickMonitor: Any?
    private var keyMonitor: Any?
    private var pickItem: ClosureMenuItem!
    private var editItem: ClosureMenuItem!
    private var foodMenuItem: NSMenuItem!
    private var clearFoodItem: ClosureMenuItem!
    private var nestMenuItem: NSMenuItem!
    private var customSpawnItem: ClosureMenuItem!
    private var characterMenuItem: NSMenuItem!
    /// While set, the goblins are hidden and the camp is frozen (a meeting, focused work). `nil` = visible.
    private var hiddenUntil: Date?
    /// The four ways to run: everything on (nil), 工作模式 work (camp hidden but running in the background, pomodoro and popups on),
    /// 節能模式 saver (camp hidden and paused, pomodoro and popups on), 專注模式 focus (everything hidden, silent and paused).
    private var userMode: QuietMode?
    enum QuietMode {
        case work, saver, focus
        var name: String { self == .work ? "工作模式" : (self == .saver ? "節能模式" : "專注模式") }
    }
    /// A full-screen window (video, slideshow) is up: counts as focus mode while the setting is on.
    private var fullscreenActive = false
    private var fullscreenTimer: Timer?
    private var wasFrozen = false
    private var hideTimer: Timer?
    /// Claude notifications that came while the goblins were hidden (silently dropped, but counted).
    private var missedNotifications = 0
    private var lastNotify: [NotifyKind: Date] = [:]
    private var pomodoroStatusItem: NSMenuItem!
    private var pomodoroStopItem: ClosureMenuItem!
    private var pomodoroTodayItem: NSMenuItem!
    private var pomodoroSpeaker = Speakers.common
    private var modeMenuItems: [ClosureMenuItem] = []
    /// What happened while the camp was away (hidden), for the summary when it comes back.
    private var away: (since: Date, ants: Int, deaths: Int, missed: Int)?
    /// The pomodoro switched the mode by itself, so it should switch it back when it is over.
    private var pomodoroChangedMode = false
    private var flashTimer: Timer?
    private var quietStatusItem: NSMenuItem!
    private var alertScreenItem: NSMenuItem!
    private var rosterItem: ClosureMenuItem!
    private lazy var roster: RosterPanel = {
        let panel = RosterPanel(colony: colony)
        panel.onSelectionChanged = { [weak self] in self?.redrawAll() }
        return panel
    }()
    private var capMenuItem: NSMenuItem!
    private let countItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private var pauseItem: ClosureMenuItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        colony.stage.onArrive = { [weak self] message in
            guard let self else { return }
            if ProcessInfo.processInfo.environment["CAMP_DEBUG"] != nil { NSLog("GoblinCamp: \(message.speaker.name) says \"\(message.text)\" (\(message.kind.rawValue))") }
            if !message.silent { GoblinVoice.shared.speak(message.text, as: message.speaker, level: self.settings.notifyVolume) }
        }
        colony.pomodoro.onEvent = { [weak self] event in self?.pomodoroEvent(event) }
        setupMenuBar()
        rebuildOverlays()
        startFullscreenWatch()
        purgeOldReplies()

        // Resume a saved colony if its nest is still on a screen; otherwise start at nest-picking.
        if settings.saveProgress, let saved = Persistence.load() {
            let nest = CGPoint(x: saved.nestX, y: saved.nestY)
            if colony.walkable.contains(where: { $0.contains(nest) }) {
                colony.restore(nest: nest, saved: saved)
                if ProcessInfo.processInfo.environment["CAMP_DEBUG"] != nil { NSLog("GoblinCamp: restored \(colony.ants.count) ants") }
            }
        }

        colony.onChange = { [weak self] in
            self?.syncWindows()
            self?.persist()
            if self?.colony.needsPrincessName == true { DispatchQueue.main.async { self?.nameThePrincess(firstTime: true) } }
        }
        colony.onAntsChanged = { [weak self] in
            self?.updateCount()
            self?.persist()
        }
        syncWindows()
        updateCount()
        startFrameTimer()
        // a camp from before names existed: ask once, soon after the app is up
        if colony.nest != nil, colony.princessName.isEmpty { DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in self?.nameThePrincess(firstTime: true) } }
        applyHotkeys()
        // rest in the chosen mode (a brand new camp starts with everything on, so the first nest can be picked and watched)
        if colony.nest != nil || ProcessInfo.processInfo.environment["CAMP_START_MODE"] != nil, let mode = baseMode {
            setMode(mode, automatic: true)
        }
        scheduleSnapshot()
        // Ages change all the time, so save now and then even when nothing else happens.
        Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in self?.persist() }
        scheduleUITests()

        // Esc cancels nest picking; Esc or Return finishes editing. (A local monitor: no permission needed.)
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            let esc = event.keyCode == 53
            let done = esc || event.keyCode == 36 || event.keyCode == 76 // Esc, Return, keypad Enter
            switch self.colony.phase {
            case .choosingNest where esc:
                self.colony.cancelPicking()
                return nil
            case .editing where done:
                self.colony.endEditing()
                return nil
            case .placingFood where esc:
                self.colony.cancelPlacingFood()
                return nil
            default:
                return event
            }
        }

        // Clicks on the nest (which land on whatever app is underneath) make the queen duck and peek.
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] _ in
            guard let self, self.colony.phase == .running, !self.colony.isPaused, let nest = self.colony.nest else { return }
            let click = NSEvent.mouseLocation
            if hypot(click.x - nest.x, click.y - nest.y) < 26 { self.colony.pokeNest() }
        }

        // Plugging or unplugging a display, or changing its resolution: rebuild the overlays.
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil,
                                               queue: .main) { [weak self] _ in
            self?.rebuildOverlays()
            self?.syncWindows()
        }

        // Test hook: skip nest-picking by dropping the nest at the centre of the main screen.
        if colony.phase == .choosingNest, ProcessInfo.processInfo.environment["CAMP_AUTO_NEST"] != nil, let f = NSScreen.main?.frame {
            colony.placeNest(at: CGPoint(x: f.midX, y: f.midY))
        }
    }

    /// Test hook: `CAMP_SNAPSHOT=/path/prefix` saves the overlay (composited on grey, cropped around the nest) after a delay.
    private func scheduleSnapshot() {
        guard let prefix = ProcessInfo.processInfo.environment["CAMP_SNAPSHOT"] else { return }
        let delays = (ProcessInfo.processInfo.environment["CAMP_SNAPSHOT_AFTER"] ?? "20").split(separator: ",").compactMap { Double($0) }
        let delay = delays.first ?? 20
        if let forced = ProcessInfo.processInfo.environment["CAMP_QUEEN_FORCE"] {
            let lead = forced == "digging" ? 4.5 : 1.2
            DispatchQueue.main.asyncAfter(deadline: .now() + max(0, delay - lead)) { [weak self] in
                self?.colony.debugForceQueen(forced)
            }
        }
        let full = ProcessInfo.processInfo.environment["CAMP_SNAPSHOT_FULL"] != nil
        for (n, when) in delays.enumerated() { DispatchQueue.main.asyncAfter(deadline: .now() + when) { [weak self] in
            guard let self else { return }
            let nest = self.colony.nest ?? CGPoint(x: NSScreen.main?.frame.midX ?? 0, y: NSScreen.main?.frame.midY ?? 0)
            for (i, window) in self.windows.enumerated() where window.frame.contains(nest) {
                guard let cg = CGWindowListCreateImage(.null, .optionIncludingWindow, CGWindowID(window.windowNumber),
                                                       [.boundsIgnoreFraming, .bestResolution]) else { continue }
                let scale = CGFloat(cg.width) / window.frame.width
                let half: CGFloat = 130
                // crop (image origin is top-left) around the nest, or keep the whole screen, then paint over grey
                let cx = (nest.x - window.frame.minX) * scale, cy = (window.frame.maxY - nest.y) * scale
                let rect = full ? CGRect(x: 0, y: 0, width: cg.width, height: cg.height)
                                : CGRect(x: cx - half * scale, y: cy - half * scale * 0.7, width: half * 2 * scale, height: half * 1.4 * scale)
                guard let crop = cg.cropping(to: rect) else { continue }
                let factor: CGFloat = full ? 0.5 : 2
                let out = NSImage(size: NSSize(width: CGFloat(crop.width) * factor, height: CGFloat(crop.height) * factor))
                out.lockFocus()
                NSColor(calibratedWhite: 0.85, alpha: 1).setFill()
                NSRect(origin: .zero, size: out.size).fill()
                NSImage(cgImage: crop, size: out.size).draw(in: NSRect(origin: .zero, size: out.size))
                out.unlockFocus()
                if let tiff = out.tiffRepresentation, let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) {
                    let path = delays.count > 1 ? "\(prefix)-\(n)-\(i).png" : "\(prefix)-\(i).png"
                    try? png.write(to: URL(fileURLWithPath: path))
                    NSLog("GoblinCamp: snapshot saved \(path)")
                }
            }
        }
        }
    }

    /// Test hooks that drive the UI with synthetic events, so the nest-picking and edit flows can be exercised
    /// without real mouse or keyboard input (which needs extra permissions):
    /// `CAMP_TEST_ESC=秒` presses Esc; `CAMP_TEST_EDIT=dx,dy` enters edit mode and drags the nest by (dx, dy), then Esc.
    private func scheduleUITests() {
        let env = ProcessInfo.processInfo.environment
        func after(_ seconds: Double, _ work: @escaping () -> Void) {
            DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: work)
        }
        func log(_ s: String) { NSLog("GoblinCamp test: \(s)") }
        func pressKey(_ code: UInt16, _ chars: String) {
            if let e = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                                        windowNumber: 0, context: nil, characters: chars, charactersIgnoringModifiers: chars,
                                        isARepeat: false, keyCode: code) { NSApp.postEvent(e, atStart: false) }
        }
        func mouse(_ type: NSEvent.EventType, at global: CGPoint, in window: NSWindow) {
            let local = CGPoint(x: global.x - window.frame.minX, y: global.y - window.frame.minY)
            if let e = NSEvent.mouseEvent(with: type, location: local, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                                          windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1) {
                NSApp.postEvent(e, atStart: false)
            }
        }

        if let s = env["CAMP_TEST_ROSTER"], let t = Double(s), let prefix = env["CAMP_SNAPSHOT"] { // open the roster, pick a goblin, capture it
            after(t) {
                self.roster.show()
                self.roster.select(row: 1)
                log("roster shown, selected goblin: \(String(describing: self.colony.selectedAntID))")
            }
            after(t + 1.5) {
                guard let cg = CGWindowListCreateImage(.null, .optionIncludingWindow, CGWindowID(self.roster.windowNumber), [.boundsIgnoreFraming, .bestResolution]) else { return log("roster capture failed") }
                let rep = NSBitmapImageRep(cgImage: cg)
                if let png = rep.representation(using: .png, properties: [:]) { try? png.write(to: URL(fileURLWithPath: "\(prefix)-roster.png")) }
                log("roster captured \(cg.width)x\(cg.height)")
            }
        }
        if env["CAMP_TEST_HIDE"] != nil { // hide for 2 s, and check the windows and the clock (CAMP_TEST_HIDE_AT = when, default 3 s)
            after(Double(env["CAMP_TEST_HIDE_AT"] ?? "") ?? 3) {
                let ticksBefore = self.colony.ants.count
                self.hide(env["CAMP_TEST_HIDE"] == "work" ? .work : .focus, for: 2)
                log("hidden: windows visible = \(self.windows.contains { $0.isVisible }), hidden flag = \(self.isHiddenByUser)")
                after(1) { log("still hidden: windows visible = \(self.windows.contains { $0.isVisible }), ants \(ticksBefore) -> \(self.colony.ants.count) (\(self.isFrozen ? "frozen" : "running in the background"))") }
                after(3) { log("after the timer: windows visible = \(self.windows.contains { $0.isVisible }), hidden flag = \(self.isHiddenByUser)") }
            }
        }
        if env["CAMP_TEST_MENU"] != nil { // print the menu the way it would look when opened
            after(2) {
                guard let menu = self.statusItem.menu else { return }
                self.menuNeedsUpdate(menu)
                func dump(_ menu: NSMenu, _ depth: Int) {
                    for item in menu.items where !item.isSeparatorItem {
                        log("menu: \(String(repeating: "  ", count: depth))\(item.title)\(item.isEnabled ? "" : "  (disabled)")")
                        if let sub = item.submenu { dump(sub, depth + 1) }
                    }
                }
                dump(menu, 0)
            }
        }
        if let s = env["CAMP_TEST_ESC"], let t = Double(s) {
            log("phase at start: \(colony.phase)")
            after(t) { pressKey(53, "\u{1b}") }
            after(t + 0.5) { log("phase after Esc: \(self.colony.phase), nest: \(String(describing: self.colony.nest))") }
        }
        if env["CAMP_TEST_FULLSCREEN"] != nil { // a window covering the whole screen for 5 s (at 4 s), like a full-screen video
            after(4) {
                guard let frame = NSScreen.screens.first?.frame else { return }
                let cover = NSWindow(contentRect: frame, styleMask: [.borderless], backing: .buffered, defer: false)
                cover.backgroundColor = .white
                cover.isOpaque = true
                cover.orderFrontRegardless()
                after(4.5) { log("with a full-screen window: mode \(String(describing: self.effectiveMode)), windows visible = \(self.windows.contains { $0.isVisible })") }
                after(5) { cover.close() }
                after(9) { log("after it closed: mode \(String(describing: self.effectiveMode)), windows visible = \(self.windows.contains { $0.isVisible })") }
            }
        }
        if let s = env["CAMP_TEST_MODE"] { // "work", "saver" or "focus" from 12 s on for 6 s; prints what is visible and whether the camp runs
            after(12) {
                let mode: QuietMode = s == "work" ? .work : (s == "saver" ? .saver : .focus)
                let before = self.colony.ants.count
                self.hide(mode, for: 6)
                self.notify(.done, project: "測試", appBundleID: nil)
                after(3) {
                    log("\(mode.name): windows visible = \(self.windows.contains { $0.isVisible }), camp hidden = \(self.colony.campHidden), goblins \(before) -> \(self.colony.ants.count), popup = \(self.colony.stage.isActive), missed = \(self.missedNotifications), fps \(self.currentFPS)")
                }
                after(8) { log("back to normal: mode \(String(describing: self.effectiveMode)), windows visible = \(self.windows.contains { $0.isVisible }), fps \(self.currentFPS)") }
            }
        }
        if let s = env["CAMP_TEST_MODELOG"] { // "4,8,20": print the mode, whether the camp is hidden and the menu bar title at those seconds
            for t in s.split(separator: ",").compactMap({ Double($0) }) {
                after(t) { log("t=\(t): mode \(String(describing: self.effectiveMode)), camp hidden \(self.colony.campHidden), windows visible \(self.windows.contains { $0.isVisible }), title '\(self.statusItem.button?.title ?? "")', popup \(self.colony.stage.current?.text ?? "-")") }
            }
        }
        if env["CAMP_TEST_AWAY"] != nil { after(12) { self.setMode(.work, for: 62) } } // work mode for just over a minute, to see the summary
        if env["CAMP_TEST_ASKFAKE"] != nil { // show a permission question with an "allow and remember" button, as if a hook had asked
            after(4) {
                self.handleAsk([URLQueryItem(name: "id", value: "test-\(UUID().uuidString)"), URLQueryItem(name: "kind", value: "permission"),
                                URLQueryItem(name: "project", value: "my-app"), URLQueryItem(name: "app", value: "com.apple.Terminal"),
                                URLQueryItem(name: "text", value: "執行：git push origin main"), URLQueryItem(name: "remember", value: "Bash(git push:*)")])
            }
        }
        if let path = env["CAMP_TEST_MANUAL"] { // open the manual and draw its window into a PNG
            after(2) {
                self.showManual()
                after(1) {
                    guard let view = self.manualWindow?.contentViewForTesting, let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
                    view.cacheDisplay(in: view.bounds, to: rep)
                    if let png = rep.representation(using: .png, properties: [:]) { try? png.write(to: URL(fileURLWithPath: path)) }
                    log("manual drawn")
                    NSApp.terminate(nil)
                }
            }
        }
        if env["CAMP_TEST_FSSPACE"] != nil { // a real full-screen Space (like a full-screen video): are our windows on screen in it?
            after(3) {
                let cover = NSWindow(contentRect: NSRect(x: 200, y: 200, width: 500, height: 300), styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
                cover.collectionBehavior = [.fullScreenPrimary]
                cover.title = "GoblinCamp test"
                cover.makeKeyAndOrderFront(nil)
                func ours() -> Int {
                    let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
                    return list.filter { ($0[kCGWindowOwnerPID as String] as? Int32) == getpid() && ($0[kCGWindowLayer as String] as? Int) != nil && ($0[kCGWindowName as String] as? String) != "GoblinCamp test" }.count
                }
                log("before full screen: overlay windows on the active Space: \(self.windows.filter { $0.isVisible && $0.isOnActiveSpace }.count) of \(self.windows.count)")
                cover.toggleFullScreen(nil)
                after(3.5) { log("in a full-screen Space: overlay windows on the active Space: \(self.windows.filter { $0.isVisible && $0.isOnActiveSpace }.count) of \(self.windows.count), mode \(String(describing: self.effectiveMode))") }
                after(4) { cover.toggleFullScreen(nil) }
                after(7.5) { log("back: overlay windows on the active Space: \(self.windows.filter { $0.isVisible && $0.isOnActiveSpace }.count)"); cover.close(); NSApp.terminate(nil) }
            }
        }
        if let s = env["CAMP_TEST_NAMES"] { // "set": rename the princess and the first goblin at 20 s and save; "show": print the names at 4 s
            if s == "set" {
                after(20) {
                    self.colony.princessName = "小茉"
                    if let first = self.colony.ants.first { self.colony.rename(antID: first.id, to: "波波") }
                    self.persist()
                    log("names set: princess \(self.colony.princessName), goblins \(self.colony.ants.map(\.name).prefix(3))")
                    NSApp.terminate(nil)
                }
            } else {
                after(4) { log("names loaded: princess '\(self.colony.princessName)', goblins \(self.colony.ants.map(\.name).prefix(3)), pending prompt \(self.colony.needsPrincessName)") ; NSApp.terminate(nil) }
            }
        }
        if let s = env["CAMP_TEST_STATS"], let t = Double(s) { after(t) { let x = Stats.shared.summary(); log("stats today: \(x.today) | week first line: \(x.week.split(separator: "\n").first ?? "")") } }
        if let s = env["CAMP_TEST_POMODORO"] { // "focusMinutes,restMinutes" (fractions allowed), started at 3 s
            let parts = s.split(separator: ",").compactMap { Double($0) }
            if parts.count == 2 { after(3) { self.startPomodoro(focus: parts[0], rest: parts[1]) } }
        }
        if let s = env["CAMP_TEST_HOOKINSTALL"] { // "interactive", "simple", "uninstall" or "status", against CAMP_CLAUDE_DIR
            after(1) {
                do {
                    switch s {
                    case "interactive": try HookInstaller.install(.interactive)
                    case "simple": try HookInstaller.install(.simple)
                    case "uninstall": try HookInstaller.uninstall()
                    default: break
                    }
                    log("hooks \(s): status \(HookInstaller.status())")
                } catch { log("hooks \(s) failed: \(error.localizedDescription)") }
                NSApp.terminate(nil)
            }
        }
        if let s = env["CAMP_TEST_ASKANSWER"] { // "allow", "deny", "look", "dismiss" or "reply:text", at CAMP_TEST_ASKAT seconds (default 8)
            after(Double(env["CAMP_TEST_ASKAT"] ?? "") ?? 8) {
                log("ask panel: \(self.askPanel != nil ? "showing, frame \(self.askPanel!.frame)" : "none")")
                let answer: AskAnswer
                switch s {
                case "allow": answer = .allow
                case "allowRemember": answer = .allowAndRemember
                case "deny": answer = .deny
                case "look": answer = .look
                case let r where r.hasPrefix("reply:"): answer = .reply(String(r.dropFirst(6)))
                default: answer = .dismiss
                }
                self.askPanel?.answer(answer)
            }
        }
        if let s = env["CAMP_TEST_CLICKMSG"], let t = Double(s) { // click the popup at t seconds (needs a popup with an app)
            after(t) {
                log("popup before click: \(String(describing: self.colony.stage.current?.phase)), panel visible: \(self.clickPanel?.isVisible ?? false), frame \(String(describing: self.clickPanel?.frame))")
                (self.clickPanel?.contentView as? ClickCatcher)?.onClick?()
                after(0.5) { log("after click: \(String(describing: self.colony.stage.current?.phase)), panel visible: \(self.clickPanel?.isVisible ?? false)") }
            }
        }
        if let s = env["CAMP_TEST_WILD"] { // "pig,300,80": an animal of that kind this far from the nest, plus a tree
            let parts = s.split(separator: ",")
            guard parts.count == 3, let kind = Animals.all.first(where: { $0.id == parts[0] }), let dx = Double(parts[1]), let dy = Double(parts[2]) else { return }
            after(4) {
                guard let nest = self.colony.nest else { return log("no nest") }
                self.colony.spawnTree(at: CGPoint(x: nest.x - 120, y: nest.y - 60))
                self.colony.debugSpawnCreature(kind: kind, at: CGPoint(x: nest.x + dx, y: nest.y + dy))
                for k in 1...60 {
                    after(Double(k) * 3) {
                        let c = self.colony
                        let modes = Dictionary(grouping: c.ants.map { String(describing: $0.mode).prefix(12) }, by: { $0 }).mapValues(\.count)
                        log("t+\(k * 3)s animals \(c.creatures.map { "\($0.kind.id) hp\($0.hp)" }) foods \(c.foods.map { "\($0.kind.rawValue)x\($0.amount)" }) slain \(c.slain) goblins \(c.ants.count) \(modes)")
                    }
                }
            }
        }
        if let s = env["CAMP_TEST_FOOD"] {
            let parts = s.split(separator: ",")
            guard parts.count == 3, let kind = FoodKind(rawValue: String(parts[0])), let dx = Double(parts[1]), let dy = Double(parts[2]) else { return }
            after(4) {
                guard let nest = self.colony.nest else { return log("no nest") }
                self.colony.beginPlacingFood(kind) // what the menu item does
                self.syncWindows()
                log("phase: \(self.colony.phase), window accepts input: \(self.windows.contains { !$0.ignoresMouseEvents })")
                let target = CGPoint(x: nest.x + dx, y: nest.y + dy)
                if let window = self.windows.first(where: { $0.frame.contains(target) }) {
                    mouse(.leftMouseDown, at: target, in: window)
                    after(0.2) { mouse(.leftMouseUp, at: target, in: window) }
                }
                after(0.5) { log("placed: \(self.colony.foods.map { "\($0.kind.rawValue)@\($0.pos) x\($0.amount)" }), phase \(self.colony.phase)") }
                for k in 1...40 { after(0.5 + Double(k) * 5) { log("t+\(k * 5)s \(self.colony.foodSummary())") } }
            }
            if env["CAMP_TEST_FOOD_CANCEL"] != nil { // press Esc while placing instead of clicking
                after(10) {
                    self.colony.beginPlacingFood(.water)
                    self.syncWindows()
                    log("placing again: phase \(self.colony.phase), pending \(String(describing: self.colony.pendingFood))")
                    after(2.5) { pressKey(53, "\u{1b}") } // leave the hint on screen long enough to be captured
                    after(3.0) { log("after Esc while placing: phase \(self.colony.phase), pending \(String(describing: self.colony.pendingFood))") }
                }
            }
        }
        if let s = env["CAMP_TEST_EDIT"] {
            let d = s.split(separator: ",").compactMap { Double($0) }
            guard d.count == 2 else { return }
            after(5) {
                guard let nest = self.colony.nest else { return log("no nest") }
                log("running, nest \(nest), ants \(self.colony.ants.count)")
                self.colony.beginEditing()
                self.syncWindows()
                log("phase: \(self.colony.phase)")
                guard let window = self.windows.first(where: { $0.frame.contains(nest) }) else { return }
                log("window accepts input: \(!window.ignoresMouseEvents)")
                mouse(.leftMouseDown, at: nest, in: window)
                after(0.3) { mouse(.leftMouseDragged, at: CGPoint(x: nest.x + d[0] / 2, y: nest.y + d[1] / 2), in: window) }
                after(0.6) { mouse(.leftMouseDragged, at: CGPoint(x: nest.x + d[0], y: nest.y + d[1]), in: window) }
                after(0.9) { mouse(.leftMouseUp, at: CGPoint(x: nest.x + d[0], y: nest.y + d[1]), in: window) }
                after(1.3) {
                    log("after drag, nest \(String(describing: self.colony.nest)), ants \(self.colony.ants.count), phase \(self.colony.phase)")
                    pressKey(53, "\u{1b}")
                }
                after(1.8) { log("after Esc, phase \(self.colony.phase)") }
                if env["CAMP_TEST_EDIT_HOLD"] != nil { // stay in edit mode for a screenshot
                    after(1.4) { self.colony.beginEditing(); self.syncWindows() }
                }
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        persist()
    }

    // MARK: Menu

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        applyStatusIcon()

        let menu = NSMenu()
        menu.delegate = self
        menu.autoenablesItems = false // enabled state of the game items is set in menuNeedsUpdate

        countItem.isEnabled = false
        menu.addItem(countItem)
        menu.addItem(.separator())

        pauseItem = ClosureMenuItem(title: "暫停") { [weak self] in
            guard let self else { return }
            self.colony.isPaused.toggle()
        }
        menu.addItem(pauseItem)
        pickItem = ClosureMenuItem(title: "重新選擇蟻窩（清空螞蟻）") { [weak self] in self?.colony.beginPicking() }
        menu.addItem(pickItem)
        editItem = ClosureMenuItem(title: "編輯蟻窩位置") { [weak self] in
            guard let self else { return }
            if self.colony.phase == .editing { self.colony.endEditing() } else { self.colony.beginEditing() }
        }
        menu.addItem(editItem)
        menu.addItem(foodMenu())
        rosterItem = ClosureMenuItem(title: "名冊…") { [weak self] in self?.roster.toggle() }
        menu.addItem(rosterItem)
        menu.addItem(ClosureMenuItem(title: "公主的名字…") { [weak self] in DispatchQueue.main.async { self?.nameThePrincess(firstTime: false) } })
        quietStatusItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        quietStatusItem.isEnabled = false
        menu.addItem(quietStatusItem)
        let modes: [(QuietMode?, String, String, String)] = [
            (nil, "全開", "1", "哥布林在畫面上活動，番茄鐘與通知都有"),
            (.work, "工作模式・營地在背景跑", "2", "營地藏起來但繼續運行；番茄鐘與 Claude 通知照常出現"),
            (.saver, "節能模式・營地暫停", "3", "營地藏起來並完全暫停（省效能）；番茄鐘與 Claude 通知照常出現"),
            (.focus, "專注模式・完全靜音", "4", "全部藏起來、暫停、不出聲；番茄鐘只計時。開會、簡報時用"),
        ]
        for (mode, title, key, tip) in modes {
            let item = ClosureMenuItem(title: title) { [weak self] in self?.chooseMode(mode) }
            item.keyEquivalent = key
            item.keyEquivalentModifierMask = [.control, .option]
            item.toolTip = tip
            item.stateProvider = { self.userMode == mode }
            modeMenuItems.append(item)
            menu.addItem(item)
        }
        menu.addItem(choiceMenu(title: "切換模式後持續", options: AppDelegate.durationChoices,
                                get: { self.settings.modeDuration }, set: { self.settings.modeDuration = $0 }))
        menu.addItem(choiceMenu(title: "啟動時的模式",
                                options: [("全開", "normal"), ("工作模式（預設）", "work"), ("節能模式", "saver"), ("專注模式", "focus")],
                                get: { self.settings.startupMode }, set: { self.settings.startupMode = $0 }))
        let hotkeys = ClosureMenuItem(title: "全域快捷鍵 ⌃⌥1～4 切換模式") { [weak self] in
            self?.settings.hotkeysEnabled.toggle()
            self?.applyHotkeys()
        }
        hotkeys.stateProvider = { self.settings.hotkeysEnabled }
        menu.addItem(hotkeys)
        menu.addItem(.separator())

        characterMenuItem = choiceMenu(title: "角色",
                                options: Characters.all.map { ($0.name, $0.id) },
                                get: { Characters.current.id }, set: { [weak self] in
                                    self?.settings.characterID = $0
                                    self?.characterChanged()
                                })
        characterMenuItem.isHidden = Characters.all.count <= 1 // nothing to choose from with a single character
        menu.addItem(characterMenuItem)
        menu.addItem(spawnMenu())
        menu.addItem(choiceMenu(title: "自然事件（動物、果樹）",
                                options: [("關閉", 0), ("少", 1), ("普通", 2), ("多", 3)],
                                get: { self.settings.wildlife }, set: { self.settings.wildlife = $0 }))
        capMenuItem = choiceMenu(title: "數量上限",
                                 options: [("50 隻", 50), ("100 隻", 100), ("150 隻", 150), ("300 隻", 300), ("500 隻", 500), ("1000 隻", 1000)],
                                 get: { self.settings.maxAnts }, set: { self.settings.maxAnts = $0 })
        menu.addItem(capMenuItem)
        menu.addItem(nestImageMenu())
        menu.addItem(pomodoroMenu())
        menu.addItem(notifyMenu())
        menu.addItem(claudeConnectMenu())
        alertScreenItem = NSMenuItem(title: "提醒顯示的螢幕", action: nil, keyEquivalent: "")
        alertScreenItem.submenu = NSMenu(title: "提醒顯示的螢幕")
        menu.addItem(alertScreenItem)
        desktopMenuItem = NSMenuItem(title: "哥布林出現在哪個桌面", action: nil, keyEquivalent: "")
        desktopMenuItem.submenu = NSMenu(title: "哥布林出現在哪個桌面")
        menu.addItem(desktopMenuItem)
        let fullscreen = ClosureMenuItem(title: "全螢幕時自動專注（影片、簡報）") { [weak self] in
            guard let self else { return }
            self.settings.fullscreenFocus.toggle()
            if !self.settings.fullscreenFocus, self.fullscreenActive { self.fullscreenActive = false; self.applyQuietState() }
        }
        fullscreen.stateProvider = { self.settings.fullscreenFocus }
        menu.addItem(fullscreen)
        menu.addItem(launchAtLoginItem())
        menu.addItem(ClosureMenuItem(title: "每日統計…") { [weak self] in self?.showStats() })
        menu.addItem(.separator())

        let save = ClosureMenuItem(title: "儲存進度") { [weak self] in
            guard let self else { return }
            self.settings.saveProgress.toggle()
            if self.settings.saveProgress { self.persist() } else { Persistence.clear() }
        }
        save.stateProvider = { self.settings.saveProgress }
        menu.addItem(save)
        menu.addItem(.separator())
        menu.addItem(.separator())
        menu.addItem(ClosureMenuItem(title: "說明手冊…") { [weak self] in self?.showManual() })
        menu.addItem(ClosureMenuItem(title: "關於哥布林營地（v\(versionText)）") { [weak self] in self?.showAbout() })
        menu.addItem(withTitle: "結束哥布林營地", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        statusItem.menu = menu
    }

    // MARK: Pomodoro

    /// "Pomodoro": a goblin at the top right holds up a clock that counts down the focus time, then the rest.
    private func pomodoroMenu() -> NSMenuItem {
        let parent = NSMenuItem(title: "番茄鐘", action: nil, keyEquivalent: "")
        let sub = NSMenu(title: "番茄鐘")
        pomodoroStatusItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        pomodoroStatusItem.isEnabled = false
        pomodoroStatusItem.isHidden = true
        sub.addItem(pomodoroStatusItem)
        pomodoroTodayItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        pomodoroTodayItem.isEnabled = false
        sub.addItem(pomodoroTodayItem)
        for (focus, rest) in [(25.0, 5.0), (50.0, 10.0), (15.0, 3.0)] {
            sub.addItem(ClosureMenuItem(title: "專注 \(Int(focus)) 分鐘，休息 \(Int(rest)) 分鐘") { [weak self] in
                self?.startPomodoro(focus: focus, rest: rest)
            })
        }
        sub.addItem(ClosureMenuItem(title: "自訂…") { [weak self] in
            DispatchQueue.main.async { self?.askCustomPomodoro() }
        })
        sub.addItem(.separator())
        let auto = ClosureMenuItem(title: "開始時自動進入工作模式") { [weak self] in self?.settings.pomodoroWorkMode.toggle() }
        auto.stateProvider = { self.settings.pomodoroWorkMode }
        sub.addItem(auto)
        pomodoroStopItem = ClosureMenuItem(title: "停止番茄鐘") { [weak self] in
            guard let pomodoro = self?.colony.pomodoro else { return }
            if pomodoro.phase == .focus { Stats.shared.addFocus(seconds: pomodoro.phaseLength - pomodoro.remaining) }
            pomodoro.stop()
            GoblinVoice.shared.stop()
            if self?.pomodoroChangedMode == true {
                self?.pomodoroChangedMode = false
                self?.setMode(nil, automatic: true)
            }
        }
        sub.addItem(pomodoroStopItem)
        parent.submenu = sub
        return parent
    }

    func startPomodoro(focus: Double, rest: Double) {
        let screen = alertScreenFrame()
        var breedIndex = 0
        pomodoroSpeaker = Speakers.common
        let character = Characters.current
        if let ant = colony.ants.randomElement() { // one of the living goblins holds the clock
            breedIndex = ant.breedIndex
            pomodoroSpeaker = Speakers.forBreed(character.breeds[min(breedIndex, character.breeds.count - 1)].id)
        }
        colony.pomodoro.start(focusMinutes: focus, restMinutes: rest, screen: screen, breedIndex: breedIndex)
        // a pomodoro means work: from the everything-on mode it switches to work mode, and back again when it is over
        if settings.pomodoroWorkMode, userMode == nil, !fullscreenActive {
            setMode(.work, automatic: true)
            pomodoroChangedMode = true
        }
    }

    /// Speaks (unless hidden: then only the badge counts it) when the pomodoro starts, rests, or ends.
    private func pomodoroEvent(_ event: Pomodoro.Event) {
        if event == .focusDone { Stats.shared.pomodoroCompleted(focusSeconds: colony.pomodoro.focusSeconds); return }
        if event == .finished, pomodoroChangedMode {
            pomodoroChangedMode = false
            setMode(nil, automatic: true)
        }
        if isSilenced {
            if event == .restBegan || event == .finished { noteMissed(); flashStatusIcon() } // no sound, only the icon blinks
            return
        }
        if ProcessInfo.processInfo.environment["CAMP_DEBUG"] != nil { NSLog("GoblinCamp: pomodoro \(event)") }
        let spoken: Pomodoro.Event = event == .finished && colony.pomodoro.endedWithoutRest ? .restBegan : event
        GoblinVoice.shared.speak(Speakers.pomodoroLine(pomodoroSpeaker, spoken), as: pomodoroSpeaker, level: settings.notifyVolume)
    }

    private func askCustomPomodoro() {
        let alert = NSAlert()
        alert.messageText = "自訂番茄鐘"
        alert.informativeText = "專注與休息各幾分鐘？（專注 1～99 分鐘，休息 0～60 分鐘，休息填 0 表示不休息）"
        let focus = NSTextField(frame: NSRect(x: 0, y: 30, width: 220, height: 24))
        let rest = NSTextField(frame: NSRect(x: 0, y: 0, width: 220, height: 24))
        focus.placeholderString = "專注分鐘"
        rest.placeholderString = "休息分鐘"
        focus.stringValue = String(format: "%g", settings.pomodoroFocus)
        rest.stringValue = String(format: "%g", settings.pomodoroRest)
        let box = NSView(frame: NSRect(x: 0, y: 0, width: 220, height: 56))
        box.addSubview(focus)
        box.addSubview(rest)
        alert.accessoryView = box
        alert.addButton(withTitle: "開始")
        alert.addButton(withTitle: "取消")
        alert.window.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
        alert.window.initialFirstResponder = focus
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        guard let f = Double(focus.stringValue), (1...99).contains(f), let r = Double(rest.stringValue), (0...60).contains(r) else {
            let error = NSAlert()
            error.messageText = "看不懂這些分鐘數"
            error.informativeText = "專注請填 1 到 99，休息請填 0 到 60。"
            error.window.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
            error.runModal()
            return
        }
        settings.pomodoroFocus = f
        settings.pomodoroRest = r
        startPomodoro(focus: f, rest: r)
    }

    // MARK: Claude notifications

    /// `goblincamp://notify?kind=permission|done&project=name`, sent by the Claude Code hooks (tools/goblin-notify.sh).
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls where url.scheme == "goblincamp" && url.host == "ask" {
            handleAsk(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? [])
        }
        for url in urls where url.scheme == "goblincamp" && url.host == "notify" {
            let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
            let kind = NotifyKind(rawValue: items.first { $0.name == "kind" }?.value ?? "") ?? .done
            var project = items.first { $0.name == "project" }?.value ?? ""
            project = String(project.filter { !$0.isNewline }.prefix(28)) // anyone can open this link, so keep it short
            var app = items.first { $0.name == "app" }?.value
            if let id = app, id.range(of: "^[A-Za-z0-9.-]{1,80}$", options: .regularExpression) == nil { app = nil }
            notify(kind, project: project, appBundleID: app)
        }
    }

    /// Someone wants the player: a goblin (or now and then the princess) pops up and says so.
    /// Silent while hidden (meeting, focus), only a badge on the menu bar icon.
    func notify(_ kind: NotifyKind, project: String = "", appBundleID: String? = nil, speaker forced: Speaker? = nil, count: Bool = true) {
        if forced == nil, count { Stats.shared.notification(kind) }
        guard settings.notifyEnabled, settings.notifies(kind) else { return }
        if isSilenced {
            noteMissed()
            return
        }
        // keep it from turning into spam
        if forced == nil, let last = lastNotify[kind], Date().timeIntervalSince(last) < 6 { return }
        lastNotify[kind] = Date()
        let screen = alertScreenFrame()
        let (speaker, breedIndex, name) = pickSpeaker(forced)
        var message = Message(kind: kind, speaker: speaker, breedIndex: breedIndex, project: project, appBundleID: appBundleID, screen: screen)
        message.name = name
        colony.stage.enqueue(message)
        redrawAll()
    }

    /// Who speaks: now and then the princess, otherwise one of the living goblins (so rare breeds turn up when you have them).
    private func pickSpeaker(_ forced: Speaker? = nil) -> (Speaker, Int, String) {
        let character = Characters.current
        if let forced { return (forced, character.breedIndex(id: forced.id), forced.isPrincess ? colony.princessName : "") }
        if Double.random(in: 0..<1) < 0.25 { return (Speakers.princess, 0, colony.princessName) }
        if let ant = colony.ants.randomElement() {
            return (Speakers.forBreed(character.breeds[min(ant.breedIndex, character.breeds.count - 1)].id), ant.breedIndex, ant.name)
        }
        return (Speakers.common, 0, "")
    }

    // MARK: Questions from hooks (answer on the bubble)

    private func after(_ seconds: Double, _ block: @escaping () -> Void) { DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: block) }

    private var pendingAsks: Set<String> = []
    private var askPanel: AskPanel?
    private var askPanelID: String?

    private static var repliesDirectory: URL {
        if let custom = ProcessInfo.processInfo.environment["CAMP_DATA_DIR"] { return URL(fileURLWithPath: custom).appendingPathComponent("replies") }
        return FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("GoblinCamp/replies")
    }

    /// Files the waiting hook script polls: `<id>.ack` (we got the question) and `<id>.json` (the answer).
    private func writeReply(_ id: String, _ payload: [String: Any], ack: Bool = false) {
        let dir = AppDelegate.repliesDirectory
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let final = dir.appendingPathComponent(ack ? "\(id).ack" : "\(id).json")
        let temp = dir.appendingPathComponent("\(id).tmp")
        guard let data = try? JSONSerialization.data(withJSONObject: payload), (try? data.write(to: temp)) != nil else { return }
        try? FileManager.default.removeItem(at: final)
        try? FileManager.default.moveItem(at: temp, to: final)
    }

    private func finishAsk(_ id: String, _ payload: [String: Any]) {
        pendingAsks.remove(id)
        writeReply(id, payload)
    }

    private func purgeOldReplies() {
        let dir = AppDelegate.repliesDirectory
        for file in (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: [.contentModificationDateKey])) ?? [] {
            let date = (try? file.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
            if Date().timeIntervalSince(date) > 3600 { try? FileManager.default.removeItem(at: file) }
        }
    }

    /// `goblincamp://ask?kind=permission|reply&id=…&project=…&app=…&text=…&wait=…` from tools/goblin-ask.sh, which then waits for the answer.
    /// Anything that cannot be shown as a question is answered "none" right away, so the hook never waits for nothing.
    private func handleAsk(_ items: [URLQueryItem]) {
        func value(_ name: String) -> String? { items.first { $0.name == name }?.value }
        guard let id = value("id"), id.range(of: "^[A-Za-z0-9-]{8,64}$", options: .regularExpression) != nil else { return }
        writeReply(id, ["ack": true], ack: true)
        let kind: NotifyKind = value("kind") == "permission" ? .permission : .done
        Stats.shared.notification(kind)
        let project = String((value("project") ?? "").filter { !$0.isNewline }.prefix(28))
        var app = value("app")
        if let bundle = app, bundle.range(of: "^[A-Za-z0-9.-]{1,80}$", options: .regularExpression) == nil { app = nil }
        let context = String((value("text") ?? "").filter { !$0.isNewline }.prefix(90))
        guard settings.notifyEnabled, settings.notifies(kind) else { return finishAsk(id, ["action": "none"]) }
        if !settings.askEnabled { // plain popup, no question
            notify(kind, project: project, appBundleID: app, count: false)
            return finishAsk(id, ["action": "none"])
        }
        if isSilenced {
            noteMissed()
            return finishAsk(id, ["action": "none"])
        }
        guard !colony.stage.isFull else { return finishAsk(id, ["action": "none"]) }
        let (speaker, breedIndex, name) = pickSpeaker()
        let wait = min(settings.askWait, Double(value("wait") ?? "") ?? 60)
        pendingAsks.insert(id)
        var message = Message(kind: kind, speaker: speaker, breedIndex: breedIndex, project: project, appBundleID: app,
                              screen: alertScreenFrame(), interaction: kind == .permission ? .decision : .reply, askID: id, context: context, talkTime: wait)
        message.name = name
        message.remember = kind == .permission ? String((value("remember") ?? "").filter { !$0.isNewline }.prefix(60)) : ""
        colony.stage.enqueue(message)
        redrawAll()
    }

    /// The panel with buttons or a text field, over the goblin's bubble spot while it stands there talking.
    private func updateAskPanel() {
        guard !isSilenced, let m = colony.stage.current, m.interaction != nil, m.phase == .talking, let id = m.askID else {
            if askPanel != nil { askPanel?.orderOut(nil); askPanel = nil; askPanelID = nil }
            return
        }
        guard askPanelID != id else { return }
        let size = AskPanel.size(for: m)
        let sprite = spriteHeight(of: m)
        var origin = NSPoint(x: m.pos.x - size.width + 30, y: m.pos.y + sprite * 0.8 + 12)
        origin.x = max(origin.x, m.screen.minX + 8)
        askPanel?.orderOut(nil)
        let panel = AskPanel(message: m, frame: NSRect(origin: origin, size: size)) { [weak self] answer in self?.answered(answer) }
        askPanel = panel
        askPanelID = id
        panel.orderFrontRegardless()
        if let path = ProcessInfo.processInfo.environment["CAMP_TEST_ASKSHOT"], let view = panel.contentView { // draw the bubble into a PNG
            after(0.5) {
                guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
                view.cacheDisplay(in: view.bounds, to: rep)
                if let png = rep.representation(using: .png, properties: [:]) { try? png.write(to: URL(fileURLWithPath: path)) }
            }
        }
    }

    private func answered(_ answer: AskAnswer) {
        guard let id = askPanelID else { return }
        let app = colony.stage.current?.appBundleID
        switch answer {
        case .allow: finishAsk(id, ["action": "allow"])
        case .allowAndRemember: finishAsk(id, ["action": "allowRemember"])
        case .deny: finishAsk(id, ["action": "deny"])
        case .reply(let text): finishAsk(id, ["action": "reply", "text": text])
        case .look:
            finishAsk(id, ["action": "none"])
            bringForward(app)
        case .dismiss: finishAsk(id, ["action": "none"])
        }
        colony.stage.dismissCurrent()
        GoblinVoice.shared.stop()
        askPanel?.orderOut(nil)
        askPanel = nil
        askPanelID = nil
    }

    private func bringForward(_ bundleID: String?) {
        guard let bundleID, let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }

    private func spriteHeight(of m: Message) -> CGFloat {
        let character = Characters.current
        let role = m.speaker.isPrincess ? character.queenRole(outfit: colony.outfitIndex) : character.breeds[min(m.breedIndex, character.breeds.count - 1)].sprites
        return CGFloat(role?.frameSize ?? 16) * (role?.pixelSize(scale: 1.6) ?? 3)
    }

    /// The overlay lets every click through, so the popup gets a small window of its own that catches clicks:
    /// clicking the bubble brings the app Claude runs in to the front and sends the messenger away.
    private var clickPanel: NSPanel?

    private func updateClickPanel() {
        guard !isSilenced, let m = colony.stage.current, m.phase == .talking, m.appBundleID != nil, m.interaction == nil else {
            clickPanel?.orderOut(nil)
            return
        }
        let character = Characters.current
        let role = m.speaker.isPrincess ? character.queenRole(outfit: colony.outfitIndex) : character.breeds[min(m.breedIndex, character.breeds.count - 1)].sprites
        let size = CGFloat(role?.frameSize ?? 16) * (role?.pixelSize(scale: 1.6) ?? 3)
        let frame = m.hitRect(spriteSize: size)
        if clickPanel == nil {
            let panel = NSPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = false
            panel.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
            panel.collectionBehavior = [.canJoinAllSpaces, .stationary]
            let view = ClickCatcher()
            view.onClick = { [weak self] in self?.messageClicked() }
            panel.contentView = view
            clickPanel = panel
        }
        clickPanel?.setFrame(frame, display: false)
        clickPanel?.orderFrontRegardless()
    }

    private func messageClicked() {
        guard let id = colony.stage.current?.appBundleID else { return }
        colony.stage.dismissCurrent()
        GoblinVoice.shared.stop()
        clickPanel?.orderOut(nil)
        bringForward(id)
    }

    /// The "Claude notifications" submenu: what to show, how loud, and a way to try it.
    private func notifyMenu() -> NSMenuItem {
        let parent = NSMenuItem(title: "Claude 通知", action: nil, keyEquivalent: "")
        let sub = NSMenu(title: "Claude 通知")
        let master = ClosureMenuItem(title: "開啟通知") { [weak self] in self?.settings.notifyEnabled.toggle() }
        master.stateProvider = { self.settings.notifyEnabled }
        sub.addItem(master)
        for (label, kind) in [("Claude 需要我決定時", NotifyKind.permission), ("Claude 工作完成時", NotifyKind.done)] {
            let item = ClosureMenuItem(title: label) { [weak self] in self?.settings.setNotifies(kind, !(self?.settings.notifies(kind) ?? true)) }
            item.stateProvider = { self.settings.notifies(kind) }
            sub.addItem(item)
        }
        sub.addItem(.separator())
        let ask = ClosureMenuItem(title: "泡泡可直接回覆（允許／拒絕、輸入回覆）") { [weak self] in self?.settings.askEnabled.toggle() }
        ask.stateProvider = { self.settings.askEnabled }
        sub.addItem(ask)
        sub.addItem(choiceMenu(title: "等你回覆多久", options: [("15 秒", 15.0), ("30 秒", 30.0), ("60 秒", 60.0)],
                               get: { self.settings.askWait }, set: { self.settings.askWait = $0 }))
        sub.addItem(.separator())
        let volume = choiceMenu(title: "聲音", options: [("關（只跳出泡泡）", 0), ("小聲", 1), ("中等", 2), ("大聲", 3)],
                                get: { self.settings.notifyVolume }, set: { self.settings.notifyVolume = $0 })
        sub.addItem(volume)
        sub.addItem(.separator())
        sub.addItem(ClosureMenuItem(title: "試試看（隨機）") { [weak self] in self?.notify(.permission, project: "測試", appBundleID: "com.apple.Terminal") })
        sub.addItem(ClosureMenuItem(title: "試試看：公主") { [weak self] in self?.notify(.done, project: "測試", appBundleID: "com.apple.Terminal", speaker: Speakers.princess) })
        sub.addItem(ClosureMenuItem(title: "試試看：詢問允許") { [weak self] in
            self?.handleAsk([URLQueryItem(name: "id", value: "test-\(UUID().uuidString)"), URLQueryItem(name: "kind", value: "permission"),
                             URLQueryItem(name: "project", value: "測試"), URLQueryItem(name: "app", value: "com.apple.Terminal"),
                             URLQueryItem(name: "text", value: "執行：git push origin main")])
        })
        sub.addItem(ClosureMenuItem(title: "試試看：可以回覆") { [weak self] in
            self?.handleAsk([URLQueryItem(name: "id", value: "test-\(UUID().uuidString)"), URLQueryItem(name: "kind", value: "reply"),
                             URLQueryItem(name: "project", value: "測試"), URLQueryItem(name: "app", value: "com.apple.Terminal")])
        })
        sub.addItem(ClosureMenuItem(title: "試試看：壯碩哥布林") { [weak self] in self?.notify(.permission, project: "測試", appBundleID: "com.apple.Terminal", speaker: Speakers.brute) })
        parent.submenu = sub
        return parent
    }

    // MARK: Names

    /// Asks what the princess is called. At the start of a new camp the game waits (paused) until she has a name.
    /// Tests (`CAMP_NO_SAVE`, `CAMP_AUTO_NEST`) never see the dialog: she just gets a name.
    private var naming = false

    private func nameThePrincess(firstTime: Bool) {
        guard !naming else { return }
        naming = true
        defer { naming = false }
        let env = ProcessInfo.processInfo.environment
        if env["CAMP_NO_SAVE"] != nil || env["CAMP_AUTO_NEST"] != nil {
            if colony.princessName.isEmpty { colony.princessName = Names.randomPrincess() }
            colony.needsPrincessName = false
            persist()
            return
        }
        let wasPaused = colony.isPaused
        colony.isPaused = true
        defer { colony.isPaused = wasPaused; colony.needsPrincessName = false; persist(); redrawAll() }
        var suggestion = colony.princessName.isEmpty ? Names.randomPrincess() : colony.princessName
        while true {
            let alert = NSAlert()
            alert.messageText = firstTime ? "幫被抓來的公主取個名字" : "公主的名字"
            alert.informativeText = "哥布林們會這樣叫她，通知泡泡裡也會用她的名字。之後可以在選單「公主的名字…」修改。"
            let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 240, height: 24))
            field.stringValue = suggestion
            field.placeholderString = "最多 8 個字"
            alert.accessoryView = field
            alert.addButton(withTitle: "好")
            alert.addButton(withTitle: firstTime ? "換一個" : "取消")
            if firstTime { alert.addButton(withTitle: "先叫她公主") }
            alert.window.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
            alert.window.initialFirstResponder = field
            NSApp.activate(ignoringOtherApps: true)
            switch alert.runModal() {
            case .alertFirstButtonReturn:
                let name = Names.clean(field.stringValue)
                colony.princessName = name.isEmpty ? (colony.princessName.isEmpty ? "公主" : colony.princessName) : name
                return
            case .alertSecondButtonReturn:
                if !firstTime { return }
                suggestion = Names.randomPrincess(except: field.stringValue)
            default:
                colony.princessName = "公主"
                return
            }
        }
    }

    // MARK: About and manual

    private var manualWindow: ManualWindow?

    private var versionText: String {
        (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "0"
    }

    private func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        let credits = NSMutableAttributedString(string: "住在 Mac 選單列的點陣風哥布林桌面小遊戲，也是會跳出來提醒你的番茄鐘與 Claude 通知小工具。\n\n資料存放在 ~/Library/Application Support/GoblinCamp。\n沒有連上網路，也不會傳送任何資料。",
                                                 attributes: [.font: NSFont.systemFont(ofSize: 11)])
        NSApp.orderFrontStandardAboutPanel(options: [.applicationName: "哥布林營地", .applicationVersion: versionText, .version: "", .credits: credits])
    }

    private func showManual() {
        if manualWindow == nil { manualWindow = ManualWindow() }
        manualWindow?.present()
    }

    // MARK: Connecting Claude Code

    private var claudeConnectItem: NSMenuItem!
    private var claudeStatusItem: NSMenuItem!
    private var claudeRemoveItem: ClosureMenuItem!

    /// One-click setup of the Claude Code hooks (no terminal needed).
    private func claudeConnectMenu() -> NSMenuItem {
        claudeConnectItem = NSMenuItem(title: "連接 Claude Code", action: nil, keyEquivalent: "")
        let sub = NSMenu(title: "連接 Claude Code")
        claudeStatusItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        claudeStatusItem.isEnabled = false
        sub.addItem(claudeStatusItem)
        sub.addItem(.separator())
        sub.addItem(ClosureMenuItem(title: "連接（泡泡可回覆，建議）…") { [weak self] in
            DispatchQueue.main.async { self?.confirmConnect(.interactive) }
        })
        sub.addItem(ClosureMenuItem(title: "連接（只有一般提醒）…") { [weak self] in
            DispatchQueue.main.async { self?.confirmConnect(.simple) }
        })
        claudeRemoveItem = ClosureMenuItem(title: "移除連接…") { [weak self] in
            DispatchQueue.main.async { self?.confirmDisconnect() }
        }
        sub.addItem(claudeRemoveItem)
        claudeConnectItem.submenu = sub
        return claudeConnectItem
    }

    private func refreshClaudeStatus() {
        let status = HookInstaller.status()
        let text: String
        switch status {
        case .notInstalled: text = "尚未連接"
        case .interactive: text = "已連接：泡泡可回覆"
        case .simple: text = "已連接：一般提醒"
        case .needsUpdate: text = "需要更新：請再按一次「連接」"
        }
        claudeStatusItem.title = "狀態：\(text)"
        claudeConnectItem.title = status == .notInstalled ? "連接 Claude Code（尚未連接）" : (status == .needsUpdate ? "連接 Claude Code（需要更新）" : "連接 Claude Code（已連接）")
        claudeRemoveItem.isEnabled = status != .notInstalled
    }

    private func presentAlert(_ title: String, _ text: String, buttons: [String] = ["好"]) -> Bool {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = text
        buttons.forEach { alert.addButton(withTitle: $0) }
        alert.window.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
        NSApp.activate(ignoringOtherApps: true)
        return alert.runModal() == .alertFirstButtonReturn
    }

    private func confirmConnect(_ style: HookInstaller.Style) {
        if (Bundle.main.executablePath ?? "").contains("AppTranslocation") {
            _ = presentAlert("請先把哥布林營地移到「應用程式」資料夾", "現在它是從暫時的位置執行的，連接後 Claude Code 之後會找不到它。移好之後重新開啟，再按一次連接。")
            return
        }
        let what = style == .interactive
            ? "・Claude 要求授權時，哥布林會問你「允許或拒絕」\n・Claude 做完一輪時，哥布林會讓你直接輸入回覆\n・Claude 閒置等你時，哥布林會提醒"
            : "・Claude 需要你、或做完事情時，哥布林會跳出來提醒（不能回覆）"
        let ok = presentAlert("連接 Claude Code？", """
            會做的事：
            1. 在 ~/.claude/hooks/ 放一個小腳本
            2. 備份 ~/.claude/settings.json（存成 settings.json.bak-goblincamp）後，加入 hook

            連接後：
            \(what)

            你原本的其他設定與 hook 不會被動到，隨時可以在這個選單移除。
            完成後請在 Claude Code 輸入 /hooks 確認，或重新開啟 Claude Code。
            """, buttons: ["連接", "取消"])
        guard ok else { return }
        do {
            try HookInstaller.install(style)
            _ = presentAlert("已連接", "請在 Claude Code 輸入 /hooks 確認，或重新開啟 Claude Code。\n之後 Claude 需要你時，哥布林就會跳出來。\n\n如果之後把哥布林營地搬到別的位置，請再按一次「連接」。")
        } catch {
            _ = presentAlert("連接失敗", error.localizedDescription)
        }
    }

    private func confirmDisconnect() {
        guard presentAlert("移除連接？", "會先備份 ~/.claude/settings.json，再拿掉哥布林營地加入的 hook 和腳本，其他設定不動。", buttons: ["移除", "取消"]) else { return }
        do {
            try HookInstaller.uninstall()
            _ = presentAlert("已移除", "請在 Claude Code 輸入 /hooks 確認，或重新開啟 Claude Code。")
        } catch {
            _ = presentAlert("移除失敗", error.localizedDescription)
        }
    }

    // MARK: Hiding

    private static let durationChoices: [(String, Double)] = [("直到我改變", 0), ("30 分鐘", 1800), ("1 小時", 3600), ("2 小時", 7200)]

    static func mode(named name: String) -> QuietMode? {
        switch name {
        case "work": return .work
        case "saver": return .saver
        case "focus": return .focus
        default: return nil
        }
    }

    /// The mode the app rests in: what a timed mode returns to.
    private var baseMode: QuietMode? { AppDelegate.mode(named: settings.startupMode) }

    /// What is actually in effect: a full-screen window forces focus mode.
    private var effectiveMode: QuietMode? { fullscreenActive && settings.fullscreenFocus ? .focus : userMode }
    /// The camp is not on screen.
    var isHiddenByUser: Bool { effectiveMode != nil }
    /// Nothing pops up and nothing is heard.
    var isSilenced: Bool { effectiveMode == .focus }
    /// The camp does not run.
    var isFrozen: Bool { effectiveMode == .focus || effectiveMode == .saver }

    /// Picked from the menu or a shortcut: lasts as long as the "how long" setting says.
    private func chooseMode(_ mode: QuietMode?) {
        setMode(mode, for: mode == nil ? nil : (settings.modeDuration > 0 ? settings.modeDuration : nil))
    }

    /// Switches mode. `seconds` nil stays until the player changes it; a timed mode goes back to the resting mode when it runs out.
    func setMode(_ mode: QuietMode?, for seconds: TimeInterval? = nil, automatic: Bool = false) {
        if !automatic { pomodoroChangedMode = false }
        if ProcessInfo.processInfo.environment["CAMP_DEBUG"] != nil { NSLog("GoblinCamp: mode -> \(String(describing: mode)) automatic \(automatic)") }
        userMode = mode
        hideTimer?.invalidate()
        hideTimer = nil
        hiddenUntil = nil
        if mode != nil, let seconds {
            hiddenUntil = Date().addingTimeInterval(seconds)
            hideTimer = Timer.scheduledTimer(withTimeInterval: seconds, repeats: false) { [weak self] _ in
                guard let self else { return }
                self.setMode(self.baseMode, automatic: true)
            }
        }
        applyQuietState()
    }

    func hide(_ mode: QuietMode, for seconds: TimeInterval?) { setMode(mode, for: seconds) }
    func unhide() { setMode(nil) }

    /// Puts the windows, sound, frame rate and menu bar icon in line with the mode in effect.
    private func applyQuietState() {
        let mode = effectiveMode
        colony.campHidden = mode != nil
        if mode == .focus {
            colony.stage.clear()
            clickPanel?.orderOut(nil)
            askPanel?.orderOut(nil)
            askPanel = nil
            askPanelID = nil
            GoblinVoice.shared.stop()
            windows.forEach { $0.orderOut(nil) }
        } else {
            missedNotifications = 0
            windows.forEach { $0.orderFrontRegardless() }
        }
        if mode != nil { roster.hide() }
        if mode != nil, away == nil { away = (Date(), colony.ants.count, colony.deaths, 0) }
        if mode == nil, let gone = away {
            away = nil
            showReturnSummary(gone)
        }
        if wasFrozen, !isFrozen { lastTick = Date() } // do not count the time spent frozen
        wasFrozen = isFrozen
        syncWindows()
        applyStatusIcon()
        scheduleFrameTimer(fps: desiredFPS())
        redrawAll()
    }

    /// "Welcome back": what changed in the camp while it was away and what notifications were missed. Silent.
    private func showReturnSummary(_ gone: (since: Date, ants: Int, deaths: Int, missed: Int)) {
        let minutes = Int(Date().timeIntervalSince(gone.since) / 60)
        guard minutes >= 1, colony.nest != nil else { return }
        let died = colony.deaths - gone.deaths
        let born = max(0, colony.ants.count - gone.ants + died)
        var parts: [String] = []
        if born > 0 { parts.append("多了 \(born) 隻\(Characters.current.noun)") }
        if died > 0 { parts.append("老死 \(died) 隻") }
        var text = "回來啦！這 \(minutes >= 60 ? "\(minutes / 60) 小時 \(minutes % 60) 分" : "\(minutes) 分鐘")，營地" + (parts.isEmpty ? "沒有變化" : parts.joined(separator: "、"))
        if gone.missed > 0 { text += "；錯過 \(gone.missed) 則 Claude 通知" }
        var message = Message(kind: .done, speaker: Speakers.princess, breedIndex: 0, project: "", appBundleID: nil,
                              screen: alertScreenFrame(), text: text + "。", silent: true)
        message.name = colony.princessName
        colony.stage.enqueue(message)
    }

    private func noteMissed() {
        missedNotifications += 1
        if away != nil { away?.missed += 1 }
        applyStatusIcon()
    }

    private var alertsBusy: Bool { colony.stage.isActive || colony.pomodoro.arriving || colony.pomodoro.leaving }

    /// Fewer frames when there is little to draw; this is meant to stay running all day.
    private func desiredFPS() -> Double {
        guard let mode = effectiveMode else { return colony.ants.count > AppDelegate.crowdedAnts ? 20 : 30 }
        if mode == .focus { return 4 }
        if alertsBusy { return 20 }
        if colony.pomodoro.isRunning { return mode == .work ? 10 : 6 }
        return mode == .work ? 10 : 3
    }

    // MARK: Full screen, screens

    /// True when some other app has a window covering a whole screen (a full-screen video, a slideshow).
    private func fullscreenWindowUp() -> Bool {
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]],
              let mainHeight = NSScreen.screens.first?.frame.height else { return false }
        let frames = NSScreen.screens.map { CGRect(x: $0.frame.minX, y: mainHeight - $0.frame.maxY, width: $0.frame.width, height: $0.frame.height) }
        let me = ProcessInfo.processInfo.processIdentifier
        for window in list {
            guard (window[kCGWindowLayer as String] as? Int) == 0,
                  (window[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value != me,
                  ((window[kCGWindowAlpha as String] as? Double) ?? 1) > 0.9,
                  let dict = window[kCGWindowBounds as String] as? NSDictionary,
                  let bounds = CGRect(dictionaryRepresentation: dict) else { continue }
            if frames.contains(where: { abs($0.minX - bounds.minX) < 2 && abs($0.minY - bounds.minY) < 2
                                        && abs($0.width - bounds.width) < 2 && abs($0.height - bounds.height) < 2 }) { return true }
        }
        return false
    }

    private func startFullscreenWatch() {
        // react at once when the desktop changes, and check twice a second as a backup
        let center = NSWorkspace.shared.notificationCenter
        center.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main) { [weak self] _ in self?.checkFullscreenAndDesktops() }
        center.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] _ in self?.checkFullscreenAndDesktops() }
        fullscreenTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in self?.checkFullscreenAndDesktops() }
        checkFullscreenAndDesktops()
    }

    /// Whether goblins may be drawn on this screen right now (the desktop it shows is one the player picked, and it is not a full-screen app).
    private func showsCamp(on screen: NSScreen) -> Bool {
        if [.choosingNest, .editing, .placingFood].contains(colony.phase) { return true } // picking a spot works on any desktop
        guard let info = Spaces.info(for: screen) else { return true }
        if info.isFullScreen { return false }
        if settings.desktopsAll { return true }
        guard let number = info.desktop else { return true }
        return settings.desktops.contains(number)
    }

    private func checkFullscreenAndDesktops() {
        for (window, screen) in zip(windows, NSScreen.screens) { (window.contentView as? AntView)?.showsCamp = showsCamp(on: screen) }
        guard settings.fullscreenFocus || fullscreenActive else { return }
        let now = fullscreenWindowUp() || Spaces.anyFullScreen
        if now != fullscreenActive {
            fullscreenActive = now
            if ProcessInfo.processInfo.environment["CAMP_DEBUG"] != nil { NSLog("GoblinCamp: full screen \(now ? "on" : "off"), mode now \(String(describing: effectiveMode))") }
            applyQuietState()
        }
    }

    /// The screen the pomodoro clock and the popups use, as chosen in the menu.
    private func alertScreenFrame() -> CGRect {
        let screens = NSScreen.screens
        let fallback = screens.first?.frame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
        switch settings.alertScreen {
        case "main": return fallback
        case "cursor": break
        case let name: if let match = screens.first(where: { $0.localizedName == name }) { return match.frame }
        }
        return screens.first { $0.frame.contains(NSEvent.mouseLocation) }?.frame ?? fallback
    }

    private var desktopMenuItem: NSMenuItem!

    /// "Which desktop": all of them, or a tick per desktop ("桌面 1", "桌面 2"…). Desktop 1 only by default.
    private func rebuildDesktopMenu() {
        guard let sub = desktopMenuItem.submenu else { return }
        sub.removeAllItems()
        let count = Spaces.desktopCount
        guard count > 0 else {
            let note = NSMenuItem(title: "（這台 Mac 查不到桌面資訊，會出現在所有桌面）", action: nil, keyEquivalent: "")
            note.isEnabled = false
            sub.addItem(note)
            return
        }
        let all = ClosureMenuItem(title: "所有桌面") { [weak self] in
            self?.settings.desktopsAll.toggle()
            self?.checkFullscreenAndDesktops()
        }
        all.stateProvider = { self.settings.desktopsAll }
        sub.addItem(all)
        sub.addItem(.separator())
        for number in 1...count {
            let item = ClosureMenuItem(title: "桌面 \(number)") { [weak self] in
                guard let self else { return }
                var list = self.settings.desktops
                if let i = list.firstIndex(of: number) { if list.count > 1 { list.remove(at: i) } } else { list.append(number); list.sort() }
                self.settings.desktops = list
                self.settings.desktopsAll = false
                self.checkFullscreenAndDesktops()
            }
            item.stateProvider = { !self.settings.desktopsAll && self.settings.desktops.contains(number) }
            sub.addItem(item)
        }
        sub.addItem(.separator())
        let note = NSMenuItem(title: "沒勾選的桌面沒有哥布林，但番茄鐘與通知照常出現", action: nil, keyEquivalent: "")
        note.isEnabled = false
        sub.addItem(note)
    }

    private func rebuildAlertScreenMenu() {
        guard let sub = alertScreenItem.submenu else { return }
        sub.removeAllItems()
        var options: [(String, String)] = [("游標所在的螢幕（預設）", "cursor"), ("主螢幕（選單列所在）", "main")]
        if NSScreen.screens.count > 1 { options += NSScreen.screens.map { ("螢幕：\($0.localizedName)", $0.localizedName) } }
        for (label, value) in options {
            let item = ClosureMenuItem(title: label) { [weak self] in self?.settings.alertScreen = value }
            item.stateProvider = { self.settings.alertScreen == value }
            sub.addItem(item)
        }
    }

    private func launchAtLoginItem() -> NSMenuItem {
        let item = ClosureMenuItem(title: "開機時自動啟動") {
            let service = SMAppService.mainApp
            do {
                if service.status == .enabled { try service.unregister() } else { try service.register() }
            } catch {
                let alert = NSAlert()
                alert.messageText = "無法設定開機啟動"
                alert.informativeText = "\(error.localizedDescription)\n\n可以到「系統設定 → 一般 → 登入項目」自己加入或移除。"
                alert.window.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
                alert.runModal()
            }
        }
        item.stateProvider = { SMAppService.mainApp.status == .enabled }
        return item
    }

    private func showStats() {
        let text = Stats.shared.summary()
        let alert = NSAlert()
        alert.messageText = "每日統計"
        alert.informativeText = "今天\n\(text.today)\n\n近 7 天\n\(text.week)"
        alert.addButton(withTitle: "好")
        alert.window.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    /// The camp's look: the built-in camps (each grows as more goblins move in), or the player's own picture.
    private func nestImageMenu() -> NSMenuItem {
        let parent = NSMenuItem(title: "營地外觀", action: nil, keyEquivalent: "")
        nestMenuItem = parent
        let sub = NSMenu(title: "營地外觀")

        for style in Camps.all {
            let item = ClosureMenuItem(title: style.name) { [weak self] in
                self?.settings.campID = style.id
                self?.redrawAll()
            }
            item.toolTip = style.blurb
            item.stateProvider = { self.settings.campID == style.id || (Camps.current === style && self.settings.campID != Camps.customID) }
            sub.addItem(item)
        }

        sub.addItem(.separator())
        let custom = ClosureMenuItem(title: "自己的圖片…") { [weak self] in
            // Let the menu finish closing before the panel opens.
            DispatchQueue.main.async { self?.pickNestImage() }
        }
        custom.stateProvider = { self.settings.campID == Camps.customID }
        sub.addItem(custom)
        sub.addItem(choiceMenu(title: "自己的圖片大小",
                               options: [("小", 32.0), ("中", 48.0), ("大", 80.0)],
                               get: { self.settings.nestImageWidth }, set: { self.settings.nestImageWidth = $0 }))
        parent.submenu = sub
        return parent
    }

    private func pickNestImage() {
        let panel = NSOpenPanel()
        panel.title = "選擇\(Characters.current.nestName)圖片"
        panel.message = "建議使用透明背景的 PNG"
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        // Overlay windows sit at the status-bar level; keep the panel above them.
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        if NestImageStore.importImage(from: url) {
            settings.campID = Camps.customID
            redrawAll()
        } else {
            let alert = NSAlert()
            alert.messageText = "無法讀取這張圖片"
            alert.informativeText = "請換一張 PNG 或 JPG 試試。"
            alert.window.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
            alert.runModal()
        }
    }

    private static let spawnPresets: [Double] = [10, 30, 60, 180, 300]

    /// How often a new one is born: a few presets and a custom value.
    private func spawnMenu() -> NSMenuItem {
        let parent = choiceMenu(title: "生成速度", options: AppDelegate.spawnPresets.map { ("每 \(IntervalFormat.text($0)) 一隻", $0) },
                                get: { self.settings.spawnInterval }, set: { self.settings.spawnInterval = $0 })
        customSpawnItem = ClosureMenuItem(title: "自訂…") { [weak self] in
            // let the menu close before the dialog opens
            DispatchQueue.main.async { self?.askCustomSpawnInterval() }
        }
        customSpawnItem.stateProvider = { !AppDelegate.spawnPresets.contains(self.settings.spawnInterval) }
        parent.submenu?.addItem(.separator())
        parent.submenu?.addItem(customSpawnItem)
        return parent
    }

    private func askCustomSpawnInterval() {
        let alert = NSAlert()
        alert.messageText = "自訂生成間隔"
        alert.informativeText = "每隔多久生出一隻？輸入秒數（45），或加單位：30s、5m、1.5h、90秒、3分。範圍 1 秒到 24 小時。"
        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 220, height: 24))
        field.stringValue = IntervalFormat.text(settings.spawnInterval)
        alert.accessoryView = field
        alert.addButton(withTitle: "好")
        alert.addButton(withTitle: "取消")
        alert.window.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
        alert.window.initialFirstResponder = field
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        if let seconds = IntervalFormat.parse(field.stringValue) {
            settings.spawnInterval = seconds
        } else {
            let error = NSAlert()
            error.messageText = "看不懂這個時間"
            error.informativeText = "請輸入像 45、30s、5m、1.5h 這樣的時間（1 秒到 24 小時）。"
            error.window.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
            error.runModal()
        }
    }

    /// "Put down food": pick a kind, then click on the screen.
    private func foodMenu() -> NSMenuItem {
        foodMenuItem = NSMenuItem(title: "放食物", action: nil, keyEquivalent: "")
        let sub = NSMenu(title: "放食物")
        for kind in FoodKind.placeable {
            sub.addItem(ClosureMenuItem(title: "\(kind.emoji) \(kind.label)") { [weak self] in self?.colony.beginPlacingFood(kind) })
        }
        sub.addItem(.separator())
        clearFoodItem = ClosureMenuItem(title: "清除所有食物") { [weak self] in
            self?.colony.clearFoods()
            self?.redrawAll()
        }
        sub.addItem(clearFoodItem)
        foodMenuItem.submenu = sub
        return foodMenuItem
    }

    /// Submenu of mutually exclusive options with a checkmark on the current one.
    private func choiceMenu<T: Equatable>(title: String, options: [(String, T)],
                                          get: @escaping () -> T, set: @escaping (T) -> Void) -> NSMenuItem {
        let parent = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        let sub = NSMenu(title: title)
        for (label, value) in options {
            let item = ClosureMenuItem(title: label) { [weak self] in
                set(value)
                self?.redrawAll()
            }
            item.stateProvider = { get() == value }
            sub.addItem(item)
        }
        parent.submenu = sub
        return parent
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        let pomodoro = colony.pomodoro
        pomodoroStatusItem.isHidden = !pomodoro.isRunning
        if let phase = pomodoro.phase {
            let left = Int(pomodoro.remaining.rounded(.up))
            pomodoroStatusItem.title = "\(phase == .focus ? "專注中" : "休息中")，剩 \(String(format: "%d:%02d", left / 60, left % 60))"
        }
        pomodoroStopItem.isEnabled = pomodoro.isRunning
        let today = Stats.shared.today
        pomodoroTodayItem.title = "今天已完成 \(today.pomodoros) 個，專注 \(Stats.minutes(today.focusSeconds))"
        pauseItem.title = colony.isPaused ? "繼續" : "暫停"
        pauseItem.isEnabled = colony.isSimulating
        let character = Characters.current
        let home = character.nestName
        rosterItem.title = roster.isVisible ? "\(Characters.current.noun)名冊（開啟中，再按一次關閉）" : "\(Characters.current.noun)名冊…"
        rosterItem.isEnabled = colony.nest != nil && !isHiddenByUser
        var status: [String] = []
        if fullscreenActive, settings.fullscreenFocus {
            status.append("全螢幕中，自動專注")
        } else if let until = hiddenUntil, let mode = userMode {
            let back = baseMode.map { "回到\($0.name)" } ?? "回到全開"
            status.append("\(mode.name)還剩約 \(max(1, Int(until.timeIntervalSinceNow / 60))) 分鐘，之後\(back)")
        }
        if missedNotifications > 0 { status.append("錯過 \(missedNotifications) 則通知") }
        quietStatusItem.isHidden = status.isEmpty
        quietStatusItem.title = status.joined(separator: "　·　")
        rebuildAlertScreenMenu()
        rebuildDesktopMenu()
        refreshClaudeStatus()
        pickItem.title = colony.nest == nil ? "選擇\(home)位置…" : "重新選擇\(home)位置（清空\(character.noun)）"
        nestMenuItem.title = "\(home)外觀"
        pickItem.isEnabled = colony.phase != .choosingNest && !isHiddenByUser
        editItem.title = colony.phase == .editing ? "完成編輯（Esc）" : "編輯\(home)位置"
        capMenuItem.title = "\(character.noun)數量上限"
        customSpawnItem.title = AppDelegate.spawnPresets.contains(settings.spawnInterval)
            ? "自訂…" : "自訂…（目前 \(IntervalFormat.text(settings.spawnInterval))）"
        updateCount()
        editItem.isEnabled = (colony.phase == .running || colony.phase == .editing) && !isHiddenByUser
        foodMenuItem.isEnabled = colony.phase == .running && !isHiddenByUser
        clearFoodItem.isEnabled = !colony.foods.isEmpty
        refreshStates(in: menu)
    }

    private func refreshStates(in menu: NSMenu) {
        for item in menu.items {
            if let closureItem = item as? ClosureMenuItem, let provider = closureItem.stateProvider {
                closureItem.state = provider() ? .on : .off
            }
            if let sub = item.submenu { refreshStates(in: sub) }
        }
    }

    // MARK: Game loop

    /// Full-screen repaints are the main cost, so a crowded colony ticks at 20 fps instead of 30.
    private static let crowdedAnts = 100

    private func startFrameTimer() {
        lastTick = Date()
        scheduleFrameTimer(fps: 30)
    }

    private func scheduleFrameTimer(fps: Double) {
        frameTimer?.invalidate()
        currentFPS = fps
        let timer = Timer(timeInterval: 1.0 / fps, repeats: true) { [weak self] _ in self?.frame() }
        RunLoop.main.add(timer, forMode: .common) // keep running while the menu is open
        frameTimer = timer
    }

    private func frame() {
        let now = Date()
        let dt = min(now.timeIntervalSince(lastTick), 0.2)
        lastTick = now

        // Mouse position and speed (no permission needed); the queen reacts to a curious or a fast cursor.
        let cursor = NSEvent.mouseLocation
        if let last = lastCursor, dt > 0 {
            cursorSpeed = max(hypot(cursor.x - last.x, cursor.y - last.y) / dt, cursorSpeed * 0.85)
        }
        lastCursor = cursor

        if !isSilenced, colony.stage.isActive {
            colony.stage.update(dt: dt)
            redrawAll()
        }
        if colony.pomodoro.isVisible {
            colony.pomodoro.update(dt: dt)
            if !isSilenced { redrawAll() }
        }
        updateClickPanel()
        updateAskPanel()
        for id in pendingAsks where !colony.stage.hasAsk(id) || colony.stage.isLeaving(ask: id) { // nobody answered in time (or it was cleared)
            finishAsk(id, ["action": "none"])
        }
        if !isFrozen, colony.isSimulating, !colony.isPaused {
            colony.tick(dt: dt, cursor: cursor, cursorSpeed: cursorSpeed)
            if !isHiddenByUser { redrawAll() } // nothing to draw while the camp is away
        }
        let wanted = desiredFPS()
        if wanted != currentFPS { scheduleFrameTimer(fps: wanted) }
    }

    /// The player picked another character: refresh the menu bar icon and names, and redraw.
    private func applyStatusIcon() {
        let character = Characters.current
        statusItem.button?.alphaValue = isSilenced ? 0.4 : (isHiddenByUser ? 0.7 : 1) // dimmed while the goblins are hidden
        // a small letter for the mode (工 work, 省 energy saving, 靜 focus) and a dot with the number of missed notifications
        let letter: String
        switch effectiveMode {
        case .work: letter = "工"
        case .saver: letter = "省"
        case .focus: letter = "靜"
        case nil: letter = ""
        }
        var badge = letter
        if missedNotifications > 0 { badge += (badge.isEmpty ? "" : " ") + "●\(missedNotifications)" }
        if missedNotifications > 0 { statusItem.button?.alphaValue = 1 }
        if let icon = character.icon {
            icon.size = NSSize(width: 16, height: 16) // 16 art pixels on 32 device pixels, so it stays crisp
            icon.isTemplate = false
            statusItem.button?.image = icon
            statusItem.button?.imagePosition = badge.isEmpty ? .imageOnly : .imageLeft
            statusItem.button?.title = badge.isEmpty ? "" : " " + badge
        } else {
            statusItem.button?.image = nil
            statusItem.button?.title = character.emoji + (badge.isEmpty ? "" : " " + badge)
        }
    }

    /// The menu bar icon blinks for a few seconds (the pomodoro ran out while everything is silent).
    private func flashStatusIcon() {
        flashTimer?.invalidate()
        var count = 0
        flashTimer = Timer.scheduledTimer(withTimeInterval: 0.35, repeats: true) { [weak self] timer in
            guard let self else { return timer.invalidate() }
            count += 1
            self.statusItem.button?.alphaValue = count % 2 == 0 ? 1 : 0.15
            if count >= 18 {
                timer.invalidate()
                self.applyStatusIcon()
            }
        }
    }

    // MARK: Shortcuts

    /// ⌃⌥1 all on, ⌃⌥2 work mode, ⌃⌥3 energy saving, ⌃⌥4 focus.
    private func applyHotkeys() {
        HotKeys.shared.unregisterAll()
        guard settings.hotkeysEnabled else { return }
        let keys: [(Int, QuietMode?)] = [(18, nil), (19, .work), (20, .saver), (21, .focus)] // the 1–4 keys
        for (code, mode) in keys {
            let ok = HotKeys.shared.register(keyCode: code) { [weak self] in self?.chooseMode(mode) }
            if !ok, ProcessInfo.processInfo.environment["CAMP_DEBUG"] != nil { NSLog("GoblinCamp: shortcut for key \(code) was not accepted") }
        }
    }

    private func characterChanged() {
        applyStatusIcon()
        updateCount()
        redrawAll()
    }

    private func redrawAll() {
        windows.forEach { $0.contentView?.needsDisplay = true }
    }

    private func updateCount() {
        countItem.title = "\(Characters.current.noun)數：\(colony.ants.count)"
    }

    private func persist() {
        guard settings.saveProgress else { return }
        if let state = colony.savedState() {
            Persistence.save(state)
        } else {
            Persistence.clear()
        }
    }

    // MARK: Overlays

    private func rebuildOverlays() {
        windows.forEach { $0.close() }
        colony.updateWalkable(NSScreen.screens.map(\.frame))
        windows = NSScreen.screens.map { screen in
            let window = OverlayWindow(screen: screen)
            window.contentView = AntView(frame: NSRect(origin: .zero, size: screen.frame.size), colony: colony)
            if !isSilenced { window.orderFrontRegardless() }
            return window
        }
    }

    /// Sync window input mode with the game phase and redraw.
    private func syncWindows() {
        let picking = [.choosingNest, .editing, .placingFood].contains(colony.phase) // overlay must capture the mouse
        for window in windows {
            window.acceptsInput = picking
            window.contentView?.needsDisplay = true
        }
        if picking, !isHiddenByUser {
            NSApp.activate(ignoringOtherApps: true)
            windows.first?.makeKeyAndOrderFront(nil)
        }
        updateCount()
        checkFullscreenAndDesktops()
    }
}
