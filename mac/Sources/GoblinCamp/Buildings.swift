import AppKit

// 營地建設 (ECONOMY.md §1.3; the rules are the server's, shared/src/camp/buildings.ts): six great works round the camp, three
// levels each. The books say what is built and what is going up; the Mac draws them in the camp (Resources/Buildings, drawn by
// tools/make_buildings.py) and sends 蓋／升級 from the 🏰 建設 panel. The clinic's quicker healing is the Mac's to do.

/// One building's rules as the panel shows them (the same numbers as shared CAMP_BUILDINGS).
struct BuildingRule {
    let id: String
    let name: String
    let effect: String
    let costs: [[(String, Int)]]
    let hours: [Double]
}

enum Buildings {
    static let max = 3
    static let rules: [BuildingRule] = [
        BuildingRule(id: "wall", name: "城牆", effect: "突襲的魔獸攻擊 −5%",
                     costs: [[("log", 500), ("stone", 800)], [("log", 2000), ("stone", 3000), ("wolf_pelt", 20)], [("log", 6000), ("stone", 9000), ("iron_plate", 10)]], hours: [4, 12, 24]),
        BuildingRule(id: "warehouse", name: "大倉庫", effect: "糧食存得比較多",
                     costs: [[("log", 400), ("stone", 200)], [("log", 1500), ("stone", 800), ("spider_silk", 20)], [("log", 5000), ("stone", 2500), ("dark_silk", 10)]], hours: [4, 12, 24]),
        BuildingRule(id: "clinic", name: "醫館", effect: "居民回血 +20%",
                     costs: [[("log", 300), ("stone", 300), ("frog_skin", 20)], [("log", 1200), ("stone", 1200), ("troll_moss", 10)], [("log", 4000), ("stone", 4000), ("banshee_tear", 5)]], hours: [4, 12, 24]),
        BuildingRule(id: "training", name: "訓練場", effect: "居民打突襲時血量 +5%",
                     costs: [[("log", 600), ("stone", 400)], [("log", 2500), ("stone", 1500), ("boar_tusk", 20)], [("log", 8000), ("stone", 5000), ("bear_claw", 10)]], hours: [4, 12, 24]),
        BuildingRule(id: "banquet", name: "宴會廳", effect: "來訪者多 10%；2 級起流浪商人多帶一樣",
                     costs: [[("log", 500), ("stone", 300), ("food_honey", 20)], [("log", 2000), ("stone", 1200), ("royal_jelly", 5)], [("log", 6000), ("stone", 4000), ("naga_pearl", 5)]], hours: [4, 12, 24]),
        BuildingRule(id: "watchtower", name: "瞭望塔", effect: "等級王來的那次突襲，大家攻擊 +10%",
                     costs: [[("log", 400), ("stone", 600)], [("log", 1600), ("stone", 2400), ("stone_wing", 10)], [("log", 5000), ("stone", 7000), ("wyvern_wing", 5)]], hours: [4, 12, 24]),
    ]
    static func rule(_ id: String) -> BuildingRule? { rules.first { $0.id == id } }

    // MARK: The art

    private static var images: [String: CGImage] = [:]
    private static let manifest: [String: [String: [String: Any]]] = {
        guard let url = Bundle.main.resourceURL?.appendingPathComponent("Buildings/manifest.json"), let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [:] }
        return json["races"] as? [String: [String: [String: Any]]] ?? [:]
    }()

    /// A picture of the race's (`key`: "<id>_<level>", "wall_<level>", "wall_<level>_tower"), or nil.
    static func image(_ key: String, race: String = Characters.current.id) -> CGImage? {
        let cacheKey = "\(race)/\(key)"
        if let hit = images[cacheKey] { return hit }
        guard let file = manifest[race]?[key]?["file"] as? String, let url = Bundle.main.resourceURL?.appendingPathComponent("Buildings/\(file)"),
              let src = CGImageSourceCreateWithURL(url as CFURL, nil), let img = CGImageSourceCreateImageAtIndex(src, 0, nil) else { return nil }
        images[cacheKey] = img
        return img
    }

    /// Where the five buildings may stand, from the camp's way in (points), in the order tried for each.
    static let spots: [CGPoint] = [
        CGPoint(x: -150, y: 50), CGPoint(x: 150, y: 50), CGPoint(x: -170, y: -60), CGPoint(x: 170, y: -60), CGPoint(x: 0, y: 120),
        CGPoint(x: -260, y: 0), CGPoint(x: 260, y: 0), CGPoint(x: -90, y: -120), CGPoint(x: 90, y: -120), CGPoint(x: 0, y: -150),
    ]
}

/// A building as the books keep it: its finished level, and when the next one going up is done.
struct BuildingState {
    var level: Int
    var busyUntil: Date?
}

/// Where a building is drawn: what, at which level (the one going up drawn as scaffolding), standing on `at`.
struct BuildingPlaced {
    let id: String
    let level: Int
    let building: Bool
    let at: CGPoint
    let image: CGImage
    var box: CGRect { CGRect(x: at.x - CGFloat(image.width), y: at.y, width: CGFloat(image.width * 2), height: CGFloat(image.height * 2)) }
}

extension Colony {
    /// The buildings to draw now: each built one (or the one going up) at its spot, and the wall round the camp.
    func placedBuildings() -> [BuildingPlaced] {
        guard let nest = scene?.nest ?? nest else { return [] }
        let key = "\(nest)|\(walkable.count)|\(decorObstacles.count)"
        if let cache = buildingCache, cache.key == key { return cache.placed }
        let placed = layOutBuildings(nest: nest)
        buildingCache = (key, placed)
        return placed
    }

    private func layOutBuildings(nest: CGPoint) -> [BuildingPlaced] {
        var out: [BuildingPlaced] = []
        var taken: [CGRect] = []
        for rule in Buildings.rules where rule.id != "wall" {
            guard let state = booksBuildings[rule.id] else { continue }
            let building = state.busyUntil != nil
            let level = max(1, building ? state.level + 1 : state.level)
            guard state.level > 0 || building, let image = Buildings.image("\(rule.id)_\(level)") else { continue }
            for spot in Buildings.spots {
                let at = CGPoint(x: nest.x + spot.x, y: nest.y + spot.y)
                let placed = BuildingPlaced(id: rule.id, level: level, building: building, at: at, image: image)
                let foot = placed.box.insetBy(dx: 4, dy: 0)
                guard walkable.contains(where: { $0.contains(at) }),
                      scene?.visiblePonds.contains(where: { $0.blocks(at, margin: 8) }) != true,
                      !taken.contains(where: { $0.intersects(foot) }),
                      !decorObstacles.contains(where: { $0.blocks(at, margin: 10) }) else { continue }
                taken.append(foot)
                out.append(placed)
                break
            }
        }
        out += wallPieces(nest: nest)
        return out
    }

    /// The wall: stretches round the camp on an oval, a gap left at the bottom for the way in, towers between from level 2.
    private func wallPieces(nest: CGPoint) -> [BuildingPlaced] {
        guard let state = booksBuildings["wall"] else { return [] }
        let building = state.busyUntil != nil
        let level = max(1, building ? state.level + 1 : state.level)
        guard state.level > 0 || building, let stretch = Buildings.image("wall_\(level)") else { return [] }
        let tower = level >= 2 ? Buildings.image("wall_\(level)_tower") : nil
        let rx: CGFloat = 330, ry: CGFloat = 200
        let pieces = Int((2 * .pi * sqrt((rx * rx + ry * ry) / 2)) / CGFloat(stretch.width * 2))
        var out: [BuildingPlaced] = []
        for k in 0..<pieces {
            let a = Double(k) / Double(pieces) * 2 * .pi
            if abs(a - .pi * 1.5) < 0.35 { continue } // (the way in, at the bottom)
            let at = CGPoint(x: nest.x + rx * CGFloat(cos(a)), y: nest.y + ry * CGFloat(sin(a)))
            guard walkable.contains(where: { $0.contains(at) }), scene?.visiblePonds.contains(where: { $0.blocks(at, margin: 4) }) != true else { continue }
            let isTower = tower != nil && k % 5 == 0
            out.append(BuildingPlaced(id: "wall", level: level, building: building, at: at, image: isTower ? tower! : stretch))
        }
        return out
    }

    /// What the goblins walk round: the buildings' ground (not the wall, which leaves its gaps open anyway).
    var buildingObstacles: [Obstacle] {
        placedBuildings().filter { $0.id != "wall" }.map { b in
            DecorObstacle(CGRect(x: b.at.x - b.box.width * 0.4, y: b.at.y, width: b.box.width * 0.8, height: min(22, b.box.height * 0.35)))
        }
    }

    /// The clinic's level (its residents heal quicker: ×(1 + 0.2 × level)).
    var clinicHeal: Double { 1 + 0.2 * Double(booksBuildings["clinic"]?.level ?? 0) }

    func sendBuild(_ id: String, done: @escaping (Result<String, VisitorError>) -> Void) {
        sendCampOrder(CampOrder(kind: "building-build", building: id), done: done)
    }
}

// MARK: - The panel

/// 🏰 建設: the six, what each does, what the next level costs (red where short) and takes, and 蓋／升級.
final class BuildingPanel: NSObject, NSWindowDelegate {
    static let shared = BuildingPanel()
    private var panel: NSPanel?
    private weak var colony: Colony?
    private var status = ""

    var isOpen: Bool { panel?.isVisible == true }

    func toggle(colony: Colony, near window: NSWindow?) {
        if isOpen { panel?.orderOut(nil); return }
        self.colony = colony
        if panel == nil {
            let p = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 360, height: 520), styleMask: [.titled, .closable, .utilityWindow], backing: .buffered, defer: false)
            p.title = "營地建設"
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

    func refresh() { if isOpen { rebuild() } }

    private func rebuild() {
        guard let panel, let colony else { return }
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.edgeInsets = NSEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        let busy = colony.booksBuildings.first { $0.value.busyUntil != nil }
        let intro = NSTextField(wrappingLabelWithString: colony.followsBooks
            ? "大工程，主要用木頭和石頭；一次蓋一個，每種最多 3 級。" + (busy.map { "\n現在在蓋：\(Buildings.rule($0.key)?.name ?? "")（\(Self.left($0.value.busyUntil))）" } ?? "")
            : "要先登入才能蓋（建設記在伺服器上）。")
        intro.font = .systemFont(ofSize: 11)
        intro.textColor = .secondaryLabelColor
        intro.preferredMaxLayoutWidth = 330
        stack.addArrangedSubview(intro)
        let quicker = colony.booksCampBonus?.build ?? 0
        for rule in Buildings.rules {
            let state = colony.booksBuildings[rule.id] ?? BuildingState(level: 0, busyUntil: nil)
            let box = NSStackView()
            box.orientation = .vertical
            box.alignment = .leading
            box.spacing = 3
            let head = NSStackView()
            head.spacing = 8
            if let image = Buildings.image("\(rule.id)_\(max(1, state.level))") {
                let view = NSImageView(image: NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height)))
                view.imageScaling = .scaleProportionallyUpOrDown
                view.widthAnchor.constraint(equalToConstant: 44).isActive = true
                view.heightAnchor.constraint(equalToConstant: 40).isActive = true
                view.alphaValue = state.level > 0 ? 1 : 0.4
                head.addArrangedSubview(view)
            }
            let title = NSTextField(labelWithString: "\(rule.name)　\(state.level > 0 ? "Lv\(state.level)" : "還沒蓋")" + (state.busyUntil != nil ? "（蓋 Lv\(state.level + 1) 中）" : ""))
            title.font = .systemFont(ofSize: 13, weight: .semibold)
            let effect = NSTextField(labelWithString: "每級：\(rule.effect)")
            effect.font = .systemFont(ofSize: 11)
            effect.textColor = .secondaryLabelColor
            let words = NSStackView(views: [title, effect])
            words.orientation = .vertical
            words.alignment = .leading
            words.spacing = 2
            head.addArrangedSubview(words)
            box.addArrangedSubview(head)
            if state.level < Buildings.max, state.busyUntil == nil {
                let cost = NSMutableAttributedString(string: "\(state.level == 0 ? "蓋" : "升到 Lv\(state.level + 1)")：")
                var enough = true
                for (i, (id, n)) in rule.costs[state.level].enumerated() {
                    let have = colony.materials[id, default: 0]
                    if have < n { enough = false }
                    let name = Materials.info(id)?.name ?? id
                    cost.append(NSAttributedString(string: "\(i > 0 ? "、" : "")\(name) \(n)", attributes: [.foregroundColor: have < n ? NSColor.systemRed : NSColor.labelColor]))
                }
                let hours = rule.hours[state.level] * (1 - min(0.5, quicker))
                cost.append(NSAttributedString(string: "　\(Self.hoursText(hours))"))
                let line = NSTextField(labelWithAttributedString: cost)
                line.font = .systemFont(ofSize: 11)
                box.addArrangedSubview(line)
                let button = NSButton(title: state.level == 0 ? "蓋" : "升級", target: self, action: #selector(build(_:)))
                button.identifier = NSUserInterfaceItemIdentifier(rule.id)
                button.controlSize = .small
                button.bezelStyle = .rounded
                button.isEnabled = colony.followsBooks && busy == nil && enough
                box.addArrangedSubview(button)
            } else if state.level >= Buildings.max {
                let done = NSTextField(labelWithString: "已經最高級了。")
                done.font = .systemFont(ofSize: 11)
                done.textColor = .secondaryLabelColor
                box.addArrangedSubview(done)
            }
            stack.addArrangedSubview(box)
        }
        if !status.isEmpty {
            let note = NSTextField(wrappingLabelWithString: status)
            note.font = .systemFont(ofSize: 11)
            note.preferredMaxLayoutWidth = 330
            stack.addArrangedSubview(note)
        }
        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 360, height: 520))
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        let holder = FlippedView()
        holder.addSubview(stack)
        stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([stack.topAnchor.constraint(equalTo: holder.topAnchor), stack.leadingAnchor.constraint(equalTo: holder.leadingAnchor), stack.widthAnchor.constraint(equalToConstant: 344)])
        holder.frame = NSRect(origin: .zero, size: NSSize(width: 344, height: stack.fittingSize.height))
        scroll.documentView = holder
        panel.contentView = scroll
    }

    @objc private func build(_ sender: NSButton) {
        guard let colony, let id = sender.identifier?.rawValue else { return }
        sender.isEnabled = false
        colony.sendBuild(id) { [weak self] result in
            switch result {
            case .success(let message): self?.status = message
            case .failure(let error): self?.status = error.message
            }
            self?.rebuild()
        }
    }

    static func hoursText(_ hours: Double) -> String {
        hours >= 1 ? "\(hours.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(hours)) : String(format: "%.1f", hours)) 小時" : "\(Int(hours * 60)) 分鐘"
    }

    static func left(_ until: Date?) -> String {
        guard let until else { return "" }
        let s = until.timeIntervalSinceNow
        return s <= 0 ? "快好了" : "還要 \(hoursText(s / 3600))"
    }
}

/// Lays its subviews out from the top (for the scrolling list).
private final class FlippedView: NSView {
    override var isFlipped: Bool { true }
}
