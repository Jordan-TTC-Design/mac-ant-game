import AppKit

/// What an avatar may be put together from (shared/src/guild.ts: AVATAR_OPTIONS, avatarOptions, defaultAvatar, randomAvatar).
enum AvatarKit {
    static let faces = ["round", "pointed", "square"]
    static let eyes = ["round", "narrow", "sparkle", "dot", "sleepy", "sharp", "lashes", "wide"]
    static let brows = ["thin", "thick", "faint", "none"]
    static let hairColors = ["black", "darkbrown", "chestnut", "orange", "yellow", "blonde", "silver", "pink", "lavender", "mint", "navy", "forest"]
    private static let mouths = ["line", "smile", "smirk", "open", "pout", "cat"]
    private static let skullMouths = ["teeth", "grin", "gap", "jaw", "fang", "stitch"]
    private static let spiritSkins = ["pale_blue", "ice", "pale_violet", "lavender"]

    struct Options { let hair: [String]; let skin: [String]; let mouth: [String]; let flame: [String] }

    static func options(_ race: String, _ sex: String) -> Options {
        let m = sex == "m"
        switch race {
        case "elf":
            return Options(hair: m ? ["neat", "long", "halfup", "ponytail", "side_braid", "waves", "messy", "braided_crown"]
                                   : ["long_wreath", "braided_crown", "side_braid", "waves", "long", "ponytail", "halfup", "wreath_updo"],
                           skin: ["fair", "warm", "tan", "bronze"], mouth: mouths, flame: [])
        case "undead":
            return Options(hair: m ? ["hood", "bare", "crack", "horns", "long_horns", "ragged_hood", "bone_crown", "candle"]
                                   : ["drift", "flame", "mist", "wisp_twins", "glass_short", "long_wave", "side_wisp", "flame_crown"],
                           skin: m ? ["bone", "ivory", "ash", "slate"] : spiritSkins, mouth: m ? skullMouths : mouths, flame: m ? ["cyan", "violet", "green", "orange"] : [])
        default:
            return Options(hair: m ? ["tuft", "mohawk", "topknot", "bald_ring", "dreads", "wild", "bun", "spikes"]
                                   : ["braids", "bun", "dreads", "wild", "tuft", "pigtails", "mohawk", "bob"],
                           skin: ["light", "grass", "moss", "deep"], mouth: mouths, flame: [])
        }
    }

    static let labels: [String: String] = [
        "round": "圓", "pointed": "尖", "square": "方",
        "narrow": "細長", "sparkle": "大閃", "dot": "豆豆", "sleepy": "睏睏", "sharp": "銳利", "lashes": "長睫毛", "wide": "圓睜",
        "thin": "細眉", "thick": "粗眉", "faint": "淡眉", "none": "無眉",
        "line": "一字", "smile": "微笑", "smirk": "歪嘴笑", "open": "張嘴", "pout": "嘟嘴", "cat": "貓嘴",
        "teeth": "一排牙", "grin": "咧嘴", "gap": "缺牙", "jaw": "下巴骨", "fang": "尖牙", "stitch": "縫線",
        "tuft": "亂翹一撮", "mohawk": "莫霍克", "topknot": "沖天辮", "bald_ring": "光頭加耳環", "dreads": "髒辮", "wild": "狂野亂髮", "bun": "頭頂小髻", "spikes": "刺刺頭",
        "braids": "雙麻花", "pigtails": "雙馬尾", "bob": "短鮑伯",
        "neat": "短俐落", "long": "長直髮", "halfup": "半紮", "ponytail": "長馬尾", "side_braid": "側編辮", "waves": "及腰波浪", "messy": "蓬鬆", "braided_crown": "編髮頭冠",
        "long_wreath": "長直髮・花冠", "wreath_updo": "花環盤髮",
        "hood": "兜帽", "bare": "光頭骨", "crack": "頭骨裂痕", "horns": "小角", "long_horns": "長角", "ragged_hood": "破兜帽", "bone_crown": "骨冠", "candle": "頭頂蠟燭",
        "drift": "飄散的靈髮", "flame": "火焰髮", "mist": "霧狀長髮", "wisp_twins": "雙馬尾鬼火", "glass_short": "半透明短髮", "long_wave": "長波浪", "side_wisp": "側邊靈絲", "flame_crown": "火焰冠",
        "light": "淺綠", "grass": "草綠", "moss": "苔綠", "deep": "深綠",
        "fair": "白皙", "warm": "暖膚", "tan": "小麥", "bronze": "古銅",
        "bone": "骨白", "ivory": "象牙", "ash": "灰骨", "slate": "石灰",
        "pale_blue": "淡藍", "ice": "冰藍", "pale_violet": "淡紫", "lavender": "薰衣草",
        "black": "黑", "darkbrown": "深棕", "chestnut": "栗色", "orange": "橘紅", "yellow": "蜜黃", "blonde": "淡金", "silver": "銀白", "pink": "粉紅", "mint": "薄荷", "navy": "深藍", "forest": "森綠",
        "cyan": "青", "violet": "紫", "green": "綠",
    ]

    /// The approved look of each race's two avatars.
    static func standard(_ race: String, _ sex: String) -> GuildInfo.Avatar {
        let r = ["goblin", "elf", "undead"].contains(race) ? race : "goblin"
        let o = options(r, sex)
        var a = GuildInfo.Avatar(race: r, sex: sex, face: "round", eyes: "round", brows: "none", mouth: o.mouth[0], hair: o.hair[0], hairColor: "black", skin: o.skin[0], flame: o.flame.first)
        switch r + sex {
        case "goblinm": a.hairColor = "darkbrown"; a.skin = "grass"; a.brows = "faint"
        case "goblinf": a.hairColor = "orange"; a.skin = "grass"; a.eyes = "lashes"
        case "elfm": a.hairColor = "chestnut"; a.skin = "fair"
        case "elff": a.hairColor = "blonde"; a.skin = "fair"; a.eyes = "lashes"
        case "undeadm": a.hairColor = "black"; a.skin = "bone"; a.flame = "cyan"
        default: a.hairColor = "mint"; a.skin = "pale_blue"; a.eyes = "lashes"
        }
        return a
    }

    /// Hair colours that go badly with a skin, left out when choosing at random.
    private static let clashes: [String: [String]] = ["grass": ["forest", "mint"], "moss": ["forest", "mint"], "deep": ["forest", "navy", "black"], "light": ["mint"], "pale_blue": ["navy"], "ice": ["mint", "navy"]]

    /// Every part chosen at random; `only` names the one part to change (the rest stay as `from` has them).
    static func random(_ race: String, _ sex: String, from: GuildInfo.Avatar? = nil, only part: String? = nil) -> GuildInfo.Avatar {
        let base = standard(race, sex)
        let o = options(base.race, sex)
        let skin = o.skin.randomElement()!
        var out = base
        out.face = faces.randomElement()!
        out.eyes = eyes.randomElement()!
        out.brows = brows.randomElement()!
        out.mouth = o.mouth.randomElement()!
        out.hair = o.hair.randomElement()!
        out.skin = skin
        out.hairColor = hairColors.filter { !(clashes[skin] ?? []).contains($0) }.randomElement()!
        out.flame = o.flame.randomElement()
        guard let from, let part, from.race == out.race, from.sex == out.sex else { return out }
        var kept = from
        switch part {
        case "face": kept.face = out.face
        case "eyes": kept.eyes = out.eyes
        case "brows": kept.brows = out.brows
        case "mouth": kept.mouth = out.mouth
        case "hair": kept.hair = out.hair
        case "hairColor": kept.hairColor = out.hairColor
        case "skin": kept.skin = out.skin
        case "flame": kept.flame = out.flame
        default: break
        }
        return kept
    }
}

/// The avatar, big, doing one of its moves (the maker's preview).
final class AvatarPreview: NSView {
    var avatar: GuildInfo.Avatar { didSet { needsDisplay = true } }
    var anim = "idle" { didSet { began = Date() } }
    private var began = Date()
    private var timer: Timer?

    init(_ avatar: GuildInfo.Avatar) {
        self.avatar = avatar
        super.init(frame: NSRect(x: 0, y: 0, width: 240, height: 250))
        translatesAutoresizingMaskIntoConstraints = false
        widthAnchor.constraint(equalToConstant: 240).isActive = true
        heightAnchor.constraint(equalToConstant: 250).isActive = true
    }

    required init?(coder: NSCoder) { fatalError() }

    override var isFlipped: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        timer?.invalidate()
        guard window != nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 20, repeats: true) { [weak self] _ in self?.needsDisplay = true }
        RunLoop.main.add(timer!, forMode: .common)
    }

    override func draw(_ dirtyRect: NSRect) {
        let card = NSBezierPath(roundedRect: bounds, xRadius: 12, yRadius: 12)
        NSColor(calibratedRed: 0.91, green: 0.86, blue: 0.75, alpha: 1).setFill()
        card.fill()
        let art = GuildArt.shared
        let t = Date().timeIntervalSince(began)
        guard let img = art.avatarFrame(avatar, art.frameIndex(anim: anim, dir: "front", t: t)), let g = NSGraphicsContext.current?.cgContext else { return }
        let scale: CGFloat = 6
        let w = CGFloat(art.frameW) * scale, h = CGFloat(art.frameH) * scale
        g.saveGState()
        g.interpolationQuality = .none
        g.translateBy(x: (bounds.width - w) / 2, y: (bounds.height - h) / 2 + h)
        g.scaleBy(x: 1, y: -1)
        g.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
        g.restoreGState()
    }
}

/// Buttons that wrap onto as many lines as they need.
final class FlowView: NSView {
    private let width: CGFloat
    private var height: CGFloat = 0

    init(width: CGFloat, items: [NSView]) {
        self.width = width
        super.init(frame: NSRect(x: 0, y: 0, width: width, height: 10))
        var x: CGFloat = 0, y: CGFloat = 0, row: CGFloat = 0
        for v in items {
            let size = v.fittingSize
            if x > 0, x + size.width > width {
                x = 0
                y += row + 4
                row = 0
            }
            v.frame = NSRect(x: x, y: y, width: size.width, height: size.height)
            addSubview(v)
            x += size.width + 4
            row = max(row, size.height)
        }
        height = y + row
        frame.size.height = height
        translatesAutoresizingMaskIntoConstraints = false
        widthAnchor.constraint(equalToConstant: width).isActive = true
        heightAnchor.constraint(equalToConstant: max(height, 1)).isActive = true
    }

    required init?(coder: NSCoder) { fatalError() }
    override var isFlipped: Bool { true }
}

/// 我的角色 (GUILD.md §2): the guild avatar, of the camp's race. Each part can be picked, or rolled at random (all of them, or
/// just one), and the preview plays the avatar's moves.
final class GuildAvatarPanel: GuildPanelController, GuildPanelInit {
    let view: GuildPanel
    private let ctx: GuildContext
    private var look: GuildInfo.Avatar
    private let preview: AvatarPreview
    private var move = "idle"
    private var busy = false

    private static let moves = [("idle", "站著"), ("walk", "走路"), ("sit", "坐著"), ("type", "打字"), ("wave", "揮手"), ("cheer", "歡呼"), ("doze", "打瞌睡")]

    init(_ ctx: GuildContext) {
        self.ctx = ctx
        let a = ctx.info()?.avatar ?? AvatarKit.standard("goblin", "m")
        look = a
        preview = AvatarPreview(a)
        view = GuildPanel(title: "我的角色", sub: "在公會據點裡代表你", close: ctx.close)
        render()
    }

    func guildChanged() {}

    private func set(_ part: String, _ value: String) {
        switch part {
        case "face": look.face = value
        case "eyes": look.eyes = value
        case "brows": look.brows = value
        case "mouth": look.mouth = value
        case "hair": look.hair = value
        case "hairColor": look.hairColor = value
        case "skin": look.skin = value
        case "flame": look.flame = value
        default: break
        }
        changed()
    }

    private func current(_ part: String) -> String? {
        switch part {
        case "face": return look.face
        case "eyes": return look.eyes
        case "brows": return look.brows
        case "mouth": return look.mouth
        case "hair": return look.hair
        case "hairColor": return look.hairColor
        case "skin": return look.skin
        default: return look.flame
        }
    }

    private func changed() {
        preview.avatar = look
        render()
    }

    private func render() {
        let inner = view.inner
        let bone = look.race == "undead" && look.sex == "m"
        let o = AvatarKit.options(look.race, look.sex)
        var out: [NSView] = [preview]
        let moveButtons = FlowView(width: inner, items: Self.moves.map { m in
            let b = GuildUI.button(m.1, prominent: move == m.0) { [weak self] in
                self?.move = m.0
                self?.preview.anim = m.0
                self?.render()
            }
            return b
        })
        out.append(moveButtons)

        let names = look.race == "undead" ? ["骨系", "魂系"] : ["男", "女"]
        let sex = NSSegmentedControl(labels: names, trackingMode: .selectOne, target: nil, action: nil)
        sex.selectedSegment = look.sex == "m" ? 0 : 1
        sex.controlSize = .small
        let handler = FieldHandler { [weak self, weak sex] in
            guard let self, let sex else { return }
            let s = sex.selectedSegment == 0 ? "m" : "f"
            if s != self.look.sex { self.look = AvatarKit.standard(self.look.race, s); self.changed() }
        }
        sex.target = handler
        sex.action = #selector(FieldHandler.fire)
        objc_setAssociatedObject(sex, "handler", handler, .OBJC_ASSOCIATION_RETAIN)
        out.append(GuildUI.row([sex, NSView(), GuildUI.button("🎲 全部隨機") { [weak self] in
            guard let self else { return }
            self.look = AvatarKit.random(self.look.race, self.look.sex)
            self.changed()
        }]))

        var parts: [(key: String, title: String, list: [String], colour: String?)] = [("hair", bone ? "頭部" : "髮型", o.hair, nil)]
        if !bone { parts.append(("hairColor", "髮色", AvatarKit.hairColors, "hair")) }
        parts.append(("skin", bone ? "骨色" : "膚色", o.skin, "skin"))
        if !o.flame.isEmpty { parts.append(("flame", "眼火", o.flame, "flame")) }
        parts.append(("face", "臉型", AvatarKit.faces, nil))
        parts.append(("eyes", "眼睛", AvatarKit.eyes, nil))
        if !bone { parts.append(("brows", "眉毛", AvatarKit.brows, nil)) }
        parts.append(("mouth", "嘴巴", o.mouth, nil))

        for p in parts {
            out.append(GuildUI.separator())
            out.append(GuildUI.row([GuildUI.heading(p.title), NSView(), GuildUI.button("🎲") { [weak self] in
                guard let self else { return }
                self.look = AvatarKit.random(self.look.race, self.look.sex, from: self.look, only: p.key)
                self.changed()
            }]))
            let items = p.list.map { v -> NSView in
                let on = current(p.key) == v
                let title = NSMutableAttributedString()
                if let channel = p.colour {
                    let key = channel == "skin" ? "\(look.race)_\(look.sex)_\(v)" : v
                    if let c = GuildArt.shared.swatch(channel, key) { title.append(NSAttributedString(string: "● ", attributes: [.foregroundColor: c])) }
                }
                title.append(NSAttributedString(string: AvatarKit.labels[v] ?? v, attributes: [.foregroundColor: on ? NSColor(calibratedRed: 0.17, green: 0.11, blue: 0, alpha: 1) : NSColor.labelColor]))
                let b = GuildUI.button("") { [weak self] in self?.set(p.key, v) }
                b.attributedTitle = title
                if on { b.bezelColor = GuildUI.gold }
                return b
            }
            out.append(FlowView(width: inner, items: items))
        }

        out.append(GuildUI.separator())
        let save = GuildUI.button("儲存角色", prominent: true) { [weak self] in self?.save() }
        save.isEnabled = !busy
        out.append(save)
        view.show(out)
    }

    private func save() {
        busy = true
        render()
        ctx.run({
            defer { self.busy = false; self.render() }
            let got = try await self.ctx.api.request("PUT", "guild/avatar", body: self.look, as: GuildInfo.self)
            self.ctx.apply(got)
        }, done: "存好了！")
    }
}
