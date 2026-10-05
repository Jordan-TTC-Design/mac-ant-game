import AppKit

/// The workshop: three pages. 製作 turns materials into gear (for whoever needs it most, or for a goblin you pick); 現有裝備
/// lists every piece there is, worn or in the stock, to take off, hand over or hold; 修理 mends worn pieces. A switch turns
/// the handing out of the stock on or off (what you placed by hand is never moved either way).
final class WorkshopWindow: NSObject, MainPane {
    enum Tab: Int { case make, pieces, repair }

    let paneView: NSView
    private let colony: Colony
    private let scroll = NSScrollView()
    private var lastMessage = ""
    private var tab = Tab.make
    /// 製作: which slot (nil: all), and whether to show only what can be made now.
    private var slotFilter: GearSlot?
    private var onlyAffordable = false
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

        let tabs = NSSegmentedControl(labels: ["製作", "現有裝備（\(pieceCount)）", "修理（\(colony.repairJobs().count)）"], trackingMode: .selectOne,
                                      target: self, action: #selector(tabChanged(_:)))
        tabs.selectedSegment = tab.rawValue
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
        y += auto.frame.height + 8

        if !lastMessage.isEmpty {
            y += label(lastMessage, bold: true, color: .systemGreen, in: holder, y: y).frame.height + 8
        }

        switch tab {
        case .make: y = layoutMake(in: holder, y: y)
        case .pieces: y = layoutPieces(in: holder, y: y)
        case .repair: y = layoutRepairs(in: holder, y: y)
        }
        holder.frame.size.height = y + 16
        scroll.documentView = holder
        scroll.contentView.scroll(to: NSPoint(x: 0, y: min(keepScroll.y, max(0, holder.frame.height - scroll.contentView.bounds.height))))
    }

    private var pieceCount: Int { colony.armory.count + colony.ants.reduce(0) { $0 + $1.gear.count } }

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

    /// One recipe: name, tier, effect, a line about it, how many there are, the cost, and 製作…. Returns its height.
    private func makeRow(_ gear: Gear, in holder: NSView, y: CGFloat) -> CGFloat {
        let unopened = Gears.unopened.contains(gear.id)
        let affordable = !unopened && colony.canAfford(gear)
        let width = inner - 110
        var top = y
        let title = NSMutableAttributedString(string: gear.name, attributes: [.font: NSFont.systemFont(ofSize: 13, weight: .semibold), .foregroundColor: NSColor.labelColor])
        if let tier = WorkshopWindow.tier(of: gear) {
            title.append(NSAttributedString(string: "  \(tier)", attributes: [.font: NSFont.systemFont(ofSize: 11, weight: .bold),
                                                                               .foregroundColor: tier == "未開放" ? NSColor.systemGray : NSColor.systemBrown]))
        }
        title.append(NSAttributedString(string: "　\(gear.effectText)", attributes: [.font: NSFont.systemFont(ofSize: 12), .foregroundColor: NSColor.labelColor]))
        let t = NSTextField(labelWithAttributedString: title)
        t.lineBreakMode = .byTruncatingTail
        t.frame = NSRect(x: margin, y: top, width: width, height: 17)
        holder.addSubview(t)
        top += 18
        top += label(gear.blurb + "　（穿著 \(colony.wearers(of: gear))・倉庫 \(colony.inStock(of: gear))）", size: 11, color: .secondaryLabelColor, in: holder, y: top, width: width).frame.height + 2
        let cost = NSTextField(labelWithAttributedString: costText(gear.cost))
        cost.frame = NSRect(x: margin, y: top, width: width, height: 16)
        holder.addSubview(cost)
        top += 16
        let b = button(unopened ? "未開放" : affordable ? "製作…" : "材料不足", enabled: affordable, in: holder, x: margin + inner - 96, y: y + (top - y) / 2 - 14) { [weak self] sender in
            self?.chooseOwner(for: gear, from: sender)
        }
        if unopened { b.toolTip = "材料只在大世界還沒開放的地方（或世界魔王）才有" }
        return top - y
    }

    /// 製作…: for whoever needs it most (or into the stock), or for a goblin picked from the list.
    private func chooseOwner(for gear: Gear, from sender: NSButton) {
        let first: (String, () -> Void)
        if let pick = colony.autoPick(for: gear) {
            first = ("自動（給最需要的：\(pick.name)）", { [weak self] in self?.make(gear, for: nil) })
        } else if colony.autoGear {
            first = ("自動（現在沒有人需要，先不做）", {})
        } else {
            first = ("放進倉庫", { [weak self] in self?.make(gear, for: nil) })
        }
        let menu = GearMenus.residents(colony: colony, slot: gear.slot, first: first) { [weak self] ant in self?.make(gear, for: ant.id) }
        menu.items.first?.isEnabled = !colony.autoGear || colony.autoPick(for: gear) != nil
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.height + 2), in: sender)
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
        y += label("📌 是你手動給的（自動分配不會拿走或換掉）；「保留」是你收回倉庫的（不會自動發出去）。", size: 11, color: .secondaryLabelColor, in: holder, y: y).frame.height + 8
        let breeds = colony.breeds
        var any = false
        for slot in GearSlot.allCases {
            let worn = colony.ants.filter { !$0.isDying }.compactMap { ant in ant.item(in: slot).map { (ant, $0) } }
                .sorted { ($0.1.gear?.power ?? 0) > ($1.1.gear?.power ?? 0) }
            let stock = colony.armory.enumerated().filter { $0.element.gear?.slot == slot }.sorted { ($0.element.gear?.power ?? 0) > ($1.element.gear?.power ?? 0) }
            guard !worn.isEmpty || !stock.isEmpty else { continue }
            any = true
            y += label("\(slot.label)（\(worn.count + stock.count)）", size: 14, bold: true, in: holder, y: y).frame.height + 6
            for (index, item) in stock {
                let name = item.gear?.name ?? item.id
                label("\(name) \(Int(item.fraction * 100))% — 倉庫" + (item.held ? "　保留" : ""), bold: true, color: item.held ? .systemOrange : .labelColor,
                      in: holder, y: y + 6, width: inner - 220)
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
                y += 32
            }
            for (ant, item) in worn {
                let breed = breeds[min(ant.breedIndex, breeds.count - 1)].name
                label("\(item.pinned ? "📌 " : "")\(item.gear?.name ?? item.id) \(Int(item.fraction * 100))% — \(ant.name)（\(breed)）",
                      in: holder, y: y + 6, width: inner - 120)
                _ = button("收回倉庫", in: holder, x: margin + inner - 110, y: y, width: 110) { [weak self] _ in
                    self?.colony.unequip(antID: ant.id, slot: slot)
                    self?.lastMessage = "\(item.gear?.name ?? item.id)收回倉庫了（保留）。"
                    self?.refresh()
                }
                y += 32
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
        for job in jobs.prefix(40) {
            let gear = job.gear
            let affordable = colony.canAffordRepair(gear)
            label("\(gear.name)　\(job.owner)　耐久 \(Int(job.item.fraction * 100))%", bold: true, in: holder, y: y, width: inner - 110)
            let cost = NSTextField(labelWithAttributedString: costText(Colony.repairCost(gear)))
            cost.frame = NSRect(x: margin, y: y + 17, width: inner - 110, height: 16)
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
        tab = Tab(rawValue: sender.selectedSegment) ?? .make
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

    @objc private func autoChanged(_ sender: NSButton) {
        colony.setAutoGear(sender.state == .on)
        lastMessage = sender.state == .on ? "倉庫的裝備會自動發給最需要的居民（📌 和保留的不會動）。" : "倉庫的裝備不再自動分配，要自己發。"
        refresh()
    }
}

/// Menus of goblins to hand a piece to (the workshop and the roster use the same one).
enum GearMenus {
    /// Goblins at home (not the young), strongest first: 「名字（品種）力 x 血 y　現在：…」; the 25 strongest, the rest under 更多….
    static func residents(colony: Colony, slot: GearSlot, first: (String, () -> Void)?, pick: @escaping (Ant) -> Void) -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false
        if let first {
            menu.addItem(ClosureMenuItem(title: first.0, handler: first.1))
            menu.addItem(.separator())
        }
        let breeds = colony.breeds
        let ants = colony.ants.filter { !$0.isDying && !$0.isDeparting && !$0.isChild }.sorted { ($0.might + $0.maxHealth) > ($1.might + $1.maxHealth) }
        func item(_ ant: Ant) -> NSMenuItem {
            let breed = breeds[min(ant.breedIndex, breeds.count - 1)].name
            let now = ant.item(in: slot).map { "\($0.pinned ? "📌" : "")\($0.gear?.name ?? $0.id) \(Int($0.fraction * 100))%" } ?? "空"
            return ClosureMenuItem(title: String(format: "%@（%@）力 %.1f 血 %.0f　現在：%@", ant.name, breed, ant.might, ant.maxHealth, now)) { pick(ant) }
        }
        if ants.isEmpty {
            let none = NSMenuItem(title: "（沒有可以給的居民）", action: nil, keyEquivalent: "")
            none.isEnabled = false
            menu.addItem(none)
        }
        for ant in ants.prefix(25) { menu.addItem(item(ant)) }
        if ants.count > 25 {
            let more = NSMenuItem(title: "更多…（\(ants.count - 25)）", action: nil, keyEquivalent: "")
            let sub = NSMenu()
            for ant in ants.dropFirst(25) { sub.addItem(item(ant)) }
            more.submenu = sub
            menu.addItem(more)
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
