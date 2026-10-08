import AppKit
import GuildRules

/// What a card in a catalog shows: a picture, a name and a line under it (a decoration, a floor, a wall).
final class CatalogCell: NSView {
    static let size = NSSize(width: 80, height: 98)

    private let image: CGImage?
    /// How many points one pixel of the picture takes.
    private let scale: CGFloat
    private let picture: NSSize
    private let name: String
    private let sub: String
    private let on: Bool
    private let shut: Bool
    private let action: () -> Void

    init(image: CGImage?, pixels: NSSize, fit: CGFloat = 56, maxScale: CGFloat = 2, name: String, sub: String, on: Bool = false, shut: Bool = false, action: @escaping () -> Void) {
        self.image = image
        self.picture = pixels
        self.scale = min(maxScale, fit / max(pixels.width, pixels.height, 1))
        self.name = name
        self.sub = sub
        self.on = on
        self.shut = shut
        self.action = action
        super.init(frame: NSRect(origin: .zero, size: CatalogCell.size))
        toolTip = sub.isEmpty ? name : "\(name)（\(sub)）"
    }

    required init?(coder: NSCoder) { fatalError() }

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        let box = NSBezierPath(roundedRect: bounds.insetBy(dx: 1, dy: 1), xRadius: 8, yRadius: 8)
        (on ? NSColor(calibratedRed: 0.91, green: 0.77, blue: 0.28, alpha: 0.9) : NSColor(white: 1, alpha: 0.1)).setFill()
        box.fill()
        NSColor(white: 1, alpha: on ? 0.9 : 0.25).setStroke()
        box.lineWidth = on ? 2 : 1
        box.stroke()
        if let image, let g = NSGraphicsContext.current?.cgContext {
            let w = picture.width * scale, h = picture.height * scale
            g.saveGState()
            g.interpolationQuality = .none
            g.setAlpha(shut ? 0.4 : 1)
            g.translateBy(x: (bounds.width - w) / 2, y: 4 + (56 - h) / 2 + h)
            g.scaleBy(x: 1, y: -1)
            g.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
            g.restoreGState()
        }
        let para = NSMutableParagraphStyle()
        para.alignment = .center
        para.lineBreakMode = .byTruncatingTail
        let ink = on ? NSColor(calibratedRed: 0.17, green: 0.11, blue: 0, alpha: 1) : NSColor.white
        (name as NSString).draw(in: NSRect(x: 3, y: 62, width: bounds.width - 6, height: 16),
                                withAttributes: [.font: NSFont.systemFont(ofSize: 11), .foregroundColor: ink.withAlphaComponent(shut ? 0.5 : 1), .paragraphStyle: para])
        (sub as NSString).draw(in: NSRect(x: 3, y: 79, width: bounds.width - 6, height: 14),
                               withAttributes: [.font: NSFont.systemFont(ofSize: 10), .foregroundColor: ink.withAlphaComponent(0.65), .paragraphStyle: para])
    }

    override func mouseDown(with event: NSEvent) {
        if !shut { action() }
    }
}

/// The floors and walls the hall can have (shared/src/guild-decor.ts HALL_FLOORS, HALL_WALLS): a race's ones need a member of it.
enum GuildStyles {
    struct Style { let id: String; let name: String; let race: String? }
    static let floors: [Style] = [
        Style(id: "oak", name: "橡木地板", race: nil), Style(id: "stone", name: "石磚", race: nil), Style(id: "carpet", name: "紅地毯", race: nil),
        Style(id: "marble", name: "棋盤格大理石", race: nil), Style(id: "plain_wood", name: "素木地板", race: nil), Style(id: "plain_stone", name: "素石地", race: nil),
        Style(id: "plain_plaster", name: "灰泥地", race: nil), Style(id: "goblin_mud", name: "夯土地", race: "goblin"), Style(id: "goblin_flagstone", name: "粗石板", race: "goblin"),
        Style(id: "elf_moss", name: "苔蘚地", race: "elf"), Style(id: "elf_roots", name: "樹根木紋", race: "elf"), Style(id: "undead_blackstone", name: "黑石磚", race: "undead"),
        Style(id: "undead_bone", name: "骨片馬賽克", race: "undead"),
    ]
    static let walls: [Style] = [
        Style(id: "stone", name: "灰石牆", race: nil), Style(id: "wood", name: "木板牆", race: nil), Style(id: "plain_plaster", name: "白灰泥牆", race: nil),
        Style(id: "plain_wood", name: "素木牆", race: nil), Style(id: "plain_stone", name: "素石牆", race: nil), Style(id: "goblin_hide", name: "獸皮帳幕牆", race: "goblin"),
        Style(id: "elf_vines", name: "活藤樹牆", race: "elf"), Style(id: "undead_gothic", name: "哥德拱窗黑石牆", race: "undead"),
    ]
    static let races = ["goblin": "哥布林", "elf": "精靈", "undead": "死靈"]
    /// The categories, in the order the catalog's tabs show them (shared/src/guild-decor.ts GUILD_DECOR_CATEGORIES).
    /// The tab of the holiday pieces (in front of the categories, when there are any).
    static let holiday = "節日限定"
    static let categories = ["辦公桌椅", "櫃子收納", "桌上小物", "燈具", "牆上掛飾", "地毯", "植物", "雕像與紀念物", "休閒娛樂", "廚房飲料", "門窗與隔間", "戶外", "會動的"]
}

/// Decorating the hall on the page itself (GUILD.md §4.2–4.3), no window of its own: the pieces are picked and dragged in the
/// hall, a panel on the right holds the catalog, the floor and the wall. A copy of the list is changed and saved in one go.
final class GuildDecorEditor: NSObject {
    let view = NSVisualEffectView()
    /// Done (saved: the guild as the server now has it) or given up / out of date (nil).
    var onFinish: ((GuildInfo?, String?) -> Void)?
    /// The wall was changed (that goes at once).
    var onGuild: ((GuildInfo) -> Void)?

    private let hall: GuildHallView
    private let api: APIClient
    private let guild: GuildInfo.Guild
    private let role: String
    private let races: Set<String>
    private let art = GuildArt.shared

    private var draft: [GuildInfo.Decor]
    private var floor: GuildInfo.Floor
    private let version: Int
    private var wall: String
    private enum Mode: Int { case decor, floor, wall }
    private var mode = Mode.decor
    private var brush: String
    private var category = GuildStyles.categories[0]
    private var busy = false

    private let room = NSTextField(labelWithString: "")
    private let modes = NSSegmentedControl(labels: ["🪑 裝飾", "🟫 地板", "🧱 牆壁"], trackingMode: .selectOne, target: nil, action: nil)
    private let hint = NSTextField(wrappingLabelWithString: "")
    private let picked = NSStackView()
    private let pickedName = NSTextField(labelWithString: "")
    private var flipButton: ClosureButton!
    private var removeButton: ClosureButton!
    private var lockButton: ClosureButton!
    private let categories = NSPopUpButton()
    private let fill = NSButton(title: "整片換成這種", target: nil, action: nil)
    private let scroll = NSScrollView()
    private let grid = TopDownView()
    private let status = NSTextField(wrappingLabelWithString: "")
    private var save: NSButton!
    private var cancel: NSButton!

    init(hall: GuildHallView, api: APIClient, guild: GuildInfo.Guild, role: String) {
        self.hall = hall
        self.api = api
        self.guild = guild
        self.role = role
        self.races = Set(guild.races)
        self.draft = guild.decor
        self.floor = guild.floor
        self.version = guild.decorVersion
        self.wall = guild.wall
        self.brush = guild.floor.base
        super.init()
        build()
        hall.editing = true
        hall.decor = draft
        hall.floorBase = floor.base
        hall.floorTiles = floor.tiles
        hall.onSelect = { [weak self] _ in self?.refresh() }
        hall.onMove = { [weak self] uid, x, y in self?.move(uid, x, y) }
        hall.onPaint = { [weak self] x, y in self?.paintTile(x, y) }
        hall.onRemove = { [weak self] uid in self?.remove(uid) }
        hall.onEscape = { [weak self] in
            self?.hall.selected = nil
            self?.refresh()
        }
        refresh()
    }

    /// Picks a tab of the catalog (a test).
    func debugSelect(_ title: String) {
        categories.selectItem(withTitle: title)
        categoryChanged()
    }

    /// Takes the hall back from the editor.
    func release() {
        hall.editing = false
        hall.onSelect = nil
        hall.onMove = nil
        hall.onPaint = nil
        hall.onRemove = nil
        hall.onEscape = nil
    }

    private var boss: Bool { role != "member" }

    // MARK: The panel

    private func build() {
        view.material = .hudWindow
        view.blendingMode = .withinWindow
        view.state = .active
        view.wantsLayer = true
        view.layer?.cornerRadius = 12
        view.layer?.backgroundColor = NSColor(white: 0.06, alpha: 0.6).cgColor

        let title = NSTextField(labelWithString: "擺裝飾")
        title.font = .boldSystemFont(ofSize: 15)
        room.font = .systemFont(ofSize: 12, weight: .semibold)
        let head = NSStackView(views: [title, NSView(), room])
        head.distribution = .fill

        modes.target = self
        modes.action = #selector(modeChanged)
        modes.selectedSegment = 0
        modes.segmentCount = boss ? 3 : 2

        hint.font = .systemFont(ofSize: 11)
        hint.textColor = .secondaryLabelColor

        pickedName.font = .boldSystemFont(ofSize: 12)
        flipButton = ClosureButton(title: "↔︎ 翻面") { [weak self] in self?.flip() }
        removeButton = ClosureButton(title: "收掉") { [weak self] in if let uid = self?.hall.selected { self?.remove(uid) } }
        lockButton = ClosureButton(title: "🔒 鎖定") { [weak self] in self?.lock() }
        for b in [flipButton!, removeButton!, lockButton!] {
            b.bezelStyle = .rounded
            b.controlSize = .small
        }
        lockButton.isHidden = !boss
        picked.setViews([pickedName, flipButton, removeButton, lockButton], in: .leading)
        picked.spacing = 6

        categories.addItems(withTitles: (art.kinds.contains { $0.season != nil } ? [GuildStyles.holiday] : []) + GuildStyles.categories)
        categories.selectItem(withTitle: category)
        categories.target = self
        categories.action = #selector(categoryChanged)
        categories.controlSize = .small
        fill.target = self
        fill.action = #selector(fillAll)
        fill.bezelStyle = .rounded
        fill.controlSize = .small

        scroll.documentView = grid
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        scroll.borderType = .noBorder

        status.font = .systemFont(ofSize: 11)
        status.textColor = NSColor(calibratedRed: 1, green: 0.62, blue: 0.55, alpha: 1)
        save = ClosureButton(title: "儲存") { [weak self] in self?.commit() }
        cancel = ClosureButton(title: "取消") { [weak self] in self?.finish(nil, nil) }
        save.bezelStyle = .rounded
        cancel.bezelStyle = .rounded
        let actions = NSStackView(views: [save, cancel])
        actions.spacing = 8

        let stack = NSStackView(views: [head, modes, hint, picked, categories, fill, scroll, status, actions])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.edgeInsets = NSEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        view.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        scroll.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor), stack.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stack.topAnchor.constraint(equalTo: view.topAnchor), stack.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            head.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -24),
            hint.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -24),
            scroll.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -24),
            scroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 160),
            status.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -24),
        ])
    }

    @objc private func modeChanged() {
        mode = Mode(rawValue: modes.selectedSegment) ?? .decor
        hall.brush = mode == .floor ? brush : nil
        if mode != .decor { hall.selected = nil }
        status.stringValue = ""
        refresh()
    }

    @objc private func categoryChanged() {
        category = categories.titleOfSelectedItem ?? category
        refresh()
    }

    @objc private func fillAll() {
        floor = GuildInfo.Floor(base: brush, tiles: [:])
        hall.floorBase = floor.base
        hall.floorTiles = floor.tiles
    }

    // MARK: What is shown

    private var used: Int {
        let size = Dictionary(art.kinds.map { ($0.id, $0.size) }, uniquingKeysWith: { a, _ in a })
        return draft.reduce(0) { $0 + (size[$1.kind] ?? 0) }
    }

    private func refresh() {
        let u = used
        room.stringValue = "裝飾點數 \(u)／\(guild.rules.room)"
        room.textColor = u > guild.rules.room ? NSColor(calibratedRed: 1, green: 0.5, blue: 0.45, alpha: 1) : .secondaryLabelColor
        save.isEnabled = !busy && u <= guild.rules.room
        cancel.isEnabled = !busy

        let d = hall.selected.flatMap { uid in draft.first { $0.uid == uid } }
        let kind = d.flatMap { piece in art.kinds.first { $0.id == piece.kind } }
        picked.isHidden = mode != .decor || d == nil
        if let d, let kind {
            pickedName.stringValue = kind.name + (d.locked == true ? "・🔒 鎖住了" : "")
            let canTouch = d.locked != true || boss
            flipButton.isEnabled = canTouch
            removeButton.isEnabled = canTouch
            lockButton.title = d.locked == true ? "解鎖" : "🔒 鎖定"
        }
        switch mode {
        case .decor:
            hint.stringValue = d == nil ? "點下面的裝飾放進據點，在據點裡拖著移動；點一下已經放的可以翻面、收掉（也可以按 Delete）。" : ""
            hint.isHidden = d != nil
        case .floor:
            hint.stringValue = "選一種地板，在據點裡點一下或拖過去，一格一格鋪；或整片換掉。"
            hint.isHidden = false
        case .wall:
            hint.stringValue = "整個據點的牆一起換，馬上生效。"
            hint.isHidden = false
        }
        categories.isHidden = mode != .decor
        fill.isHidden = mode != .floor
        layoutGrid()
    }

    private func layoutGrid() {
        grid.subviews.forEach { $0.removeFromSuperview() }
        var cells: [CatalogCell] = []
        switch mode {
        case .decor:
            // (a holiday piece needs its season on today, as the server says: the days are worked out only there)
            let season = { (k: GuildArt.DecorKind) in self.guild.seasons.first { $0.id == k.season } }
            let open = { (k: GuildArt.DecorKind) in
                k.level <= self.guild.level && (k.race == nil || self.races.contains(k.race!)) && (k.season == nil || season(k)?.on == true)
            }
            let all = art.kinds.filter { category == GuildStyles.holiday ? $0.season != nil : $0.category == category }
            for k in all.filter(open) + all.filter({ !open($0) }) {
                let piece = art.decorPiece(k.id)
                let shut = !open(k)
                let why = k.level > guild.level ? "Lv \(k.level)"
                    : (k.race != nil && !races.contains(k.race!)) ? "要有\(GuildStyles.races[k.race ?? ""] ?? "")"
                    : season(k).map { "\($0.name) \($0.range)" } ?? "節日限定"
                let cost = "\(k.size) 點" + (season(k).map { "・\($0.name)" } ?? "")
                cells.append(CatalogCell(image: piece.flatMap { art.frame(of: $0, at: 0) }, pixels: NSSize(width: piece?.w ?? 16, height: piece?.h ?? 16), name: k.name,
                                         sub: shut ? why : cost, shut: shut || busy) { [weak self] in self?.add(k.id) })
            }
        case .floor:
            for f in GuildStyles.floors {
                let shut = f.race.map { !races.contains($0) } ?? false
                cells.append(CatalogCell(image: art.floorTile(f.id), pixels: NSSize(width: 16, height: 16), fit: 40, maxScale: 3, name: f.name, sub: shut ? "要有\(GuildStyles.races[f.race ?? ""] ?? "")" : "",
                                         on: brush == f.id, shut: shut) { [weak self] in
                    self?.brush = f.id
                    self?.hall.brush = f.id
                    self?.refresh()
                })
            }
        case .wall:
            for w in GuildStyles.walls {
                let shut = w.race.map { !races.contains($0) } ?? false
                cells.append(CatalogCell(image: art.wallPiece(w.id), pixels: NSSize(width: 16, height: 32), fit: 44, maxScale: 3, name: w.name, sub: shut ? "要有\(GuildStyles.races[w.race ?? ""] ?? "")" : "",
                                         on: wall == w.id, shut: shut || busy) { [weak self] in self?.setWall(w.id) })
            }
        }
        let cols = 4, gap: CGFloat = 4
        let size = CatalogCell.size
        for (i, c) in cells.enumerated() {
            c.frame.origin = NSPoint(x: CGFloat(i % cols) * (size.width + gap), y: CGFloat(i / cols) * (size.height + gap))
            grid.addSubview(c)
        }
        let rows = (cells.count + cols - 1) / cols
        grid.frame = NSRect(x: 0, y: 0, width: CGFloat(cols) * (size.width + gap), height: max(CGFloat(rows) * (size.height + gap), 10))
    }

    // MARK: Changing the hall

    /// Keeps a piece inside the hall, on the wall or on the floor as it belongs, on the art's pixels (pwa/app/pages/guild/index.vue place).
    private func place(_ kind: String, _ x: Double, _ y: Double) -> (x: Double, y: Double) {
        let k = art.decorPiece(kind)
        let w = Double(k?.w ?? 16), h = Double(k?.h ?? 16)
        let half = w / 32
        let cx = min(Double(guild.rules.width) - half, max(half, x))
        let cy = (k?.wall ?? false) ? min(guildWallRows, max(1 + h / 32, y)) : min(Double(guild.rules.height), max(guildWallRows + 1.0 / 16, y))
        let snap = { (v: Double) in (v * 16).rounded() / 16 }
        return (snap(cx), snap(cy))
    }

    private func sync() {
        hall.decor = draft
        refresh()
    }

    private func add(_ kind: String) {
        guard draft.count < 1000 else {
            status.stringValue = "最多放 1000 件。"
            return
        }
        let k = art.decorPiece(kind)
        let at = place(kind, Double(guild.rules.width) / 2, (k?.wall ?? false) ? guildWallRows : guildWallRows + 3)
        let abc = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789")
        let uid = String((0..<10).map { _ in abc.randomElement()! })
        draft.append(GuildInfo.Decor(uid: uid, kind: kind, x: at.x, y: at.y, flip: nil, locked: nil))
        hall.selected = uid
        status.stringValue = ""
        sync()
    }

    private func move(_ uid: String, _ x: Double, _ y: Double) {
        guard let i = draft.firstIndex(where: { $0.uid == uid }), draft[i].locked != true || boss else { return }
        let at = place(draft[i].kind, x, y)
        guard draft[i].x != at.x || draft[i].y != at.y else { return }
        draft[i].x = at.x
        draft[i].y = at.y
        sync()
    }

    private func flip() {
        guard let uid = hall.selected, let i = draft.firstIndex(where: { $0.uid == uid }) else { return }
        draft[i].flip = !(draft[i].flip ?? false)
        sync()
    }

    private func remove(_ uid: String) {
        guard let i = draft.firstIndex(where: { $0.uid == uid }), draft[i].locked != true || boss else { return }
        draft.remove(at: i)
        hall.selected = nil
        sync()
    }

    private func lock() {
        guard let uid = hall.selected, let i = draft.firstIndex(where: { $0.uid == uid }) else { return }
        draft[i].locked = draft[i].locked == true ? nil : true
        sync()
    }

    /// Lays the brush's floor on one tile (the base style needs no tile of its own).
    private func paintTile(_ x: Int, _ y: Int) {
        let key = "\(x),\(y)"
        if brush == floor.base { floor.tiles[key] = nil } else { floor.tiles[key] = brush }
        hall.floorTiles = floor.tiles
    }

    // MARK: Going to the server

    private func setWall(_ id: String) {
        guard !busy else { return }
        busy = true
        refresh()
        struct Body: Encodable { let wall: String }
        Task { @MainActor in
            defer {
                self.busy = false
                self.refresh()
            }
            do {
                let got = try await self.api.request("PUT", "guild/wall", body: Body(wall: id), as: GuildInfo.self)
                self.wall = id
                self.hall.wall = id
                self.status.stringValue = ""
                self.onGuild?(got)
            } catch {
                self.status.stringValue = error.localizedDescription
            }
        }
    }

    private func commit() {
        guard !busy else { return }
        busy = true
        status.stringValue = ""
        refresh()
        struct Body: Encodable { let version: Int; let items: [GuildInfo.Decor]; let floor: GuildInfo.Floor }
        Task { @MainActor in
            do {
                let got = try await self.api.request("PUT", "guild/decor", body: Body(version: self.version, items: self.draft, floor: self.floor), as: GuildInfo.self)
                self.busy = false
                self.finish(got, "裝飾存好了。")
            } catch let e as APIError where e.status == 409 {
                // (someone else saved first: start again from theirs)
                self.busy = false
                self.finish(nil, "有人先存了，已經換成他的版本，請再擺一次。")
            } catch {
                self.busy = false
                self.status.stringValue = error.localizedDescription
                self.refresh()
            }
        }
    }

    private func finish(_ got: GuildInfo?, _ note: String?) {
        release()
        onFinish?(got, note)
    }
}

/// A view whose y runs down, for the panels' scrolling lists (the others are private to their files).
final class TopDownView: NSView {
    override var isFlipped: Bool { true }
}
