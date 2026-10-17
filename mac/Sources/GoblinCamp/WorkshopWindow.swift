import AppKit

/// The workshop's pages. 製作 turns materials into gear (straight to whoever needs it most, several at once, or for a goblin
/// you pick), with suggestions on top (what would upgrade the most, what wants mending); 道具 (signed in) makes what parties
/// take along; 現有裝備 lists every piece there is by kind, worn or in the stock, to take off, hand over or hold; 修理 mends
/// worn pieces, one or all. A switch turns the handing out of the stock on or off (what you placed by hand is never moved
/// either way). Signed in, residents living on a held cell or guarding a friend's are in it too (the handing out reaches the
/// towns, and every cell with a second switch). What happened shows in a line above the page, not scrolled away.
final class WorkshopWindow: NSObject, MainPane {
    enum Tab: Int { case make, items, pieces, repair }

    let paneView: NSView
    private let colony: Colony
    private let scroll = NSScrollView()
    private var lastMessage = ""
    private var tab = Tab.make
    /// 製作: which slot (nil: all), and whether to show only what can be made now.
    private var slotFilter: GearSlot?
    private var onlyAffordable = true
    /// 現有裝備: the kinds opened to show who has each piece.
    private var opened: Set<String> = []
    /// The line above the page saying what just happened (the page itself scrolls).
    private let status = NSTextField(wrappingLabelWithString: "")
    /// The width the page was laid out for (laid out again when the window is made wider or narrower).
    private var laidOutWidth: CGFloat = 0

    /// The page follows the window's width, between these.
    private static let narrowest: CGFloat = 600, widest: CGFloat = 900
    private var width: CGFloat { max(WorkshopWindow.narrowest, min(WorkshopWindow.widest, scroll.contentSize.width)) }

    init(colony: Colony) {
        self.colony = colony
        paneView = NSView(frame: NSRect(x: 0, y: 0, width: WorkshopWindow.narrowest, height: 700))
        super.init()
        scroll.frame = paneView.bounds
        scroll.autoresizingMask = [.width, .height]
        status.font = .systemFont(ofSize: 12, weight: .semibold)
        status.textColor = .systemGreen
        status.autoresizingMask = [.width, .minYMargin]
        status.isHidden = true
        paneView.addSubview(status)
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        scroll.postsFrameChangedNotifications = true
        paneView.addSubview(scroll)
        NotificationCenter.default.addObserver(forName: NSView.frameDidChangeNotification, object: scroll, queue: .main) { [weak self] _ in
            guard let self, abs(self.width - self.laidOutWidth) > 1, self.paneView.window != nil else { return }
            self.refresh()
        }
        refresh()
    }

    var contentViewForTesting: NSView? { paneView }

    /// Off-screen drawing for tests uses the light look (in the dark look the text is white on nothing).
    func useLightAppearanceForTesting() { paneView.appearance = NSAppearance(named: .aqua) }

    /// For tests: shows a page (and scrolls to its top).
    func select(_ tab: Tab) {
        self.tab = tab
        refresh()
    }

    func paneWillShow() { refresh() }

    /// A line from the server about what was made, mended or handed over (the camp follows the books).
    func show(_ message: String) {
        lastMessage = message
        refresh()
    }

    // MARK: Layout (by hand, top to bottom)

    private let margin: CGFloat = 20
    private var inner: CGFloat { width - margin * 2 }

    /// Rebuilds the page (after making something, or when the materials changed).
    func refresh() {
        let keepScroll = scroll.contentView.bounds.origin
        laidOutWidth = width
        let holder = FlippedView(frame: NSRect(x: 0, y: 0, width: width, height: 10))
        var y: CGFloat = 14

        placeStatus()
        let names: [Tab: String] = [.make: "製作", .items: "道具", .pieces: "現有裝備（\(pieceCount)）", .repair: "修理（\(colony.repairJobs().count)）"]
        if !visibleTabs.contains(tab) { tab = .make }
        let tabs = NSSegmentedControl(labels: visibleTabs.map { names[$0]! }, trackingMode: .selectOne, target: self, action: #selector(tabChanged(_:)))
        tabs.selectedSegment = visibleTabs.firstIndex(of: tab) ?? 0
        tabs.sizeToFit()
        tabs.frame.origin = NSPoint(x: margin, y: y)
        holder.addSubview(tabs)
        y += tabs.frame.height + 8

        let auto = NSButton(checkboxWithTitle: "自動把倉庫的裝備發給最需要的居民", target: self, action: #selector(autoChanged(_:)))
        auto.state = colony.autoGear ? .on : .off
        auto.toolTip = "你手動給的（📌）和保留在倉庫的，自動分配都不會動"
        auto.sizeToFit()
        auto.frame.origin = NSPoint(x: margin, y: y)
        holder.addSubview(auto)
        y += auto.frame.height + 4
        if colony.followsBooks {
            let far = NSButton(checkboxWithTitle: "自動分配也包含領地（營地和城鎮一定會發）", target: self, action: #selector(farChanged(_:)))
            far.state = colony.autoGearFar ? .on : .off
            far.isEnabled = colony.autoGear
            far.toolTip = "關著時只發給營地和城鎮的居民；打開後每一塊領地的居民也會拿到"
            far.sizeToFit()
            far.frame.origin = NSPoint(x: margin + 18, y: y)
            holder.addSubview(far)
            y += far.frame.height + 4
        }
        y += 4

        switch tab {
        case .make: y = layoutMake(in: holder, y: y)
        case .items: y = layoutItems(in: holder, y: y)
        case .pieces: y = layoutPieces(in: holder, y: y)
        case .repair: y = layoutRepairs(in: holder, y: y)
        }
        holder.frame.size.height = y + 16
        scroll.documentView = holder
        scroll.contentView.scroll(to: NSPoint(x: 0, y: min(keepScroll.y, max(0, holder.frame.height - scroll.contentView.bounds.height))))
    }

    /// 道具 only signed in (they are for the big world's expeditions).
    private var visibleTabs: [Tab] { colony.followsBooks ? [.make, .items, .pieces, .repair] : [.make, .pieces, .repair] }

    /// The line above the page: shown (and the page made shorter) while there is something to say.
    private func placeStatus() {
        let bounds = paneView.bounds
        status.isHidden = lastMessage.isEmpty
        status.stringValue = lastMessage
        let h: CGFloat = lastMessage.isEmpty ? 0 : ceil(status.sizeThatFits(NSSize(width: bounds.width - margin * 2, height: 200)).height) + 12
        status.frame = NSRect(x: margin, y: bounds.height - h + 4, width: bounds.width - margin * 2, height: max(0, h - 8))
        scroll.frame = NSRect(x: 0, y: 0, width: bounds.width, height: bounds.height - h)
    }

    private var pieceCount: Int { colony.armory.count + (colony.ants + colony.awayResidents.map(\.ant)).reduce(0) { $0 + $1.gear.count } }

    @discardableResult
    private func label(_ text: String, size: CGFloat = 12, bold: Bool = false, color: NSColor = .labelColor, in holder: NSView, x: CGFloat? = nil, y: CGFloat, width: CGFloat? = nil) -> NSTextField {
        let w = width ?? inner
        let f = NSTextField(wrappingLabelWithString: text)
        f.font = .systemFont(ofSize: size, weight: bold ? .semibold : .regular)
        f.textColor = color
        f.preferredMaxLayoutWidth = w
        let fit = f.sizeThatFits(NSSize(width: w, height: 1000))
        f.frame = NSRect(x: x ?? margin, y: y, width: w, height: ceil(fit.height))
        holder.addSubview(f)
        return f
    }

    private func button(_ title: String, enabled: Bool = true, in holder: NSView, x: CGFloat, y: CGFloat, width: CGFloat = 96, action: @escaping (NSButton) -> Void) -> NSButton {
        weak var me: NSButton?
        let b = ClosureButton(title: title) { if let me { action(me) } }
        me = b
        b.bezelStyle = .rounded
        b.isEnabled = enabled
        b.frame = NSRect(x: x, y: y, width: width, height: 28)
        holder.addSubview(b)
        return b
    }

    /// A piece's icon at the left of a row (nothing when the art is missing). Returns how far the text moves right.
    @discardableResult
    private func icon(_ id: String, in holder: NSView, y: CGFloat, points: CGFloat) -> CGFloat {
        guard let image = GearIcons.image(id, points: points) else { return 0 }
        let view = NSImageView(frame: NSRect(x: margin, y: y, width: points, height: points))
        view.image = image
        holder.addSubview(view)
        return points + 8
    }

    private func costText(_ cost: [(String, Int)]) -> NSAttributedString {
        let text = NSMutableAttributedString()
        for (i, (id, need)) in cost.enumerated() {
            let owned = colony.materials[id, default: 0]
            if i > 0 { text.append(NSAttributedString(string: "　")) }
            text.append(NSAttributedString(string: "\(Materials.info(id)?.name ?? id) \(owned)/\(need)", attributes: [
                .font: NSFont.systemFont(ofSize: 11, weight: .medium),
                .foregroundColor: owned >= need ? NSColor.systemGreen : NSColor.systemRed,
            ]))
        }
        return text
    }

    // MARK: 製作

    /// T−1 (only the camp's own wood and stone), 未開放 (materials from places not open yet), or nothing.
    static func tier(of gear: Gear) -> String? {
        if Gears.unopened.contains(gear.id) { return "未開放" }
        if gear.cost.allSatisfy({ ["log", "stone"].contains($0.0) }) { return "T−1" }
        return nil
    }

    private func layoutMake(in holder: NSView, y start: CGFloat) -> CGFloat {
        var y = start
        let have = colony.materials.filter { $0.value > 0 }.sorted { $0.key < $1.key }
        let stock = have.isEmpty ? "還沒有素材。" : "素材：" + have.map { "\(Materials.info($0.key)?.name ?? $0.key) ×\($0.value)" }.joined(separator: "　")
        y += label(stock, color: .secondaryLabelColor, in: holder, y: y).frame.height + 8
        y = layoutSuggestions(in: holder, y: y)

        let slots: [GearSlot?] = [nil] + GearSlot.allCases.map { $0 }
        let filter = NSSegmentedControl(labels: slots.map { $0?.label ?? "全部" }, trackingMode: .selectOne, target: self, action: #selector(slotChanged(_:)))
        filter.selectedSegment = slots.firstIndex { $0 == slotFilter } ?? 0
        filter.segmentStyle = .rounded
        filter.sizeToFit()
        filter.frame.origin = NSPoint(x: margin, y: y)
        holder.addSubview(filter)
        let only = NSButton(checkboxWithTitle: "只看做得出來的", target: self, action: #selector(onlyChanged(_:)))
        only.state = onlyAffordable ? .on : .off
        only.sizeToFit()
        only.frame.origin = NSPoint(x: margin + inner - only.frame.width, y: y + 2)
        holder.addSubview(only)
        y += filter.frame.height + 10

        let shown = Gears.all
            .filter { slotFilter == nil || $0.slot == slotFilter }
            .filter { !onlyAffordable || (!Gears.unopened.contains($0.id) && colony.canAfford($0)) }
        if shown.isEmpty { y += label("沒有做得出來的。", color: .secondaryLabelColor, in: holder, y: y).frame.height + 8 }
        for slot in GearSlot.allCases {
            let rows = shown.filter { $0.slot == slot }.sorted { $0.power < $1.power }
            guard !rows.isEmpty else { continue }
            if slotFilter == nil { y += label(slot.label, size: 14, bold: true, in: holder, y: y).frame.height + 6 }
            for gear in rows { y += makeRow(gear, in: holder, y: y) + 8 }
            y += 4
        }
        return y
    }

    /// What would help most now, one click each: for each slot, the best piece the materials make, for everyone it would
    /// upgrade (as many as can be made, up to 20); and mending whatever wants it. Nothing when there is nothing to do.
    private func layoutSuggestions(in holder: NSView, y start: CGFloat) -> CGFloat {
        var lines: [(String, String, () -> Void)] = []
        if colony.autoGear {
            for slot in GearSlot.allCases {
                let best = Gears.all.filter { $0.slot == slot && !Gears.unopened.contains($0.id) && colony.canAfford($0) && colony.upgradeCount($0) > 0 }.max { $0.power < $1.power }
                guard let gear = best else { continue }
                let need = colony.upgradeCount(gear)
                let n = min(need, colony.affordableCount(gear.cost), 20)
                lines.append(("\(slot.label)：\(need) 隻可以換成\(gear.name)（\(gear.effectText)）", n > 1 ? "做 ×\(n)" : "做 1 件", { [weak self] in self?.make(gear, count: n) }))
            }
        }
        let mendable = colony.repairJobs().filter { colony.canAffordRepair($0.gear) }.count
        if mendable > 0 { lines.append(("修理：\(mendable) 件快壞了，材料夠修", "全部修理", { [weak self] in self?.repairAll() })) }
        guard !lines.isEmpty else { return start }
        var y = start
        y += label("建議", size: 14, bold: true, in: holder, y: y).frame.height + 4
        for (text, action, run) in lines.prefix(6) {
            label(text, size: 12, in: holder, y: y + 6, width: inner - 110)
            _ = button(action, in: holder, x: margin + inner - 96, y: y) { _ in run() }
            y += 32
        }
        return y + 10
    }

    /// One recipe: name, tier, effect, a line about it, how many there are and would gain from it, the cost, and 製作 (straight
    /// to whoever needs it most) with ⌄ (several at once, or for someone picked). Returns its height.
    private func makeRow(_ gear: Gear, in holder: NSView, y: CGFloat) -> CGFloat {
        let unopened = Gears.unopened.contains(gear.id)
        let affordable = !unopened && colony.canAfford(gear)
        let shift = icon(gear.id, in: holder, y: y + 2, points: 30)
        let left = margin + shift
        let width = inner - 120 - shift
        var top = y
        let title = NSMutableAttributedString(string: gear.name, attributes: [.font: NSFont.systemFont(ofSize: 13, weight: .semibold), .foregroundColor: NSColor.labelColor])
        if let tier = WorkshopWindow.tier(of: gear) {
            title.append(NSAttributedString(string: "  \(tier)", attributes: [.font: NSFont.systemFont(ofSize: 11, weight: .bold),
                                                                               .foregroundColor: tier == "未開放" ? NSColor.systemGray : NSColor.systemBrown]))
        }
        title.append(NSAttributedString(string: "　\(gear.effectText)", attributes: [.font: NSFont.systemFont(ofSize: 12), .foregroundColor: NSColor.labelColor]))
        let t = NSTextField(labelWithAttributedString: title)
        t.lineBreakMode = .byTruncatingTail
        t.frame = NSRect(x: left, y: top, width: width, height: 17)
        holder.addSubview(t)
        top += 18
        let gain = unopened ? 0 : colony.upgradeCount(gear)
        top += label(gear.blurb + "　（穿著 \(colony.wearers(of: gear))・倉庫 \(colony.inStock(of: gear))\(gain > 0 ? "・能讓 \(gain) 隻變強" : "")）", size: 11, color: .secondaryLabelColor, in: holder, x: left, y: top, width: width).frame.height + 2
        let cost = NSTextField(labelWithAttributedString: costText(gear.cost))
        cost.frame = NSRect(x: left, y: top, width: width, height: 16)
        holder.addSubview(cost)
        top += 16
        // 製作: straight to whoever needs it most (into the stock with the handing out off); ⌄: several, or someone picked
        let nobody = colony.autoGear && gain == 0
        let mid = y + (top - y) / 2 - 14
        let b = button(unopened ? "未開放" : !affordable ? "材料不足" : nobody ? "都有了" : "製作", enabled: affordable && !nobody, in: holder, x: margin + inner - 112, y: mid, width: 80) { [weak self] _ in
            self?.make(gear, count: 1)
        }
        b.toolTip = unopened ? "材料只在大世界還沒開放的地方（或世界魔王）才有" : nobody ? "大家這個位置都有一樣好或更好的了；按 ⌄ 可以挑一隻給牠" : colony.autoGear ? "給最需要的：\(colony.autoPick(for: gear)?.name ?? "")" : "放進倉庫"
        let more = button("⌄", enabled: affordable, in: holder, x: margin + inner - 30, y: mid, width: 30) { [weak self] sender in
            self?.chooseOwner(for: gear, from: sender)
        }
        more.toolTip = "一次做好幾件，或挑一隻給牠"
        return top - y
    }

    /// ⌄: several at once (each for whoever needs it most then), or one for a goblin picked from the list.
    private func chooseOwner(for gear: Gear, from sender: NSButton) {
        let menu = GearMenus.residents(colony: colony, slot: gear.slot, first: nil) { [weak self] ant in self?.make(gear, for: ant.id) }
        let can = colony.affordableCount(gear.cost)
        let need = colony.autoGear ? colony.upgradeCount(gear) : can
        let all = min(need, can, 20)
        var batches = [3, 5, 10].filter { $0 < all }.map { n in (colony.autoGear ? "做 \(n) 件（給最需要的 \(n) 隻）" : "做 \(n) 件（放進倉庫）", n) }
        if all > 1 { batches.append((colony.autoGear ? "做到每隻需要的都有（\(all) 件）" : "做 \(all) 件（材料做得出來的）", all)) }
        if !batches.isEmpty {
            for (i, (title, n)) in batches.enumerated() { menu.insertItem(ClosureMenuItem(title: title) { [weak self] in self?.make(gear, count: n) }, at: i) }
            menu.insertItem(.separator(), at: batches.count)
        }
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.height + 2), in: sender)
    }

    /// 製作 / 做 ×n: for whoever needs them most (into the stock with the handing out off).
    private func make(_ gear: Gear, count: Int) {
        guard count > 1 else { return make(gear, for: nil) }
        let (made, sent) = colony.craftMany(gear, count: count)
        lastMessage = sent ? "做 \(count) 件\(gear.name)中…" : made > 0 ? "做好了 \(made) 件\(gear.name)。" : "大家身上這個位置都有一樣好或更好的了，先不做。"
        refresh()
    }

    private func repairAll() {
        let n = colony.repairAll()
        lastMessage = n == 0 ? "材料不夠，一件都修不了。" : colony.followsBooks ? "修理中…" : "修好了 \(n) 件。"
        refresh()
    }

    // MARK: 道具

    private func layoutItems(in holder: NSView, y start: CGFloat) -> CGFloat {
        var y = start
        y += label("道具放在倉庫，出征時和加成食物一樣帶著用（每 5 隻 1 個）。有些要先完成任務才會解鎖。", size: 11, color: .secondaryLabelColor, in: holder, y: y).frame.height + 8
        for item in Items.all {
            let open = colony.isOpen(item)
            let can = open && colony.affordableCount(item.cost) > 0
            let title = NSMutableAttributedString(string: item.name, attributes: [.font: NSFont.systemFont(ofSize: 13, weight: .semibold), .foregroundColor: open ? NSColor.labelColor : NSColor.secondaryLabelColor])
            if !open { title.append(NSAttributedString(string: "  任務解鎖", attributes: [.font: NSFont.systemFont(ofSize: 11, weight: .bold), .foregroundColor: NSColor.systemGray])) }
            title.append(NSAttributedString(string: "　\(item.what)", attributes: [.font: NSFont.systemFont(ofSize: 12), .foregroundColor: NSColor.labelColor]))
            let t = NSTextField(labelWithAttributedString: title)
            t.frame = NSRect(x: margin, y: y, width: inner - 110, height: 17)
            holder.addSubview(t)
            label("倉庫有 \(colony.materials[item.id, default: 0])", size: 11, color: .secondaryLabelColor, in: holder, y: y + 18, width: inner - 110)
            let cost = NSTextField(labelWithAttributedString: costText(item.cost))
            cost.frame = NSRect(x: margin, y: y + 34, width: inner - 110, height: 16)
            holder.addSubview(cost)
            _ = button(!open ? "未解鎖" : can ? "製作" : "材料不足", enabled: can, in: holder, x: margin + inner - 96, y: y + 12) { [weak self] _ in
                guard let self else { return }
                self.lastMessage = self.colony.craftItem(item) ? "做\(item.name)中…" : "做不了\(item.name)。"
                self.refresh()
            }
            y += 58
        }
        return y
    }

    private func make(_ gear: Gear, for antID: Int?) {
        switch colony.craft(gear, for: antID) {
        case .made(let made, let by): lastMessage = "做好了 \(made.name)，交給 \(by)。"
        case .stored(let made): lastMessage = "做好了 \(made.name)，放進倉庫。"
        case .missing: lastMessage = "材料不夠。"
        case .nobodyNeeds: lastMessage = "大家身上這個位置都有一樣好或更好的了，先不做（可以挑一隻給牠）。"
        case .refused(let why): lastMessage = why
        case .sent(let made): lastMessage = "做\(made.name)中…"
        }
        refresh()
    }

    // MARK: 現有裝備

    private func layoutPieces(in holder: NSView, y start: CGFloat) -> CGFloat {
        var y = start
        y += label("每種一列，點「看是誰」打開。📌 是你手動給的（自動分配不會拿走或換掉）；「保留」是你收回倉庫的（不會自動發出去）。", size: 11, color: .secondaryLabelColor, in: holder, y: y).frame.height + 8
        let breeds = colony.breeds
        var any = false
        for slot in GearSlot.allCases {
            let worn = (colony.ants.filter { !$0.isDying } + colony.awayResidents.map(\.ant)).compactMap { ant in ant.item(in: slot).map { (ant, $0) } }
            let stock = colony.armory.enumerated().filter { $0.element.gear?.slot == slot }
            guard !worn.isEmpty || !stock.isEmpty else { continue }
            any = true
            y += label("\(slot.label)（\(worn.count + stock.count)）", size: 14, bold: true, in: holder, y: y).frame.height + 6
            // one line for each kind, the best first; opened, who has each piece
            let kinds = Set(worn.map(\.1.id) + stock.map(\.element.id)).sorted { (Gears.by(id: $0)?.power ?? 0) > (Gears.by(id: $1)?.power ?? 0) }
            for id in kinds {
                let mineWorn = worn.filter { $0.1.id == id }.sorted { $0.1.fraction < $1.1.fraction }
                let mineStock = stock.filter { $0.element.id == id }
                let name = Gears.by(id: id)?.name ?? id
                let shift = icon(id, in: holder, y: y + 3, points: 22)
                let worst = (mineWorn.map(\.1.fraction) + mineStock.map(\.element.fraction)).min() ?? 1
                label("\(name) ×\(mineWorn.count + mineStock.count) — 穿著 \(mineWorn.count)・倉庫 \(mineStock.count)" + (worst < 0.75 ? "　（最舊 \(Int(worst * 100))%）" : ""),
                      bold: true, in: holder, x: margin + shift, y: y + 6, width: inner - 120 - shift)
                let isOpen = opened.contains(id)
                _ = button(isOpen ? "收起" : "看是誰", in: holder, x: margin + inner - 110, y: y, width: 110) { [weak self] _ in
                    guard let self else { return }
                    if isOpen { self.opened.remove(id) } else { self.opened.insert(id) }
                    self.refresh()
                }
                y += 32
                guard isOpen else { continue }
                for (index, item) in mineStock {
                    label("倉庫 \(Int(item.fraction * 100))%" + (item.held ? "　保留" : ""), color: item.held ? .systemOrange : .labelColor, in: holder, x: margin + 30, y: y + 6, width: inner - 250)
                    _ = button("給…", in: holder, x: margin + inner - 212, y: y, width: 96) { [weak self] sender in
                        guard let self, let gear = item.gear else { return }
                        let menu = GearMenus.residents(colony: self.colony, slot: gear.slot, first: nil) { ant in
                            if let why = self.colony.equip(stock: index, on: ant.id) { self.lastMessage = why } else if !self.colony.followsBooks { self.lastMessage = "\(name)交給\(ant.name)。" }
                            self.refresh()
                        }
                        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.height + 2), in: sender)
                    }
                    _ = button(item.held ? "交給自動" : "保留", in: holder, x: margin + inner - 110, y: y, width: 110) { [weak self] _ in
                        self?.colony.hold(stock: index, !item.held)
                        self?.refresh()
                    }
                    y += 30
                }
                for (ant, item) in mineWorn {
                    let breed = breeds[min(ant.breedIndex, breeds.count - 1)].name
                    let place = colony.placeLabel(of: ant.id).map { "・\($0)" } ?? ""
                    label("\(item.pinned ? "📌 " : "")\(Int(item.fraction * 100))% — \(ant.name)（\(breed)\(place)）", in: holder, x: margin + 30, y: y + 6, width: inner - 150)
                    _ = button("收回倉庫", in: holder, x: margin + inner - 110, y: y, width: 110) { [weak self] _ in
                        self?.colony.unequip(antID: ant.id, slot: slot)
                        self?.lastMessage = "\(name)收回倉庫了（保留）。"
                        self?.refresh()
                    }
                    y += 30
                }
                y += 4
            }
            y += 6
        }
        if !any { y += label("還沒有任何裝備，去「製作」做一件吧。", color: .secondaryLabelColor, in: holder, y: y).frame.height }
        return y
    }

    // MARK: 修理

    private func layoutRepairs(in holder: NSView, y start: CGFloat) -> CGFloat {
        var y = start
        y += label("耐久低於 75% 的裝備，花三分之一的材料就能修好（最舊的在最上面）。", size: 11, color: .secondaryLabelColor, in: holder, y: y).frame.height + 8
        let jobs = colony.repairJobs()
        if jobs.isEmpty { y += label("沒有要修的。", color: .secondaryLabelColor, in: holder, y: y).frame.height }
        let mendable = jobs.filter { colony.canAffordRepair($0.gear) }.count
        if !jobs.isEmpty {
            _ = button(mendable == jobs.count ? "全部修理（\(jobs.count) 件）" : "修材料夠的（\(mendable)/\(jobs.count) 件）", enabled: mendable > 0, in: holder, x: margin, y: y, width: 200) { [weak self] _ in
                self?.repairAll()
            }
            y += 38
        }
        for job in jobs.prefix(40) {
            let gear = job.gear
            let affordable = colony.canAffordRepair(gear)
            let shift = icon(gear.id, in: holder, y: y + 2, points: 30)
            label("\(gear.name)　\(job.owner)　耐久 \(Int(job.item.fraction * 100))%", bold: true, in: holder, x: margin + shift, y: y, width: inner - 110 - shift)
            let cost = NSTextField(labelWithAttributedString: costText(Colony.repairCost(gear)))
            cost.frame = NSRect(x: margin + shift, y: y + 17, width: inner - 110 - shift, height: 16)
            holder.addSubview(cost)
            _ = button(affordable ? "修理" : "材料不足", enabled: affordable, in: holder, x: margin + inner - 96, y: y + 3) { [weak self] _ in
                guard let self else { return }
                self.lastMessage = self.colony.repair(job) ? (self.colony.followsBooks ? "修\(gear.name)中…" : "修好了 \(gear.name)（\(job.owner)）。") : "材料不夠。"
                self.refresh()
            }
            y += 40
        }
        if jobs.count > 40 { y += label("…還有 \(jobs.count - 40) 件", color: .secondaryLabelColor, in: holder, y: y).frame.height }
        return y
    }

    // MARK: Controls

    @objc private func tabChanged(_ sender: NSSegmentedControl) {
        tab = visibleTabs.indices.contains(sender.selectedSegment) ? visibleTabs[sender.selectedSegment] : .make
        lastMessage = ""
        scroll.contentView.scroll(to: .zero)
        refresh()
    }

    @objc private func slotChanged(_ sender: NSSegmentedControl) {
        slotFilter = sender.selectedSegment == 0 ? nil : GearSlot.allCases[sender.selectedSegment - 1]
        refresh()
    }

    @objc private func onlyChanged(_ sender: NSButton) {
        onlyAffordable = sender.state == .on
        refresh()
    }

    @objc private func farChanged(_ sender: NSButton) {
        colony.setAutoGearFar(sender.state == .on)
        lastMessage = sender.state == .on ? "自動分配也會發給每一塊領地的居民。" : "自動分配只發給營地和城鎮的居民。"
        refresh()
    }

    @objc private func autoChanged(_ sender: NSButton) {
        colony.setAutoGear(sender.state == .on)
        lastMessage = sender.state == .on ? "倉庫的裝備會自動發給最需要的居民（📌 和保留的不會動）。" : "倉庫的裝備不再自動分配，要自己發。"
        refresh()
    }
}

/// Menus of goblins to hand a piece to (the workshop and the roster use the same one).
enum GearMenus {
    /// A blank the size of an icon, so the names line up whether or not one wears something there.
    static let empty = NSImage(size: NSSize(width: 16, height: 16))

    /// Goblins at home (not the young), strongest first: 「名字（品種）力 x 血 y　現在：…」; the 25 strongest, the rest under 更多….
    /// Signed in, those away from home who can be handed gear follow, one submenu per place (the towns first).
    static func residents(colony: Colony, slot: GearSlot, first: (String, () -> Void)?, pick: @escaping (Ant) -> Void) -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false
        if let first {
            menu.addItem(ClosureMenuItem(title: first.0, handler: first.1))
            menu.addItem(.separator())
        }
        let breeds = colony.breeds
        let strongest = { (a: Ant, b: Ant) in (a.might + a.maxHealth) > (b.might + b.maxHealth) }
        let ants = colony.ants.filter { !$0.isDying && !$0.isDeparting && !$0.isChild }.sorted(by: strongest)
        func item(_ ant: Ant) -> NSMenuItem {
            let breed = breeds[min(ant.breedIndex, breeds.count - 1)].name
            let now = ant.item(in: slot).map { "\($0.pinned ? "📌" : "")\($0.gear?.name ?? $0.id) \(Int($0.fraction * 100))%" } ?? "空"
            let entry = ClosureMenuItem(title: String(format: "%@（%@）力 %.1f 血 %.0f　現在：%@", ant.name, breed, ant.might, ant.maxHealth, now)) { pick(ant) }
            entry.image = ant.item(in: slot).flatMap { GearIcons.image($0.id, points: 16) } ?? GearMenus.empty
            return entry
        }
        func note(_ title: String) -> NSMenuItem {
            let line = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            line.isEnabled = false
            return line
        }
        /// The 25 strongest of `list`, the rest under 更多….
        func add(_ list: [Ant], to menu: NSMenu) {
            for ant in list.prefix(25) { menu.addItem(item(ant)) }
            if list.count > 25 {
                let more = NSMenuItem(title: "更多…（\(list.count - 25)）", action: nil, keyEquivalent: "")
                let sub = NSMenu()
                for ant in list.dropFirst(25) { sub.addItem(item(ant)) }
                more.submenu = sub
                menu.addItem(more)
            }
        }
        let away = Dictionary(grouping: colony.awayResidents, by: \.label)
        if !away.isEmpty { menu.addItem(note("主營（\(ants.count)）")) }
        if ants.isEmpty { menu.addItem(note("（沒有可以給的居民）")) }
        add(ants, to: menu)
        guard !away.isEmpty else { return menu }
        menu.addItem(.separator())
        // towns first, then the held cells in the order they were taken, then those guarding a friend's
        let order = { (label: String) -> (Int, Int) in
            let kind = label.hasPrefix("城鎮") ? 0 : label.hasPrefix("領地") ? 1 : 2
            return (kind, Int(label.split(separator: " ").last ?? "") ?? 0)
        }
        for label in away.keys.sorted(by: { order($0) < order($1) }) {
            let list = away[label]!.map(\.ant).sorted(by: strongest)
            let place = NSMenuItem(title: "\(label)（\(list.count)）", action: nil, keyEquivalent: "")
            let sub = NSMenu()
            sub.autoenablesItems = false
            add(list, to: sub)
            place.submenu = sub
            menu.addItem(place)
        }
        return menu
    }
}

/// A view whose origin is at the top, so the list grows downward inside the scroll view.
private final class FlippedView: NSView {
    override var isFlipped: Bool { true }
}

/// A push button that runs a closure.
final class ClosureButton: NSButton {
    private let action_: () -> Void

    init(title: String, action: @escaping () -> Void) {
        action_ = action
        super.init(frame: .zero)
        self.title = title
        target = self
        self.action = #selector(fire)
    }

    required init?(coder: NSCoder) { fatalError() }

    @objc private func fire() { action_() }
}
