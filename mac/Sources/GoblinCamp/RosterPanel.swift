import AppKit

/// A tall panel docked at the right edge of the screen that lists everyone in the camp. Picking a row rings that
/// goblin on screen, so you can find it among the others.
final class RosterPanel: NSObject, NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate {
    private let colony: Colony
    private let panel: NSPanel
    private let summary = NSTextField(wrappingLabelWithString: "")
    private let detail = NSTextField(wrappingLabelWithString: "")
    private let table = NSTableView()
    /// The picked goblin's gear, one row per slot: what it wears, and the stock's pieces for that slot to change to.
    private let gearBox = NSStackView()
    /// What the gear rows were built from (rebuilt only when it changes, so an open menu is not pulled away every second).
    private var gearSignature = ""
    private var rows: [Ant] = []
    private var timer: Timer?

    /// Called when the selection changes so the overlay can redraw the ring.
    var onSelectionChanged: (() -> Void)?

    var isVisible: Bool { panel.isVisible }

    init(colony: Colony) {
        self.colony = colony
        panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 360, height: 760),
                        styleMask: [.titled, .closable, .resizable, .utilityWindow, .nonactivatingPanel],
                        backing: .buffered, defer: false)
        super.init()
        panel.title = "\(Characters.current.noun)名冊"
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        // above the transparent overlay windows, which sit at the status-bar level
        panel.level = Levels.dialog
        panel.collectionBehavior = [.canJoinAllSpaces]
        panel.minSize = NSSize(width: 340, height: 480)
        buildContent()
        NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: panel, queue: .main) { [weak self] _ in
            self?.stopUpdating()
        }
    }

    /// Test aids.
    var windowNumber: Int { panel.windowNumber }
    var contentViewForTesting: NSView? { panel.contentView }
    func useLightAppearanceForTesting() { panel.appearance = NSAppearance(named: .aqua) }

    func select(row: Int) {
        guard rows.indices.contains(row) else { return }
        table.selectRowIndexes([row], byExtendingSelection: false)
    }

    // MARK: Show / hide

    func toggle() {
        if panel.isVisible { hide() } else { show() }
    }

    func show() {
        panel.title = "\(Characters.current.noun)名冊"
        if let screen = NSScreen.main {
            let area = screen.visibleFrame
            let width: CGFloat = 360
            panel.setFrame(NSRect(x: area.maxX - width - 8, y: area.minY + 8, width: width, height: area.height - 16), display: false)
        }
        reload()
        panel.orderFrontRegardless()
        timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in self?.reload() }
        RunLoop.main.add(timer!, forMode: .common)
    }

    func hide() {
        panel.orderOut(nil)
        stopUpdating()
    }

    private func stopUpdating() {
        timer?.invalidate()
        timer = nil
        if colony.selectedAntID != nil {
            colony.selectedAntID = nil
            onSelectionChanged?()
        }
    }

    // MARK: Layout

    private func buildContent() {
        let content = NSView()
        panel.contentView = content

        summary.font = .systemFont(ofSize: 12)
        summary.translatesAutoresizingMaskIntoConstraints = false
        detail.font = .systemFont(ofSize: 12)
        detail.textColor = .secondaryLabelColor
        detail.translatesAutoresizingMaskIntoConstraints = false

        func column(_ id: String, _ title: String, _ width: CGFloat) -> NSTableColumn {
            let c = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(id))
            c.title = title
            c.width = width
            c.minWidth = 30
            return c
        }
        table.addTableColumn(column("id", "#", 30))
        table.addTableColumn(column("name", "名字", 92))
        table.addTableColumn(column("breed", "品種", 44))
        table.addTableColumn(column("state", "狀態", 66))
        table.addTableColumn(column("gear", "裝備", 40))
        table.addTableColumn(column("life", "壽命", 58))
        table.dataSource = self
        table.delegate = self
        table.rowHeight = 20
        table.allowsMultipleSelection = false
        table.usesAlternatingRowBackgroundColors = true
        table.headerView = NSTableHeaderView()
        table.style = .plain

        let scroll = NSScrollView()
        scroll.documentView = table
        scroll.hasVerticalScroller = true
        scroll.borderType = .noBorder
        scroll.translatesAutoresizingMaskIntoConstraints = false

        gearBox.orientation = .vertical
        gearBox.alignment = .leading
        gearBox.spacing = 3
        gearBox.translatesAutoresizingMaskIntoConstraints = false

        content.addSubview(summary)
        content.addSubview(scroll)
        content.addSubview(detail)
        content.addSubview(gearBox)
        NSLayoutConstraint.activate([
            summary.topAnchor.constraint(equalTo: content.topAnchor, constant: 8),
            summary.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 10),
            summary.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -10),
            scroll.topAnchor.constraint(equalTo: summary.bottomAnchor, constant: 8),
            scroll.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            detail.topAnchor.constraint(equalTo: scroll.bottomAnchor, constant: 8),
            detail.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 10),
            detail.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -10),
            detail.heightAnchor.constraint(greaterThanOrEqualToConstant: 96),
            gearBox.topAnchor.constraint(equalTo: detail.bottomAnchor, constant: 6),
            gearBox.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 10),
            gearBox.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -10),
            gearBox.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -10),
        ])
    }

    // MARK: Content

    private var breeds: [Breed] { Characters.current.breeds }

    private func breedName(of ant: Ant) -> String {
        breeds[min(ant.breedIndex, breeds.count - 1)].name
    }

    /// Rare breeds first, then the oldest.
    private func sortedRows() -> [Ant] {
        colony.ants.sorted { a, b in
            if a.breedIndex != b.breedIndex { return a.breedIndex > b.breedIndex }
            return a.age > b.age
        }
    }

    private func reload() {
        rows = sortedRows()
        let counts = Dictionary(grouping: rows, by: \.breedIndex)
        let byBreed = breeds.enumerated().reversed().compactMap { i, breed -> String? in
            guard let n = counts[i]?.count else { return nil }
            return "\(breed.name) \(n)"
        }.joined(separator: "　")
        let noun = Characters.current.noun
        summary.stringValue = "現有 \(rows.count) 隻\(noun)" + (byBreed.isEmpty ? "" : "\n\(byBreed)")
            + "\n累積搬回食物 \(colony.foodDelivered) 份　已老死 \(colony.deaths - colony.slain) 隻　打獵犧牲 \(colony.slain) 隻"
            + "\n\(colony.romanceSummary)"

        table.reloadData()
        if let id = colony.selectedAntID, let row = rows.firstIndex(where: { $0.id == id }) {
            table.selectRowIndexes([row], byExtendingSelection: false)
        }
        updateDetail()
    }

    /// Reloads when the panel is showing (after a gear command was answered).
    func refreshIfVisible() {
        if panel.isVisible { reload() }
    }

    private func updateDetail() {
        guard let id = colony.selectedAntID, let ant = colony.ants.first(where: { $0.id == id }) else {
            detail.stringValue = "點一隻，畫面上會圈出牠，也可以在下面幫牠換裝備。"
            updateGear(nil)
            return
        }
        defer { updateGear(ant) }
        let breed = breeds[min(ant.breedIndex, breeds.count - 1)]
        let t = ant.traits
        let left = max(0, t.lifespan - ant.age)
        var text = "\(ant.name)（#\(ant.id)）\(ant.female ? "♀" : "♂") \(breed.name)　\(breed.blurb)\n"
        if !ant.parents.isEmpty { text += "父母：\(ant.parents)\n" }
        if colony.romance.partnerID == ant.id, colony.romance.stage != .single {
            text += (colony.romance.stage == .married ? "配偶：" : colony.romance.stage == .dating ? "交往中：" : "正在追求：") + (colony.princessName.isEmpty ? "公主" : colony.princessName) + "\n"
        }
        text += "年齡 \(IntervalFormat.text(ant.age.rounded()))，還剩約 \(IntervalFormat.text(left.rounded()))\n"
        text += String(format: "速度 ×%.2f　感知 ×%.2f　休息 ×%.2f\n", t.speed, t.sense, t.rest)
        text += "一次搬 \(t.carry) 份　叫同伴 +\(t.recruit)" + (ant.lifeFraction > Ant.elderStart ? "　（年老，走得慢）" : "")
        text += String(format: "\n出手 %.1f　血量 %.0f", ant.might, ant.maxHealth)
        if let activity = ant.activity { text += "\n現在：\(activity.label)" }
        detail.stringValue = text
    }

    // MARK: Gear

    /// One row per slot for the picked goblin: 「武器」 and a pop-up with what it wears (📌: put on by hand), the stock's pieces
    /// that fit there (保留: held), and 「脫下（收回倉庫）」.
    private func updateGear(_ ant: Ant?) {
        let signature: String = {
            guard let ant else { return "" }
            let worn = GearSlot.allCases.map { s in ant.item(in: s).map { "\($0.id)\(Int($0.fraction * 100))\($0.pinned)" } ?? "-" }
            let stock = colony.armory.map { "\($0.id)\(Int($0.fraction * 100))\($0.held)" }
            return "\(ant.id)|\(ant.isChild)|\(worn)|\(stock)"
        }()
        guard signature != gearSignature else { return }
        gearSignature = signature
        gearBox.arrangedSubviews.forEach { $0.removeFromSuperview() }
        guard let ant else { return }
        let title = NSTextField(labelWithString: ant.isChild ? "裝備（小孩還不能穿）" : "裝備（選一件換上；📌 是你手動給的）")
        title.font = .systemFont(ofSize: 12, weight: .semibold)
        gearBox.addArrangedSubview(title)
        guard !ant.isChild else { return }
        for slot in GearSlot.allCases {
            let label = NSTextField(labelWithString: slot.label)
            label.font = .systemFont(ofSize: 12)
            label.widthAnchor.constraint(equalToConstant: 40).isActive = true
            let popup = NSPopUpButton(frame: .zero, pullsDown: false)
            popup.font = .systemFont(ofSize: 12)
            popup.menu?.autoenablesItems = false
            let current = ant.item(in: slot)
            popup.addItem(withTitle: current.map { "\($0.pinned ? "📌 " : "")\($0.gear?.name ?? $0.id) \(Int($0.fraction * 100))%" } ?? "（空）")
            let pieces = colony.armory.enumerated().filter { $0.element.gear?.slot == slot }.sorted { ($0.element.gear?.power ?? 0) > ($1.element.gear?.power ?? 0) }
            if !pieces.isEmpty {
                popup.menu?.addItem(.separator())
                for (index, item) in pieces {
                    let gear = item.gear!
                    let entry = ClosureMenuItem(title: "換上 \(gear.name) \(Int(item.fraction * 100))%（\(gear.effectText)）" + (item.held ? "　保留" : "")) { [weak self] in
                        guard let self else { return }
                        if let why = self.colony.equip(stock: index, on: ant.id) { self.detail.stringValue = why }
                        self.gearSignature = ""
                        self.reload()
                    }
                    if colony.cannotWear(gear, on: ant) != nil { entry.isEnabled = false; entry.toolTip = colony.cannotWear(gear, on: ant) }
                    popup.menu?.addItem(entry)
                }
            }
            if current != nil {
                popup.menu?.addItem(.separator())
                popup.menu?.addItem(ClosureMenuItem(title: "脫下（收回倉庫）") { [weak self] in
                    self?.colony.unequip(antID: ant.id, slot: slot)
                    self?.gearSignature = ""
                    self?.reload()
                })
            }
            if pieces.isEmpty && current == nil { popup.isEnabled = false }
            popup.selectItem(at: 0)
            let row = NSStackView(views: [label, popup])
            row.spacing = 6
            popup.widthAnchor.constraint(equalToConstant: 280).isActive = true
            gearBox.addArrangedSubview(row)
        }
    }

    // MARK: Table

    func numberOfRows(in tableView: NSTableView) -> Int { rows.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let column = tableColumn, rows.indices.contains(row) else { return nil }
        let ant = rows[row], t = ant.traits
        if column.identifier.rawValue == "life" {
            let id = NSUserInterfaceItemIdentifier("lifeCell")
            let indicator = (tableView.makeView(withIdentifier: id, owner: self) as? NSLevelIndicator) ?? {
                let i = NSLevelIndicator()
                i.identifier = id
                i.levelIndicatorStyle = .continuousCapacity
                i.minValue = 0
                i.maxValue = 1
                // the bar shows life LEFT, so it is the low end that is worrying (yellow, then red)
                i.warningValue = 0.25
                i.criticalValue = 0.1
                return i
            }()
            indicator.doubleValue = 1 - ant.lifeFraction // full bar = a whole life ahead
            indicator.toolTip = "已活 \(IntervalFormat.text(ant.age.rounded()))／壽命約 \(IntervalFormat.text(t.lifespan.rounded()))"
            return indicator
        }
        let text: String
        switch column.identifier.rawValue {
        case "id": text = "\(ant.id)"
        case "name": text = ant.name
        case "breed": text = breedName(of: ant)
        case "state": text = ant.stateLabel
        default: text = ant.isChild ? "-" : "\(ant.gear.count)/\(GearSlot.allCases.count)"
        }
        let id = NSUserInterfaceItemIdentifier("textCell")
        let field = (tableView.makeView(withIdentifier: id, owner: self) as? NSTextField) ?? {
            let f = NSTextField(labelWithString: "")
            f.identifier = id
            f.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
            f.lineBreakMode = .byTruncatingTail
            return f
        }()
        field.stringValue = text
        // the name can be typed over (double-click it)
        field.isEditable = column.identifier.rawValue == "name"
        field.delegate = self
        field.tag = ant.id
        field.font = column.identifier.rawValue == "name" ? .systemFont(ofSize: 12) : .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        return field
    }

    /// A name was typed over in the table.
    func controlTextDidEndEditing(_ obj: Notification) {
        guard let field = obj.object as? NSTextField, field.isEditable else { return }
        colony.rename(antID: field.tag, to: field.stringValue)
        reload()
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        let row = table.selectedRow
        colony.selectedAntID = rows.indices.contains(row) ? rows[row].id : nil
        updateDetail()
        onSelectionChanged?()
    }
}
