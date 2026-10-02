import AppKit

// Taiwan's holidays in the camp (DESKTOP.md §3): the day is named in the camp window, the camp says so once that day, and some days have
// their own goings-on (fireworks on 國慶 and New Year's Eve, the eldest led round on 重陽, 湯圓 on 冬至, a tree at Christmas).

/// One holiday.
struct Holiday: Equatable {
    let id: String
    let name: String
    /// What the camp says when the day comes (one of these).
    let greetings: [String]
    /// Only marked as a day off: no celebrating (memorial days).
    var quiet = false
    /// Fireworks after dark.
    var fireworks = false
}

enum Holidays {
    // MARK: The days

    static let newYearsEve = Holiday(id: "new_years_eve", name: "跨年夜", greetings: ["今天跨年！半夜有煙火喔！", "最後一天了，晚上一起倒數！"], fireworks: true)
    static let newYear = Holiday(id: "new_year", name: "元旦", greetings: ["新年快樂！", "新的一年，營地也要加油！"])
    static let lunarEve = Holiday(id: "lunar_eve", name: "除夕", greetings: ["今天除夕，大家圍爐囉！", "除夕快樂！晚上要守歲喔！"], fireworks: true)
    static let springFestival = Holiday(id: "spring_festival", name: "春節", greetings: ["新年快樂！恭喜發財！", "過年囉！紅包拿來～"])
    static let lantern = Holiday(id: "lantern", name: "元宵節", greetings: ["元宵節快樂！晚上提燈籠！", "今天要吃湯圓、猜燈謎！"])
    static let peace = Holiday(id: "peace_memorial", name: "和平紀念日", greetings: ["今天是和平紀念日，放假一天。"], quiet: true)
    static let children = Holiday(id: "children", name: "兒童節", greetings: ["兒童節快樂！今天小孩最大！"])
    static let qingming = Holiday(id: "qingming", name: "清明節", greetings: ["清明節，今天吃潤餅。", "清明時節，大家去掃墓。"])
    static let labor = Holiday(id: "labor", name: "勞動節", greetings: ["勞動節快樂！今天大家放假～"])
    static let dragonBoat = Holiday(id: "dragon_boat", name: "端午節", greetings: ["端午節快樂！要吃粽子喔！", "端午節！中午來立蛋！"])
    static let qixi = Holiday(id: "qixi", name: "七夕", greetings: ["今天是七夕，情人節快樂～"])
    static let ghost = Holiday(id: "ghost", name: "中元節", greetings: ["中元普渡，供桌擺起來！", "鬼門開了……大家晚上小心喔。"])
    static let midAutumn = Holiday(id: "mid_autumn", name: "中秋節", greetings: ["中秋節快樂！今晚烤肉賞月！", "中秋節！柚子帽戴起來！"])
    static let teachers = Holiday(id: "teachers", name: "教師節", greetings: ["教師節快樂！謝謝老師～"])
    static let doubleNinth = Holiday(id: "double_ninth", name: "重陽節", greetings: ["重陽節，敬老囉！", "今天重陽，大家登高！"])
    static let national = Holiday(id: "national", name: "國慶日", greetings: ["國慶日快樂！晚上有煙火喔！", "今天放假！晚上一起看煙火！"], fireworks: true)
    static let retrocession = Holiday(id: "retrocession", name: "光復節", greetings: ["今天是光復節，放假一天。"], quiet: true)
    static let dongzhi = Holiday(id: "dongzhi", name: "冬至", greetings: ["冬至到了，來吃湯圓！", "冬至快樂！湯圓要吃幾顆？"])
    static let weiya = Holiday(id: "weiya", name: "尾牙", greetings: ["今天尾牙！老闆請客！", "尾牙到了，要抽獎囉！"])
    static let christmas = Holiday(id: "christmas", name: "聖誕節", greetings: ["聖誕快樂！", "Merry Christmas！營地也有聖誕樹喔！"])

    // MARK: Which day is which

    /// The date the camp lives in: today, or `CAMP_DATE=yyyy-MM-dd` (tests).
    static var now: Date {
        guard let forced = ProcessInfo.processInfo.environment["CAMP_DATE"] else { return Date() }
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        guard let day = f.date(from: forced) else { return Date() }
        let time = Calendar.current.dateComponents([.hour, .minute, .second], from: Date())
        return Calendar.current.date(byAdding: time, to: day) ?? day
    }

    private static var cache: (key: String, holiday: Holiday?)?

    /// Today's holiday, if any (worked out once a day).
    static var today: Holiday? {
        let key = Stats.key(now)
        if let cache, cache.key == key { return cache.holiday }
        let found = on(now)
        cache = (key, found)
        return found
    }

    /// The solar term day of 清明 (around 4/4–4/5) and 冬至 (around 12/21–12/22), by the usual formula for 2001–2099.
    static func qingmingDay(year: Int) -> Int { let y = Double(year % 100); return Int(y * 0.2422 + 4.81) - Int((y - 1) / 4) }
    static func dongzhiDay(year: Int) -> Int { let y = Double(year % 100); return Int(y * 0.2422 + 21.94) - Int((y - 1) / 4) }

    static func on(_ date: Date) -> Holiday? {
        let solar = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day], from: date)
        let (y, m, d) = (solar.year ?? 2026, solar.month ?? 1, solar.day ?? 1)
        var chinese = Calendar(identifier: .chinese)
        chinese.timeZone = TimeZone(identifier: "Asia/Taipei") ?? .current
        let lunar = chinese.dateComponents([.month, .day], from: date) // (`isLeapMonth` comes with the month)
        let leap = lunar.isLeapMonth ?? false
        let (lm, ld) = (lunar.month ?? 0, lunar.day ?? 0)
        let tomorrow = Calendar(identifier: .gregorian).date(byAdding: .day, value: 1, to: date) ?? date
        let next = chinese.dateComponents([.month, .day], from: tomorrow)

        if !leap {
            switch (lm, ld) {
            case (1, 1...5): return springFestival
            case (1, 15): return lantern
            case (5, 5): return dragonBoat
            case (7, 7): return qixi
            case (7, 15): return ghost
            case (8, 15): return midAutumn
            case (9, 9): return doubleNinth
            case (12, 16): return weiya
            default: break
            }
            if lm == 12, next.month == 1, next.day == 1, next.isLeapMonth != true { return lunarEve }
        }
        if m == 4, d == 4, qingmingDay(year: y) == 4 { // both on one day
            return Holiday(id: "children_qingming", name: "兒童節・清明節", greetings: ["今天兒童節也是清明節！小孩最大，也吃潤餅！"])
        }
        switch (m, d) {
        case (1, 1): return newYear
        case (2, 28): return peace
        case (4, qingmingDay(year: y)): return qingming
        case (4, 4): return children
        case (5, 1): return labor
        case (9, 28): return teachers
        case (10, 10): return national
        case (10, 25): return retrocession
        case (12, dongzhiDay(year: y)): return dongzhi
        case (12, 25): return christmas
        case (12, 31): return newYearsEve
        default: return nil
        }
    }

    /// Fireworks are up now: a fireworks day after dark (and New Year's Eve on past midnight, a little).
    static var fireworksNow: Bool {
        let hour = Scenery.currentHour
        if let day = today, day.fireworks, hour >= 19 { return true }
        if today == newYear, hour == 0 { return true } // (the countdown's fireworks run past midnight)
        if today == springFestival, hour == 0, Calendar(identifier: .chinese).dateComponents([.day], from: now).day == 1 { return true }
        return false
    }

    // MARK: Saying it once a day

    /// Whether the camp has said today's holiday yet (kept in the settings, so it is said once a day, not at every start).
    static func shouldAnnounce() -> Holiday? {
        guard let day = today else { return nil }
        let key = Stats.key(now)
        guard Settings.shared.holidayAnnounced != key || ProcessInfo.processInfo.environment["CAMP_DATE"] != nil else { return nil }
        return day
    }

    static func announced() { Settings.shared.holidayAnnounced = Stats.key(now) }
}

// MARK: - Fireworks

/// The fireworks over the camp on a fireworks night: shells rise from below, burst into a ring of sparks, and fade.
final class Fireworks {
    struct Shell {
        var from: CGPoint
        var to: CGPoint
        var age = 0.0
        let rise: Double
        let color: NSColor
        let sparks: Int
        let size: Double
    }
    private(set) var shells: [Shell] = []
    private var timer = 0.0

    static let palette: [NSColor] = [
        NSColor(calibratedRed: 1, green: 0.35, blue: 0.35, alpha: 1), NSColor(calibratedRed: 1, green: 0.8, blue: 0.3, alpha: 1),
        NSColor(calibratedRed: 0.45, green: 0.8, blue: 1, alpha: 1), NSColor(calibratedRed: 0.65, green: 1, blue: 0.5, alpha: 1),
        NSColor(calibratedRed: 1, green: 0.55, blue: 0.9, alpha: 1), NSColor(calibratedWhite: 1, alpha: 1),
    ]

    /// The lifetime of a shell after it bursts.
    static let burstTime = 1.6

    var isOn: Bool { !shells.isEmpty }

    /// `area`: the part of the camp the sky is over (the upper part of where they walk).
    func update(dt: Double, on: Bool, area: CGRect) {
        for i in shells.indices { shells[i].age += dt }
        shells.removeAll { $0.age > $0.rise + Fireworks.burstTime }
        guard on, area.width > 40 else { return }
        timer -= dt
        guard timer <= 0 else { return }
        timer = Double.random(in: 0.35...1.1)
        let salvo = Double.random(in: 0..<1) < 0.15 ? 3 : 1 // now and then three go up at once
        for k in 0..<salvo {
            let burst = CGPoint(x: CGFloat.random(in: area.minX + 50...area.maxX - 50), y: CGFloat.random(in: area.midY...area.maxY - 30))
            let from = CGPoint(x: burst.x + CGFloat.random(in: -20...20), y: area.minY)
            shells.append(Shell(from: from, to: burst, rise: Double.random(in: 0.7...1.1) + Double(k) * 0.15, color: Fireworks.palette.randomElement()!,
                                sparks: Int.random(in: 24...36), size: Double.random(in: 40...75)))
        }
    }
}

extension Colony {
    /// Once a frame: fireworks, and what the day's goings-on need (Colony.tick).
    func updateHoliday(dt: Double) {
        if let year = ProcessInfo.processInfo.environment["CAMP_TEST_HOLIDAYS"].flatMap(Int.init) { // every holiday of that year, then quit
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd"
            var day = f.date(from: "\(year)-01-01")!
            var list: [String] = []
            while Calendar(identifier: .gregorian).component(.year, from: day) == year {
                if let h = Holidays.on(day) { list.append("\(f.string(from: day).dropFirst(5)) \(h.name)") }
                day = Calendar(identifier: .gregorian).date(byAdding: .day, value: 1, to: day)!
            }
            print("holidays \(year): " + list.joined(separator: "、"))
            fflush(stdout)
            NSApp.terminate(nil)
        }
        let area = walkable.reduce(CGRect.null) { $0.union($1) }
        fireworks.update(dt: dt, on: Holidays.fireworksNow && !campHidden, area: area.isNull ? .zero : area)
        // on a fireworks night those who are out stop and look up now and then, and cheer
        if fireworks.isOn, Double.random(in: 0..<1) < dt * 0.6 {
            let lookers = ants.indices.filter { i in
                guard case .wandering = ants[i].mode else { return false }
                return !ants[i].isHidden && ants[i].touch == nil
            }
            if let i = lookers.randomElement() {
                ants[i].face(CGPoint(x: ants[i].pos.x, y: ants[i].pos.y + 100))
                ants[i].touch = Touch.react(.hop, 2, line: ["哇～", "好漂亮！", "再一個！", "砰！"].randomElement())
            }
        }
        holidayTimer -= dt
        guard holidayTimer <= 0 else { return }
        holidayTimer = 20
        if holidaySaid != Stats.key(Holidays.now), let day = Holidays.shouldAnnounce(), let line = day.greetings.randomElement(), onAnnounce?(line) == true {
            holidaySaid = Stats.key(Holidays.now)
            Holidays.announced()
        }
        guard let day = Holidays.today, !day.quiet else { return }
        // 重陽: now and then the eldest is led round the camp, the others at its side (respect for the old)
        if day == Holidays.doubleNinth, !Colony.isNight, Double.random(in: 0..<1) < 0.3 { honourTheEldest() }
    }

    private func honourTheEldest() {
        let idle = ants.indices.filter { i in
            if case .wandering = ants[i].mode { return !ants[i].isChild && !ants[i].isWounded && ants[i].touch == nil && !ants[i].isHidden }
            return false
        }
        guard let eldest = idle.max(by: { ants[$0].lifeFraction < ants[$1].lifeFraction }) else { return }
        let escorts = idle.filter { $0 != eldest }.sorted {
            hypot(ants[$0].pos.x - ants[eldest].pos.x, ants[$0].pos.y - ants[eldest].pos.y) < hypot(ants[$1].pos.x - ants[eldest].pos.x, ants[$1].pos.y - ants[eldest].pos.y)
        }.prefix(3)
        guard !escorts.isEmpty else { return }
        var world = AntWorld(nest: nest ?? .zero, walkable: walkable, foods: [], creatures: [], foodScale: 1)
        world.night = false
        let seconds = Double.random(in: 25...40)
        ants[eldest].begin(.stroll, world: world, seconds: seconds)
        let offsets = [CGPoint(x: -22, y: -8), CGPoint(x: 22, y: -8), CGPoint(x: 0, y: -26)]
        for (k, i) in escorts.enumerated() { ants[i].begin(.serve(boss: ants[eldest].id, offset: offsets[k]), world: world, seconds: seconds) }
        addFloater("重陽敬老：大家陪 \(ants[eldest].name) 走一圈", .uncommon, at: ants[eldest].pos, important: true)
    }
}
