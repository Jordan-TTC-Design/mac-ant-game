import AppKit

/// The big world as the camp sees it (LIFE_WORLD.md): a party lines up in front of the nest and the others see it off; one
/// that won comes home holding up what it brought and the others crowd round; the hurt lie by the clinic and someone looks
/// after them; those who fell get a memorial, and now and then someone goes and stands at it. Only while the camp is drawn
/// and nothing is the matter (no rain, no monster near).
final class CampScenes {
    /// Where those who fell are remembered: one per fight, in the camp's own style, fading after a few days.
    struct Memorial: Codable {
        var at: CGPoint
        var placed: Date
        var fallen: Int
        var against: String
        var race: String
    }

    /// What the parties that just came home did (the camp's events), until those walking in are met with it.
    struct Homecoming {
        var won: Bool
        var hurt: Bool
        var loot: [String]
        var at: Date
    }

    /// A crowd to gather: `kind` as in `Ant.Activity.witness`, round `spot`, until `until`.
    private struct Gathering {
        var spot: CGPoint
        var kind: Int
        var want: Int
        var until: Date
        var count = 0
    }

    static let memorialCap = 8
    /// A memorial is mourned at for a day, and fades away between three and seven days old.
    static let mournFor: TimeInterval = 86_400
    static let fadeFrom: TimeInterval = 3 * 86_400
    static let fadeTo: TimeInterval = 7 * 86_400
    private static let defaultsKey = "goblincamp.memorials"

    private(set) var memorials: [Memorial] = CampScenes.load()
    private(set) var homecoming: Homecoming?
    private var waitingMemorials: [(fallen: Int, against: String)] = []
    private var gatherings: [Gathering] = []
    /// Where the party now lining up stands (those setting out together gather at the same place).
    private var muster: (spot: CGPoint, until: Date)?
    private var mournTimer = Double.random(in: 30...60)
    private var nurseTimer = 3.0
    private var lastWelcome = Date.distantPast

    // MARK: What the books said

    /// The parties that came home or fought for one of our cells since last time.
    func note(_ parties: [CampLedger.Expedition]) {
        for e in parties {
            if e.arrived == true, !["recall", "reroute", "retreat", "move", "guard"].contains(e.kind ?? "") {
                let won = ["cleared", "taken", "settled"].contains(e.cell ?? "")
                let loot = (e.loot ?? [:]).sorted { $0.value > $1.value }.prefix(3).map(\.key)
                var come = homecoming.flatMap { Date().timeIntervalSince($0.at) < 600 ? $0 : nil } ?? Homecoming(won: false, hurt: false, loot: [], at: Date())
                come.won = come.won || won
                come.hurt = come.hurt || !won || (e.fallen ?? 0) > 0
                come.loot = Array((come.loot + loot).prefix(3))
                come.at = Date()
                homecoming = come
            }
            if let fallen = e.fallen, fallen > 0, e.arrived == true || e.defended == true {
                waitingMemorials.append((fallen, e.against ?? e.where ?? ""))
            }
        }
    }

    // MARK: Setting off and coming home (Colony.applyBooks)

    private func showing(_ colony: Colony) -> Bool { !colony.campHidden && !colony.isRaining && !colony.monsterNear }

    /// One the books have away: it lines up with the others in front of the nest and goes, or (nothing to show) just goes.
    func setOff(_ ant: Ant, exit: CGPoint, colony: Colony) -> Ant.Mode {
        guard showing(colony), !ant.isChild, let nest = colony.nest else { return .departing(target: exit) }
        let now = Date()
        if muster.map({ $0.until < now }) ?? true {
            let spot = frontOf(nest, colony: colony, away: exit)
            muster = (spot, now.addingTimeInterval(20))
            gatherings.append(Gathering(spot: spot, kind: 0, want: min(5, max(2, colony.ants.count / 20)), until: now.addingTimeInterval(8)))
        }
        let spot = muster!.spot
        let place = CGPoint(x: spot.x + CGFloat.random(in: -14...14), y: spot.y + CGFloat.random(in: -6...6))
        return .activity(.muster(spot: place, exit: exit), remaining: 7)
    }

    /// One walking in from the big world: a winner holds up what it brought, the hurt go and lie by the clinic.
    func welcome(_ ant: inout Ant, colony: Colony) {
        ant.mode = .returningToNest
        guard showing(colony), let nest = colony.nest, let come = homecoming, Date().timeIntervalSince(come.at) < 600 else { return }
        if come.hurt, Double.random(in: 0..<1) < (come.won ? 0.3 : 0.6) {
            ant.health = min(ant.health, 0.8) // (badly hurt: Ant.isWounded)
            if let bed = clinicBed(colony) { ant.mode = .activity(.convalesce(spot: bed), remaining: 300) }
            return
        }
        guard come.won else { return }
        let spot = frontOf(nest, colony: colony, away: ant.pos)
        let to = CGPoint(x: spot.x + CGFloat.random(in: -16...16), y: spot.y + CGFloat.random(in: -5...5))
        ant.mode = .activity(.parade(to: to, loot: come.loot.randomElement()), remaining: 7)
    }

    /// A little way out in front of the nest, toward `away` (where they go or come from), on ground they can stand on.
    private func frontOf(_ nest: CGPoint, colony: Colony, away: CGPoint) -> CGPoint {
        let a = atan2(away.y - nest.y, away.x - nest.x)
        for r in [62.0, 50, 76, 40, 28] { // (out of the crowd at the door)
            let p = CGPoint(x: nest.x + cos(a) * r, y: nest.y + sin(a) * r * 0.6 - 10)
            if colony.walkable.contains(where: { $0.contains(p) }) { return p }
        }
        return CGPoint(x: nest.x, y: nest.y - 16)
    }

    /// Beside the clinic, if the camp has built one.
    private func clinicBed(_ colony: Colony) -> CGPoint? {
        guard let clinic = colony.placedBuildings().first(where: { $0.id == "clinic" && !$0.building }) else { return nil }
        let w = CGFloat(clinic.image.width)
        let beds = colony.ants.compactMap { ant -> CGPoint? in
            if case .activity(.convalesce(let spot), _) = ant.mode { return spot }
            return nil
        }
        for k in 0..<8 { // in a row along its front, then a second row
            let p = CGPoint(x: clinic.at.x - w * 0.8 + CGFloat(k % 4) * w * 0.55, y: clinic.at.y - 10 - CGFloat(k / 4) * 12)
            if colony.walkable.contains(where: { $0.contains(p) }), !beds.contains(where: { hypot($0.x - p.x, $0.y - p.y) < 8 }) { return p }
        }
        return nil
    }

    // MARK: Every frame (Colony.tick)

    fileprivate func update(dt: Double, world: AntWorld, colony: Colony) {
        let now = Date()
        guard let nest = colony.nest else { return }
        if !waitingMemorials.isEmpty, !colony.walkable.isEmpty {
            for w in waitingMemorials.prefix(3) { raise(w.fallen, w.against, nest: nest, colony: colony) }
            waitingMemorials.removeAll()
        }
        let before = memorials.count
        memorials.removeAll { now.timeIntervalSince($0.placed) > CampScenes.fadeTo }
        if memorials.count != before { save() }
        guard showing(colony) else { gatherings.removeAll(); return }

        // those coming home in triumph are met once the first of them is nearly at the door (the walk in from the edge is long)
        if !gatherings.contains(where: { $0.kind == 1 }), now.timeIntervalSince(lastWelcome) > 20,
           let near = colony.ants.lazy.compactMap({ ant -> CGPoint? in
               guard case .activity(.parade(let to, _), _) = ant.mode, hypot(to.x - ant.pos.x, to.y - ant.pos.y) < 90 else { return nil }
               return to
           }).first {
            lastWelcome = now
            gatherings.append(Gathering(spot: near, kind: 1, want: min(8, max(3, colony.ants.count / 15)), until: now.addingTimeInterval(10)))
        }

        // the crowds: whoever is idle near enough comes to look
        gatherings.removeAll { $0.until < now || $0.count >= $0.want }
        for g in gatherings.indices {
            let spot = gatherings[g].spot
            for i in idle(colony, near: spot, within: 260).prefix(gatherings[g].want - gatherings[g].count) {
                let a = Double.random(in: 0..<(2 * .pi)), r = Double.random(in: 22...34)
                let from = CGPoint(x: spot.x + cos(a) * r, y: spot.y + sin(a) * r * 0.6)
                colony.ants[i].begin(.witness(spot: from, face: spot, kind: gatherings[g].kind), world: world, seconds: Double.random(in: 7...10))
                gatherings[g].count += 1
            }
        }

        // the memorials of the last day: now and then someone goes and stands at one
        mournTimer -= dt
        if mournTimer <= 0 {
            mournTimer = Double.random(in: 45...90)
            if world.activitiesOn, let m = memorials.filter({ now.timeIntervalSince($0.placed) < CampScenes.mournFor }).randomElement(),
               let i = idle(colony, near: m.at, within: 400).first {
                let side: CGFloat = Bool.random() ? 1 : -1
                colony.ants[i].begin(.witness(spot: CGPoint(x: m.at.x + side * 12, y: m.at.y - 6), face: m.at, kind: 2), world: world, seconds: Double.random(in: 8...12))
            }
        }

        // the hurt by the clinic: someone sits with each (they mend faster)
        nurseTimer -= dt
        if nurseTimer <= 0 {
            nurseTimer = 3
            let nursed = Set(colony.ants.compactMap { ant -> Int? in
                if case .activity(.nurse(let patient), _) = ant.mode { return patient }
                return nil
            })
            for patient in colony.ants where patient.liesDown && !nursed.contains(patient.id) {
                let breeds = Characters.current.breeds
                let carers = idle(colony, near: patient.pos, within: 300).sorted { a, b in
                    let ka = ["healer", "sage", "common"].firstIndex(of: breeds[min(colony.ants[a].breedIndex, breeds.count - 1)].id) ?? 9
                    let kb = ["healer", "sage", "common"].firstIndex(of: breeds[min(colony.ants[b].breedIndex, breeds.count - 1)].id) ?? 9
                    return ka < kb
                }
                guard let i = carers.first else { break }
                colony.ants[i].begin(.nurse(patient: patient.id), world: world)
            }
        }
        for ant in colony.ants {
            guard case .activity(.nurse(let patient), _) = ant.mode, let j = colony.ants.firstIndex(where: { $0.id == patient }),
                  hypot(colony.ants[j].pos.x - ant.pos.x, colony.ants[j].pos.y - ant.pos.y) < 16 else { continue }
            colony.ants[j].health = min(colony.ants[j].maxHealth, colony.ants[j].health + dt * 0.02)
        }
    }

    /// Those out and about with nothing to do, nearest `spot` first.
    private func idle(_ colony: Colony, near spot: CGPoint, within: CGFloat) -> [Int] {
        colony.ants.indices.filter { i in
            let a = colony.ants[i]
            guard case .wandering = a.mode, !a.isChild, !a.isWounded, a.touch == nil else { return false }
            return hypot(a.pos.x - spot.x, a.pos.y - spot.y) < within
        }.sorted { hypot(colony.ants[$0].pos.x - spot.x, colony.ants[$0].pos.y - spot.y) < hypot(colony.ants[$1].pos.x - spot.x, colony.ants[$1].pos.y - spot.y) }
    }

    /// Puts up a memorial somewhere quiet round the camp (not on water, a building, the decorations or another memorial).
    private func raise(_ fallen: Int, _ against: String, nest: CGPoint, colony: Colony) {
        let buildings = colony.placedBuildings().map { $0.box.insetBy(dx: -6, dy: -6) }
        let graves = Characters.current.id == "undead" ? colony.graves : []
        // what else stands about the camp: food put down, the decorations, the tents' doors, the ranch's animals
        // where the merchant's cart stops and a visitor waits (Merchant.swift, Visitors.swift), even when nobody is there now
        let stands = [CGPoint(x: nest.x - 95, y: nest.y - 26), colony.merchant.pos] + [colony.visitorPos].compactMap { $0 }
        let busy = colony.foods.map(\.pos) + colony.decor.map { colony.decorPoint($0) } + (colony.scene?.tentEntrances() ?? []) + colony.ranch.beasts.map(\.pos)
        var spot: CGPoint?
        search: for r in stride(from: 120.0, through: 220, by: 16) {
            for k in 0..<14 {
                let a = Double.pi * (1.1 + Double(k) * 0.06) + (k % 2 == 0 ? 0 : 0.03) // below and to the sides of the nest
                let p = CGPoint(x: nest.x + cos(a + Double(k) * 0.37) * r, y: nest.y + sin(a + Double(k) * 0.37) * r * 0.55)
                guard colony.walkable.contains(where: { $0.contains(p) }),
                      !buildings.contains(where: { $0.contains(p) }),
                      !colony.decorObstacles.contains(where: { $0.blocks(p, margin: 10) }),
                      colony.scene?.visiblePonds.contains(where: { $0.blocks(p, margin: 10) }) != true,
                      !memorials.contains(where: { hypot($0.at.x - p.x, $0.at.y - p.y) < 22 }),
                      !graves.contains(where: { hypot($0.x - p.x, $0.y - p.y) < 20 }),
                      !busy.contains(where: { hypot($0.x - p.x, $0.y - p.y) < 40 }),
                      !stands.contains(where: { hypot($0.x - p.x, $0.y - p.y) < 70 }) else { continue }
                spot = p
                break search
            }
        }
        guard let at = spot else { return }
        memorials.append(Memorial(at: at, placed: Date(), fallen: fallen, against: against, race: Characters.current.id))
        if memorials.count > CampScenes.memorialCap { memorials.removeFirst(memorials.count - CampScenes.memorialCap) }
        save()
        colony.addFloater((against.isEmpty ? "" : "\(against)之戰，") + "倒下 \(fallen) 隻", .uncommon, at: CGPoint(x: at.x, y: at.y + 14), important: true)
    }

    /// Kept with the settings (`CAMP_DEFAULTS` keeps a test's apart; `CAMP_NO_SAVE` keeps nothing).
    private static let store: UserDefaults? = {
        let env = ProcessInfo.processInfo.environment
        if env["CAMP_NO_SAVE"] != nil, env["CAMP_DEFAULTS"] == nil { return nil }
        return env["CAMP_DEFAULTS"].flatMap { UserDefaults(suiteName: $0) } ?? .standard
    }()

    private static func load() -> [Memorial] {
        guard let data = store?.data(forKey: defaultsKey) else { return [] }
        return (try? JSONDecoder().decode([Memorial].self, from: data)) ?? []
    }

    private func save() {
        if let data = try? JSONEncoder().encode(memorials) { CampScenes.store?.set(data, forKey: CampScenes.defaultsKey) }
    }

    /// Test aid (`CAMP_TEST_WORLDEVENT`): what would have come from the books.
    func pretend(won: Bool, hurt: Bool, loot: [String]) { homecoming = Homecoming(won: won, hurt: hurt, loot: loot, at: Date()) }
    func pretendFallen(_ fallen: Int, against: String) {
        waitingMemorials.append((fallen, against))
        mournTimer = 4
    }
}

extension Colony {
    func updateScenes(dt: Double, world: AntWorld) {
        scenes.update(dt: dt, world: world, colony: self)
        if let script = CampScenes.testScript { runSceneTest(script, dt: dt) }
    }
}

// MARK: - Drawing (AntView)

extension CampScenes {
    private static func px(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ u: CGFloat, _ color: NSColor) {
        color.setFill()
        NSRect(x: x - w * u / 2, y: y, width: w * u, height: h * u).fill()
    }

    private static func say(_ text: String, at p: CGPoint) {
        let font = NSFont.boldSystemFont(ofSize: 10)
        let s = text as NSString
        let w = s.size(withAttributes: [.font: font]).width
        let dark: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor(calibratedWhite: 0.1, alpha: 0.85)]
        for (dx, dy) in [(-1.0, 0.0), (1, 0), (0, -1), (0, 1), (-1, -1), (1, -1), (-1, 1), (1, 1)] { // an outline, so it reads on grass and snow
            s.draw(at: NSPoint(x: p.x - w / 2 + dx, y: p.y + dy), withAttributes: dark)
        }
        s.draw(at: NSPoint(x: p.x - w / 2, y: p.y), withAttributes: [.font: font, .foregroundColor: NSColor.white])
    }

    /// What goes with a scene's activity: words of farewell or welcome, a tear at a memorial, the loot held up, a hand for the hurt.
    static func drawExtras(_ ant: Ant, at p: CGPoint, size: CGFloat, pixel u: CGFloat) {
        let t = ant.activityClock
        let race = Characters.current.id
        let head = CGPoint(x: p.x, y: p.y + size * 0.86)
        switch ant.activity {
        case .witness(let spot, _, let kind)? where hypot(spot.x - ant.pos.x, spot.y - ant.pos.y) < 6 || race == "undead":
            let wave = sin(t * 9) > 0
            switch kind {
            case 0: // seeing them off: a wave, and a word once
                let words = ["goblin": ["加油！", "早點回來！"], "elf": ["一路平安", "願森林護佑"], "undead": ["……", "早去早回"], "beast": ["嗷嗚——！", "打贏回來！"]][race] ?? ["加油！"]
                if t > 0.4, t < 3.2 { say(words[ant.id % words.count], at: CGPoint(x: head.x, y: head.y + 2)) }
                switch race {
                case "elf": px(p.x + size * 0.32, p.y + size * 0.55 + (wave ? 2 : 0), 1.6, 1.2, u, NSColor(calibratedRed: 0.45, green: 0.75, blue: 0.35, alpha: 1)) // a leaf held up
                case "undead": px(p.x + size * 0.3 + (wave ? 1.5 : -1.5), p.y + size * 0.5, 1.2, 1.6, u, NSColor(calibratedRed: 0.5, green: 0.85, blue: 1, alpha: 0.9)) // the soul lamp swinging
                default: px(p.x + size * 0.32, p.y + size * 0.5 + (wave ? 2 : 0), 1, 1.4, u, NSColor(calibratedWhite: 0.95, alpha: 1)) // a hand up
                }
            case 1: // welcoming them home
                let words = ["哇！", "好多！", "辛苦了！", "厲害！"]
                if t > 0.4, t < 3.6, ant.id % 2 == 0 { say(words[ant.id % words.count], at: CGPoint(x: head.x, y: head.y + 2)) }
                px(p.x + size * 0.32, p.y + size * 0.5 + (wave ? 2 : 0), 1, 1.4, u, NSColor(calibratedWhite: 0.95, alpha: 1))
            default: // at a memorial
                switch race {
                case "elf": // a leaf drifting down
                    let f = CGFloat((t * 0.35).truncatingRemainder(dividingBy: 1))
                    px(p.x + sin(f * 6) * 4, head.y + 4 - f * size * 0.8, 1.4, 1, u, NSColor(calibratedRed: 0.55, green: 0.78, blue: 0.35, alpha: 1 - f))
                case "undead": // a wisp
                    px(p.x, head.y + CGFloat(sin(t * 3)) * 1.5, 1.4, 1.8, u, NSColor(calibratedRed: 0.55, green: 0.9, blue: 1, alpha: 0.75))
                case "beast": // a howl, once
                    if t > 1, t < 3.5 { say("嗷——", at: CGPoint(x: head.x, y: head.y + 2)) }
                default: // a tear
                    let f = CGFloat((t * 0.6).truncatingRemainder(dividingBy: 1))
                    px(p.x + size * 0.12, p.y + size * 0.55 - f * size * 0.25, 0.7, 1, u, NSColor(calibratedRed: 0.55, green: 0.8, blue: 1, alpha: 1 - f * 0.6))
                }
            }
        case .parade(_, let loot)?: // the spoils held up over the head: a little bundle in the colour of what it is
            let color = loot.flatMap { Materials.info($0)?.color } ?? NSColor(calibratedRed: 0.85, green: 0.7, blue: 0.35, alpha: 1)
            px(head.x, head.y, 4, 3, u, color)
            px(head.x, head.y + 3 * u, 2, 1, u, color.blended(withFraction: 0.35, of: .white) ?? color)
            px(head.x - 1.5 * u, head.y + u, 0.6, 0.6, u, NSColor.white.withAlphaComponent(0.8))
        case .nurse(let patient)? where t > 1.5:
            _ = patient
            mark(at: CGPoint(x: head.x, y: head.y + CGFloat(sin(t * 3)) * 1.2), u: u)
        case .muster?:
            break
        default: break
        }
    }

    /// One lying hurt by the clinic: a bandage mark over it now and then.
    static func drawPatient(_ ant: Ant, at p: CGPoint, size: CGFloat, pixel u: CGFloat) {
        guard Int(Date().timeIntervalSinceReferenceDate + Double(ant.id)) % 4 != 0 else { return }
        mark(at: CGPoint(x: p.x, y: p.y + size * 0.45), u: u)
    }

    /// The race's sign of looking after someone: a green cross, a leaf, a little soul flame, a paw.
    private static func mark(at c: CGPoint, u: CGFloat) {
        switch Characters.current.id {
        case "elf":
            px(c.x, c.y, 2.2, 1.2, u, NSColor(calibratedRed: 0.45, green: 0.8, blue: 0.4, alpha: 1))
            px(c.x + 0.8 * u, c.y + 1.2 * u, 1, 0.8, u, NSColor(calibratedRed: 0.6, green: 0.9, blue: 0.5, alpha: 1))
        case "undead":
            px(c.x, c.y, 1.4, 2.2, u, NSColor(calibratedRed: 0.55, green: 0.9, blue: 1, alpha: 0.85))
            px(c.x, c.y + 2.2 * u, 0.7, 0.8, u, NSColor(calibratedRed: 0.8, green: 0.97, blue: 1, alpha: 0.85))
        default:
            let green = NSColor(calibratedRed: 0.35, green: 0.85, blue: 0.4, alpha: 1)
            px(c.x, c.y, 0.9, 2.7, u, green)
            px(c.x, c.y + 0.9 * u, 2.7, 0.9, u, green)
        }
    }

    /// A memorial in the race's own style, fading once it is a few days old.
    static func drawMemorial(_ m: Memorial, at p: CGPoint) {
        let age = Date().timeIntervalSince(m.placed)
        let alpha = CGFloat(age < fadeFrom ? 1 : max(0, 1 - (age - fadeFrom) / (fadeTo - fadeFrom)))
        guard alpha > 0.02, let ctx = NSGraphicsContext.current?.cgContext else { return }
        let u: CGFloat = 2.6
        ctx.saveGState()
        ctx.setAlpha(alpha)
        NSColor.black.withAlphaComponent(0.18).setFill() // its shadow
        NSBezierPath(ovalIn: NSRect(x: p.x - 6 * u, y: p.y - 1.5 * u, width: 12 * u, height: 3 * u)).fill()
        let stone = NSColor(calibratedRed: 0.55, green: 0.55, blue: 0.58, alpha: 1)
        let wood = NSColor(calibratedRed: 0.45, green: 0.3, blue: 0.18, alpha: 1)
        switch m.race {
        case "elf": // a sapling with a white flower
            px(p.x, p.y, 0.8, 7, u, NSColor(calibratedRed: 0.35, green: 0.5, blue: 0.22, alpha: 1))
            let leaf = NSColor(calibratedRed: 0.42, green: 0.72, blue: 0.32, alpha: 1)
            px(p.x - 1.4 * u, p.y + 3.5 * u, 2, 1.2, u, leaf)
            px(p.x + 1.4 * u, p.y + 5 * u, 2, 1.2, u, leaf)
            px(p.x - 0.8 * u, p.y + 6.5 * u, 2.2, 1.4, u, leaf)
            px(p.x + 0.4 * u, p.y + 7.4 * u, 1.2, 1.2, u, NSColor(calibratedWhite: 0.97, alpha: 1))
            px(p.x, p.y, 4, 1, u, NSColor(calibratedRed: 0.4, green: 0.3, blue: 0.2, alpha: 1)) // fresh earth
        case "undead": // a fresh grave: a mound and a crooked cross
            let earth = NSColor(calibratedRed: 0.3, green: 0.24, blue: 0.2, alpha: 1)
            px(p.x, p.y, 9, 1.6, u, earth)
            px(p.x, p.y + 1.6 * u, 6, 1, u, earth)
            let grey = NSColor(calibratedRed: 0.62, green: 0.62, blue: 0.66, alpha: 1)
            px(p.x + 3 * u, p.y + 1 * u, 0.9, 7, u, grey)
            px(p.x + 3 * u, p.y + 5.5 * u, 3.6, 0.9, u, grey)
        case "beast": // a horned skull on a post
            px(p.x, p.y, 1, 7, u, wood)
            let bone = NSColor(calibratedRed: 0.93, green: 0.9, blue: 0.8, alpha: 1)
            px(p.x, p.y + 6.5 * u, 4, 3, u, bone)
            px(p.x, p.y + 5.6 * u, 2.4, 1, u, bone)
            px(p.x - 0.9 * u, p.y + 7.5 * u, 0.9, 0.9, u, .black)
            px(p.x + 0.9 * u, p.y + 7.5 * u, 0.9, 0.9, u, .black)
            px(p.x - 2.6 * u, p.y + 8.6 * u, 1.4, 0.8, u, bone)
            px(p.x + 2.6 * u, p.y + 8.6 * u, 1.4, 0.8, u, bone)
            px(p.x - 3.2 * u, p.y + 9.4 * u, 0.8, 0.8, u, bone)
            px(p.x + 3.2 * u, p.y + 9.4 * u, 0.8, 0.8, u, bone)
        default: // goblins: a stick in a heap of stones, a rag tied on
            px(p.x - 1.6 * u, p.y, 2, 1.4, u, stone)
            px(p.x + 1.6 * u, p.y, 2, 1.2, u, stone.blended(withFraction: 0.2, of: .black) ?? stone)
            px(p.x, p.y + 1 * u, 2, 1, u, stone)
            px(p.x, p.y + 1.6 * u, 0.9, 7, u, wood)
            let wave = CGFloat(sin(Date().timeIntervalSinceReferenceDate * 2 + Double(m.at.x))) * 0.4
            px(p.x + 1.6 * u, p.y + 6.4 * u + wave, 2.4, 1.6, u, NSColor(calibratedRed: 0.7, green: 0.25, blue: 0.2, alpha: 1))
        }
        ctx.restoreGState()
    }
}

// MARK: - Test aid

extension CampScenes {
    /// `CAMP_TEST_WORLDEVENT=send,triumph,wounded,mourn` (any of them): from 20 s on, plays them one after another (12 s apart) on
    /// the residents there are, as if the books had said so. Pair with `CAMP_TEST_LIFESHOT` to see them.
    static let testScript: [String]? = ProcessInfo.processInfo.environment["CAMP_TEST_WORLDEVENT"].map { $0.split(separator: ",").map(String.init) }
    fileprivate static var testClock = 0.0
    fileprivate static var testDone = 0
}

extension Colony {
    fileprivate func runSceneTest(_ script: [String], dt: Double) {
        let before = CampScenes.testClock
        CampScenes.testClock += dt
        let gap = Double(ProcessInfo.processInfo.environment["CAMP_TEST_WORLDGAP"] ?? "") ?? 12
        // `CAMP_TEST_WORLDSHOT=/path/prefix`: the camp window drawn 3 and 7 s into each scene; done after the last
        if let prefix = ProcessInfo.processInfo.environment["CAMP_TEST_WORLDSHOT"] {
            for (k, name) in script.enumerated() {
                let waits = (ProcessInfo.processInfo.environment["CAMP_TEST_WORLDWAITS"] ?? "3,7").split(separator: ",").compactMap { Double($0) }
                for wait in waits where before < 20 + Double(k) * gap + wait && CampScenes.testClock >= 20 + Double(k) * gap + wait {
                    let labels = Dictionary(grouping: ants.filter { $0.activity != nil }, by: { $0.stateLabel }).map { "\($0.key) \($0.value.count)" }
                    print("scene test \(name)+\(Int(wait)): \(labels.sorted().joined(separator: "、")) | memorials \(scenes.memorials.map { "(\(Int($0.at.x)),\(Int($0.at.y)))" }.joined()) nest \(nest.map { "\(Int($0.x)),\(Int($0.y))" } ?? "-")")
                    fflush(stdout)
                    if let view = AntView.campView, let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) {
                        view.cacheDisplay(in: view.bounds, to: rep)
                        try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: "\(prefix)-\(name)-\(Int(wait)).png"))
                    }
                    if k == script.count - 1, wait == waits.last { NSApp.terminate(nil) }
                }
            }
        }
        let step = Int((CampScenes.testClock - 20) / gap)
        guard CampScenes.testClock >= 20, step >= CampScenes.testDone, step < script.count, let nest else { return }
        CampScenes.testDone = step + 1
        let name = script[step]
        let out = ants.indices.filter { !ants[$0].isChild && !ants[$0].isHidden && ants[$0].touch == nil }.shuffled().prefix(4)
        let edge = CGPoint(x: (walkable.map(\.maxX).max() ?? nest.x + 300) - 4, y: nest.y)
        print("scene test t\(Int(CampScenes.testClock)): \(name) with \(out.count)")
        fflush(stdout)
        switch name {
        case "send":
            for i in out { ants[i].mode = scenes.setOff(ants[i], exit: edge, colony: self) }
        case "triumph", "wounded":
            if name == "wounded", booksBuildings["clinic"] == nil { booksBuildings["clinic"] = BuildingState(level: 1, busyUntil: nil) }
            scenes.pretend(won: name == "triumph", hurt: name == "wounded", loot: ["wolf_pelt", "crystal_shard"])
            for i in out {
                ants[i].pos = CGPoint(x: edge.x - CGFloat.random(in: 0...20), y: nest.y + CGFloat.random(in: -30...30))
                var ant = ants[i]
                scenes.welcome(&ant, colony: self)
                ants[i] = ant
            }
        case "mourn":
            scenes.pretendFallen(3, against: "野狼窩")
        default: break
        }
    }
}
