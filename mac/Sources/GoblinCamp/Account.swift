import AppKit
import Security

/// The signed-in person as the server told us (nothing secret: the token is in the Keychain).
struct AccountUser: Codable, Equatable {
    let id: String
    let email: String
    let displayName: String
    let friendCode: String
}

/// What the server says when something went wrong: a code for the app and a sentence for the player (DESIGN.md, shared/src/auth.ts).
struct APIError: Error, LocalizedError {
    let status: Int
    let code: String
    let message: String
    var errorDescription: String? { message }
    /// No answer at all (no network, server down).
    static func offline(_ error: Error) -> APIError { APIError(status: 0, code: "offline", message: "連不上伺服器，請確認網路（或稍後再試）。") }
    var isOffline: Bool { status == 0 }
    /// The session is gone (signed out elsewhere, expired, password reset).
    var isUnauthorized: Bool { status == 401 }
}

/// Where the account lives on this Mac: the token in the Keychain, the rest in account.json beside notes.json.
/// A test run with its own `CAMP_DATA_DIR` keeps the token in that folder instead, so it never touches the real Keychain.
final class AccountStore {
    private struct File: Codable {
        var deviceID = UUID().uuidString.lowercased()
        /// The big-world window's own id (a browser of its own to the server: its own session). Made the first time it opens.
        var webDeviceID: String?
        var user: AccountUser?
        /// Tests only (see above).
        var testToken: String?
    }

    private var file = File()
    private let url: URL
    private let testMode: Bool
    private static let keychainService = "dev.goblincamp.game.account"

    /// Where the server is: `CAMP_SERVER_URL` (tests), else `GoblinServerURL` in Info.plist (set for the builds colleagues get),
    /// else `http://localhost:8787` (development).
    let serverURL: URL

    init() {
        let env = ProcessInfo.processInfo.environment
        testMode = env["CAMP_DATA_DIR"] != nil
        let base = env["CAMP_DATA_DIR"].map { URL(fileURLWithPath: $0) }
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("GoblinCamp")
        url = base.appendingPathComponent("account.json")
        let planned = Bundle.main.object(forInfoDictionaryKey: "GoblinServerURL") as? String
        serverURL = URL(string: env["CAMP_SERVER_URL"] ?? (planned?.isEmpty == false ? planned! : "http://localhost:8787")) ?? URL(string: "http://localhost:8787")!
        if let data = try? Data(contentsOf: url), let saved = try? JSONDecoder().decode(File.self, from: data) { file = saved } else { save() }
    }

    /// This Mac's own id, made once and kept (the server knows the Mac by it).
    var deviceID: String { file.deviceID }
    var webDeviceID: String {
        if let id = file.webDeviceID { return id }
        let id = UUID().uuidString.lowercased()
        file.webDeviceID = id
        save()
        return id
    }
    var deviceName: String { Host.current().localizedName ?? "Mac" }
    var user: AccountUser? { file.user }

    var token: String? {
        if testMode { return file.testToken }
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: AccountStore.keychainService,
                                    kSecReturnData as String: true, kSecMatchLimit as String: kSecMatchLimitOne]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    func signedIn(user: AccountUser, token: String) {
        file.user = user
        if testMode { file.testToken = token } else { writeKeychain(token) }
        save()
    }

    /// The session ended on the server: the token goes, the person stays (so the app can say "sign in again" with the address filled in).
    func sessionEnded() {
        if testMode { file.testToken = nil } else {
            SecItemDelete([kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: AccountStore.keychainService] as CFDictionary)
        }
        save()
    }

    func signedOut() {
        file.user = nil
        if testMode { file.testToken = nil } else {
            SecItemDelete([kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: AccountStore.keychainService] as CFDictionary)
        }
        save()
    }

    private func writeKeychain(_ token: String) {
        let match: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: AccountStore.keychainService]
        SecItemDelete(match as CFDictionary)
        var add = match
        add[kSecAttrAccount as String] = "session"
        add[kSecValueData as String] = Data(token.utf8)
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(add as CFDictionary, nil)
        if status != errSecSuccess { NSLog("GoblinCamp: could not save the session in the Keychain (\(status))") }
    }

    private func save() {
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(file).write(to: url, options: .atomic)
        } catch {
            NSLog("GoblinCamp: saving account.json failed: \(error)")
        }
    }
}

/// Talks to the server (server/README.md has the list). Everything is async and throws `APIError`.
final class APIClient {
    private let store: AccountStore
    private let session: URLSession

    init(store: AccountStore) {
        self.store = store
        let config = URLSessionConfiguration.ephemeral // no cookies or caches: the Mac signs in with its Bearer token
        config.timeoutIntervalForRequest = 20
        session = URLSession(configuration: config)
    }

    static let decoder = JSONDecoder()
    static let encoder = JSONEncoder()

    func request<T: Decodable>(_ method: String, _ path: String, body: Encodable? = nil, as: T.Type = T.self, auth: Bool = true) async throws -> T {
        let data = try await raw(method, path, body: body, auth: auth)
        do {
            return try APIClient.decoder.decode(T.self, from: data.isEmpty ? Data("{}".utf8) : data)
        } catch {
            throw APIError(status: 200, code: "bad_response", message: "伺服器的回覆看不懂（\(error.localizedDescription)）。")
        }
    }

    @discardableResult
    func raw(_ method: String, _ path: String, body: Encodable? = nil, auth: Bool = true) async throws -> Data {
        guard let url = URL(string: store.serverURL.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + "/api/" + path) else {
            throw APIError(status: 0, code: "bad_url", message: "伺服器位址不對：\(store.serverURL)")
        }
        var req = URLRequest(url: url)
        req.httpMethod = method
        if let body {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try APIClient.encoder.encode(body)
        }
        if auth, let token = store.token { req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        let data: Data, response: URLResponse
        do {
            (data, response) = try await session.data(for: req)
        } catch {
            throw APIError.offline(error)
        }
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            struct Body: Decodable { let error: String?; let message: String? }
            let parsed = try? APIClient.decoder.decode(Body.self, from: data)
            throw APIError(status: status, code: parsed?.error ?? "http_\(status)", message: parsed?.message ?? "伺服器回了錯誤（\(status)）。")
        }
        return data
    }

    // MARK: Accounts (/api/auth)

    struct Device: Encodable { let id: String; let kind = "mac"; let name: String }
    struct LoginResult: Decodable { let user: AccountUser; let token: String? }
    struct Message: Decodable { let message: String? }
    struct SessionInfo: Decodable, Identifiable {
        struct Dev: Decodable { let id: String; let kind: String; let name: String }
        let id: String
        let device: Dev?
        let lastSeenAt: String
        let current: Bool
    }

    func login(email: String, password: String) async throws -> LoginResult {
        struct Body: Encodable { let email, password: String; let device: Device }
        return try await request("POST", "auth/login", body: Body(email: email, password: password, device: Device(id: store.deviceID, name: store.deviceName)), auth: false)
    }

    func register(email: String, password: String, displayName: String, inviteCode: String) async throws -> String {
        struct Body: Encodable { let email, password, displayName, inviteCode: String }
        let m: Message = try await request("POST", "auth/register", body: Body(email: email, password: password, displayName: displayName, inviteCode: inviteCode), auth: false)
        return m.message ?? "確認信寄出了。"
    }

    func resendVerification(email: String) async throws {
        struct Body: Encodable { let email: String }
        try await raw("POST", "auth/resend-verification", body: Body(email: email), auth: false)
    }

    func forgotPassword(email: String) async throws {
        struct Body: Encodable { let email: String }
        try await raw("POST", "auth/forgot-password", body: Body(email: email), auth: false)
    }

    func logout() async throws { try await raw("POST", "auth/logout") }

    var serverHost: String? { store.serverURL.host }

    /// A one-time link that opens the web page at `to` signed in as this account, for the big-world window.
    func handoff(to: String) async throws -> URL {
        struct Body: Encodable { let webDevice, to: String }
        struct Answer: Decodable { let url: String }
        let answer: Answer = try await request("POST", "auth/handoff", body: Body(webDevice: store.webDeviceID, to: to))
        guard let url = URL(string: answer.url) else { throw APIError(status: 200, code: "bad_response", message: "伺服器給的網址看不懂。") }
        return url
    }

    func sessions() async throws -> [SessionInfo] {
        struct Body: Decodable { let sessions: [SessionInfo] }
        return try await request("GET", "auth/sessions", as: Body.self).sessions
    }

    func endSession(_ id: String) async throws { try await raw("DELETE", "auth/sessions/\(id)") }

    /// The WebSocket for "something changed" (`/api/ws`), signed in with the Bearer token.
    func webSocket() -> URLSessionWebSocketTask? {
        guard let token = store.token, var parts = URLComponents(url: store.serverURL, resolvingAgainstBaseURL: false) else { return nil }
        parts.scheme = parts.scheme == "https" ? "wss" : "ws"
        parts.path = "/api/ws"
        guard let url = parts.url else { return nil }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return session.webSocketTask(with: req)
    }
}
