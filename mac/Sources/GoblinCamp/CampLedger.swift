import CampRules
import Foundation

/// The camp's books as the server keeps them (server/CAMP.md): fetched, kept on this Mac for when it is offline (camp.json),
/// and turned into what `Colony.restore` already reads. Where the camp stands and its land stay this Mac's own
/// (camp-local.json; see `Persistence`).
final class CampLedger {
    /// A piece as the books have it (`pinned`: put on by hand; `held`: taken off by hand into the store).
    struct GearPiece: Codable {
        let id: String
        let left: Double
        var pinned: Bool?
        var held: Bool?
        var item: GearItem { GearItem(id: id, left: left, pinned: pinned == true, held: held == true) }
    }

    struct Resident: Codable {
        let id: Int
        let breed: String
        let seed: Double
        let legacySeed: String?
        let name: String?
        let parents: String?
        let bornAt: String
        let diesAt: String?
        let gear: [String: GearPiece]?
        let place: String
    }

    /// `GET /api/camp` (shared/src/camp/api.ts `CampView`).
    struct View: Codable {
        let race: String
        let seed: Double
        let startedAt: String
        let advancedTo: String
        let nextSlot: Int
        let nextId: Int
        let peak: Int
        let stage: Int
        let version: Int
        let materials: [String: Int]
        let larder: [String: Int]
        let armory: [GearPiece]
        /// Whether the store is handed out by itself; missing from older servers (on).
        let autoGear: Bool?
        let boosts: [String: String]
        let foodCooldowns: [String: String]
        let princessName: String
        let romance: RomanceState?
        let kills: [String: Int]
        let delivered: Int
        /// 聖光模式 (server/CAMP.md §7); missing from older servers.
        struct Sanctuary: Codable, Equatable { let since: String?; let canTurnOnAt: String? }
        let sanctuary: Sanctuary?
        /// The camp's sites and what they make (server/FARM.md §11, shared/src/camp/api.ts `CampProduction`); missing from older servers.
        struct Production: Codable {
            struct Busy: Codable { let site: Int; let until: String }
            struct Next: Codable { let level: Int; let cost: [String: Int]; let hours: Double; let makes: [String: Double] }
            struct Site: Codable {
                let id: Int
                let kind: String
                let name: String
                /// 0: still being built.
                let level: Int
                let maxLevel: Int
                let parts: [String]?
                let makes: [String: Double]
                let busyUntil: String?
                let next: Next?
                /// nil: it cannot be taken down (the farm).
                let refund: [String: Int]?
            }
            struct Buildable: Codable { let kind: String; let name: String; let cost: [String: Int]; let hours: Double; let makes: [String: Double] }
            let slots: Int
            let used: Int
            let workers: Int
            let need: Int
            let share: Double
            let perHour: [String: Double]
            let busy: Busy?
            let sites: [Site]
            let buildable: [Buildable]

            var farm: Site? { sites.first { $0.kind == "farm" } }
        }
        let production: Production?
        /// The wandering merchant while it is at the camp (Merchant.swift); older servers leave it out.
        let merchant: MerchantVisitInfo?
        /// The decorations put down (Decor.swift); older servers leave it out.
        let decor: [DecorPlaced]?
        /// The ranch's animals (Ranch.swift); older servers leave it out.
        struct RanchView: Codable {
            struct Animal: Codable { let id: Int; let kind: String; let bornAt: String; let caught: Bool?; let name: String? }
            let animals: [Animal]
        }
        let ranch: RanchView?
        /// The pomodoro's focus rounds, and what they bring today (shared/src/camp/focus.ts); older servers leave it out.
        let focus: FocusInfo?
        /// The quests' decorations earned (shared/src/camp/quests.ts `decorEarned`); older servers leave it out.
        let decorEarned: [String]?
        let residents: [Resident]

        private enum CodingKeys: String, CodingKey {
            case race, seed, startedAt, advancedTo, nextSlot, nextId, peak, stage, version, materials, larder, armory, autoGear, boosts, foodCooldowns
            case princessName, romance, kills, delivered, sanctuary, production, merchant, decor, ranch, focus, decorEarned, residents
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            race = try c.decode(String.self, forKey: .race)
            seed = try c.decode(Double.self, forKey: .seed)
            startedAt = try c.decode(String.self, forKey: .startedAt)
            advancedTo = try c.decode(String.self, forKey: .advancedTo)
            nextSlot = try c.decode(Int.self, forKey: .nextSlot)
            nextId = try c.decode(Int.self, forKey: .nextId)
            peak = try c.decode(Int.self, forKey: .peak)
            stage = try c.decode(Int.self, forKey: .stage)
            version = try c.decode(Int.self, forKey: .version)
            materials = try c.decode([String: Int].self, forKey: .materials)
            larder = try c.decode([String: Int].self, forKey: .larder)
            armory = try c.decode([GearPiece].self, forKey: .armory)
            autoGear = try? c.decodeIfPresent(Bool.self, forKey: .autoGear)
            boosts = try c.decode([String: String].self, forKey: .boosts)
            foodCooldowns = try c.decode([String: String].self, forKey: .foodCooldowns)
            princessName = try c.decode(String.self, forKey: .princessName)
            romance = try? c.decodeIfPresent(RomanceState.self, forKey: .romance) // (a story from another version: start hers afresh)
            kills = try c.decode([String: Int].self, forKey: .kills)
            delivered = try c.decode(Int.self, forKey: .delivered)
            sanctuary = try? c.decodeIfPresent(Sanctuary.self, forKey: .sanctuary)
            production = try? c.decodeIfPresent(Production.self, forKey: .production)
            merchant = try? c.decodeIfPresent(MerchantVisitInfo.self, forKey: .merchant)
            decor = try? c.decodeIfPresent([DecorPlaced].self, forKey: .decor)
            ranch = try? c.decodeIfPresent(RanchView.self, forKey: .ranch)
            focus = try? c.decodeIfPresent(FocusInfo.self, forKey: .focus)
            decorEarned = try? c.decodeIfPresent([String].self, forKey: .decorEarned)
            residents = try c.decode([Resident].self, forKey: .residents)
        }
    }

    /// A raid the server fought (shared/src/camp: RaidOutcome), as far as the Mac plays it.
    struct Raid: Decodable {
        struct Monsters: Decodable { let id: String; let count: Int }
        let monsters: [Monsters]
        let fallen: [Int]
        let loot: [String: Int]
        let killed: [String: Int]
        let winner: String
    }

    /// A party in the big world (server/WORLD.md §15): setting out, arriving, or another camp's party at one of ours.
    struct Expedition: Decodable {
        let setOut: Bool?
        let arrived: Bool?
        let defended: Bool?
        let won: Bool?
        /// attack, move, guard, recall (walking back from a cell), reroute (the rest of a recall, looking for room)
        let kind: String?
        /// cleared, taken, settled, held, back, guarding, camping
        let cell: String?
        let against: String?
        let loot: [String: Int]?
        let fallen: Int?
        let killed: Int?
        /// Who attacked (when `defended`).
        let by: String?
        /// Damage done to a great monster of the world.
        let damage: Int?
    }

    /// A lair came back for one of the camp's cells in the big world.
    struct LairBack: Decodable {
        let name: String
        let level: Int
        let held: Bool
        let fallen: Int
        let loot: [String: Int]
    }

    /// The share of a great monster's spoils this camp got (it helped beat it).
    struct BossReward: Decodable {
        let name: String
        let loot: [String: Int]
        let xp: Int
        let share: Double
    }

    /// A site was built or went up a level (for the farm, `part` is what the level added).
    struct SiteDone: Decodable { let site: Int; let kind: String; let level: Int; let name: String; let part: String? }

    /// One thing that happened in the camp (`GET /api/camp/events`); raids and the big world's parties are read.
    struct Event: Decodable {
        let seq: Int
        let at: String
        let kind: String
        let raid: Raid?
        let expedition: Expedition?
        let bossReward: BossReward?
        /// What the held cells of the big world yielded (material → how many).
        let yields: [String: Int]?
        let lairBack: LairBack?
        let site: SiteDone?
        /// A focus round done: the day's count so far (shared/src/camp/focus.ts).
        let focusRounds: Int?
        private enum CodingKeys: String, CodingKey { case seq, at, kind, data }
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            seq = try c.decode(Int.self, forKey: .seq)
            at = try c.decode(String.self, forKey: .at)
            kind = try c.decode(String.self, forKey: .kind)
            raid = kind == "raid" ? try? c.decode(Raid.self, forKey: .data) : nil
            expedition = kind == "expedition" ? try? c.decode(Expedition.self, forKey: .data) : nil
            site = kind == "site" ? try? c.decode(SiteDone.self, forKey: .data) : nil
            struct Focus: Decodable { let rounds: Int }
            focusRounds = kind == "focus" ? (try? c.decode(Focus.self, forKey: .data))?.rounds : nil
            struct World: Decodable { let bossReward: BossReward?; let yields: [String: Int]?; let lairBack: LairBack? }
            let world = kind == "world" ? try? c.decode(World.self, forKey: .data) : nil
            bossReward = world?.bossReward
            yields = world?.yields
            lairBack = world?.lairBack
        }
    }

    private let api: APIClient
    private let cacheURL: URL
    private let seenURL: URL
    /// The newest event this Mac has handled (nil: none yet; the history before signing in here is not played).
    private var seenSeq: Int?
    private let debug = ProcessInfo.processInfo.environment["CAMP_DEBUG"] != nil
    /// The last books this Mac saw (from the server, or from camp.json while offline).
    private(set) var view: View?
    /// Who lives at home now: the books, plus the births and deaths this Mac has worked out since (the shared rules, so the
    /// server works out the same; raids and commands only come with the next books).
    private(set) var residents: [Resident] = []
    private var rules: (place: CampPlace, population: CampPopulation)?

    init(api: APIClient) {
        self.api = api
        let env = ProcessInfo.processInfo.environment
        let base = env["CAMP_DATA_DIR"].map { URL(fileURLWithPath: $0) }
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("GoblinCamp")
        cacheURL = base.appendingPathComponent("camp.json")
        seenURL = base.appendingPathComponent("camp-seen.json")
        if let data = try? Data(contentsOf: seenURL), let seq = try? JSONDecoder().decode(Int.self, from: data) { seenSeq = seq }
        if let data = try? Data(contentsOf: cacheURL), let saved = try? JSONDecoder().decode(View.self, from: data) { take(saved) }
    }

    /// Starts working births and deaths out from these books.
    private func take(_ view: View) {
        self.view = view
        residents = view.residents.filter { $0.place == "home" }
        let ms = { (text: String) -> Double? in ServerTime.parse(text).map { ($0.timeIntervalSince1970 * 1000).rounded() } }
        let rule = Races.rules(view.race)
        let place = CampPlace(race: view.race, key: "home", startedAt: ms(view.startedAt) ?? 0, birthMinutes: rule.homeBirthMinutes, cap: rule.homeCap,
                              sanctuary: view.sanctuary?.since != nil)
        let alive = residents.map { r in
            CampResident(id: r.id, breed: r.breed, seed: UInt32(truncatingIfNeeded: Int64(r.seed)), bornAt: ms(r.bornAt) ?? 0, diesAt: r.diesAt.flatMap(ms))
        }
        rules = (place, CampPopulation(residents: alive, nextId: view.nextId, nextSlot: view.nextSlot, peak: view.peak))
    }

    /// Works births and deaths out up to `now` on this Mac (between books, and while offline). Returns whether anyone came or went.
    @discardableResult
    func advanceHere(to now: Date = Date()) -> Bool {
        guard let view, var rules else { return false }
        let step = Population.advance(rules.place, &rules.population, campSeed: Int(view.seed), to: (now.timeIntervalSince1970 * 1000).rounded())
        self.rules = rules
        guard !step.born.isEmpty || !step.died.isEmpty else { return false }
        let gone = Set(step.died.map(\.id))
        residents.removeAll { gone.contains($0.id) }
        let iso = { (ms: Double) in ServerTime.format(Date(timeIntervalSince1970: ms / 1000)) }
        for b in step.born where !gone.contains(b.id) {
            residents.append(Resident(id: b.id, breed: b.breed, seed: Double(b.seed), legacySeed: nil, name: nil, parents: nil,
                                      bornAt: iso(b.bornAt), diesAt: b.diesAt.map(iso), gear: nil, place: "home"))
        }
        if debug { NSLog("GoblinCamp: camp here: +\(step.born.count) −\(step.died.count) → \(residents.count)") }
        return true
    }

    /// Residents alive but away from home (on a held cell of the big world, or on the road): the camp lets them walk off.
    func awayIDs() -> Set<Int> {
        Set((view?.residents ?? []).filter { $0.place != "home" }.map(\.id))
    }

    /// The residents as the camp takes them (`Colony.applyBooks`).
    func bookResidents(now: Date = Date()) -> [BookResident] {
        residents.map { r in
            var share: Double?
            if let dies = r.diesAt.flatMap(ServerTime.parse), let born = ServerTime.parse(r.bornAt), dies > born {
                share = min(1, max(0, now.timeIntervalSince(born) / dies.timeIntervalSince(born)))
            }
            let gear = (r.gear ?? [:]).mapValues(\.item)
            return BookResident(id: r.id, breed: r.breed, seed: r.legacySeed.flatMap { UInt64($0) } ?? UInt64(r.seed), name: r.name,
                                parents: r.parents, lifeShare: share, gear: gear)
        }
    }

    /// What the camp owns, as the books have it.
    func bookStores() -> BookStores? {
        guard let view else { return nil }
        let now = Date()
        func secondsLeft(_ ends: [String: String]) -> [String: Double] {
            ends.compactMapValues { ServerTime.parse($0).map { $0.timeIntervalSince(now) } }.filter { $0.value > 0 }
        }
        return BookStores(materials: view.materials, kills: view.kills, larder: view.larder,
                          armory: view.armory.map(\.item), peak: max(view.peak, residents.count), delivered: view.delivered,
                          boosts: secondsLeft(view.boosts), cooldowns: secondsLeft(view.foodCooldowns),
                          farmLevel: view.production?.farm?.level ?? 1, race: view.race,
                          sites: (view.production?.sites ?? []).filter { $0.kind != "farm" }.map { (id: $0.id, kind: $0.kind, level: $0.level) },
                          autoGear: view.autoGear ?? true)
    }

    /// What happened since this Mac last looked (oldest first). The first time, everything before is taken as seen.
    func newEvents() async throws -> [Event] {
        struct Page: Decodable { let events: [Event]; let seq: Int }
        var all: [Event] = []
        var since = seenSeq ?? 0
        for _ in 0..<40 {
            let page: Page = try await api.request("GET", "camp/events?since=\(since)")
            all += page.events
            if page.events.count < 500 || page.seq == since { since = page.seq; break }
            since = page.seq
        }
        let first = seenSeq == nil
        seenSeq = max(seenSeq ?? 0, since)
        try? JSONEncoder().encode(seenSeq).write(to: seenURL, options: .atomic)
        return first ? [] : all
    }

    // MARK: Commands, queued (so they wait while offline and are done once: each has its own requestId)

    /// One command as it is sent (shared/src/camp/api.ts `campCommand`); fields a kind does not use stay out.
    struct Queued: Codable {
        let requestId: String
        let kind: String
        var gear: String?
        var resident: Int?
        var slot: String?
        var stock: Int?
        var food: String?
        var name: String?
        var romance: RomanceState?
        /// craft: for whom; gear-hold: held or not; auto-gear: on or off.
        var to: Int?
        var held: Bool?
        var on: Bool?
        init(kind: String) { requestId = UUID().uuidString.lowercased(); self.kind = kind }
    }

    private(set) var pending: [Queued] = []
    private var pendingURL: URL { cacheURL.deletingLastPathComponent().appendingPathComponent("camp-pending.json") }
    private var sending = false

    func enqueue(_ command: Queued) {
        pending.append(command)
        savePending()
    }

    private func savePending() {
        try? JSONEncoder().encode(pending).write(to: pendingURL, options: .atomic)
    }

    func loadPending() {
        if let data = try? Data(contentsOf: pendingURL), let saved = try? JSONDecoder().decode([Queued].self, from: data) { pending = saved }
    }

    /// Sends the queue in order. Each answer (or refusal: its reason) goes to `answered`; offline, the rest wait for next time.
    /// On the main thread: `answered` touches windows (it once built the roster panel off it, and AppKit killed the app).
    @MainActor
    func sendPending(answered: @escaping (Queued, Result<CommandAnswer, APIError>) -> Void) async {
        guard !sending else { return }
        sending = true
        defer { sending = false }
        while let next = pending.first {
            do {
                let answer: CommandAnswer = try await api.request("POST", "camp/commands", body: next)
                _ = keep(answer.camp)
                pending.removeFirst()
                savePending()
                answered(next, .success(answer))
            } catch let error as APIError where error.isOffline || error.isUnauthorized || error.status >= 500 {
                return // try again later
            } catch let error as APIError {
                pending.removeFirst() // refused (not enough, cooling down…): it will not go through later either
                savePending()
                answered(next, .failure(error))
            } catch {
                return
            }
        }
    }

    /// `POST /api/camp/commands` (shared/src/camp/api.ts `campCommand`): the answer, and the books after it.
    struct CommandAnswer: Decodable { let message: String; let resident: Int?; let camp: View }

    func command<Body: Encodable>(_ body: Body) async throws -> CommandAnswer {
        let answer: CommandAnswer = try await api.request("POST", "camp/commands", body: body)
        _ = keep(answer.camp)
        return answer
    }

    private func keep(_ view: View) -> View {
        take(view)
        do {
            try FileManager.default.createDirectory(at: cacheURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(view).write(to: cacheURL, options: .atomic)
        } catch {
            NSLog("GoblinCamp: keeping camp.json failed: \(error)")
        }
        if debug { NSLog("GoblinCamp: camp: v\(view.version) \(view.race), \(view.residents.count) residents, peak \(view.peak)") }
        return view
    }

    // MARK: Talking to the server

    /// The account's camp now (the server works births, deaths and raids out first), or nil when it has none.
    func fetch() async throws -> View? {
        do {
            let fresh: View = try await api.request("GET", "camp")
            return keep(fresh)
        } catch let error as APIError where error.status == 404 {
            return nil
        }
    }

    /// A new camp (`replace`: 開新世界 over the old one).
    func start(race: String, replace: Bool) async throws -> View {
        struct Body: Encodable { let race: String }
        let made: View = try await api.request("POST", replace ? "camp/new-world" : "camp/start", body: Body(race: race))
        return keep(made)
    }

    /// Moves this Mac's old camp (state.json) in. `replace`: the account has a camp and the player chose this Mac's.
    func migrate(_ saved: SavedState, replace: Bool) async throws -> View {
        struct Piece: Encodable { let id: String; let left: Double? }
        struct Goblin: Encodable {
            let id: Int, breed: String, age: Double
            /// A string: the 64-bit seed would lose digits as a JSON number.
            let seed: String
            let name: String?, gear: [String: Piece]?, parents: String?
        }
        struct Save: Encodable {
            let goblins: [Goblin]
            let princessName: String?, materials: [String: Int]?, kills: [String: Int]?, peak: Int?, larder: [String: Int]?
            let armoryItems: [Piece]?, romance: RomanceState?, delivered: Int?
        }
        struct Body: Encodable { let race: String; let replace: Bool; let save: Save }
        let goblins = (saved.goblins ?? []).map { g in
            Goblin(id: g.id, breed: g.breed, age: g.age, seed: String(g.seed), name: g.name,
                   gear: g.gear?.mapValues { Piece(id: $0.id, left: $0.left) }, parents: g.parents)
        }
        var armory = (saved.armoryItems ?? []).map { Piece(id: $0.id, left: $0.left) }
        for (id, n) in saved.armory ?? [:] { armory += Array(repeating: Piece(id: id, left: nil), count: n) }
        let save = Save(goblins: goblins, princessName: saved.princessName, materials: saved.materials, kills: saved.kills, peak: saved.peak,
                        larder: saved.larder, armoryItems: armory.isEmpty ? nil : armory, romance: saved.romance, delivered: saved.delivered)
        let moved: View = try await api.request("POST", "camp/migrate", body: Body(race: saved.race ?? "goblin", replace: replace, save: save))
        return keep(moved)
    }

    // MARK: Into the Mac's camp

    /// The books as a `SavedState` for `Colony.restore`, with this Mac's own parts (where the camp stands, its land) from `local`.
    /// Ages: the share of its life a resident has lived is kept (the Mac counts lifespans in its own units).
    func savedState(nest: CGPoint, local: SavedState?, now: Date = Date()) -> SavedState? {
        guard let view else { return nil }
        let character = Characters.all.first { $0.id == view.race } ?? Characters.current
        let goblins: [SavedGoblin] = view.residents.filter { $0.place == "home" }.map { r in
            let born = ServerTime.parse(r.bornAt) ?? now
            let lived = max(0, now.timeIntervalSince(born))
            var age = lived
            if let diesText = r.diesAt, let dies = ServerTime.parse(diesText), dies > born {
                let share = min(1, lived / dies.timeIntervalSince(born))
                let stat = character.breeds.first { $0.id == r.breed }?.stats.lifespan ?? 1
                age = share * Traits.baseLifespan * stat
            }
            return SavedGoblin(id: r.id, breed: r.breed, age: age, seed: r.legacySeed.flatMap { UInt64($0) } ?? UInt64(r.seed), name: r.name,
                               gear: r.gear?.mapValues { SavedGear(id: $0.id, left: $0.left, pinned: $0.pinned == true) }, parents: r.parents)
        }
        func secondsLeft(_ ends: [String: String]) -> [String: Double]? {
            let left = ends.compactMapValues { ServerTime.parse($0).map { $0.timeIntervalSince(now) } }.filter { $0.value > 0 }
            return left.isEmpty ? nil : left
        }
        return SavedState(nestX: nest.x, nestY: nest.y, antCount: goblins.count, goblins: goblins, delivered: view.delivered, nextID: view.nextId,
                          princessName: view.princessName.isEmpty ? nil : view.princessName, materials: view.materials, kills: view.kills, peak: view.peak,
                          playSeconds: local?.playSeconds, larder: view.larder, terrain: local?.terrain, terrains: local?.terrains,
                          armoryItems: view.armory.map { SavedGear(id: $0.id, left: $0.left, held: $0.held == true) }, romance: view.romance,
                          boosts: secondsLeft(view.boosts), foodCooldowns: secondsLeft(view.foodCooldowns), race: view.race)
    }
}
