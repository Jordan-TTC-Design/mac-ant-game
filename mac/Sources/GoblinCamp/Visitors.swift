import AppKit
import CampRules

// Special residents and visitors who would like to move in (DESKTOP.md §10.0; the rules are the server's,
// shared/src/camp/visitors.ts). The books say who waits at the gate; the Mac draws them there and sends the answer.

/// A camp command about residents, as the server takes it (shared/src/camp/api.ts `campCommand`).
struct CampOrder: Encodable {
    let kind: String
    var visit: String?
    var replace: Int?
    var resident: Int?
}

struct VisitorError: Error { let message: String }

/// The six specials (shared SPECIAL_RESIDENTS): what each does at home, for the panels.
enum SpecialRoles {
    static let effects: [String: String] = [
        "healer": "身邊的居民回血快一半",
        "champion": "打突襲時大家攻擊 +10%",
        "artisan": "工地產量 +10%",
        "beastmaster": "牧場產出 +15%",
        "bard": "出生快 10%",
        "sentinel": "突襲的魔獸血少 10%",
    ]
    static func isSpecial(_ breed: String) -> Bool { effects[breed] != nil }
}

extension Colony {
    /// Where the one at the gate stands: beside the camp's way in.
    var visitorPos: CGPoint? { nest.map { CGPoint(x: $0.x + 46, y: $0.y - 18) } }

    /// The name of a breed of this camp's race (the manifests'; specials included).
    func breedTitle(_ breed: String) -> String {
        Characters.current.breeds.first { $0.id == breed }?.name ?? "居民"
    }

    /// Whether a special of this breed lives at home now (the healer's and beastmaster's work is the Mac's).
    func hasSpecial(_ breed: String) -> Bool {
        guard let i = Characters.current.breeds.firstIndex(where: { $0.id == breed }) else { return false }
        return ants.contains { $0.breedIndex == i && !$0.isHidden }
    }

    /// The healer's reach: residents this close to a healer heal faster.
    func nearHealer(_ p: CGPoint) -> Bool {
        guard let i = Characters.current.breeds.firstIndex(where: { $0.id == "healer" }) else { return false }
        return ants.contains { $0.breedIndex == i && hypot($0.pos.x - p.x, $0.pos.y - p.y) < 120 }
    }

    func sendCampOrder(_ order: CampOrder, done: @escaping (Result<String, VisitorError>) -> Void) {
        guard let onCampCommand else { return done(.failure(VisitorError(message: "要先登入才能這樣做。"))) }
        onCampCommand(order, done)
    }
}

// MARK: - The panel

/// The one at the gate: who they are, what they ask, and 答應／拒絕 (with someone to swap out when the camp is full).
final class VisitorWindow: NSObject, NSWindowDelegate {
    static let shared = VisitorWindow()
    private var panel: NSPanel?
    private weak var colony: Colony?
    private var status = ""
    private var replace: Int?
    private var busy = false

    func show(colony: Colony) {
        self.colony = colony
        status = ""
        replace = nil
        if panel == nil {
            let p = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 380, height: 260), styleMask: [.titled, .closable, .utilityWindow], backing: .buffered, defer: false)
            p.isReleasedWhenClosed = false
            p.level = Levels.dialog
            p.delegate = self
            panel = p
        }
        rebuild()
        panel?.center()
        NSApp.activate(ignoringOtherApps: true)
        panel?.makeKeyAndOrderFront(nil)
    }

    func close() { panel?.orderOut(nil) }

    private func name(_ id: String) -> String { Materials.info(id)?.name ?? id }

    private func rebuild() {
        guard let panel, let colony else { return }
        guard let v = colony.booksVisitor else {
            if status.isEmpty { return close() }
            let done = NSTextField(wrappingLabelWithString: status)
            done.preferredMaxLayoutWidth = 340
            let stack = NSStackView(views: [done])
            stack.edgeInsets = NSEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
            panel.contentView = stack
            panel.setContentSize(NSSize(width: 380, height: stack.fittingSize.height))
            return
        }
        let who = colony.breedTitle(v.breed)
        let leaves = MerchantVisitInfo.date(v.leaves)
        panel.title = "\(who)想住進營地"
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.edgeInsets = NSEdgeInsets(top: 14, left: 16, bottom: 14, right: 16)
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        var intro = "\(v.special ? "✦ 特殊居民・" : "")\(who)在營地門口等，會待到 \(f.string(from: leaves))。"
        if let effect = SpecialRoles.effects[v.breed] { intro += "\n住進來的話：\(effect)。營地裡這種只能有一位。" }
        let introField = NSTextField(wrappingLabelWithString: intro)
        introField.preferredMaxLayoutWidth = 340
        stack.addArrangedSubview(introField)

        // the present they ask for: red where the camp is short
        let have = colony.materials
        let fee = NSMutableAttributedString(string: "見面禮：")
        for (k, (id, n)) in v.fee.sorted(by: { $0.key < $1.key }).enumerated() {
            let short = have[id, default: 0] < n
            fee.append(NSAttributedString(string: (k > 0 ? "、" : "") + "\(name(id)) ×\(n)（有 \(have[id, default: 0])）",
                                          attributes: short ? [.foregroundColor: NSColor.systemRed] : [:]))
        }
        let feeField = NSTextField(labelWithAttributedString: fee)
        feeField.preferredMaxLayoutWidth = 340
        stack.addArrangedSubview(feeField)
        let affordable = v.fee.allSatisfy { have[$0.key, default: 0] >= $0.value }

        // a full camp: someone has to make room (the youngest plain ones first: the cheapest to lose)
        let cap = Races.rules(Characters.current.id).homeCap
        let full = colony.booksHome.count >= cap
        if full {
            let note = NSTextField(wrappingLabelWithString: "營地住滿了（\(cap)），要選一位離開讓出位子：")
            note.textColor = .secondaryLabelColor
            stack.addArrangedSubview(note)
            let pop = NSPopUpButton(frame: .zero, pullsDown: false)
            let rank = ["common": 0, "scout": 1, "brute": 1, "sage": 2, "golden": 3]
            let list = colony.booksHome.sorted { (rank[$0.breed] ?? 4, $1.bornAt) < (rank[$1.breed] ?? 4, $0.bornAt) }.prefix(40)
            pop.addItem(withTitle: "（選一位）")
            for r in list {
                let born = MerchantVisitInfo.date(r.bornAt)
                let hours = max(0, Int(Date().timeIntervalSince(born) / 3600))
                pop.addItem(withTitle: "\(r.name ?? "#\(r.id)")・\(colony.breedTitle(r.breed))・\(hours) 小時大")
                pop.lastItem?.tag = r.id
            }
            if let replace, let item = pop.itemArray.first(where: { $0.tag == replace }) { pop.select(item) }
            pop.target = self
            pop.action = #selector(pickReplace(_:))
            stack.addArrangedSubview(pop)
        }

        let row = NSStackView()
        row.orientation = .horizontal
        row.spacing = 10
        let yes = NSButton(title: "答應", target: self, action: #selector(accept))
        yes.bezelStyle = .rounded
        yes.keyEquivalent = "\r"
        yes.isEnabled = !busy && affordable && (!full || replace != nil)
        let no = NSButton(title: "拒絕", target: self, action: #selector(decline))
        no.bezelStyle = .rounded
        no.isEnabled = !busy
        row.addArrangedSubview(yes)
        row.addArrangedSubview(no)
        stack.addArrangedSubview(row)
        if !status.isEmpty {
            let line = NSTextField(wrappingLabelWithString: status)
            line.textColor = .systemOrange
            line.preferredMaxLayoutWidth = 340
            stack.addArrangedSubview(line)
        }
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.widthAnchor.constraint(equalToConstant: 380).isActive = true
        panel.contentView = stack
        panel.setContentSize(NSSize(width: 380, height: stack.fittingSize.height))
    }

    @objc private func pickReplace(_ sender: NSPopUpButton) {
        replace = sender.selectedItem.flatMap { $0.tag > 0 ? $0.tag : nil }
        rebuild()
    }

    @objc private func accept() { answer(CampOrder(kind: "visitor-accept", visit: colony?.booksVisitor?.id, replace: replace)) }
    @objc private func decline() { answer(CampOrder(kind: "visitor-decline", visit: colony?.booksVisitor?.id)) }

    private func answer(_ order: CampOrder) {
        guard let colony, order.visit != nil else { return }
        busy = true
        rebuild()
        colony.sendCampOrder(order) { [weak self] result in
            guard let self else { return }
            self.busy = false
            switch result {
            case .success(let message):
                self.status = message
                colony.announce(message)
            case .failure(let e):
                self.status = e.message
            }
            self.rebuild()
        }
    }
}

// MARK: - A race level reached

extension Colony {
    /// Fireworks over the camp and cheering for a while, and the princess says what the level opened.
    func celebrate(level: Int, opens: String?, seconds: Double = 20) {
        celebratingUntil = Date().addingTimeInterval(seconds)
        let line = "種族等級升到 \(level) 級了！" + ((opens ?? "").isEmpty ? "" : "\(opens!)。")
        if onAnnounce?(line) != true { announce(line) }
    }
}
