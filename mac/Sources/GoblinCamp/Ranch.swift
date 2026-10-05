import AppKit
import CampRules

// The ranch (DESKTOP.md §8, shared/src/camp/ranch.ts): the player fences a pen (fence pieces from the decorations catalogue,
// on a grid; a closed ring is a pen), picks up the animals that wander into the camp and drops them in, and they live and
// breed there. What they give is only earned while the camp is open here: every ten minutes of the camp running, the Mac
// tells the books how many minutes it was open, and the server gives the herd's yield (never for more than really passed).
// Changes to the herd (caught, born, butchered, got away) go to the books a second after they happen.

/// The rules (the same numbers as shared/src/camp/ranch.ts).
enum RanchRules {
    /// Where a kind lives: a fenced pen, the elves' eagle perch, the undead's soul lamp.
    enum Housing { case pen, perch, lamp }
    struct Kind {
        let name: String
        let young: String
        let perHour: [String: Double]
        var butcher: [String: Int] = [:]
        var housing = Housing.pen
        /// How many grown ones it takes for a young one (0: it never breeds; 1: a soul splits by itself).
        var parents = 2
    }
    static let kinds: [String: Kind] = [
        "sheep": Kind(name: "羊", young: "小羊", perHour: ["scrap_rag": 0.4]),
        "chicken": Kind(name: "雞", young: "小雞", perHour: ["feather": 0.3]),
        "pig": Kind(name: "豬", young: "小豬", perHour: [:], butcher: ["food_meat": 3]),
        "deer": Kind(name: "鹿", young: "小鹿", perHour: ["bone_shard": 0.25]),
        "rabbit": Kind(name: "兔子", young: "小兔子", perHour: ["rabbit_fur": 0.3]),
        "eagle": Kind(name: "老鷹", young: "老鷹", perHour: ["feather": 0.2, "rabbit_fur": 0.1], housing: .perch, parents: 0),
        "bone_sheep": Kind(name: "骨羊", young: "骨羊", perHour: ["bone_shard": 0.4], parents: 0),
        "bone_chicken": Kind(name: "骨雞", young: "骨雞", perHour: ["bone_shard": 0.25], parents: 0),
        "bone_dog": Kind(name: "骨犬", young: "骨犬", perHour: ["bone_shard": 0.3], parents: 0),
        "soul_beast": Kind(name: "獸魂", young: "小獸魂", perHour: ["ectoplasm": 0.3, "night_dust": 0.15], housing: .lamp, parents: 1),
    ]
    static let grownMinutes = 60.0
    static let cap = [1: 6, 2: 12, 3: 20]
    /// `CAMP_RANCH_SCALE` makes time in the pens run faster (tests): births, visits and reports come that many times sooner.
    static let scale = Double(ProcessInfo.processInfo.environment["CAMP_RANCH_SCALE"] ?? "") ?? 1
    /// Minutes of the camp being open between two births of a kind (grown ones and room needed).
    static let breedMinutes = 40.0...80.0
    /// The camp reports its open time this often (seconds).
    static let reportEvery = 600.0
    /// A soul lamp keeps this many souls; a perch one eagle.
    static let lampRoom = 3
    /// Pats (one a visit) before a wild eagle stays; beast bones before a bone beast can be put together.
    static let eagleTrust = 3
    static let bonesNeeded = 3
    /// How high on its perch an eagle sits (points above the perch's foot).
    static let perchTop: CGFloat = 62
}

/// One animal in a pen.
struct RanchBeast {
    let id: Int
    let kind: String
    var born: Date
    var caught: Bool
    /// What the player called it ("" : nothing yet).
    var name = ""
    /// Seconds (of the pens' time) toward a hen's next egg.
    var laying = Double.random(in: 0...600)
    /// Its pen (by index), or -1 for one that lives on a perch or by a lamp (`home`: that decoration's spot).
    var pen = 0
    var home = CGPoint.zero
    /// An eagle on the wing: seconds left of its round, and how far round it is. A soul: where it is in its circling.
    var flight = 0.0
    var angle = Double.random(in: 0..<(2 * .pi))
    var rest = Double.random(in: 20...60)
    var pos = CGPoint.zero
    var target = CGPoint.zero
    var pause = 0.0
    var legPhase = 0.0
    var facingRight = true

    var grown: Bool { caught || Date().timeIntervalSince(born) >= RanchRules.grownMinutes * 60 / RanchRules.scale }
    var minutesToGrow: Int { max(0, Int((RanchRules.grownMinutes * 60 / RanchRules.scale - Date().timeIntervalSince(born)) / 60) + 1) }
}

/// What the Mac tells the books (`ranch-sync`).
struct RanchReport {
    struct Animal: Encodable { let id: Int; let kind: String; let caught: Bool?; let name: String? }
    let animals: [Animal]
    let minutes: Double
    let butchered: [Int]
}

/// What a camp of its own keeps in ranch.json.
private struct RanchFile: Codable {
    struct Animal: Codable { let id: Int; let kind: String; let born: Date; let caught: Bool; var name: String? }
    var animals: [Animal]
    var openSeconds: Double
    var carry: [String: Double]
}

final class RanchState {
    var beasts: [RanchBeast] = []
    /// The cells inside each pen (a pen: ground wholly ringed by fence pieces), and where the fence pieces are.
    var pens: [[GridCell]] = []
    var fenceCells: Set<GridCell> = []
    /// Fence pieces turned into gates (F in decoration mode): residents come to the pen there.
    var gateCells: Set<GridCell> = []
    var pensDirty = true
    /// Seconds the camp has been open here that the books have not been told of yet.
    var openSeconds = 0.0
    /// The herd changed: tell the books in a moment. And those butchered since the last report.
    var dirty = false
    var dirtyTimer = 0.0
    var butchered: [Int] = []
    var syncing = false
    /// Seconds toward the next birth of each kind, and how long that takes this time.
    var breeding: [String: (done: Double, need: Double)] = [:]
    /// The wild animal in the player's hand.
    var held: Int?
    var loaded = false
    var nextID = 1
    var carry: [String: Double] = [:]
    var saveTimer = 30.0
    /// Beasts' souls drifting through an undead camp (caught by hand or by a resident, kept in a soul lamp).
    var wisps: [(id: Int, pos: CGPoint, vel: CGVector, life: Double)] = []
    var heldWisp: Int?
    var nextWisp = 1
    /// A wild eagle on a perch for a while (elves): where, and for how long more; whether it was patted this visit.
    var visitor: (perch: CGPoint, left: Double, patted: Bool)?
    /// Slow timers: residents sent to catch and to feed, monsters at the pens, visits.
    var choreTimer = 3.0
    var raidTimer = 4.0
    var visitTimer = 30.0
    var tendTimer = 40.0
    /// Who is after which animal (ant id → creature id; a soul's id negative).
    var herders: [Int: Int] = [:]
}

extension Colony {
    // MARK: Pens

    /// The most animals the camp keeps, by its look.
    var ranchCap: Int { RanchRules.cap[decorStage] ?? 6 }

    /// How many a pen holds: one for every two cells of ground.
    func penRoom(_ pen: Int) -> Int { ranch.pens.indices.contains(pen) ? max(1, ranch.pens[pen].count / 2) : 0 }
    func penCount(_ pen: Int) -> Int { ranch.beasts.filter { $0.pen == pen }.count }

    /// The pen a point is in, if any.
    func penAt(_ p: CGPoint) -> Int? {
        ranch.pens.firstIndex { cells in cells.contains { cellRect($0).contains(p) } }
    }

    /// Works the pens out from the fence pieces: the cells no flood from outside reaches.
    private func recomputePens() {
        ranch.pensDirty = false
        let fences = Set(decor.filter { DecorCatalog.isFence($0.kind) }.map(fenceCell))
        ranch.fenceCells = fences
        ranch.gateCells = Set(decor.filter { DecorCatalog.isFence($0.kind) && $0.flip == true }.map(fenceCell))
        guard fences.count >= 4 else { ranch.pens = []; return }
        let minX = fences.map(\.x).min()! - 1, maxX = fences.map(\.x).max()! + 1, minY = fences.map(\.y).min()! - 1, maxY = fences.map(\.y).max()! + 1
        var outside = Set<GridCell>(), stack = [GridCell(x: minX, y: minY)]
        func neighbours(_ c: GridCell) -> [GridCell] { [GridCell(x: c.x + 1, y: c.y), GridCell(x: c.x - 1, y: c.y), GridCell(x: c.x, y: c.y + 1), GridCell(x: c.x, y: c.y - 1)] }
        while let c = stack.popLast() {
            guard c.x >= minX, c.x <= maxX, c.y >= minY, c.y <= maxY, !fences.contains(c), outside.insert(c).inserted else { continue }
            stack.append(contentsOf: neighbours(c))
        }
        var pens: [[GridCell]] = [], seen = Set<GridCell>()
        for x in minX...maxX {
            for y in minY...maxY {
                let start = GridCell(x: x, y: y)
                guard !fences.contains(start), !outside.contains(start), !seen.contains(start) else { continue }
                var pen: [GridCell] = [], todo = [start]
                while let c = todo.popLast() {
                    guard !fences.contains(c), !outside.contains(c), seen.insert(c).inserted else { continue }
                    pen.append(c)
                    todo.append(contentsOf: neighbours(c))
                }
                pens.append(pen)
            }
        }
        ranch.pens = pens
    }

    /// The spots of the decorations that house what lives outside a pen: eagle perches, soul lamps.
    func homes(_ housing: RanchRules.Housing) -> [CGPoint] {
        let fn = housing == .perch ? "eagle" : "soulpen"
        return housing == .pen ? [] : decor.filter { DecorCatalog.kind($0.kind)?.fn == fn }.map(decorPoint)
    }

    private func homeRoom(_ housing: RanchRules.Housing) -> Int { housing == .perch ? 1 : RanchRules.lampRoom }

    /// A home of that sort with room left (counting `among`), nearest to `p`.
    func freeHome(_ housing: RanchRules.Housing, near p: CGPoint, among beasts: [RanchBeast]) -> CGPoint? {
        homes(housing).filter { h in beasts.filter { $0.pen < 0 && hypot($0.home.x - h.x, $0.home.y - h.y) < 2 }.count < homeRoom(housing) }
            .min { hypot($0.x - p.x, $0.y - p.y) < hypot($1.x - p.x, $1.y - p.y) }
    }

    /// Everyone in a pen (or on a perch, by a lamp) that is still there and has room; the rest find another, or get away.
    private func settleBeasts() {
        var count = [Int: Int]()
        var kept: [RanchBeast] = [], away: [RanchBeast] = []
        for var beast in ranch.beasts {
            let housing = RanchRules.kinds[beast.kind]?.housing ?? .pen
            if housing != .pen {
                let still = homes(housing).contains { hypot($0.x - beast.home.x, $0.y - beast.home.y) < 2 }
                    && kept.filter { $0.pen < 0 && hypot($0.home.x - beast.home.x, $0.home.y - beast.home.y) < 2 }.count < homeRoom(housing)
                if !still {
                    guard let home = freeHome(housing, near: beast.pos, among: kept) else { away.append(beast); continue }
                    beast.home = home
                    beast.pos = home
                }
                beast.pen = -1
                kept.append(beast)
                continue
            }
            var pen = penAt(beast.pos)
            if pen == nil || count[pen!, default: 0] >= penRoom(pen!) { pen = ranch.pens.indices.first { count[$0, default: 0] < penRoom($0) } }
            guard let pen else { away.append(beast); continue }
            count[pen, default: 0] += 1
            if beast.pen != pen || penAt(beast.pos) != pen {
                beast.pos = randomSpot(in: pen)
                beast.target = beast.pos
            }
            beast.pen = pen
            kept.append(beast)
        }
        ranch.beasts = kept
        for beast in away {
            let kind = RanchRules.kinds[beast.kind]
            let why = kind?.housing == .perch ? "沒有鷹架了" : kind?.housing == .lamp ? "沒有養魂燈了" : "沒有圍欄了"
            addFloater("\(kind?.name ?? "")跑掉了（\(why)）", .common, at: beast.pos, important: true)
            ranch.dirty = true
        }
    }

    private func randomSpot(in pen: Int) -> CGPoint {
        guard let cell = ranch.pens[pen].randomElement() else { return .zero }
        let r = cellRect(cell).insetBy(dx: 3, dy: 3)
        return CGPoint(x: CGFloat.random(in: r.minX...r.maxX), y: CGFloat.random(in: r.minY...r.maxY))
    }

    // MARK: Every frame

    func updateRanch(dt: Double) {
        let state = ranch
        if let prefix = RanchTest.prefix { runRanchTest(prefix) }
        if !state.loaded {
            state.loaded = true
            if followsBooks { state.openSeconds = Settings.shared.ranchOpenSeconds } else { loadLocalRanch() }
        }
        if state.pensDirty {
            recomputePens()
            settleBeasts()
        }
        // the animal in the hand follows the pointer
        if let id = state.held, let cursor = hand.cursor { carryCreature(id, to: CGPoint(x: cursor.x, y: cursor.y - 10)) }
        // they potter about their pen; souls circle their lamp; the eagle sits on its perch and takes a turn round the camp
        for i in state.beasts.indices {
            var b = state.beasts[i]
            switch RanchRules.kinds[b.kind]?.housing ?? .pen {
            case .lamp:
                b.angle += dt * 0.9
                let k = Double(b.id % 3)
                b.pos = CGPoint(x: b.home.x + cos(b.angle + k * 2.1) * 13, y: b.home.y + 26 + sin(b.angle * 1.7 + k) * 5 + k * 5)
                b.facingRight = sin(b.angle + k * 2.1) < 0
                b.legPhase += dt * 2
            case .perch:
                if b.flight > 0 { // a round over the camp, or a stoop at a monster
                    b.flight -= dt
                    b.angle += dt * 0.8
                    let centre = nest ?? b.home
                    var to = CGPoint(x: centre.x + cos(b.angle) * 150, y: centre.y + 70 + sin(b.angle) * 60)
                    if let monster = creatures.first(where: { $0.kind.hostile }) { to = CGPoint(x: monster.pos.x, y: monster.pos.y + 14) }
                    if b.flight <= 0 { to = CGPoint(x: b.home.x, y: b.home.y + RanchRules.perchTop) }
                    let d = hypot(to.x - b.pos.x, to.y - b.pos.y), step = min(d, 70 * dt)
                    if d > 1 { b.facingRight = to.x >= b.pos.x; b.pos.x += (to.x - b.pos.x) / d * step; b.pos.y += (to.y - b.pos.y) / d * step }
                    if b.flight <= 0, d > 4 { b.flight = 0.2 } // (not home yet)
                    b.legPhase += dt * 6
                } else {
                    b.pos = CGPoint(x: b.home.x, y: b.home.y + RanchRules.perchTop)
                    b.rest -= dt
                    if b.rest <= 0 || creatures.contains(where: { $0.kind.hostile }) {
                        b.rest = Double.random(in: 40...90)
                        b.flight = Double.random(in: 7...11)
                    }
                }
            case .pen:
                if b.kind == "chicken", b.grown { // a hen lays an egg for the pot every twenty minutes or so (of the camp being open)
                    b.laying += dt * RanchRules.scale
                    if b.laying >= 1200 {
                        b.laying = Double.random(in: 0...300)
                        if layEgg() { addFloater("下了一顆蛋", .common, at: b.pos) }
                    }
                }
                if b.pause > 0 {
                    b.pause -= dt
                } else {
                    let d = hypot(b.target.x - b.pos.x, b.target.y - b.pos.y)
                    if d < 1.5 {
                        b.pause = Double.random(in: 1...6)
                        if state.pens.indices.contains(b.pen) { b.target = randomSpot(in: b.pen) }
                    } else {
                        let step = min(d, (b.kind.hasSuffix("chicken") || b.kind == "rabbit" ? 11 : 7) * dt)
                        b.facingRight = b.target.x >= b.pos.x
                        b.pos.x += (b.target.x - b.pos.x) / d * step
                        b.pos.y += (b.target.y - b.pos.y) / d * step
                        b.legPhase += step * 0.35
                    }
                }
            }
            state.beasts[i] = b
        }
        updateRanchChores(dt: dt)
        // nobody but the animals lives in a pen: a resident fenced in walks out through the nest
        if !state.pens.isEmpty {
            for i in ants.indices where !ants[i].isHidden && ants[i].touch == nil && penAt(ants[i].pos) != nil {
                ants[i].mode = .inNest(remaining: Double.random(in: 1...3), thenForage: nil)
            }
        }
        guard !state.beasts.isEmpty || state.dirty || !state.butchered.isEmpty || state.openSeconds >= 60 else { return }
        // births: enough grown ones of a kind (two; one soul splits by itself), room at home and under the camp's cap
        for (kind, rule) in RanchRules.kinds where rule.parents > 0 {
            let grown = state.beasts.filter { $0.kind == kind && $0.grown }
            var pen: Int?, home: CGPoint?
            if rule.housing == .pen { pen = grown.map(\.pen).first { penCount($0) < penRoom($0) } } else { home = grown.first.flatMap { freeHome(rule.housing, near: $0.home, among: state.beasts) } }
            guard grown.count >= rule.parents, state.beasts.count < ranchCap, pen != nil || home != nil else {
                state.breeding[kind] = nil
                continue
            }
            var timer = state.breeding[kind] ?? (0, Double.random(in: RanchRules.breedMinutes) * 60)
            timer.done += dt * RanchRules.scale
            if timer.done >= timer.need {
                state.breeding[kind] = nil
                var young = RanchBeast(id: state.nextID, kind: kind, born: Date(), caught: false, pen: pen ?? -1)
                state.nextID += 1
                young.home = home ?? .zero
                young.pos = pen.flatMap { p in grown.first { $0.pen == p }?.pos } ?? home ?? .zero
                young.target = young.pos
                state.beasts.append(young)
                state.dirty = true
                addFloater(rule.housing == .lamp ? "獸魂分成了兩個！" : "\(rule.young)出生了！", .uncommon, at: young.pos, important: true)
            } else {
                state.breeding[kind] = timer
            }
        }
        // the camp is open: the minutes count, and are told every ten
        state.openSeconds += dt * RanchRules.scale
        state.saveTimer -= dt
        if state.saveTimer <= 0 {
            state.saveTimer = 30
            if followsBooks { Settings.shared.ranchOpenSeconds = state.openSeconds } else { saveLocalRanch() }
        }
        if state.dirty { state.dirtyTimer += dt } else { state.dirtyTimer = 0 }
        if !state.syncing, state.openSeconds >= RanchRules.reportEvery || (state.dirty && state.dirtyTimer >= 1) { reportRanch() }
    }

    // MARK: Telling the books

    private func reportRanch() {
        let state = ranch
        let minutes = (state.openSeconds / 60).rounded(.down)
        let butchered = state.butchered
        state.dirty = false
        state.dirtyTimer = 0
        guard followsBooks else { // a camp of its own: the same sums here
            var total = state.carry
            for b in state.beasts where b.grown {
                for (id, perHour) in RanchRules.kinds[b.kind]?.perHour ?? [:] { total[id, default: 0] += perHour * min(minutes, 60) / 60 }
            }
            var gain: [String: Int] = [:]
            for (id, n) in total { let whole = Int(n + 1e-9); if whole > 0 { gain[id] = whole }; total[id] = n - Double(whole) }
            state.carry = total.filter { $0.value > 1e-9 }
            state.openSeconds -= minutes * 60
            state.butchered = []
            if !gain.isEmpty { _ = exchangeLocally(give: [:], get: gain); ranchGained(gain) }
            if state.beasts.contains(where: { $0.kind.hasPrefix("bone_") && $0.grown }), minutes >= 10 { nourishTower("bone") }
            if state.beasts.contains(where: { $0.kind == "soul_beast" && $0.grown }), minutes >= 10 { nourishTower("soul") }
            saveLocalRanch()
            onAntsChanged?()
            return
        }
        guard let send = onRanchSync else { return }
        state.syncing = true
        let report = RanchReport(animals: state.beasts.map { .init(id: $0.id, kind: $0.kind, caught: $0.caught ? true : nil, name: $0.name.isEmpty ? nil : $0.name) }, minutes: minutes, butchered: butchered)
        send(report) { [weak self] answer in
            guard let self else { return }
            let state = self.ranch
            state.syncing = false
            switch answer {
            case .success(let message):
                state.openSeconds = max(0, state.openSeconds - minutes * 60)
                state.butchered.removeAll { butchered.contains($0) }
                Settings.shared.ranchOpenSeconds = state.openSeconds
                if !message.isEmpty, let p = state.beasts.first?.pos {
                    self.addFloater(message.replacingOccurrences(of: "。", with: ""), .uncommon, at: p, important: true)
                    self.ranchCarrier()
                }
            case .failure:
                state.dirty = !butchered.isEmpty || state.dirty // (try again with the next report)
                state.openSeconds = min(state.openSeconds, RanchRules.reportEvery - 60) // (and not at once)
            }
        }
    }

    private func ranchGained(_ gain: [String: Int]) {
        let words = gain.sorted { $0.key < $1.key }.map { "\(Materials.info($0.key)?.name ?? $0.key) ×\($0.value)" }.joined(separator: "、")
        if let p = ranch.beasts.first?.pos ?? nest { addFloater("牧場：\(words)", .uncommon, at: p, important: true) }
        ranchCarrier()
    }

    /// Somebody near the animals carries a sack of what they gave back to the camp.
    func ranchCarrier() {
        guard let nest, let from = ranch.beasts.first?.pos else { return }
        let near = ants.indices.filter { i in
            guard case .wandering = ants[i].mode else { return false }
            return !ants[i].isChild && !ants[i].isHidden && ants[i].touch == nil
        }.min { hypot(ants[$0].pos.x - from.x, ants[$0].pos.y - from.y) < hypot(ants[$1].pos.x - from.x, ants[$1].pos.y - from.y) }
        guard let i = near else { return }
        ants[i].activityClock = 0
        ants[i].mode = .activity(.haul(load: 4, to: nest), remaining: 60)
    }

    /// The herd as the books have it (after any report, and when another Mac changed it).
    func applyBooksRanch(_ animals: [(id: Int, kind: String, bornAt: Date, caught: Bool, name: String)]?) {
        guard let animals, !ranch.dirty, !ranch.syncing else { return }
        let state = ranch
        if state.pensDirty { recomputePens() }
        let known = Dictionary(uniqueKeysWithValues: state.beasts.map { ($0.id, $0) })
        var next: [RanchBeast] = []
        for a in animals {
            if var have = known[a.id] {
                have.born = a.bornAt
                have.caught = a.caught
                have.name = a.name
                next.append(have)
            } else if let housing = RanchRules.kinds[a.kind]?.housing, housing != .pen {
                guard let home = freeHome(housing, near: nest ?? .zero, among: next) else { continue }
                var beast = RanchBeast(id: a.id, kind: a.kind, born: a.bornAt, caught: a.caught, pen: -1)
                beast.name = a.name
                beast.home = home
                beast.pos = home
                next.append(beast)
            } else if let pen = state.pens.indices.first(where: { p in next.filter { $0.pen == p }.count < penRoom(p) }) {
                var beast = RanchBeast(id: a.id, kind: a.kind, born: a.bornAt, caught: a.caught, pen: pen)
                beast.name = a.name
                beast.pos = randomSpot(in: pen)
                beast.target = beast.pos
                next.append(beast)
            }
        }
        if next.count != animals.count { state.dirty = true } // (some have no pen here: the books are told they are gone)
        state.beasts = next
        state.nextID = max(state.nextID, (animals.map(\.id).max() ?? 0) + 1)
    }

    // MARK: A camp of its own: ranch.json

    private func loadLocalRanch() {
        guard ProcessInfo.processInfo.environment["CAMP_NO_SAVE"] == nil, let data = try? Data(contentsOf: Persistence.url("ranch.json")),
              let file = try? JSONDecoder().decode(RanchFile.self, from: data) else { return }
        ranch.openSeconds = file.openSeconds
        ranch.carry = file.carry
        recomputePens()
        applyLocal(file.animals.map { ($0.id, $0.kind, $0.born, $0.caught, $0.name ?? "") })
    }

    private func applyLocal(_ animals: [(id: Int, kind: String, bornAt: Date, caught: Bool, name: String)]) {
        applyBooksRanch(animals)
        ranch.dirty = false
    }

    private func saveLocalRanch() {
        guard ProcessInfo.processInfo.environment["CAMP_NO_SAVE"] == nil else { return }
        let file = RanchFile(animals: ranch.beasts.map { .init(id: $0.id, kind: $0.kind, born: $0.born, caught: $0.caught, name: $0.name.isEmpty ? nil : $0.name) }, openSeconds: ranch.openSeconds, carry: ranch.carry)
        guard let data = try? JSONEncoder().encode(file) else { return }
        try? data.write(to: Persistence.url("ranch.json"), options: .atomic)
    }

    // MARK: The hand: catching, butchering, letting go

    /// Whether this wild animal can be kept (and so picked up).
    func canCatch(_ creature: Creature) -> Bool { !creature.kind.hostile && RanchRules.kinds[creature.kind.id] != nil }

    func pickUp(creature id: Int) {
        guard let c = creatures.first(where: { $0.id == id }), canCatch(c) else { return }
        ranch.held = id
        addFloater(Reactions.animal(c.kind.id), .common, at: CGPoint(x: c.pos.x, y: c.pos.y + 14))
    }

    /// The animal in the hand is let go at `p`: into a pen with room it is caught; anywhere else it bolts.
    func dropCreature(at p: CGPoint) {
        guard let id = ranch.held else { return }
        ranch.held = nil
        guard let c = creatures.first(where: { $0.id == id }) else { return }
        guard penAt(p) != nil else {
            startleCreature(id)
            if ranch.pens.isEmpty { addFloater("還沒有牧場：用柵欄圍一圈（🏡 裝飾 → 柵欄）", .common, at: p, important: true) }
            return
        }
        if let why = addBeast(c.kind.id, at: p) {
            startleCreature(id)
            addFloater(why, .common, at: p, important: true)
        } else {
            _ = takeCreature(id)
        }
    }

    /// A caught, full-grown one of `kind` joins the ranch at `p`: in the pen there, or on the perch / by the lamp nearest. Why not, or nil.
    @discardableResult
    func addBeast(_ kind: String, at p: CGPoint, quiet: Bool = false) -> String? {
        guard let rule = RanchRules.kinds[kind] else { return "牧場不養這種動物" }
        guard ranch.beasts.count < ranchCap else { return "營地最多養 \(ranchCap) 隻（營地長大會變多）" }
        var beast = RanchBeast(id: ranch.nextID, kind: kind, born: Date(), caught: true)
        if rule.housing == .pen {
            guard let pen = penAt(p) else { return "要放進牧場裡" }
            guard penCount(pen) < penRoom(pen) else { return "這個牧場滿了（\(penRoom(pen)) 隻）" }
            beast.pen = pen
            beast.pos = p
            beast.target = p
        } else {
            guard let home = freeHome(rule.housing, near: p, among: ranch.beasts) else { return rule.housing == .perch ? "沒有空的鷹架" : "養魂燈滿了（一盞 \(RanchRules.lampRoom) 個）" }
            beast.pen = -1
            beast.home = home
            beast.pos = p
        }
        ranch.nextID += 1
        ranch.beasts.append(beast)
        ranch.dirty = true
        if !quiet { addFloater(rule.housing == .lamp ? "收進養魂燈了" : "抓到一隻\(rule.name)！", .uncommon, at: p, important: true) }
        return nil
    }

    /// Where a resident would bring one of `kind`: the spot to let it go at (outside the fence; by the lamp) and where it ends up. Nil: no room.
    func roomFor(_ kind: String, near p: CGPoint) -> (door: CGPoint, home: CGPoint)? {
        guard let rule = RanchRules.kinds[kind], ranch.beasts.count < ranchCap else { return nil }
        if rule.housing != .pen {
            guard let home = freeHome(rule.housing, near: p, among: ranch.beasts) else { return nil }
            return (nearestWalkable(to: CGPoint(x: home.x, y: home.y - 12)), home)
        }
        var best: (door: CGPoint, home: CGPoint, d: CGFloat)?
        for (k, pen) in ranch.pens.enumerated() where penCount(k) < penRoom(k) {
            let inside = Set(pen)
            for cell in pen {
                for (dx, dy) in [(1, 0), (-1, 0), (0, 1), (0, -1)] {
                    let fence = GridCell(x: cell.x + dx, y: cell.y + dy), out = GridCell(x: cell.x + 2 * dx, y: cell.y + 2 * dy)
                    guard ranch.fenceCells.contains(fence), !ranch.fenceCells.contains(out), !inside.contains(out) else { continue }
                    let door = CGPoint(x: cellRect(out).midX, y: cellRect(out).midY)
                    guard walkable.contains(where: { $0.contains(door) }), penAt(door) == nil else { continue }
                    let d = hypot(door.x - p.x, door.y - p.y) - (ranch.gateCells.contains(fence) ? 10_000 : 0) // (by the gate, when there is one)
                    if d < (best?.d ?? .infinity) { best = (door, CGPoint(x: cellRect(cell).midX, y: cellRect(cell).midY), d) }
                }
            }
        }
        return best.map { ($0.door, $0.home) }
    }

    /// The penned animal under a point.
    func beastAt(_ p: CGPoint) -> Int? {
        if let v = ranch.visitor, hypot(v.perch.x - p.x, v.perch.y + RanchRules.perchTop + 6 - p.y) < 12 { return 0 } // (the wild eagle on a visit)
        return ranch.beasts.last { hypot($0.pos.x - p.x, $0.pos.y + 6 - p.y) < 11 }?.id
    }

    /// The drifting soul under a point.
    func wispAt(_ p: CGPoint) -> Int? { ranch.wisps.last { hypot($0.pos.x - p.x, $0.pos.y + 6 - p.y) < 12 }?.id }

    /// What a hover says of it.
    func beastLine(_ id: Int) -> String? {
        if id == 0 { return "野生的老鷹・點牠一下跟牠混熟（\(Settings.shared.ranchEagleTrust)／\(RanchRules.eagleTrust)）" }
        guard let b = ranch.beasts.first(where: { $0.id == id }), let kind = RanchRules.kinds[b.kind] else { return nil }
        let called = b.name.isEmpty ? "" : "\(b.name)・"
        if !b.grown { return "\(called)\(kind.young)・再 \(b.minutesToGrow) 分鐘長大" }
        let gives = kind.perHour.map { "每小時\(Materials.info($0.key)?.name ?? $0.key) \($0.value)" }.joined(separator: "、")
        return "\(called)\(kind.name)・" + (gives.isEmpty ? "可以宰來吃（右鍵）" : gives + "（營地開著時）")
    }

    /// The player names one (up to eight characters; nothing: no name).
    func name(beast id: Int, _ name: String) {
        guard let i = ranch.beasts.firstIndex(where: { $0.id == id }) else { return }
        ranch.beasts[i].name = String(name.trimmingCharacters(in: .whitespacesAndNewlines).prefix(8))
        ranch.dirty = true
    }

    // MARK: Chores: residents catch and feed; monsters raid the pens; the eagle; souls and bones

    /// What a resident may go after now: animals that wandered in and can be kept (by id), drifting souls (by minus their id).
    var herdTargets: [Int: CGPoint] {
        var out: [Int: CGPoint] = [:]
        for c in creatures where canCatch(c) && c.id != ranch.held { out[c.id] = c.pos }
        for w in ranch.wisps where w.id != ranch.heldWisp { out[-w.id] = w.pos }
        return out
    }

    func updateRanchChores(dt: Double) {
        let state = ranch
        let race = Characters.current.id
        // souls drift; the one in the hand follows the pointer
        for i in state.wisps.indices {
            if state.wisps[i].id == state.heldWisp, let cursor = hand.cursor { state.wisps[i].pos = CGPoint(x: cursor.x, y: cursor.y - 10); continue }
            state.wisps[i].pos.x += state.wisps[i].vel.dx * dt
            state.wisps[i].pos.y += state.wisps[i].vel.dy * dt + sin(state.wisps[i].life) * 0.2
            state.wisps[i].life -= dt
        }
        state.wisps.removeAll { $0.life <= 0 && $0.id != state.heldWisp }
        if var v = state.visitor {
            v.left -= dt
            state.visitor = v.left > 0 && homes(.perch).contains(where: { hypot($0.x - v.perch.x, $0.y - v.perch.y) < 2 }) ? v : nil
        }
        state.herders = state.herders.filter { (ant, _) in
            ants.contains { a in a.id == ant && { if case .activity(.herd, _) = a.mode { return true } else { return false } }() }
        }
        state.choreTimer -= dt
        guard state.choreTimer <= 0 else { return }
        state.choreTimer = 3
        let idle = ants.indices.filter { i in
            guard case .wandering = ants[i].mode else { return false }
            return !ants[i].isChild && !ants[i].isHidden && !ants[i].isWounded && ants[i].touch == nil
        }
        func nearest(_ p: CGPoint, within reach: CGFloat) -> Int? {
            idle.filter { hypot(ants[$0].pos.x - p.x, ants[$0].pos.y - p.y) < reach && state.herders[ants[$0].id] == nil }
                .min { hypot(ants[$0].pos.x - p.x, ants[$0].pos.y - p.y) < hypot(ants[$1].pos.x - p.x, ants[$1].pos.y - p.y) }
        }
        // 1. somebody goes after what could be kept (when there is room for it)
        if !monsterNear {
            for (target, p) in herdTargets where !state.herders.values.contains(target) {
                let kind = target < 0 ? "soul_beast" : creatures.first { $0.id == target }?.kind.id ?? ""
                guard roomFor(kind, near: p) != nil, Double.random(in: 0..<1) < 0.6, let i = nearest(p, within: 420) else { continue }
                ants[i].activityClock = 0
                ants[i].mode = .activity(.herd(target: target), remaining: 40)
                state.herders[ants[i].id] = target
                break // (one at a time)
            }
        }
        // 2. feeding time now and then
        state.tendTimer -= 3
        if state.tendTimer <= 0, let beast = state.beasts.filter({ $0.pen >= 0 }).randomElement(), let spot = roomlessDoor(of: beast.pen, near: beast.pos), let i = nearest(spot.door, within: 500) {
            state.tendTimer = Double.random(in: 50...110)
            ants[i].activityClock = 0
            ants[i].mode = .activity(.tend(spot: spot.door, face: spot.home), remaining: Double.random(in: 10...16))
        }
        // 3. monsters at the pens: they carry one off, unless something guards it
        state.raidTimer -= 3
        if state.raidTimer <= 0 {
            state.raidTimer = 6
            for m in creatures where m.kind.hostile {
                let near = state.beasts.indices.filter { state.beasts[$0].pen >= 0 && hypot(state.beasts[$0].pos.x - m.pos.x, state.beasts[$0].pos.y - m.pos.y) < 70 }
                guard !near.isEmpty else { continue }
                let guarded = decor.enumerated().contains { k, d in
                    ["guard", "wolfdog", "bonedog"].contains(DecorCatalog.kind(d.kind)?.fn ?? "") && hypot(decorNow(k).x - m.pos.x, decorNow(k).y - m.pos.y) < 160
                } || state.beasts.contains { ["bone_dog", "eagle"].contains($0.kind) && $0.grown }
                if guarded {
                    if Double.random(in: 0..<1) < 0.5 { addFloater("牧場有守衛：\(m.kind.name)被趕開了", .common, at: m.pos) }
                    continue
                }
                guard Double.random(in: 0..<1) < 0.35 else { continue }
                let small = near.filter { ["chicken", "rabbit", "bone_chicken"].contains(state.beasts[$0].kind) }
                let k = (small.isEmpty ? near : small).randomElement()!
                let lost = state.beasts.remove(at: k)
                state.dirty = true
                addFloater("\(m.kind.name)叼走了一隻\(RanchRules.kinds[lost.kind]?.name ?? "")！", .rare, at: lost.pos, important: true)
                break
            }
        }
        // 4. the eagle: a stoop at a monster when it is on the wing near one; and the alarm
        if let eagle = state.beasts.first(where: { $0.kind == "eagle" }), let m = creatures.first(where: { $0.kind.hostile }) {
            _ = decorAlarm(extra: 0, retreat: false)
            if eagle.flight > 0, hypot(eagle.pos.x - m.pos.x, eagle.pos.y - m.pos.y) < 30 {
                _ = handStrike(creature: m.id)
                addFloater("老鷹撲下去！", .uncommon, at: m.pos)
            }
        }
        // 5. visits: a wild eagle to an empty perch (elves); a beast's soul drifting through (the undead, with a lamp to keep it in)
        state.visitTimer -= 3 * RanchRules.scale
        guard state.visitTimer <= 0 else { return }
        state.visitTimer = Double.random(in: 240...480)
        if race == "elf", state.visitor == nil, let perch = freeHome(.perch, near: nest ?? .zero, among: state.beasts), state.beasts.count < ranchCap {
            state.visitor = (perch, 150, false)
            addFloater("一隻老鷹停在鷹架上", .uncommon, at: CGPoint(x: perch.x, y: perch.y + 70), important: true)
        }
        if race == "undead", state.wisps.count < 2, freeHome(.lamp, near: nest ?? .zero, among: state.beasts) != nil, state.beasts.count < ranchCap {
            let area = walkable.reduce(CGRect.null) { $0.union($1) }
            guard !area.isNull else { return }
            let fromLeft = Bool.random()
            let start = CGPoint(x: fromLeft ? area.minX + 4 : area.maxX - 4, y: CGFloat.random(in: area.minY + 30...max(area.minY + 31, area.maxY - 30)))
            state.wisps.append((state.nextWisp, start, CGVector(dx: (fromLeft ? 1 : -1) * Double.random(in: 5...9), dy: Double.random(in: -1.5...1.5)), 120))
            state.nextWisp += 1
            addFloater("一隻獸魂飄進來了", .uncommon, at: start, important: true)
        }
    }

    /// A spot outside pen `pen`'s fence nearest `p`, and the cell inside it faces (for feeding over the fence), full or not.
    private func roomlessDoor(of pen: Int, near p: CGPoint) -> (door: CGPoint, home: CGPoint)? {
        guard ranch.pens.indices.contains(pen) else { return nil }
        let inside = Set(ranch.pens[pen])
        var best: (door: CGPoint, home: CGPoint, d: CGFloat)?
        for cell in ranch.pens[pen] {
            for (dx, dy) in [(1, 0), (-1, 0), (0, 1), (0, -1)] {
                let fence = GridCell(x: cell.x + dx, y: cell.y + dy), out = GridCell(x: cell.x + 2 * dx, y: cell.y + 2 * dy)
                guard ranch.fenceCells.contains(fence), !ranch.fenceCells.contains(out), !inside.contains(out) else { continue }
                let door = CGPoint(x: cellRect(out).midX, y: cellRect(out).midY)
                guard walkable.contains(where: { $0.contains(door) }), penAt(door) == nil else { continue }
                let d = hypot(door.x - p.x, door.y - p.y) - (ranch.gateCells.contains(fence) ? 10_000 : 0)
                if d < (best?.d ?? .infinity) { best = (door, CGPoint(x: cellRect(cell).midX, y: cellRect(cell).midY), d) }
            }
        }
        return best.map { ($0.door, $0.home) }
    }

    /// A resident reached what it was after: it has it (three times in four) and carries it home, or it got away.
    func herdReached(_ target: Int, by index: Int) {
        ranch.herders[ants[index].id] = nil
        let at = ants[index].pos
        if target < 0 { // a soul
            guard let k = ranch.wisps.firstIndex(where: { $0.id == -target }), let room = roomFor("soul_beast", near: at) else { return }
            ranch.wisps.remove(at: k)
            ants[index].activityClock = 0
            ants[index].mode = .activity(.carryBeast(kind: "soul_beast", to: room.door, home: room.home), remaining: 90)
            return
        }
        guard let c = creatures.first(where: { $0.id == target }), canCatch(c), let room = roomFor(c.kind.id, near: at) else { return }
        if Double.random(in: 0..<1) < 0.75, takeCreature(target) != nil {
            ants[index].activityClock = 0
            ants[index].mode = .activity(.carryBeast(kind: c.kind.id, to: room.door, home: room.home), remaining: 90)
            ants[index].touch = Touch.react(.hop, 1, line: "抓到了！")
        } else {
            startleCreature(target)
            ants[index].touch = Touch.react(.none, 1.6, line: ["跑掉了！", "差一點…"].randomElement(), emote: "💦")
        }
    }

    /// A resident got what it carried to its home.
    func herdPenned(_ kind: String, home: CGPoint) {
        if let why = addBeast(kind, at: home) { addFloater("\(why)，放走了", .common, at: home) }
    }

    /// A dig turned up a beast's bone (the undead): three of them and room in a pen, and a bone beast is put together.
    func beastBoneFound(at p: CGPoint) {
        let bones = Settings.shared.ranchBones + 1
        Settings.shared.ranchBones = bones
        addFloater("挖到一塊獸骨（\(min(bones, RanchRules.bonesNeeded))／\(RanchRules.bonesNeeded)）", .uncommon, at: p, important: true)
        assembleBoneBeast(near: p)
    }

    func assembleBoneBeast(near p: CGPoint) {
        guard Settings.shared.ranchBones >= RanchRules.bonesNeeded else { return }
        let kind = ["bone_sheep", "bone_chicken", "bone_dog"].randomElement()!
        guard let room = roomFor(kind, near: p) else {
            if ranch.pens.isEmpty { addFloater("獸骨湊齊了：圍一圈鐵柵就能拼出骨獸", .uncommon, at: p, important: true) }
            return
        }
        guard addBeast(kind, at: room.home, quiet: true) == nil else { return }
        Settings.shared.ranchBones -= RanchRules.bonesNeeded
        addFloater("拼好了一隻\(RanchRules.kinds[kind]?.name ?? "")！", .rare, at: room.home, important: true)
    }

    /// A pat for the wild eagle on its visit (one a visit counts): after a few it stays.
    func patVisitor() {
        guard var v = ranch.visitor else { return }
        let at = CGPoint(x: v.perch.x, y: v.perch.y + 80)
        guard !v.patted else { return addFloater("（牠瞄了你一眼）", .common, at: at) }
        v.patted = true
        ranch.visitor = v
        let trust = Settings.shared.ranchEagleTrust + 1
        if trust >= RanchRules.eagleTrust, addBeast("eagle", at: v.perch, quiet: true) == nil {
            Settings.shared.ranchEagleTrust = 0
            ranch.visitor = nil
            addFloater("老鷹留下來了！", .rare, at: at, important: true)
        } else {
            Settings.shared.ranchEagleTrust = min(trust, RanchRules.eagleTrust - 1)
            addFloater("老鷹讓你摸了一下（\(Settings.shared.ranchEagleTrust)／\(RanchRules.eagleTrust)）", .uncommon, at: at, important: true)
        }
    }

    /// A drifting soul taken in the hand, and let go: by a lamp with room it is kept; elsewhere it drifts on.
    func pickUp(wisp id: Int) { ranch.heldWisp = id }

    func dropWisp(at p: CGPoint) {
        guard let id = ranch.heldWisp else { return }
        ranch.heldWisp = nil
        guard let k = ranch.wisps.firstIndex(where: { $0.id == id }) else { return }
        guard let lamp = homes(.lamp).min(by: { hypot($0.x - p.x, $0.y - p.y) < hypot($1.x - p.x, $1.y - p.y) }), hypot(lamp.x - p.x, lamp.y + 20 - p.y) < 46 else {
            if homes(.lamp).isEmpty { addFloater("要有養魂燈才養得住（🏡 裝飾 → 活物）", .common, at: p, important: true) }
            return
        }
        if let why = addBeast("soul_beast", at: lamp) { addFloater(why, .common, at: p, important: true) } else { ranch.wisps.remove(at: k) }
    }

    /// Whether it can be butchered (a grown one that gives meat; elves eat no meat).
    func canButcher(_ id: Int) -> Bool {
        guard let b = ranch.beasts.first(where: { $0.id == id }) else { return false }
        return b.grown && !(RanchRules.kinds[b.kind]?.butcher.isEmpty ?? true) && Characters.current.id != "elf"
    }

    func butcher(_ id: Int) {
        guard canButcher(id), let i = ranch.beasts.firstIndex(where: { $0.id == id }) else { return }
        let beast = ranch.beasts.remove(at: i)
        ranch.butchered.append(id)
        ranch.dirty = true
        addHit(at: beast.pos)
        if !followsBooks, let meat = RanchRules.kinds[beast.kind]?.butcher { _ = exchangeLocally(give: [:], get: meat); ranchGained(meat) }
    }

    func release(beast id: Int) {
        guard let i = ranch.beasts.firstIndex(where: { $0.id == id }) else { return }
        let beast = ranch.beasts.remove(at: i)
        ranch.dirty = true
        addFloater("\(RanchRules.kinds[beast.kind]?.name ?? "")放走了", .common, at: beast.pos)
    }
}

// MARK: - Test (`CAMP_TEST_RANCH=/path/prefix`, with `CAMP_RANCH_SCALE=300`)

/// At 20 s fences a pen by the camp, lets two sheep, two chickens and a pig in and catches them; draws the camp (`-a.png`); half
/// a minute later (hours, in the pens' time) says what was born and what the herd gave, butchers the pig, draws again (`-b.png`).
enum RanchTest {
    static let prefix = ProcessInfo.processInfo.environment["CAMP_TEST_RANCH"]
    static var step = 0
    static var before = 0
    static var logged = false
    static let started = Date()
}

extension Colony {
    fileprivate func runRanchTest(_ prefix: String) {
        let t = Date().timeIntervalSince(RanchTest.started)
        func shoot(_ path: String) {
            guard let view = NSApp.windows.compactMap({ $0.contentView as? AntView }).first(where: \.isMap), let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
            view.cacheDisplay(in: view.bounds, to: rep)
            try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
        }
        func herd() -> String {
            let counts = Dictionary(grouping: ranch.beasts, by: { $0.kind + ($0.grown ? "" : "(young)") }).mapValues(\.count)
            return "\(counts.sorted { $0.key < $1.key }.map { "\($0.key) \($0.value)" }.joined(separator: ", "))"
        }
        let race = Characters.current.id
        func spawn(_ id: String, _ dx: CGFloat, _ dy: CGFloat) -> Int? {
            guard let nest, let animal = Animals.all.first(where: { $0.id == id }) else { return nil }
            debugSpawnCreature(kind: animal, at: CGPoint(x: nest.x + dx, y: nest.y + dy))
            return creatures.last?.id
        }
        switch RanchTest.step {
        case 0 where t > 20:
            RanchTest.step = 1
            guard let nest else { return }
            let kind = race == "elf" ? "e_fence" : race == "undead" ? "u_fence" : "g_fence"
            let c = DecorCatalog.fenceCell, origin = CGPoint(x: nest.x + 60, y: nest.y + 30)
            var laid = 0, refused = Set<String>()
            for i in 0..<7 { for j in 0..<5 where i == 0 || i == 6 || j == 0 || j == 4 {
                if let why = placeDecor(kind, at: CGPoint(x: origin.x + Double(i) * c, y: origin.y + Double(j) * c)) { refused.insert(why) } else { laid += 1 }
            } }
            recomputePens()
            print("ranch test: \(race) laid \(laid) fence pieces (refused: \(refused)), pens \(ranch.pens.map(\.count)), room \(ranch.pens.indices.map(penRoom)), cap \(ranchCap)")
            guard let pen = ranch.pens.first else { fflush(stdout); return }
            if let wild = spawn("sheep", -60, -60) { // one by hand
                pickUp(creature: wild)
                dropCreature(at: CGPoint(x: cellRect(pen[0]).midX, y: cellRect(pen[0]).midY))
            }
            for (k, id) in ["sheep", "chicken", "chicken", "pig", "deer", "rabbit"].enumerated() { _ = spawn(id, -80 + CGFloat(k) * 20, -70) } // the rest for the residents
            if race == "elf" { print("ranch test: perch \(placeDecor("e_eagleperch", at: CGPoint(x: nest.x - 60, y: nest.y + 40)) ?? "placed")"); ranch.visitTimer = 0 }
            if race == "undead" {
                print("ranch test: lamp \(placeDecor("u_soullamp", at: CGPoint(x: nest.x - 60, y: nest.y + 40)) ?? "placed")")
                ranch.visitTimer = 0
                for _ in 0..<3 { beastBoneFound(at: nest) }
            }
            print("ranch test: by hand \(herd()); wild \(creatures.map(\.kind.id))")
            fflush(stdout)
        case 1 where t > 30:
            RanchTest.step = 2
            if race == "elf" {
                for _ in 0..<3 { ranch.visitor?.patted = false; patVisitor() }
                print("ranch test: eagle visitor \(ranch.visitor != nil), tamed \(ranch.beasts.contains { $0.kind == "eagle" })")
            }
            if race == "undead" { print("ranch test: wisps \(ranch.wisps.count), bones left \(Settings.shared.ranchBones)") }
            print("ranch test: at 10 s \(herd()); still wild \(creatures.map(\.kind.id)); herding \(ranch.herders.count)")
            fflush(stdout)
            shoot(prefix + "-a.png")
        case 2 where t > 50:
            RanchTest.step = 3
            print("ranch test: after \(Int((t - 20) * RanchRules.scale / 60)) pen-minutes: \(herd()); still wild \(creatures.map(\.kind.id)); materials \(materials.filter { !["log", "stone"].contains($0.key) })")
            if let pig = ranch.beasts.first(where: { $0.kind == "pig" && $0.grown }) { butcher(pig.id); print("ranch test: butchered a pig: can \(race != "elf"), meat \(materials["food_meat"] ?? 0)") }
            if let b = ranch.beasts.first(where: { $0.pen >= 0 }), let nest { _ = spawn("giant_rat", b.pos.x - nest.x + 10, b.pos.y - nest.y) }
            RanchTest.before = ranch.beasts.count
            ranch.raidTimer = 0
            fflush(stdout)
            shoot(prefix + "-b.png")
        case 3 where t > 53 && RanchTest.before > 0 && !RanchTest.logged:
            RanchTest.logged = true
            let rat = creatures.first { $0.kind.hostile }
            let d = rat.map { r in ranch.beasts.filter { $0.pen >= 0 }.map { hypot($0.pos.x - r.pos.x, $0.pos.y - r.pos.y) }.min() ?? -1 }
            print("ranch test: 3 s on, rat \(rat.map { "hp \($0.hp)" } ?? "gone"), nearest penned animal \(d.map { Int($0) } ?? -1) pt away")
            fflush(stdout)
        case 3 where t > 62:
            RanchTest.step = 4
            let inside = ants.filter { !$0.isHidden && penAt($0.pos) != nil }.count
            print("ranch test: a rat at the pen for 12 s: \(RanchTest.before) -> \(ranch.beasts.count) animals; rat still here: \(creatures.contains { $0.kind.hostile }); residents inside a pen: \(inside)")
            fflush(stdout)
            NSApp.terminate(nil)
        default: break
        }
    }
}
