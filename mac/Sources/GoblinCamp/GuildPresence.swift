import Foundation

/// Tells the server whether this Mac's player is at their computer (GUILD.md §3), for the guild hall: focusing (a pomodoro's
/// focus part, or 專注模式), there, away (no key or mouse for a while), or gone (the app quit). Said when it changes and every
/// `heartbeat` seconds (shared/src/guild.ts PRESENCE_HEARTBEAT_SECONDS), so a Mac that went quiet counts as offline there.
final class GuildPresence {
    enum State: String { case focus, online, away, offline }

    /// Every this many seconds, say it even if it did not change.
    static let heartbeat: TimeInterval = 120

    private let api: APIClient
    /// Whether an account is signed in (nothing is said otherwise).
    var signedIn: () -> Bool = { false }
    /// How it is now.
    var current: () -> State = { .online }
    private var timer: Timer?
    private var said: State?
    private var saidAt = Date.distantPast

    init(api: APIClient) {
        self.api = api
    }

    func start() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in self?.check() }
        check()
    }

    /// Looks again now (the pomodoro or the mode just changed).
    func check() {
        guard signedIn() else {
            said = nil
            return
        }
        let now = current()
        guard now != said || Date().timeIntervalSince(saidAt) >= GuildPresence.heartbeat else { return }
        said = now
        saidAt = Date()
        struct Body: Encodable { let state: String }
        Task { try? await self.api.raw("PUT", "guild/presence", body: Body(state: now.rawValue)) }
    }

    /// The app is quitting: say "offline", waiting a moment at most (it must not hold the quit up).
    func quit() {
        timer?.invalidate()
        guard signedIn(), said != nil, said != .offline else { return }
        let done = DispatchSemaphore(value: 0)
        struct Body: Encodable { let state: String }
        Task.detached { [api] in
            _ = try? await api.raw("PUT", "guild/presence", body: Body(state: State.offline.rawValue))
            done.signal()
        }
        _ = done.wait(timeout: .now() + 1.5)
    }
}
