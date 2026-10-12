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
    let view = NSView()
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
    private enum Mode: Int { case decor, floor, wall, area }
    /// The hall's shape (the leader and officers, GUILD.md §4.1): drawn tile by tile, saved with the rest.
    private var area: [String]
    private var shapeAdd = true
    /// Whether the shape can be drawn here: by the leader or an officer, with a server that knows of shapes.
    private var canShape: Bool { boss && guild.area != nil && guild.rules.tiles != nil }
    private var tilesMax: Int { guild.rules.tiles ?? 0 }
    private var shapeProblem: String? { canShape ? hallAreaProblem(area, most: tilesMax) : nil }
    private var mode = Mode.decor
    private var brush: String
    private var category = GuildStyles.categories[0]
    private var busy = false

    private let room = NSTextField(labelWithString: "")
    private let modes = NSSegmentedControl(labels: ["🪑 裝飾", "🟫 地板", "🧱 牆壁", "📐 範圍"], trackingMode: .selectOne, target: nil, action: nil)
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
        self.area = guild.hallArea
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
        hall.onShape = { [weak self] x, y in self?.paintShape(x, y) }
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

    /// A test: the 範圍 tab, with these tiles drawn on (or rubbed out); what the panel then says, and the shape.
    func debugShape(_ tiles: [[Int]], add: Bool) -> String {
        modes.selectedSegment = Mode.area.rawValue
        modeChanged()
        shapeAdd = add
        for t in tiles where t.count == 2 { paintShape(t[0], t[1]) }
        refresh()
        return "tiles \(hallAreaTiles(area))/\(tilesMax), problem \(shapeProblem ?? "none"), status '\(status.stringValue)', first piece \(draft.first.map { "\($0.x),\($0.y)" } ?? "-"), floor \(floor.tiles.keys.sorted()), area \(area.prefix(3)) … \(area.count) rows"
    }

    /// Takes the hall back from the editor.
    func release() {
        hall.editing = false
        hall.onSelect = nil
        hall.onMove = nil
        hall.onPaint = nil
        hall.onShape = nil
        hall.onRemove = nil
        hall.onEscape = nil
    }

    private var boss: Bool { role != "member" }

    // MARK: The panel

    private func build() {
        view.wantsLayer = true // (a plain dark backing, not a blur: see GuildPanel)
        view.layer?.cornerRadius = 12
        view.layer?.backgroundColor = NSColor(white: 0.09, alpha: 0.95).cgColor

        let title = NSTextField(labelWithString: "擺裝飾")
        title.font = .boldSystemFont(ofSize: 15)
        room.font = .systemFont(ofSize: 12, weight: .semibold)
        let head = NSStackView(views: [title, NSView(), room])
        head.distribution = .fill

        modes.target = self
        modes.action = #selector(modeChanged)
        modes.selectedSegment = 0
        modes.segmentCount = canShape ? 4 : boss ? 3 : 2

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
        hall.shaping = mode == .area
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

    /// What each kind takes of the room (made once: the catalog is hundreds of pieces and this is asked at every drag).
    private lazy var sizes: [String: Int] = Dictionary(art.kinds.map { ($0.id, $0.size) }, uniquingKeysWith: { a, _ in a })
    private var used: Int { draft.reduce(0) { $0 + (sizes[$1.kind] ?? 0) } }

    /// Everything on the panel again, the catalog's cards too (when the tab, the mode, the brush or the wall changed).
    private func refresh() {
        refreshHeader()
        layoutGrid()
    }

    /// The room used, the picked piece and the buttons: what a placed or dragged piece changes (not the catalog's cards).
    private func refreshHeader() {
        let u = used
        let problem = shapeProblem
        if mode == .area {
            let n = hallAreaTiles(area)
            room.stringValue = "地板 \(n)／\(tilesMax) 格"
            room.textColor = n > tilesMax ? NSColor(calibratedRed: 1, green: 0.5, blue: 0.45, alpha: 1) : .secondaryLabelColor
        } else {
            room.stringValue = "裝飾點數 \(u)／\(guild.rules.room)"
            room.textColor = u > guild.rules.room ? NSColor(calibratedRed: 1, green: 0.5, blue: 0.45, alpha: 1) : .secondaryLabelColor
        }
        save.isEnabled = !busy && u <= guild.rules.room && problem == nil
        if let problem, mode == .area { status.stringValue = problem }
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
        case .area:
            let left = tilesMax - hallAreaTiles(area)
            hint.stringValue = "在據點裡點一下或拖過去，畫出地板要到哪裡：外面一圈都可以畫，往哪個方向長都行，也可以畫一條走廊接到另一個房間。地板最上面那排會自動長出牆。\n"
                + (left > 0 ? "還可以畫 \(left) 格；" : "格數用完了；") + "公會升級會多給格數。上面有裝飾的格子要先把裝飾移開才能擦。"
            hint.isHidden = false
        }
        categories.isHidden = mode != .decor
        fill.isHidden = mode != .floor
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
        case .area:
            cells.append(CatalogCell(image: art.floorTile(floor.base), pixels: NSSize(width: 16, height: 16), fit: 40, maxScale: 3, name: "✏️ 畫地板", sub: "", on: shapeAdd) { [weak self] in
                self?.shapeAdd = true
                self?.refresh()
            })
            cells.append(CatalogCell(image: nil, pixels: NSSize(width: 16, height: 16), fit: 40, maxScale: 3, name: "🧽 擦掉", sub: "", on: !shapeAdd) { [weak self] in
                self?.shapeAdd = false
                self?.refresh()
            })
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

    /// Where a piece dragged to (x, y) goes, on the art's pixels: there if it fits (on the floor, or on a wall over a top edge
    /// of it); nil: it does not (pwa/app/pages/guild/index.vue place).
    private func place(_ kind: String, _ x: Double, _ y: Double) -> (x: Double, y: Double)? {
        let k = art.decorPiece(kind)
        let snap = { (v: Double) in (v * 16).rounded() / 16 }
        let at = (x: snap(x), y: snap(y))
        return hall.layout.fits(w: Double(k?.w ?? 16), wall: k?.wall ?? false, x: at.x, y: at.y) ? at : nil
    }

    private func sync() {
        hall.decor = draft
        refreshHeader()
    }

    private func add(_ kind: String) {
        guard draft.count < 1000 else {
            status.stringValue = "最多放 1000 件。"
            return
        }
        let k = art.decorPiece(kind)
        // (the middle of the hall if it fits there, else the first floor tile, or wall over a top edge, where it does)
        let wall = k?.wall ?? false
        var tries = [HallPoint(x: Double(hall.layout.width) / 2, y: wall ? guildWallRows : guildWallRows + 3)]
        tries += hall.layout.floorTiles.map { HallPoint(x: $0.x + 0.5, y: wall ? $0.y : $0.y + 1) }
        guard let at = tries.lazy.compactMap({ self.place(kind, $0.x, $0.y) }).first else {
            status.stringValue = "據點裡沒有放得下這件裝飾的地方。"
            return
        }
        let abc = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789")
        let uid = String((0..<10).map { _ in abc.randomElement()! })
        draft.append(GuildInfo.Decor(uid: uid, kind: kind, x: at.x, y: at.y, flip: nil, locked: nil))
        hall.selected = uid
        status.stringValue = ""
        sync()
    }

    private func move(_ uid: String, _ x: Double, _ y: Double) {
        guard let i = draft.firstIndex(where: { $0.uid == uid }), draft[i].locked != true || boss else { return }
        // (dragged off the floor: it stays where it last fitted)
        guard let at = place(draft[i].kind, x, y), draft[i].x != at.x || draft[i].y != at.y else { return }
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

    /// Draws one tile of the hall's shape on, or rubs it out; everything moves with it when it grows up or to the left
    /// (pwa/app/pages/guild/index.vue paintShape).
    private func paintShape(_ x: Int, _ y: Int) {
        let on = shapeAdd
        guard hall.layout.floorAt(x, y) != on else { return }
        if on, hallAreaTiles(area) >= tilesMax {
            status.stringValue = "地板最多 \(tilesMax) 格，先擦掉別的地方，或等公會升級。"
            return
        }
        guard let next = hallAreaPaint(area, x: x, y: y, on: on) else { return }
        if (next.area.map(\.count).max() ?? 0) > hallAreaMaxWidth || next.area.count + Int(guildWallRows) > hallAreaMaxHeight {
            status.stringValue = "據點最寬 \(hallAreaMaxWidth) 格、最高 \(hallAreaMaxHeight - Int(guildWallRows)) 格。"
            return
        }
        let (dx, dy) = (Double(next.dx), Double(next.dy))
        let shape = hallLayout(area: next.area)
        var moved = draft
        for i in moved.indices {
            moved[i].x += dx
            moved[i].y += dy
            let k = art.decorPiece(moved[i].kind)
            if !shape.fits(w: Double(k?.w ?? 16), wall: k?.wall ?? false, x: moved[i].x, y: moved[i].y) {
                status.stringValue = "這格上面有裝飾，先把它移開才能擦掉。"
                return
            }
        }
        // (the floor's own styles move with it; one on a tile rubbed out goes)
        var tiles: [String: String] = [:]
        for (key, id) in floor.tiles {
            let at = key.split(separator: ",").compactMap { Int($0) }
            if at.count == 2, shape.floorAt(at[0] + next.dx, at[1] + next.dy) { tiles["\(at[0] + next.dx),\(at[1] + next.dy)"] = id }
        }
        status.stringValue = ""
        area = next.area
        draft = moved
        floor.tiles = tiles
        hall.area = area
        hall.floorTiles = tiles
        hall.decor = draft
        if next.dx != 0 || next.dy != 0 { hall.nudge(dx: next.dx, dy: next.dy) }
        refreshHeader()
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
        struct Body: Encodable { let version: Int; let items: [GuildInfo.Decor]; let floor: GuildInfo.Floor; let area: [String]? }
        // (the shape goes only when it was drawn anew)
        let shape = canShape && area != guild.hallArea ? area : nil
        Task { @MainActor in
            do {
                let got = try await self.api.request("PUT", "guild/decor", body: Body(version: self.version, items: self.draft, floor: self.floor, area: shape), as: GuildInfo.self)
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
