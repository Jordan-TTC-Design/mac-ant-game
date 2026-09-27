import Foundation

/// What happened on one day.
struct DayStats: Codable {
    var pomodoros = 0
    /// Focus time in seconds, including the part of a pomodoro that was stopped early.
    var focusSeconds = 0.0
    var askedDecision = 0
    var finishedTasks = 0
}

/// Daily numbers for the pomodoro and the Claude notifications, in ~/Library/Application Support/GoblinCamp/stats.json.
final class Stats {
    static let shared = Stats()

    private(set) var days: [String: DayStats]
    private let url: URL
    private let noDisk: Bool

    init(url: URL? = nil) {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        self.url = url ?? base.appendingPathComponent("GoblinCamp/stats.json")
        noDisk = ProcessInfo.processInfo.environment["CAMP_NO_SAVE"] != nil // tests must not touch the real numbers
        days = noDisk ? [:] : (try? JSONDecoder().decode([String: DayStats].self, from: Data(contentsOf: self.url))) ?? [:]
    }

    static func key(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    var today: DayStats { days[Stats.key(Date())] ?? DayStats() }

    private func change(_ body: (inout DayStats) -> Void) {
        var day = today
        body(&day)
        days[Stats.key(Date())] = day
        save()
    }

    func pomodoroCompleted(focusSeconds: Double) { change { $0.pomodoros += 1; $0.focusSeconds += focusSeconds } }
    func addFocus(seconds: Double) { if seconds > 1 { change { $0.focusSeconds += seconds } } }
    func notification(_ kind: NotifyKind) {
        change { if kind == .permission { $0.askedDecision += 1 } else { $0.finishedTasks += 1 } }
    }

    private func save() {
        guard !noDisk else { return }
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(days).write(to: url, options: .atomic)
        } catch {
            NSLog("GoblinCamp: saving stats failed: \(error)")
        }
    }

    static func minutes(_ seconds: Double) -> String {
        let m = Int((seconds / 60).rounded())
        return m >= 60 ? "\(m / 60) 小時 \(m % 60) 分" : "\(m) 分鐘"
    }

    /// Today and the last week, as lines of text.
    func summary(now: Date = Date()) -> (today: String, week: String) {
        let d = today
        let todayText = "番茄鐘完成 \(d.pomodoros) 個，專注 \(Stats.minutes(d.focusSeconds))\nClaude 通知 \(d.askedDecision + d.finishedTasks) 則（需要決定 \(d.askedDecision)、完成 \(d.finishedTasks)）"
        var lines: [String] = []
        let calendar = Calendar.current
        for back in 0..<7 {
            guard let date = calendar.date(byAdding: .day, value: -back, to: now) else { continue }
            let day = days[Stats.key(date)] ?? DayStats()
            let f = DateFormatter()
            f.dateFormat = "M/d（E）"
            f.locale = Locale(identifier: "zh_TW")
            let bar = String(repeating: "🍅", count: min(day.pomodoros, 12))
            lines.append("\(f.string(from: date))　\(day.pomodoros) 個　\(Stats.minutes(day.focusSeconds))　通知 \(day.askedDecision + day.finishedTasks)　\(bar)")
        }
        return (todayText, lines.joined(separator: "\n"))
    }
}
