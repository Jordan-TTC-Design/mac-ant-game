import AppKit

/// What the panels need of the guild page.
struct GuildContext {
    let api: APIClient
    let info: () -> GuildInfo?
    let me: () -> String?
    /// The server's new news about the guild (from a change this made).
    let apply: (GuildInfo) -> Void
    let reload: () -> Void
    let notify: (String) -> Void
    let close: () -> Void
}

/// A panel's controller: the view, and a way to look at the guild again after it changed.
protocol GuildPanelController: AnyObject {
    var view: GuildPanel { get }
    func guildChanged()
}

/// Panels that are made from the page's context.
protocol GuildPanelInit {
    init(_ ctx: GuildContext)
}

private func roleName(_ role: String) -> String { role == "leader" ? "會長" : role == "officer" ? "幹部" : "成員" }

extension GuildContext {
    /// Does something with the server, says what it said if it failed, and looks at the guild again.
    func run(_ work: @escaping () async throws -> Void, done: String? = nil, then: (() -> Void)? = nil) {
        Task { @MainActor in
            do {
                try await work()
                if let done { self.notify(done) }
                then?()
            } catch {
                self.notify(error.localizedDescription)
            }
        }
    }
}

// MARK: 捐獻

/// 捐獻 (GUILD.md §4.1): camp materials given to the guild, each worth contribution; enough of it raises the level.
final class GuildDonatePanel: GuildPanelController, GuildPanelInit {
    let view: GuildPanel
    private let ctx: GuildContext
    private var have: [String: Int] = [:]
    private var ledger: Ledger?
    private var give: [String: Int] = [:]
    private var busy = false
    private var fields: [String: NSTextField] = [:]
    private let totalLabel = NSTextField(labelWithString: "")
    private var donateButton: ClosureButton?

    struct Ledger: Decodable {
        struct Who: Decodable { let id: String; let name: String; let points: Int }
        struct Gift: Decodable { let name: String; let materials: [String: Int]; let points: Int; let at: String }
        let members: [Who]
        let recent: [Gift]
    }

    /// The contribution a guild needs in all to be each level (shared/src/guild.ts GUILD_LEVEL_POINTS).
    static let levelPoints = [0, 3000, 9000, 20000, 40000, 70000, 120000]
    private static let rare: Set<String> = ["shiny_bead", "golden_fur", "night_heart", "golden_frog_eye", "alpha_mane", "shaman_charm", "cursed_steel", "captain_badge", "queen_silk",
                                            "heartwood", "naiad_tear", "river_pearl", "rat_crown", "royal_jelly", "golem_core", "vampire_fang", "rabbit_foot", "amber"]

    /// What one of a material is worth to the guild (shared/src/guild.ts donationPoints; 0: not something that can be given).
    static func worth(_ id: String) -> Int {
        guard Materials.info(id) != nil else { return 0 }
        if id == "log" || id == "stone" { return 1 }
        if id.hasPrefix("scrap_") { return 2 }
        if id.hasPrefix("ration_") || id.hasPrefix("food_") { return 3 }
        if id == "crystal_shard" { return 5 }
        return rare.contains(id) ? 30 : 4
    }

    init(_ ctx: GuildContext) {
        self.ctx = ctx
        view = GuildPanel(title: "捐獻", sub: "營地的材料捐給公會，累積貢獻讓公會升級", close: ctx.close)
        load()
        render()
    }

    func guildChanged() { render() }

    private func load() {
        struct Camp: Decodable { let materials: [String: Int] }
        Task { @MainActor in
            self.have = (try? await self.ctx.api.request("GET", "camp", as: Camp.self))?.materials ?? [:]
            self.ledger = try? await self.ctx.api.request("GET", "guild/donations", as: Ledger.self)
            self.render()
        }
    }

    private func total() -> Int { give.reduce(0) { $0 + Self.worth($1.key) * $1.value } }

    private func updateTotal() {
        totalLabel.stringValue = "共 \(total()) 貢獻"
        donateButton?.isEnabled = !busy && total() > 0
    }

    private func render() {
        let inner = view.inner
        guard let g = ctx.info()?.guild else { return }
        var out: [NSView] = []
        // where the guild stands
        let from = Self.levelPoints[g.level - 1], to = g.level < Self.levelPoints.count ? Self.levelPoints[g.level] : nil
        let bar = NSProgressIndicator()
        bar.style = .bar
        bar.isIndeterminate = false
        bar.minValue = 0
        bar.maxValue = 1
        bar.doubleValue = to.map { Double(g.points - from) / Double($0 - from) } ?? 1
        bar.translatesAutoresizingMaskIntoConstraints = false
        bar.widthAnchor.constraint(equalToConstant: inner).isActive = true
        out.append(GuildUI.row([GuildUI.label("\(g.name)・Lv \(g.level)", size: 13, bold: true), GuildUI.note(g.toNext.map { "再 \($0) 貢獻升 \(g.level + 1) 級" } ?? "已經是最高級了")]))
        out.append(bar)
        out.append(GuildUI.note("累積 \(g.points) 貢獻。升級後可以收更多人、據點變大、裝飾點數變多。", width: inner))

        out.append(GuildUI.separator())
        out.append(GuildUI.heading("我的營地材料"))
        let rows = have.filter { $0.value > 0 && Self.worth($0.key) > 0 }.sorted { Self.worth($0.key) != Self.worth($1.key) ? Self.worth($0.key) > Self.worth($1.key) : $0.value > $1.value }
        fields = [:]
        if rows.isEmpty { out.append(GuildUI.note("營地裡還沒有可以捐的材料。", width: inner)) }
        for (id, n) in rows {
            let info = Materials.info(id)
            let gem = NSView()
            gem.wantsLayer = true
            gem.layer?.backgroundColor = (info?.color ?? .gray).cgColor
            gem.layer?.cornerRadius = 4
            gem.translatesAutoresizingMaskIntoConstraints = false
            gem.widthAnchor.constraint(equalToConstant: 14).isActive = true
            gem.heightAnchor.constraint(equalToConstant: 14).isActive = true
            let name = GuildUI.label("\(info?.name ?? id)  有 \(n)・每個 \(Self.worth(id))", size: 12)
            name.lineBreakMode = .byTruncatingTail
            name.setContentHuggingPriority(.defaultLow, for: .horizontal)
            let field = NSTextField(string: give[id].map(String.init) ?? "")
            field.placeholderString = "0"
            field.alignment = .right
            field.controlSize = .small
            field.translatesAutoresizingMaskIntoConstraints = false
            field.widthAnchor.constraint(equalToConstant: 56).isActive = true
            // (the total follows each key, not only Return or leaving the field; the box is tidied when one leaves it)
            let handler = FieldHandler { [weak self, weak field] in
                guard let self, let field else { return }
                let v = max(0, min(n, Int(field.stringValue.trimmingCharacters(in: .whitespaces)) ?? 0))
                self.give[id] = v == 0 ? nil : v
                self.updateTotal()
            }
            handler.onEnd = { [weak self, weak field] in
                guard let self, let field else { return }
                let v = self.give[id] ?? 0
                field.stringValue = v == 0 ? "" : String(v)
            }
            field.delegate = handler
            field.target = handler
            field.action = #selector(FieldHandler.fire)
            objc_setAssociatedObject(field, "handler", handler, .OBJC_ASSOCIATION_RETAIN)
            fields[id] = field
            let all = GuildUI.button("全部") { [weak self] in
                self?.give[id] = n
                field.stringValue = String(n)
                self?.updateTotal()
            }
            out.append(GuildUI.row([gem, name, field, all], spacing: 6))
        }
        if !rows.isEmpty {
            let b = GuildUI.button("捐出", prominent: true) { [weak self] in self?.donate() }
            donateButton = b
            totalLabel.font = .boldSystemFont(ofSize: 12)
            out.append(GuildUI.row([totalLabel, NSView(), b]))
            updateTotal()
        }

        if let ledger {
            out.append(GuildUI.separator())
            out.append(GuildUI.heading("公會帳本"))
            for m in ledger.members { out.append(GuildUI.row([GuildUI.label(m.name), NSView(), GuildUI.label("\(m.points)", bold: true)])) }
            out.append(GuildUI.heading("最近的捐獻"))
            if ledger.recent.isEmpty { out.append(GuildUI.note("還沒有人捐過。", width: inner)) }
            for r in ledger.recent {
                let what = r.materials.map { "\(Materials.info($0.key)?.name ?? $0.key)×\($0.value)" }.joined(separator: "、")
                out.append(GuildUI.label("\(r.name) 捐了 \(what)（+\(r.points)）・\(GuildUI.ago(r.at))", size: 11, width: inner))
            }
        }
        view.show(out)
    }

    private func donate() {
        let materials = give.filter { $0.value > 0 }
        guard !materials.isEmpty, !busy else { return }
        busy = true
        updateTotal()
        struct Body: Encodable { let materials: [String: Int] }
        struct Out: Decodable { let message: String; let guild: GuildInfo }
        ctx.run({
            defer { self.busy = false }
            let out = try await self.ctx.api.request("POST", "guild/donate", body: Body(materials: materials), as: Out.self)
            self.give = [:]
            self.ctx.apply(out.guild)
            self.ctx.notify(out.message)
            self.load()
        })
    }
}

/// Calls back when a text field changes (each key), is sent (Return), or is left.
final class FieldHandler: NSObject, NSTextFieldDelegate {
    private let body: () -> Void
    var onEnd: (() -> Void)?
    init(_ body: @escaping () -> Void) { self.body = body }
    @objc func fire() { body() }
    func controlTextDidChange(_ obj: Notification) { body() }
    func controlTextDidEndEditing(_ obj: Notification) {
        body()
        onEnd?()
    }
}

// MARK: 成員

/// 公會成員 (GUILD.md): who is in and how each one is; the leader and officers invite and send people away, the leader sets
/// roles and hands over the lead; anyone may leave.
final class GuildMembersPanel: GuildPanelController, GuildPanelInit {
    let view: GuildPanel
    private let ctx: GuildContext
    private var friends: [Friend] = []
    private let codeField = NSTextField()

    struct Friend: Decodable { let id: String; let name: String; let race: String }

    init(_ ctx: GuildContext) {
        self.ctx = ctx
        view = GuildPanel(title: "公會成員", close: ctx.close)
        struct Friends: Decodable { let friends: [Friend] }
        Task { @MainActor in
            self.friends = (try? await ctx.api.request("GET", "friends", as: Friends.self))?.friends ?? []
            self.render()
        }
        render()
    }

    func guildChanged() { render() }

    private func presenceText(_ m: GuildInfo.Member) -> String {
        let now = Date()
        var state = m.presence
        if state != "offline" {
            let seen = m.seenAt.flatMap { ISO8601DateFormatter.guild.date(from: $0) }
            if seen.map({ now.timeIntervalSince($0) > GuildTiming.presenceTTL }) ?? true { state = "offline" }
        }
        switch state {
        case "focus": return "🔴 專注中"
        case "online": return "🟢 在線"
        case "away": return "🟡 離開中"
        default: return "⚪️ 離線" + (m.seenAt.map { "・\(GuildUI.ago($0))來過" } ?? "")
        }
    }

    private func render() {
        guard let g = ctx.info()?.guild else { return }
        let inner = view.inner
        let me = ctx.me()
        let role = g.members.first { $0.id == me }?.role ?? "member"
        view.setSub("\(g.name)・\(g.members.count)／\(g.rules.members) 人")
        var out: [NSView] = []
        for m in g.members {
            let name = GuildUI.label("\(m.name)  \(roleName(m.role))", size: 12, bold: true)
            let line2 = GuildUI.note(presenceText(m) + (m.focusToday > 0 ? "・今天專注 \(m.focusToday) 輪" : ""), width: inner - 50)
            let text = NSStackView(views: [name, line2])
            text.orientation = .vertical
            text.alignment = .leading
            text.spacing = 1
            var acts: [NSView] = []
            if m.id != me, role == "leader" {
                if m.role == "member" { acts.append(GuildUI.button("升幹部") { [weak self] in self?.setRole(m, "officer") }) }
                if m.role == "officer" { acts.append(GuildUI.button("降成員") { [weak self] in self?.setRole(m, "member") }) }
                acts.append(GuildUI.sure("交會長") { [weak self] in self?.setRole(m, "leader") })
                acts.append(GuildUI.sure("請離開") { [weak self] in self?.kick(m) })
            } else if m.id != me, role == "officer", m.role == "member" {
                acts.append(GuildUI.sure("請離開") { [weak self] in self?.kick(m) })
            }
            out.append(GuildUI.row([GuildUI.face(m.avatar), text]))
            if !acts.isEmpty { out.append(GuildUI.row([NSView()] + acts, spacing: 4)) }
        }

        if role != "member" {
            out.append(GuildUI.separator())
            out.append(GuildUI.heading("邀請"))
            let taken = Set(g.members.map(\.id) + g.invited.map(\.id))
            let full = g.members.count >= g.rules.members
            let ask = friends.filter { !taken.contains($0.id) }
            for f in ask {
                let b = GuildUI.button("邀請", prominent: true) { [weak self] in self?.invite(["userId": f.id], note: "邀請了\(f.name)，等對方答應。") }
                b.isEnabled = !full
                out.append(GuildUI.row([GuildUI.label(f.name, bold: true), GuildUI.note("好友"), NSView(), b]))
            }
            if ask.isEmpty { out.append(GuildUI.note("好友都邀過了（或還沒有好友）。也可以輸入對方的好友代碼：", width: inner)) }
            codeField.placeholderString = "對方的好友代碼"
            codeField.controlSize = .small
            let send = GuildUI.button("邀請", prominent: true) { [weak self] in
                guard let self else { return }
                let code = self.codeField.stringValue.trimmingCharacters(in: .whitespaces)
                guard !code.isEmpty else { return }
                self.invite(["code": code], note: "邀請送出了，等對方答應。") { self.codeField.stringValue = "" }
            }
            send.isEnabled = !full
            codeField.setContentHuggingPriority(.defaultLow, for: .horizontal)
            out.append(GuildUI.row([codeField, send]))
            if full { out.append(GuildUI.note("公會滿了，升級後可以收更多人。", width: inner)) }
            for p in g.invited {
                out.append(GuildUI.row([GuildUI.label(p.name, bold: true), GuildUI.note("等對方答應・\(GuildUI.ago(p.at))"), NSView(),
                                        GuildUI.button("收回") { [weak self] in self?.uninvite(p.id) }]))
            }
        }

        out.append(GuildUI.separator())
        let last = g.members.count == 1
        out.append(GuildUI.row([GuildUI.sure("離開公會") { [weak self] in self?.leave() }, GuildUI.note(last ? "你是最後一個人，離開後公會就解散了。" : "離開後要等 24 小時才能加入別的公會。", width: inner - 100)]))
        view.show(out)
    }

    private func invite(_ body: [String: String], note: String, then: (() -> Void)? = nil) {
        ctx.run({ try await self.ctx.api.raw("POST", "guild/invites", body: body) }, done: note, then: { then?(); self.ctx.reload() })
    }

    private func uninvite(_ id: String) {
        ctx.run({ try await self.ctx.api.raw("DELETE", "guild/invites/\(id)") }, then: ctx.reload)
    }

    private func setRole(_ m: GuildInfo.Member, _ to: String) {
        ctx.run({ try await self.ctx.api.raw("PUT", "guild/members/\(m.id)/role", body: ["role": to]) }, then: ctx.reload)
    }

    private func kick(_ m: GuildInfo.Member) {
        ctx.run({ try await self.ctx.api.raw("DELETE", "guild/members/\(m.id)") }, done: "\(m.name) 離開了公會。", then: ctx.reload)
    }

    private func leave() {
        ctx.run({ try await self.ctx.api.raw("POST", "guild/leave") }, done: "離開了公會。", then: { self.ctx.close(); self.ctx.reload() })
    }
}

// MARK: 設定

/// 公會設定 (GUILD.md): the leader renames the guild and draws its badge; the leader and officers see who changed the hall and
/// the leader can put it back as it was before a change.
final class GuildSettingsPanel: GuildPanelController, GuildPanelInit {
    let view: GuildPanel
    private let ctx: GuildContext
    private var log: [Entry] = []
    private let nameField = NSTextField()
    private var badge = ""
    private var editor: BadgeEditorView?
    private var drawn = false

    struct Entry: Decodable {
        let id: String
        let by: String
        let at: String
        let added: Int
        let moved: Int
        let removed: Int
        let restored: Bool
        let floor: Int
    }

    init(_ ctx: GuildContext) {
        self.ctx = ctx
        view = GuildPanel(title: "公會設定", close: ctx.close)
        if let g = ctx.info()?.guild {
            nameField.stringValue = g.name
            badge = g.badge
        }
        loadLog()
        render()
    }

    func guildChanged() {
        // (the form keeps what is being typed; only the list is looked at again)
        render()
    }

    private func loadLog() {
        struct Entries: Decodable { let entries: [Entry] }
        Task { @MainActor in
            self.log = (try? await self.ctx.api.request("GET", "guild/decor/log", as: Entries.self))?.entries ?? []
            self.render()
        }
    }

    private func line(_ e: Entry) -> String {
        if e.restored { return "還原了裝飾" }
        return [e.added > 0 ? "放了 \(e.added) 件" : nil, e.moved > 0 ? "動了 \(e.moved) 件" : nil, e.removed > 0 ? "收了 \(e.removed) 件" : nil, e.floor > 0 ? "鋪了 \(e.floor) 格地板" : nil]
            .compactMap { $0 }.joined(separator: "、")
    }

    private func render() {
        guard let g = ctx.info()?.guild else { return }
        let inner = view.inner
        let role = g.members.first { $0.id == ctx.me() }?.role ?? "member"
        view.setSub(g.name)
        var out: [NSView] = []
        if role == "member" { out.append(GuildUI.note("這一頁是會長和幹部用的。", width: inner)) }
        if role == "leader" {
            out.append(GuildUI.heading("公會名字"))
            nameField.controlSize = .small
            nameField.setContentHuggingPriority(.defaultLow, for: .horizontal)
            out.append(GuildUI.row([nameField, GuildUI.button("改名", prominent: true) { [weak self] in
                guard let self else { return }
                let name = self.nameField.stringValue.trimmingCharacters(in: .whitespaces)
                guard name.count >= 2, name != g.name else { return }
                self.patch(["name": name], "名字改好了。")
            }]))
            out.append(GuildUI.separator())
            out.append(GuildUI.heading("公會徽章"))
            if editor == nil {
                let e = BadgeEditorView(badge)
                e.onChange = { [weak self] b in self?.badge = b }
                editor = e
            }
            out.append(editor!)
            out.append(GuildUI.button("儲存徽章", prominent: true) { [weak self] in
                guard let self else { return }
                self.patch(["badge": self.badge], "徽章換好了。")
            })
        }
        if role != "member" {
            out.append(GuildUI.separator())
            out.append(GuildUI.heading("擺放紀錄"))
            out.append(GuildUI.note("誰在什麼時候動了據點的裝飾和地板（留 7 天）。" + (role == "leader" ? "可以還原到某一次改動之前。" : ""), width: inner))
            if log.isEmpty { out.append(GuildUI.note("還沒有人動過裝飾。", width: inner)) }
            for e in log {
                let text = GuildUI.label("\(e.by) \(line(e))\n\(GuildUI.ago(e.at))", size: 11)
                text.setContentHuggingPriority(.defaultLow, for: .horizontal)
                var row: [NSView] = [text]
                if role == "leader" { row.append(GuildUI.sure("還原到這之前") { [weak self] in self?.restore(e) }) }
                out.append(GuildUI.row(row))
            }
        }
        view.show(out)
    }

    private func patch(_ body: [String: String], _ done: String) {
        ctx.run({
            let got = try await self.ctx.api.request("PATCH", "guild", body: body, as: GuildInfo.self)
            self.ctx.apply(got)
        }, done: done)
    }

    private func restore(_ e: Entry) {
        struct Body: Encodable { let logId: String }
        ctx.run({
            let got = try await self.ctx.api.request("POST", "guild/decor/restore", body: Body(logId: e.id), as: GuildInfo.self)
            self.ctx.apply(got)
            self.loadLog()
        }, done: "還原了。")
    }
}

// MARK: 建立或加入公會

/// No guild yet: the invitations there are, and founding one (the founder leads it).
final class GuildFoundPanel: GuildPanelController, GuildPanelInit {
    let view: GuildPanel
    private let ctx: GuildContext
    private let nameField = NSTextField()
    private var badge = GuildBadgeArt.standard
    private var editor: BadgeEditorView?
    private var drawing = false

    init(_ ctx: GuildContext) {
        self.ctx = ctx
        view = GuildPanel(title: "公會", sub: "和同事組公會，據點裡看得到誰在電腦前", close: ctx.close)
        render()
    }

    func guildChanged() { render() }

    private func render() {
        guard let info = ctx.info() else { return }
        let inner = view.inner
        var out: [NSView] = []
        if !info.invites.isEmpty {
            out.append(GuildUI.heading("公會邀請"))
            for i in info.invites {
                let text = NSStackView(views: [GuildUI.label(i.name, size: 12, bold: true), GuildUI.note("\(i.members) 人・\(i.by) 邀請・\(GuildUI.ago(i.at))", width: inner - 190)])
                text.orientation = .vertical
                text.alignment = .leading
                text.spacing = 1
                let join = GuildUI.button("加入", prominent: true) { [weak self] in self?.join(i.guildId) }
                join.isEnabled = info.waitUntil == nil
                out.append(GuildUI.row([BadgeView(i.badge, size: 36), text, NSView(), join, GuildUI.button("不要") { [weak self] in self?.decline(i.guildId) }]))
            }
            out.append(GuildUI.separator())
        }
        out.append(GuildUI.heading("建立公會"))
        if let until = info.waitUntil, let at = ISO8601DateFormatter.guild.date(from: until), at > Date() {
            out.append(GuildUI.note("剛離開公會，\(GuildUI.ago(until))後才能加入或建立新的。", width: inner))
        }
        nameField.placeholderString = "公會名字（2～16 個字）"
        nameField.controlSize = .small
        out.append(nameField)
        nameField.translatesAutoresizingMaskIntoConstraints = false
        nameField.widthAnchor.constraint(equalToConstant: inner).isActive = true
        out.append(GuildUI.row([BadgeView(badge, size: 56), GuildUI.button(drawing ? "收起" : "畫徽章") { [weak self] in
            self?.drawing.toggle()
            self?.render()
        }]))
        if drawing {
            if editor == nil {
                let e = BadgeEditorView(badge)
                e.onChange = { [weak self] b in self?.badge = b }
                editor = e
            }
            out.append(editor!)
        }
        let found = GuildUI.button("建立（你會是會長）", prominent: true) { [weak self] in self?.found() }
        found.isEnabled = info.waitUntil == nil
        out.append(found)
        out.append(GuildUI.note("加入公會要靠邀請：請會長或幹部用你的好友代碼邀請你。", width: inner))
        view.show(out)
    }

    private func found() {
        let name = nameField.stringValue.trimmingCharacters(in: .whitespaces)
        guard name.count >= 2 else {
            ctx.notify("公會名字要 2～16 個字。")
            return
        }
        struct Body: Encodable { let name: String; let badge: String }
        ctx.run({
            let got = try await self.ctx.api.request("POST", "guild", body: Body(name: name, badge: self.badge), as: GuildInfo.self)
            self.ctx.apply(got)
            self.ctx.close()
        }, done: "公會建立了！")
    }

    private func join(_ id: String) {
        ctx.run({
            let got = try await self.ctx.api.request("POST", "guild/join/\(id)", as: GuildInfo.self)
            self.ctx.apply(got)
            self.ctx.close()
        }, done: "加入了！")
    }

    private func decline(_ id: String) {
        ctx.run({ try await self.ctx.api.raw("DELETE", "guild/join/\(id)") }, then: ctx.reload)
    }
}
