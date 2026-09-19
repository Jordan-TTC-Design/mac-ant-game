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
        capMenuItem = choiceMenu(title: "數量上限",
                                 options: [("50 隻", 50), ("100 隻", 100), ("150 隻", 150), ("300 隻", 300), ("500 隻", 500), ("1000 隻", 1000)],
                                 get: { self.settings.maxAnts }, set: { self.settings.maxAnts = $0 })
        menu.addItem(capMenuItem)
        menu.addItem(nestImageMenu())
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
        for kind in FoodKind.allCases {
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
        pauseItem.title = colony.isPaused ? "繼續" : "暫停"
        pauseItem.isEnabled = colony.isSimulating
        let character = Characters.current
        let home = character.nestName
        rosterItem.title = roster.isVisible ? "\(Characters.current.noun)名冊（開啟中，再按一次關閉）" : "\(Characters.current.noun)名冊…"
        rosterItem.isEnabled = colony.nest != nil
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

        guard colony.isSimulating, !colony.isPaused else { return }
        colony.tick(dt: dt, cursor: cursor, cursorSpeed: cursorSpeed)
        redrawAll()
        let wanted: Double = colony.ants.count > AppDelegate.crowdedAnts ? 20 : 30
        if wanted != currentFPS { scheduleFrameTimer(fps: wanted) }
    }

    /// The player picked another character: refresh the menu bar icon and names, and redraw.
    private func applyStatusIcon() {
        let character = Characters.current
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
            window.orderFrontRegardless()
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
        if picking {
            NSApp.activate(ignoringOtherApps: true)
            windows.first?.makeKeyAndOrderFront(nil)
        }
        updateCount()
    }
}
