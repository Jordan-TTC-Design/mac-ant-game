import AppKit

/// 回報, a page of the main window (shared/src/feedback.ts; the phone's is pwa/app/pages/feedback): anyone signed in sends a
/// bug, an idea or a balance note, and sees everyone's and where each one stands. One thing shows at a time, like the
/// phone's pages: the list, one report with the thread under it, or the form for a new one.
final class FeedbackPane: NSObject, MainPane {
    // what the server sends (shared/src/feedback.ts)
    struct Summary: Decodable {
        let id: String
        let kind: String
        let title: String
        let status: String
        let author: String
        let mine: Bool
        let replies: Int
        let votes: Int
        let voted: Bool
        let createdAt: String
        let updatedAt: String
    }
    struct Reply: Decodable {
        let id: String
        let author: String
        let admin: Bool
        let body: String
        let status: String?
        let at: String
    }
    struct Detail: Decodable {
        let id: String
        let kind: String
        let title: String
        let status: String
        let author: String
        let mine: Bool
        let votes: Int
        let voted: Bool
        let createdAt: String
        let body: String
        let device: String?
        let thread: [Reply]
        let admin: Bool
    }
    struct List: Decodable {
        let items: [Summary]
        let counts: [String: Int]
        let admin: Bool
    }

    static let kinds = ["bug", "idea", "balance"]
    static let kindLabel = ["bug": "Bug", "idea": "優化建議", "balance": "遊戲平衡"]
    /// In the order a report usually goes through them.
    static let statuses = ["open", "accepted", "working", "next", "done", "declined"]
    static let statusLabel = ["open": "待確認", "accepted": "已收到", "working": "處理中", "next": "下次更新", "done": "已完成", "declined": "不處理"]
    static let voteLabel = ["bug": "我也遇到", "idea": "我也想要", "balance": "我也同意"]
    static let hint = [
        "bug": "發生了什麼事？怎麼做會出現？原本以為會怎樣？",
        "idea": "想要哪裡變得更好用？為什麼？",
        "balance": "哪裡太強、太弱、太慢或太快？大概想調成怎樣？",
    ]
    private static let kindColor: [String: NSColor] = [
        "bug": NSColor(calibratedRed: 0.78, green: 0.22, blue: 0.18, alpha: 1),
        "idea": NSColor(calibratedRed: 0.18, green: 0.44, blue: 0.75, alpha: 1),
        "balance": NSColor(calibratedRed: 0.48, green: 0.31, blue: 0.66, alpha: 1),
    ]
    private static let statusColor: [String: NSColor] = [
        "open": NSColor(white: 0.45, alpha: 1),
        "accepted": NSColor(calibratedRed: 0.18, green: 0.44, blue: 0.75, alpha: 1),
        "working": NSColor(calibratedRed: 0.85, green: 0.45, blue: 0.05, alpha: 1),
        "next": NSColor(calibratedRed: 0.48, green: 0.31, blue: 0.66, alpha: 1),
        "done": NSColor(calibratedRed: 0.23, green: 0.6, blue: 0.28, alpha: 1),
        "declined": NSColor(white: 0.3, alpha: 1),
    ]

    private enum Screen { case list, detail, writing }

    let paneView = NSView(frame: NSRect(x: 0, y: 0, width: 600, height: 600))
    private let api: APIClient
    private let scroll = NSScrollView()
    private let doc = TopDownView()
    private let stack = NSStackView()

    private var screen = Screen.list
    private var list: List?
    private var item: Detail?
    private var problem = ""
    private var busy = false

    // the list's filters ("active": everything not yet done or declined)
    private var status = "active"
    private var kind = ""
    private var mine = false
    private var byVotes = false

    // what is being written (kept while the page is redrawn or switched away from)
    private var newKind = "bug"
    private let titleField = NSTextField()
    private let bodyText = FeedbackPane.textBox()
    private let replyText = FeedbackPane.textBox()
    private var nextStatus = "open"
    private var hintLabel: NSTextField?
    private var sendButton: ClosureButton?

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
        scroll.frame = paneView.bounds
        scroll.autoresizingMask = [.width, .height]
        paneView.addSubview(scroll)
        let wide = stack.widthAnchor.constraint(equalTo: doc.widthAnchor, constant: -56)
        wide.priority = .defaultHigh
        NSLayoutConstraint.activate([
            doc.leadingAnchor.constraint(equalTo: scroll.contentView.leadingAnchor), doc.trailingAnchor.constraint(equalTo: scroll.contentView.trailingAnchor),
            doc.topAnchor.constraint(equalTo: scroll.contentView.topAnchor),
            stack.topAnchor.constraint(equalTo: doc.topAnchor, constant: 24), stack.bottomAnchor.constraint(equalTo: doc.bottomAnchor, constant: -24),
            stack.leadingAnchor.constraint(equalTo: doc.leadingAnchor, constant: 28),
            stack.widthAnchor.constraint(lessThanOrEqualToConstant: 640), wide,
        ])
        titleField.placeholderString = "一句話說明"
        titleField.font = .systemFont(ofSize: 13)
        render()
    }

    func paneWillShow() {
        if screen == .detail, let id = item?.id { open(id) } else if screen == .list { load() }
    }

    /// A test: the page with made-up reports, without a server ("list", "detail" or "writing").
    func debugShow(_ which: String) {
        let json = """
        {"admin":true,"counts":{"open":2,"accepted":1,"working":1,"next":0,"done":5,"declined":1},"items":[
        {"id":"a","kind":"bug","title":"捐獻材料之後軟體直接關掉","status":"working","author":"jordan","mine":true,"replies":2,"votes":3,"voted":false,"createdAt":"2026-10-12T04:00:00.000Z","updatedAt":"2026-10-12T09:00:00.000Z"},
        {"id":"b","kind":"idea","title":"公會據點希望可以自己畫範圍，不要升級就自動往右下長大，擺設會跑版","status":"next","author":"咕嚕","mine":false,"replies":0,"votes":7,"voted":true,"createdAt":"2026-10-11T04:00:00.000Z","updatedAt":"2026-10-12T03:00:00.000Z"},
        {"id":"c","kind":"balance","title":"精靈的弓太強了","status":"open","author":"幽幽","mine":false,"replies":1,"votes":0,"voted":false,"createdAt":"2026-10-10T04:00:00.000Z","updatedAt":"2026-10-10T04:00:00.000Z"}]}
        """
        let one = """
        {"id":"a","kind":"bug","title":"捐獻材料之後軟體直接關掉","status":"working","author":"jordan","mine":true,"votes":3,"voted":false,"createdAt":"2026-10-12T04:00:00.000Z",
        "body":"在公會頁按「捐獻」，選了木材之後按捐出，軟體就整個關掉了。\\n每次都會，重開之後貢獻有加上去。","device":"GoblinCamp Mac 1.2.3・macOS 26.3.0","admin":true,
        "thread":[{"id":"r1","author":"管理員小幫手","admin":true,"body":"收到，正在看。","status":"working","at":"2026-10-12T05:00:00.000Z"},
        {"id":"r2","author":"jordan","admin":false,"body":"補充：手機上捐不會這樣。","status":null,"at":"2026-10-12T06:00:00.000Z"}]}
        """
        list = try? APIClient.decoder.decode(List.self, from: Data(json.utf8))
        item = try? APIClient.decoder.decode(Detail.self, from: Data(one.utf8))
        nextStatus = item?.status ?? "open"
        screen = which == "detail" ? .detail : which == "writing" ? .writing : .list
        render()
    }

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
        var q: [String] = []
        if status != "active" && status != "all" { q.append("status=\(status)") }
        if !kind.isEmpty { q.append("kind=\(kind)") }
        if mine { q.append("mine=1") }
        if byVotes { q.append("sort=votes") }
        run { self.list = try await self.api.request("GET", "feedback?\(q.joined(separator: "&"))", as: List.self) }
    }

    private func open(_ id: String) {
        if item?.id != id {
            item = nil
            replyText.text.string = ""
        }
        screen = .detail
        run {
            let got = try await self.api.request("GET", "feedback/\(id)", as: Detail.self)
            self.item = got
            self.nextStatus = got.status
        }
    }

    private func back() {
        screen = .list
        problem = ""
        load()
    }

    private func sendNew() {
        struct Body: Encodable { let kind: String; let title: String; let body: String; let device: String }
        struct Made: Decodable { let id: String }
        let v = ProcessInfo.processInfo.operatingSystemVersion
        let app = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let body = Body(kind: newKind, title: titleField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines), body: bodyText.text.string,
                        device: "GoblinCamp Mac \(app)・macOS \(v.majorVersion).\(v.minorVersion).\(v.patchVersion)")
        run {
            let made = try await self.api.request("POST", "feedback", body: body, as: Made.self)
            self.titleField.stringValue = ""
            self.bodyText.text.string = ""
            self.open(made.id)
        }
    }

    /// An admin with a new status sends both at once (the text becomes the note on the change).
    private func sendReply() {
        guard let item else { return }
        let text = replyText.text.string.trimmingCharacters(in: .whitespacesAndNewlines)
        struct Status: Encodable { let status: String; let note: String? }
        struct Words: Encodable { let body: String }
        let changing = item.admin && nextStatus != item.status
        guard changing || !text.isEmpty else { return }
        let next = nextStatus
        run {
            let got = changing
                ? try await self.api.request("POST", "feedback/\(item.id)/status", body: Status(status: next, note: text.isEmpty ? nil : text), as: Detail.self)
                : try await self.api.request("POST", "feedback/\(item.id)/replies", body: Words(body: text), as: Detail.self)
            self.item = got
            self.nextStatus = got.status
            self.replyText.text.string = ""
        }
    }

    /// 我也遇到 / 我也想要, or taking it back.
    private func vote() {
        guard let item else { return }
        run { self.item = try await self.api.request(item.voted ? "DELETE" : "PUT", "feedback/\(item.id)/vote", as: Detail.self) }
    }

    private func remove() {
        guard let item else { return }
        struct Nothing: Decodable {}
        run {
            _ = try await self.api.request("DELETE", "feedback/\(item.id)", as: Nothing.self)
            self.item = nil
            self.back()
        }
    }

    // MARK: What shows

    private func render() {
        for v in stack.arrangedSubviews { stack.removeArrangedSubview(v); v.removeFromSuperview() }
        hintLabel = nil
        sendButton = nil
        popupHandlers = [:]
        handlers = []
        switch screen {
        case .list: renderList()
        case .detail: renderDetail()
        case .writing: renderWriting()
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
        title("回報", [GuildUI.button("＋ 回報", prominent: true) { [weak self] in
            self?.screen = .writing
            self?.problem = ""
            self?.render()
        }])
        add(words("遇到 bug、想到可以更好的地方、覺得哪裡太強太弱，都寫在這裡；大家看得到每一則處理到哪裡。", size: 12, color: .secondaryLabelColor))

        // the filters: where it stands (with how many), which kind, in what order, only one's own
        let counts = list?.counts ?? [:]
        let active = Self.statuses.filter { $0 != "done" && $0 != "declined" }.reduce(0) { $0 + (counts[$1] ?? 0) }
        let total = Self.statuses.reduce(0) { $0 + (counts[$1] ?? 0) }
        let statusIds = ["active"] + Self.statuses + ["all"]
        let statusPick = popup(statusIds.map { id in
            id == "active" ? "進行中 \(active)" : id == "all" ? "全部 \(total)" : "\(Self.statusLabel[id] ?? id) \(counts[id] ?? 0)"
        }, at: statusIds.firstIndex(of: status) ?? 0) { [weak self] i in
            self?.status = statusIds[i]
            self?.load()
        }
        let kindIds = [""] + Self.kinds
        let kindPick = popup(kindIds.map { $0.isEmpty ? "所有類型" : Self.kindLabel[$0] ?? $0 }, at: kindIds.firstIndex(of: kind) ?? 0) { [weak self] i in
            self?.kind = kindIds[i]
            self?.load()
        }
        let sortPick = popup(["最新動態", "最多人 +1"], at: byVotes ? 1 : 0) { [weak self] i in
            self?.byVotes = i == 1
            self?.load()
        }
        let own = ClosureButton(title: "只看我的") { [weak self] in
            guard let self else { return }
            self.mine.toggle()
            self.load()
        }
        own.setButtonType(.switch)
        own.state = mine ? .on : .off
        own.controlSize = .small
        add(GuildUI.row([statusPick, kindPick, sortPick, own]), fill: false)
        add(GuildUI.separator())

        if !problem.isEmpty { add(words(problem, color: .systemRed)) }
        guard let list else {
            if problem.isEmpty { add(words("讀取中…", color: .secondaryLabelColor)) }
            return
        }
        let items = list.items.filter { status != "active" || ($0.status != "done" && $0.status != "declined") }
        if items.isEmpty { add(words(mine ? "你還沒有這樣的回報。" : "這裡還沒有回報。", color: .secondaryLabelColor)) }
        for i in items {
            var tags = [tag(Self.kindLabel[i.kind] ?? i.kind, Self.kindColor[i.kind]), tag(Self.statusLabel[i.status] ?? i.status, Self.statusColor[i.status])]
            if i.mine { tags.append(tag("我的", GuildUI.gold, dark: true)) }
            let name = GuildUI.label(i.title, size: 13, bold: true)
            name.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            let under = GuildUI.note("\(i.author)・\(GuildUI.ago(i.updatedAt))\(i.replies > 0 ? "・💬 \(i.replies)" : "")")
            let left = NSStackView(views: [GuildUI.row(tags, spacing: 4), name, under])
            left.orientation = .vertical
            left.alignment = .leading
            left.spacing = 3
            let spacer = NSView()
            spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
            var parts: [NSView] = [left, spacer]
            if i.votes > 0 { parts.append(GuildUI.label("👍 \(i.votes)", size: 12, bold: i.voted, color: i.voted ? .labelColor : .secondaryLabelColor)) }
            parts.append(GuildUI.label("›", size: 16, color: .tertiaryLabelColor))
            let id = i.id
            add(ClickRow(GuildUI.row(parts)) { [weak self] in self?.open(id) }, gap: 2)
        }
    }

    private func renderDetail() {
        title("回報", [])
        add(GuildUI.button("‹ 所有回報") { [weak self] in self?.back() }, fill: false)
        guard let item else {
            add(words(problem.isEmpty ? "讀取中…" : problem, color: problem.isEmpty ? .secondaryLabelColor : .systemRed))
            return
        }
        add(GuildUI.row([tag(Self.kindLabel[item.kind] ?? item.kind, Self.kindColor[item.kind]), tag(Self.statusLabel[item.status] ?? item.status, Self.statusColor[item.status])], spacing: 4), fill: false)
        add(words(item.title, size: 17, bold: true), gap: 6)
        add(words("\(item.author)\(item.mine ? "（你）" : "")・\(GuildUI.ago(item.createdAt))", size: 12, color: .secondaryLabelColor), gap: 2)
        if !item.body.isEmpty { add(words(item.body)) }
        if let device = item.device, !device.isEmpty { add(words("裝置：\(device)", size: 11, color: .tertiaryLabelColor)) }

        // +1 (not on one's own), and how far along it is
        let label = Self.voteLabel[item.kind] ?? "+1"
        var voteRow: [NSView] = []
        if !item.mine {
            let b = GuildUI.button("👍 \(label)\(item.voted ? "（已 +1）" : "")", prominent: item.voted) { [weak self] in self?.vote() }
            b.isEnabled = !busy
            voteRow.append(b)
        }
        let said = item.votes > 0 ? "\(item.votes) 人\(label.dropFirst())" : item.mine ? "還沒有人 +1" : ""
        if !said.isEmpty { voteRow.append(GuildUI.note(said)) }
        if !voteRow.isEmpty { add(GuildUI.row(voteRow), fill: false) }
        let at = Self.statuses.firstIndex(of: item.status) ?? 0
        let steps = Self.statuses.filter { $0 != "declined" }.enumerated().map { i, s -> NSView in
            let on = s == item.status, past = i < at && item.status != "declined"
            return tag(Self.statusLabel[s] ?? s, on ? Self.statusColor[s] : NSColor(white: 0.5, alpha: past ? 0.45 : 0.18), dim: !on && !past)
        }
        add(GuildUI.row(steps, spacing: 4), fill: false)
        add(GuildUI.separator(), gap: 14)

        add(GuildUI.heading("回覆與進度"))
        if item.thread.isEmpty { add(GuildUI.note("還沒有回覆。")) }
        for r in item.thread {
            var who: [NSView] = [GuildUI.label(r.author, size: 12, bold: true)]
            if r.admin { who.append(tag("管理員", GuildUI.gold, dark: true)) }
            who.append(GuildUI.note(GuildUI.ago(r.at)))
            add(GuildUI.row(who, spacing: 6), fill: false, gap: 12)
            if let s = r.status { add(GuildUI.row([GuildUI.note("狀態改為"), tag(Self.statusLabel[s] ?? s, Self.statusColor[s])], spacing: 4), fill: false, gap: 3) }
            if !r.body.isEmpty { add(words(r.body), gap: 3) }
        }

        guard item.mine || item.admin else {
            add(GuildUI.note("只有回報的人和管理員能回覆。"), gap: 14)
            return
        }
        add(GuildUI.separator(), gap: 14)
        if item.admin {
            let pick = popup(Self.statuses.map { Self.statusLabel[$0] ?? $0 }, at: Self.statuses.firstIndex(of: nextStatus) ?? 0) { [weak self] i in
                guard let self else { return }
                self.nextStatus = Self.statuses[i]
                self.sendButton?.title = self.nextStatus != item.status ? "更新狀態" : "送出"
            }
            add(GuildUI.row([GuildUI.note("狀態"), pick]), fill: false)
            add(GuildUI.note("改狀態時，下面寫的會一起送出（可以留空）。"), gap: 3)
        } else {
            add(GuildUI.note("補充說明"))
        }
        add(replyText.box, gap: 4)
        replyText.box.heightAnchor.constraint(equalToConstant: 76).isActive = true
        if !problem.isEmpty { add(words(problem, color: .systemRed)) }
        let send = GuildUI.button(item.admin && nextStatus != item.status ? "更新狀態" : "送出", prominent: true) { [weak self] in self?.sendReply() }
        send.isEnabled = !busy
        sendButton = send
        var buttons: [NSView] = [send]
        // (the author takes it back while nobody has looked at it yet; an admin removes it any time)
        if item.admin || (item.mine && item.status == "open") {
            let del = GuildUI.sure("刪除這則回報") { [weak self] in self?.remove() }
            del.isEnabled = !busy
            buttons.append(del)
        }
        add(GuildUI.row(buttons), fill: false)
    }

    private func renderWriting() {
        title("回報問題或建議", [])
        let pick = NSSegmentedControl(labels: Self.kinds.map { Self.kindLabel[$0] ?? $0 }, trackingMode: .selectOne, target: nil, action: nil)
        pick.selectedSegment = Self.kinds.firstIndex(of: newKind) ?? 0
        let handler = FieldHandler { [weak self, weak pick] in
            guard let self, let pick else { return }
            self.newKind = Self.kinds[max(0, pick.selectedSegment)]
            self.hintLabel?.stringValue = Self.hint[self.newKind] ?? ""
        }
        pick.target = handler
        pick.action = #selector(FieldHandler.fire)
        handlers = [handler]
        add(pick, fill: false)
        add(GuildUI.note("標題"), gap: 14)
        add(titleField, gap: 3)
        add(GuildUI.note("詳細說明（選填）"), gap: 12)
        let hint = GuildUI.note(Self.hint[newKind] ?? "")
        hintLabel = hint
        add(hint, gap: 2)
        add(bodyText.box, gap: 4)
        bodyText.box.heightAnchor.constraint(equalToConstant: 130).isActive = true
        if !problem.isEmpty { add(words(problem, color: .systemRed)) }
        let send = GuildUI.button("送出", prominent: true) { [weak self] in
            guard let self else { return }
            guard self.titleField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2 else {
                self.problem = "標題至少要 2 個字。"
                return self.render()
            }
            self.sendNew()
        }
        send.isEnabled = !busy
        add(GuildUI.row([send, GuildUI.button("取消") { [weak self] in self?.back() }]), fill: false, gap: 12)
        add(GuildUI.note("所有人都看得到回報的標題和內容；管理員會更新處理狀態並回覆你。"), gap: 12)
    }

    // MARK: Pieces

    private var handlers: [FieldHandler] = []

    /// A small coloured word (the kind, the status, 我的, 管理員).
    private func tag(_ text: String, _ color: NSColor?, dark: Bool = false, dim: Bool = false) -> NSView {
        let l = NSTextField(labelWithString: text)
        l.font = .systemFont(ofSize: 10, weight: .semibold)
        l.textColor = dark ? NSColor(calibratedRed: 0.17, green: 0.11, blue: 0, alpha: 1) : dim ? .secondaryLabelColor : .white
        l.translatesAutoresizingMaskIntoConstraints = false
        let box = NSView()
        box.wantsLayer = true
        box.layer?.cornerRadius = 4
        box.layer?.backgroundColor = (color ?? NSColor(white: 0.45, alpha: 1)).cgColor
        box.addSubview(l)
        NSLayoutConstraint.activate([
            l.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: 5), l.trailingAnchor.constraint(equalTo: box.trailingAnchor, constant: -5),
            l.topAnchor.constraint(equalTo: box.topAnchor, constant: 1), l.bottomAnchor.constraint(equalTo: box.bottomAnchor, constant: -2),
        ])
        box.setContentHuggingPriority(.required, for: .horizontal)
        return box
    }

    private func popup(_ titles: [String], at index: Int, _ picked: @escaping (Int) -> Void) -> NSPopUpButton {
        let p = NSPopUpButton()
        p.controlSize = .small
        p.font = .systemFont(ofSize: NSFont.smallSystemFontSize)
        p.addItems(withTitles: titles)
        p.selectItem(at: index)
        let handler = FieldHandler { [weak p] in if let p { picked(p.indexOfSelectedItem) } }
        p.target = handler
        p.action = #selector(FieldHandler.fire)
        popupHandlers[ObjectIdentifier(p)] = handler
        return p
    }
    /// (a control does not keep its target: these last as long as the page that is showing)
    private var popupHandlers: [ObjectIdentifier: FieldHandler] = [:]

    /// A box to write several lines in.
    private static func textBox() -> (box: NSScrollView, text: NSTextView) {
        let box = NSTextView.scrollableTextView()
        let text = box.documentView as! NSTextView
        text.font = .systemFont(ofSize: 13)
        text.isRichText = false
        text.textContainerInset = NSSize(width: 4, height: 6)
        text.allowsUndo = true
        box.borderType = .bezelBorder
        box.hasVerticalScroller = true
        return (box, text)
    }
}

/// A row of a list that is clicked as a whole: it lights up under the pointer.
final class ClickRow: NSView {
    private let action: () -> Void
    private var tracking: NSTrackingArea?

    init(_ content: NSView, action: @escaping () -> Void) {
        self.action = action
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 8
        content.translatesAutoresizingMaskIntoConstraints = false
        addSubview(content)
        NSLayoutConstraint.activate([
            content.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8), content.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
            content.topAnchor.constraint(equalTo: topAnchor, constant: 7), content.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -7),
        ])
    }
    required init?(coder: NSCoder) { fatalError() }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking { removeTrackingArea(tracking) }
        tracking = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeInKeyWindow], owner: self)
        addTrackingArea(tracking!)
    }
    override func mouseEntered(with event: NSEvent) { layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(0.08).cgColor }
    override func mouseExited(with event: NSEvent) { layer?.backgroundColor = nil }
    override func mouseUp(with event: NSEvent) {
        if bounds.contains(convert(event.locationInWindow, from: nil)) { action() }
    }
    /// (the labels inside do not take the click)
    override func hitTest(_ point: NSPoint) -> NSView? { super.hitTest(point) == nil ? nil : self }
    override func resetCursorRects() { addCursorRect(bounds, cursor: .pointingHand) }
}
