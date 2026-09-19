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
    private let countItem = NSMenuItem(title: "螞蟻數：0", action: nil, keyEquivalent: "")
    private var pauseItem: ClosureMenuItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        rebuildOverlays()

        // Resume a saved colony if its nest is still on a screen; otherwise start at nest-picking.
        if settings.saveProgress, let saved = Persistence.load() {
            let nest = CGPoint(x: saved.nestX, y: saved.nestY)
            if colony.walkable.contains(where: { $0.contains(nest) }) {
                colony.restore(nest: nest, antCount: saved.antCount)
                if ProcessInfo.processInfo.environment["ANT_DEBUG"] != nil { NSLog("AntFarm: restored \(saved.antCount) ants") }
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
        if colony.phase == .choosingNest, ProcessInfo.processInfo.environment["ANT_AUTO_NEST"] != nil, let f = NSScreen.main?.frame {
            colony.placeNest(at: CGPoint(x: f.midX, y: f.midY))
        }
    }

    /// Test hook: `ANT_SNAPSHOT=/path/prefix` saves the overlay (composited on grey, cropped around the nest) after a delay.
    private func scheduleSnapshot() {
        guard let prefix = ProcessInfo.processInfo.environment["ANT_SNAPSHOT"] else { return }
        let delays = (ProcessInfo.processInfo.environment["ANT_SNAPSHOT_AFTER"] ?? "20").split(separator: ",").compactMap { Double($0) }
        let delay = delays.first ?? 20
        if let forced = ProcessInfo.processInfo.environment["ANT_QUEEN_FORCE"] {
            let lead = forced == "digging" ? 4.5 : 1.2
            DispatchQueue.main.asyncAfter(deadline: .now() + max(0, delay - lead)) { [weak self] in
                self?.colony.debugForceQueen(forced)
            }
        }
        let full = ProcessInfo.processInfo.environment["ANT_SNAPSHOT_FULL"] != nil
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
                    NSLog("AntFarm: snapshot saved \(path)")
                }
            }
        }
        }
    }

    /// Test hooks that drive the UI with synthetic events, so the nest-picking and edit flows can be exercised
    /// without real mouse or keyboard input (which needs extra permissions):
    /// `ANT_TEST_ESC=秒` presses Esc; `ANT_TEST_EDIT=dx,dy` enters edit mode and drags the nest by (dx, dy), then Esc.
    private func scheduleUITests() {
        let env = ProcessInfo.processInfo.environment
        func after(_ seconds: Double, _ work: @escaping () -> Void) {
            DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: work)
        }
        func log(_ s: String) { NSLog("AntFarm test: \(s)") }
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

        if let s = env["ANT_TEST_ESC"], let t = Double(s) {
            log("phase at start: \(colony.phase)")
            after(t) { pressKey(53, "\u{1b}") }
            after(t + 0.5) { log("phase after Esc: \(self.colony.phase), nest: \(String(describing: self.colony.nest))") }
        }
        if let s = env["ANT_TEST_FOOD"] {
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
            if env["ANT_TEST_FOOD_CANCEL"] != nil { // press Esc while placing instead of clicking
                after(10) {
                    self.colony.beginPlacingFood(.water)
                    self.syncWindows()
                    log("placing again: phase \(self.colony.phase), pending \(String(describing: self.colony.pendingFood))")
                    after(2.5) { pressKey(53, "\u{1b}") } // leave the hint on screen long enough to be captured
                    after(3.0) { log("after Esc while placing: phase \(self.colony.phase), pending \(String(describing: self.colony.pendingFood))") }
                }
            }
        }
        if let s = env["ANT_TEST_EDIT"] {
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
                if env["ANT_TEST_EDIT_HOLD"] != nil { // stay in edit mode for a screenshot
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
        statusItem.button?.title = "🐜"

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
        menu.addItem(.separator())

        menu.addItem(choiceMenu(title: "生成速度",
                                options: [("每 10 秒一隻", 10.0), ("每 5 秒一隻", 5.0), ("每 3 秒一隻", 3.0), ("每 1 秒一隻", 1.0)],
                                get: { self.settings.spawnInterval }, set: { self.settings.spawnInterval = $0 }))
        menu.addItem(choiceMenu(title: "螞蟻上限",
                                options: [("100 隻", 100), ("200 隻", 200), ("500 隻", 500), ("1000 隻", 1000)],
                                get: { self.settings.maxAnts }, set: { self.settings.maxAnts = $0 }))
        menu.addItem(choiceMenu(title: "螞蟻大小",
                                options: [("小", 0.8), ("標準", 1.0), ("大", 1.5), ("超大", 2.2)],
                                get: { self.settings.antScale }, set: { self.settings.antScale = $0 }))
        menu.addItem(choiceMenu(title: "移動速度",
                                options: [("慢", 0.5), ("標準", 1.0), ("快", 2.0)],
                                get: { self.settings.speedMultiplier }, set: { self.settings.speedMultiplier = $0 }))
        menu.addItem(choiceMenu(title: "螞蟻顏色",
                                options: AntColorTheme.allCases.map { ($0.label, $0) },
                                get: { self.settings.colorTheme }, set: { self.settings.colorTheme = $0 }))
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
        menu.addItem(withTitle: "結束螞蟻農場", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        statusItem.menu = menu
    }

    private func nestImageMenu() -> NSMenuItem {
        let parent = NSMenuItem(title: "蟻窩圖案", action: nil, keyEquivalent: "")
        let sub = NSMenu(title: "蟻窩圖案")

        let builtIn = ClosureMenuItem(title: "預設土堆") { [weak self] in
            NestImageStore.remove()
            self?.redrawAll()
        }
        builtIn.stateProvider = { NestImageStore.image == nil }
        sub.addItem(builtIn)

        let custom = ClosureMenuItem(title: "選擇圖片…") { [weak self] in
            // Let the menu finish closing before the panel opens.
            DispatchQueue.main.async { self?.pickNestImage() }
        }
        custom.stateProvider = { NestImageStore.image != nil }
        sub.addItem(custom)

        sub.addItem(.separator())
        sub.addItem(choiceMenu(title: "圖片大小",
                               options: [("小", 32.0), ("中", 48.0), ("大", 80.0)],
                               get: { self.settings.nestImageWidth }, set: { self.settings.nestImageWidth = $0 }))
        parent.submenu = sub
        return parent
    }

    private func pickNestImage() {
        let panel = NSOpenPanel()
        panel.title = "選擇蟻窩圖片"
        panel.message = "建議使用透明背景的 PNG"
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        // Overlay windows sit at the status-bar level; keep the panel above them.
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        if NestImageStore.importImage(from: url) {
            redrawAll()
        } else {
            let alert = NSAlert()
            alert.messageText = "無法讀取這張圖片"
            alert.informativeText = "請換一張 PNG 或 JPG 試試。"
            alert.window.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
            alert.runModal()
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
        pickItem.title = colony.nest == nil ? "選擇蟻窩位置…" : "重新選擇蟻窩（清空螞蟻）"
        pickItem.isEnabled = colony.phase != .choosingNest
        editItem.title = colony.phase == .editing ? "完成編輯（Esc）" : "編輯蟻窩位置"
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

    private func redrawAll() {
        windows.forEach { $0.contentView?.needsDisplay = true }
    }

    private func updateCount() {
        countItem.title = "螞蟻數：\(colony.ants.count)"
    }

    private func persist() {
        guard settings.saveProgress else { return }
        if let nest = colony.nest {
            Persistence.save(SavedState(nestX: nest.x, nestY: nest.y, antCount: colony.ants.count))
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
