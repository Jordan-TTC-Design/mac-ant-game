import AppKit

/// A tall panel docked at the right edge of the screen that lists everyone in the camp. Picking a row rings that
/// goblin on screen, so you can find it among the others.
final class RosterPanel: NSObject, NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate {
    private let colony: Colony
    private let panel: NSPanel
    private let summary = NSTextField(wrappingLabelWithString: "")
    private let detail = NSTextField(wrappingLabelWithString: "")
    private let table = NSTableView()
    private var rows: [Ant] = []
    private var timer: Timer?

    /// Called when the selection changes so the overlay can redraw the ring.
    var onSelectionChanged: (() -> Void)?

    var isVisible: Bool { panel.isVisible }

    init(colony: Colony) {
        self.colony = colony
        panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 330, height: 700),
                        styleMask: [.titled, .closable, .resizable, .utilityWindow, .nonactivatingPanel],
                        backing: .buffered, defer: false)
        super.init()
        panel.title = "\(Characters.current.noun)名冊"
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        // above the transparent overlay windows, which sit at the status-bar level
        panel.level = Levels.panel
        panel.collectionBehavior = [.canJoinAllSpaces]
        panel.minSize = NSSize(width: 300, height: 320)
        buildContent()
        NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: panel, queue: .main) { [weak self] _ in
            self?.stopUpdating()
        }
    }

    /// Test aids.
    var windowNumber: Int { panel.windowNumber }

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
            let width: CGFloat = 330
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
        table.addTableColumn(column("id", "#", 34))
        table.addTableColumn(column("name", "名字", 104))
        table.addTableColumn(column("breed", "品種", 52))
        table.addTableColumn(column("life", "壽命", 70))
        table.addTableColumn(column("stats", "速度 / 感知 / 搬運", 112))
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

        content.addSubview(summary)
        content.addSubview(scroll)
        content.addSubview(detail)
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
            detail.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -10),
            detail.heightAnchor.constraint(greaterThanOrEqualToConstant: 96),
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

        table.reloadData()
        if let id = colony.selectedAntID, let row = rows.firstIndex(where: { $0.id == id }) {
            table.selectRowIndexes([row], byExtendingSelection: false)
        }
        updateDetail()
    }

    private func updateDetail() {
        guard let id = colony.selectedAntID, let ant = colony.ants.first(where: { $0.id == id }) else {
            detail.stringValue = "點一隻，畫面上會圈出牠。"
            return
        }
        let breed = breeds[min(ant.breedIndex, breeds.count - 1)]
        let t = ant.traits
        let left = max(0, t.lifespan - ant.age)
        var text = "\(ant.name)（#\(ant.id)）\(breed.name)　\(breed.blurb)\n"
        text += "年齡 \(IntervalFormat.text(ant.age.rounded()))，還剩約 \(IntervalFormat.text(left.rounded()))\n"
        text += String(format: "速度 ×%.2f　感知 ×%.2f　休息 ×%.2f\n", t.speed, t.sense, t.rest)
        text += "一次搬 \(t.carry) 份　叫同伴 +\(t.recruit)" + (ant.lifeFraction > Ant.elderStart ? "　（年老，走得慢）" : "")
        var worn: [String] = []
        for slot in GearSlot.allCases {
            if let item = ant.item(in: slot), let gear = item.gear { worn.append("\(slot.label) \(gear.name) \(Int(item.fraction * 100))%") }
        }
        text += "\n" + (worn.isEmpty ? "裝備：（沒有）" : "裝備：" + worn.joined(separator: "　"))
        text += String(format: "\n出手 %.1f　血量 %.0f", ant.might, ant.maxHealth)
        if let activity = ant.activity { text += "\n現在：\(activity.label)" }
        detail.stringValue = text
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
        default: text = String(format: "%.2f / %.2f / %d", t.speed, t.sense, t.carry)
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
