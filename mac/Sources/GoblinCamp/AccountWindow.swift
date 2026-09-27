import AppKit

/// 登入／註冊：one small window with two tabs. Not signing in is fine: the notes then stay on this Mac only.
final class AccountWindow: NSObject, NSWindowDelegate {
    enum Tab { case login, register }

    let window: NSWindow
    private let sync: SyncEngine
    /// Called after signing in, with a line to tell the player (how many notes went up).
    private let onSignedIn: (String) -> Void
    private var tab: Tab = .login
    /// After registering: waiting for the player to click the link in the mail.
    private var sentTo: String?
    private var busy = false

    private let emailField = NSTextField()
    private let passwordField = PasswordBox()
    private let passwordAgain = PasswordBox()
    private let nameField = NSTextField()
    private let inviteField = NSTextField()
    private let statusLabel = NSTextField(wrappingLabelWithString: "")
    private var statusIsError = false

    private static let width: CGFloat = 440
    private static let ink = NSColor(calibratedWhite: 0.12, alpha: 1)
    private static let grey = NSColor(calibratedWhite: 0.45, alpha: 1)
    private static let green = NSColor(calibratedRed: 0.20, green: 0.60, blue: 0.28, alpha: 1)
    private static let red = NSColor(calibratedRed: 0.78, green: 0.22, blue: 0.20, alpha: 1)

    init(sync: SyncEngine, onSignedIn: @escaping (String) -> Void) {
        self.sync = sync
        self.onSignedIn = onSignedIn
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: AccountWindow.width, height: 400), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        super.init()
        window.title = "哥布林營地帳號"
        window.isReleasedWhenClosed = false
        window.level = Levels.dialog
        window.appearance = NSAppearance(named: .aqua) // always light, like the game's bubbles
        window.backgroundColor = .white
        window.delegate = self
        for field in [emailField, nameField, inviteField] + passwordField.fields + passwordAgain.fields {
            field.font = .systemFont(ofSize: 13)
            field.bezelStyle = .roundedBezel
            field.target = self
            field.action = #selector(submit)
        }
        emailField.placeholderString = "you@example.com"
        passwordField.placeholderString = "至少 10 個字"
        passwordAgain.placeholderString = "和上面一樣"
        nameField.placeholderString = "使者上會顯示這個名字"
        inviteField.placeholderString = "GOBLIN-XXXX-XXXX"
        if let email = sync.account.user?.email { emailField.stringValue = email } // (signing in again after the session ended)
        build()
        window.center()
    }

    func show(_ tab: Tab = .login) {
        self.tab = tab
        sentTo = nil
        setStatus("", error: false)
        build()
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(emailField.stringValue.isEmpty ? emailField : passwordField.field)
    }

    // MARK: Layout (top down, by hand, like the question bubbles)

    private func build() {
        let root = NSView()
        let pad: CGFloat = 24, w = AccountWindow.width
        var y: CGFloat = 0
        var placed: [(NSView, CGFloat, CGFloat, CGFloat, CGFloat)] = [] // view, x, y-from-top, width, height
        func put(_ v: NSView, x: CGFloat = pad, width: CGFloat? = nil, height: CGFloat, gap: CGFloat = 8) {
            placed.append((v, x, y, width ?? w - x - pad, height))
            y += height + gap
        }
        func label(_ s: String, size: CGFloat, weight: NSFont.Weight = .regular, color: NSColor = AccountWindow.ink) -> NSTextField {
            let l = NSTextField(wrappingLabelWithString: s)
            l.font = .systemFont(ofSize: size, weight: weight)
            l.textColor = color
            return l
        }

        y = pad
        // the goblin's face, the name of the thing, and what signing in is for
        let face = PixelImageView(image: Characters.current.icon ?? NSImage())
        face.imageScaling = .scaleProportionallyUpOrDown
        placed.append((face, pad, y, 44, 44))
        placed.append((label("哥布林營地帳號", size: 18, weight: .bold), pad + 56, y + 2, w - pad * 2 - 56, 24))
        placed.append((label("登入後，便利貼會在你的 Mac 和手機之間同步", size: 12, color: AccountWindow.grey), pad + 56, y + 26, w - pad * 2 - 56, 18))
        y += 44 + 18

        if let sentTo {
            put(label("確認信寄到 \(sentTo) 了", size: 15, weight: .semibold), height: 22)
            put(label("點信裡的連結確認信箱，然後回來登入。找不到的話看看垃圾信件匣。", size: 13, color: AccountWindow.grey), height: 36, gap: 14)
            let resend = PillButton(title: "重寄確認信", fill: NSColor(calibratedWhite: 0.9, alpha: 1), textColor: AccountWindow.ink) { [weak self] in self?.resend() }
            let back = PillButton(title: "回到登入", fill: AccountWindow.green, textColor: .white) { [weak self] in
                self?.sentTo = nil
                self?.tab = .login
                self?.build()
            }
            placed.append((resend, pad, y, resend.frame.width, 26))
            placed.append((back, pad + resend.frame.width + 8, y, back.frame.width, 26))
            y += 26 + 12
        } else {
            // the two tabs
            let login = PillButton(title: "登入", fill: tab == .login ? AccountWindow.green : NSColor(calibratedWhite: 0.92, alpha: 1),
                                   textColor: tab == .login ? .white : AccountWindow.ink) { [weak self] in self?.switchTo(.login) }
            let register = PillButton(title: "註冊", fill: tab == .register ? AccountWindow.green : NSColor(calibratedWhite: 0.92, alpha: 1),
                                      textColor: tab == .register ? .white : AccountWindow.ink) { [weak self] in self?.switchTo(.register) }
            let tabsWidth = login.frame.width + register.frame.width + 6
            placed.append((login, (w - tabsWidth) / 2, y, login.frame.width, 26))
            placed.append((register, (w - tabsWidth) / 2 + login.frame.width + 6, y, register.frame.width, 26))
            y += 26 + 16

            func row(_ title: String, _ field: NSView) {
                placed.append((label(title, size: 13, color: AccountWindow.grey), pad, y + 4, 60, 18))
                put(field, x: pad + 64, height: 24, gap: 10)
            }
            row("信箱", emailField)
            row("密碼", passwordField)
            if tab == .register {
                row("再一次", passwordAgain)
                row("暱稱", nameField)
                row("邀請碼", inviteField)
            }
            y += 4
            let action = PillButton(title: tab == .login ? "登入" : "註冊", fill: AccountWindow.green, textColor: .white) { [weak self] in self?.submit() }
            placed.append((action, w - pad - action.frame.width, y, action.frame.width, 26))
            if tab == .login {
                let forgot = NSButton(title: "忘記密碼？", target: self, action: #selector(forgot))
                forgot.isBordered = false
                forgot.contentTintColor = AccountWindow.grey
                forgot.font = .systemFont(ofSize: 12)
                placed.append((forgot, pad, y + 4, 90, 18))
            }
            y += 26 + 12
        }

        placed.append((statusLabel, pad, y, w - pad * 2, 34))
        y += 34 + 6
        let line = NSBox()
        line.boxType = .separator
        put(line, x: pad, height: 1, gap: 10)
        put(label(tab == .register && sentTo == nil ? "需要邀請碼才能註冊；跟給你這個 App 的人要一組。" : "不登入也可以，便利貼只會存在這台 Mac。",
                  size: 12, color: AccountWindow.grey), height: 18, gap: 0)
        y += pad - 4

        root.frame = NSRect(x: 0, y: 0, width: w, height: y)
        for (view, x, top, width, height) in placed {
            view.frame = NSRect(x: x, y: y - top - height, width: width, height: height)
            root.addSubview(view)
        }
        window.fit(root)
    }

    private func switchTo(_ tab: Tab) {
        guard self.tab != tab else { return }
        self.tab = tab
        setStatus("", error: false)
        build()
        window.makeFirstResponder(emailField)
    }

    private func setStatus(_ text: String, error: Bool) {
        statusLabel.stringValue = text
        statusLabel.font = .systemFont(ofSize: 12, weight: error ? .semibold : .regular)
        statusLabel.textColor = error ? AccountWindow.red : AccountWindow.green
    }

    // MARK: Actions

    private var email: String { emailField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines) }

    @objc private func submit() {
        guard !busy, sentTo == nil else { return }
        // the plain checks here, so the player hears about them before anything is sent
        guard email.contains("@"), email.contains(".") else { return setStatus("信箱看起來不太對。", error: true) }
        let password = passwordField.stringValue
        if tab == .register {
            guard password.count >= 10 else { return setStatus("密碼至少要 10 個字。", error: true) }
            guard password == passwordAgain.stringValue else { return setStatus("兩次輸入的密碼不一樣。", error: true) }
            let name = nameField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty, name.count <= 20 else { return setStatus("暱稱要 1～20 個字。", error: true) }
            let invite = inviteField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !invite.isEmpty else { return setStatus("請填邀請碼。", error: true) }
            run("註冊中…") { [self] in
                _ = try await sync.api.register(email: email, password: password, displayName: name, inviteCode: invite)
                sentTo = email
                passwordField.stringValue = ""
                passwordAgain.stringValue = ""
                build()
                setStatus("", error: false)
            }
        } else {
            guard !password.isEmpty else { return setStatus("請填密碼。", error: true) }
            run("登入中…") { [self] in
                let count = try await sync.signIn(email: email, password: password)
                passwordField.stringValue = ""
                window.orderOut(nil)
                onSignedIn(count == 0 ? "登入了！之後便利貼會自動同步。" : "登入了！這台 Mac 的 \(count) 張便利貼正在同步到帳號。")
            }
        }
    }

    @objc private func forgot() {
        guard email.contains("@") else { return setStatus("請先在上面填你的信箱，再按「忘記密碼？」。", error: true) }
        run("寄送中…") { [self] in
            try await sync.api.forgotPassword(email: email)
            setStatus("如果這個信箱有帳號，重設密碼的信已經寄出（1 小時內有效）。", error: false)
        }
    }

    private func resend() {
        guard let to = sentTo ?? (email.isEmpty ? nil : email) else { return }
        run("寄送中…") { [self] in
            try await sync.api.resendVerification(email: to)
            setStatus("又寄了一封，請看最新的那封。", error: false)
        }
    }

    /// Runs a request with the window showing it is busy, and turns the server's answer into a line under the form.
    private func run(_ working: String, _ body: @escaping @MainActor () async throws -> Void) {
        busy = true
        setStatus(working, error: false)
        statusLabel.textColor = AccountWindow.grey
        Task { @MainActor in
            defer { self.busy = false }
            do {
                try await body()
            } catch let error as APIError {
                switch error.code {
                case "email_not_verified":
                    self.sentTo = self.email
                    self.build()
                    self.setStatus("這個信箱還沒確認。", error: true)
                default:
                    self.setStatus(error.message, error: true)
                }
            } catch {
                self.setStatus(error.localizedDescription, error: true)
            }
        }
    }
}

/// An image drawn without smoothing, so pixel art stays sharp when it is scaled up.
final class PixelImageView: NSImageView {
    override func draw(_ dirtyRect: NSRect) {
        NSGraphicsContext.current?.imageInterpolation = .none
        super.draw(dirtyRect)
    }
}

/// 登入中的裝置：every device signed in to the account, and a way to sign one out.
final class DevicesWindow: NSObject {
    let window: NSWindow
    private let api: APIClient

    init(api: APIClient) {
        self.api = api
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 420, height: 200), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        super.init()
        window.title = "登入中的裝置"
        window.isReleasedWhenClosed = false
        window.level = Levels.dialog
        window.appearance = NSAppearance(named: .aqua)
        window.backgroundColor = .white
        window.center()
    }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        reload()
    }

    private func reload() {
        Task { @MainActor in
            do {
                self.layout(try await self.api.sessions(), note: nil)
            } catch {
                self.layout([], note: (error as? APIError)?.message ?? error.localizedDescription)
            }
        }
    }

    private func layout(_ sessions: [APIClient.SessionInfo], note: String?) {
        let w: CGFloat = 420, pad: CGFloat = 20, rowH: CGFloat = 44
        let height = pad * 2 + CGFloat(max(sessions.count, 1)) * rowH + 24
        let root = NSView(frame: NSRect(x: 0, y: 0, width: w, height: height))
        var y = height - pad - 20
        let header = NSTextField(labelWithString: note ?? "登出某台之後，那台要重新登入才會再同步。")
        header.font = .systemFont(ofSize: 12)
        header.textColor = note == nil ? NSColor(calibratedWhite: 0.45, alpha: 1) : NSColor(calibratedRed: 0.78, green: 0.22, blue: 0.2, alpha: 1)
        header.frame = NSRect(x: pad, y: y, width: w - pad * 2, height: 18)
        root.addSubview(header)
        y -= 8
        for s in sessions {
            y -= rowH
            let kind = s.device?.kind == "pwa" ? "手機" : "Mac"
            let name = NSTextField(labelWithString: "\(s.device?.name ?? "不明的裝置")（\(kind)）\(s.current ? "・這台" : "")")
            name.font = .systemFont(ofSize: 13, weight: .semibold)
            name.frame = NSRect(x: pad, y: y + 20, width: w - pad * 2 - 90, height: 18)
            let seen = NSTextField(labelWithString: "上次使用：" + (ServerTime.parse(s.lastSeenAt).map { NoteTime.text($0) } ?? s.lastSeenAt))
            seen.font = .systemFont(ofSize: 11)
            seen.textColor = NSColor(calibratedWhite: 0.45, alpha: 1)
            seen.frame = NSRect(x: pad, y: y + 3, width: w - pad * 2 - 90, height: 16)
            root.addSubview(name)
            root.addSubview(seen)
            if !s.current {
                let out = PillButton(title: "登出", fill: NSColor(calibratedWhite: 0.9, alpha: 1), textColor: NSColor(calibratedWhite: 0.12, alpha: 1)) { [weak self] in
                    guard let self else { return }
                    Task { @MainActor in
                        try? await self.api.endSession(s.id)
                        self.reload()
                    }
                }
                out.frame.origin = NSPoint(x: w - pad - out.frame.width, y: y + 8)
                root.addSubview(out)
            }
        }
        window.fit(root)
    }
}

extension NSWindow {
    /// Resizes the window to `content` (keeping its top edge where it is, so it grows and shrinks downwards), then shows it.
    func fit(_ content: NSView) {
        var frame = self.frame
        let size = frameRect(forContentRect: NSRect(origin: .zero, size: content.frame.size)).size
        frame.origin.y += frame.height - size.height
        frame.size = size
        setFrame(frame, display: false)
        contentView = content
    }
}

/// A password box with an eye beside it: pressed, the password shows (and the box keeps what was typed); again, it hides.
final class PasswordBox: NSView {
    private let secret = NSSecureTextField()
    private let plain = NSTextField()
    private let eye = NSButton()
    private var shown = false

    /// Both boxes, for the window to style and to answer Return.
    var fields: [NSTextField] { [secret, plain] }
    /// The one showing now.
    var field: NSTextField { shown ? plain : secret }

    var stringValue: String {
        get { field.stringValue }
        set { secret.stringValue = newValue; plain.stringValue = newValue }
    }
    var placeholderString: String? {
        get { secret.placeholderString }
        set { secret.placeholderString = newValue; plain.placeholderString = newValue }
    }

    init() {
        super.init(frame: .zero)
        plain.isHidden = true
        eye.isBordered = false
        eye.imagePosition = .imageOnly
        eye.target = self
        eye.action = #selector(toggle)
        eye.contentTintColor = NSColor(calibratedWhite: 0.45, alpha: 1)
        eye.toolTip = "顯示密碼"
        setEye()
        for v in [secret, plain, eye] as [NSView] { addSubview(v) }
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override func layout() {
        super.layout()
        let eyeWidth: CGFloat = 28
        secret.frame = NSRect(x: 0, y: 0, width: bounds.width - eyeWidth - 4, height: bounds.height)
        plain.frame = secret.frame
        eye.frame = NSRect(x: bounds.width - eyeWidth, y: 0, width: eyeWidth, height: bounds.height)
    }

    private func setEye() {
        let name = shown ? "eye" : "eye.slash"
        eye.image = NSImage(systemSymbolName: name, accessibilityDescription: shown ? "隱藏密碼" : "顯示密碼")
        eye.toolTip = shown ? "隱藏密碼" : "顯示密碼"
    }

    @objc private func toggle() {
        let text = field.stringValue
        let wasFocused = window?.firstResponder === field.currentEditor() || window?.firstResponder === field
        shown.toggle()
        secret.stringValue = text
        plain.stringValue = text
        secret.isHidden = shown
        plain.isHidden = !shown
        setEye()
        if wasFocused { window?.makeFirstResponder(field) }
    }
}
