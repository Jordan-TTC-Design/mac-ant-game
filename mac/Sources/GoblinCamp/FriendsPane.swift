import AppKit

/// 好友, a page of the main window (shared/src/friends.ts; the phone's is pwa/app/pages/friends): friends and their asks, and
/// a conversation with one of them. Like the phone, one thing shows at a time: the list, or one chat with the box to write in
/// at the bottom. The server says when something changed (`friends.changed`, AppDelegate passes it on).
final class FriendsPane: NSObject, MainPane, NSTextFieldDelegate {
    // what the server sends (shared/src/friends.ts)
    struct Last: Decodable {
        let text: String
        let at: String
        let mine: Bool
    }
    struct Friend: Decodable {
        let id: String
        let name: String
        let race: String
        let unread: Int
        let last: Last?
    }
    struct Asker: Decodable {
        let id: String
        let name: String
        let at: String
    }
    struct List: Decodable {
        let code: String
        let friends: [Friend]
        let incoming: [Asker]
        let outgoing: [Asker]
    }
    struct Message: Decodable {
        let id: String
        let mine: Bool
        let text: String
        let at: String
        let read: Bool
    }
    struct Person: Decodable {
        let id: String
        let name: String
    }
    struct Chat: Decodable {
        let friend: Person
        let messages: [Message]
        let more: Bool
    }

    /// shared/src/friends.ts MESSAGE_MAX
    static let messageMax = 200

    private enum Screen { case list, chat }

    let paneView = NSView(frame: NSRect(x: 0, y: 0, width: 600, height: 600))
    private let api: APIClient
    private let scroll = NSScrollView()
    private let doc = TopDownView()
    private let stack = NSStackView()
    private let composer = NSVisualEffectView()
    private let field = NSTextField()
    private let counter = NSTextField(labelWithString: "")
    private var sendButton: ClosureButton!
    private let codeField = NSTextField()

    private var screen = Screen.list
    private var list: List?
    private var chat: Chat?
    /// Whose chat is open (kept while it loads).
    private(set) var chatWith: String?
    private var problem = ""
    private var note = ""
    private var busy = false
    private var scrollDownNext = false
    /// Messages from friends not read yet, all together (the sidebar shows it).
    var onUnread: ((Int) -> Void)?

    init(api: APIClient) {
        self.api = api
        super.init()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        doc.translatesAutoresizingMaskIntoConstraints = false
        doc.addSubview(stack)
        scroll.documentView = doc
        scroll.hasVerticalScroller = true
        scroll.drawsBackground = false
        scroll.borderType = .noBorder
        scroll.translatesAutoresizingMaskIntoConstraints = false
        paneView.addSubview(scroll)

        // the box to write in, under the chat (hidden on the list)
        composer.material = .contentBackground
        composer.translatesAutoresizingMaskIntoConstraints = false
        field.placeholderString = "寫訊息…（Return 送出）"
        field.font = .systemFont(ofSize: 13)
        field.delegate = self
        field.target = self
        field.action = #selector(returnPressed)
        field.lineBreakMode = .byTruncatingHead
        counter.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        counter.textColor = .secondaryLabelColor
        sendButton = GuildUI.button("送出", prominent: true) { [weak self] in self?.send() }
        sendButton.controlSize = .regular
        let bar = GuildUI.row([field, counter, sendButton])
        bar.translatesAutoresizingMaskIntoConstraints = false
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        composer.addSubview(bar)
        let line = NSBox()
        line.boxType = .separator
        line.translatesAutoresizingMaskIntoConstraints = false
        composer.addSubview(line)
        paneView.addSubview(composer)

        let wide = stack.widthAnchor.constraint(equalTo: doc.widthAnchor, constant: -56)
        wide.priority = .defaultHigh
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: paneView.topAnchor), scroll.leadingAnchor.constraint(equalTo: paneView.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: paneView.trailingAnchor), scroll.bottomAnchor.constraint(equalTo: composer.topAnchor),
            composer.leadingAnchor.constraint(equalTo: paneView.leadingAnchor), composer.trailingAnchor.constraint(equalTo: paneView.trailingAnchor),
            composer.bottomAnchor.constraint(equalTo: paneView.bottomAnchor),
            line.topAnchor.constraint(equalTo: composer.topAnchor), line.leadingAnchor.constraint(equalTo: composer.leadingAnchor), line.trailingAnchor.constraint(equalTo: composer.trailingAnchor),
            bar.topAnchor.constraint(equalTo: composer.topAnchor, constant: 10), bar.bottomAnchor.constraint(equalTo: composer.bottomAnchor, constant: -12),
            bar.leadingAnchor.constraint(equalTo: composer.leadingAnchor, constant: 28), bar.trailingAnchor.constraint(equalTo: composer.trailingAnchor, constant: -28),
            doc.leadingAnchor.constraint(equalTo: scroll.contentView.leadingAnchor), doc.trailingAnchor.constraint(equalTo: scroll.contentView.trailingAnchor),
            doc.topAnchor.constraint(equalTo: scroll.contentView.topAnchor),
            doc.heightAnchor.constraint(greaterThanOrEqualTo: scroll.contentView.heightAnchor),
            stack.topAnchor.constraint(equalTo: doc.topAnchor, constant: 24), stack.bottomAnchor.constraint(lessThanOrEqualTo: doc.bottomAnchor, constant: -16),
            stack.leadingAnchor.constraint(equalTo: doc.leadingAnchor, constant: 28),
            stack.widthAnchor.constraint(lessThanOrEqualToConstant: 640), wide,
        ])
        codeField.placeholderString = "朋友的好友代碼，例如 GOB-7K2QXM"
        codeField.font = .systemFont(ofSize: 13)
        codeField.target = self
        codeField.action = #selector(addFriend)
        render()
    }

    func paneWillShow() {
        if screen == .chat, let id = chatWith { open(id) } else { load() }
    }

    /// The server said friends or messages changed (`from`: a message from that friend): what shows is fetched again, and
    /// the count of unread ones in any case.
    func changed(from: String?) {
        if screen == .chat, let id = chatWith, from == nil || from == id {
            loadChat(id, quietly: true)
        } else {
            fetchList()
        }
    }

    /// Opens the chat with this friend (from the princess's news, say).
    func show(chatWith id: String) {
        open(id)
    }

    /// The count of unread messages again (after signing in, or when the connection comes back).
    func refreshCount() { fetchList() }

    // MARK: The server

    /// Does something with the server on the main thread all through, and says what went wrong.
    private func run(_ work: @escaping @MainActor () async throws -> Void) {
        busy = true
        problem = ""
        Task { @MainActor in
            do {
                try await work()
            } catch {
                self.problem = error.localizedDescription
            }
            self.busy = false
            self.render()
        }
    }

    private func load() {
        run { try await self.getList() }
    }

    /// The list and its count, without a word if it fails (a change heard in the background).
    private func fetchList() {
        Task { @MainActor in
            guard (try? await self.getList()) != nil else { return }
            if self.screen == .list { self.render() }
        }
    }

    @MainActor private func getList() async throws {
        let got = try await api.request("GET", "friends", as: List.self)
        list = got
        onUnread?(got.friends.reduce(0) { $0 + $1.unread } + got.incoming.count)
    }

    private func open(_ id: String) {
        if chatWith != id {
            chat = nil
            field.stringValue = ""
        }
        chatWith = id
        screen = .chat
        note = ""
        scrollDownNext = true
        loadChat(id, quietly: false)
        render()
    }

    /// The newest messages (opening them marks theirs read, so the count is fetched again after).
    private func loadChat(_ id: String, quietly: Bool) {
        let work: @MainActor () async throws -> Void = {
            let got = try await self.api.request("GET", "friends/\(id)/messages", as: Chat.self)
            guard self.chatWith == id else { return }
            let grew = got.messages.last?.id != self.chat?.messages.last?.id
            self.chat = got
            if grew { self.scrollDownNext = true }
            try? await self.getList()
        }
        if quietly {
            Task { @MainActor in
                guard (try? await work()) != nil, self.screen == .chat else { return }
                self.render()
            }
        } else {
            run(work)
        }
    }

    /// Older messages, put in front of the ones there.
    private func loadOlder() {
        guard let id = chatWith, let first = chat?.messages.first?.at else { return }
        let before = first.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed.subtracting(CharacterSet(charactersIn: "+:"))) ?? first
        run {
            let got = try await self.api.request("GET", "friends/\(id)/messages?before=\(before)", as: Chat.self)
            guard let now = self.chat, self.chatWith == id else { return }
            self.chat = Chat(friend: now.friend, messages: got.messages + now.messages, more: got.more)
        }
    }

    @objc private func returnPressed() { send() }

    private func send() {
        guard let id = chatWith, !busy else { return }
        let text = field.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        guard text.count <= Self.messageMax else {
            problem = "訊息最多 \(Self.messageMax) 個字。"
            return render()
        }
        struct Body: Encodable { let text: String }
        run {
            let sent = try await self.api.request("POST", "friends/\(id)/messages", body: Body(text: text), as: Message.self)
            self.field.stringValue = ""
            self.updateCounter()
            if let now = self.chat, self.chatWith == id, !now.messages.contains(where: { $0.id == sent.id }) {
                self.chat = Chat(friend: now.friend, messages: now.messages + [sent], more: now.more)
            }
            self.scrollDownNext = true
        }
    }

    @objc private func addFriend() {
        let code = codeField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !code.isEmpty else { return }
        struct Body: Encodable { let code: String }
        struct Answer: Decodable { let status: String }
        note = ""
        run {
            let answer = try await self.api.request("POST", "friends/asks", body: Body(code: code), as: Answer.self)
            self.codeField.stringValue = ""
            self.note = answer.status == "friends" ? "成為好友了！" : "邀請送出了，等對方答應。"
            try await self.getList()
        }
    }

    private func accept(_ id: String) {
        struct Answer: Decodable { let status: String }
        run {
            _ = try await self.api.request("POST", "friends/\(id)/accept", as: Answer.self)
            try await self.getList()
        }
    }

    /// No to an ask, taking one's own ask back, or no longer friends.
    private func drop(_ id: String) {
        run {
            _ = try await self.api.raw("DELETE", "friends/\(id)")
            if self.chatWith == id { self.backToList() }
            try await self.getList()
        }
    }

    private func block(_ id: String) {
        run {
            _ = try await self.api.raw("POST", "friends/\(id)/block")
            self.backToList()
            try await self.getList()
        }
    }

    private func backToList() {
        screen = .list
        chatWith = nil
        chat = nil
        problem = ""
        note = ""
    }

    // MARK: What shows

    private func render() {
        let keepBottom = scrollDownNext
        for v in stack.arrangedSubviews { stack.removeArrangedSubview(v); v.removeFromSuperview() }
        composer.isHidden = screen != .chat
        sendButton.isEnabled = !busy
        switch screen {
        case .list: renderList()
        case .chat: renderChat()
        }
        updateCounter()
        if keepBottom, screen == .chat {
            scrollDownNext = false
            doc.layoutSubtreeIfNeeded()
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.doc.layoutSubtreeIfNeeded()
                let bottom = max(0, self.doc.frame.height - self.scroll.contentView.bounds.height)
                self.scroll.contentView.scroll(to: NSPoint(x: 0, y: bottom))
                self.scroll.reflectScrolledClipView(self.scroll.contentView)
                if self.paneView.window?.firstResponder !== self.field.currentEditor() { self.paneView.window?.makeFirstResponder(self.field) }
            }
        } else if screen == .list {
            scroll.contentView.scroll(to: .zero)
        }
    }

    /// Adds a view as wide as the page (`fill`), or as wide as it is.
    private func add(_ v: NSView, fill: Bool = true, gap: CGFloat? = nil) {
        if let gap, let last = stack.arrangedSubviews.last { stack.setCustomSpacing(gap, after: last) }
        stack.addArrangedSubview(v)
        if fill { v.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true }
    }

    private func title(_ text: String, _ buttons: [NSView]) {
        let h = NSTextField(labelWithString: text)
        h.font = .systemFont(ofSize: 20, weight: .bold)
        h.lineBreakMode = .byTruncatingTail
        h.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        add(GuildUI.row([h, spacer] + buttons))
    }

    private func words(_ text: String, size: CGFloat = 13, color: NSColor = .labelColor, bold: Bool = false) -> NSTextField {
        let l = GuildUI.label(text, size: size, bold: bold, color: color)
        l.isSelectable = true
        l.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return l
    }

    private func renderList() {
        title("好友", [])
        if let list {
            let copy = GuildUI.button("複製") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(list.code, forType: .string)
            }
            let code = GuildUI.label(list.code, size: 13, bold: true)
            code.isSelectable = true
            add(GuildUI.row([GuildUI.note("我的好友代碼"), code, copy]), fill: false)
        }
        codeField.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let ask = GuildUI.button("加好友") { [weak self] in self?.addFriend() }
        ask.isEnabled = !busy
        add(GuildUI.row([codeField, ask]))
        if !note.isEmpty { add(words(note, size: 12, color: .systemGreen)) }
        if !problem.isEmpty { add(words(problem, size: 12, color: .systemRed)) }
        guard let list else {
            if problem.isEmpty { add(words("讀取中…", color: .secondaryLabelColor)) }
            return
        }

        if !list.incoming.isEmpty {
            add(GuildUI.separator(), gap: 14)
            add(GuildUI.heading("想加你好友（\(list.incoming.count)）"))
            for a in list.incoming {
                let id = a.id
                let yes = GuildUI.button("答應", prominent: true) { [weak self] in self?.accept(id) }
                let no = GuildUI.button("婉拒") { [weak self] in self?.drop(id) }
                yes.isEnabled = !busy
                no.isEnabled = !busy
                add(personRow(a.name, under: GuildUI.ago(a.at), trailing: [yes, no]), gap: 4)
            }
        }

        add(GuildUI.separator(), gap: 14)
        add(GuildUI.heading("好友（\(list.friends.count)）"))
        if list.friends.isEmpty { add(GuildUI.note("還沒有好友。把你的代碼給朋友，或輸入朋友的代碼加好友。")) }
        for f in list.friends {
            let last = f.last.map { ($0.mine ? "你：" : "") + $0.text } ?? "還沒有訊息"
            var trailing: [NSView] = []
            if let at = f.last?.at { trailing.append(GuildUI.note(GuildUI.ago(at))) }
            if f.unread > 0 { trailing.append(badge(f.unread)) }
            trailing.append(GuildUI.label("›", size: 16, color: .tertiaryLabelColor))
            let id = f.id
            add(ClickRow(personRow(f.name, under: last, bold: f.unread > 0, trailing: trailing)) { [weak self] in self?.open(id) }, gap: 2)
        }

        if !list.outgoing.isEmpty {
            add(GuildUI.separator(), gap: 14)
            add(GuildUI.heading("等對方答應（\(list.outgoing.count)）"))
            for a in list.outgoing {
                let id = a.id
                let cancel = GuildUI.button("收回") { [weak self] in self?.drop(id) }
                cancel.isEnabled = !busy
                add(personRow(a.name, under: "\(GuildUI.ago(a.at))送出", trailing: [cancel]), gap: 4)
            }
        }
    }

    private func renderChat() {
        let name = chat?.friend.name ?? list?.friends.first { $0.id == chatWith }?.name ?? "好友"
        var buttons: [NSView] = []
        if let id = chatWith {
            let unfriend = GuildUI.sure("解除好友") { [weak self] in self?.drop(id) }
            let blockIt = GuildUI.sure("封鎖") { [weak self] in self?.block(id) }
            unfriend.isEnabled = !busy
            blockIt.isEnabled = !busy
            unfriend.toolTip = "不再是好友，訊息會留著，之後要重新加好友才能再聊。"
            blockIt.toolTip = "不再是好友，對方之後的邀請和訊息都不會送到你這裡（對方不會知道）。"
            buttons = [unfriend, blockIt]
        }
        add(GuildUI.button("‹ 好友") { [weak self] in
            self?.backToList()
            self?.load()
        }, fill: false)
        title(name, buttons)
        if !problem.isEmpty { add(words(problem, size: 12, color: .systemRed)) }
        guard let chat else {
            if problem.isEmpty { add(words("讀取中…", color: .secondaryLabelColor)) }
            return
        }
        if chat.more {
            let older = GuildUI.button("載入更早的訊息") { [weak self] in self?.loadOlder() }
            older.isEnabled = !busy
            add(older, fill: false)
        }
        if chat.messages.isEmpty { add(GuildUI.note("還沒有訊息，打個招呼吧！"), gap: 14) }
        var previous: Date?
        let lastMine = chat.messages.lastIndex { $0.mine }
        for (i, m) in chat.messages.enumerated() {
            let at = ISO8601DateFormatter.guild.date(from: m.at)
            // a time between messages more than 10 minutes apart
            if let at, previous.map({ at.timeIntervalSince($0) > 600 }) ?? true {
                let time = GuildUI.note(Self.clock(at))
                time.alignment = .center
                add(time, gap: 12)
            }
            previous = at ?? previous
            add(bubble(m), gap: 4)
            if i == lastMine {
                let seen = GuildUI.note(m.read ? "已讀" : "送出了")
                seen.alignment = .right
                add(seen, gap: 2)
            }
        }
    }

    // MARK: Pieces

    private func personRow(_ name: String, under: String, bold: Bool = false, trailing: [NSView]) -> NSView {
        let who = GuildUI.label(name, size: 13, bold: true)
        let line = GuildUI.label(under, size: 12, bold: bold, color: bold ? .labelColor : .secondaryLabelColor)
        line.maximumNumberOfLines = 1
        line.lineBreakMode = .byTruncatingTail
        line.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let left = NSStackView(views: [who, line])
        left.orientation = .vertical
        left.alignment = .leading
        left.spacing = 2
        left.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return GuildUI.row([left, spacer] + trailing)
    }

    /// A message: theirs on the left in grey, one's own on the right in the guild's gold.
    private func bubble(_ m: Message) -> NSView {
        let text = NSTextField(wrappingLabelWithString: m.text)
        text.font = .systemFont(ofSize: 13)
        text.isSelectable = true
        text.textColor = m.mine ? NSColor(calibratedRed: 0.17, green: 0.11, blue: 0, alpha: 1) : .labelColor
        text.translatesAutoresizingMaskIntoConstraints = false
        let box = NSView()
        box.wantsLayer = true
        box.layer?.cornerRadius = 12
        // (fixed colours: a layer does not follow light and dark by itself; a translucent grey reads on both)
        box.layer?.backgroundColor = (m.mine ? GuildUI.gold.withAlphaComponent(0.85) : NSColor(white: 0.5, alpha: 0.2)).cgColor
        box.addSubview(text)
        NSLayoutConstraint.activate([
            text.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: 11), text.trailingAnchor.constraint(equalTo: box.trailingAnchor, constant: -11),
            text.topAnchor.constraint(equalTo: box.topAnchor, constant: 7), text.bottomAnchor.constraint(equalTo: box.bottomAnchor, constant: -7),
            text.widthAnchor.constraint(lessThanOrEqualToConstant: 380),
        ])
        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        let row = GuildUI.row(m.mine ? [spacer, box] : [box, spacer], spacing: 0)
        row.alignment = .top
        return row
    }

    private func badge(_ n: Int) -> NSView {
        let l = NSTextField(labelWithString: n > 99 ? "99+" : "\(n)")
        l.font = .systemFont(ofSize: 10, weight: .bold)
        l.textColor = .white
        l.alignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        let box = NSView()
        box.wantsLayer = true
        box.layer?.cornerRadius = 8
        box.layer?.backgroundColor = NSColor.systemRed.cgColor
        box.addSubview(l)
        NSLayoutConstraint.activate([
            l.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: 5), l.trailingAnchor.constraint(equalTo: box.trailingAnchor, constant: -5),
            l.centerYAnchor.constraint(equalTo: box.centerYAnchor), box.heightAnchor.constraint(equalToConstant: 16),
            box.widthAnchor.constraint(greaterThanOrEqualToConstant: 16),
        ])
        return box
    }

    /// 「今天 14:05」「昨天 22:10」「10/12 09:00」
    private static func clock(_ at: Date) -> String {
        let cal = Calendar.current
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_TW")
        f.dateFormat = "HH:mm"
        if cal.isDateInToday(at) { return "今天 \(f.string(from: at))" }
        if cal.isDateInYesterday(at) { return "昨天 \(f.string(from: at))" }
        f.dateFormat = cal.isDate(at, equalTo: Date(), toGranularity: .year) ? "M/d HH:mm" : "yyyy/M/d HH:mm"
        return f.string(from: at)
    }

    /// How many may still be typed, shown only near the end.
    private func updateCounter() {
        let left = Self.messageMax - field.stringValue.count
        counter.stringValue = left <= 40 ? "\(left)" : ""
        counter.textColor = left < 0 ? .systemRed : .secondaryLabelColor
    }

    func controlTextDidChange(_ obj: Notification) { updateCounter() }

    /// A test: the page with made-up friends and messages, without a server ("list" or "chat").
    func debugShow(_ which: String) {
        let names = """
        {"code":"GOB-7K2QXM","friends":[
        {"id":"f1","name":"咕嚕","race":"goblin","since":"2026-10-01T04:00:00.000Z","unread":2,"last":{"text":"晚上要不要一起打世界魔王？我這邊已經準備好補給了","at":"2026-10-17T05:50:00.000Z","mine":false}},
        {"id":"f2","name":"幽幽","race":"undead","since":"2026-10-02T04:00:00.000Z","unread":0,"last":{"text":"好喔","at":"2026-10-16T12:00:00.000Z","mine":true}},
        {"id":"f3","name":"小精靈","race":"elf","since":"2026-10-03T04:00:00.000Z","unread":0,"last":null}],
        "incoming":[{"id":"i1","name":"新來的","race":"goblin","at":"2026-10-17T03:00:00.000Z"}],
        "outgoing":[{"id":"o1","name":"等等我","race":"elf","at":"2026-10-15T03:00:00.000Z"}]}
        """
        let talk = """
        {"friend":{"id":"f1","name":"咕嚕","race":"goblin"},"more":true,"messages":[
        {"id":"m1","mine":true,"text":"你的領地被打了嗎？","at":"2026-10-16T12:00:00.000Z","read":true},
        {"id":"m2","mine":false,"text":"還好，守住了，謝謝你昨天來幫忙守！","at":"2026-10-16T12:02:00.000Z","read":true},
        {"id":"m3","mine":true,"text":"不客氣～","at":"2026-10-16T12:03:00.000Z","read":true},
        {"id":"m4","mine":false,"text":"晚上要不要一起打世界魔王？","at":"2026-10-17T05:49:00.000Z","read":true},
        {"id":"m5","mine":false,"text":"我這邊已經準備好補給了，大概九點上線，你那時候方便嗎？如果不行也沒關係，我們改天再約。","at":"2026-10-17T05:50:00.000Z","read":true},
        {"id":"m6","mine":true,"text":"可以！九點見","at":"2026-10-17T05:52:00.000Z","read":false}]}
        """
        list = try? APIClient.decoder.decode(List.self, from: Data(names.utf8))
        if which == "chat" {
            chat = try? APIClient.decoder.decode(Chat.self, from: Data(talk.utf8))
            chatWith = "f1"
            screen = .chat
            field.stringValue = String(repeating: "很長的訊息", count: 33)
            scrollDownNext = true
        }
        render()
    }
}
