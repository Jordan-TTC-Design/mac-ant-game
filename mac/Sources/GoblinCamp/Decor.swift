import AppKit
import CampRules

// Decorations the player puts down in the camp window (DESKTOP.md §5): each race's fifty (Resources/Decor, drawn by
// tools/make_decor.py), free for now, as many as the camp's decoration room holds. Where they stand is kept as an offset from
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
        ("building", "建築"), ("pen", "圍欄"), ("furniture", "家具"), ("scene", "場景"), ("tree", "樹"),
        ("sign", "路牌"), ("bone", "骨頭"), ("flower", "花"), ("plant", "魔植"), ("creature", "活物"),
    ]
    /// Decoration room by the camp's look (shared DECOR_ROOM), and the most things whatever the room.
    static let room = [1: 20, 2: 45, 3: 80]
    static let maxItems = 120
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
        let p = decorPoint(d), size = DecorCatalog.size(d.kind)
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
        if ignoring == nil, used + info.size > decorRoom { return "裝飾點數不夠" }
        if ignoring == nil, others.count >= DecorCatalog.maxItems { return "放太多了" }
        guard walkable.contains(where: { $0.contains(p) }) else { return "這裡放不下" }
        if scene?.visiblePonds.contains(where: { $0.blocks(p, margin: 4) }) == true { return "不能放在水裡" }
        if let nest, hypot(p.x - nest.x, p.y - nest.y) < 36 { return "離營地洞口太近" }
        if info.blocks { // a big one needs its own ground
            let foot = footprint(kind, at: p)
            if others.contains(where: { DecorCatalog.kind($0.kind)?.blocks == true && footprint($0.kind, at: decorPoint($0)).intersects(foot) }) { return "跟別的裝飾疊在一起" }
        }
        return nil
    }

    private func footprint(_ kind: String, at p: CGPoint) -> CGRect {
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

    // MARK: Changing them

    @discardableResult
    func placeDecor(_ kind: String, at p: CGPoint) -> String? {
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

    func flipDecor(_ i: Int) {
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
        rebuildDecorObstacles()
        if followsBooks { onDecorChanged?(decor) } else { Self.saveLocalDecor(decor) }
    }

    /// The books' list arrived (another Mac changed it, or after signing in). A camp's own list moves to the books once.
    func applyBooksDecor(_ list: [DecorPlaced]?) {
        guard let list, list != decor, decorSelected == nil, decorPlacing == nil else { return }
        if list.isEmpty, !decor.isEmpty, !decorSentOnce { // signed in with decorations made here: they go up to the account
            decorSentOnce = true
            onDecorChanged?(decor)
            return
        }
        decor = list
        rebuildDecorObstacles()
    }

    // MARK: A camp of its own: decor.json

    private static var localURL: URL { Persistence.url("decor.json") }

    static func loadLocalDecor() -> [DecorPlaced] {
        guard ProcessInfo.processInfo.environment["CAMP_NO_SAVE"] == nil, let data = try? Data(contentsOf: localURL) else { return [] }
        return (try? JSONDecoder().decode([DecorPlaced].self, from: data)) ?? []
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
        for d in decor where DecorCatalog.kind(d.kind)?.fn == "bite" {
            let p = decorPoint(d)
            if let monster = creatures.first(where: { $0.kind.hostile && hypot($0.pos.x - p.x, $0.pos.y - p.y) < 40 }) {
                _ = handStrike(creature: monster.id)
                addFloater("咬！", .common, at: p)
            }
        }
    }

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

        let room = NSTextField(labelWithString: "裝飾點數 \(colony.decorUsed)／\(colony.decorRoom)　（營地長大會變多）")
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
            let button = NSButton(title: kind.name + (kind.fn != nil ? " ★" : ""), target: self, action: #selector(pick(_:)))
            button.identifier = NSUserInterfaceItemIdentifier(kind.id)
            button.imagePosition = .imageAbove
            button.bezelStyle = .regularSquare
            button.setButtonType(.pushOnPushOff)
            button.state = colony.decorPlacing == kind.id ? .on : .off
            button.font = .systemFont(ofSize: 10)
            button.toolTip = "\(kind.name)・占 \(kind.size) 點" + (kind.fn != nil ? "・★ 有作用" : "")
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

        let help = NSTextField(wrappingLabelWithString: colony.decorPlacing != nil
            ? "在營地裡點一下放下（按住 ⇧ 可以連續放）。Esc 不放了。"
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
