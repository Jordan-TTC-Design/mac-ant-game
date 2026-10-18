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
        Style(id: "undead_bone", name: "骨片馬賽克", race: "undead"), Style(id: "beast_redearth", name: "赤土碎石地", race: "beast"),
        Style(id: "beast_hides", name: "縫皮地", race: "beast"),
    ]
    static let walls: [Style] = [
        Style(id: "stone", name: "灰石牆", race: nil), Style(id: "wood", name: "木板牆", race: nil), Style(id: "plain_plaster", name: "白灰泥牆", race: nil),
        Style(id: "plain_wood", name: "素木牆", race: nil), Style(id: "plain_stone", name: "素石牆", race: nil), Style(id: "goblin_hide", name: "獸皮帳幕牆", race: "goblin"),
        Style(id: "elf_vines", name: "活藤樹牆", race: "elf"), Style(id: "undead_gothic", name: "哥德拱窗黑石牆", race: "undead"),
        Style(id: "beast_redrock", name: "紅岩爪痕牆", race: "beast"),
    ]
    static let races = ["goblin": "哥布林", "elf": "精靈", "undead": "死靈", "beast": "獸人"]
    /// The categories, in the order the catalog's tabs show them (shared/src/guild-decor.ts GUILD_DECOR_CATEGORIES).
    /// The tab of the holiday pieces (in front of the categories, when there are any).
    static let holiday = "節日限定"
    /// The tab of the guild merchant's pieces (shared/src/guild-merchant.ts): bought from him, then the guild's to put down.
    static let merchant = "商人限定"
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
    private enum Mode: Int { case decor, floor, wall, area, plots }
    /// The wall brushed a segment at a time, and the floor given to members (GUILD.md §4, the leader and officers): saved with the rest.
    private var walls: [String: String]
    private var plots: [String: String]
    private var wallBrush: String
    /// Who the 🏠 tab gives floor to ("": takes it back).
    private var plotWho = ""
    /// Whether this server keeps wall segments and places (an older one leaves them out, and they are not sent).
    private var keepsWalls: Bool { guild.wallList != nil }
    private var keepsPlots: Bool { guild.plotList != nil }
    /// The hall's shape (the leader and officers, GUILD.md §4.1): drawn tile by tile, saved with the rest.
    private var area: [String]
    private var shapeAdd = true
    /// Whether the shape can be drawn here: by the leader or an officer, with a server that knows of shapes.
    private var canShape: Bool { boss && guild.area != nil && guild.rules.tiles != nil }
    private var tilesMax: Int { guild.rules.tiles ?? 0 }
    private var shapeProblem: String? { canShape ? hallAreaProblem(area, most: tilesMax) : nil }
    private var mode = Mode.decor
    private var brush: String
    /// The piece picked in the catalog to put down like a floor brush (nil: none, a click in the hall picks pieces).
    private var stamp: String? { didSet { hall.stamp = stamp } }
    private var category = GuildStyles.categories[0]
    private var busy = false
    /// What the draft was (the pieces, the floor, the shape), to go back to with ⌘Z and forward again with ⇧⌘Z: one step a
    /// press in the hall (a whole stroke of pieces, tiles or shape), or a button.
    private struct Snapshot: Equatable { var draft: [GuildInfo.Decor]; var floor: GuildInfo.Floor; var area: [String]; var walls: [String: String]; var plots: [String: String] }
    private var undos: [Snapshot] = []
    private var redos: [Snapshot] = []
    private var strokeFrom: Snapshot?
    private static let undoMost = 200

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
    private let wallFill = NSButton(title: "整面換成這種", target: nil, action: nil)
    private let scroll = NSScrollView()
    private let grid = TopDownView()
    private let status = NSTextField(wrappingLabelWithString: "")
    private var save: NSButton!
    private var cancel: NSButton!
    private var undoButton: NSButton!
    private var redoButton: NSButton!

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
        self.walls = guild.walls
        self.plots = guild.plots
        self.wallBrush = guild.wall
        super.init()
        build()
        hall.editing = true
        hall.decor = draft
        hall.floorBase = floor.base
        hall.floorTiles = floor.tiles
        hall.walls = walls
        hall.plots = plots
        hall.onWall = { [weak self] x, y in self?.paintWall(x, y) }
        hall.onPlot = { [weak self] x, y in self?.paintPlot(x, y) }
        hall.boxSelects = true
        hall.onSelect = { [weak self] in self?.refreshHeader() }
        hall.onMove = { [weak self] uid, x, y in self?.move(uid, x, y) }
        hall.onPaint = { [weak self] x, y in self?.paintTile(x, y) }
        hall.onStamp = { [weak self] kind, x, y in self?.stampPiece(kind, x, y) ?? false }
        hall.stampLook = { [weak self] kind, x, y in self?.stampLook(kind, x, y) ?? (x, y, false) }
        hall.onShape = { [weak self] x, y in self?.paintShape(x, y) }
        hall.onRemove = { [weak self] in self?.removePicked() }
        hall.onStroke = { [weak self] began in self?.stroke(began) }
        hall.onUndo = { [weak self] in self?.undo() }
        hall.onRedo = { [weak self] in self?.redo() }
        hall.canUndo = { [weak self] in (self?.undos.isEmpty == false, self?.redos.isEmpty == false) }
        hall.onEscape = { [weak self] in
            self?.hall.selected = []
            self?.stamp = nil
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
        hall.onStamp = nil
        hall.onShape = nil
        hall.onRemove = nil
        hall.onEscape = nil
        hall.onStroke = nil
        hall.onUndo = nil
        hall.onRedo = nil
        hall.canUndo = nil
        hall.stampLook = nil
        hall.onWall = nil
        hall.onPlot = nil
        hall.boxSelects = false
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
        modes.segmentCount = 5
        modes.setLabel("🏠 位置", forSegment: Mode.plots.rawValue)
        // (the wall, the shape and the places are the leader's and officers': a member sees the tabs, greyed)
        modes.setEnabled(boss, forSegment: Mode.wall.rawValue)
        modes.setEnabled(canShape, forSegment: Mode.area.rawValue)
        modes.setEnabled(boss && keepsPlots, forSegment: Mode.plots.rawValue)
        if !boss {
            for m in [Mode.wall, .area, .plots] { modes.setToolTip("只有會長和幹部可以用", forSegment: m.rawValue) }
        }

        hint.font = .systemFont(ofSize: 11)
        hint.textColor = .secondaryLabelColor

        pickedName.font = .boldSystemFont(ofSize: 12)
        flipButton = ClosureButton(title: "↔︎ 翻面") { [weak self] in self?.flip() }
        removeButton = ClosureButton(title: "收掉") { [weak self] in self?.removePicked() }
        lockButton = ClosureButton(title: "🔒 鎖定") { [weak self] in self?.lock() }
        for b in [flipButton!, removeButton!, lockButton!] {
            b.bezelStyle = .rounded
            b.controlSize = .small
        }
        lockButton.isHidden = !boss
        picked.setViews([pickedName, flipButton, removeButton, lockButton], in: .leading)
        picked.spacing = 6

        categories.addItems(withTitles: (art.kinds.contains { $0.season != nil } ? [GuildStyles.holiday] : []) + (art.kinds.contains { $0.merchant } ? [GuildStyles.merchant] : []) + GuildStyles.categories)
        categories.selectItem(withTitle: category)
        categories.target = self
        categories.action = #selector(categoryChanged)
        categories.controlSize = .small
        fill.target = self
        fill.action = #selector(fillAll)
        fill.bezelStyle = .rounded
        fill.controlSize = .small
        wallFill.target = self
        wallFill.action = #selector(wallAll)
        wallFill.bezelStyle = .rounded
        wallFill.controlSize = .small

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
        undoButton = ClosureButton(title: "↶ 復原") { [weak self] in self?.undo() }
        redoButton = ClosureButton(title: "↷ 重做") { [weak self] in self?.redo() }
        for b in [undoButton!, redoButton!] {
            b.bezelStyle = .rounded
            b.controlSize = .small
        }
        undoButton.toolTip = "⌘Z"
        redoButton.toolTip = "⇧⌘Z"
        let actions = NSStackView(views: [save, cancel, NSView(), undoButton, redoButton])
        actions.spacing = 8

        let stack = NSStackView(views: [head, modes, hint, picked, categories, fill, wallFill, scroll, status, actions])
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
            actions.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -24),
        ])
    }

    @objc private func modeChanged() {
        mode = Mode(rawValue: modes.selectedSegment) ?? .decor
        hall.brush = mode == .floor ? brush : nil
        hall.shaping = mode == .area
        hall.boxSelects = mode == .decor
        hall.wallBrush = mode == .wall ? wallBrush : nil
        hall.plotting = mode == .plots
        if mode != .decor { stamp = nil }
        if mode != .decor { hall.selected = [] }
        status.stringValue = ""
        refresh()
    }

    @objc private func categoryChanged() {
        category = categories.titleOfSelectedItem ?? category
        refresh()
    }

    /// The whole wall in the brush's style: at once, as before (and the segments brushed otherwise go with the next save).
    @objc private func wallAll() {
        // (a server that keeps segments: every segment brushed, in the draft like any brushing — ⌘Z takes it back, 儲存 keeps it)
        guard keepsWalls else { return setWall(wallBrush) }
        record()
        let layout = hall.layout
        var next: [String: String] = [:]
        if wallBrush != wall {
            for y in 0..<layout.height { for x in 0..<layout.width where layout.wallAt(x, y) { next["\(x),\(y)"] = wallBrush } }
        }
        walls = next
        hall.walls = walls
        refresh()
    }

    @objc private func fillAll() {
        record()
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
        if mode == .plots {
            room.stringValue = "已分 \(plots.count) 格"
            room.textColor = .secondaryLabelColor
        } else if mode == .area {
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
        undoButton.isEnabled = !busy && !undos.isEmpty
        redoButton.isEnabled = !busy && !redos.isEmpty

        let sel = pickedPieces
        picked.isHidden = mode != .decor || sel.isEmpty
        if let d = sel.first {
            let locked = sel.filter { $0.locked == true }.count
            if sel.count == 1 {
                pickedName.stringValue = (art.kinds.first { $0.id == d.kind }?.name ?? "") + (locked > 0 ? "・🔒 鎖住了" : "")
            } else {
                pickedName.stringValue = "已選 \(sel.count) 件" + (locked > 0 ? "・🔒 \(locked) 件鎖住了" : "")
            }
            let canTouch = boss || locked < sel.count
            flipButton.isEnabled = canTouch
            removeButton.isEnabled = canTouch
            lockButton.title = locked == sel.count ? "解鎖" : "🔒 鎖定"
        }
        switch mode {
        case .decor:
            hint.stringValue = stamp.map { s in "拿著「\(art.kinds.first { $0.id == s }?.name ?? "")」：在據點裡點一下放一件，或拖過去一路放（游標下綠色是放得下、紅色是放不下）。再點一次那張卡片或按 Esc 放下，就可以拖著移動已經放的。" }
                ?? (sel.isEmpty ? "點下面的裝飾拿起來，像鋪地板一樣在據點裡點一下或拖過去放。已經放的：點一下選取、拖著移動；在空地上拖一個框可以一次選很多件，按住 ⇧ 點可以加選或取消（⌘A 全選）；選好的可以一起拖、翻面、收掉（也可以按 Delete）。\n⌘Z 復原、⇧⌘Z 重做；要看別的地方：兩指滑動（或滾輪）、方向鍵。" : "")
            hint.isHidden = stamp == nil && !sel.isEmpty
        case .floor:
            hint.stringValue = "選一種地板，在據點裡點一下或拖過去，一格一格鋪；或整片換掉。"
            hint.isHidden = false
        case .wall:
            hint.stringValue = "選一種牆壁，在據點的牆上點一下或拖過去，一段一段換（跟著其他擺設一起儲存）；「整面換成這種」把每一段都刷成這種（一樣按儲存才生效，⌘Z 可以復原）。"
            hint.isHidden = false
        case .plots:
            hint.stringValue = "選一位成員，在據點的地板上點一下或拖過去，把那幾格分給他當自己的位置：那裡只有他自己和會長、幹部能擺、能動。「收回」把格子變回大家的。"
            hint.isHidden = false
        case .area:
            let left = tilesMax - hallAreaTiles(area)
            hint.stringValue = "在據點裡點一下或拖過去，畫出地板要到哪裡：外面一圈都可以畫，往哪個方向長都行，也可以畫一條走廊接到另一個房間。地板最上面那排會自動長出牆。\n"
                + (left > 0 ? "還可以畫 \(left) 格；" : "格數用完了；") + "公會升級會多給格數。上面有裝飾的格子要先把裝飾移開才能擦。\n要看別的地方：兩指滑動（或滾輪）、方向鍵；畫到畫面邊緣會自己跟著捲。"
            hint.isHidden = false
        }
        categories.isHidden = mode != .decor
        fill.isHidden = mode != .floor
        wallFill.isHidden = mode != .wall
        wallFill.isEnabled = !busy
    }

    private func layoutGrid() {
        grid.subviews.forEach { $0.removeFromSuperview() }
        var cells: [CatalogCell] = []
        switch mode {
        case .decor:
            // (a holiday piece needs its season on today, as the server says: the days are worked out only there)
            let season = { (k: GuildArt.DecorKind) in self.guild.seasons.first { $0.id == k.season } }
            // (and one of the merchant's, the guild to have bought it off him: shared guildDecorUnlocked)
            let open = { (k: GuildArt.DecorKind) in
                k.level <= self.guild.level && (k.race == nil || self.races.contains(k.race!)) && (k.season == nil || season(k)?.on == true)
                    && (!k.merchant || self.guild.unlocked.contains(k.id))
            }
            let all = art.kinds.filter { category == GuildStyles.holiday ? $0.season != nil : category == GuildStyles.merchant ? $0.merchant : $0.category == category }
            for k in all.filter(open) + all.filter({ !open($0) }) {
                let piece = art.decorPiece(k.id)
                let shut = !open(k)
                let why = k.level > guild.level ? "Lv \(k.level)"
                    : k.merchant ? "商人限定"
                    : (k.race != nil && !races.contains(k.race!)) ? "要有\(GuildStyles.races[k.race ?? ""] ?? "")"
                    : season(k).map { "\($0.name) \($0.range)" } ?? "節日限定"
                let cost = "\(k.size) 點" + (season(k).map { "・\($0.name)" } ?? "")
                cells.append(CatalogCell(image: piece.flatMap { art.frame(of: $0, at: 0) }, pixels: NSSize(width: piece?.w ?? 16, height: piece?.h ?? 16), name: k.name,
                                         sub: shut ? why : cost, on: stamp == k.id, shut: shut || busy) { [weak self] in self?.pick(k.id) })
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
                cells.append(CatalogCell(image: art.wallPiece(w.id), pixels: NSSize(width: 16, height: 32), fit: 44, maxScale: 3, name: w.name,
                                         sub: shut ? "要有\(GuildStyles.races[w.race ?? ""] ?? "")" : wall == w.id ? "整面" : "",
                                         on: wallBrush == w.id, shut: shut || busy) { [weak self] in
                    self?.wallBrush = w.id
                    self?.hall.wallBrush = w.id
                    self?.refresh()
                })
            }
        case .plots:
            for m in guild.members.sorted(by: { $0.joinedAt < $1.joinedAt }) {
                let mine = plots.values.filter { $0 == m.id }.count
                cells.append(CatalogCell(image: GuildDecorEditor.swatch(hall.plotColour(m.id) ?? .gray), pixels: NSSize(width: 16, height: 16), fit: 36, maxScale: 3,
                                         name: m.name, sub: mine > 0 ? "\(mine) 格" : "", on: plotWho == m.id) { [weak self] in
                    self?.plotWho = m.id
                    self?.refresh()
                })
            }
            cells.append(CatalogCell(image: nil, pixels: NSSize(width: 16, height: 16), fit: 40, maxScale: 3, name: "🧽 收回", sub: "變回大家的", on: plotWho.isEmpty) { [weak self] in
                self?.plotWho = ""
                self?.refresh()
            })
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

    /// A small square of one colour (a member's, on their card in the 🏠 tab).
    private static func swatch(_ colour: NSColor) -> CGImage? {
        guard let g = CGContext(data: nil, width: 16, height: 16, bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        g.setFillColor(colour.cgColor)
        g.fill(CGRect(x: 2, y: 2, width: 12, height: 12))
        return g.makeImage()
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

    /// A card clicked: its piece is taken up to put down like a floor brush, or put back when it was already in hand.
    private func pick(_ kind: String) {
        stamp = stamp == kind ? nil : kind
        hall.selected = []
        status.stringValue = ""
        refresh()
    }

    /// Where the held piece would go at (x, its bottom y), and whether it can (fits, room, the most pieces): for its picture
    /// under the pointer.
    private func stampLook(_ kind: String, _ x: Double, _ y: Double) -> (x: Double, y: Double, ok: Bool) {
        let room = draft.count < 1000 && used + (sizes[kind] ?? 0) <= guild.rules.room
        if let at = place(kind, x, y) { return (at.x, at.y, room && theirs(kind, at.x, at.y) == nil) }
        let snap = { (v: Double) in (v * 16).rounded() / 16 }
        return (snap(x), snap(y), false)
    }

    /// Puts one of the picked piece down at (x, its bottom y), where it fits and there is room (says whether it went down).
    private func stampPiece(_ kind: String, _ x: Double, _ y: Double) -> Bool {
        guard draft.count < 1000 else {
            status.stringValue = "最多放 1000 件。"
            return false
        }
        guard used + (sizes[kind] ?? 0) <= guild.rules.room else {
            status.stringValue = "裝飾點數不夠了（\(used)／\(guild.rules.room)）。"
            return false
        }
        guard let at = place(kind, x, y) else {
            status.stringValue = art.decorPiece(kind)?.wall == true ? "這件要掛在牆上。" : "這裡放不下（要在地板上）。"
            return false
        }
        if let why = theirs(kind, at.x, at.y) {
            status.stringValue = why
            return false
        }
        let abc = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789")
        let uid = String((0..<10).map { _ in abc.randomElement()! })
        draft.append(GuildInfo.Decor(uid: uid, kind: kind, x: at.x, y: at.y, flip: nil, locked: nil))
        status.stringValue = ""
        sync()
        return true
    }

    /// The tile a piece belongs to, for the places: the one under its feet; a wall piece's, the floor tile at the foot of its
    /// wall (shared/src/guild-decor.ts guildDecorTile).
    private func decorTile(_ kind: String, _ x: Double, _ y: Double) -> String {
        let c = Int(x.rounded(.down))
        if art.decorPiece(kind)?.wall == true, let r = (Int(ceil(y))...Int(ceil(y)) + Int(guildWallRows)).first(where: { hall.layout.wallAt(c, $0) }) { return "\(c),\(r)" }
        return "\(c),\(Int((y - 1e-6).rounded(.down)))"
    }

    /// Why a member may not touch a piece of this kind here: someone else's place (nil: they may; the leader and officers always
    /// may). The server's words (guildDecorChange).
    private func theirs(_ kind: String, _ x: Double, _ y: Double) -> String? {
        guard !boss, let who = plots[decorTile(kind, x, y)], who != hall.me, let name = guild.members.first(where: { $0.id == who })?.name else { return nil }
        return "這裡是\(name)的位置，只有他自己和會長、幹部能動。"
    }

    /// The pieces picked, in the draft's order.
    private var pickedPieces: [GuildInfo.Decor] { hall.selected.isEmpty ? [] : draft.filter { hall.selected.contains($0.uid) } }

    /// A piece dragged with its feet to (x, y), and the others picked with it, by as much: all go, or none (one that would
    /// leave the floor, or a locked one for a member, keeps the lot where it last fitted).
    private func move(_ uid: String, _ x: Double, _ y: Double) {
        guard let lead = draft.first(where: { $0.uid == uid }), let at = place(lead.kind, x, y) else { return }
        let (dx, dy) = (at.x - lead.x, at.y - lead.y)
        guard dx != 0 || dy != 0 else { return }
        let group = hall.selected.contains(uid) ? hall.selected : [uid]
        var next = draft
        for i in next.indices where group.contains(next[i].uid) {
            guard next[i].locked != true || boss, let to = place(next[i].kind, next[i].x + dx, next[i].y + dy) else { return }
            if let why = theirs(next[i].kind, next[i].x, next[i].y) ?? theirs(next[i].kind, to.x, to.y) {
                if status.stringValue != why { status.stringValue = why }
                return
            }
            next[i].x = to.x
            next[i].y = to.y
        }
        draft = next
        sync()
    }

    private func flip() {
        let sel = hall.selected
        guard !sel.isEmpty else { return }
        record()
        var refused: String?
        for i in draft.indices where sel.contains(draft[i].uid) && (draft[i].locked != true || boss) {
            if let why = theirs(draft[i].kind, draft[i].x, draft[i].y) { refused = why; continue }
            draft[i].flip = !(draft[i].flip ?? false)
        }
        status.stringValue = refused ?? ""
        sync()
    }

    /// The picked pieces go (a locked one stays, for a member).
    private func removePicked() {
        let touchable = pickedPieces.filter { $0.locked != true || boss }
        let gone = Set(touchable.filter { theirs($0.kind, $0.x, $0.y) == nil }.map(\.uid))
        status.stringValue = touchable.lazy.compactMap { self.theirs($0.kind, $0.x, $0.y) }.first ?? ""
        guard !gone.isEmpty else { return }
        record()
        draft.removeAll { gone.contains($0.uid) }
        hall.selected.subtract(gone)
        sync()
    }

    /// Locks the picked pieces, or unlocks them when they all are.
    private func lock() {
        let sel = hall.selected
        guard !sel.isEmpty, boss else { return }
        record()
        let on = pickedPieces.contains { $0.locked != true }
        for i in draft.indices where sel.contains(draft[i].uid) { draft[i].locked = on ? true : nil }
        sync()
    }

    // MARK: Undo

    private var snapshot: Snapshot { Snapshot(draft: draft, floor: floor, area: area, walls: walls, plots: plots) }

    /// Keeps the draft as it is now, to come back to (before a change that is not a press in the hall).
    private func record() {
        undos.append(snapshot)
        if undos.count > GuildDecorEditor.undoMost { undos.removeFirst() }
        redos.removeAll()
    }

    /// A press in the hall: what it changed by the time it ends is one step.
    private func stroke(_ began: Bool) {
        if began {
            strokeFrom = snapshot
            return
        }
        guard let from = strokeFrom else { return }
        strokeFrom = nil
        guard from != snapshot else { return }
        undos.append(from)
        if undos.count > GuildDecorEditor.undoMost { undos.removeFirst() }
        redos.removeAll()
        refreshHeader()
    }

    private func undo() {
        guard !busy, let back = undos.popLast() else { return }
        redos.append(snapshot)
        restore(back)
    }

    private func redo() {
        guard !busy, let next = redos.popLast() else { return }
        undos.append(snapshot)
        restore(next)
    }

    private func restore(_ s: Snapshot) {
        draft = s.draft
        floor = s.floor
        area = s.area
        walls = s.walls
        plots = s.plots
        hall.area = area
        hall.walls = walls
        hall.plots = plots
        hall.floorBase = floor.base
        hall.floorTiles = floor.tiles
        hall.decor = draft
        hall.selected = hall.selected.filter { uid in draft.contains { $0.uid == uid } }
        status.stringValue = ""
        refresh()
    }

    /// Brushes one column of wall, by the floor tile it stands on (the guild's own style needs no segment of its own).
    private func paintWall(_ x: Int, _ y: Int) {
        let key = "\(x),\(y)"
        if wallBrush == wall { walls[key] = nil } else { walls[key] = wallBrush }
        hall.walls = walls
    }

    /// Gives one floor tile to the member picked in the 🏠 tab, or takes it back.
    private func paintPlot(_ x: Int, _ y: Int) {
        let key = "\(x),\(y)"
        let was = plots[key]
        plots[key] = plotWho.isEmpty ? nil : plotWho
        guard plots[key] != was else { return }
        hall.plots = plots
        refresh()
    }

    /// Tile keys moved by (dx, dy), and only those still good in the new shape (shared shiftTileKeys, keepTileKeys).
    private static func shifted(_ map: [String: String], _ dx: Int, _ dy: Int, keep: (Int, Int) -> Bool) -> [String: String] {
        var out: [String: String] = [:]
        for (key, v) in map {
            let at = key.split(separator: ",").compactMap { Int($0) }
            guard at.count == 2, at[0] + dx >= 0, at[1] + dy >= 0, keep(at[0] + dx, at[1] + dy) else { continue }
            out["\(at[0] + dx),\(at[1] + dy)"] = v
        }
        return out
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
        // (the wall segments and places move with it too, and those now off the wall or the floor go)
        walls = GuildDecorEditor.shifted(walls, next.dx, next.dy) { shape.wallAt($0, $1) }
        plots = GuildDecorEditor.shifted(plots, next.dx, next.dy) { shape.floorAt($0, $1) }
        hall.area = area
        hall.floorTiles = tiles
        hall.walls = walls
        hall.plots = plots
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
        struct Body: Encodable { let version: Int; let items: [GuildInfo.Decor]; let floor: GuildInfo.Floor; let area: [String]?; let walls: [String: String]?; let plots: [String: String]? }
        // (the wall segments and places go from the leader and officers, to a server that keeps them)
        let walls = boss && keepsWalls ? walls : nil, plots = boss && keepsPlots ? plots : nil
        // (the shape goes only when it was drawn anew)
        let shape = canShape && area != guild.hallArea ? area : nil
        Task { @MainActor in
            do {
                let got = try await self.api.request("PUT", "guild/decor", body: Body(version: self.version, items: self.draft, floor: self.floor, area: shape, walls: walls, plots: plots), as: GuildInfo.self)
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
