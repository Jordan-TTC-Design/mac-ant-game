import AppKit

// The scribe (DESKTOP.md §4): while Claude Code is at work, a goblin sits at a desk in front of the camp and types (an elf writes with a
// quill, a skeleton hammers a typewriter); each tool Claude uses sends a runner off with a scroll; when Claude stops, the scribe
// stretches and goes. One desk per session, up to four.
//
// Claude Code's hooks only drop small files (HookInstaller's "pulse"): `<session>` (its folder) when a prompt starts, `<session>.tool`
// touched at each tool, `<session>.done` when it stops. The game looks at them once a second.

final class ClaudeDesk {
    struct Session {
        let id: String
        var project: String
        /// When it started working (this turn), and when it last used a tool.
        var since: Date
        var lastTool: Date?
        /// The goblin at its desk, the desk, and when its last runner went.
        var scribe: Int?
        var desk: CGPoint = .zero
        var lastRunner = Date.distantPast
    }

    static let maxDesks = 4
    /// A turn longer than this and the scribe nods off.
    static let dozeAfter: TimeInterval = 20 * 60
    /// A session that has said nothing for this long is taken as gone (Claude Code closed without a Stop).
    static let staleAfter: TimeInterval = 30 * 60

    private(set) var sessions: [String: Session] = [:]
    private var timer = 0.0

    static var folder: URL { Persistence.url("claude") }

    init() {
        try? FileManager.default.createDirectory(at: ClaudeDesk.folder, withIntermediateDirectories: true) // (the hook writes only if it is there)
    }

    private func modified(_ url: URL) -> Date? {
        (try? FileManager.default.attributesOfItem(atPath: url.path))?[.modificationDate] as? Date
    }

    /// Looks at the folder (once a second); returns the sessions that just finished.
    func poll(dt: Double) -> [Session] {
        timer -= dt
        guard timer <= 0 else { return [] }
        timer = 1
        let fm = FileManager.default
        let folder = ClaudeDesk.folder
        let names = (try? fm.contentsOfDirectory(atPath: folder.path)) ?? []
        let now = Date()
        var finished: [Session] = []
        var seen = Set<String>()
        for name in names where !name.contains(".") {
            let main = folder.appendingPathComponent(name)
            guard let started = modified(main) else { continue }
            let done = modified(folder.appendingPathComponent(name + ".done"))
            let tool = modified(folder.appendingPathComponent(name + ".tool"))
            let last = max(started, tool ?? started)
            if let done, done >= last || now.timeIntervalSince(last) > ClaudeDesk.staleAfter { // stopped (or long silent): clear its files
                if let session = sessions.removeValue(forKey: name), done >= last { finished.append(session) }
                for suffix in ["", ".tool", ".done"] { try? fm.removeItem(at: folder.appendingPathComponent(name + suffix)) }
                continue
            }
            if done == nil, now.timeIntervalSince(last) > ClaudeDesk.staleAfter {
                sessions.removeValue(forKey: name)
                for suffix in ["", ".tool"] { try? fm.removeItem(at: folder.appendingPathComponent(name + suffix)) }
                continue
            }
            seen.insert(name)
            let project = ((try? String(contentsOf: main, encoding: .utf8)) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                .split(separator: "/").last.map(String.init) ?? ""
            if sessions[name] == nil {
                guard sessions.count < ClaudeDesk.maxDesks else { continue }
                sessions[name] = Session(id: name, project: project, since: started)
            }
            sessions[name]?.project = project
            if let tool, tool > (sessions[name]?.lastTool ?? .distantPast) { sessions[name]?.lastTool = tool }
        }
        for gone in Set(sessions.keys).subtracting(seen) { sessions.removeValue(forKey: gone) } // (its files were removed by hand)
        return finished
    }

    func set(_ id: String, scribe: Int?, desk: CGPoint) {
        sessions[id]?.scribe = scribe
        sessions[id]?.desk = desk
    }

    func ranRunner(_ id: String) { sessions[id]?.lastRunner = Date() }
}

extension Colony {
    /// Once a frame (from `updateHoliday`'s neighbour in the tick): desks, scribes and runners follow Claude Code's sessions.
    func updateScribes(dt: Double) {
        let finished = claudeDesk.poll(dt: dt)
        for session in finished { // Claude stopped: the scribe stretches and is done
            guard let id = session.scribe, let i = ants.firstIndex(where: { $0.id == id }) else { continue }
            if case .activity(.scribe, _) = ants[i].mode { ants[i].mode = .wandering }
            ants[i].touch = Touch.react(.hop, 2.5, line: ["寫完了！", "做完囉～", "（伸懶腰）"].randomElement())
        }
        guard let nest else { return }
        let sessions = claudeDesk.sessions.values.sorted { $0.since < $1.since }
        for (k, session) in sessions.enumerated() {
            // its desk: a little row in front of the camp
            let desk = nearestWalkable(to: CGPoint(x: nest.x + 62 + CGFloat(k % 2) * 58, y: nest.y - 34 - CGFloat(k / 2) * 34))
            var scribe = session.scribe.flatMap { id in ants.firstIndex { $0.id == id } }
            if let i = scribe {
                if case .activity(.scribe, _) = ants[i].mode {} else if ants[i].touch == nil { scribe = nil } // (it left the desk: somebody else sits down)
            }
            if scribe == nil { // somebody comes to the desk: the clever ones first
                let free = ants.indices.filter { i in
                    guard case .wandering = ants[i].mode, ants[i].touch == nil, !ants[i].isChild, !ants[i].isHidden, !ants[i].isWounded else { return false }
                    return true
                }
                scribe = free.min { a, b in
                    func cost(_ i: Int) -> CGFloat {
                        hypot(ants[i].pos.x - desk.x, ants[i].pos.y - desk.y) - (ants[i].traits.personality == .calm ? 200 : 0)
                    }
                    return cost(a) < cost(b)
                }
                if let i = scribe {
                    ants[i].activityClock = 0
                    ants[i].mode = .activity(.scribe(desk: desk, dozing: false), remaining: 1_000_000)
                }
            }
            claudeDesk.set(session.id, scribe: scribe.map { ants[$0].id }, desk: desk)
            if let i = scribe, case .activity(.scribe(_, let dozing), let left) = ants[i].mode {
                let sleepy = Date().timeIntervalSince(session.since) > ClaudeDesk.dozeAfter
                if sleepy != dozing { ants[i].mode = .activity(.scribe(desk: desk, dozing: sleepy), remaining: left) }
            }
            // a tool: a runner takes a scroll from the desk into the camp (one at a time per desk)
            if let tool = session.lastTool, tool > session.lastRunner, Date().timeIntervalSince(session.lastRunner) > 6 {
                let near = ants.indices.filter { i in
                    guard case .wandering = ants[i].mode, ants[i].touch == nil, !ants[i].isChild, !ants[i].isHidden else { return false }
                    return hypot(ants[i].pos.x - desk.x, ants[i].pos.y - desk.y) < 160
                }
                if let i = near.min(by: { hypot(ants[$0].pos.x - desk.x, ants[$0].pos.y - desk.y) < hypot(ants[$1].pos.x - desk.x, ants[$1].pos.y - desk.y) }) {
                    ants[i].activityClock = 0
                    ants[i].mode = .activity(.haul(load: 3, to: nest), remaining: 60)
                    claudeDesk.ranRunner(session.id)
                }
            }
        }
        // scribes whose session is gone (Claude Code closed) get up
        let sitting = Set(claudeDesk.sessions.values.compactMap(\.scribe))
        for i in ants.indices {
            if case .activity(.scribe, _) = ants[i].mode, !sitting.contains(ants[i].id) { ants[i].mode = .wandering }
        }
    }
}
