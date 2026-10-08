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
func sameRects(_ what: String, _ want: Any?, _ got: [HallRect]) {
    let list = want as? [[String: Any]] ?? []
    expect("\(what) count", list.count == got.count, "\(list.count) vs \(got.count)")
    for (i, (w, g)) in zip(list, got).enumerated() {
        for (key, value) in [("x0", g.x0), ("y0", g.y0), ("x1", g.x1), ("y1", g.y1)] { same("\(what)[\(i)].\(key)", w[key], value) }
    }
}
func sameFurnishing(_ what: String, _ want: [String: Any], _ got: HallFurnishing) {
    samePoints("\(what).desks", want["desks"], got.desks)
    samePoints("\(what).seats", want["seats"], got.seats)
    samePoints("\(what).drinks", want["drinks"], got.drinks)
    sameRects("\(what).solids", want["solids"], got.solids)
}
/// The pieces as the fixtures write them ({x, y, flip, spec}).
func pieces(_ any: Any?) -> [HallPlacedPiece] {
    (any as? [[String: Any]] ?? []).map { j in
        let s = j["spec"] as? [String: Any] ?? [:]
        let flag = { (key: String) in s[key] as? Bool ?? false }
        let spec = HallPieceSpec(
            w: number(s["w"]) ?? .nan, h: number(s["h"]) ?? .nan, flat: flag("flat"), wall: flag("wall"), ceiling: flag("ceiling"),
            living: flag("living"), seat: s["seat"] is [String: Any] ? point(s["seat"]) : nil, desk: flag("desk"), drink: flag("drink"))
        return HallPlacedPiece(x: number(j["x"]) ?? .nan, y: number(j["y"]) ?? .nan, flip: j["flip"] as? Bool ?? false, spec: spec)
    }
}

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

// the halls: each one's furnishing worked out from its pieces
var layouts: [HallLayout] = []
for (i, j) in (root["halls"] as? [[String: Any]] ?? []).enumerated() {
    let level = Int(number(j["level"]) ?? 0)
    let l = hallLayout(level: level, furnishing: hallFurnishing(pieces(j["pieces"])))
    layouts.append(l)
    let tag = "hall \(i) (\(j["name"] ?? "?"))"
    let want = j["layout"] as? [String: Any] ?? [:]
    same("\(tag).width", want["width"], Double(l.width))
    same("\(tag).height", want["height"], Double(l.height))
    sameFurnishing(tag, want, HallFurnishing(desks: l.desks, seats: l.seats, drinks: l.drinks, solids: l.solids))
}
func layoutOf(_ group: [String: Any]) -> HallLayout {
    let i = Int(number(group["hall"]) ?? -1)
    return layouts.indices.contains(i) ? layouts[i] : hallLayout(level: 1)
}
for (i, j) in (root["furnishings"] as? [[String: Any]] ?? []).enumerated() {
    sameFurnishing("furnishing \(i)", j["furnishing"] as? [String: Any] ?? [:], hallFurnishing(pieces(j["pieces"])))
}

// hallPose, worked out anew each time and with the ways kept between frames
for scene in root["poses"] as? [[String: Any]] ?? [] {
    let layout = layoutOf(scene)
    let members = (scene["members"] as? [[String: Any]] ?? []).map {
        HallMember(id: $0["id"] as? String ?? "", presence: $0["presence"] as? String ?? "", seat: Int(number($0["seat"]) ?? 0))
    }
    let presentIds = scene["present"] as? [String] ?? []
    let present = members.filter { presentIds.contains($0.id) }
    let ways = HallWays()
    for moment in scene["times"] as? [[String: Any]] ?? [] {
        let now = number(moment["now"]) ?? 0
        for (want, m) in zip(moment["poses"] as? [Any] ?? [], members) {
            for (how, got) in [("fresh", hallPose(layout, m, present: present, now: now)), ("kept", hallPose(layout, m, present: present, now: now, ways: ways))] {
                let tag = "pose of \(m.id) (hall \(scene["hall"] ?? "?"), \(how)) at \(now)"
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
}

// the ways round things, and walking by hand
for group in root["routes"] as? [[String: Any]] ?? [] {
    let layout = layoutOf(group)
    for c in group["cases"] as? [[String: Any]] ?? [] {
        let (a, b) = (point(c["from"]), point(c["to"]))
        samePoints("hallRoute(\(a) → \(b))", c["route"], hallRoute(layout, from: a, to: b))
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
    for c in group["cases"] as? [[String: Any]] ?? [] {
        let p = point(c["p"])
        let got = hallInteract(layout, p)
        expect("hallInteract(\(p)).anim", c["anim"] as? String == got.anim, "\(c["anim"] ?? "nil") vs \(got.anim)")
        samePoint("hallInteract(\(p)).at", c["at"], got.at)
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
