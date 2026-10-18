import AppKit

/// 再派一次: the last attack sent to each cell, kept on this Mac (who went, from where, the food), so a second wave is one
/// click. Nothing here is checked: the dispatch sheet takes what still fits. (The phone keeps its own: pwa/app/utils/again.ts.)
struct WorldLastAttack: Codable {
    let from: String
    let party: [Int]
    let supplies: [String: Int]
    let settle: Bool

    /// (a test run's own preferences with `CAMP_DEFAULTS`, as Settings)
    static let defaults: UserDefaults = ProcessInfo.processInfo.environment["CAMP_DEFAULTS"].flatMap { UserDefaults(suiteName: $0) } ?? .standard
    private static func key(_ cell: String) -> String { "goblincamp.again.\(cell)" }
    static func load(_ cell: String) -> WorldLastAttack? {
        defaults.data(forKey: key(cell)).flatMap { try? JSONDecoder().decode(WorldLastAttack.self, from: $0) }
    }
    func save(_ cell: String) {
        if let data = try? JSONEncoder().encode(self) { Self.defaults.set(data, forKey: Self.key(cell)) }
    }
}

/// A sheet over the main window: a title, what it holds (scrolls), and the buttons at the bottom that always show.
class WorldSheet: NSObject {
    let panel: NSPanel
    let stack = NSStackView()
    let footer = NSStackView()
    private let scroll = NSScrollView()
    private let doc = TopDownView()
    private weak var host: NSWindow?

    init(title: String, width: CGFloat = 520, height: CGFloat = 640) {
        panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: width, height: height), styleMask: [.titled, .resizable, .docModalWindow], backing: .buffered, defer: false)
        panel.title = title
        panel.minSize = NSSize(width: 420, height: 360)
        super.init()
        let content = panel.contentView!
        let heading = GuildUI.label(title, size: 16, bold: true)
        heading.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(heading)
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        doc.translatesAutoresizingMaskIntoConstraints = false
        doc.addSubview(stack)
        scroll.documentView = doc
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        scroll.automaticallyAdjustsContentInsets = false
        scroll.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(scroll)
        let line = GuildUI.separator()
        line.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(line)
        footer.orientation = .horizontal
        footer.spacing = 10
        footer.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(footer)
        NSLayoutConstraint.activate([
            heading.topAnchor.constraint(equalTo: content.topAnchor, constant: 16), heading.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            scroll.topAnchor.constraint(equalTo: heading.bottomAnchor, constant: 8), scroll.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: content.trailingAnchor), scroll.bottomAnchor.constraint(equalTo: line.topAnchor),
            line.leadingAnchor.constraint(equalTo: content.leadingAnchor), line.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            footer.topAnchor.constraint(equalTo: line.bottomAnchor, constant: 12), footer.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -14),
            footer.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
            doc.leadingAnchor.constraint(equalTo: scroll.contentView.leadingAnchor), doc.trailingAnchor.constraint(equalTo: scroll.contentView.trailingAnchor),
            doc.topAnchor.constraint(equalTo: scroll.contentView.topAnchor),
            stack.topAnchor.constraint(equalTo: doc.topAnchor, constant: 4), stack.bottomAnchor.constraint(equalTo: doc.bottomAnchor, constant: -12),
            stack.leadingAnchor.constraint(equalTo: doc.leadingAnchor, constant: 20), stack.trailingAnchor.constraint(equalTo: doc.trailingAnchor, constant: -20),
        ])
    }

    func present(on window: NSWindow) {
        host = window
        window.beginSheet(panel)
    }

    func dismiss() {
        if let host { host.endSheet(panel) } else { panel.orderOut(nil) }
    }

    func clear() {
        for v in stack.arrangedSubviews {
            stack.removeArrangedSubview(v)
            v.removeFromSuperview()
        }
    }

    func add(_ v: NSView) {
        stack.addArrangedSubview(v)
        v.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true
    }

    func text(_ s: String, size: CGFloat = 13, bold: Bool = false, color: NSColor = .labelColor) -> NSTextField {
        GuildUI.label(s, size: size, bold: bold, color: color, width: 460)
    }

    func note(_ s: String) -> NSTextField { text(s, size: 12, color: .secondaryLabelColor) }

    /// A button at the normal size; `on`: the one chosen, in the accent colour (white on it reads well, unlike on gold).
    func chip(_ title: String, on: Bool = false, enabled: Bool = true, _ action: @escaping () -> Void) -> ClosureButton {
        let b = ClosureButton(title: title, action: action)
        b.bezelStyle = .rounded
        b.controlSize = .regular
        if on { b.bezelColor = .controlAccentColor }
        b.isEnabled = enabled
        return b
    }

    /// One of a few choices, as a segmented control (打贏後: 留下來佔領 / 直接回家 / 劫掠).
    func segments(_ labels: [String], selected: Int, _ action: @escaping (Int) -> Void) -> NSSegmentedControl {
        let seg = WorldSegments(labels: labels, action: action)
        seg.selectedSegment = selected
        return seg
    }

    /// A choice in a list (a radio button and two lines), the whole line clickable.
    func choice(_ title: String, _ detail: String, on: Bool, _ action: @escaping () -> Void) -> NSView {
        let radio = NSButton(radioButtonWithTitle: "", target: nil, action: nil)
        radio.state = on ? .on : .off
        let lines = NSStackView(views: [GuildUI.label(title, size: 13, bold: true), GuildUI.label(detail, size: 12, color: .secondaryLabelColor)])
        lines.orientation = .vertical
        lines.alignment = .leading
        lines.spacing = 1
        let row = WorldClickRow(action: action)
        radio.target = row
        radio.action = #selector(WorldClickRow.fire)
        let inner = GuildUI.row([radio, lines], spacing: 8)
        inner.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(inner)
        NSLayoutConstraint.activate([
            inner.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 6), inner.trailingAnchor.constraint(lessThanOrEqualTo: row.trailingAnchor, constant: -6),
            inner.topAnchor.constraint(equalTo: row.topAnchor, constant: 5), inner.bottomAnchor.constraint(equalTo: row.bottomAnchor, constant: -5),
        ])
        return row
    }

    /// Up to `per` views side by side in each row.
    func rows(_ list: [NSView], per: Int = 3) -> NSView {
        let rows = NSStackView()
        rows.orientation = .vertical
        rows.alignment = .leading
        rows.spacing = 6
        var i = 0
        while i < list.count {
            let row = GuildUI.row(Array(list[i..<min(list.count, i + per)]), spacing: 6)
            row.distribution = .fillEqually
            rows.addArrangedSubview(row)
            row.widthAnchor.constraint(equalTo: rows.widthAnchor).isActive = true
            i += per
        }
        return rows
    }

    /// Big numbers side by side (我方戰力, 對方戰力, 走過去).
    func compare(_ items: [(String, String)]) -> NSView {
        let row = GuildUI.row(items.map { small, big in
            let v = NSStackView(views: [GuildUI.label(small, size: 12, color: .secondaryLabelColor), GuildUI.label(big, size: 20, bold: true)])
            v.orientation = .vertical
            v.spacing = 1
            return WorldPanel(v, tint: nil)
        }, spacing: 8)
        row.distribution = .fillEqually
        return row
    }

    /// How likely a win is: green for the share won, red for the rest.
    func odds(_ win: Double) -> NSView {
        let bar = OddsBar()
        bar.win = win
        bar.translatesAutoresizingMaskIntoConstraints = false
        bar.heightAnchor.constraint(equalToConstant: 8).isActive = true
        return bar
    }
}

final class OddsBar: NSView {
    var win = 0.0 { didSet { needsDisplay = true } }
    override func draw(_ dirtyRect: NSRect) {
        let r = NSBezierPath(roundedRect: bounds, xRadius: 4, yRadius: 4)
        NSColor.systemRed.setFill()
        r.fill()
        NSGraphicsContext.saveGraphicsState()
        r.addClip()
        NSColor.systemGreen.setFill()
        NSRect(x: 0, y: 0, width: bounds.width * max(0, min(1, win)), height: bounds.height).fill()
        NSGraphicsContext.restoreGraphicsState()
    }
}

/// Sending a party (the phone's is pwa/app/components/DispatchDialog.vue): where from, who goes (the strongest few in one go,
/// or one by one from the list), the food, how it would likely fare and how long the walk is. Every change asks the server
/// (POST world/expeditions/plan), which works it all out by the same rules as sending it; the Mac only counts heads.
final class WorldDispatch: WorldSheet {
    var onSent: ((String) -> Void)?
    var onClose: (() -> Void)?
    /// The way from where it sets out, for the map to draw.
    var onRoute: ((WorldRoute?) -> Void)?

    private let api: APIClient
    private let target: WorldCell
    private let kind: String
    private let me: WorldMe
    private let race: String
    private var again: WorldLastAttack?
    private var from: String
    private var picked = Set<Int>()
    private var supplies: [String: Int] = [:]
    private var settle: Bool
    private var plunder = false
    private var showRoster = false
    private var showBoosts = false
    private var plan: WorldPlan?
    private var planProblem = ""
    private var asked = 0
    private var pending: DispatchWorkItem?
    private var sending = false
    /// The party was picked once (from the first answer): later answers keep what was picked.
    private var started = false
    private var lastRoute = ""
    private var goButton: ClosureButton!
    private var names: WorldNames { .shared }

    private var settleKey: String { "goblincamp.settle.\(target.owner != nil ? "camp" : "lair")" }

    init(api: APIClient, target: WorldCell, kind: String, me: WorldMe, race: String, start: String?, again: WorldLastAttack?) {
        self.api = api
        self.target = target
        self.kind = kind
        self.me = me
        self.race = race
        self.again = again
        let first = again?.from ?? start ?? "home"
        from = first == "home" || me.cells.contains { $0.cell == first && $0.garrison > me.rules.garrisonMin } ? first : "home"
        settle = kind == "attack" ? (WorldLastAttack.defaults.object(forKey: "goblincamp.settle.\(target.owner != nil ? "camp" : "lair")") as? Bool ?? true) : kind == "settle"
        let title = ["attack": target.boss != nil ? "出征打世界魔王" : "出征", "settle": "派人去佔領", "move": "派人去駐守", "guard": "派兵幫\(target.owner?.name ?? "好友")守"][kind] ?? "出征"
        super.init(title: title)
        goButton = ClosureButton(title: "出發") { [weak self] in self?.send() }
        goButton.bezelStyle = .rounded
        goButton.controlSize = .large
        goButton.keyEquivalent = "\r"
        let cancel = GuildUI.button("取消") { [weak self] in self?.close() }
        cancel.controlSize = .large
        cancel.keyEquivalent = "\u{1b}"
        footer.addArrangedSubview(cancel)
        footer.addArrangedSubview(goButton)
        render()
        ask(now: true)
    }

    /// For the test runs: presses 出發 once the party is in.
    func sendForTesting() { send() }

    private func close() {
        pending?.cancel()
        dismiss()
        onClose?()
    }

    // MARK: counting heads (as the phone's dialog)

    private var capped: Bool { kind == "attack" || kind == "settle" }
    private var keep: Int { from == "home" ? 2 : me.rules.garrisonMin }
    private var fromCell: WorldMe.Cell? { me.cells.first { $0.cell == (from == "home" ? me.homeCell : from) } }
    private var cap: Int { plan?.supplies.cap ?? ((me.partyCap ?? 60) + (fromCell?.party ?? 0)) }
    private var store: [String: Int] { me.food ?? [:] }
    private var rationsHeld: Int { names.rations.reduce(0) { $0 + (store[$1] ?? 0) } }
    private var rationsTaken: Int { names.rations.reduce(0) { $0 + (supplies[$1] ?? 0) } }
    private var extra: Int { min(cap / 2, rationsTaken / names.rules.rationsPerExtra) }
    private var extraCanTake: Int { min(cap / 2, rationsHeld / names.rules.rationsPerExtra) }
    private var available: [WorldPlan.Resident] { plan?.residents ?? [] }
    private var order: [WorldPlan.Resident] { kind == "attack" || kind == "guard" ? available : available.reversed() }
    private var most: Int {
        let room = capped ? cap + extra : kind == "guard" ? names.rules.guestsMax - (target.guests ?? 0) : me.rules.cellCapacity
        return max(0, min(60, available.count - keep, room, plan?.entry ?? 60))
    }
    private var party: [WorldPlan.Resident] { available.filter { picked.contains($0.id) } }
    private static func boostCost(_ size: Int) -> Int { max(1, Int(ceil(Double(size) / 5))) }

    private func setExtra(_ n: Int) {
        var need = n * names.rules.rationsPerExtra
        for id in names.rations {
            let take = min(store[id] ?? 0, need)
            supplies[id] = take
            need -= take
        }
        changed()
    }

    private func pickTop(_ n: Int) {
        picked = Set(order.prefix(min(n, most)).map(\.id))
        changed()
    }

    private func toggle(_ id: Int) {
        if picked.contains(id) { picked.remove(id) } else if picked.count < most { picked.insert(id) }
        changed()
    }

    private func changed() {
        render()
        ask()
    }

    // MARK: asking the server

    private struct PlanBody: Encodable {
        let from: String
        let to: String
        let kind: String
        let residents: [Int]?
        let supplies: [String: Int]?
        let settle: Bool
        let plunder: Bool
    }

    /// Asks again for what the party picked would do (a moment after the last change, so clicking along asks once).
    private func ask(now: Bool = false) {
        pending?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.askNow() }
        pending = work
        DispatchQueue.main.asyncAfter(deadline: .now() + (now ? 0 : 0.35), execute: work)
    }

    private func askNow() {
        asked += 1
        let mine = asked
        let body = PlanBody(from: from, to: target.cell, kind: kind, residents: picked.isEmpty ? nil : Array(picked).sorted(),
                            supplies: capped ? supplies.filter { $0.value > 0 } : nil, settle: settle, plunder: plunder)
        Task { @MainActor in
            do {
                let got = try await api.request("POST", "world/expeditions/plan", body: body, as: WorldPlan.self)
                guard mine == asked else { return }
                plan = got
                planProblem = ""
                if !started {
                    started = true
                    startParty()
                    return
                }
                let route = got.way.waypoints.joined(separator: ",")
                if route != lastRoute {
                    lastRoute = route
                    onRoute?(got.way)
                }
            } catch let e as APIError {
                guard mine == asked else { return }
                planProblem = e.message
            } catch {
                planProblem = error.localizedDescription
            }
            render()
        }
    }

    /// The first party: the best for the job (the strongest to fight, plain ones to settle), or last time's.
    private func startParty() {
        picked = Set(order.prefix(min(capped ? most : 10, most)).map(\.id))
        if let again {
            let want = min(again.party.count, most)
            let same = order.filter { again.party.contains($0.id) }.prefix(want)
            let others = order.filter { !again.party.contains($0.id) }.prefix(want - same.count)
            picked = Set((same + others).map(\.id))
            for (id, n) in again.supplies { supplies[id] = min(n, store[id] ?? 0) }
            if kind == "attack" { settle = again.settle }
            self.again = nil
        }
        changed()
    }

    private func send() {
        guard let plan, !sending else { return }
        sending = true
        render()
        struct Body: Encodable {
            let from: String
            let to: String
            let settle: Bool
            let guard_: Bool?
            let plunder: Bool?
            let residents: [Int]
            let supplies: [String: Int]?
            enum CodingKeys: String, CodingKey { case from, to, settle, guard_ = "guard", plunder, residents, supplies }
        }
        let ids = party.map(\.id)
        let eaten = capped ? plan.supplies.spent : [:]
        let doPlunder = plunder && plan.canPlunder
        let body = Body(from: from, to: target.cell, settle: kind == "move" ? false : kind == "settle" ? true : settle && !doPlunder,
                        guard_: kind == "guard" ? true : nil, plunder: doPlunder ? true : nil, residents: ids, supplies: eaten.isEmpty ? nil : eaten)
        Task { @MainActor in
            do {
                _ = try await api.raw("POST", "world/expeditions", body: body)
                if kind == "attack" { WorldLastAttack(from: from, party: ids, supplies: supplies, settle: settle).save(target.cell) }
                dismiss()
                onSent?(doPlunder ? "出發劫掠！\(ids.count) 隻上路。" : "出發了！\(ids.count) 隻上路。")
                onClose?()
            } catch let e as APIError {
                planProblem = e.message
                sending = false
                render()
            } catch {
                planProblem = error.localizedDescription
                sending = false
                render()
            }
        }
    }

    // MARK: what shows

    private func render() {
        clear()
        let p = plan
        // where from
        let starts = p?.starts ?? [WorldPlan.Start(id: "home", n: me.atHome, best: 0, power: 0)]
        if starts.count > 1 {
            add(text("從哪裡出發", bold: true))
            for o in starts {
                add(choice(o.id == "home" ? "🏕️ 營地" : "領地・\(me.cells.first { $0.cell == o.id }.map { names.terrain($0.terrain) } ?? "")", "\(o.id == "home" ? "在家" : "住") \(o.n) 隻・最強 \(o.best) 隻，戰力 \(o.power)", on: from == o.id) { [weak self] in
                    guard let self, self.from != o.id else { return }
                    self.from = o.id
                    self.picked = []
                    self.started = false
                    self.changed()
                })
            }
            add(GuildUI.separator())
        }
        guard let p else {
            add(note(planProblem.isEmpty ? "讀取居民中…" : planProblem))
            goButton.isEnabled = false
            return
        }

        // how it would go
        var numbers: [(String, String)] = [("我方戰力", "\(p.power)")]
        if let l = target.lair { numbers.append(("對方戰力", "\(l.power)")) } else if target.owner != nil { numbers.append(("對方守軍", "\(target.garrison) 隻")) }
        if let m = p.minutes {
            let small = p.moonGate ? "月光傳送（今天還有 \(me.moonGatesLeft ?? 0) 次）" : p.nightRaid ? "夜襲：對方看不到" : p.detour > 0 ? "繞路 +\(p.detour) 分" : "走過去"
            numbers.append((small, p.moonGate ? "瞬間到" : "\(m) 分"))
        }
        add(compare(numbers))
        if p.fullMoon == true { add(note("🌕 滿月狂暴：攻擊 +40%、走路快 15%，但受傷 +25%（已算進上面的戰力與時間）")) }
        let noWay = p.way.waypoints.isEmpty
        if noWay { add(text("\(p.way.blockedBy?.name ?? "別人")的領地（有巢穴、建築或城鎮）擋在路上，繞不過去：先把擋路的那一格打下來，或從別的地方出發。", color: .systemRed)) }
        if let e = p.estimate, !party.isEmpty {
            add(odds(e.win))
            let feel = e.win >= 0.8 ? "（應該打得贏）" : e.win >= 0.45 ? "（有點冒險）" : "（很難打贏）"
            if target.owner != nil {
                add(note("對方會有 \(e.facing) 隻迎戰（最強的先上；全部 \(e.total) 隻，一格的地方有限，最多是你的 1.5 倍）。勝率約 \(Int((e.win * 100).rounded()))%・我方平均倒下 \(String(format: "%.1f", e.fallen))・打倒對方 \(String(format: "%.1f", e.killed)) 隻\(feel)"))
            } else {
                add(note("勝率約 \(Int((e.win * 100).rounded()))%・平均倒下 \(String(format: "%.1f", e.fallen)) 隻・打倒 \(String(format: "%.1f", e.killed)) 隻\(feel)"))
            }
            if e.win < 0.6 { add(hints(e)) }
        }
        if let entry = p.entry { add(note("這個巢穴很小，一次最多只能進去 \(entry) 隻：靠裝備、道具和糧食取勝，不是人多。")) }
        if let w = target.lairWounds { add(note("巢穴受傷中：剩 \(w.standing)/\(w.total) 隻、\(Int((w.hpShare * 100).rounded()))% 血")) }

        // the food
        if capped { addFood(p) }

        // who goes
        add(GuildUI.row([text("已選 \(party.count) 隻", bold: true), note("最多 \(most)（\(from == "home" ? "營地至少留 2 隻" : "那一格至少留 \(me.rules.garrisonMin) 隻")）")]))
        let quick = capped ? most : 10
        add(GuildUI.row([
            chip(showRoster ? "收起名單" : "逐隻挑選", on: showRoster) { [weak self] in self?.showRoster.toggle(); self?.render() },
            chip(kind == "attack" || kind == "guard" ? "最強 \(quick) 隻" : "一般的 \(quick) 隻") { [weak self] in self?.pickTop(quick) },
            chip("全部") { [weak self] in guard let self else { return }; self.pickTop(self.most) },
            chip("清空") { [weak self] in self?.picked = []; self?.changed() },
        ], spacing: 6))
        if showRoster { add(roster()) }

        // after a win
        if kind == "attack" && target.boss == nil {
            let labels = ["留下來佔領", "直接回家"] + (p.canPlunder ? ["🏴‍☠️ 劫掠"] : [])
            let seg = segments(labels, selected: plunder ? 2 : settle ? 0 : 1) { [weak self] i in
                if i == 2 { self?.plunder = true; self?.changed() } else { self?.chooseSettle(i == 0) }
            }
            add(GuildUI.row([text("打贏後", bold: true), seg], spacing: 10))
            let r = names.rules
            add(note(plunder ? "搶走對方倉庫每種素材的 \(Int((r.raidShare * 100).rounded()))%（每種最多 \(r.raidCap)、一次最多 \(r.raidTotal)；城鎮、有瞭望塔的格子減半）就走，不佔地"
                     : settle ? "活下來的至少 \(me.rules.garrisonMin) 隻才佔得住・下次會記得" : "撿了戰利品就回來・下次會記得"))
        }
        if kind == "settle" && party.count < me.rules.garrisonMin { add(text("至少要 \(me.rules.garrisonMin) 隻才守得住一格。", color: .systemRed)) }
        if kind == "guard" {
            add(note("牠們會住在那裡，巢穴回來搶、有人來打時一起守；戰死的裝備會回你的倉庫。你或對方隨時可以叫牠們回來。一格最多 \(names.rules.guestsMax) 隻好友的居民（現在有 \(target.guests ?? 0) 隻）。"))
        }
        let problem = !planProblem.isEmpty ? planProblem : (p.supplies.problem ?? (party.isEmpty ? nil : p.problem))
        if let problem { add(text(problem, bold: true, color: .systemRed)) }

        let go = ["attack": "出發攻擊", "settle": "出發佔領", "move": "出發", "guard": "出發幫守"][kind] ?? "出發"
        goButton.title = sending ? "出發中…" : "\(go)（\(party.count) 隻）"
        goButton.isEnabled = !sending && !party.isEmpty && !noWay && (kind != "settle" || party.count >= me.rules.garrisonMin)
            && p.supplies.problem == nil && p.problem == nil && p.minutes != nil
    }

    private func chooseSettle(_ v: Bool) {
        plunder = false
        settle = v
        WorldLastAttack.defaults.set(v, forKey: settleKey)
        changed()
    }

    /// What would help, when it looks bad.
    private func hints(_ e: WorldPlan.Estimate) -> NSView {
        var out: [String] = []
        let bare = party.filter { $0.gear == 0 }.count
        if bare > 0 { out.append("\(bare) 隻沒穿裝備：去工坊做武器和護甲，戰力會高很多") }
        if extra < extraCanTake { out.append("帶乾糧可以多派（每 \(names.rules.rationsPerExtra) 份多 1 隻，最多多 \(cap / 2) 隻）") }
        let cost = Self.boostCost(party.count)
        let unused = names.boosts.filter { (supplies[$0.id] ?? 0) == 0 && (store[$0.id] ?? 0) >= cost }
        if !unused.isEmpty { out.append("帶\(unused.map(\.name).joined(separator: "、"))可以加成") }
        out.append("打輸了巢穴會留傷，趁牠還沒回血派第二波")
        return text(out.map { "・\($0)" }.joined(separator: "\n"), size: 11, color: .systemOrange)
    }

    private func addFood(_ p: WorldPlan) {
        add(GuildUI.separator())
        add(GuildUI.row([text("帶食物", bold: true), note("一隊最多 \(cap) 隻（Lv\(me.level)）\(extra > 0 ? "＋乾糧 \(extra) 隻" : "")")]))
        add(GuildUI.row([
            text("乾糧"), note("倉庫 \(rationsHeld) 份・每 \(names.rules.rationsPerExtra) 份多派 1 隻"), NSView(),
            chip("−", enabled: extra > 0) { [weak self] in guard let self else { return }; self.setExtra(self.extra - 1) },
            text("+\(extra) 隻", bold: true),
            chip("＋", enabled: extra < extraCanTake) { [weak self] in guard let self else { return }; self.setExtra(self.extra + 1) },
        ], spacing: 6))
        let taken = names.boosts.filter { (supplies[$0.id] ?? 0) > 0 }.count
        let fold = ClosureButton(title: "\(showBoosts ? "▾" : "▸") 加成食物\(taken > 0 ? "（帶了 \(taken) 樣）" : "")") { [weak self] in self?.showBoosts.toggle(); self?.render() }
        fold.isBordered = false
        fold.font = .boldSystemFont(ofSize: 13)
        add(GuildUI.row([fold]))
        if showBoosts {
            let cost = Self.boostCost(max(1, party.count))
            let shown = names.boosts.filter { !$0.item || (store[$0.id] ?? 0) > 0 || (supplies[$0.id] ?? 0) > 0 }
            for f in shown {
                let on = (supplies[f.id] ?? 0) > 0
                let box = NSButton(checkboxWithTitle: "", target: nil, action: nil)
                box.state = on ? .on : .off
                box.isEnabled = on || (store[f.id] ?? 0) >= cost
                let row = WorldClickRow { [weak self] in
                    guard box.isEnabled else { return }
                    self?.supplies[f.id] = on ? 0 : 1
                    self?.changed()
                }
                box.target = row
                box.action = #selector(WorldClickRow.fire)
                let lines = NSStackView(views: [GuildUI.label("\(f.name)  ×\(cost)（倉庫有 \(store[f.id] ?? 0)）", size: 13, bold: true, color: box.isEnabled ? .labelColor : .tertiaryLabelColor),
                                                GuildUI.label(f.what, size: 12, color: .secondaryLabelColor)])
                lines.orientation = .vertical
                lines.alignment = .leading
                lines.spacing = 1
                let inner = GuildUI.row([box, lines], spacing: 8)
                inner.translatesAutoresizingMaskIntoConstraints = false
                row.addSubview(inner)
                NSLayoutConstraint.activate([
                    inner.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 6), inner.trailingAnchor.constraint(lessThanOrEqualTo: row.trailingAnchor),
                    inner.topAnchor.constraint(equalTo: row.topAnchor, constant: 4), inner.bottomAnchor.constraint(equalTo: row.bottomAnchor, constant: -4),
                ])
                add(row)
            }
        }
        add(GuildUI.separator())
    }

    private func roster() -> NSView {
        let list = NSStackView()
        list.orientation = .vertical
        list.alignment = .leading
        list.spacing = 2
        for r in available {
            let on = picked.contains(r.id)
            let box = NSButton(checkboxWithTitle: "", target: nil, action: nil)
            box.state = on ? .on : .off
            box.isEnabled = on || picked.count < most
            let name = WorldText.residentName(race: race, name: r.name, seed: r.seed, legacySeed: r.legacySeed)
            let who = NSStackView(views: [GuildUI.label(name, size: 13, bold: true), GuildUI.label("\(WorldArt.breedName(race, r.breed))\(r.gear > 0 ? "・裝備 \(r.gear) 件" : "")", size: 12, color: .secondaryLabelColor)])
            who.orientation = .vertical
            who.alignment = .leading
            who.spacing = 0
            let power = GuildUI.label("戰力 \(r.power)", size: 13, bold: true)
            let row = WorldClickRow { [weak self] in self?.toggle(r.id) }
            let inner = GuildUI.row([box, WorldArt.view(WorldArt.breed(race, r.breed), size: 30), who, NSView(), power], spacing: 8)
            inner.translatesAutoresizingMaskIntoConstraints = false
            row.addSubview(inner)
            NSLayoutConstraint.activate([
                inner.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 4), inner.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -4),
                inner.topAnchor.constraint(equalTo: row.topAnchor, constant: 2), inner.bottomAnchor.constraint(equalTo: row.bottomAnchor, constant: -2),
            ])
            box.target = row
            box.action = #selector(WorldClickRow.fire)
            list.addArrangedSubview(row)
            row.widthAnchor.constraint(equalTo: list.widthAnchor).isActive = true
        }
        return list
    }
}

/// 撤回 (server/WORLD.md §24; the phone's is pwa/app/components/RecallDialog.vue): residents on a held cell (or camping
/// beside it) walk to the camp or to another held cell. Those who do not fit walk on to the nearest cell with room.
final class WorldRecall: WorldSheet {
    var onDone: ((String) -> Void)?

    private let api: APIClient
    private let from: String
    private let available: Int
    private let keep: Int
    private let campers: Bool
    private var cells: [WorldTerritoryItem]?
    private var problem = ""
    private var busy = false
    private var to = "home"
    private let count = NSTextField()
    private var goButton: ClosureButton!

    init(api: APIClient, from: String, title: String, available: Int, keep: Int, campers: Bool) {
        self.api = api
        self.from = from
        self.available = available
        self.keep = keep
        self.campers = campers
        super.init(title: title, width: 460, height: 560)
        count.integerValue = available
        count.target = self
        count.action = #selector(countChanged)
        count.translatesAutoresizingMaskIntoConstraints = false
        count.widthAnchor.constraint(equalToConstant: 80).isActive = true
        goButton = ClosureButton(title: "出發") { [weak self] in self?.go() }
        goButton.bezelStyle = .rounded
        goButton.controlSize = .large
        goButton.keyEquivalent = "\r"
        let cancel = GuildUI.button("取消") { [weak self] in self?.dismiss() }
        cancel.controlSize = .large
        cancel.keyEquivalent = "\u{1b}"
        footer.addArrangedSubview(cancel)
        footer.addArrangedSubview(goButton)
        render()
        struct List: Decodable { let items: [WorldTerritoryItem] }
        Task { @MainActor in
            do {
                cells = try await api.request("GET", "world/territory", as: List.self).items
            } catch let e as APIError {
                problem = e.message
            } catch {
                problem = error.localizedDescription
            }
            render()
        }
    }

    @objc private func countChanged() { render() }

    private func minutes(_ cell: String) -> Int { WorldNames.shared.walkMinutes(WorldGrid.meters(WorldGrid.center(from), WorldGrid.center(cell))) }
    private func name(_ c: WorldTerritoryItem) -> String { c.landmark?.label ?? WorldNames.shared.terrains[c.terrain] ?? "領地" }
    private var n: Int { max(1, min(available, count.integerValue)) }
    /// Everyone goes (the cell is given up), or too few would be left to hold it.
    private var givesUp: Bool { !campers && available - n < keep }
    private var going: Int { givesUp ? available : n }

    private func render() {
        clear()
        guard let cells else {
            add(note(problem.isEmpty ? "讀取中…" : problem))
            goButton.isEnabled = false
            return
        }
        let home = cells.first { $0.home == true }
        let choices = cells.filter { $0.home != true && $0.cell != from }.sorted { minutes($0.cell) < minutes($1.cell) }
        add(text("去哪裡", bold: true, color: .secondaryLabelColor))
        var options: [NSView] = [option("🏕️ 營地", "約 \(home.map { "\(minutes($0.cell))" } ?? "?") 分鐘・一定住得下", id: "home")]
        for c in choices {
            let free = max(0, c.capacity - c.garrison)
            options.append(option(name(c), "約 \(minutes(c.cell)) 分鐘・住 \(c.garrison)／\(c.capacity)・\(free > 0 ? "還能住 \(free) 隻" : "滿了")\((c.camping ?? 0) > 0 ? "・外面扎營 \(c.camping!) 隻" : "")", id: c.cell))
        }
        for o in options { add(o) }
        add(text("幾隻（\(campers ? "外面扎營的" : "住在這裡的")共 \(available) 隻）", bold: true, color: .secondaryLabelColor))
        add(GuildUI.row([count, chip("全部") { [weak self] in guard let self else { return }; self.count.integerValue = self.available; self.render() }]))
        if givesUp { add(text("\(n < available ? "這一格至少要留 \(keep) 隻，所以會全部 \(available) 隻都撤走。" : "")全部撤走，這一格就放掉了（出發時就不是你的了）。", color: .systemRed)) }
        if to != "home", let t = choices.first(where: { $0.cell == to }), going > max(0, t.capacity - t.garrison) {
            add(note("住不下的 \(going - max(0, t.capacity - t.garrison)) 隻會自動走去最近還有空位的領地；都滿了就在那一格旁邊扎營，有空位時自動住進去（扎營的也會幫忙守）。"))
        }
        if !problem.isEmpty { add(text(problem, color: .systemRed)) }
        goButton.title = busy ? "出發中…" : "出發（\(going) 隻）"
        goButton.isEnabled = !busy
    }

    private func option(_ title: String, _ detail: String, id: String) -> NSView {
        choice(title, detail, on: to == id) { [weak self] in self?.to = id; self?.render() }
    }

    private func go() {
        guard cells != nil, !busy else { return }
        busy = true
        problem = ""
        render()
        struct Body: Encodable { let to: String; let count: Int?; let campers: Bool? }
        let going = going, to = to
        let body = Body(to: to, count: going < available ? going : nil, campers: campers ? true : nil)
        Task { @MainActor in
            do {
                _ = try await api.raw("POST", "world/cells/\(from)/recall", body: body)
                let home = cells?.first { $0.home == true }
                let target = cells?.first { $0.cell == to }
                let where_ = to == "home" ? "營地" : target.map(name) ?? "那一格"
                let mins = to == "home" ? home.map { "\(minutes($0.cell))" } ?? "?" : "\(minutes(to))"
                dismiss()
                onDone?("\(going) 隻出發去\(where_)了（約 \(mins) 分鐘）。")
            } catch let e as APIError {
                problem = e.message
                busy = false
                render()
            } catch {
                problem = error.localizedDescription
                busy = false
                render()
            }
        }
    }
}

/// A segmented control that says which segment was picked.
final class WorldSegments: NSSegmentedControl {
    private var picked: ((Int) -> Void)?

    convenience init(labels: [String], action: @escaping (Int) -> Void) {
        self.init(labels: labels, trackingMode: .selectOne, target: nil, action: nil)
        picked = action
        target = self
        self.action = #selector(changed)
        controlSize = .regular
    }

    @objc private func changed() { picked?(selectedSegment) }
}
