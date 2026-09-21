import CoreGraphics
import Foundation

// The princess's love life. See ROMANCE.md for the whole story and the numbers.
//
// A golden goblin may (after the first day or two, at a random time) start to court her. It goes well or badly, by chance and by how
// well the two get on ("chemistry"). Together they walk, hug, go for outings with guards, spend the night talking in bed, quarrel,
// make up or split up. They may marry, and she may then have a half-human child. Everything is gentle and stays in view of the
// whole camp; nothing more than holding hands, hugging and talking is ever shown.

/// Where things stand. Saved with the camp.
struct RomanceState: Codable {
    enum Stage: String, Codable { case single, courting, dating, married }

    var stage: Stage = .single
    var partnerID: Int?
    var partnerName = ""
    /// How well the two get on (fixed for the pair): it tilts most things in their story.
    var chemistry = 0.5
    /// 0...100.
    var affection = 0.0
    /// Small happenings since the stage began.
    var beats = 0
    /// Story time in seconds (real time while the app runs, times `CAMP_ROMANCE_SCALE`).
    var clock = 0.0
    var nextBeatAt = 0.0
    /// Game time (`Colony.playSeconds`) before the next courtship may start; nil = not yet decided.
    var nextSuitorAt: Double?
    /// They are not speaking until then (story time).
    var coldUntil = 0.0
    /// Story time when the pregnancy began, and how long it lasts.
    var pregnancy: Double?
    var pregnancyLength = 0.0
    /// Who the father is (kept, in case he is gone by the time it is born).
    var fatherName = ""
    var children = 0
    /// Golden goblins she has been with (and left) or refused.
    var exes: [Int] = []
    var lastSuitorID: Int?
    var lastBedNight = 0
    var nextOutingAt = 0.0
    var nextProposalBeat = 14

    init() {}

    private enum Keys: String, CodingKey {
        case stage, partnerID, partnerName, chemistry, affection, beats, clock, nextBeatAt, nextSuitorAt, coldUntil, pregnancy, pregnancyLength, fatherName
        case children, exes, lastSuitorID, lastBedNight, nextOutingAt, nextProposalBeat
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        stage = try c.decodeIfPresent(Stage.self, forKey: .stage) ?? .single
        partnerID = try c.decodeIfPresent(Int.self, forKey: .partnerID)
        partnerName = try c.decodeIfPresent(String.self, forKey: .partnerName) ?? ""
        chemistry = try c.decodeIfPresent(Double.self, forKey: .chemistry) ?? 0.5
        affection = try c.decodeIfPresent(Double.self, forKey: .affection) ?? 0
        beats = try c.decodeIfPresent(Int.self, forKey: .beats) ?? 0
        clock = try c.decodeIfPresent(Double.self, forKey: .clock) ?? 0
        nextBeatAt = try c.decodeIfPresent(Double.self, forKey: .nextBeatAt) ?? 0
        nextSuitorAt = try c.decodeIfPresent(Double.self, forKey: .nextSuitorAt)
        coldUntil = try c.decodeIfPresent(Double.self, forKey: .coldUntil) ?? 0
        pregnancy = try c.decodeIfPresent(Double.self, forKey: .pregnancy)
        pregnancyLength = try c.decodeIfPresent(Double.self, forKey: .pregnancyLength) ?? 0
        fatherName = try c.decodeIfPresent(String.self, forKey: .fatherName) ?? ""
        children = try c.decodeIfPresent(Int.self, forKey: .children) ?? 0
        exes = try c.decodeIfPresent([Int].self, forKey: .exes) ?? []
        lastSuitorID = try c.decodeIfPresent(Int.self, forKey: .lastSuitorID)
        lastBedNight = try c.decodeIfPresent(Int.self, forKey: .lastBedNight) ?? 0
        nextOutingAt = try c.decodeIfPresent(Double.self, forKey: .nextOutingAt) ?? 0
        nextProposalBeat = try c.decodeIfPresent(Int.self, forKey: .nextProposalBeat) ?? 14
    }
}

/// What is going on right now (not saved).
struct RomanceRuntime {
    enum Outing { case none, out(CGPoint), stay(until: Double), back }

    /// The scene in progress (its kind, and when it is over in story time), and whether we are waiting for one to end.
    var scene: SceneKind?
    var sceneUntil = 0.0
    /// Guards walking with her on an outing.
    var guards: [Int] = []
    var outing = Outing.none
    /// Hearts (or a stormcloud) over her for this many more seconds.
    var glow = 0.0
    var sulk = 0.0
    /// The partner is lying in the bed beside her.
    var inBed = false
    var debugApplied = false
    var checkTimer = 0.0
}

enum Romance {
    /// `CAMP_ROMANCE_SCALE` makes the story go faster (tests). Never below 1 by default.
    static let speed: Double = {
        if let s = ProcessInfo.processInfo.environment["CAMP_ROMANCE_SCALE"], let v = Double(s), v > 0 { return v }
        return 1
    }()
    /// `CAMP_ROMANCE=now` lets the first courtship start at once; without it nothing starts during the first day of game time.
    static let hurry = ProcessInfo.processInfo.environment["CAMP_ROMANCE"] == "now"
    /// `CAMP_ROMANCE_FORCE=outing` makes every beat an outing (tests).
    static let force = ProcessInfo.processInfo.environment["CAMP_ROMANCE_FORCE"]
    static let day = 86_400.0
    /// Where the partner lies when they share the bed, relative to her.
    static let bedOffset = CGPoint(x: 46, y: 9)

    static func random(_ range: ClosedRange<Double>) -> Double { Double.random(in: range) }
}

extension Colony {
    // MARK: What to show

    /// One line for the roster.
    var romanceSummary: String {
        let name = princessName.isEmpty ? "公主" : princessName
        var line: String
        switch romance.stage {
        case .single: line = "\(name)：單身"
        case .courting: line = "\(name)：\(romance.partnerName) 正在追求她"
        case .dating: line = "\(name)：和 \(romance.partnerName) 交往中（好感 \(Int(romance.affection))）"
        case .married: line = "\(name)：和 \(romance.partnerName) 結婚了（好感 \(Int(romance.affection))）"
        }
        if let began = romance.pregnancy, romance.pregnancyLength > 0 {
            line += "，懷孕 \(min(100, Int((romance.clock - began) / romance.pregnancyLength * 100)))%"
        }
        if romance.children > 0 { line += "，孩子 \(romance.children) 個" }
        if romance.stage != .single, romance.coldUntil > romance.clock { line += "（冷戰中）" }
        return line
    }

    // MARK: The story

    private var princess: String { princessName.isEmpty ? "公主" : princessName }
    private var maternityIDs: (early: Int?, late: Int?) {
        let outfits = Characters.current.outfits
        return (outfits.firstIndex { $0.id == "maternity1" }, outfits.firstIndex { $0.id == "maternity2" })
    }

    private func log(_ text: String) {
        if ProcessInfo.processInfo.environment["CAMP_DEBUG"] != nil { NSLog("GoblinCamp romance: \(text)") }
    }

    private func say(_ text: String, near point: CGPoint? = nil, rarity: Rarity = .uncommon) {
        guard let where_ = point ?? queen?.pos else { return }
        addFloater(text, rarity, at: CGPoint(x: where_.x, y: where_.y + 30), important: true)
        log(text)
    }

    /// Called every tick, before the goblins move: runs the story and says where the company should stand.
    func updateRomance(dt: Double, world: inout AntWorld) {
        guard let queen, queen.arrived, !queen.isCarried, !campHidden else { return }
        romance.clock += dt * Romance.speed
        romanceRuntime.glow = max(0, romanceRuntime.glow - dt)
        romanceRuntime.sulk = max(0, romanceRuntime.sulk - dt)
        if !romanceRuntime.debugApplied { applyDebugStage() }
        maintainPregnancy() // (she may be expecting even if the father is gone)

        if romance.stage == .single {
            releaseCompany()
            considerSuitor()
            return
        }
        guard let pi = ants.firstIndex(where: { $0.id == romance.partnerID }), !ants[pi].isDying else {
            partnerGone(dead: true)
            return
        }

        let danger = princessInDanger
        if danger, romanceRuntime.scene != nil || romanceRuntime.inBed { endScene() }
        if romanceRuntime.scene != nil, self.queen?.scene == nil { endScene() } // (something ended it: she hid)
        if let scene = romanceRuntime.scene, romance.clock >= romanceRuntime.sceneUntil, case .bed = scene { endScene() }
        if danger || monsterNear {
            if case .none = romanceRuntime.outing {} else { abortOuting("怪物來了，趕快回營地") }
        }

        // beats: one small thing happens between them every so often
        if romanceRuntime.scene == nil, !danger, !monsterNear, romance.clock >= romance.nextBeatAt, romance.stage == .courting || self.queen?.isAvailable == true, isAttending(pi) {
            runBeat(partner: pi)
        }
        runOuting()
        runNightBed(partner: pi)
        keepCompany(partner: pi, world: &world)
    }

    // MARK: Being together on screen

    private func isAttending(_ index: Int) -> Bool {
        if case .activity(.attend, _) = ants[index].mode { return true }
        return false
    }

    /// Everybody who keeps her company gets a place to stand; the partner is asked to come if it is free.
    private func keepCompany(partner pi: Int, world: inout AntWorld) {
        guard let queen else { return }
        let qp = queen.pos
        let h = queen.heading
        let side = CGPoint(x: cos(h - .pi / 2), y: sin(h - .pi / 2))
        let back = CGPoint(x: -cos(h), y: -sin(h))
        func clamped(_ p: CGPoint) -> CGPoint {
            guard let rect = world.walkable.first(where: { $0.contains(qp) }) ?? world.walkable.first else { return p }
            return CGPoint(x: min(max(p.x, rect.minX + 10), rect.maxX - 10), y: min(max(p.y, rect.minY + 10), rect.maxY - 10))
        }
        var offset = romance.stage == .courting ? CGPoint(x: 34, y: -4) : CGPoint(x: 17, y: -3)
        var target: CGPoint?
        let cold = romance.stage != .courting && romance.clock < romance.coldUntil
        switch romanceRuntime.scene {
        case .walk?: target = CGPoint(x: qp.x + side.x * 15 + back.x * 4, y: qp.y + side.y * 15 + back.y * 4)
        case .hug?: offset = CGPoint(x: 15, y: 0)
        case .quarrel?: offset = CGPoint(x: 46, y: 4)
        case .wedding?: offset = CGPoint(x: 17, y: 0)
        case .bed?: offset = Romance.bedOffset
        case nil: if cold { offset = CGPoint(x: 58, y: 10) }
        }
        let spot = clamped(target ?? CGPoint(x: qp.x + offset.x, y: qp.y + offset.y))
        world.attendFace = qp
        // the partner
        if !ants[pi].isWounded, !ants[pi].isChild, !monsterNear, canJoin(ants[pi]) { ants[pi].begin(.attend, world: world) }
        if isAttending(pi) { world.attendTargets[ants[pi].id] = spot }
        // lying in bed once there (and getting up again afterwards)
        if case .bed? = romanceRuntime.scene {
            let arrived = hypot(ants[pi].pos.x - spot.x, ants[pi].pos.y - spot.y) < 4
            ants[pi].lying = arrived
            romanceRuntime.inBed = arrived
        } else if ants[pi].lying || romanceRuntime.inBed {
            ants[pi].lying = false
            romanceRuntime.inBed = false
        }
        // the guards, a little behind and to the sides
        for (k, id) in romanceRuntime.guards.enumerated() {
            guard let gi = ants.firstIndex(where: { $0.id == id }), isAttending(gi) else { continue }
            let lateral: CGFloat = k % 2 == 0 ? 1 : -1
            let spread = CGFloat(20 + 12 * (k / 2))
            world.attendTargets[id] = clamped(CGPoint(x: qp.x + back.x * (34 + CGFloat(k / 2) * 14) + side.x * lateral * spread,
                                                     y: qp.y + back.y * (34 + CGFloat(k / 2) * 14) + side.y * lateral * spread))
        }
    }

    /// He drops what he is doing (walking about, resting a while, fishing, reading…) to be with her; not while hunting, hauling or hidden in the nest.
    private func canJoin(_ ant: Ant) -> Bool {
        switch ant.mode {
        case .wandering, .returningToNest, .foraging: return true
        case .activity(let kind, _): if case .attend = kind { return false } else { return true }
        default: return false
        }
    }

    /// Everybody but the partner goes back to what they were doing.
    private func releaseCompany() {
        for i in ants.indices {
            if case .activity(.attend, _) = ants[i].mode { ants[i].mode = .wandering }
            ants[i].lying = false
        }
        romanceRuntime.guards = []
        romanceRuntime.inBed = false
    }

    private func endScene() {
        romanceRuntime.scene = nil
        romanceRuntime.inBed = false
        queen?.endScene()
    }

    // MARK: Meeting

    /// Between stories: after a day or two of game time, and then at some random moment, a golden goblin starts to court her.
    private func considerSuitor() {
        if romance.nextSuitorAt == nil {
            romance.nextSuitorAt = Romance.hurry ? 0 : playSeconds + Romance.day + Romance.random(0...(2.5 * Romance.day)) // not in the first day; maybe not for days
        }
        romanceRuntime.checkTimer -= 1
        guard let due = romance.nextSuitorAt, playSeconds >= due, ants.count >= 12 || Romance.hurry, !princessInDanger, !monsterNear else { return }
        let goldenIDs = breeds.indices.filter { breeds[$0].id == "golden" }
        var candidates = ants.indices.filter { i in
            let a = ants[i]
            return goldenIDs.contains(a.breedIndex) && !a.isChild && !a.isDying && !a.isWounded && !a.female && a.lifeFraction < 0.55 && !romance.exes.contains(a.id)
                && !a.isCarryingPrincess
        }
        if candidates.count > 1, let last = romance.lastSuitorID { candidates.removeAll { ants[$0].id == last } }
        guard let pick = candidates.randomElement() else {
            romance.nextSuitorAt = playSeconds + (Romance.hurry ? 2 : Romance.random(1200...5400)) // nobody suitable yet; look again later
            return
        }
        romance.stage = .courting
        romance.partnerID = ants[pick].id
        romance.partnerName = ants[pick].name
        romance.chemistry = ProcessInfo.processInfo.environment["CAMP_ROMANCE_CHEM"].flatMap(Double.init) ?? Romance.random(0.2...0.95)
        romance.affection = Romance.random(18...34)
        romance.beats = 0
        romance.nextBeatAt = romance.clock + Romance.random(12...25)
        romance.lastSuitorID = ants[pick].id
        romanceRuntime.scene = nil
        say("\(ants[pick].name) 開始偷偷關心\(princess)")
        romanceRuntime.glow = 4
    }

    // MARK: Beats

    private func runBeat(partner pi: Int) {
        let now = romance.clock
        switch romance.stage {
        case .single: return
        case .courting: courtBeat(partner: pi)
        case .dating, .married:
            if now < romance.coldUntil { romance.nextBeatAt = romance.coldUntil; return } // not speaking
            if romance.coldUntil > 0, now >= romance.coldUntil { romance.coldUntil = 0; makeUpOrNot(); return }
            togetherBeat(partner: pi)
        }
    }

    /// One awkward, sweet or unlucky moment of the courtship.
    private func courtBeat(partner pi: Int) {
        let name = ants[pi].name
        let delta = (romance.chemistry - 0.45) * 9 + Romance.random(-4...6)
        romance.affection = min(100, max(0, romance.affection + delta))
        romance.beats += 1
        romance.nextBeatAt = romance.clock + Romance.random(25...50)
        let pos = ants[pi].pos
        if delta > 3 {
            say(["\(name) 摘了一朵花給她", "\(name) 幫她提了東西", "\(name) 說了個笑話，她笑了"].randomElement()!, near: pos)
            romanceRuntime.glow = 5
        } else if delta > 0 {
            say(["\(name) 默默陪在她旁邊", "\(name) 偷看了她一眼"].randomElement()!, near: pos, rarity: .common)
            romanceRuntime.glow = 3
        } else if delta > -3 {
            say(["\(name) 緊張得說不出話", "\(name) 差點被自己絆倒"].randomElement()!, near: pos, rarity: .common)
        } else {
            say(["\(name) 說錯了話，她皺起眉頭", "\(name) 送的禮物不太對…"].randomElement()!, near: pos, rarity: .common)
            romanceRuntime.sulk = 4
        }
        log("courting beat \(romance.beats): affection \(Int(romance.affection)) (chemistry \(String(format: "%.2f", romance.chemistry)))")

        if romance.affection <= 4 {
            say("\(princess)拒絕了 \(name)")
            endStory(reason: "被拒絕了", waitDays: 0.5...1.5, remember: false)
        } else if romance.beats >= 8, romance.affection >= 58 {
            romance.stage = .dating
            romance.beats = 0
            romance.nextBeatAt = romance.clock + Romance.random(8...16)
            romance.nextProposalBeat = Int.random(in: 12...20)
            say("\(princess)接受了 \(name) 的心意！", rarity: .rare)
            romanceRuntime.glow = 8
            startScene(.hug, seconds: 7)
        } else if romance.beats >= 13 {
            say("\(princess)委婉地拒絕了 \(name)")
            endStory(reason: "沒有結果", waitDays: 0.5...1.5, remember: false)
        }
    }

    /// A date, a hug, an outing… or a quarrel.
    private func togetherBeat(partner pi: Int) {
        let married = romance.stage == .married
        let name = ants[pi].name
        romance.beats += 1
        romance.nextBeatAt = romance.clock + Romance.random(married ? 60...110 : 40...80)
        if Romance.force == "bed" { return } // (nothing else happens, so the night can be watched)
        let quarrelChance = max(0.03, min(0.25, 0.08 + (0.5 - romance.chemistry) * 0.2)) * (married ? 0.6 : 1)
        if Romance.force == nil, Double.random(in: 0..<1) < quarrelChance {
            quarrel()
            return
        }
        let good = Romance.random(1...4) + (romance.chemistry - 0.5) * 3
        romance.affection = min(100, romance.affection + good)

        // an engagement, once they have been together a while and it is going well
        if !married, romance.beats >= romance.nextProposalBeat, romance.affection >= 76, Double.random(in: 0..<1) < 0.3 {
            propose(name: name)
            return
        }
        // a child, for a married couple
        if married, romance.pregnancy == nil, romance.children < 3, romance.beats >= 5, romance.clock >= romance.nextOutingAt - 300,
           Double.random(in: 0..<1) < 0.085 * min(1.4, 0.6 + romance.affection / 100) {
            romance.pregnancy = romance.clock
            romance.pregnancyLength = Romance.random(1800...2700)
            romance.fatherName = romance.partnerName
            say("\(princess)有喜了！", rarity: .rare)
            romanceRuntime.glow = 8
            maintainPregnancy()
            return
        }
        let expecting = romance.pregnancy != nil
        var options: [(String, Double)] = [("walk", 3), ("hug", 2), ("gift", 1)]
        if romance.beats >= 4, romance.clock >= romance.nextOutingAt { options.append(("outing", expecting ? 0.5 : 1.3)) }
        var roll = Double.random(in: 0..<options.reduce(0) { $0 + $1.1 })
        var choice = options[0].0
        for (kind, weight) in options { roll -= weight; if roll < 0 { choice = kind; break } }
        if let forced = Romance.force { choice = forced }
        switch choice {
        case "hug":
            say(["\(name) 抱了抱\(princess)", "\(princess)靠在 \(name) 肩上"].randomElement()!, rarity: .common)
            startScene(.hug, seconds: Romance.random(6...9))
        case "gift":
            say(["\(name) 送了她一朵花", "\(name) 摘了野果給她", "\(name) 為她做了個小花環"].randomElement()!, rarity: .common)
            romanceRuntime.glow = 5
        case "outing":
            beginOuting()
        default:
            say(["\(name) 牽著\(princess)散步", "\(princess)和 \(name) 手牽手走走"].randomElement()!, rarity: .common)
            if let target = strollTarget() { startScene(.walk(to: target), seconds: 30) }
        }
        log("beat \(romance.beats): \(choice), affection \(Int(romance.affection))")
    }

    private func quarrel() {
        let married = romance.stage == .married
        let name = romance.partnerName
        romance.affection = max(0, romance.affection - Romance.random(8...18))
        say(["\(princess)和 \(name) 吵架了", "\(princess)在生 \(name) 的氣", "\(name) 惹她不開心了"].randomElement()!, rarity: .common)
        romanceRuntime.sulk = 8
        startScene(.quarrel, seconds: Romance.random(7...10))
        romance.coldUntil = romance.clock + Romance.random(90...240)
        log("quarrel: affection \(Int(romance.affection))")
        if romance.affection < (married ? 10 : 22) { splitUp() }
    }

    /// The cold spell is over: they make up, or it drags on.
    private func makeUpOrNot() {
        let name = romance.partnerName
        if Double.random(in: 0..<1) < 0.35 + romance.affection / 200 {
            romance.affection = min(100, romance.affection + 6)
            say("\(princess)和 \(name) 和好了", rarity: .uncommon)
            romanceRuntime.glow = 6
            startScene(.hug, seconds: 8)
            romance.nextBeatAt = romance.clock + Romance.random(30...60)
        } else {
            romance.affection = max(0, romance.affection - 4)
            romance.coldUntil = romance.clock + Romance.random(60...150)
            log("still cold: affection \(Int(romance.affection))")
            if romance.affection < (romance.stage == .married ? 10 : 22) { splitUp() }
        }
    }

    private func propose(name: String) {
        say("\(name) 向\(princess)求婚了！", rarity: .rare)
        romance.nextProposalBeat = romance.beats + Int.random(in: 6...12)
        let accept = min(0.92, 0.3 + romance.affection / 160 + romance.chemistry * 0.25)
        if Double.random(in: 0..<1) < accept {
            romance.stage = .married
            romance.beats = 0
            romance.nextBeatAt = romance.clock + 20
            say("婚禮！全營地都在慶祝", rarity: .rare)
            romanceRuntime.glow = 10
            startScene(.wedding, seconds: 14)
        } else {
            romance.affection = max(0, romance.affection - 12)
            romance.coldUntil = romance.clock + Romance.random(60...120)
            say("\(princess)還沒準備好…", rarity: .common)
            romanceRuntime.sulk = 5
        }
    }

    // MARK: Outings

    private func strollTarget() -> CGPoint? {
        guard let queen else { return nil }
        for _ in 0..<12 {
            let angle = Double.random(in: 0..<(2 * .pi)), r = Double.random(in: 40...90)
            let p = CGPoint(x: queen.pos.x + cos(angle) * r, y: queen.pos.y + sin(angle) * r)
            if walkable.contains(where: { $0.insetBy(dx: 30, dy: 30).contains(p) }) { return p }
        }
        return nil
    }

    /// A day out, further from the camp than she normally goes, with guards along.
    private func beginOuting() {
        guard let nest, let queen else { return }
        if case .none = romanceRuntime.outing {} else { return } // (already out)
        romance.nextOutingAt = romance.clock + Romance.random(300...600) // (not now: try again a bit later)
        guard !Colony.isNight, !isRaining, !creatures.contains(where: { $0.kind.hostile }) else { return }
        let pi = ants.firstIndex { $0.id == romance.partnerID }
        let free = ants.indices.filter { i in
            i != pi && !ants[i].isChild && !ants[i].isWounded && !ants[i].isDying && !ants[i].isCarryingPrincess && !ants[i].female
                && { if case .wandering = ants[i].mode { return true } else { return false } }()
        }
        let ranked = free.sorted { ants[$0].might > ants[$1].might } // the strongest go
        guard let first = ranked.first else { return }
        var guardIndices = [first]
        if ranked.count > 1, Double.random(in: 0..<1) < 0.6 { guardIndices.append(ranked[1]) }
        var target: CGPoint?
        for _ in 0..<16 {
            let angle = Double.random(in: 0..<(2 * .pi)), r = Double.random(in: 160...300)
            let p = CGPoint(x: nest.x + cos(angle) * r, y: nest.y + sin(angle) * r)
            if walkable.contains(where: { $0.insetBy(dx: 60, dy: 60).contains(p) }), hypot(p.x - queen.pos.x, p.y - queen.pos.y) > 120 { target = p; break }
        }
        guard let target else { return }
        romance.nextOutingAt = romance.clock + Romance.random(900...2400)
        romanceRuntime.guards = guardIndices.map { ants[$0].id }
        for i in guardIndices { ants[i].begin(.attend, world: worldForBegin()) }
        self.queen?.setHome(target)
        romanceRuntime.outing = .out(target)
        startScene(.walk(to: target), seconds: 40)
        say("\(romance.partnerName) 帶\(princess)出去走走，護衛跟著", rarity: .uncommon)
        log("outing to \(target), guards \(romanceRuntime.guards)")
    }

    private func worldForBegin() -> AntWorld {
        AntWorld(nest: nest ?? .zero, walkable: walkable, foods: [], creatures: [], foodScale: 1)
    }

    private func runOuting() {
        switch romanceRuntime.outing {
        case .none: break
        case .out:
            if romanceRuntime.scene == nil { // she got there
                romanceRuntime.outing = .stay(until: romance.clock + Romance.random(60...160))
                say("\(princess)在這裡休息了一會兒", rarity: .common)
                romance.affection = min(100, romance.affection + Romance.random(2...5))
                romanceRuntime.glow = 5
            }
        case .stay(let until):
            if romance.clock >= until, romanceRuntime.scene == nil, queen?.isAvailable == true {
                romanceRuntime.outing = .back
                if let nest { queen?.resetHome(nest: nest, walkable: walkable) }
                if let home = queen?.homePoint { startScene(.walk(to: home), seconds: 40) }
            }
        case .back:
            if romanceRuntime.scene == nil {
                romanceRuntime.outing = .none
                romanceRuntime.guards = []
                for i in ants.indices { if case .activity(.attend, _) = ants[i].mode, ants[i].id != romance.partnerID { ants[i].mode = .wandering } }
                say("回到營地了", rarity: .common)
            }
        }
        // the guards are gone (hurt, or called away): nobody to keep her safe out here
        if !romanceRuntime.guards.isEmpty, !romanceRuntime.guards.contains(where: { id in ants.first { $0.id == id }.map { isAttendingAnt($0) } ?? false }) {
            abortOuting("護衛不見了，趕快回營地")
        }
    }

    private func isAttendingAnt(_ ant: Ant) -> Bool {
        if case .activity(.attend, _) = ant.mode { return true }
        return false
    }

    /// Something is wrong out there: straight home, and the guards fall in behind.
    private func abortOuting(_ why: String) {
        if case .back = romanceRuntime.outing { return }
        if case .none = romanceRuntime.outing { return }
        say(why, rarity: .common)
        romanceRuntime.outing = .back
        if let nest { queen?.resetHome(nest: nest, walkable: walkable) }
        endScene()
        if let home = queen?.homePoint { startScene(.walk(to: home), seconds: 40) }
    }

    // MARK: Nights

    /// At night, a couple who are on good terms go to bed together and talk until they fall asleep.
    private func runNightBed(partner pi: Int) {
        guard Colony.isNight, romanceRuntime.scene == nil, romance.clock >= romance.coldUntil, romance.stage != .courting else { return }
        romanceRuntime.checkTimer -= 1
        guard romanceRuntime.checkTimer <= 0 else { return }
        romanceRuntime.checkTimer = 300 // (ticks: about every five seconds)
        let hour = Calendar.current.component(.hour, from: Date())
        let night = (Calendar.current.ordinality(of: .day, in: .era, for: Date()) ?? 0) - (hour < 6 ? 1 : 0)
        guard romance.lastBedNight != night, Double.random(in: 0..<1) < 0.35, queen?.isAvailable == true, case .none = romanceRuntime.outing,
              isAttending(pi), let q = queen, hypot(ants[pi].pos.x - q.pos.x, ants[pi].pos.y - q.pos.y) < 220 else { return }
        romance.lastBedNight = night
        let length = Romance.random(45...80)
        if startScene(.bed, seconds: length) {
            say("晚上了，\(princess)和 \(romance.partnerName) 一起回去睡覺，說著悄悄話", rarity: .common)
            romance.affection = min(100, romance.affection + Romance.random(1...3))
        }
    }

    // MARK: Scenes

    @discardableResult
    private func startScene(_ kind: SceneKind, seconds: Double) -> Bool {
        guard queen?.isAvailable == true || romanceRuntime.scene == nil, queen?.startScene(kind, duration: seconds) == true else { return false }
        romanceRuntime.scene = kind
        romanceRuntime.sceneUntil = romance.clock + seconds * Romance.speed
        return true
    }

    // MARK: Endings

    private func splitUp() {
        let married = romance.stage == .married
        let name = romance.partnerName
        say(married ? "\(princess)和 \(name) 離婚了…" : "\(princess)和 \(name) 分手了…", rarity: .rare)
        endStory(reason: married ? "離婚" : "分手", waitDays: married ? 2...4 : 1...2, remember: true)
    }

    /// The partner has died or gone.
    private func partnerGone(dead: Bool) {
        if romance.partnerID != nil { say("\(romance.partnerName) 不在了…", rarity: .rare) }
        endStory(reason: "離世", waitDays: 2...3.5, remember: true)
    }

    private func endStory(reason: String, waitDays: ClosedRange<Double>, remember: Bool) {
        log("story over: \(reason)")
        if remember, let id = romance.partnerID { romance.exes.append(id) }
        endScene()
        if case .none = romanceRuntime.outing {} else {
            romanceRuntime.outing = .none
            if let nest { queen?.resetHome(nest: nest, walkable: walkable) }
        }
        releaseCompany()
        romance.stage = .single
        romance.partnerID = nil
        romance.partnerName = ""
        romance.affection = 0
        romance.beats = 0
        romance.coldUntil = 0
        romance.nextSuitorAt = playSeconds + Romance.random(waitDays.lowerBound * Romance.day...(waitDays.upperBound * Romance.day))
        romanceRuntime.sulk = 6
    }

    // MARK: Pregnancy

    /// Keeps the right maternity dress on her (a little belly at first, a bigger one later) and brings the child when it is time.
    private func maintainPregnancy() {
        guard let began = romance.pregnancy, romance.pregnancyLength > 0 else { return }
        let fraction = (romance.clock - began) / romance.pregnancyLength
        let (early, late) = maternityIDs
        if let wanted = fraction < 0.45 ? early : late, outfitIndex != wanted { outfitIndex = wanted }
        if fraction >= 1, queen?.isAvailable == true, !princessInDanger { giveBirth() }
    }

    private func giveBirth() {
        guard let queen else { return }
        let roll = Double.random(in: 0..<1)
        let id = roll < 0.35 ? "half_gob" : roll < 0.65 ? "half_mix" : "half_hum" // it may take after either of them
        let index = breeds.firstIndex { $0.id == id } ?? breeds.firstIndex { $0.id == "golden" } ?? 0
        var baby = makeAnt(at: CGPoint(x: queen.pos.x + 12, y: queen.pos.y - 4), breedIndex: index, age: 0)
        baby.parents = "\(princess) × \(romance.fatherName.isEmpty ? romance.partnerName : romance.fatherName)"
        ants.append(baby)
        romance.pregnancy = nil
        romance.children += 1
        outfitIndex = 0
        let kind = baby.female ? "女孩" : "男孩"
        say("\(princess)生下了一個\(kind)：\(baby.name)（\(breeds[index].name)）", rarity: .rare)
        romanceRuntime.glow = 10
        if ants.count > peakAnts { peakAnts = ants.count }
        onAntsChanged?()
    }

    // MARK: Testing

    /// `CAMP_ROMANCE_STAGE=courting|dating|married|pregnant` starts the story at that point (needs a golden goblin in the camp).
    private func applyDebugStage() {
        guard let stage = ProcessInfo.processInfo.environment["CAMP_ROMANCE_STAGE"] else { romanceRuntime.debugApplied = true; return }
        let goldenIDs = breeds.indices.filter { breeds[$0].id == "golden" }
        guard let i = ants.firstIndex(where: { goldenIDs.contains($0.breedIndex) && !$0.isChild && !$0.female }) else { return } // wait for one to be born
        romanceRuntime.debugApplied = true
        romance.partnerID = ants[i].id
        romance.partnerName = ants[i].name
        romance.chemistry = ProcessInfo.processInfo.environment["CAMP_ROMANCE_CHEM"].flatMap(Double.init) ?? 0.8
        romance.affection = 85
        romance.nextBeatAt = romance.clock + 5
        switch stage {
        case "courting": romance.stage = .courting; romance.affection = 30
        case "dating": romance.stage = .dating; romance.beats = 6
        case "married": romance.stage = .married; romance.beats = 8
        case "pregnant":
            romance.stage = .married
            romance.beats = 8
            romance.pregnancy = romance.clock - romance.pregnancyLength * 0.6
            romance.pregnancyLength = 1800
            romance.pregnancy = romance.clock - 1800 * 0.6
            romance.fatherName = romance.partnerName
        default: break
        }
    }
}
