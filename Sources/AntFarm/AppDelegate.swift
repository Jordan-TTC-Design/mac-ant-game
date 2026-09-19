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
        let delay = Double(ProcessInfo.processInfo.environment["ANT_SNAPSHOT_AFTER"] ?? "") ?? 20
        if let forced = ProcessInfo.processInfo.environment["ANT_QUEEN_FORCE"] {
            let lead = forced == "digging" ? 4.5 : 1.2
            DispatchQueue.main.asyncAfter(deadline: .now() + max(0, delay - lead)) { [weak self] in
                self?.colony.debugForceQueen(forced)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self, let nest = self.colony.nest else { return }
            for (i, window) in self.windows.enumerated() where window.frame.contains(nest) {
                guard let cg = CGWindowListCreateImage(.null, .optionIncludingWindow, CGWindowID(window.windowNumber),
                                                       [.boundsIgnoreFraming, .bestResolution]) else { continue }
                let scale = CGFloat(cg.width) / window.frame.width
                let half: CGFloat = 130
                // crop (image origin is top-left) around the nest, then paint over grey
                let cx = (nest.x - window.frame.minX) * scale, cy = (window.frame.maxY - nest.y) * scale
                let rect = CGRect(x: cx - half * scale, y: cy - half * scale * 0.7, width: half * 2 * scale, height: half * 1.4 * scale)
                guard let crop = cg.cropping(to: rect) else { continue }
                let out = NSImage(size: NSSize(width: crop.width * 2, height: crop.height * 2))
                out.lockFocus()
                NSColor(calibratedWhite: 0.85, alpha: 1).setFill()
                NSRect(origin: .zero, size: out.size).fill()
                NSImage(cgImage: crop, size: out.size).draw(in: NSRect(origin: .zero, size: out.size))
                out.unlockFocus()
                if let tiff = out.tiffRepresentation, let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) {
                    try? png.write(to: URL(fileURLWithPath: "\(prefix)-\(i).png"))
                    NSLog("AntFarm: snapshot saved \(prefix)-\(i).png")
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

        countItem.isEnabled = false
        menu.addItem(countItem)
        menu.addItem(.separator())

        pauseItem = ClosureMenuItem(title: "暫停") { [weak self] in
            guard let self else { return }
            self.colony.isPaused.toggle()
        }
        menu.addItem(pauseItem)
        menu.addItem(ClosureMenuItem(title: "重新選擇蟻窩（清空螞蟻）") { [weak self] in self?.colony.reset() })
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

        guard colony.phase == .running, !colony.isPaused else { return }
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
        if colony.phase == .running, let nest = colony.nest {
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
        let picking = colony.phase == .choosingNest
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
