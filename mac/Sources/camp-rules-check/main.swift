// Works out shared/src/camp/fixtures.json again with the Swift rules and reports every difference.
//   swift run camp-rules-check [path to fixtures.json]
// Exit status 0 when everything matches (the Mac and the server work out the same camp), 1 otherwise.
import CampRules
import Foundation

let path = CommandLine.arguments.dropFirst().first ?? "../shared/src/camp/fixtures.json"
guard let data = FileManager.default.contents(atPath: path),
      let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
    print("cannot read \(path)")
    exit(1)
}

var problems: [String] = []
var checks = 0
func expect(_ what: String, _ ok: Bool, _ detail: @autoclosure () -> String = "") {
    checks += 1
    if !ok { problems.append("✗ \(what) \(detail())") }
}
func number(_ any: Any?) -> Double? { (any as? NSNumber)?.doubleValue }

func residentMatches(_ what: String, _ json: Any?, _ r: CampResident) {
    guard let j = json as? [String: Any] else { return expect(what, false, "missing") }
    expect("\(what).id", number(j["id"]) == Double(r.id), "\(j["id"] ?? "nil") vs \(r.id)")
    expect("\(what).breed", j["breed"] as? String == r.breed, "\(j["breed"] ?? "nil") vs \(r.breed)")
    expect("\(what).seed", number(j["seed"]) == Double(r.seed), "\(j["seed"] ?? "nil") vs \(r.seed)")
    expect("\(what).bornAt", number(j["bornAt"]) == r.bornAt, "\(j["bornAt"] ?? "nil") vs \(r.bornAt)")
    expect("\(what).diesAt", number(j["diesAt"]) == r.diesAt, "\(j["diesAt"] ?? "nil") vs \(String(describing: r.diesAt))")
}

// the building blocks
let basics = root["basics"] as? [String: Any] ?? [:]
for item in basics["hashes"] as? [[String: Any]] ?? [] {
    let text = item["text"] as? String ?? ""
    expect("hash(\"\(text)\")", number(item["hash"]) == Double(CampRandom.hash(text)), "\(item["hash"] ?? "nil") vs \(CampRandom.hash(text))")
}
if let randoms = basics["randoms"] as? [String: Any], let seed = number(randoms["seed"]) {
    var g = CampRandom.Generator(seed: UInt32(seed))
    for (i, want) in (randoms["first"] as? [Any] ?? []).enumerated() {
        let got = g.next()
        expect("random #\(i)", number(want) == got, "\(want) vs \(got)")
    }
}

// the race table
let rules = root["rules"] as? [String: Any] ?? [:]
expect("baseLifespanHours", number(rules["baseLifespanHours"]) == Races.baseLifespanHours)
for (race, any) in rules["races"] as? [String: Any] ?? [:] {
    guard let j = any as? [String: Any], let r = Races.all[race] else { expect("race \(race)", false, "not in Swift"); continue }
    let pairs: [(String, Double)] = [("homeBirthMinutes", r.homeBirthMinutes), ("homeCap", Double(r.homeCap)), ("stage2", Double(r.stage2)),
                                     ("stage3", Double(r.stage3)), ("raidEveryMinutes", r.raidEveryMinutes), ("cellCap", Double(r.cellCap)),
                                     ("cellMin", Double(r.cellMin)), ("nestBirthMinutes", r.nestBirthMinutes), ("townCap", Double(r.townCap)),
                                     ("townBirthMinutes", r.townBirthMinutes)]
    for (key, value) in pairs { expect("\(race).\(key)", number(j[key]) == value, "\(j[key] ?? "nil") vs \(value)") }
    expect("\(race).ages", (j["ages"] as? Bool) == r.ages)
    let breeds = j["breeds"] as? [[String: Any]] ?? []
    expect("\(race).breeds count", breeds.count == r.breeds.count)
    for (b, s) in zip(breeds, r.breeds) {
        expect("\(race).\(s.id)", b["id"] as? String == s.id && number(b["weight"]) == s.weight && number(b["lifespan"]) == s.lifespan,
               "\(b) vs \(s)")
    }
}

// the worked examples
let seed = Int(number(root["seed"]) ?? 0)
let start = number(root["startedAt"]) ?? 0
let hour = 3_600_000.0
for raceCase in root["races"] as? [[String: Any]] ?? [] {
    let race = raceCase["race"] as? String ?? ""
    var home = Population.startHome(race: race, campSeed: seed, startedAt: start)
    var first = home.population.residents
    for slot in 1...5 {
        first.append(Population.residentFor(home.place, campSeed: seed, slot: slot, id: slot + 2, bornAt: start + Double(slot) * home.place.birthMinutes * 60_000))
    }
    for (i, want) in (raceCase["firstResidents"] as? [Any] ?? []).enumerated() where i < first.count {
        residentMatches("\(race) resident \(i)", want, first[i])
    }
    for cp in raceCase["checkpoints"] as? [[String: Any]] ?? [] {
        let hours = number(cp["hours"]) ?? 0
        let step = Population.advance(home.place, &home.population, campSeed: seed, to: start + hours * hour)
        let tag = "\(race) at \(Int(hours))h"
        expect("\(tag) born", number(cp["born"]) == Double(step.born.count), "\(cp["born"] ?? "nil") vs \(step.born.count)")
        expect("\(tag) died", number(cp["died"]) == Double(step.died.count), "\(cp["died"] ?? "nil") vs \(step.died.count)")
        expect("\(tag) alive", number(cp["alive"]) == Double(home.population.alive.count), "\(cp["alive"] ?? "nil") vs \(home.population.alive.count)")
        expect("\(tag) peak", number(cp["peak"]) == Double(home.population.peak))
        expect("\(tag) nextId", number(cp["nextId"]) == Double(home.population.nextId))
        expect("\(tag) nextSlot", number(cp["nextSlot"]) == Double(home.population.nextSlot), "\(cp["nextSlot"] ?? "nil") vs \(home.population.nextSlot)")
        if let last = step.born.last { residentMatches("\(tag) lastBorn", cp["lastBorn"], last) } else { expect("\(tag) lastBorn", cp["lastBorn"] is NSNull) }
    }
    if let battle = raceCase["battle"] as? [String: Any] {
        var b = Population.startHome(race: race, campSeed: seed, startedAt: start)
        Population.advance(b.place, &b.population, campSeed: seed, to: start + 6 * hour)
        let fallen = Population.fall(&b.population, ids: [3, 4, 5], at: start + 6 * hour).map { Double($0.id) }
        let after = Population.advance(b.place, &b.population, campSeed: seed, to: start + 7 * hour)
        expect("\(race) battle fallen", (battle["fallen"] as? [Any] ?? []).compactMap(number) == fallen)
        expect("\(race) battle bornAfter", number(battle["bornAfter"]) == Double(after.born.count))
        expect("\(race) battle alive", number(battle["alive"]) == Double(b.population.alive.count))
        expect("\(race) battle nextSlot", number(battle["nextSlot"]) == Double(b.population.nextSlot))
    }
    if let calm = raceCase["sanctuary"] as? [String: Any] {
        var c = Population.startHome(race: race, campSeed: seed, startedAt: start)
        let place = CampPlace(race: c.place.race, key: c.place.key, startedAt: c.place.startedAt, birthMinutes: c.place.birthMinutes, cap: c.place.cap, sanctuary: true)
        Population.advance(place, &c.population, campSeed: seed, to: start + 30 * hour)
        expect("\(race) sanctuary alive", number(calm["alive"]) == Double(c.population.alive.count))
        expect("\(race) sanctuary nextId", number(calm["nextId"]) == Double(c.population.nextId))
        expect("\(race) sanctuary nextSlot", number(calm["nextSlot"]) == Double(c.population.nextSlot))
    }
    let r = Races.rules(race)
    let nest = CampPlace(race: race, key: "cell:38344:1015372", startedAt: start, birthMinutes: r.nestBirthMinutes, cap: r.cellCap)
    for (i, want) in (raceCase["nestResidents"] as? [Any] ?? []).enumerated() {
        residentMatches("\(race) nest resident \(i)", want, Population.residentFor(nest, campSeed: seed, slot: i, id: 100 + i, bornAt: start + Double(i) * nest.birthMinutes * 60_000))
    }
}

if problems.isEmpty {
    print("camp rules: all \(checks) checks match the server's (\(path))")
} else {
    problems.prefix(40).forEach { print($0) }
    print("camp rules: \(problems.count) of \(checks) checks differ")
    exit(1)
}
