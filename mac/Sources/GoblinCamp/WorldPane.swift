import AppKit
import CoreLocation

/// 大世界, the Mac's own page of the main window (the phone's is pwa/app/pages/world.vue; server/WORLD.md §15): the real map
/// on the left (WorldMapView), and on the right the camp's standing, search and landmarks, the enemies coming, the parties on
/// the road, what happened lately and the reports. Clicking a cell puts its card in the right column instead (what is there,
/// and what can be done: attack, settle, send more, build, recall, move the camp); sending a party opens the dispatch sheet
/// (WorldDispatch). The server fights, walks and keeps the books; this only asks and shows. A held cell's own page, a report's
/// replay, the talents and the leaderboard are still the web app's, in a window of their own.
final class WorldPane: NSObject, MainPane, NSSearchFieldDelegate {
    let paneView = NSView(frame: NSRect(x: 0, y: 0, width: 1000, height: 700))
    private let api: APIClient
    private let map = WorldMapView(frame: NSRect(x: 0, y: 0, width: 600, height: 700))
    private let side = NSView()
    private let titleLabel = GuildUI.label("大世界", size: 18, bold: true)
    private let subLabel = GuildUI.label("", size: 12, color: .secondaryLabelColor)
    private let searchField = NSSearchField()
    private var talentsButton: ClosureButton!
    private let scroll = NSScrollView()
    private let doc = TopDownView()
    private let stack = NSStackView()

    /// The signed-in account (whose cells are "mine").
    var me: () -> String? = { nil }
    /// 看營地: the camp's own page.
    var onOpenCamp: (() -> Void)?
    /// 傳訊息: a friend's chat.
    var onMessage: ((String) -> Void)?

    // what the server said
    private var world: WorldMe?
    private var cells: [WorldCell] = []
    private var friends: FriendsPane.List?
    private var problem = ""
    private var loaded = false
    /// The last look at the map (a fresh one close by needs no other).
    private var fetched: (at: Date, center: CLLocationCoordinate2D)?
    /// The next refresh puts the map back on the camp (opening the page starts there, not where it was dragged last time).
    private var backHome = true
    private var refreshing = false

    // what is picked and asked
    private var selected: String?
    private var message = ""
    private var busy = false
    private var asking: String? // "open" / "move": the camp's place is asked twice, in the card itself
    /// 從這裡出征: where a party sets out from ("home" or a held cell), once picked on the map.
    private var launchFrom: String?
    private var way: WorldRoute?
    private var wayAsked = 0
    private var landmarks: [WorldPlace]?
    private var landmarkKind = ""
    private var landmarkProblem = ""
    private var searchResults: [WorldPlace]?
    private var searchProblem = ""
    private var searching = false
    /// Countdowns redrawn every second, without building the column again.
    private var ticks: [(NSTextField, () -> String)] = []
    private var clock: Timer?
    private var poll: Timer?
    private var dispatch: WorldDispatch?
    private var webWindows: [String: (window: NSWindow, pane: WebPane)] = [:]

    private var names: WorldNames { .shared }
    private var race: String { Characters.current.id }
    private static let fetchRadius = 1800.0
    private static let stillCovered = 900.0
    /// Places to start looking from (the map is the real world: somewhere public, not your home).
    private static let places: [(String, Double, Double)] = [("大安森林公園", 25.0302, 121.5357), ("台北 101", 25.0336, 121.5647), ("新竹公園", 24.8016, 120.9786), ("台中公園", 24.1449, 120.6844), ("高雄中央公園", 22.6246, 120.3016)]

    init(api: APIClient) {
        self.api = api
        super.init()
        map.translatesAutoresizingMaskIntoConstraints = false
        side.translatesAutoresizingMaskIntoConstraints = false
        paneView.addSubview(map)
        paneView.addSubview(side)
        map.onSelect = { [weak self] in self?.pick($0) }
        map.onPan = { [weak self] c in self?.moved(to: c) }
        map.onHome = { [weak self] in self?.goHome() }

        // the right column: the standing and search on top (stay put), the rest scrolls
        searchField.placeholderString = "搜尋地點，例如：台藝大、台北車站"
        searchField.sendsWholeSearchString = true
        searchField.target = self
        searchField.action = #selector(search)
        searchField.delegate = self
        talentsButton = button("🌟 天賦") { [weak self] in self?.openWeb("/talents", title: "種族天賦") }
        let races = button("🧬 種族") { [weak self] in self?.openWeb("/race", title: "種族") }
        let board = button("排行") { [weak self] in self?.openWeb("/leaderboard", title: "排行榜") }
        let land = button("領地") { [weak self] in self?.openWeb("/territory", title: "我的領地") }
        let titleRow = GuildUI.row([titleLabel, NSView(), talentsButton, races, land, board])
        titleRow.arrangedSubviews[1].setContentHuggingPriority(.init(1), for: .horizontal)
        let landmarkButton = button("🏛️ 地圖這附近的地標") { [weak self] in self?.toggleLandmarks() }
        let top = NSStackView(views: [titleRow, subLabel, GuildUI.row([searchField, landmarkButton])])
        top.orientation = .vertical
        top.alignment = .leading
        top.spacing = 6
        top.translatesAutoresizingMaskIntoConstraints = false
        side.addSubview(top)

        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        doc.translatesAutoresizingMaskIntoConstraints = false
        doc.addSubview(stack)
        scroll.documentView = doc
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        scroll.borderType = .noBorder
        scroll.automaticallyAdjustsContentInsets = false
        scroll.translatesAutoresizingMaskIntoConstraints = false
        side.addSubview(scroll)
        let line = GuildUI.separator()
        line.translatesAutoresizingMaskIntoConstraints = false
        side.addSubview(line)

        NSLayoutConstraint.activate([
            map.leadingAnchor.constraint(equalTo: paneView.leadingAnchor, constant: 12), map.topAnchor.constraint(equalTo: paneView.topAnchor, constant: 12),
            map.bottomAnchor.constraint(equalTo: paneView.bottomAnchor, constant: -12), map.trailingAnchor.constraint(equalTo: side.leadingAnchor, constant: -12),
            side.topAnchor.constraint(equalTo: paneView.topAnchor), side.bottomAnchor.constraint(equalTo: paneView.bottomAnchor),
            side.trailingAnchor.constraint(equalTo: paneView.trailingAnchor), side.widthAnchor.constraint(equalToConstant: 380),
            top.topAnchor.constraint(equalTo: side.topAnchor, constant: 16), top.leadingAnchor.constraint(equalTo: side.leadingAnchor, constant: 8),
            top.trailingAnchor.constraint(equalTo: side.trailingAnchor, constant: -20),
            titleRow.widthAnchor.constraint(equalTo: top.widthAnchor),
            searchField.widthAnchor.constraint(greaterThanOrEqualToConstant: 160),
            line.topAnchor.constraint(equalTo: top.bottomAnchor, constant: 10), line.leadingAnchor.constraint(equalTo: side.leadingAnchor), line.trailingAnchor.constraint(equalTo: side.trailingAnchor),
            scroll.topAnchor.constraint(equalTo: line.bottomAnchor), scroll.leadingAnchor.constraint(equalTo: side.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: side.trailingAnchor), scroll.bottomAnchor.constraint(equalTo: side.bottomAnchor),
            doc.leadingAnchor.constraint(equalTo: scroll.contentView.leadingAnchor), doc.trailingAnchor.constraint(equalTo: scroll.contentView.trailingAnchor),
            doc.topAnchor.constraint(equalTo: scroll.contentView.topAnchor),
            doc.heightAnchor.constraint(greaterThanOrEqualTo: scroll.contentView.heightAnchor),
            stack.topAnchor.constraint(equalTo: doc.topAnchor, constant: 12), stack.bottomAnchor.constraint(lessThanOrEqualTo: doc.bottomAnchor, constant: -16),
            stack.leadingAnchor.constraint(equalTo: doc.leadingAnchor, constant: 8), stack.trailingAnchor.constraint(equalTo: doc.trailingAnchor, constant: -20),
        ])
        map.look(at: CLLocationCoordinate2D(latitude: 25.0302, longitude: 121.5357), meters: 2400, animated: false)
        render()
    }

    // MARK: the page coming and going

    func paneWillShow() {
        backHome = true
        map.start()
        clock?.invalidate()
        clock = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.tick() }
        poll?.invalidate()
        // (a party on the road: look again every 20 seconds, to see it arrive)
        poll = Timer.scheduledTimer(withTimeInterval: 20, repeats: true) { [weak self] _ in
            guard let self, !(self.world?.walking.isEmpty ?? true) || !(self.world?.incoming?.isEmpty ?? true) else { return }
            self.refresh()
        }
        refresh()
        loadFriends()
    }

    func paneDidHide() {
        map.stop()
        clock?.invalidate()
        poll?.invalidate()
    }

    /// The camp changed on the server (a party arriving, someone attacking): look again if the page is up.
    func campChanged() {
        guard paneView.window?.isVisible == true, clock != nil, clock!.isValid else { return }
        refresh()
    }

    /// Somebody else signed in: forget everything.
    func reset() {
        world = nil
        cells = []
        friends = nil
        selected = nil
        launchFrom = nil
        fetched = nil
        backHome = true
        for (_, w) in webWindows { w.window.close() }
        webWindows = [:]
        render()
    }

    /// For the test runs (CAMP_TEST_WORLD): the main window as it stands, saved as a picture; `done` says what showed.
    func snapshotForTesting(to path: String, done: @escaping (String) -> Void) {
        guard let window = paneView.window,
              let image = CGWindowListCreateImage(.null, .optionIncludingWindow, CGWindowID(window.windowNumber), [.boundsIgnoreFraming, .bestResolution]) else { return done("(no window)") }
        let rep = NSBitmapImageRep(cgImage: image)
        try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
        // (a sheet up over it is a window of its own: saved beside it)
        if let sheet = window.attachedSheet,
           let img = CGWindowListCreateImage(.null, .optionIncludingWindow, CGWindowID(sheet.windowNumber), [.boundsIgnoreFraming, .bestResolution]) {
            try? NSBitmapImageRep(cgImage: img).representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path.replacingOccurrences(of: ".png", with: "-sheet.png")))
        }
        done("\(cells.count) cells, home \(world?.homeCell ?? "none"), \(problem.isEmpty ? "ok" : problem)")
    }

    /// For the test runs: picks a cell (CAMP_TEST_WORLD_PICK: "lair", "mine", or a cell id) and, for "lair", opens the dispatch sheet.
    func pickForTesting(_ what: String) {
        let c: WorldCell? = what == "lair" ? cells.filter { $0.lair != nil && $0.owner == nil && $0.boss == nil }.min { WorldGrid.meters($0.coordinate, map.center) < WorldGrid.meters($1.coordinate, map.center) }
            : what == "mine" ? cells.first { $0.owner?.id == myID && $0.home != true } ?? cells.first { $0.owner?.id == myID }
            : cells.first { $0.cell == what }
        guard let c else { return NSLog("GoblinCamp test: world: nothing to pick for \(what)") }
        pick(c.cell)
        if what == "lair" { DispatchQueue.main.asyncAfter(deadline: .now() + 1) { self.openDispatch("attack") } }
        // (CAMP_TEST_WORLD_SEND: and send it, then say what is on the road)
        if what == "lair", ProcessInfo.processInfo.environment["CAMP_TEST_WORLD_SEND"] != nil {
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) { self.dispatch?.sendForTesting() }
            DispatchQueue.main.asyncAfter(deadline: .now() + 8) {
                NSLog("GoblinCamp test: world sent: \(self.message); on the road \(self.world?.walking.map { "\($0.party) → \($0.to)" } ?? [])")
            }
        }
    }

    // MARK: asking the server

    @MainActor private func loadCells(_ center: CLLocationCoordinate2D, fresh: Bool = true) async throws {
        if !fresh, let f = fetched, Date().timeIntervalSince(f.at) < 60, WorldGrid.meters(f.center, center) < Self.stillCovered { return }
        let got: [WorldCell] = try await api.request("GET", String(format: "world/cells?lat=%.6f&lng=%.6f&radius=%.0f", center.latitude, center.longitude, Self.fetchRadius))
        fetched = (Date(), center)
        // (laid over what is there: the map never goes blank while the new comes; only what is near enough is kept)
        var byCell: [String: WorldCell] = [:]
        for c in cells where WorldGrid.meters(c.coordinate, center) < Self.fetchRadius + Self.stillCovered { byCell[c.cell] = c }
        for c in got { byCell[c.cell] = c }
        cells = Array(byCell.values)
    }

    func refresh() {
        guard !refreshing else { return }
        refreshing = true
        Task { @MainActor in
            defer { refreshing = false }
            do {
                let goHome = backHome
                world = try await api.request("GET", "world")
                backHome = false
                if goHome, let h = world?.home {
                    let c = CLLocationCoordinate2D(latitude: h.lat, longitude: h.lng)
                    map.look(at: c, meters: 2400, animated: loaded)
                    try await loadCells(c)
                } else {
                    try await loadCells(map.center)
                }
                problem = ""
                loaded = true
            } catch let e as APIError {
                problem = e.message
            } catch {
                problem = error.localizedDescription
            }
            render()
            loadWay()
        }
    }

    private func loadFriends() {
        Task { @MainActor in
            friends = try? await api.request("GET", "friends", as: FriendsPane.List.self)
            render()
        }
    }

    /// The map was dragged: fetched only when it has gone past what was looked at lately.
    private func moved(to c: CLLocationCoordinate2D) {
        Task { @MainActor in
            try? await loadCells(c, fresh: false)
            drawMap()
            if landmarks != nil { findLandmarks() }
        }
    }

    private func go(to c: CLLocationCoordinate2D, pick cell: String? = nil) {
        map.look(at: c)
        Task { @MainActor in
            try? await loadCells(c, fresh: false)
            if let cell { pick(cell) } else { drawMap() }
        }
    }

    private func goHome() {
        guard let h = world?.home else { return }
        go(to: CLLocationCoordinate2D(latitude: h.lat, longitude: h.lng))
    }

    /// Does something; the new standing shows, or what went wrong.
    private func act(_ done: String, _ work: @escaping () async throws -> Void) {
        busy = true
        message = ""
        render()
        Task { @MainActor in
            do {
                try await work()
                message = done
                busy = false
                refresh()
            } catch let e as APIError {
                message = e.message
                busy = false
                render()
            } catch {
                message = error.localizedDescription
                busy = false
                render()
            }
        }
    }

    private struct Nothing: Decodable {}
    private func post(_ path: String, _ body: Encodable? = nil) async throws {
        struct Empty: Encodable {}
        _ = try await api.raw("POST", path, body: body ?? Empty())
    }

    // MARK: what is picked

    private var cell: WorldCell? { cells.first { $0.cell == selected } }
    private var myID: String? { me() }
    private var isMine: Bool {
        guard let c = cell, let o = c.owner else { return false }
        return o.id == myID || (world?.cells.contains { $0.cell == c.cell } ?? false)
    }
    private var myCell: WorldMe.Cell? { world?.cells.first { $0.cell == selected } }
    private var isHome: Bool { cell != nil && cell?.cell == world?.homeCell }
    private var isFriend: Bool { cell?.owner.map { o in friends?.friends.contains { $0.id == o.id } ?? false } ?? false }
    private var askedFriend: Bool { cell?.owner.map { o in friends?.outgoing.contains { $0.id == o.id } ?? false } ?? false }
    private var spare: Int { max(0, (world?.atHome ?? 0) - 2) }
    private var canAct: Bool {
        guard let w = world, w.open else { return false }
        return spare > 0 || launchFrom != nil || w.cells.contains { $0.garrison > w.rules.garrisonMin && $0.cell != w.homeCell }
    }

    private func pick(_ c: String) {
        if let from = launchFrom, c == (from == "home" ? world?.homeCell : from) { return } // (that is where it sets out)
        selected = c
        message = ""
        asking = nil
        searchResults = nil
        render()
        drawMap()
        loadWay()
        if launchFrom != nil { aimAt() }
    }

    private func close() {
        selected = nil
        message = ""
        way = nil
        render()
        drawMap()
    }

    /// With a start picked: open the sheet for what the cell clicked calls for (a friend's: the card, to pick help or attack).
    private func aimAt() {
        guard let c = cell else { return }
        if (c.owner != nil && isFriend) || c.cell == world?.homeCell { return }
        openDispatch(isMine ? "move" : (c.boss != nil || c.lair != nil || c.owner != nil) ? "attack" : "settle")
    }

    /// The way there from the camp (or the cell picked to set out from), drawn before anybody goes.
    private func loadWay() {
        way = nil
        wayAsked += 1
        let asked = wayAsked
        let from = launchFrom ?? "home"
        let start = from == "home" ? world?.homeCell : from
        guard let to = selected, let start, world?.open == true, to != start else { return drawPlan() }
        struct Body: Encodable { let from: String; let to: String }
        Task { @MainActor in
            let got = try? await api.request("POST", "world/expeditions/route", body: Body(from: from, to: to), as: WorldRoute.self)
            guard asked == wayAsked else { return }
            way = got
            drawPlan()
            render()
        }
    }

    // MARK: the map

    private var parties: [WorldMapView.Party] {
        guard let w = world else { return [] }
        let mine = w.walking.compactMap { e -> WorldMapView.Party? in
            guard let from = e.from == "home" ? w.homeCell : e.from, let a = WorldText.date(e.setOutAt), let b = WorldText.date(e.arriveAt) else { return nil }
            return WorldMapView.Party(id: e.id, path: (e.route ?? [from, e.to]).map(WorldGrid.center), setOutAt: a, arriveAt: b, race: race, hostile: false)
        }
        let theirs = (w.incoming ?? []).compactMap { e -> WorldMapView.Party? in
            guard let a = WorldText.date(e.setOutAt), let b = WorldText.date(e.arriveAt) else { return nil }
            return WorldMapView.Party(id: e.id, path: (e.route ?? [e.from, e.to]).map(WorldGrid.center), setOutAt: a, arriveAt: b, race: e.by.race, hostile: true)
        }
        return mine + theirs
    }

    /// The reports of this camp being attacked in the last day.
    private var attackedLately: [WorldExpedition] {
        (world?.recent ?? []).filter { $0.defending == true && Date().timeIntervalSince(WorldText.date($0.arriveAt) ?? .distantPast) < 24 * 3600 }
    }

    private var alerts: [String] { Array(Set(attackedLately.map(\.to) + (world?.incoming ?? []).map(\.to))) }

    private var plan: [CLLocationCoordinate2D]? { (way?.waypoints.isEmpty ?? true) ? nil : way!.waypoints.map(WorldGrid.center) }

    private func drawMap() {
        map.setHome(race: world?.homeCell == nil ? nil : race)
        map.show(cells: cells, mine: myID, selected: selected, walkingTo: world?.walking.map(\.to) ?? [], alerts: alerts, parties: parties, plan: plan)
    }

    private func drawPlan() { map.pick(selected, plan: plan) }

    // MARK: search and landmarks

    @objc private func search() {
        let q = searchField.stringValue.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty, !searching else {
            if q.isEmpty { searchResults = nil; searchProblem = ""; render() }
            return
        }
        searching = true
        searchProblem = ""
        landmarks = nil
        render()
        let at = map.center
        struct Found: Decodable { let places: [WorldPlace] }
        Task { @MainActor in
            defer { searching = false; render() }
            do {
                let enc = q.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? q
                searchResults = try await api.request("GET", String(format: "world/search?q=%@&lat=%.6f&lng=%.6f", enc, at.latitude, at.longitude), as: Found.self).places
            } catch let e as APIError {
                searchResults = nil
                searchProblem = e.message
            } catch {
                searchProblem = error.localizedDescription
            }
        }
    }

    private func toggleLandmarks() {
        if landmarks != nil {
            landmarks = nil
            render()
        } else {
            searchResults = nil
            findLandmarks()
        }
    }

    private func findLandmarks() {
        landmarkProblem = ""
        let at = map.center
        struct Found: Decodable { let landmarks: [WorldPlace] }
        Task { @MainActor in
            do {
                landmarks = try await api.request("GET", String(format: "world/landmarks?lat=%.6f&lng=%.6f", at.latitude, at.longitude), as: Found.self).landmarks
            } catch let e as APIError {
                landmarkProblem = e.message
            } catch {
                landmarkProblem = error.localizedDescription
            }
            render()
        }
    }

    // MARK: the web app's own pages (a held cell, a report, the talents, the leaderboard), each in a window

    /// A page of the web app in a window of its own beside the map (one window per first path part).
    func openWeb(_ path: String, title: String) {
        let key = path.split(separator: "/").first.map(String.init) ?? path
        if let w = webWindows[key] {
            w.pane.load(path)
            w.window.title = title
            w.window.makeKeyAndOrderFront(nil)
            return
        }
        let pane = WebPane(api: api, path: path)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 560, height: 760), styleMask: [.titled, .closable, .resizable, .miniaturizable], backing: .buffered, defer: false)
        window.title = title
        window.isReleasedWhenClosed = false
        pane.paneView.frame = window.contentView!.bounds
        pane.paneView.autoresizingMask = [.width, .height]
        window.contentView!.addSubview(pane.paneView)
        if let host = paneView.window { window.setFrameTopLeftPoint(NSPoint(x: host.frame.maxX - 580, y: host.frame.maxY - 40)) } else { window.center() }
        webWindows[key] = (window, pane)
        pane.paneWillShow()
        window.makeKeyAndOrderFront(nil)
    }

    // MARK: sending a party

    private func openDispatch(_ kind: String, again: WorldLastAttack? = nil) {
        guard let c = cell, let w = world, let host = paneView.window else { return }
        let sheet = WorldDispatch(api: api, target: c, kind: kind, me: w, race: race, start: launchFrom, again: again)
        sheet.onRoute = { [weak self] route in
            self?.way = route
            self?.drawPlan()
        }
        sheet.onSent = { [weak self] text in
            guard let self else { return }
            self.launchFrom = nil
            self.message = text
            self.refresh()
        }
        sheet.onClose = { [weak self] in
            self?.dispatch = nil
            self?.loadWay() // (the sheet may have shown another start's way)
        }
        dispatch = sheet
        sheet.present(on: host)
    }

    private func openRecall(campers: Bool) {
        guard let c = cell, let w = world, let mc = myCell, let host = paneView.window else { return }
        let sheet = WorldRecall(api: api, from: c.cell, title: campers ? "叫扎營的走" : "撤回", available: campers ? mc.camping : mc.garrison, keep: w.rules.garrisonMin, campers: campers)
        sheet.onDone = { [weak self] text in
            self?.message = text
            self?.refresh()
        }
        sheet.present(on: host)
    }

    // MARK: the right column

    private func tick() {
        for (label, text) in ticks { label.stringValue = text() }
    }

    private func clear() {
        for v in stack.arrangedSubviews {
            stack.removeArrangedSubview(v)
            v.removeFromSuperview()
        }
        ticks = []
    }

    private func add(_ v: NSView, to s: NSStackView? = nil) {
        let s = s ?? stack
        s.addArrangedSubview(v)
        v.widthAnchor.constraint(equalTo: s.widthAnchor).isActive = true
    }

    private func text(_ s: String, size: CGFloat = 13, bold: Bool = false, color: NSColor = .labelColor) -> NSTextField {
        GuildUI.label(s, size: size, bold: bold, color: color, width: 340)
    }

    private func ticking(_ make: @escaping () -> String, size: CGFloat = 12, color: NSColor = .secondaryLabelColor) -> NSTextField {
        let l = text(make(), size: size, color: color)
        ticks.append((l, make))
        return l
    }

    /// A panel: a rounded box with a title and what is in it.
    private func panel(_ title: String?, tint: NSColor? = nil, _ views: [NSView]) -> NSView {
        let inner = NSStackView()
        inner.orientation = .vertical
        inner.alignment = .leading
        inner.spacing = 6
        if let title { add(text(title, size: 13, bold: true, color: tint ?? .labelColor), to: inner) }
        for v in views { add(v, to: inner) }
        return WorldPanel(inner, tint: tint)
    }

    /// A line to click (a report, a landmark, an enemy coming).
    private func clickable(_ views: [NSView], _ action: @escaping () -> Void) -> NSView {
        let row = WorldClickRow(action: action)
        let inner = NSStackView(views: views)
        inner.orientation = .vertical
        inner.alignment = .leading
        inner.spacing = 2
        inner.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(inner)
        NSLayoutConstraint.activate([
            inner.leadingAnchor.constraint(equalTo: row.leadingAnchor), inner.trailingAnchor.constraint(equalTo: row.trailingAnchor),
            inner.topAnchor.constraint(equalTo: row.topAnchor, constant: 4), inner.bottomAnchor.constraint(equalTo: row.bottomAnchor, constant: -4),
        ])
        for v in views { v.widthAnchor.constraint(lessThanOrEqualTo: inner.widthAnchor).isActive = true }
        return row
    }

    private func buttons(_ list: [NSView]) -> NSView {
        // (wrapping: rows of up to three)
        let rows = NSStackView()
        rows.orientation = .vertical
        rows.alignment = .leading
        rows.spacing = 6
        var i = 0
        while i < list.count {
            rows.addArrangedSubview(GuildUI.row(Array(list[i..<min(list.count, i + 3)]), spacing: 6))
            i += 3
        }
        return rows
    }

    private func note(_ s: String) -> NSTextField { text(s, size: 12, color: .secondaryLabelColor) }

    private func button(_ title: String, prominent: Bool = false, enabled: Bool = true, _ action: @escaping () -> Void) -> ClosureButton {
        let b = ClosureButton(title: title, action: action)
        b.bezelStyle = .rounded
        b.controlSize = .regular
        if prominent { b.bezelColor = .controlAccentColor } // (white on the accent reads well; on gold it did not)
        b.isEnabled = enabled
        return b
    }

    func render() {
        clear()
        drawMap()
        let w = world
        if let w {
            var sub = "\(Characters.current.noun) Lv\(w.level)（\(w.xp)/\(w.nextLevelXp)）・\(w.cells.count) 格・在家 \(w.atHome)"
            if let u = w.upkeep, u.paying > 0 { sub += "・乾糧 \(u.rations)（每 \(u.everyHours) 小時吃 \(u.perYield)）" }
            subLabel.stringValue = sub
            let spent = w.talents?.picks.values.reduce(0, +) ?? 0
            talentsButton.isHidden = w.talents == nil
            talentsButton.bezelColor = (w.talents?.points ?? 0) > spent ? .controlAccentColor : nil
        } else {
            subLabel.stringValue = ""
            talentsButton.isHidden = true
        }
        guard let w else {
            add(text(problem.isEmpty ? "讀取中…" : problem, color: .secondaryLabelColor))
            return
        }
        if !problem.isEmpty { add(text(problem, color: .systemRed)) }
        if let s = w.season { add(panel(nil, tint: .systemOrange, [text("\(s.icon) \(s.name)：\(s.blurb)（到 \(WorldText.time(s.endsAt))）")])) }

        if w.homeCell == nil && !w.canOpen {
            add(panel("還不能開啟大世界", [text("營地要曾經有過 \(w.unlockPeak) 隻（第三階段）才能開啟；現在最多時是 \(w.peak) 隻。"), note("先看看附近有什麼：拖動地圖，點格子看看。")]))
        } else if w.homeCell == nil {
            add(panel("先選營地的位置", tint: .systemGreen, [text("地圖是真實世界：點一格，把你的營地放在那裡——整個營地都在那一格，不用派人。之後再從營地出發去打怪、佔地。請選公園、地標這類公開的地方，不要選自己家。")]))
        } else if !w.open {
            let ends = w.shieldEndsAt.map { "；\(WorldText.time($0))（龜縮滿 24 小時）會自動結束" } ?? ""
            add(panel("龜縮中", tint: .systemBlue, [text("上一場打輸了，營地和領地現在都不會被打，但也不能出征。準備好了就重新開啟\(ends)。"),
                                                   button("重新開啟大世界", prominent: true, enabled: !busy) { [weak self] in self?.act("重新開啟了大世界。") { try await self?.post("world/open") } }]))
        }
        if w.homeCell == nil {
            let chips = Self.places.map { p in button(p.0) { [weak self] in self?.go(to: CLLocationCoordinate2D(latitude: p.1, longitude: p.2)) } }
            add(buttons(chips))
        }
        if let b = w.bosses?.first {
            add(clickable([text("世界魔王：\(b.name)（\(String(format: "%.1f", b.km)) 公里外）", bold: true, color: .systemRed),
                           ticking { "剩 \(100 * b.hp / max(1, b.maxHp))% 血・\(WorldText.left(b.endsAt))後離開・點一下去看看" }]) { [weak self] in
                self?.go(to: CLLocationCoordinate2D(latitude: b.lat, longitude: b.lng), pick: b.cell)
            })
        }
        if let from = launchFrom {
            add(panel(nil, tint: .systemYellow, [text("從\(from == "home" ? "營地" : "這塊領地")出征：點地圖上要去的格子", bold: true),
                                                 button("取消") { [weak self] in self?.launchFrom = nil; self?.render() }]))
        }
        renderSearch()
        if cell != nil {
            renderCard(w)
        } else {
            if selected != nil { add(text("讀取這一格中…", color: .secondaryLabelColor)) }
            renderLists(w)
        }
        add(note("真實世界的地圖。格子裡是那裡最強的怪物與等級；黃框是你的，紅框是別人的，深紅粗框是別人蓋了東西的領地（隊伍要繞過去）；黃色點點是點的那一格要走的路。點一格看看。"))
    }

    private func renderSearch() {
        if searching { add(text("找…", color: .secondaryLabelColor)) }
        if let found = searchResults {
            var rows: [NSView] = [GuildUI.row([text("「\(searchField.stringValue)」找到 \(found.count) 個地方", bold: true), button("收起") { [weak self] in self?.searchResults = nil; self?.render() }])]
            if found.isEmpty { rows.append(note("找不到這個地方，換個說法試試（例如全名：國立臺灣藝術大學）。")) }
            for p in found {
                rows.append(clickable([text("📍 \(p.name)", bold: true), note([p.where, p.km.map(WorldText.distance)].compactMap { $0 }.joined(separator: "・"))]) { [weak self] in
                    self?.searchResults = nil
                    self?.go(to: CLLocationCoordinate2D(latitude: p.lat, longitude: p.lng), pick: p.cell)
                })
            }
            add(panel(nil, rows))
        }
        if !searchProblem.isEmpty { add(text(searchProblem, color: .systemRed)) }
        if let list = landmarks {
            let kinds = names.landmarks.filter { k in list.contains { $0.kind == k.kind } }
            var chips: [NSView] = [button("全部 \(list.count)", prominent: landmarkKind.isEmpty) { [weak self] in self?.landmarkKind = ""; self?.render() }]
            chips += kinds.map { k in button("\(k.icon) \(k.name)", prominent: landmarkKind == k.kind) { [weak self] in self?.landmarkKind = k.kind; self?.render() } }
            var rows: [NSView] = [buttons(chips), note("地圖中心 3 公里內，拖動地圖會跟著換")]
            let shown = list.filter { landmarkKind.isEmpty || $0.kind == landmarkKind }
            if shown.isEmpty { rows.append(note("地圖中心 3 公里內沒有地標，拖到別的地方再找一次。")) }
            for l in shown {
                let rule = names.landmark(l.kind ?? "")
                let whose = l.owner.map { $0.id == myID ? "你的" : "\($0.name)的" } ?? "沒人佔"
                rows.append(clickable([text("\(rule?.icon ?? "📍") \(l.name)", bold: true),
                                       note("\(rule?.name ?? "")・\(rule?.blurb ?? "")・\(l.km.map(WorldText.distance) ?? "")・\(whose)")]) { [weak self] in
                    self?.landmarks = nil
                    self?.go(to: CLLocationCoordinate2D(latitude: l.lat, longitude: l.lng), pick: l.cell)
                })
            }
            add(panel("附近的地標", rows))
        }
        if !landmarkProblem.isEmpty { add(text(landmarkProblem, color: .systemRed)) }
    }

    private func renderLists(_ w: WorldMe) {
        if let coming = w.incoming, !coming.isEmpty {
            add(panel("⚠️ 敵軍來襲", tint: .systemRed, coming.map { e in
                clickable([text("\(e.by.name) 派了 \(e.party) 隻 → 你的\(e.where.kind == "home" ? "營地" : e.where.label)\(e.where.landmark.map { "・\($0)" } ?? "")"),
                           ticking { "\(WorldText.arriving(e.arriveAt))・點一下看那一格（可以派人增援，或撤回）" }]) { [weak self] in
                    self?.go(to: WorldGrid.center(e.to), pick: e.to)
                }
            }))
        }
        if !w.walking.isEmpty {
            let kinds = ["move": "（搬家）", "guard": "（幫守）", "recall": "（撤回）", "reroute": "（找有空位的領地）", "retreat": "（撤退）"]
            add(panel("在路上", w.walking.map { e in
                clickable([text("\(e.party) 隻 → \(cellName(e.to))\(kinds[e.kind] ?? "")"), ticking { WorldText.arriving(e.arriveAt) }]) { [weak self] in
                    self?.go(to: WorldGrid.center(e.to), pick: e.to)
                }
            }))
        }
        if let list = w.happenings, !list.isEmpty {
            add(panel("最近的事", list.prefix(5).map { h in
                var line = ""
                if let l = h.lairBack {
                    line = "\(l.held ? "守住了" : "被搶回去了")：\(l.name)（\(l.level) 級）回來搶領地\(l.fallen > 0 ? "，倒下 \(l.fallen) 隻" : "")\(l.held && !l.loot.isEmpty ? "，撿到 \(WorldText.loot(l.loot))" : "")"
                } else if let b = h.bossReward {
                    line = "世界魔王\(b.name)倒下了：出了 \(Int((b.share * 100).rounded()))% 的力，分到 \(WorldText.loot(b.loot))，經驗 +\(b.xp)"
                } else if let y = h.yields {
                    line = "領地送來了 \(WorldText.loot(y))"
                }
                let v = NSStackView(views: [text(line), note(WorldText.time(h.at))])
                v.orientation = .vertical
                v.alignment = .leading
                v.spacing = 1
                return v
            }))
        }
        if !w.recent.isEmpty {
            add(panel("戰報", w.recent.prefix(5).map { r in
                let well = WorldText.wentWell(r)
                let what = r.defending == true ? "\(r.by ?? "有人")來打\(WorldText.place(r).map { "：\($0)" } ?? "")" : (r.outcome?.against ?? "")
                return clickable([text(WorldText.outcome(r), bold: true, color: well ? .systemGreen : .systemRed), text(what), note(WorldText.time(r.arriveAt))]) { [weak self] in
                    self?.openWeb("/expedition/\(r.id)", title: "戰報")
                }
            }))
        }
    }

    private func cellName(_ id: String) -> String {
        if id == "home" { return "營地" }
        guard let c = cells.first(where: { $0.cell == id }) else { return "遠方" }
        return c.owner.map { "\($0.name)的領地" } ?? c.lair?.name ?? names.terrain(c.terrain)
    }

    /// When the camp may move again, as words (nil: it may now).
    private var moveWait: String? {
        guard let at = WorldText.date(world?.homeMoveAt), at > Date() else { return nil }
        let h = Int(ceil(at.timeIntervalSinceNow / 3600))
        return h >= 24 ? "\(Int(ceil(Double(h) / 24))) 天後" : "\(h) 小時後"
    }

    /// The card of the cell picked.
    private func renderCard(_ w: WorldMe) {
        guard let c = cell else { return }
        let level = w.level
        var rows: [NSView] = []
        // the head: a picture, the title and what stands out about the cell
        let badge: CGImage? = c.boss.flatMap { WorldArt.foe($0.kind) } ?? c.owner.flatMap { WorldArt.face($0.race) }
            ?? c.lair.flatMap { WorldArt.foe($0.kind == "enemy_town" ? "enemy_town" : names.leader($0.foes)) }
        let title: String = {
            if let o = c.owner { return isMine ? (isHome ? "你的營地" : "你的領地") : "\(o.name)的領地" }
            if let b = c.boss { return "世界魔王・\(b.name)" }
            if let l = c.lair { return "\(l.name)  \(l.level) 級" }
            if c.meteor != nil { return "☄️ 流星・\(WorldText.ground(c.terrain, c.detail))" }
            return WorldText.ground(c.terrain, c.detail)
        }()
        let closeButton = button("✕") { [weak self] in self?.close() }
        closeButton.bezelStyle = .circular
        let titleField = text(title, size: 16, bold: true)
        titleField.setContentHuggingPriority(.defaultLow, for: .horizontal)
        var headViews: [NSView] = []
        if let badge { headViews.append(WorldArt.view(badge, size: 44)) }
        headViews += [titleField, closeButton]
        rows.append(GuildUI.row(headViews, spacing: 10))

        let from = launchFrom.map { $0 == "home" ? "營地" : "這塊領地" } ?? "營地"
        var ground = WorldText.ground(c.terrain, c.detail)
        if let way, !way.waypoints.isEmpty, !isMine || launchFrom != nil { ground += "・從\(from)走約 \(walkMinutes(way)) 分鐘" }
        rows.append(note(ground))
        func warn(_ s: String, _ color: NSColor = .systemRed) { rows.append(text(s, size: 12, bold: true, color: color)) }
        if let need = c.lair?.minRaceLevel, level < need { warn("🔒 需要種族等級 \(need) 才能打（你現在 \(level) 級）") }
        if c.boss != nil, level < names.rules.bossMinRaceLevel { warn("🔒 世界魔王要種族等級 \(names.rules.bossMinRaceLevel) 才能打（你現在 \(level) 級）") }
        if c.lair?.boss == true { warn("👑 初期魔王：比一般巢穴強很多，會掉做中等裝備的材料。打輸了傷會留著，可以找朋友接著打。", .systemOrange) }
        if let way, way.waypoints.isEmpty { warn("🧱 \(way.blockedBy?.name ?? "別人")的領地擋在路上，從\(from)過不去") }
        if c.blocks == true { warn("🧱 有蓋東西的領地：你的隊伍不能穿過去，要繞路（打下來就通了）") }
        if c.threats?.contains("ambush") == true { warn("🎯 精靈的伏擊範圍：隊伍經過這裡會先被射倒一些（拿盾牌的不會）", .systemPurple) }
        if c.threats?.contains("blight") == true { warn("☠️ 死靈的腐化大地：你在這裡的領地產出會變少（城鎮、有聖樹的那一區不會）", .systemPurple) }
        if let d = c.detail { rows.append(note(WorldText.detailLine(d, race: race))) }
        if let m = c.meteor { warn("☄️ 流星掉在這裡：先派隊伍到的拿走 \(WorldText.loot(m.loot))・\(WorldText.time(m.endsAt))消失", .systemOrange) }
        for e in (w.incoming ?? []) where e.to == c.cell {
            rows.append(ticking({ "⚔️ \(e.by.name)派了 \(e.party) 隻正在路上，\(WorldText.arriving(e.arriveAt))" }, size: 12, color: .systemRed))
        }
        if let r = attackedLately.first(where: { $0.to == c.cell }) {
            rows.append(GuildUI.row([text("⚔️ \(r.by ?? "有人")\(WorldText.time(r.arriveAt))來打過：\(WorldText.outcome(r))", color: .systemRed),
                                     button("看戰報") { [weak self] in self?.openWeb("/expedition/\(r.id)", title: "戰報") }]))
        }
        if let lm = c.landmark, let rule = names.landmark(lm.kind) {
            rows.append(text("\(rule.icon) \(lm.name)（\(rule.name)）", bold: true, color: .systemBrown))
            rows.append(note(rule.blurb))
        }

        // what is there
        if let l = c.lair {
            let foes = GuildUI.row(l.foes.sorted { $0.value > $1.value }.map { id, n in
                let v = NSStackView(views: [WorldArt.view(WorldArt.foe(id), size: 30), note("\(names.foe(id)) ×\(n)")])
                v.orientation = .vertical
                v.spacing = 2
                return v
            } + [NSView(), text("戰力 \(l.power)", size: 14, bold: true)], spacing: 10)
            foes.alignment = .bottom
            rows.append(foes)
            if let wd = c.lairWounds {
                warn("受傷中：剩 \(wd.standing)/\(wd.total) 隻、\(Int((wd.hpShare * 100).rounded()))% 血，\(WorldText.time(wd.healedAt))恢復——趁現在派第二波！", .systemOrange)
            }
        } else if let b = c.boss {
            let bar = NSProgressIndicator()
            bar.isIndeterminate = false
            bar.maxValue = Double(b.maxHp)
            bar.doubleValue = Double(b.hp)
            rows.append(bar)
            rows.append(ticking { "\(b.hp) / \(b.maxHp) 血・\(WorldText.left(b.endsAt))後離開。牠的傷會留著，大家一起打。" })
        } else if isMine {
            let nest = ["none": "還沒有繁殖巢（不會自己生居民）", "building": "繁殖巢蓋到一半", "ready": "有繁殖巢，會自己生居民"][c.nest] ?? ""
            rows.append(text(isHome ? "營地就在這裡：在家的 \(c.garrison) 隻都住這、守這，營地本身就會生居民\(c.town ? "・城鎮" : "")" : "住了 \(c.garrison) 隻・\(nest)\(c.town ? "・城鎮" : "")"))
            if let n = myCell?.camping, n > 0 { rows.append(note("⛺ 外面扎營 \(n) 隻（住不下，等有空位就住進去，也會幫忙守）")) }
            if let g = c.guests, g > 0 { rows.append(note("🤝 好友幫守 \(g) 隻")) }
            if let b = c.building { rows.append(note("🏗️ \(names.building(b.kind, race: race)) \(b.level) 級\(b.busy ? "（蓋到一半）" : "")")) }
            let yields = (names.terrainYield[c.terrain] ?? []).map(names.material).joined(separator: "、")
            rows.append(note("每 3 小時產出：\(yields)\(myCell.map { "・下次 \(WorldText.time($0.nextYieldAt))" } ?? "")"))
        } else if let o = c.owner {
            rows.append(note("住了 \(c.garrison) 隻\(c.guests.map { $0 > 0 ? "・好友幫守 \($0) 隻" : "" } ?? "")\(c.building.map { "・\(names.building($0.kind, race: o.race)) \($0.level) 級" } ?? "")"))
        } else if let back = c.lairBackAt {
            rows.append(note("巢穴清掉了，\(WorldText.time(back)) 會回來。現在可以直接住。"))
        } else {
            rows.append(note("什麼都沒有，可以直接住。"))
        }

        // what can be done
        let place = c.landmark?.name ?? WorldText.ground(c.terrain, c.detail)
        let canMoveHere = w.homeCell != nil && !isHome && c.boss == nil && (c.owner == nil || isMine)
        var actions: [NSView] = []
        if w.homeCell == nil {
            if w.canOpen && c.owner == nil && c.boss == nil {
                if let l = c.lair { rows.append(note("營地放下來，這裡的\(l.name)就會被趕走。")) }
                if asking == "open" {
                    rows.append(panel(nil, tint: .systemYellow, [
                        text("把營地放在「\(place)」這一格？整個營地都在這裡（在家的 \(w.atHome) 隻都住這、守這），之後 \(names.rules.homeMoveDays) 天可以搬一次。"),
                        GuildUI.row([button("確定", prominent: true, enabled: !busy) { [weak self] in
                            guard let self, let at = self.selected else { return }
                            self.asking = nil
                            struct Body: Encodable { let cell: String }
                            self.backHome = true
                            self.act("大世界開啟了！營地就在這一格。") { try await self.post("world/open", Body(cell: at)) }
                        }, button("再想想") { [weak self] in self?.asking = nil; self?.render() }]),
                    ]))
                } else {
                    actions.append(button("把營地放在這裡", prominent: true, enabled: !busy) { [weak self] in self?.asking = "open"; self?.render() })
                }
            }
        } else if isMine {
            if !isHome {
                actions.append(button("進去看看", prominent: true) { [weak self] in self?.openWeb("/territory/\(c.cell)", title: "領地") })
            } else {
                actions.append(button("看營地", prominent: true) { [weak self] in self?.onOpenCamp?() })
            }
            let canLaunch = w.open && (isHome ? spare > 0 : (myCell?.garrison ?? 0) > w.rules.garrisonMin)
            actions.append(button("從這裡出征", enabled: canLaunch) { [weak self] in
                guard let self else { return }
                self.launchFrom = self.isHome ? "home" : self.selected
                self.selected = nil
                self.message = ""
                self.render()
            })
            if !isHome { actions.append(button("派人駐守", enabled: canAct) { [weak self] in self?.openDispatch("move") }) }
            if !isHome && c.nest == "none" {
                actions.append(button("蓋繁殖巢", enabled: !busy) { [weak self] in
                    self?.act("開始蓋繁殖巢了（\(w.rules.nestHours) 小時）。") { try await self?.post("world/cells/\(c.cell)/nest") }
                })
            }
            let centres = myCell?.regionCentres ?? myCell?.regionTowns ?? 0
            if !c.town && c.hub == nil, let mc = myCell, mc.region >= w.rules.townCellsEach * (centres + 1) {
                actions.append(button("🏘️ 蓋城鎮", enabled: !busy) { [weak self] in self?.act("蓋了城鎮！") { try await self?.post("world/cells/\(c.cell)/town") } })
                if !isHome {
                    for h in names.hubs where h.kind != "town" {
                        let icon = ["fortress": "🏰", "workstead": "⚒️", "sanctuary": "⛩️"][h.kind] ?? ""
                        let name = names.hub(h.kind, race: race)
                        let b = button("\(icon) 蓋\(name)", enabled: !busy) { [weak self] in
                            struct Body: Encodable { let kind: String }
                            self?.act("蓋了\(name)！") { try await self?.post("world/cells/\(c.cell)/hub", Body(kind: h.kind)) }
                        }
                        b.toolTip = h.blurb
                        actions.append(b)
                    }
                }
            }
            if !isHome { actions.append(button("撤回", enabled: !busy) { [weak self] in self?.openRecall(campers: false) }) }
            if (myCell?.camping ?? 0) > 0 { actions.append(button("叫扎營的走", enabled: !busy) { [weak self] in self?.openRecall(campers: true) }) }
        } else {
            let myGuests = w.guarding.first { $0.cell == c.cell }?.count ?? 0
            let fight = c.boss != nil || c.lair != nil || c.owner != nil
            if c.owner != nil && isFriend {
                actions.append(button("派兵幫守", prominent: true, enabled: canAct && (c.guests ?? 0) < names.rules.guestsMax) { [weak self] in self?.openDispatch("guard") })
            }
            if myGuests > 0 {
                actions.append(button("叫幫守的 \(myGuests) 隻回來", enabled: !busy) { [weak self] in
                    self?.act("幫守的居民回家了。") { try await self?.post("world/cells/\(c.cell)/unguard") }
                })
            }
            let last = fight && myGuests == 0 ? WorldLastAttack.load(c.cell) : nil
            if let last {
                actions.append(button("再派一次（\(last.party.count) 隻）", prominent: true, enabled: canAct) { [weak self] in self?.openDispatch("attack", again: last) })
            }
            if fight && myGuests == 0 {
                actions.append(button(c.boss != nil ? "攻擊魔王" : "攻擊", prominent: !(c.owner != nil && isFriend) && last == nil, enabled: canAct) { [weak self] in self?.openDispatch("attack") })
            } else if !fight {
                actions.append(button("派人佔領", prominent: true, enabled: canAct) { [weak self] in self?.openDispatch("settle") })
            }
            if let o = c.owner {
                if isFriend {
                    actions.append(button("傳訊息") { [weak self] in self?.onMessage?(o.id) })
                } else {
                    actions.append(button(askedFriend ? "等對方答應好友" : "加好友", enabled: !busy && !askedFriend) { [weak self] in self?.addFriend(o) })
                }
            }
        }
        if canMoveHere && asking != "move" {
            actions.append(button("搬營地到這裡", enabled: !busy && moveWait == nil) { [weak self] in self?.asking = "move"; self?.render() })
        }
        if !actions.isEmpty { rows.append(buttons(actions)) }
        if asking == "move" {
            rows.append(panel(nil, tint: .systemYellow, [
                text("把營地搬到「\(place)」？\(names.rules.homeMoveDays) 天只能搬一次。\(c.lair.map { "這裡的\($0.name)會被趕走。" } ?? "")原本那一格就不是你的了（住在那的會跟著回營地）。"),
                GuildUI.row([button("確定搬過來", prominent: true, enabled: !busy) { [weak self] in
                    guard let self else { return }
                    self.asking = nil
                    self.backHome = true
                    self.act("營地搬過來了！") { try await self.post("world/cells/\(c.cell)/home") }
                }, button("再想想") { [weak self] in self?.asking = nil; self?.render() }]),
            ]))
        }
        if canMoveHere, let wait = moveWait { rows.append(note("營地 \(names.rules.homeMoveDays) 天只能搬一次，\(wait)可以再搬。")) }
        if isMine && !isHome && c.nest == "none" {
            rows.append(note("佔領只是派人去住，那一格不會自己長人。蓋繁殖巢（\(WorldText.cost(w.rules.nestCost))，\(w.rules.nestHours) 小時蓋好）之後，這一格每 \(w.rules.nestBirthMinutes) 分鐘生一隻，不用一直從營地派人補。"))
        }
        if !message.isEmpty { rows.append(text(message, bold: true, color: .systemGreen)) }
        add(panel(nil, rows))
    }

    /// About how long the walk is from where it would set out (the slowest goblin and food make it differ a little; the
    /// dispatch sheet asks the server for the exact time).
    private func walkMinutes(_ way: WorldRoute) -> Int {
        let start = (launchFrom ?? "home") == "home" ? world?.homeCell : launchFrom
        let travel = world?.cells.first { $0.cell == start }?.travel ?? 1
        return max(1, Int((Double(names.walkMinutes(way.meters)) * travel).rounded()))
    }

    private func addFriend(_ o: WorldOwner) {
        struct Body: Encodable { let userId: String }
        struct Answer: Decodable { let status: String }
        busy = true
        Task { @MainActor in
            do {
                let out = try await api.request("POST", "friends/asks", body: Body(userId: o.id), as: Answer.self)
                message = out.status == "friends" ? "成為好友了！" : "送出好友邀請了，等\(o.name)答應。"
            } catch let e as APIError {
                message = e.message
            } catch {
                message = error.localizedDescription
            }
            busy = false
            loadFriends()
        }
    }
}

/// A rounded box round what it holds (a section of the right column, the card), tinted for warnings.
final class WorldPanel: NSView {
    private let tint: NSColor?

    init(_ content: NSView, tint: NSColor?) {
        self.tint = tint
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 10
        layer?.borderWidth = 1
        content.translatesAutoresizingMaskIntoConstraints = false
        addSubview(content)
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12), content.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            content.topAnchor.constraint(equalTo: topAnchor, constant: 10), content.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    override var wantsUpdateLayer: Bool { true }
    override func updateLayer() {
        // (the colours follow light and dark: resolved here, where the appearance is this view's)
        effectiveAppearance.performAsCurrentDrawingAppearance {
            layer?.backgroundColor = (tint?.withAlphaComponent(0.1) ?? .controlBackgroundColor).cgColor
            layer?.borderColor = (tint ?? .separatorColor).cgColor
        }
    }
}

/// A line of the right column that does something when clicked.
final class WorldClickRow: NSView {
    private let action: () -> Void
    private var hover = false { didSet { needsDisplay = true } }

    init(action: @escaping () -> Void) {
        self.action = action
        super.init(frame: .zero)
        addTrackingArea(NSTrackingArea(rect: .zero, options: [.mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect], owner: self))
    }

    required init?(coder: NSCoder) { fatalError() }

    override func resetCursorRects() { addCursorRect(bounds, cursor: .pointingHand) }
    override func mouseEntered(with event: NSEvent) { hover = true }
    override func mouseExited(with event: NSEvent) { hover = false }
    override func mouseUp(with event: NSEvent) { if bounds.contains(convert(event.locationInWindow, from: nil)) { action() } }
    /// (a checkbox or radio button inside it does the same)
    @objc func fire() { action() }
    override func mouseDown(with event: NSEvent) {}

    override func draw(_ dirtyRect: NSRect) {
        guard hover else { return }
        NSColor.selectedContentBackgroundColor.withAlphaComponent(0.12).setFill()
        NSBezierPath(roundedRect: bounds.insetBy(dx: -4, dy: 0), xRadius: 6, yRadius: 6).fill()
    }
}
