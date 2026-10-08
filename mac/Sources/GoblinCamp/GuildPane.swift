import AppKit

/// The main window's 公會 page (GUILD.md), native like the camp: the hall fills the page (GuildHallView); the guild's name,
/// a few buttons and the chat float over it. Decorating, the avatar maker, the members and the settings are the web pages
/// (the same as the phone's), opened in a window of their own. Without a guild: a line and a button to found or join one.
final class GuildPane: NSObject, MainPane, NSTextFieldDelegate {
    let paneView = NSView(frame: NSRect(x: 0, y: 0, width: 900, height: 700))
    private let hall = GuildHallView(frame: NSRect(x: 0, y: 0, width: 900, height: 700))
    private let api: APIClient
    /// Sends a message up the WebSocket (SyncEngine).
    private let sendLive: ([String: Any]) -> Void

    private let title = NSTextField(labelWithString: "")
    private let subtitle = NSTextField(labelWithString: "")
    private let card = NSVisualEffectView()
    private let buttons = NSStackView()
    private let chatBox = NSVisualEffectView()
    private let chatLines = NSTextField(wrappingLabelWithString: "")
    private let sayField = NSTextField()
    private let empty = NSStackView()
    private let emptyText = NSTextField(wrappingLabelWithString: "")
    private var webWindows: [String: NSWindow] = [:]
    private var webPanes: [String: WebPane] = [:]

    private var info: GuildInfo?
    private var chat: [GuildChatLine] = []
    private var myId: String?
    private var refresh: Timer?

    init(api: APIClient, myId: String?, sendLive: @escaping ([String: Any]) -> Void) {
        self.api = api
        self.myId = myId
        self.sendLive = sendLive
        super.init()
        hall.autoresizingMask = [.width, .height]
        hall.send = sendLive
        hall.onTalk = { [weak self] in self?.paneView.window?.makeFirstResponder(self?.sayField) }
        paneView.addSubview(hall)
        buildOverlay()
    }

    // MARK: Layout

    private func buildOverlay() {
        // the guild's name, top left
        card.material = .hudWindow
        card.blendingMode = .withinWindow
        card.state = .active
        card.wantsLayer = true
        card.layer?.cornerRadius = 10
        title.font = .boldSystemFont(ofSize: 14)
        subtitle.font = .systemFont(ofSize: 11)
        subtitle.textColor = .secondaryLabelColor
        let names = NSStackView(views: [title, subtitle])
        names.orientation = .vertical
        names.alignment = .leading
        names.spacing = 1
        names.edgeInsets = NSEdgeInsets(top: 6, left: 10, bottom: 6, right: 10)
        card.addSubview(names)
        names.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([names.leadingAnchor.constraint(equalTo: card.leadingAnchor), names.trailingAnchor.constraint(equalTo: card.trailingAnchor),
                                     names.topAnchor.constraint(equalTo: card.topAnchor), names.bottomAnchor.constraint(equalTo: card.bottomAnchor)])
        paneView.addSubview(card)

        // the buttons, top right
        for (label, path, tip) in [("🪑 擺裝飾", "/guild", "擺裝飾、鋪地板、換牆壁"), ("🧑‍🎨 分身", "/avatar", "捏自己的分身"), ("👥 成員", "/guild/members", "成員、邀請、職位"), ("⚙️ 設定", "/guild/settings", "名字、徽章、擺放紀錄（會長、幹部）")] {
            let b = ClosureButton(title: label) { [weak self] in self?.openWeb(path, title: label) }
            b.bezelStyle = .rounded
            b.controlSize = .small
            b.toolTip = tip
            buttons.addArrangedSubview(b)
        }
        buttons.spacing = 6
        paneView.addSubview(buttons)

        // the chat, bottom left
        chatBox.material = .hudWindow
        chatBox.blendingMode = .withinWindow
        chatBox.state = .active
        chatBox.wantsLayer = true
        chatBox.layer?.cornerRadius = 10
        chatLines.font = .systemFont(ofSize: 12)
        chatLines.maximumNumberOfLines = 6
        sayField.placeholderString = "說點什麼…（Return 送出，Esc 回到據點）"
        sayField.delegate = self
        sayField.target = self
        sayField.action = #selector(say)
        let chatStack = NSStackView(views: [chatLines, sayField])
        chatStack.orientation = .vertical
        chatStack.alignment = .leading
        chatStack.spacing = 6
        chatStack.edgeInsets = NSEdgeInsets(top: 8, left: 10, bottom: 8, right: 10)
        chatBox.addSubview(chatStack)
        chatStack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([chatStack.leadingAnchor.constraint(equalTo: chatBox.leadingAnchor), chatStack.trailingAnchor.constraint(equalTo: chatBox.trailingAnchor),
                                     chatStack.topAnchor.constraint(equalTo: chatBox.topAnchor), chatStack.bottomAnchor.constraint(equalTo: chatBox.bottomAnchor),
                                     sayField.widthAnchor.constraint(equalTo: chatStack.widthAnchor, constant: -20), chatLines.widthAnchor.constraint(equalTo: sayField.widthAnchor)])
        paneView.addSubview(chatBox)

        // no guild yet
        emptyText.alignment = .center
        emptyText.textColor = .white
        let found = ClosureButton(title: "建立或加入公會") { [weak self] in self?.openWeb("/guild", title: "公會") }
        found.bezelStyle = .rounded
        empty.orientation = .vertical
        empty.spacing = 12
        empty.addArrangedSubview(emptyText)
        empty.addArrangedSubview(found)
        paneView.addSubview(empty)

        for v in [card, buttons, chatBox, empty] { v.translatesAutoresizingMaskIntoConstraints = false }
        NSLayoutConstraint.activate([
            card.leadingAnchor.constraint(equalTo: paneView.leadingAnchor, constant: 10), card.topAnchor.constraint(equalTo: paneView.topAnchor, constant: 10),
            buttons.trailingAnchor.constraint(equalTo: paneView.trailingAnchor, constant: -10), buttons.topAnchor.constraint(equalTo: paneView.topAnchor, constant: 10),
            chatBox.leadingAnchor.constraint(equalTo: paneView.leadingAnchor, constant: 10), chatBox.bottomAnchor.constraint(equalTo: paneView.bottomAnchor, constant: -10),
            chatBox.widthAnchor.constraint(equalToConstant: 360),
            empty.centerXAnchor.constraint(equalTo: paneView.centerXAnchor), empty.centerYAnchor.constraint(equalTo: paneView.centerYAnchor),
            empty.widthAnchor.constraint(lessThanOrEqualToConstant: 360),
        ])
        show(nil)
    }

    // MARK: MainPane

    func paneWillShow() {
        load()
        loadChat()
        refresh?.invalidate()
        // (presence that went stale, and anything a missed event changed)
        refresh = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in self?.load() }
        DispatchQueue.main.async { self.paneView.window?.makeFirstResponder(self.hall) }
    }

    func paneDidHide() {
        refresh?.invalidate()
        hall.releaseHand()
    }

    func signedIn(as id: String?) {
        myId = id
        hall.me = id
    }

    // MARK: Data

    func load() {
        Task { @MainActor in
            guard let got = try? await self.api.request("GET", "guild", as: GuildInfo.self) else { return }
            self.show(got)
        }
    }

    private func loadChat() {
        struct Lines: Decodable { let lines: [GuildChatLine] }
        Task { @MainActor in
            guard let got = try? await self.api.request("GET", "guild/chat", as: Lines.self) else { return }
            self.chat = got.lines
            self.showChat()
        }
    }

    private func show(_ got: GuildInfo?) {
        info = got
        let g = got?.guild
        for v in [card, buttons, chatBox] as [NSView] { v.isHidden = g == nil }
        empty.isHidden = g != nil || got == nil
        emptyText.stringValue = "你還沒有加入公會。\n建立一個，或請會長、幹部用你的好友代碼邀請你。"
        guard let g else {
            hall.members = []
            hall.decor = []
            return
        }
        let now = Date()
        let online = g.members.filter { presence($0, now) != "offline" }.count
        title.stringValue = g.name
        subtitle.stringValue = "Lv \(g.level)・\(g.members.count)／\(g.rules.members) 人・\(online) 人在線"
        hall.level = g.level
        hall.me = myId
        hall.members = g.members.sorted { $0.joinedAt < $1.joinedAt }.enumerated().map { i, m in
            GuildHallView.Member(id: m.id, name: m.name, avatar: m.avatar, presence: presence(m, now), seat: i)
        }
        hall.decor = g.decor
        hall.floorBase = g.floor.base
        hall.floorTiles = g.floor.tiles
        hall.wall = g.wall
        // (the settings button is the leader's and officers')
        let mine = g.members.first { $0.id == myId }
        buttons.arrangedSubviews.last?.isHidden = mine?.role == "member"
    }

    /// What a member's last report means now (shared/src/guild.ts presenceNow).
    private func presence(_ m: GuildInfo.Member, _ now: Date) -> String {
        guard m.presence != "offline", let seen = m.seenAt.flatMap({ ISO8601DateFormatter.guild.date(from: $0) }), now.timeIntervalSince(seen) <= GuildTiming.presenceTTL else { return "offline" }
        return m.presence
    }

    private func showChat() {
        let recent = chat.suffix(5)
        chatLines.stringValue = recent.isEmpty ? "還沒有人說話，打個招呼吧。" : recent.map { "\($0.name)：\($0.text)" }.joined(separator: "\n")
        let now = Date()
        var bubbles: [String: (String, Date)] = [:]
        for line in chat {
            guard let at = ISO8601DateFormatter.guild.date(from: line.at) else { continue }
            let until = at.addingTimeInterval(GuildTiming.bubble)
            if until > now { bubbles[line.userId] = (line.text, until) }
        }
        hall.bubbles = bubbles.mapValues { (text: $0.0, until: $0.1) }
    }

    /// The server's news about the guild (AppDelegate passes the guild.* events on).
    func event(_ type: String, _ event: [String: Any]) {
        switch type {
        case "guild.changed":
            load()
        case "guild.presence":
            load()
        case "guild.move":
            guard let id = event["userId"] as? String, let move = GuildMove(event: event) else { return }
            hall.others[id] = (move, Date())
        case "guild.release":
            if let id = event["userId"] as? String { hall.others[id] = nil }
        case "guild.say":
            guard let data = try? JSONSerialization.data(withJSONObject: event), let line = try? JSONDecoder().decode(GuildChatLine.self, from: data) else { return }
            if !chat.contains(line) { chat = Array((chat + [line]).suffix(50)) }
            showChat()
        default:
            break
        }
    }

    // MARK: Talking

    @objc private func say() {
        let text = sayField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        sayField.stringValue = ""
        struct Body: Encodable { let text: String }
        Task { @MainActor in
            if let line = try? await self.api.request("POST", "guild/say", body: Body(text: String(text.prefix(GuildTiming.sayMax))), as: GuildChatLine.self), !self.chat.contains(line) {
                self.chat = Array((self.chat + [line]).suffix(50))
                self.showChat()
            }
        }
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
        if selector == #selector(NSResponder.cancelOperation(_:)) {
            paneView.window?.makeFirstResponder(hall)
            return true
        }
        return false
    }

    // MARK: The web pages

    /// Opens one of the guild's web pages in a window of its own (one per page, kept).
    private func openWeb(_ path: String, title: String) {
        if let w = webWindows[path] {
            webPanes[path]?.paneWillShow()
            w.makeKeyAndOrderFront(nil)
            return
        }
        let pane = WebPane(api: api, path: path)
        let size = path == "/guild" ? NSSize(width: 1100, height: 720) : NSSize(width: 440, height: 720) // (decorating needs the hall beside the catalog)
        let w = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.titled, .closable, .resizable, .miniaturizable], backing: .buffered, defer: false)
        w.title = title.replacingOccurrences(of: #"^\S+ "#, with: "", options: .regularExpression)
        w.isReleasedWhenClosed = false
        pane.paneView.frame = w.contentLayoutRect
        pane.paneView.autoresizingMask = [.width, .height]
        w.contentView = pane.paneView
        w.center()
        webWindows[path] = w
        webPanes[path] = pane
        pane.paneWillShow()
        w.makeKeyAndOrderFront(nil)
    }
}
