import AppKit

/// The main window's 公會 page (GUILD.md), native like the camp: the hall fills the page (GuildHallView); the guild's name,
/// a few buttons and the chat float over it. Decorating, the avatar maker, donating, the members and the settings are panels
/// on the page itself (GuildDecorEditor, GuildPanels, GuildAvatarPanel), no windows of their own. Without a guild: a line and
/// a button to found or join one.
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
    /// The page goes to a window of its own and back (AppDelegate), and stays above the others when it is out.
    var onPop: (() -> Void)?
    var onTop: (() -> Void)?
    private var popButton: ClosureButton!
    private var topButton: ClosureButton!
    private let notice = NSTextField(labelWithString: "")
    private let noticeBox = NSVisualEffectView()
    private var noticeTimer: Timer?
    /// The side panel that is open (decorating, and the others), one at a time.
    private var panel: NSView?
    private var editor: GuildDecorEditor?
    private var controller: GuildPanelController?

    private var info: GuildInfo?
    private var chat: [GuildChatLine] = []
    private var myId: String?
    private var refresh: Timer?
    /// The chat's lines show while typing and for a while after something is said; otherwise just the box, out of the way.
    private var linesUntil = Date.distantPast
    private var linesTimer: Timer?

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
        let items: [(String, String, () -> Void)] = [
            ("🪑 擺裝飾", "擺裝飾、鋪地板、換牆壁", { [weak self] in self?.toggleDecor() }),
            ("🧑‍🎨 角色", "捏自己的角色", { [weak self] in self?.toggle(GuildAvatarPanel.self) }),
            ("🎁 捐獻", "營地的材料捐給公會，讓公會升級", { [weak self] in self?.toggle(GuildDonatePanel.self) }),
            ("👥 成員", "成員、邀請、職位", { [weak self] in self?.toggle(GuildMembersPanel.self) }),
            ("⚙️ 設定", "名字、徽章、擺放紀錄（會長、幹部）", { [weak self] in self?.toggle(GuildSettingsPanel.self) }),
        ]
        popButton = ClosureButton(title: "⧉ 彈出") { [weak self] in self?.onPop?() }
        topButton = ClosureButton(title: "📌 置頂") { [weak self] in self?.onTop?() }
        for b in [popButton!, topButton!] {
            b.bezelStyle = .rounded
            b.controlSize = .small
            buttons.addArrangedSubview(b)
        }
        topButton.isHidden = true
        popButton.toolTip = "把公會頁彈出成獨立的小視窗，可以放在桌面角落"
        topButton.toolTip = "小視窗永遠在其他視窗上面"
        for (label, tip, action) in items {
            let b = ClosureButton(title: label, action: action)
            b.bezelStyle = .rounded
            b.controlSize = .small
            b.toolTip = tip
            buttons.addArrangedSubview(b)
        }
        buttons.spacing = 6
        paneView.addSubview(buttons)

        // a line that says what just happened, under the name
        noticeBox.material = .hudWindow
        noticeBox.blendingMode = .withinWindow
        noticeBox.state = .active
        noticeBox.wantsLayer = true
        noticeBox.layer?.cornerRadius = 8
        noticeBox.isHidden = true
        notice.font = .systemFont(ofSize: 12, weight: .semibold)
        notice.textColor = NSColor(calibratedRed: 1, green: 0.95, blue: 0.77, alpha: 1)
        notice.lineBreakMode = .byTruncatingTail
        noticeBox.addSubview(notice)
        notice.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([notice.leadingAnchor.constraint(equalTo: noticeBox.leadingAnchor, constant: 10), notice.trailingAnchor.constraint(equalTo: noticeBox.trailingAnchor, constant: -10),
                                     notice.topAnchor.constraint(equalTo: noticeBox.topAnchor, constant: 5), notice.bottomAnchor.constraint(equalTo: noticeBox.bottomAnchor, constant: -5)])
        paneView.addSubview(noticeBox)

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
        emptyText.preferredMaxLayoutWidth = 320
        emptyText.textColor = .white
        let found = ClosureButton(title: "建立或加入公會") { [weak self] in self?.toggle(GuildFoundPanel.self) }
        found.bezelStyle = .rounded
        empty.orientation = .vertical
        empty.spacing = 12
        empty.addArrangedSubview(emptyText)
        empty.addArrangedSubview(found)
        paneView.addSubview(empty)

        for v in [card, buttons, chatBox, empty, noticeBox] { v.translatesAutoresizingMaskIntoConstraints = false }
        NSLayoutConstraint.activate([
            card.leadingAnchor.constraint(equalTo: paneView.leadingAnchor, constant: 10), card.topAnchor.constraint(equalTo: paneView.topAnchor, constant: 10),
            noticeBox.leadingAnchor.constraint(equalTo: paneView.leadingAnchor, constant: 10), noticeBox.topAnchor.constraint(equalTo: card.bottomAnchor, constant: 6),
            noticeBox.widthAnchor.constraint(lessThanOrEqualToConstant: 420),
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
        defer {
            // (the open panel looks at the news; one that is for a guild closes when there is none, and the other way round)
            if got != nil {
                if (controller is GuildFoundPanel) != (got?.guild == nil) { closePanel() } else { controller?.guildChanged() }
            }
        }
        let g = got?.guild
        for v in [card, buttons, chatBox] as [NSView] { v.isHidden = g == nil }
        empty.isHidden = g != nil || got == nil
        let waiting = got?.invites.count ?? 0
        emptyText.stringValue = "你還沒有加入公會。\n" + (waiting > 0 ? "有 \(waiting) 個公會邀請你。" : "建立一個，或請會長、幹部用你的好友代碼邀請你。")
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
        if editor == nil {
            // (not while decorating: the draft is what the hall shows then)
            hall.decor = g.decor
            hall.floorBase = g.floor.base
            hall.floorTiles = g.floor.tiles
        }
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

    private func showChat(fresh: Bool = false) {
        if fresh { linesUntil = Date().addingTimeInterval(10) }
        foldLines()
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
            showChat(fresh: true)
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
                self.showChat(fresh: true)
            }
        }
    }

    /// Shows the lines (typing, or something just said) or folds them away, and looks again when that may change.
    private func foldLines() {
        let typing = paneView.window?.firstResponder === sayField.currentEditor()
        chatLines.isHidden = !(typing || Date() < linesUntil)
        linesTimer?.invalidate()
        if !chatLines.isHidden { linesTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: false) { [weak self] _ in self?.foldLines() } }
    }

    func controlTextDidBeginEditing(_ obj: Notification) { foldLines() }
    func controlTextDidEndEditing(_ obj: Notification) { foldLines() }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
        if selector == #selector(NSResponder.cancelOperation(_:)) {
            paneView.window?.makeFirstResponder(hall)
            return true
        }
        return false
    }

    /// What the two window buttons say: out in a window of its own or not, and whether that window stays on top.
    func setPopped(_ popped: Bool, onTop: Bool) {
        popButton.title = popped ? "⧉ 收回主視窗" : "⧉ 彈出"
        popButton.toolTip = popped ? "把公會頁收回主視窗" : "把公會頁彈出成獨立的小視窗，可以放在桌面角落"
        topButton.isHidden = !popped
        topButton.title = onTop ? "📌 置頂中" : "📌 置頂"
        if onTop { topButton.bezelColor = GuildUI.gold } else { topButton.bezelColor = nil }
    }

    // MARK: Test hooks (`GUILD_TEST`, AppDelegate)

    /// Shows this guild (a JSON as the server sends it) and opens one of the panels, so they can be looked at without a server.
    func debugShow(_ data: Data, me: String, panel name: String) {
        myId = me
        hall.me = me
        guard let got = try? JSONDecoder().decode(GuildInfo.self, from: data) else { return }
        show(got)
        switch name {
        case "decor": toggleDecor()
        case "avatar": toggle(GuildAvatarPanel.self)
        case "donate": toggle(GuildDonatePanel.self)
        case "members": toggle(GuildMembersPanel.self)
        case "settings": toggle(GuildSettingsPanel.self)
        case "found": toggle(GuildFoundPanel.self)
        default: break
        }
    }

    func debugCategory(_ title: String) { editor?.debugSelect(title) }

    /// Clicks the first card of the open decorating panel the way a mouse would (a test: says what changed).
    func debugClickFirstCard() -> String {
        let alive = "controller alive: \(controller != nil || editor != nil)"
        if controller != nil { return alive }
        guard let panel = panel else { return "no panel (editor \(editor == nil ? "nil" : "set"), controller \(controller == nil ? "nil" : "set"), info \(info == nil ? "nil" : "set"), me \(myId ?? "nil"))" }
        guard let window = paneView.window else { return "no window" }
        func cards(_ v: NSView) -> [CatalogCell] { (v as? CatalogCell).map { [$0] } ?? v.subviews.flatMap(cards) }
        guard let cell = cards(panel).first else { return "no card" }
        let before = hall.decor.count
        let p = cell.convert(NSPoint(x: cell.bounds.midX, y: cell.bounds.midY), to: nil)
        for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
            if let e = NSEvent.mouseEvent(with: type, location: p, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1) {
                window.sendEvent(e)
            }
        }
        let hit = window.contentView?.hitTest(paneView.superview?.convert(p, from: nil) ?? p)
        return "\(alive); decor \(before) -> \(hall.decor.count); hit view: \(hit.map { String(describing: type(of: $0)) } ?? "nil")"
    }

    // MARK: Panels on the page

    /// Says what just happened for a few seconds.
    func notify(_ text: String) {
        notice.stringValue = text
        noticeBox.isHidden = text.isEmpty
        noticeTimer?.invalidate()
        noticeTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: false) { [weak self] _ in self?.noticeBox.isHidden = true }
    }

    private var context: GuildContext {
        GuildContext(api: api, info: { [weak self] in self?.info }, me: { [weak self] in self?.myId },
                     apply: { [weak self] got in self?.show(got) }, reload: { [weak self] in self?.load() },
                     notify: { [weak self] text in self?.notify(text) }, close: { [weak self] in self?.closePanel() })
    }

    /// Puts a panel on the right of the page (closing the one that was there).
    /// (The caller has closed the one before, and made the new controller: this must not tear that down, or its buttons do nothing.)
    private func open(panel view: NSView, width: CGFloat = 380) {
        panel?.removeFromSuperview()
        panel = view
        hall.rightInset = width + 20
        paneView.addSubview(view)
        view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            view.trailingAnchor.constraint(equalTo: paneView.trailingAnchor, constant: -10), view.topAnchor.constraint(equalTo: buttons.bottomAnchor, constant: 8),
            view.bottomAnchor.constraint(equalTo: paneView.bottomAnchor, constant: -10), view.widthAnchor.constraint(equalToConstant: width),
        ])
    }

    private func closePanel() {
        if let editor {
            editor.release()
            self.editor = nil
            showSaved() // (what was changed and not saved goes away)
        }
        controller = nil
        hall.rightInset = 0
        panel?.removeFromSuperview()
        panel = nil
        paneView.window?.makeFirstResponder(hall)
    }

    /// The hall as the server has it (the decorating draft is put down).
    private func showSaved() {
        guard let g = info?.guild else { return }
        hall.decor = g.decor
        hall.floorBase = g.floor.base
        hall.floorTiles = g.floor.tiles
    }

    /// Opens one of the panels, or closes it when it is the one open.
    private func toggle<T: GuildPanelController>(_ kind: T.Type) where T: GuildPanelInit {
        if controller is T {
            closePanel()
            return
        }
        guard info != nil else { return }
        closePanel()
        let c = T(context)
        controller = c
        open(panel: c.view, width: c.view.width)
    }

    private func toggleDecor() {
        if editor != nil {
            closePanel()
            return
        }
        guard let g = info?.guild, let role = g.members.first(where: { $0.id == myId })?.role else { return }
        closePanel()
        let e = GuildDecorEditor(hall: hall, api: api, guild: g, role: role)
        e.onGuild = { [weak self] got in self?.show(got) }
        e.onFinish = { [weak self] got, note in
            guard let self else { return }
            self.editor = nil
            if got == nil { self.showSaved() }
            self.closePanel()
            if let got { self.show(got) } else { self.load() }
            if let note { self.notify(note) }
        }
        editor = e
        open(panel: e.view, width: 372)
        paneView.window?.makeFirstResponder(hall)
    }
}
