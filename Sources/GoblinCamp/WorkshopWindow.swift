import AppKit

/// The workshop: turns the materials the goblins bring home into weapons and gear, and hands each piece to the goblin who gains most.
final class WorkshopWindow: NSObject {
    private let window: NSWindow
    private let colony: Colony
    private let scroll = NSScrollView()
    private var lastMessage = ""

    private static let width: CGFloat = 560

    init(colony: Colony) {
        self.colony = colony
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: WorkshopWindow.width, height: 660), styleMask: [.titled, .closable, .resizable, .miniaturizable],
                          backing: .buffered, defer: false)
        super.init()
        window.title = "工坊"
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: WorkshopWindow.width, height: 360)
        window.maxSize = NSSize(width: WorkshopWindow.width, height: 4000)
        window.center()
        scroll.frame = window.contentView!.bounds
        scroll.autoresizingMask = [.width, .height]
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        window.contentView?.addSubview(scroll)
        refresh()
    }

    var contentViewForTesting: NSView? { window.contentView }

    /// Off-screen drawing for tests uses the light look (in the dark look the text is white on nothing).
    func useLightAppearanceForTesting() { window.appearance = NSAppearance(named: .aqua) }

    func present() {
        refresh()
        window.level = Levels.panel
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    /// Rebuilds the list (after making something, or when the materials changed). Laid out by hand, top to bottom.
    func refresh() {
        let holder = FlippedView(frame: NSRect(x: 0, y: 0, width: WorkshopWindow.width, height: 10))
        var y: CGFloat = 16
        let margin: CGFloat = 20, inner = WorkshopWindow.width - margin * 2

        func label(_ text: String, size: CGFloat = 12, bold: Bool = false, color: NSColor = .labelColor, x: CGFloat = margin, width: CGFloat = inner) -> NSTextField {
            let f = NSTextField(wrappingLabelWithString: text)
            f.font = .systemFont(ofSize: size, weight: bold ? .semibold : .regular)
            f.textColor = color
            f.preferredMaxLayoutWidth = width
            let fit = f.sizeThatFits(NSSize(width: width, height: 1000))
            f.frame = NSRect(x: x, y: y, width: width, height: ceil(fit.height))
            holder.addSubview(f)
            return f
        }

        y += label("用魔獸掉的素材做武器與裝備。做好的東西會自動交給最需要它的哥布林（那個位置最差的、力量或體格最適合的），畫面上會圈出牠。", color: .secondaryLabelColor).frame.height + 10
        let have = colony.materials.filter { $0.value > 0 }.sorted { $0.key < $1.key }
        let stock = have.isEmpty ? "還沒有素材，等魔獸來襲吧。" : "倉庫：" + have.map { "\(Materials.info($0.key)?.name ?? $0.key) ×\($0.value)" }.joined(separator: "　")
        y += label(stock, bold: true).frame.height + 6
        if !colony.armory.isEmpty {
            let spare = colony.armory.sorted { $0.id < $1.id }.map { "\($0.gear?.name ?? $0.id) \(Int($0.fraction * 100))%" }.joined(separator: "　")
            y += label("庫存裝備（歸還的、暫時沒人需要的，百分比是耐久）：" + spare, color: .secondaryLabelColor).frame.height + 6
        }
        y += 8

        for slot in GearSlot.allCases {
            y += label(slot.label, size: 14, bold: true).frame.height + 6
            for gear in Gears.all where gear.slot == slot {
                y += addRow(for: gear, to: holder, y: y, margin: margin, inner: inner) + 8
            }
            y += 6
        }
        if !lastMessage.isEmpty {
            let f = label(lastMessage, bold: true, color: .systemGreen)
            y += f.frame.height
        }
        holder.frame.size.height = y + 16
        scroll.documentView = holder
    }

    /// One recipe: name and effect, a line about it, what it costs (green = have enough), and the button. Returns its height.
    private func addRow(for gear: Gear, to holder: NSView, y: CGFloat, margin: CGFloat, inner: CGFloat) -> CGFloat {
        let affordable = colony.canAfford(gear)
        let textWidth = inner - 110
        func field(_ text: String, size: CGFloat, weight: NSFont.Weight = .regular, color: NSColor = .labelColor, at top: CGFloat) -> NSTextField {
            let f = NSTextField(wrappingLabelWithString: text)
            f.font = .systemFont(ofSize: size, weight: weight)
            f.textColor = color
            f.preferredMaxLayoutWidth = textWidth
            let fit = f.sizeThatFits(NSSize(width: textWidth, height: 1000))
            f.frame = NSRect(x: margin, y: top, width: textWidth, height: ceil(fit.height))
            holder.addSubview(f)
            return f
        }
        var top = y
        top += field("\(gear.name)　\(gear.effectText)", size: 13, weight: .semibold, at: top).frame.height + 1
        top += field(gear.blurb + "　（已有 \(colony.wearers(of: gear)) 隻穿著）", size: 11, color: .secondaryLabelColor, at: top).frame.height + 2

        let cost = NSMutableAttributedString()
        for (i, (id, need)) in gear.cost.enumerated() {
            let owned = colony.materials[id, default: 0]
            if i > 0 { cost.append(NSAttributedString(string: "　")) }
            cost.append(NSAttributedString(string: "\(Materials.info(id)?.name ?? id) \(owned)/\(need)", attributes: [
                .font: NSFont.systemFont(ofSize: 11, weight: .medium),
                .foregroundColor: owned >= need ? NSColor.systemGreen : NSColor.systemRed,
            ]))
        }
        let costLabel = NSTextField(labelWithAttributedString: cost)
        costLabel.frame = NSRect(x: margin, y: top, width: textWidth, height: 16)
        holder.addSubview(costLabel)
        top += 16

        let button = ClosureButton(title: affordable ? "製作" : "材料不足") { [weak self] in self?.make(gear) }
        button.isEnabled = affordable
        button.bezelStyle = .rounded
        button.frame = NSRect(x: margin + inner - 96, y: y + (top - y) / 2 - 14, width: 96, height: 28)
        holder.addSubview(button)
        return top - y
    }

    private func make(_ gear: Gear) {
        switch colony.craft(gear) {
        case .made(let made, let by): lastMessage = "做好了 \(made.name)，交給 \(by)。"
        case .missing: lastMessage = "材料不夠。"
        case .nobodyNeeds: lastMessage = "大家身上這個位置都有一樣好或更好的了，先不做。"
        }
        refresh()
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
