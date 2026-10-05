import AppKit
import CampRules

// Decorations the player puts down in the camp window (DESKTOP.md §5): each race's fifty (Resources/Decor, drawn by
// tools/make_decor.py), free, as many as the camp's decoration room holds; and three more each that are quests' rewards
// (`limited`: shown locked until the camp has earned them, shared/src/camp/quests.ts `decorEarned`). Where they stand is kept as an offset from
// the land's anchor (TerrainScene.nest), so resizing or moving the window never moves them. A signed-in camp keeps the list on
// the server (`decor-set`); a camp of its own in decor.json.

/// One kind of decoration (Resources/Decor/catalog.json, the same as shared/src/camp/decor-catalog.ts).
struct DecorKindInfo: Decodable {
    let id: String
    let race: String
    let name: String
    let category: String
    let size: Int
    let frames: Int
    let fn: String?
    let blocks: Bool
    /// "quest": a quest's reward, put down only once earned; nil: free.
    let limited: String?
}

/// One decoration put down: which, where (points from the land's anchor), turned round or not.
struct DecorPlaced: Codable, Equatable {
    var kind: String
    var x: Double
    var y: Double
    var flip: Bool?
}

enum DecorCatalog {
    static let categories: [(id: String, name: String)] = [
        ("fence", "柵欄"), ("building", "建築"), ("pen", "圍欄"), ("furniture", "家具"), ("scene", "場景"), ("tree", "樹"),
        ("sign", "路牌"), ("bone", "骨頭"), ("flower", "花"), ("plant", "魔植"), ("creature", "活物"),
    ]
    /// Decoration room by the camp's look (shared DECOR_ROOM), and the most things whatever the room.
    static let room = [1: 20, 2: 45, 3: 80]
    static let maxItems = 120
    /// Fence pieces take no room; this many at most. They sit on a grid of this many points, so rings close.
    static let maxFences = 80
    static let fenceCell = 20.0
    static func isFence(_ id: String) -> Bool { byID[id]?.category == "fence" }
    static let reach = 1200.0

    private static var folder: URL? { Bundle.main.resourceURL?.appendingPathComponent("Decor") }

    static let all: [DecorKindInfo] = {
        guard let url = folder?.appendingPathComponent("catalog.json"), let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([DecorKindInfo].self, from: data)) ?? []
    }()
    private static let byID = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })

    static func kind(_ id: String) -> DecorKindInfo? { byID[id] }
    static func of(race: String) -> [DecorKindInfo] { all.filter { $0.race == race } }

    private static var images: [String: [CGImage]] = [:]

    /// The frames of a kind (one, or two for the ones that move).
    static func frames(_ id: String) -> [CGImage] {
        if let cached = images[id] { return cached }
        guard let folder, let kind = byID[id] else { return [] }
        let frames: [CGImage] = (0..<kind.frames).compactMap { f in
            let url = folder.appendingPathComponent(id + (f == 0 ? "" : "-\(f)") + ".png")
            guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
            return CGImageSourceCreateImageAtIndex(source, 0, nil)
        }
        images[id] = frames
        return frames
    }

    /// Its size on screen in points (one art pixel is two points).
    static func size(_ id: String) -> CGSize {
        guard let image = frames(id).first else { return CGSize(width: 20, height: 20) }
        return CGSize(width: image.width * 2, height: image.height * 2)
    }
}

/// A cell of the fence grid (columns and rows from the land's anchor).
struct GridCell: Hashable {
    let x: Int
    let y: Int
}

/// The ground a big decoration stands on: goblins walk round it.
final class DecorObstacle: Obstacle {
    let rect: CGRect
    init(_ rect: CGRect) { self.rect = rect }
    func blocks(_ p: CGPoint, margin: CGFloat) -> Bool { rect.insetBy(dx: -margin, dy: -margin).contains(p) }
}

extension Colony {
    // MARK: Where they stand

    /// The land's anchor: decorations are kept as offsets from it.
    var decorAnchor: CGPoint { scene?.nest ?? nest ?? .zero }

    func decorPoint(_ d: DecorPlaced) -> CGPoint { CGPoint(x: decorAnchor.x + d.x, y: decorAnchor.y + d.y) }

    /// The box a decoration is drawn in (camp coordinates): it stands on the middle of its bottom edge.
    func decorBox(_ d: DecorPlaced) -> CGRect {
        let p = decorPoint(d), cell = DecorCatalog.fenceCell
        if DecorCatalog.isFence(d.kind) { return CGRect(x: p.x - cell / 2, y: p.y, width: cell, height: cell + 6) } // (a fence piece is its grid cell)
        let size = DecorCatalog.size(d.kind)
        return CGRect(x: p.x - size.width / 2, y: p.y, width: size.width, height: size.height)
    }

    /// The camp's look (1–3) for its decoration room: the books' when signed in, else worked out from its peak here.
    var decorStage: Int { booksStage ?? Races.campStage(Characters.current.id, peak: peakAnts) }
    var decorRoom: Int { DecorCatalog.room[decorStage] ?? 20 }
    var decorUsed: Int { decor.reduce(0) { $0 + (DecorCatalog.kind($1.kind)?.size ?? 0) } }

    /// Why a decoration of this kind cannot go here (nil: it can). `ignoring`: the one being moved.
    func decorProblem(_ kind: String, at p: CGPoint, ignoring: Int? = nil) -> String? {
        guard let info = DecorCatalog.kind(kind) else { return "沒有這種裝飾" }
        let others = decor.enumerated().filter { $0.offset != ignoring }.map(\.element)
        let used = others.reduce(0) { $0 + (DecorCatalog.kind($1.kind)?.size ?? 0) }
        let fences = others.filter { DecorCatalog.isFence($0.kind) }
        if info.category == "fence" {
            if ignoring == nil, fences.count >= DecorCatalog.maxFences { return "柵欄最多 \(DecorCatalog.maxFences) 段" }
            if fences.contains(where: { hypot(decorPoint($0).x - p.x, decorPoint($0).y - p.y) < 2 }) { return "這裡已經有柵欄了" }
        }
        if ignoring == nil, used + info.size > decorRoom { return "裝飾點數不夠" }
        if ignoring == nil, others.count - fences.count >= DecorCatalog.maxItems { return "放太多了" }
        guard walkable.contains(where: { $0.contains(p) }) else { return "這裡放不下" }
        if scene?.visiblePonds.contains(where: { $0.blocks(p, margin: 4) }) == true { return "不能放在水裡" }
        if obstacles.contains(where: { $0.blocks(p, margin: 2) }) { return "這裡有水或石頭，放不了" } // (streams, ledges, rocks and trees: where nobody walks)
        if let nest, hypot(p.x - nest.x, p.y - nest.y) < 36 { return "離營地洞口太近" }
        if info.blocks { // a big one needs its own ground
            let foot = footprint(kind, at: p)
            if others.contains(where: { DecorCatalog.kind($0.kind)?.blocks == true && footprint($0.kind, at: decorPoint($0)).intersects(foot) }) { return "跟別的裝飾疊在一起" }
        }
        return nil
    }

    private func footprint(_ kind: String, at p: CGPoint) -> CGRect {
        if DecorCatalog.isFence(kind) { let c = DecorCatalog.fenceCell; return CGRect(x: p.x - c / 2, y: p.y, width: c, height: c) } // (the whole cell: nobody squeezes between two posts)
        let size = DecorCatalog.size(kind)
        return CGRect(x: p.x - size.width * 0.4, y: p.y, width: size.width * 0.8, height: min(16, size.height * 0.35))
    }

    /// What the goblins walk round (the big ones' ground).
    func rebuildDecorObstacles() {
        decorObstacles = decor.compactMap { d in
            guard DecorCatalog.kind(d.kind)?.blocks == true else { return nil }
            return DecorObstacle(footprint(d.kind, at: decorPoint(d)))
        }
    }

    /// The decoration under a point (the one drawn on top), or nil.
    func decorAt(_ p: CGPoint) -> Int? {
        decor.indices.reversed().first { decorBox(decor[$0]).insetBy(dx: 2, dy: 0).contains(p) }
    }

    // MARK: Drawing order, and the ones that wander

    private static let flatCategories: Set<String> = ["scene", "flower"]
    /// Kinds that move about near where they were put: how far they go and how fast (points, points a second).
    static let roamers: [String: (reach: Double, speed: Double)] = [
        "e_treant": (34, 5), "u_ghost": (46, 10), "u_bats": (40, 26), "u_crows": (26, 14), "u_crawlinghand": (30, 8), "e_butterflies": (0, 0),
    ]

    /// What lies on the ground (drawn under everybody), by index.
    func decorFlat() -> [Int] {
        decor.indices.filter { Colony.flatCategories.contains(DecorCatalog.kind(decor[$0].kind)?.category ?? "") || decor[$0].kind.hasSuffix("path") }
    }

    /// What stands up (drawn among the residents), far to near.
    func decorStanding() -> [Int] {
        let flat = Set(decorFlat())
        return decor.indices.filter { !flat.contains($0) }.sorted { decorPoint(decor[$0]).y > decorPoint(decor[$1]).y }
    }

    /// Once a frame: the wandering ones drift toward a spot near home, then pick another.
    func updateDecorRoam(dt: Double) {
        guard !decorating else { return }
        for (k, d) in decor.enumerated() {
            guard let rule = Colony.roamers[d.kind], rule.reach > 0 else { continue }
            var state = decorRoam[k] ?? (at: .zero, to: .zero, left: false, wait: 0)
            if state.wait > 0 {
                state.wait -= dt
            } else {
                let dx = state.to.x - state.at.x, dy = state.to.y - state.at.y, dist = hypot(dx, dy)
                if dist < 1.5 { // there: a rest, then somewhere else (only where a goblin could walk)
                    state.wait = Double.random(in: 1...5)
                    for _ in 0..<6 {
                        let to = CGPoint(x: Double.random(in: -rule.reach...rule.reach), y: Double.random(in: -rule.reach * 0.6...rule.reach * 0.6))
                        let world = CGPoint(x: decorPoint(d).x + to.x, y: decorPoint(d).y + to.y)
                        if walkable.contains(where: { $0.contains(world) }) { state.to = to; break }
                    }
                } else {
                    let step = min(dist, rule.speed * dt)
                    state.at.x += dx / dist * step
                    state.at.y += dy / dist * step
                    state.left = dx < 0
                }
            }
            decorRoam[k] = state
        }
    }

    /// Where a decoration is now (its spot, plus how far it has wandered).
    func decorNow(_ k: Int) -> CGPoint {
        let p = decorPoint(decor[k]), roam = decorRoam[k]?.at ?? .zero
        return CGPoint(x: p.x + roam.x, y: p.y + roam.y)
    }

    // MARK: Fences

    /// The middle of the bottom edge of the grid cell a point is in (cells are counted from the land's anchor).
    func fenceSnap(_ p: CGPoint) -> CGPoint {
        let c = DecorCatalog.fenceCell, a = decorAnchor
        return CGPoint(x: a.x + ((p.x - a.x) / c).rounded() * c, y: a.y + ((p.y - a.y) / c).rounded(.down) * c)
    }

    /// The grid cell (column, row from the anchor) of a fence piece.
    func fenceCell(_ d: DecorPlaced) -> GridCell { GridCell(x: Int((d.x / DecorCatalog.fenceCell).rounded()), y: Int((d.y / DecorCatalog.fenceCell).rounded())) }

    /// The rectangle of a grid cell, in camp coordinates.
    func cellRect(_ cell: GridCell) -> CGRect {
        let c = DecorCatalog.fenceCell, a = decorAnchor
        return CGRect(x: a.x + (Double(cell.x) - 0.5) * c, y: a.y + Double(cell.y) * c, width: c, height: c)
    }

    // MARK: Changing them

    @discardableResult
    func placeDecor(_ kind: String, at point: CGPoint) -> String? {
        let p = DecorCatalog.isFence(kind) ? fenceSnap(point) : point
        if let problem = decorProblem(kind, at: p) { return problem }
        decor.append(DecorPlaced(kind: kind, x: (p.x - decorAnchor.x).rounded(), y: (p.y - decorAnchor.y).rounded(), flip: nil))
        decorChanged()
        return nil
    }

    func moveDecor(_ i: Int, to p: CGPoint) -> Bool {
        guard decor.indices.contains(i), decorProblem(decor[i].kind, at: p, ignoring: i) == nil else { return false }
        decor[i].x = (p.x - decorAnchor.x).rounded()
        decor[i].y = (p.y - decorAnchor.y).rounded()
        return true
    }

    func flipDecor(_ i: Int) { // (a fence piece turned is a gate)
        guard decor.indices.contains(i) else { return }
        decor[i].flip = decor[i].flip == true ? nil : true
        decorChanged()
    }

    func removeDecor(_ i: Int) {
        guard decor.indices.contains(i) else { return }
        decor.remove(at: i)
        if decorSelected == i { decorSelected = nil } else if let s = decorSelected, s > i { decorSelected = s - 1 }
        decorChanged()
    }

    /// After any change: the goblins' paths, and the list kept (books or file).
    func decorChanged() {
        decorRoam = [:] // (the list moved: everyone back to its spot)
        ranch.pensDirty = true
        rebuildDecorObstacles()
        if followsBooks { onDecorChanged?(decor) } else { Self.saveLocalDecor(decor) }
    }

    /// The books' list arrived (another Mac changed it, or after signing in). A camp's own list moves to the books once.
    func applyBooksDecor(_ list: [DecorPlaced]?) {
        guard var list, decorSelected == nil, decorPlacing == nil else { return }
        list.removeAll { DecorCatalog.kind($0.kind) == nil } // (a kind this version no longer has)
        guard list != decor else { return }
        if list.isEmpty, !decor.isEmpty, !decorSentOnce { // signed in with decorations made here: they go up to the account
            decorSentOnce = true
            onDecorChanged?(decor)
            return
        }
        decor = list
        ranch.pensDirty = true
        decorRoam = [:]
        rebuildDecorObstacles()
    }

    // MARK: A camp of its own: decor.json

    private static var localURL: URL { Persistence.url("decor.json") }

    static func loadLocalDecor() -> [DecorPlaced] {
        guard ProcessInfo.processInfo.environment["CAMP_NO_SAVE"] == nil, let data = try? Data(contentsOf: localURL) else { return [] }
        return ((try? JSONDecoder().decode([DecorPlaced].self, from: data)) ?? []).filter { DecorCatalog.kind($0.kind) != nil }
    }

    static func saveLocalDecor(_ list: [DecorPlaced]) {
        guard ProcessInfo.processInfo.environment["CAMP_NO_SAVE"] == nil, let data = try? JSONEncoder().encode(list) else { return }
        try? FileManager.default.createDirectory(at: localURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: localURL, options: .atomic)
    }

    // MARK: What some of them do (only while the camp is on this Mac)

    /// How many of the decorations put down do this.
    func decorCount(_ fn: String) -> Int { decor.filter { DecorCatalog.kind($0.kind)?.fn == fn }.count }
    func decorHas(_ fn: String) -> Bool { decor.contains { DecorCatalog.kind($0.kind)?.fn == fn } }

    /// Once a frame: the biting plants bite monsters that come near; the crypt is another way in and out.
    func updateDecorEffects(dt: Double) {
        if let prefix = DecorTest.prefix { runDecorTest(prefix) }
        decorTimer -= dt
        guard decorTimer <= 0 else { return }
        decorTimer = 2
        var seen = Set<String>() // (two of a kind do no more than one)
        for (k, d) in decor.enumerated() {
            guard let fn = DecorCatalog.kind(d.kind)?.fn else { continue }
            let p = decorNow(k)
            func monster(within reach: CGFloat) -> Creature? { creatures.first { $0.kind.hostile && hypot($0.pos.x - p.x, $0.pos.y - p.y) < reach } }
            switch fn {
            case "bite": // the biting plants
                if let m = monster(within: 40) { _ = handStrike(creature: m.id); addFloater("咬！", .common, at: p) }
            case "guard": // a treant swings at what comes near (twice a goblin's hand)
                if let m = monster(within: 60) { _ = handStrike(creature: m.id); _ = handStrike(creature: m.id); addFloater("樹人揮了一拳", .common, at: p) }
            case "wolfdog", "bonedog":
                if let m = monster(within: 70) { _ = handStrike(creature: m.id); addFloater(fn == "bonedog" ? "喀！" : "汪！", .common, at: p) }
            case "slow": // a bog: what wades in is held a moment
                if let m = monster(within: 34) { decorHold(creature: m.id, seconds: 1.4) }
            case "lullaby": // the young near a singing flower grow a little faster
                for i in ants.indices where ants[i].isChild && !ants[i].isHidden && hypot(ants[i].pos.x - p.x, ants[i].pos.y - p.y) < 80 { ants[i].age += 0.4 }
            case "watch", "forecast", "bell", "drum":
                guard seen.insert("alarm").inserted else { break }
                let drums = decorHas("drum"), bell = decorHas("bell")
                if decorAlarm(extra: drums ? 4 : 0, retreat: bell) {
                    addFloater(bell ? "噹！噹！魔獸來了！" : fn == "forecast" ? "星象台早就算到了：魔獸來了！" : drums && fn == "drum" ? "咚咚咚！集合！" : "瞭望台發現魔獸！", .uncommon, at: p, important: true)
                }
            default: break
            }
        }
    }

    /// How fast gear wears: a whetstone and a smithy each take a tenth off.
    var decorWear: Double { (decorHas("whet") ? 0.9 : 1) * (decorHas("smithy") ? 0.9 : 1) }

    /// Attack bonus from the totem, the archery target and (at night, the undead) the soul fire: +5% each kind.
    var decorMight: Double {
        var bonus = 0.0
        if decorHas("totem") { bonus += 0.05 }
        if decorHas("archery") { bonus += 0.05 }
        if decorHas("nightmight"), Colony.isNight { bonus += 0.05 }
        return 1 + bonus
    }

    /// The crypts' doors, as more ways into the nest.
    var decorDoors: [CGPoint] { decor.filter { DecorCatalog.kind($0.kind)?.fn == "door" }.map(decorPoint) }
}

// MARK: - The catalogue window (decoration mode)

/// The decorations of the camp's race by category, a click picks one to put down; the room left; how it works.
final class DecorPalette: NSObject, NSWindowDelegate {
    static let shared = DecorPalette()
    private var panel: NSPanel?
    private weak var colony: Colony?
    private var category = "building"
    private var status = ""

    var isOpen: Bool { panel?.isVisible == true }

    func toggle(colony: Colony, near window: NSWindow?) {
        if isOpen { close(); return }
        self.colony = colony
        colony.decorating = true
        colony.decorPlacing = nil
        colony.decorSelected = nil
        if panel == nil {
            let p = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 330, height: 460), styleMask: [.titled, .closable, .utilityWindow], backing: .buffered, defer: false)
            p.title = "裝飾營地"
            p.isReleasedWhenClosed = false
            p.level = Levels.dialog
            p.becomesKeyOnlyIfNeeded = true
            p.delegate = self
            panel = p
        }
        rebuild()
        if let frame = window?.frame, let panel {
            panel.setFrameTopLeftPoint(NSPoint(x: frame.maxX + 8, y: frame.maxY))
            if let screen = window?.screen, !screen.visibleFrame.contains(panel.frame) { panel.setFrameTopLeftPoint(NSPoint(x: frame.minX - panel.frame.width - 8, y: frame.maxY)) }
        }
        panel?.orderFront(nil)
    }

    func close() {
        panel?.orderOut(nil)
        finish()
    }

    func windowWillClose(_ notification: Notification) { finish() }

    private func finish() {
        guard let colony else { return }
        colony.decorating = false
        colony.decorPlacing = nil
        colony.decorSelected = nil
    }

    /// Something changed in the camp (placed, removed): the room line.
    func refresh(_ message: String? = nil) {
        if let message { status = message }
        if isOpen { rebuild() }
    }

    private func rebuild() {
        guard let panel, let colony else { return }
        let kinds = DecorCatalog.of(race: Characters.current.id)
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.edgeInsets = NSEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)

        let fences = colony.decor.filter { DecorCatalog.isFence($0.kind) }.count
        let room = NSTextField(labelWithString: "裝飾點數 \(colony.decorUsed)／\(colony.decorRoom)　柵欄 \(fences)／\(DecorCatalog.maxFences)")
        room.font = .systemFont(ofSize: 12, weight: .semibold)
        stack.addArrangedSubview(room)

        let pop = NSPopUpButton(frame: .zero, pullsDown: false)
        for (id, name) in DecorCatalog.categories {
            let n = kinds.filter { $0.category == id }.count
            guard n > 0 else { continue }
            pop.addItem(withTitle: "\(name)（\(n)）")
            pop.lastItem?.representedObject = id
            if id == category { pop.select(pop.lastItem) }
        }
        pop.target = self
        pop.action = #selector(pickCategory(_:))
        stack.addArrangedSubview(pop)

        let grid = NSStackView()
        grid.orientation = .vertical
        grid.alignment = .leading
        grid.spacing = 6
        var row: NSStackView?
        for (k, kind) in kinds.filter({ $0.category == category }).enumerated() {
            if k % 3 == 0 {
                row = NSStackView()
                row!.orientation = .horizontal
                row!.spacing = 6
                grid.addArrangedSubview(row!)
            }
            let locked = kind.limited != nil && !colony.decorEarned.contains(kind.id)
            let button = NSButton(title: (kind.limited != nil ? "🎁" : "") + kind.name + (kind.fn != nil ? " ★" : ""), target: self, action: #selector(pick(_:)))
            button.identifier = NSUserInterfaceItemIdentifier(kind.id)
            button.imagePosition = .imageAbove
            button.bezelStyle = .regularSquare
            button.setButtonType(.pushOnPushOff)
            button.state = colony.decorPlacing == kind.id ? .on : .off
            button.font = .systemFont(ofSize: 10)
            button.toolTip = "\(kind.name)・占 \(kind.size) 點" + (kind.fn != nil ? "・★ 有作用" : "")
                + (locked ? "\n🎁 任務獎勵：在主視窗的「任務」完成任務才能放" + (colony.followsBooks ? "" : "（要先登入）") : kind.limited != nil ? "\n🎁 任務拿到的" : "")
            button.isEnabled = !locked
            if let image = DecorCatalog.frames(kind.id).first {
                let scale = min(2.0, 52.0 / Double(max(image.width, image.height)))
                let ns = NSImage(cgImage: image, size: NSSize(width: Double(image.width) * scale, height: Double(image.height) * scale))
                button.image = ns
            }
            button.translatesAutoresizingMaskIntoConstraints = false
            button.widthAnchor.constraint(equalToConstant: 96).isActive = true
            button.heightAnchor.constraint(equalToConstant: 84).isActive = true
            row?.addArrangedSubview(button)
        }
        let scroll = NSScrollView()
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        let holder = FlippedView()
        holder.addSubview(grid)
        grid.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([grid.topAnchor.constraint(equalTo: holder.topAnchor), grid.leadingAnchor.constraint(equalTo: holder.leadingAnchor)])
        holder.frame = NSRect(origin: .zero, size: grid.fittingSize)
        scroll.documentView = holder
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.widthAnchor.constraint(equalToConstant: 306).isActive = true
        scroll.heightAnchor.constraint(equalToConstant: 300).isActive = true
        stack.addArrangedSubview(scroll)

        let help = NSTextField(wrappingLabelWithString: colony.decorPlacing.map(DecorCatalog.isFence) == true
            ? "在營地裡按住拖一條線，就鋪一排柵欄。圍成一圈就是牧場：把走進營地的雞、羊、豬拎起來丟進去養。右鍵拆掉一段。Esc 不鋪了。"
            : colony.decorPlacing != nil
            ? "在營地裡點一下放下，可以一直點、連續放。Esc（或再按一次同一個按鈕）不放了。"
            : "點上面一樣，再點營地放下。點營地裡的裝飾可以拖著移動，F 翻面，Delete 收回。Esc 或關掉這個視窗結束。")
        help.preferredMaxLayoutWidth = 300
        help.font = .systemFont(ofSize: 11)
        help.textColor = .secondaryLabelColor
        stack.addArrangedSubview(help)
        if !status.isEmpty {
            let line = NSTextField(wrappingLabelWithString: status)
            line.font = .systemFont(ofSize: 11)
            line.textColor = .systemOrange
            stack.addArrangedSubview(line)
        }
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.widthAnchor.constraint(equalToConstant: 330).isActive = true
        panel.contentView = stack
        panel.setContentSize(NSSize(width: 330, height: stack.fittingSize.height))
    }

    @objc private func pickCategory(_ sender: NSPopUpButton) {
        category = sender.selectedItem?.representedObject as? String ?? category
        rebuild()
    }

    @objc private func pick(_ sender: NSButton) {
        guard let colony, let id = sender.identifier?.rawValue else { return }
        colony.decorPlacing = colony.decorPlacing == id ? nil : id
        colony.decorSelected = nil
        status = ""
        rebuild()
    }
}

/// A view whose y runs down, so the grid of decorations starts at the top of its scroll view.
private final class FlippedView: NSView {
    override var isFlipped: Bool { true }
}

// MARK: - Test (`CAMP_TEST_DECOR=/path/prefix`)

/// At 25 s puts a dozen of the race's decorations round the camp, opens the catalogue with one under the pointer, and draws
/// the camp (`-camp.png`) and the catalogue (`-palette.png`); then turns one round, moves one, takes one away, and quits.
enum DecorTest {
    static let prefix = ProcessInfo.processInfo.environment["CAMP_TEST_DECOR"]
    static var step = 0
    static let started = Date()
}

extension Colony {
    fileprivate func runDecorTest(_ prefix: String) {
        let t = Date().timeIntervalSince(DecorTest.started)
        func shoot(_ window: NSWindow?, _ path: String) {
            guard let view = window?.contentView, let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
            view.cacheDisplay(in: view.bounds, to: rep)
            try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
        }
        let camp = NSApp.windows.first { ($0.contentView as? AntView)?.isMap == true }
        switch DecorTest.step {
        case 0 where t > 25:
            DecorTest.step = 1
            guard let nest else { return }
            let kinds = DecorCatalog.of(race: Characters.current.id)
            var placed = 0, refused: [String] = []
            for (k, kind) in kinds.enumerated() where k % 4 == 0 {
                let a = Double(k) * 0.9, r = 90.0 + Double(k % 3) * 45
                if let why = placeDecor(kind.id, at: CGPoint(x: nest.x + CGFloat(cos(a) * r * 1.4), y: nest.y + CGFloat(sin(a) * r * 0.8))) { refused.append("\(kind.name):\(why)") } else { placed += 1 }
            }
            print("decor test: \(Characters.current.id) placed \(placed), used \(decorUsed)/\(decorRoom), obstacles \(decorObstacles.count), refused \(refused.prefix(6))")
            fflush(stdout)
            DecorPalette.shared.toggle(colony: self, near: camp)
            decorPlacing = kinds.first { $0.size == 2 }?.id
            hand.cursor = CGPoint(x: nest.x - 40, y: nest.y + 60)
            decorSelected = 0
        case 1 where t > 27:
            DecorTest.step = 2
            shoot(camp, prefix + "-camp.png")
            shoot(NSApp.windows.first { $0 is NSPanel && $0.isVisible }, prefix + "-palette.png")
            let before = decor.count
            flipDecor(0)
            let moved = moveDecor(1, to: CGPoint(x: decorPoint(decor[1]).x + 20, y: decorPoint(decor[1]).y))
            removeDecor(decor.count - 1)
            let stuck = ants.filter { a in !a.isHidden && decorObstacles.contains { $0.blocks(a.pos, margin: 0) } }.count
            print("decor test: flipped \(decor[0].flip == true), moved \(moved), \(before) -> \(decor.count), goblins standing inside a building: \(stuck)")
            fflush(stdout)
        case 2 where t > 45:
            DecorTest.step = 3
            let stuck = ants.filter { a in !a.isHidden && decorObstacles.contains { $0.blocks(a.pos, margin: 0) } }.count
            print("decor test: after 18 s, goblins inside a building: \(stuck) of \(ants.filter { !$0.isHidden }.count)")
            shoot(camp, prefix + "-later.png")
            fflush(stdout)
            NSApp.terminate(nil)
        default: break
        }
    }
}
