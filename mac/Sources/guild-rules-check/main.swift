// Works out shared/src/guild-hall-fixtures.json again with the Swift rules and reports every difference.
//   swift run guild-rules-check [path to guild-hall-fixtures.json]
// Exit status 0 when everything matches (the Mac and the phones see the same hall), 1 otherwise.
import Foundation
import GuildRules

let path = CommandLine.arguments.dropFirst().first ?? "../shared/src/guild-hall-fixtures.json"
guard let data = FileManager.default.contents(atPath: path),
      let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
    print("cannot read \(path)")
    exit(1)
}

var problems: [String] = []
var checks = 0
/// Numbers within the tolerance but not to the last bit (worth knowing, not a failure).
var inexact = 0
func expect(_ what: String, _ ok: Bool, _ detail: @autoclosure () -> String = "") {
    checks += 1
    if !ok { problems.append("✗ \(what) \(detail())") }
}
/// (JSONSerialization keeps some long decimals as NSDecimalNumber, whose doubleValue can be a bit off: read those from their
/// digits, so a number compares to the last bit.)
func number(_ any: Any?) -> Double? {
    if let d = any as? NSDecimalNumber { return Double(d.stringValue) }
    return (any as? NSNumber)?.doubleValue
}
func same(_ what: String, _ want: Any?, _ got: Double) {
    guard let w = number(want) else { return expect(what, false, "missing (got \(got))") }
    if w != got { inexact += 1 }
    expect(what, abs(w - got) <= 1e-9, "\(w) vs \(got)")
}
func point(_ any: Any?) -> HallPoint {
    let j = any as? [String: Any] ?? [:]
    return HallPoint(x: number(j["x"]) ?? .nan, y: number(j["y"]) ?? .nan)
}
func samePoint(_ what: String, _ want: Any?, _ got: HallPoint) {
    let j = want as? [String: Any] ?? [:]
    same("\(what).x", j["x"], got.x)
    same("\(what).y", j["y"], got.y)
}
func samePoints(_ what: String, _ want: Any?, _ got: [HallPoint]) {
    let list = want as? [Any] ?? []
    expect("\(what) count", list.count == got.count, "\(list.count) vs \(got.count)")
    for (i, (w, g)) in zip(list, got).enumerated() { samePoint("\(what)[\(i)]", w, g) }
}
func layoutOf(_ any: Any?) -> HallLayout { hallLayout(level: Int(number((any as? [String: Any])?["level"]) ?? 1)) }

// the constants and the level table
let rules = root["rules"] as? [String: Any] ?? [:]
same("wallRows", rules["wallRows"], guildWallRows)
same("walkSpeed", rules["walkSpeed"], guildWalkSpeed)
same("activitySeconds", rules["activitySeconds"], guildActivitySeconds)
let levels = rules["levels"] as? [[String: Any]] ?? []
expect("levels count", levels.count == guildLevels.count, "\(levels.count) vs \(guildLevels.count)")
for (j, l) in zip(levels, guildLevels) {
    let pairs: [(String, Int)] = [("level", l.level), ("members", l.members), ("width", l.width), ("height", l.height), ("room", l.room)]
    for (key, value) in pairs { expect("level \(l.level).\(key)", number(j[key]) == Double(value), "\(j[key] ?? "nil") vs \(value)") }
}

// hallHash
for item in root["hashes"] as? [[String: Any]] ?? [] {
    let parts = item["parts"] as? [String] ?? []
    let got = hallHash(parts)
    expect("hallHash(\(parts))", number(item["hash"]) == got, "\(item["hash"] ?? "nil") vs \(got)")
}

// hallLayout
for j in root["layouts"] as? [[String: Any]] ?? [] {
    let level = Int(number(j["level"]) ?? 0)
    let l = hallLayout(level: level)
    let tag = "layout \(level)"
    same("\(tag).width", j["width"], Double(l.width))
    same("\(tag).height", j["height"], Double(l.height))
    let pieces = j["pieces"] as? [[String: Any]] ?? []
    expect("\(tag).pieces count", pieces.count == l.pieces.count, "\(pieces.count) vs \(l.pieces.count)")
    for (i, (w, g)) in zip(pieces, l.pieces).enumerated() {
        expect("\(tag).pieces[\(i)].id", w["id"] as? String == g.id, "\(w["id"] ?? "nil") vs \(g.id)")
        samePoint("\(tag).pieces[\(i)]", w, HallPoint(x: g.x, y: g.y))
    }
    samePoints("\(tag).seats", j["seats"], l.seats)
    samePoint("\(tag).drink", j["drink"], l.drink)
    samePoints("\(tag).bench", j["bench"], l.bench)
    let aisles = j["aisles"] as? [Any] ?? []
    expect("\(tag).aisles count", aisles.count == l.aisles.count, "\(aisles.count) vs \(l.aisles.count)")
    for (i, (w, g)) in zip(aisles, l.aisles).enumerated() { same("\(tag).aisles[\(i)]", w, g) }
}

// hallPose
for scene in root["poses"] as? [[String: Any]] ?? [] {
    let layout = layoutOf(scene)
    let members = (scene["members"] as? [[String: Any]] ?? []).map {
        HallMember(id: $0["id"] as? String ?? "", presence: $0["presence"] as? String ?? "", seat: Int(number($0["seat"]) ?? 0))
    }
    let presentIds = scene["present"] as? [String] ?? []
    let present = members.filter { presentIds.contains($0.id) }
    for moment in scene["times"] as? [[String: Any]] ?? [] {
        let now = number(moment["now"]) ?? 0
        for (want, m) in zip(moment["poses"] as? [Any] ?? [], members) {
            let tag = "pose of \(m.id) (hall \(layout.width)×\(layout.height)) at \(now)"
            let got = hallPose(layout, m, present: present, now: now)
            guard let w = want as? [String: Any] else {
                expect(tag, got == nil, "nil vs \(String(describing: got))")
                continue
            }
            guard let got else { expect(tag, false, "\(w) vs nil"); continue }
            same("\(tag).x", w["x"], got.x)
            same("\(tag).y", w["y"], got.y)
            same("\(tag).t", w["t"], got.t)
            expect("\(tag).anim", w["anim"] as? String == got.anim, "\(w["anim"] ?? "nil") vs \(got.anim)")
            expect("\(tag).dir", w["dir"] as? String == got.dir, "\(w["dir"] ?? "nil") vs \(got.dir)")
            expect("\(tag).flip", w["flip"] as? Bool == got.flip, "\(w["flip"] ?? "nil") vs \(got.flip)")
        }
    }
}

// walking: the wanderers' paths, and by hand
for group in root["paths"] as? [[String: Any]] ?? [] {
    let layout = layoutOf(group)
    for c in group["cases"] as? [[String: Any]] ?? [] {
        let (a, b) = (point(c["from"]), point(c["to"]))
        samePoints("hallPath(\(a) → \(b))", c["path"], hallPath(layout, from: a, to: b))
    }
}
for group in root["walkable"] as? [[String: Any]] ?? [] {
    let layout = layoutOf(group)
    for c in group["cases"] as? [[String: Any]] ?? [] {
        let p = point(c)
        let got = hallWalkable(layout, p)
        expect("hallWalkable(\(p))", c["ok"] as? Bool == got, "\(c["ok"] ?? "nil") vs \(got)")
    }
}
for group in root["steps"] as? [[String: Any]] ?? [] {
    let layout = layoutOf(group)
    for c in group["cases"] as? [[String: Any]] ?? [] {
        let p = point(c["from"]), dx = number(c["dx"]) ?? 0, dy = number(c["dy"]) ?? 0
        samePoint("hallStep(\(p), \(dx), \(dy))", c["to"], hallStep(layout, p, dx: dx, dy: dy))
    }
}
for group in root["interacts"] as? [[String: Any]] ?? [] {
    let layout = layoutOf(group)
    let extraSeats = (group["extraSeats"] as? [Any] ?? []).map { point($0) }
    for c in group["cases"] as? [[String: Any]] ?? [] {
        let p = point(c["p"])
        for (key, got) in [("plain", hallInteract(layout, p, extraSeats: [])), ("extra", hallInteract(layout, p, extraSeats: extraSeats))] {
            let w = c[key] as? [String: Any] ?? [:]
            expect("hallInteract(\(p)) \(key).anim", w["anim"] as? String == got.anim, "\(w["anim"] ?? "nil") vs \(got.anim)")
            samePoint("hallInteract(\(p)) \(key).at", w["at"], got.at)
        }
    }
}

let bits = inexact == 0 ? "all to the last bit" : "\(inexact) numbers within 1e-9 but not to the last bit"
if problems.isEmpty {
    print("guild hall rules: all \(checks) checks match the phones' (\(bits); \(path))")
} else {
    problems.prefix(40).forEach { print($0) }
    print("guild hall rules: \(problems.count) of \(checks) checks differ (\(bits))")
    exit(1)
}
