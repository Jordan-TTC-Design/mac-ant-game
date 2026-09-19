import AppKit
import UniformTypeIdentifiers

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
    /// 專注模式 (focus): hidden and completely paused. 工作模式 (work): hidden, but the camp keeps running in the background.
    private var quietMode: QuietMode?
    enum QuietMode { case focus, work }
    private var hideTimer: Timer?
    /// Claude notifications that came while the goblins were hidden (silently dropped, but counted).
    private var missedNotifications = 0
    private var lastNotify: [NotifyKind: Date] = [:]
    private var pomodoroStatusItem: NSMenuItem!
    private var pomodoroStopItem: ClosureMenuItem!
    private var pomodoroSpeaker = Speakers.common
    private var focusMenuItem: NSMenuItem!
    private var workMenuItem: NSMenuItem!
    private var unhideItem: ClosureMenuItem!
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
            GoblinVoice.shared.speak(message.text, as: message.speaker, level: self.settings.notifyVolume)
        }
        colony.pomodoro.onEvent = { [weak self] event in self?.pomodoroEvent(event) }
        setupMenuBar()
        rebuildOverlays()

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
        }
        colony.onAntsChanged = { [weak self] in
            self?.updateCount()
            self?.persist()
        }
        syncWindows()
        updateCount()
        startFrameTimer()
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
        if let s = env["CAMP_TEST_POMODORO"] { // "focusMinutes,restMinutes" (fractions allowed), started at 3 s
            let parts = s.split(separator: ",").compactMap { Double($0) }
            if parts.count == 2 { after(3) { self.startPomodoro(focus: parts[0], rest: parts[1]) } }
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
        focusMenuItem = quietMenu(title: "專注模式", mode: .focus)
        menu.addItem(focusMenuItem)
        workMenuItem = quietMenu(title: "工作模式", mode: .work)
        menu.addItem(workMenuItem)
        unhideItem = ClosureMenuItem(title: "結束專注模式") { [weak self] in self?.unhide() }
        menu.addItem(unhideItem)
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
        menu.addItem(.separator())

        let save = ClosureMenuItem(title: "儲存進度") { [weak self] in
            guard let self else { return }
            self.settings.saveProgress.toggle()
            if self.settings.saveProgress { self.persist() } else { Persistence.clear() }
        }
        save.stateProvider = { self.settings.saveProgress }
        menu.addItem(save)
        menu.addItem(.separator())
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
        for (focus, rest) in [(25.0, 5.0), (50.0, 10.0), (15.0, 3.0)] {
            sub.addItem(ClosureMenuItem(title: "專注 \(Int(focus)) 分鐘，休息 \(Int(rest)) 分鐘") { [weak self] in
                self?.startPomodoro(focus: focus, rest: rest)
            })
        }
        sub.addItem(ClosureMenuItem(title: "自訂…") { [weak self] in
            DispatchQueue.main.async { self?.askCustomPomodoro() }
        })
        sub.addItem(.separator())
        pomodoroStopItem = ClosureMenuItem(title: "停止番茄鐘") { [weak self] in
            self?.colony.pomodoro.stop()
            GoblinVoice.shared.stop()
        }
        sub.addItem(pomodoroStopItem)
        parent.submenu = sub
        return parent
    }

    func startPomodoro(focus: Double, rest: Double) {
        let screen = colony.walkable.first ?? NSScreen.screens.first?.frame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
        var breedIndex = 0
        pomodoroSpeaker = Speakers.common
        let character = Characters.current
        if let ant = colony.ants.randomElement() { // one of the living goblins holds the clock
            breedIndex = ant.breedIndex
            pomodoroSpeaker = Speakers.forBreed(character.breeds[min(breedIndex, character.breeds.count - 1)].id)
        }
        colony.pomodoro.start(focusMinutes: focus, restMinutes: rest, screen: screen, breedIndex: breedIndex)
    }

    /// Speaks (unless hidden: then only the badge counts it) when the pomodoro starts, rests, or ends.
    private func pomodoroEvent(_ event: Pomodoro.Event) {
        if isHiddenByUser {
            if event != .started { missedNotifications += 1; applyStatusIcon() }
            return
        }
        if ProcessInfo.processInfo.environment["CAMP_DEBUG"] != nil { NSLog("GoblinCamp: pomodoro \(event)") }
        GoblinVoice.shared.speak(Speakers.pomodoroLine(pomodoroSpeaker, event), as: pomodoroSpeaker, level: settings.notifyVolume)
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
    func notify(_ kind: NotifyKind, project: String = "", appBundleID: String? = nil, speaker forced: Speaker? = nil) {
        guard settings.notifyEnabled, settings.notifies(kind) else { return }
        if isHiddenByUser {
            missedNotifications += 1
            applyStatusIcon()
            return
        }
        // keep it from turning into spam
        if forced == nil, let last = lastNotify[kind], Date().timeIntervalSince(last) < 6 { return }
        lastNotify[kind] = Date()
        let mouse = NSEvent.mouseLocation
        let screen = colony.walkable.first { $0.contains(mouse) } ?? colony.walkable.first ?? NSScreen.main?.frame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
        let character = Characters.current
        var breedIndex = 0
        var speaker = Speakers.common
        if let forced {
            speaker = forced
            breedIndex = character.breedIndex(id: forced.id)
        } else if Double.random(in: 0..<1) < 0.25 {
            speaker = Speakers.princess
        } else if let ant = colony.ants.randomElement() { // one of the living goblins, so rare breeds turn up when you have them
            breedIndex = ant.breedIndex
            speaker = Speakers.forBreed(character.breeds[min(breedIndex, character.breeds.count - 1)].id)
        }
        colony.stage.enqueue(Message(kind: kind, speaker: speaker, breedIndex: breedIndex, project: project, appBundleID: appBundleID, screen: screen))
        redrawAll()
    }

    /// The overlay lets every click through, so the popup gets a small window of its own that catches clicks:
    /// clicking the bubble brings the app Claude runs in to the front and sends the messenger away.
    private var clickPanel: NSPanel?

    private func updateClickPanel() {
        guard !isHiddenByUser, let m = colony.stage.current, m.phase == .talking, m.appBundleID != nil else {
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
            panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
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
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) {
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
        }
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
        let volume = choiceMenu(title: "聲音", options: [("關（只跳出泡泡）", 0), ("小聲", 1), ("中等", 2), ("大聲", 3)],
                                get: { self.settings.notifyVolume }, set: { self.settings.notifyVolume = $0 })
        sub.addItem(volume)
        sub.addItem(.separator())
        sub.addItem(ClosureMenuItem(title: "試試看（隨機）") { [weak self] in self?.notify(.permission, project: "測試", appBundleID: "com.apple.Terminal") })
        sub.addItem(ClosureMenuItem(title: "試試看：公主") { [weak self] in self?.notify(.done, project: "測試", appBundleID: "com.apple.Terminal", speaker: Speakers.princess) })
        sub.addItem(ClosureMenuItem(title: "試試看：壯碩哥布林") { [weak self] in self?.notify(.permission, project: "測試", appBundleID: "com.apple.Terminal", speaker: Speakers.brute) })
        parent.submenu = sub
        return parent
    }

    // MARK: Hiding

    private static let hideChoices: [(label: String, seconds: TimeInterval?)] = [
        ("30 分鐘", 30 * 60), ("1 小時", 3600), ("2 小時", 7200), ("直到我取消", nil),
    ]

    /// 專注模式 and 工作模式, each for a while: the goblins disappear from the screen and nothing pops up.
    /// In focus mode the camp is also frozen; in work mode it keeps running in the background.
    private func quietMenu(title: String, mode: QuietMode) -> NSMenuItem {
        let parent = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        let sub = NSMenu(title: title)
        for choice in AppDelegate.hideChoices {
            sub.addItem(ClosureMenuItem(title: choice.label) { [weak self] in self?.hide(mode, for: choice.seconds) })
        }
        parent.submenu = sub
        return parent
    }

    var isHiddenByUser: Bool { hiddenUntil != nil }
    /// Focus mode stops the game completely.
    var isFrozen: Bool { quietMode == .focus }

    /// `seconds` nil hides until the player brings the goblins back.
    func hide(_ mode: QuietMode, for seconds: TimeInterval?) {
        hiddenUntil = seconds.map { Date().addingTimeInterval($0) } ?? .distantFuture
        quietMode = mode
        hideTimer?.invalidate()
        if let seconds {
            hideTimer = Timer.scheduledTimer(withTimeInterval: seconds, repeats: false) { [weak self] _ in self?.unhide() }
        }
        colony.stage.clear()
        clickPanel?.orderOut(nil)
        GoblinVoice.shared.stop()
        windows.forEach { $0.orderOut(nil) }
        roster.hide()
        applyStatusIcon()
        scheduleFrameTimer(fps: mode == .focus ? 5 : 10) // nothing to draw, so run lightly (this is meant to stay running all day)
    }

    func unhide() {
        guard hiddenUntil != nil else { return }
        let wasFrozen = isFrozen
        hiddenUntil = nil
        quietMode = nil
        missedNotifications = 0
        hideTimer?.invalidate()
        hideTimer = nil
        if wasFrozen { lastTick = Date() } // do not count the time spent frozen
        windows.forEach { $0.orderFrontRegardless() }
        syncWindows()
        applyStatusIcon()
        scheduleFrameTimer(fps: 30)
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
        pauseItem.title = colony.isPaused ? "繼續" : "暫停"
        pauseItem.isEnabled = colony.isSimulating
        let character = Characters.current
        let home = character.nestName
        rosterItem.title = roster.isVisible ? "\(Characters.current.noun)名冊（開啟中，再按一次關閉）" : "\(Characters.current.noun)名冊…"
        rosterItem.isEnabled = colony.nest != nil && !isHiddenByUser
        focusMenuItem.isHidden = isHiddenByUser
        workMenuItem.isHidden = isHiddenByUser
        unhideItem.isHidden = !isHiddenByUser
        if let until = hiddenUntil {
            let name = isFrozen ? "專注模式" : "工作模式"
            let missed = missedNotifications > 0 ? "　·　期間有 \(missedNotifications) 則通知" : ""
            unhideItem.title = (until == .distantFuture ? "結束\(name)" : "結束\(name)（還剩約 \(max(1, Int(until.timeIntervalSinceNow / 60))) 分鐘）") + missed
        }
        pickItem.title = colony.nest == nil ? "選擇\(home)位置…" : "重新選擇\(home)位置（清空\(character.noun)）"
        nestMenuItem.title = "\(home)外觀"
        pickItem.isEnabled = colony.phase != .choosingNest
        editItem.title = colony.phase == .editing ? "完成編輯（Esc）" : "編輯\(home)位置"
        capMenuItem.title = "\(character.noun)數量上限"
        customSpawnItem.title = AppDelegate.spawnPresets.contains(settings.spawnInterval)
            ? "自訂…" : "自訂…（目前 \(IntervalFormat.text(settings.spawnInterval))）"
        updateCount()
        editItem.isEnabled = colony.phase == .running || colony.phase == .editing
        foodMenuItem.isEnabled = colony.phase == .running
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

        if !isHiddenByUser, colony.stage.isActive {
            colony.stage.update(dt: dt)
            redrawAll()
        }
        if colony.pomodoro.isVisible {
            colony.pomodoro.update(dt: dt)
            if !isHiddenByUser { redrawAll() }
        }
        updateClickPanel()
        guard !isFrozen, colony.isSimulating, !colony.isPaused else { return }
        colony.tick(dt: dt, cursor: cursor, cursorSpeed: cursorSpeed)
        if !isHiddenByUser { redrawAll() } // in work mode nothing is on screen
        else { return }
        let wanted: Double = colony.ants.count > AppDelegate.crowdedAnts ? 20 : 30
        if wanted != currentFPS { scheduleFrameTimer(fps: wanted) }
    }

    /// The player picked another character: refresh the menu bar icon and names, and redraw.
    private func applyStatusIcon() {
        let character = Characters.current
        statusItem.button?.alphaValue = isFrozen ? 0.4 : (isHiddenByUser ? 0.7 : 1) // dimmed while the goblins are hidden
        defer { // a dot beside the icon while notifications piled up during the hiding
            if missedNotifications > 0 {
                statusItem.button?.imagePosition = .imageLeft
                statusItem.button?.title = " ●\(missedNotifications)"
                statusItem.button?.alphaValue = 1
            }
        }
        if let icon = character.icon {
            icon.size = NSSize(width: 16, height: 16) // 16 art pixels on 32 device pixels, so it stays crisp
            icon.isTemplate = false
            statusItem.button?.image = icon
            statusItem.button?.title = ""
            if ProcessInfo.processInfo.environment["CAMP_DEBUG"] != nil { NSLog("GoblinCamp: menu bar icon from \(character.id): \(icon.representations.first?.pixelsWide ?? 0)px") }
        } else {
            statusItem.button?.image = nil
            statusItem.button?.title = character.emoji
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
            if !isHiddenByUser { window.orderFrontRegardless() }
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
    }
}
