import AppKit
import Darwin

/// How each run ended, in exits.log beside the saves, for "it closed by itself": a line when the app starts, and one when it
/// ends saying why (the menu's 結束, an update, logging out or shutting down, another app asking it to quit, a signal, or a
/// crash with its stack). A start with no end after it means it was force quit or died without a word; the next start says
/// so and names the system's crash report, if there is one. The last lines go into 複製診斷資訊.
enum ExitLog {
    /// Why it is about to quit, when something other than the menu asks (the updater sets it before quitting).
    static var reason: String?
    private static var started = Date()

    static var url: URL { Persistence.url("exits.log") }
    private static var enabled: Bool {
        let env = ProcessInfo.processInfo.environment
        return env["CAMP_NO_SAVE"] == nil || env["CAMP_DATA_DIR"] != nil // (a test run without its own folder leaves the real log alone)
    }

    /// At launch: notes how the last run ended, starts this one, and listens for crashes and signals.
    static func start() {
        guard enabled else { return }
        started = Date()
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        var lines = ((try? String(contentsOf: url, encoding: .utf8)) ?? "").split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        if lines.last == "" { lines.removeLast() }
        if lines.count > 400 { lines.removeFirst(lines.count - 300) }
        // (a signal handler can only write the time as seconds: made readable now)
        lines = lines.map { line in
            guard line.hasPrefix("時間 "), let end = line.dropFirst(3).firstIndex(of: " "), let seconds = TimeInterval(line[line.index(line.startIndex, offsetBy: 3)..<end]) else { return line }
            return stamp(Date(timeIntervalSince1970: seconds)) + line[end...]
        }
        // the last run started and never said how it ended
        if let last = lines.last(where: { !$0.hasPrefix("  ") }), last.contains(" 啟動 ") {
            let report = crashReport(after: startTime(of: last))
            lines.append("\(stamp(Date())) 上次沒有正常結束（被強制結束或當掉）\(report.map { "；系統的當機報告：\($0)" } ?? "；沒有找到系統的當機報告")")
            Diagnostics.note("last run ended without a word\(report.map { " (\($0))" } ?? "")")
        }
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        lines.append("\(stamp(started)) 啟動 v\(version)（pid \(getpid())，macOS \(ProcessInfo.processInfo.operatingSystemVersionString)）")
        try? (lines.joined(separator: "\n") + "\n").write(to: url, atomically: true, encoding: .utf8)

        logFD = open(url.path, O_WRONLY | O_APPEND)
        for sig in [SIGSEGV, SIGBUS, SIGILL, SIGTRAP, SIGABRT, SIGFPE] { signal(sig, crashed) }
        for sig in [SIGTERM, SIGHUP, SIGINT] { signal(sig, signalled) }
        NSSetUncaughtExceptionHandler { exception in ExitLog.uncaught(exception) }
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.willPowerOffNotification, object: nil, queue: .main) { _ in
            if reason == nil { reason = "登出或關機" }
        }
    }

    /// From applicationShouldTerminate: why, as far as can be told (a quit Apple event says who asked, and for logging out why).
    static func quitting() {
        guard reason == nil else { return }
        guard let event = NSAppleEventManager.shared().currentAppleEvent, event.eventClass == fourCC("aevt"), event.eventID == fourCC("quit") else {
            reason = "從選單或 ⌘Q 結束"
            return
        }
        switch event.attributeDescriptor(forKeyword: fourCC("why?"))?.enumCodeValue {
        case fourCC("logo"), fourCC("rlgo"): reason = "登出"
        case fourCC("rrst"), fourCC("rest"): reason = "重新開機"
        case fourCC("rsdn"), fourCC("shut"): reason = "關機"
        default: reason = "其他程式要求結束（例如活動監視器的「結束」）"
        }
    }

    /// From applicationWillTerminate: the last line of this run.
    static func ended() {
        guard enabled else { return }
        let minutes = Int(Date().timeIntervalSince(started) / 60)
        write("\(stamp(Date())) 結束：\(reason ?? "原因不明")（開了 \(minutes) 分鐘）\n")
    }

    static func uncaught(_ exception: NSException) {
        write("\(stamp(Date())) 當掉：Objective-C 例外 \(exception.name.rawValue)：\(exception.reason ?? "")\n"
            + exception.callStackSymbols.prefix(30).map { "  \($0)" }.joined(separator: "\n") + "\n")
    }

    /// The last few runs, for the diagnostics.
    static func tail(_ n: Int = 20) -> [String] {
        let text = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        return text.split(separator: "\n").suffix(n).map(String.init)
    }

    static func write(_ text: String) {
        guard logFD >= 0 else { return }
        text.utf8CString.withUnsafeBufferPointer { buffer in _ = Darwin.write(logFD, buffer.baseAddress, buffer.count - 1) }
    }

    // MARK: helpers

    private static func stamp(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f.string(from: date)
    }

    private static func startTime(of line: String) -> Date {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f.date(from: String(line.prefix(19))) ?? .distantPast
    }

    /// The newest GoblinCamp crash report macOS wrote since `date`, by file name.
    private static func crashReport(after date: Date) -> String? {
        let folder = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/DiagnosticReports")
        let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
        return files
            .filter { $0.lastPathComponent.hasPrefix("GoblinCamp") }
            .compactMap { url -> (URL, Date)? in
                guard let at = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate, at >= date else { return nil }
                return (url, at)
            }
            .max { $0.1 < $1.1 }?.0.lastPathComponent
    }

    private static func fourCC(_ s: String) -> UInt32 {
        s.utf8.reduce(0) { $0 << 8 | UInt32($1) }
    }
}

// (what the signal handlers use: nothing in them may allocate, so the file is opened beforehand and the words are fixed)
private var logFD: Int32 = -1

private func rawWrite(_ s: StaticString) {
    _ = write(logFD, s.utf8Start, s.utf8CodeUnitCount)
}

private func rawNumber(_ n: Int) {
    withUnsafeTemporaryAllocation(of: UInt8.self, capacity: 24) { buf in
        var v = n < 0 ? -n : n
        var i = 24
        repeat {
            i -= 1
            buf[i] = UInt8(48 + v % 10)
            v /= 10
        } while v > 0 && i > 1
        if n < 0 { i -= 1; buf[i] = 45 }
        _ = write(logFD, buf.baseAddress! + i, 24 - i)
    }
}

private func signalName(_ sig: Int32) -> StaticString {
    switch sig {
    case SIGSEGV: return "SIGSEGV（記憶體存取錯誤）"
    case SIGBUS: return "SIGBUS（記憶體存取錯誤）"
    case SIGILL: return "SIGILL（程式錯誤）"
    case SIGTRAP: return "SIGTRAP（Swift 執行錯誤，例如陣列超出範圍）"
    case SIGABRT: return "SIGABRT（程式自己中止）"
    case SIGFPE: return "SIGFPE（算術錯誤）"
    case SIGTERM: return "SIGTERM"
    case SIGHUP: return "SIGHUP"
    case SIGINT: return "SIGINT"
    default: return "signal"
    }
}

private let crashed: @convention(c) (Int32) -> Void = { sig in
    if logFD >= 0 {
        rawWrite("時間 ")
        rawNumber(time(nil))
        rawWrite(" 當掉：")
        rawWrite(signalName(sig))
        rawWrite("\n")
        withUnsafeTemporaryAllocation(of: UnsafeMutableRawPointer?.self, capacity: 64) { frames in
            let n = backtrace(frames.baseAddress, 64)
            backtrace_symbols_fd(frames.baseAddress, n, logFD)
        }
    }
    // then as if nobody had listened: macOS writes its crash report too
    signal(sig, SIG_DFL)
    raise(sig)
}

private let signalled: @convention(c) (Int32) -> Void = { sig in
    if logFD >= 0 {
        rawWrite("時間 ")
        rawNumber(time(nil))
        rawWrite(" 結束：收到 ")
        rawWrite(signalName(sig))
        rawWrite("（被別的程式結束）\n")
    }
    signal(sig, SIG_DFL)
    raise(sig)
}
