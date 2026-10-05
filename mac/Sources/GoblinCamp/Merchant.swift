import AppKit

// The wandering merchant (DESKTOP.md §2, shared/src/camp/merchant.ts): it comes to a camp that is on the screen one to three
// times a day, brings a present, sets up beside the camp for a quarter of an hour, and swaps rarer things for the camp's
// materials. Click it to trade. A signed-in camp asks the server (which pays and checks); a camp of its own does it here.

/// A visit, as the server sends it (`CampView.merchant`) or as a camp of its own makes it.
struct MerchantVisitInfo: Codable, Equatable {
    struct Offer: Codable, Equatable {
        let give: [String: Int]
        let get: [String: Int]
        let sale: Bool?
        /// A rare find: the merchant's visit on a day of much focus (Focus.swift).
        var rare: Bool? = nil
    }
    let id: String
    let merchant: String
    let arrivedAt: String
    let leavesAt: String
    let gift: [String: Int]
    let stock: [Offer]
    var bought: [Int]

    private static let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    static func date(_ s: String) -> Date { iso.date(from: s) ?? ISO8601DateFormatter().date(from: s) ?? Date() }
    static func string(_ d: Date) -> String { iso.string(from: d) }
    var leaves: Date { MerchantVisitInfo.date(leavesAt) }
    var arrived: Date { MerchantVisitInfo.date(arrivedAt) }
}

/// The rules for a camp that keeps its own books (the same as shared/src/camp/merchant.ts, with this Mac's own dice).
enum MerchantRules {
    static let stayMinutes = 15.0
    static let perDay = 3
    static let gapMinutes = 60.0

    static func name(_ race: String) -> String {
        ["goblin": "狗頭人行商", "elf": "松鼠商隊", "undead": "冥河擺渡人"][race] ?? "狗頭人行商"
    }

    private struct Deal { let give: [String: Int]; let get: [String: Int]; let weight: Double }

    private static let common: [Deal] = [
        Deal(give: ["log": 80], get: ["crystal_shard": 1], weight: 2),
        Deal(give: ["stone": 60], get: ["scrap_iron": 6], weight: 2),
        Deal(give: ["log": 30], get: ["ration_bread": 3], weight: 2),
        Deal(give: ["rat_pelt": 6], get: ["leather_strap": 1], weight: 1.5),
        Deal(give: ["scrap_rag": 10], get: ["spider_silk": 2], weight: 1),
        Deal(give: ["rat_fang": 8], get: ["wolf_fang": 2], weight: 1),
        Deal(give: ["slime_goo": 8], get: ["elastic_gel": 2], weight: 1),
        Deal(give: ["log": 40, "stone": 20], get: ["amber": 1], weight: 1),
        Deal(give: ["scrap_iron": 12], get: ["guard_plate": 1], weight: 0.8),
        Deal(give: ["feather": 6], get: ["food_honey": 3], weight: 1),
    ]
    private static let own: [String: [Deal]] = [
        "goblin": [Deal(give: ["log": 50, "scrap_iron": 6], get: ["stolen_coin": 3], weight: 2), Deal(give: ["rat_tail": 6, "rat_pelt": 4], get: ["rat_crown": 1], weight: 0.6),
                   Deal(give: ["stone": 40], get: ["throwing_knife": 2], weight: 1.5), Deal(give: ["scrap_wood": 15], get: ["war_paint": 2], weight: 1.2)],
        "elf": [Deal(give: ["log": 60], get: ["heartwood": 1], weight: 1.5), Deal(give: ["ration_berry": 4], get: ["glow_spore": 3], weight: 1.5),
                Deal(give: ["feather": 8], get: ["ancient_bark": 2], weight: 1.2), Deal(give: ["food_honey": 4, "log": 20], get: ["amber": 2], weight: 0.8)],
        "undead": [Deal(give: ["stone": 50], get: ["ectoplasm": 2], weight: 1.5), Deal(give: ["bone_shard": 10], get: ["night_dust": 3], weight: 1.5),
                   Deal(give: ["night_dust": 6, "scrap_iron": 8], get: ["cursed_steel": 1], weight: 1), Deal(give: ["night_dust": 10], get: ["night_heart": 1], weight: 0.5)],
    ]

    static func gift(stage: Int) -> [String: Int] {
        let scale = stage >= 3 ? 1.5 : 1
        var gift = stage <= 1 ? ["log": Int.random(in: 10...20), "stone": Int.random(in: 5...10)]
                              : ["log": Int((Double(Int.random(in: 20...40)) * scale).rounded()), "stone": Int((Double(Int.random(in: 10...20)) * scale).rounded())]
        if stage >= 2 { gift[["scrap_rag", "scrap_wood", "scrap_iron", "rat_pelt", "feather"].randomElement()!, default: 0] += Int.random(in: 2...4) }
        if stage >= 3, Double.random(in: 0..<1) < 0.2 { gift["crystal_shard", default: 0] += 1 }
        return gift
    }

    static func stock(race: String) -> [MerchantVisitInfo.Offer] {
        var left = (own[race] ?? own["goblin"]!) + common
        var picked: [MerchantVisitInfo.Offer] = []
        for _ in 0..<Int.random(in: 4...6) where !left.isEmpty {
            var roll = Double.random(in: 0..<left.reduce(0) { $0 + $1.weight })
            var i = 0
            while i < left.count - 1 { roll -= left[i].weight; if roll < 0 { break }; i += 1 }
            let deal = left.remove(at: i)
            picked.append(.init(give: deal.give, get: deal.get, sale: nil))
        }
        if Double.random(in: 0..<1) < 0.15, let k = picked.indices.randomElement() {
            picked[k] = .init(give: picked[k].give.mapValues { max(1, Int((Double($0) * 0.6).rounded())) }, get: picked[k].get, sale: true)
        }
        return picked
    }

    static func visit(race: String, stage: Int, now: Date = Date()) -> MerchantVisitInfo {
        MerchantVisitInfo(id: "local-\(Int(now.timeIntervalSince1970))", merchant: name(race), arrivedAt: MerchantVisitInfo.string(now),
                          leavesAt: MerchantVisitInfo.string(now.addingTimeInterval(stayMinutes * 60)), gift: gift(stage: stage), stock: stock(race: race), bought: [])
    }
}

/// When the merchant comes today: one or two visits (one more on a holiday) between 9 and 21 o'clock, an hour apart at least,
/// the same all day (worked out from the date), counted in the settings so a restart does not bring it again.
enum MerchantPlan {
    static func times(for day: Date) -> [Date] {
        let cal = Calendar.current
        let start = cal.startOfDay(for: day)
        let key = Stats.key(day)
        var seed = key.unicodeScalars.reduce(UInt64(5381)) { ($0 << 5) &+ $0 &+ UInt64($1.value) } // (the same every run: not hashValue)
        func next() -> Double {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            return Double(seed >> 11) / Double(1 << 53)
        }
        let count = (next() < 0.5 ? 1 : 2) + (Holidays.on(day).map { !$0.quiet } == true ? 1 : 0)
        var hours: [Double] = []
        for _ in 0..<40 where hours.count < count {
            let h = 9 + next() * 12
            if hours.allSatisfy({ abs($0 - h) >= 1.2 }) { hours.append(h) }
        }
        return hours.sorted().map { start.addingTimeInterval($0 * 3600) }
    }

    /// How many came today on this Mac.
    static var doneToday: Int {
        guard let saved = Settings.shared.merchantVisits, saved.hasPrefix(Stats.key(Holidays.now) + ":") else { return 0 }
        return Int(saved.split(separator: ":").last ?? "") ?? 0
    }

    /// `CAMP_MERCHANT_AT=seconds`: the first visit that long after the start (tests).
    static let testAt = Double(ProcessInfo.processInfo.environment["CAMP_MERCHANT_AT"] ?? "")
    static let started = Date()

    /// Whether the next visit of the day is due: the day's plan, or the visit a day of focus earned (FocusInfo), an hour
    /// after the last one at least.
    static func due(now: Date = Holidays.now, focus: FocusInfo? = nil) -> Bool {
        if let testAt { return Date().timeIntervalSince(started) >= testAt && doneToday == 0 }
        if bonusDue(focus: focus, now: now) { return true }
        let plan = times(for: now)
        let done = doneToday
        return done < plan.count && now >= plan[done]
    }

    /// The visit earned by focus today and not had yet.
    static func bonusDue(focus: FocusInfo?, now: Date = Holidays.now) -> Bool {
        guard focus?.perks.merchant == true, Settings.shared.merchantBonusDay != Stats.key(now) else { return false }
        return now.timeIntervalSince(Settings.shared.merchantLastAt ?? .distantPast) >= 61 * 60
    }

    /// A visit came (or was refused): the earned one first, else the day's next.
    static func markVisit(focus: FocusInfo? = nil) {
        if bonusDue(focus: focus) { Settings.shared.merchantBonusDay = Stats.key(Holidays.now) } else { Settings.shared.merchantVisits = "\(Stats.key(Holidays.now)):\(doneToday + 1)" }
        Settings.shared.merchantLastAt = Date()
    }
}

/// The merchant at the camp: where it stands and walks, and its visit.
final class MerchantDesk {
    enum Phase { case away, coming, here, going }
    private(set) var visit: MerchantVisitInfo?
    /// A camp of its own made this visit (not the server).
    private(set) var local = false
    var phase = Phase.away
    var pos = CGPoint.zero
    var stall = CGPoint.zero
    var exit = CGPoint.zero
    var legPhase = 0.0
    var facingRight = true
    /// Waiting for the server's answer.
    var asking = false
    /// Said that it is about to leave.
    var warned = false
    /// The last visit the camp was told about.
    var announced = ""
    /// Called when the visit changed (the trade window refreshes).
    var onChange: (() -> Void)?

    func show(_ visit: MerchantVisitInfo?, local: Bool) {
        let changed = visit != self.visit
        self.visit = visit
        self.local = local
        if changed { onChange?() }
    }

    func bought(_ offer: Int) {
        guard var visit, !visit.bought.contains(offer) else { return }
        visit.bought.append(offer)
        self.visit = visit
        onChange?()
    }
}

/// What the merchant asks of the server (the app does the asking: AppDelegate), and the answer in words.
enum MerchantRequest {
    case arrive
    case trade(visit: String, offer: Int)
}

enum MerchantAnswer {
    case success(String)
    case failure(String)
}

extension Colony {
    private static let walkSpeed = 38.0

    /// Once a frame: the merchant comes when the day's plan says so, walks in, stays, and leaves.
    func updateMerchant(dt: Double) {
        let desk = merchant
        // a visit on the books (ours, or one another of the account's Macs brought) is shown here too
        if followsBooks, !desk.asking, let books = booksMerchant, books.leaves > Date(), desk.visit?.id != books.id || desk.visit?.bought != books.bought {
            desk.show(books, local: false)
        }
        if let visit = desk.visit {
            if desk.phase == .away { comeIn() }
            if desk.announced != visit.id { // tell the player (once per visit)
                if onAnnounce?(arrivalLine(visit)) == true { desk.announced = visit.id }
            }
            let left = visit.leaves.timeIntervalSinceNow
            if left < 180, left > 0, !desk.warned, onAnnounce?("\(visit.merchant)再 3 分鐘就要走囉！") == true { desk.warned = true }
            if left <= 0, desk.phase != .going {
                desk.phase = .going
                MerchantWindow.shared.close()
            }
        }
        switch desk.phase {
        case .coming, .going:
            let target = desk.phase == .coming ? desk.stall : desk.exit
            let d = hypot(target.x - desk.pos.x, target.y - desk.pos.y)
            if d < 2 {
                if desk.phase == .coming { desk.phase = .here } else { desk.phase = .away; desk.show(nil, local: false) }
            } else {
                let step = min(d, Colony.walkSpeed * dt)
                desk.facingRight = target.x >= desk.pos.x
                desk.pos.x += (target.x - desk.pos.x) / d * step
                desk.pos.y += (target.y - desk.pos.y) / d * step
                desk.legPhase += step * 0.25
            }
        default: break
        }
        if let prefix = MerchantTest.prefix { runMerchantTest(prefix) }
        // time for a visit?
        guard desk.visit == nil, desk.phase == .away, !desk.asking, !campHidden, phase == .running, MerchantPlan.due(focus: booksFocus), onAnnounce != nil else { return }
        if followsBooks {
            guard let ask = onMerchant else { return }
            desk.asking = true
            ask(.arrive) { [weak self] result in
                guard let self else { return }
                self.merchant.asking = false
                MerchantPlan.markVisit(focus: self.booksFocus) // (refused or not: today's turn is used)
                if case .success = result { self.merchant.show(self.booksMerchant, local: false) }
            }
        } else {
            let visit = MerchantRules.visit(race: Characters.current.id, stage: localStage)
            _ = exchangeLocally(give: [:], get: visit.gift)
            MerchantPlan.markVisit()
            desk.show(visit, local: true)
            onAntsChanged?()
        }
    }

    /// The look of a camp of its own (1–3), as the server counts it (shared campStage: by its peak).
    private var localStage: Int { peakAnts >= 80 ? 3 : peakAnts >= 25 ? 2 : 1 }

    private func arrivalLine(_ visit: MerchantVisitInfo) -> String {
        let gift = visit.gift.sorted { $0.key < $1.key }.map { "\(Materials.info($0.key)?.name ?? $0.key) ×\($0.value)" }.joined(separator: "、")
        let minutes = max(1, Int(visit.leaves.timeIntervalSinceNow / 60))
        return "\(visit.merchant)來到營地了！送了\(gift.isEmpty ? "一點心意" : gift)，帶了 \(visit.stock.count) 樣東西，待 \(minutes) 分鐘。點牠就能交易。"
    }

    private func comeIn() {
        guard let nest else { return }
        let area = walkable.reduce(CGRect.null) { $0.union($1) }
        let desk = merchant
        desk.stall = nearestWalkable(to: CGPoint(x: nest.x - 95, y: nest.y - 26))
        desk.exit = CGPoint(x: (area.isNull ? desk.stall.x - 300 : area.minX) - 30, y: desk.stall.y)
        desk.pos = desk.exit
        desk.phase = desk.visit.map { $0.leaves > Date() } == true ? .coming : .away
        desk.warned = false
    }

    /// Takes one of the merchant's swaps. `done` gets what happened, in words.
    func merchantTrade(_ offer: Int, done: @escaping (String) -> Void) {
        guard let visit = merchant.visit, visit.stock.indices.contains(offer), !visit.bought.contains(offer) else { return done("這個已經換過了。") }
        let deal = visit.stock[offer]
        func words(_ m: [String: Int]) -> String { m.sorted { $0.key < $1.key }.map { "\(Materials.info($0.key)?.name ?? $0.key) ×\($0.value)" }.joined(separator: "、") }
        if merchant.local || !followsBooks {
            guard exchangeLocally(give: deal.give, get: deal.get) else { return done("素材不夠：要 \(words(deal.give))。") }
            merchant.bought(offer)
            onAntsChanged?()
            return done("用 \(words(deal.give)) 換到了 \(words(deal.get))。")
        }
        guard let ask = onMerchant else { return done("現在連不上伺服器。") }
        ask(.trade(visit: visit.id, offer: offer)) { [weak self] result in
            switch result {
            case .success(let message):
                if let books = self?.booksMerchant { self?.merchant.show(books, local: false) } else { self?.merchant.bought(offer) }
                done(message)
            case .failure(let message): done(message)
            }
        }
    }
}

// MARK: - The trade window

/// The merchant's stall as a small window: each swap with what it costs (and what the camp has), and a button.
final class MerchantWindow: NSObject, NSWindowDelegate {
    static let shared = MerchantWindow()
    private var panel: NSPanel?
    private weak var colony: Colony?
    private var status = ""
    private var timer: Timer?

    func show(colony: Colony) {
        self.colony = colony
        colony.merchant.onChange = { [weak self] in self?.rebuild() }
        status = ""
        if panel == nil {
            let p = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 400, height: 320), styleMask: [.titled, .closable, .utilityWindow], backing: .buffered, defer: false)
            p.isReleasedWhenClosed = false
            p.level = Levels.dialog
            p.delegate = self
            panel = p
        }
        rebuild()
        panel?.center()
        NSApp.activate(ignoringOtherApps: true)
        panel?.makeKeyAndOrderFront(nil)
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 20, repeats: true) { [weak self] _ in self?.rebuild() } // (the minutes left)
    }

    func close() {
        timer?.invalidate()
        panel?.orderOut(nil)
    }

    func windowWillClose(_ notification: Notification) { timer?.invalidate() }

    private func name(_ id: String) -> String { Materials.info(id)?.name ?? id }

    private func rebuild() {
        guard let panel, let colony else { return }
        guard let visit = colony.merchant.visit else { return close() }
        let minutes = max(0, Int(visit.leaves.timeIntervalSinceNow / 60))
        panel.title = "\(visit.merchant)・還會待 \(minutes) 分鐘"
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.edgeInsets = NSEdgeInsets(top: 14, left: 16, bottom: 14, right: 16)
        let intro = NSTextField(wrappingLabelWithString: "想換什麼？每樣只能換一次。")
        intro.textColor = .secondaryLabelColor
        stack.addArrangedSubview(intro)
        let have = colony.materials
        for (k, offer) in visit.stock.enumerated() {
            let row = NSStackView()
            row.orientation = .horizontal
            row.spacing = 10
            let cost = offer.give.sorted { $0.key < $1.key }.map { "\(name($0.key)) ×\($0.value)（有 \(have[$0.key, default: 0])）" }.joined(separator: "、")
            let gets = offer.get.sorted { $0.key < $1.key }.map { "\(name($0.key)) ×\($0.value)" }.joined(separator: "、")
            let text = NSTextField(wrappingLabelWithString: "\(offer.rare == true ? "【稀有】" : "")\(offer.sale == true ? "【特價】" : "")\(cost)\n→ \(gets)")
            text.font = .systemFont(ofSize: 12)
            text.preferredMaxLayoutWidth = 290
            text.translatesAutoresizingMaskIntoConstraints = false
            text.widthAnchor.constraint(equalToConstant: 290).isActive = true
            let bought = visit.bought.contains(k)
            let affordable = offer.give.allSatisfy { have[$0.key, default: 0] >= $0.value }
            let button = NSButton(title: bought ? "換過了" : "換", target: self, action: #selector(trade(_:)))
            button.tag = k
            button.isEnabled = !bought && affordable
            button.bezelStyle = .rounded
            row.addArrangedSubview(text)
            row.addArrangedSubview(button)
            stack.addArrangedSubview(row)
        }
        if !status.isEmpty {
            let line = NSTextField(wrappingLabelWithString: status)
            line.textColor = .systemGreen
            stack.addArrangedSubview(line)
        }
        intro.preferredMaxLayoutWidth = 360
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.widthAnchor.constraint(equalToConstant: 400).isActive = true
        let size = stack.fittingSize
        panel.contentView = stack
        panel.setContentSize(NSSize(width: 400, height: size.height))
        stack.layoutSubtreeIfNeeded()
    }

    @objc private func trade(_ sender: NSButton) {
        sender.isEnabled = false
        colony?.merchantTrade(sender.tag) { [weak self] message in
            self?.status = message
            self?.rebuild()
        }
    }
}

// MARK: - Test (`CAMP_TEST_MERCHANT=/path/prefix`, with `CAMP_MERCHANT_AT=seconds`)

/// Once the merchant is at its stall: draws the camp (`-camp.png`), opens the stall (`-stall.png`), swaps the first thing the camp
/// can pay for and draws the stall again (`-traded.png`), then quits.
enum MerchantTest {
    static let prefix = ProcessInfo.processInfo.environment["CAMP_TEST_MERCHANT"]
    static var step = 0
    static var at = Date.distantFuture
}

extension Colony {
    fileprivate func runMerchantTest(_ prefix: String) {
        func shootWindow(_ window: NSWindow?, _ path: String) {
            guard let view = window?.contentView, let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
            view.cacheDisplay(in: view.bounds, to: rep)
            try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
        }
        let camp = NSApp.windows.first { ($0.contentView as? AntView)?.isMap == true }
        switch MerchantTest.step {
        case 0 where merchant.phase == .here:
            MerchantTest.step = 1
            MerchantTest.at = Date()
            print("merchant test: \(merchant.visit?.merchant ?? "?") at its stall, gift \(merchant.visit?.gift ?? [:]), stock \(merchant.visit?.stock.count ?? 0), materials \(materials)")
            fflush(stdout)
            shootWindow(camp, prefix + "-camp.png")
            MerchantWindow.shared.show(colony: self)
        case 1 where Date().timeIntervalSince(MerchantTest.at) > 1.5:
            MerchantTest.step = 2
            shootWindow(NSApp.windows.first { $0 is NSPanel && $0.isVisible }, prefix + "-stall.png")
            if let visit = merchant.visit, let k = visit.stock.firstIndex(where: { $0.give.allSatisfy { materials[$0.key, default: 0] >= $0.value } }) {
                merchantTrade(k) { message in print("merchant test: traded \(k): \(message)"); fflush(stdout) }
            } else {
                print("merchant test: nothing affordable")
            }
        case 2 where Date().timeIntervalSince(MerchantTest.at) > 3:
            MerchantTest.step = 3
            shootWindow(NSApp.windows.first { $0 is NSPanel && $0.isVisible }, prefix + "-traded.png")
            print("merchant test: materials now \(materials), bought \(merchant.visit?.bought ?? [])")
            fflush(stdout)
            NSApp.terminate(nil)
        default: break
        }
    }
}
