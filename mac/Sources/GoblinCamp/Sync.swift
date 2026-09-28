import AppKit

/// A note as the server sends it (server/src/notes/routes.ts `toNote`).
struct ServerNote: Decodable {
    let id: String
    let text: String
    let color: String
    let breed: String
    let goblinName: String
    let dueAt: String?
    let remindAt: String?
    let remindFired: Bool
    let done: Bool
    let deleted: Bool
    /// (a server from before kinds sends neither)
    let kind: String?
    let desk: Bool?
    let createdAt: String
    let updatedAt: String
    let seq: Int

    var sticky: StickyNote {
        StickyNote(id: id, text: text, color: color, breed: breed, goblinName: goblinName, dueAt: dueAt.flatMap(ServerTime.parse),
                   remindAt: remindAt.flatMap(ServerTime.parse), remindFired: remindFired, done: done,
                   createdAt: ServerTime.parse(createdAt) ?? Date(), updatedAt: ServerTime.parse(updatedAt) ?? Date(), deleted: deleted,
                   kind: kind, desk: desk)
    }
}

/// The server's times: ISO 8601 in UTC, with milliseconds.
enum ServerTime {
    private static let withFraction: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private static let plain = ISO8601DateFormatter()
    static func parse(_ s: String) -> Date? { withFraction.date(from: s) ?? plain.date(from: s) }
    static func format(_ d: Date) -> String { withFraction.string(from: d) }
}

/// A JSON value for the fields of a change (a string, true/false or null).
private enum FieldValue: Encodable {
    case string(String), bool(Bool), null
    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .string(let s): try c.encode(s)
        case .bool(let b): try c.encode(b)
        case .null: try c.encodeNil()
        }
    }
}

/// Keeps this Mac's notes and the server's the same: sends what changed here (a second after the change), fetches what changed
/// elsewhere (when the server says so over the WebSocket, when the app starts, and every five minutes), and signs in and out.
/// The rules for two devices changing the same note are the server's (DESIGN.md §5).
final class SyncEngine {
    enum Status: Equatable {
        case signedOut
        case syncing
        case synced(Date)
        /// No connection; changes wait here and go when it is back.
        case offline
        /// The session ended (signed out elsewhere, expired, password changed).
        case needsLogin
        case problem(String)
    }

    let account: AccountStore
    let api: APIClient
    private let notes: NoteController
    private(set) var status: Status = .signedOut { didSet { if status != oldValue { onStatus?() } } }
    var onStatus: (() -> Void)?
    /// Someone just signed in on this Mac (the camp starts from the account's books then).
    var onSignedIn: (() -> Void)?
    /// The server says the camp's books changed (another device, a command, a raid worked out).
    var onCampChanged: (() -> Void)?
    private var running = false
    private var again = false
    private var debounce: Timer?
    private var poll: Timer?
    private var socket: URLSessionWebSocketTask?
    private var pingTimer: Timer?
    private var reconnectDelay = 5.0
    private var debug: Bool { ProcessInfo.processInfo.environment["CAMP_DEBUG"] != nil }

    init(notes: NoteController) {
        self.notes = notes
        account = AccountStore()
        api = APIClient(store: account)
        notes.store.onLocalChange = { [weak self] in self?.syncSoon() }
    }

    var user: AccountUser? { account.token == nil ? nil : account.user }

    func start() {
        if user != nil { beginSession() } else if account.user != nil { status = .needsLogin }
    }

    // MARK: Signing in and out

    /// Returns how many notes of this Mac will go up to the account.
    @MainActor @discardableResult
    func signIn(email: String, password: String) async throws -> Int {
        let result = try await api.login(email: email, password: password)
        guard let token = result.token else { throw APIError(status: 200, code: "no_token", message: "伺服器沒有給登入憑證。") }
        account.signedIn(user: result.user, token: token)
        let before = notes.store.live.count
        beginSession()
        onSignedIn?()
        return before
    }

    /// `keep`: this Mac's notes stay (as its own, no longer tied to the account); otherwise they are removed from this Mac (the account keeps them).
    @MainActor
    func signOut(keep: Bool) async {
        try? await api.logout()
        endSession()
        account.signedOut()
        notes.endSync(keep: keep)
        status = .signedOut
    }

    private func beginSession() {
        guard let user else { return }
        notes.store.beginSync(for: user.id)
        syncNow()
        connectSocket()
        poll?.invalidate()
        poll = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            self?.syncNow()
            if self?.socket == nil { self?.connectSocket() }
        }
    }

    private func endSession() {
        poll?.invalidate()
        poll = nil
        debounce?.invalidate()
        pingTimer?.invalidate()
        socket?.cancel(with: .normalClosure, reason: nil)
        socket = nil
    }

    /// The server no longer knows this session: sign out here too, but keep the notes and where they stand, so signing in again carries on.
    private func sessionEnded() {
        endSession()
        account.sessionEnded()
        status = .needsLogin
        if debug { NSLog("GoblinCamp: sync: the session ended") }
    }

    // MARK: Syncing

    /// A note changed here: send it in a second (several quick changes go together).
    func syncSoon() {
        guard user != nil else { return }
        debounce?.invalidate()
        debounce = Timer.scheduledTimer(withTimeInterval: 1, repeats: false) { [weak self] _ in self?.syncNow() }
    }

    func syncNow() {
        guard user != nil else { return }
        if running { again = true; return }
        running = true
        status = .syncing
        Task { @MainActor in
            await self.run()
            self.running = false
            if self.again {
                self.again = false
                self.syncNow()
            }
        }
    }

    @MainActor
    private func run() async {
        do {
            try await pushAll()
            try await pullAll()
            status = .synced(Date())
            reconnectDelay = 5
        } catch let error as APIError {
            if error.isUnauthorized { sessionEnded() } else if error.isOffline { status = .offline } else { status = .problem(error.message) }
            if debug { NSLog("GoblinCamp: sync failed: \(error.code) \(error.message)") }
        } catch {
            status = .problem(error.localizedDescription)
        }
    }

    private struct Change: Encodable {
        let id: String
        let baseSeq: Int
        let fields: [String: FieldValue]
        let createdAt: String?
    }
    private struct PushResult: Decodable {
        let id: String
        let status: String
        let note: ServerNote?
        let copy: ServerNote?
        let reason: String?
    }

    private static func value(of field: String, in note: StickyNote) -> FieldValue {
        switch field {
        case "text": return .string(note.text)
        case "color": return .string(note.color)
        case "breed": return .string(note.breed)
        case "goblinName": return .string(note.goblinName)
        case "dueAt": return note.dueAt.map { .string(ServerTime.format($0)) } ?? .null
        case "remindAt": return note.remindAt.map { .string(ServerTime.format($0)) } ?? .null
        case "remindFired": return .bool(note.remindFired)
        case "done": return .bool(note.done)
        case "kind": return .string(note.kind ?? "todo")
        case "desk": return .bool(note.onDesk)
        default: return .bool(note.deleted)
        }
    }

    @MainActor
    private func pushAll() async throws {
        for _ in 0..<20 { // (a hundred at a time; stops when nothing is waiting)
            let batch = Array(notes.store.pending.prefix(100))
            if batch.isEmpty { return }
            let changes = batch.map { item -> Change in
                // a note the server has never seen goes with every field
                let fields = item.meta.seq == 0 ? Set(StickyNote.syncedFields) : item.meta.dirty
                return Change(id: item.note.id, baseSeq: item.meta.seq, fields: Dictionary(uniqueKeysWithValues: fields.map { ($0, SyncEngine.value(of: $0, in: item.note)) }),
                              createdAt: item.meta.seq == 0 ? ServerTime.format(item.note.createdAt) : nil)
            }
            struct Body: Encodable { let changes: [Change] }
            struct Reply: Decodable { let results: [PushResult] }
            let reply: Reply = try await api.request("POST", "notes/push", body: Body(changes: changes))
            var stuck = false
            for (sent, result) in zip(batch, reply.results) {
                let fields = Set(changes.first { $0.id == sent.note.id }?.fields.keys.map { $0 } ?? [])
                switch result.status {
                case "rejected":
                    switch result.reason {
                    case "id_taken": notes.renew(sent.note.id)
                    case "limit":
                        status = .problem("便利貼超過 500 張，新的沒有同步。")
                        stuck = true
                    default: notes.store.resend(sent.note.id)
                    }
                default:
                    notes.store.sent(sent.note.id, fields: fields, as: sent.note)
                    var back: [(note: StickyNote, seq: Int)] = []
                    if let n = result.note { back.append((n.sticky, n.seq)) }
                    if let c = result.copy { back.append((c.sticky, c.seq)) }
                    notes.applyRemote(back)
                }
                if debug { NSLog("GoblinCamp: sync: pushed \(sent.note.id.prefix(8)) → \(result.status)\(result.reason.map { " (\($0))" } ?? "")") }
            }
            if stuck { return }
        }
    }

    @MainActor
    private func pullAll() async throws {
        struct Page: Decodable { let notes: [ServerNote]; let seq: Int; let more: Bool }
        for _ in 0..<50 {
            let page: Page = try await api.request("GET", "notes/changes?since=\(notes.store.lastSeq)")
            if !page.notes.isEmpty {
                notes.applyRemote(page.notes.map { ($0.sticky, $0.seq) })
                if debug { NSLog("GoblinCamp: sync: pulled \(page.notes.count) note(s) up to \(page.seq)") }
            }
            notes.store.setLastSeq(page.seq)
            if !page.more { return }
        }
    }

    // MARK: The WebSocket

    private func connectSocket() {
        guard socket == nil, user != nil, let task = api.webSocket() else { return }
        socket = task
        task.resume()
        receive(on: task)
        pingTimer?.invalidate()
        pingTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.socket?.sendPing { _ in }
        }
    }

    private func receive(on task: URLSessionWebSocketTask) {
        task.receive { [weak self] result in
            DispatchQueue.main.async {
                guard let self, self.socket === task else { return }
                switch result {
                case .success(let message):
                    if case .string(let text) = message, text.contains("\"notes.changed\"") { self.syncNow() }
                    if case .string(let text) = message, text.contains("\"camp.changed\"") { self.onCampChanged?() }
                    if case .string(let text) = message, text.contains("\"hello\""), self.debug { NSLog("GoblinCamp: sync: connected") }
                    self.receive(on: task)
                case .failure:
                    self.socketClosed()
                }
            }
        }
    }

    /// The connection dropped. If the session is over the server says so on the next call; otherwise connect again, waiting longer each time.
    private func socketClosed() {
        socket = nil
        pingTimer?.invalidate()
        guard user != nil else { return }
        Task { @MainActor in
            do {
                try await self.api.raw("GET", "auth/me")
            } catch let error as APIError where error.isUnauthorized {
                self.sessionEnded()
                return
            } catch {}
            let wait = self.reconnectDelay
            self.reconnectDelay = min(self.reconnectDelay * 2, 120)
            DispatchQueue.main.asyncAfter(deadline: .now() + wait) { [weak self] in
                guard let self, self.user != nil else { return }
                self.connectSocket()
                self.syncNow()
            }
        }
    }
}
