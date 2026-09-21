import AppKit
import CryptoKit

/// Keeping the app up to date without anyone having to hand a zip around.
///
/// There is no server: `./build.sh --release` writes a small `version.json` next to the zip, both are attached to a
/// GitHub release, and the app reads that one static file. When the player says yes we download the zip, check it,
/// and hand the swap to a short script that waits for us to quit (an app cannot overwrite itself while it runs).
enum UpdateFeed {
    /// GitHub keeps `releases/latest/download/<asset>` pointing at the newest release, so the app never needs a new URL.
    static let manifest = "https://github.com/Jordan-TTC-Design/mac-ant-game/releases/latest/download/version.json"

    /// `CAMP_UPDATE_FEED` points the check at a local file or a test release (tests, and trying a release before it is public).
    static var url: URL? {
        URL(string: ProcessInfo.processInfo.environment["CAMP_UPDATE_FEED"] ?? manifest)
    }

    /// `CAMP_NO_UPDATE` keeps a development build from ever replacing itself.
    static var disabled: Bool { ProcessInfo.processInfo.environment["CAMP_NO_UPDATE"] != nil }
}

/// One release as the feed describes it.
struct UpdateRelease {
    var version: String
    var url: URL
    var notes: String
    var sha256: String?
    var minimumSystemVersion: String?

    init?(json: [String: Any]) {
        guard let version = json["version"] as? String, !version.isEmpty,
              let link = json["url"] as? String, let url = URL(string: link) else { return nil }
        // Only ever download over TLS: nothing in the zip is signed by us, so the connection is what vouches for it.
        guard url.scheme == "https" || url.isFileURL else { return nil }
        self.version = version
        self.url = url
        self.notes = (json["notes"] as? String) ?? ""
        self.sha256 = (json["sha256"] as? String)?.lowercased()
        self.minimumSystemVersion = json["minimumSystemVersion"] as? String
    }
}

/// "0.7.0" vs "0.10.1" the way a person reads them, not the way strings compare.
enum Version {
    static func parts(_ text: String) -> [Int] {
        text.split(separator: ".").map { Int($0.prefix(while: \.isNumber)) ?? 0 }
    }

    /// True when `candidate` is newer than `current`.
    static func isNewer(_ candidate: String, than current: String) -> Bool {
        let a = parts(candidate), b = parts(current)
        for i in 0..<max(a.count, b.count) {
            let l = i < a.count ? a[i] : 0, r = i < b.count ? b[i] : 0
            if l != r { return l > r }
        }
        return false
    }
}

/// Everything here runs on the main thread; the network callbacks hop back to it.
final class Updater {
    static let shared = Updater()

    enum State: Equatable {
        case idle
        case checking
        case upToDate
        case available(version: String)
        case downloading(fraction: Double)
        case installing
        case failed(String)
    }

    private(set) var state: State = .idle { didSet { if state != oldValue { onChange?() } } }
    /// The menu redraws itself on this.
    var onChange: (() -> Void)?

    private var found: UpdateRelease?
    private let settings = Settings.shared
    private var session: URLSession { URLSession(configuration: .ephemeral) }

    var current: String { (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "0" }

    /// The release waiting to be installed, unless the player asked to skip it.
    var pending: UpdateRelease? {
        guard let found, Version.isNewer(found.version, than: current) else { return nil }
        return found
    }

    // MARK: Checking

    /// A quiet look a little after launch and once a day after that; `manual` is the menu item, which always reports back.
    func start() {
        guard !UpdateFeed.disabled else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 20) { [weak self] in self?.checkIfDue() }
        Timer.scheduledTimer(withTimeInterval: 6 * 3600, repeats: true) { [weak self] _ in
            DispatchQueue.main.async { self?.checkIfDue() }
        }
    }

    private func checkIfDue() {
        guard settings.updateCheckEnabled else { return }
        let day = 24.0 * 3600
        guard Date().timeIntervalSince1970 - settings.lastUpdateCheck > day else { return }
        check(manual: false)
    }

    /// `thenInstall` is the test path (`CAMP_TEST_UPDATE`): no alerts, just do it.
    func check(manual: Bool, thenInstall: Bool = false) {
        guard !UpdateFeed.disabled, let url = UpdateFeed.url else { return }
        if case .checking = state { return }
        if case .downloading = state { return }
        state = .checking
        settings.lastUpdateCheck = Date().timeIntervalSince1970
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 20
        session.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self else { return }
                if let error {
                    Diagnostics.note("update check failed: \(error.localizedDescription)")
                    self.state = manual ? .failed("連不上更新伺服器") : .idle
                    if manual { self.report() }
                    return
                }
                if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                    Diagnostics.note("update check got HTTP \(http.statusCode)")
                    self.state = manual ? .failed("更新資訊讀不到（HTTP \(http.statusCode)）") : .idle
                    if manual { self.report() }
                    return
                }
                guard let data, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let release = UpdateRelease(json: json) else {
                    Diagnostics.note("update feed could not be read")
                    self.state = manual ? .failed("更新資訊格式看不懂") : .idle
                    if manual { self.report() }
                    return
                }
                self.found = release
                if !Version.isNewer(release.version, than: self.current) {
                    Diagnostics.note("update: already on \(self.current) (latest \(release.version))")
                    self.state = .upToDate
                    if manual { self.report() }
                    return
                }
                if let minimum = release.minimumSystemVersion, !self.systemIsAtLeast(minimum) {
                    self.state = manual ? .failed("新版需要 macOS \(minimum) 以上") : .idle
                    if manual { self.report() }
                    return
                }
                Diagnostics.note("update: \(release.version) available")
                self.state = .available(version: release.version)
                if thenInstall { self.download(release); return }
                // A check the player did not ask for only nags once per version.
                if manual || self.settings.skippedUpdateVersion != release.version { self.offer(release, manual: manual) }
            }
        }.resume()
    }

    private func systemIsAtLeast(_ minimum: String) -> Bool {
        let want = Version.parts(minimum)
        let have = ProcessInfo.processInfo.operatingSystemVersion
        let mine = [have.majorVersion, have.minorVersion, have.patchVersion]
        for i in 0..<max(want.count, mine.count) {
            let l = i < mine.count ? mine[i] : 0, r = i < want.count ? want[i] : 0
            if l != r { return l > r }
        }
        return true
    }

    // MARK: Asking

    /// The result of a check the player asked for, so the menu item never looks like it did nothing.
    private func report() {
        switch state {
        case .upToDate:
            let alert = NSAlert()
            alert.messageText = "已經是最新版了"
            alert.informativeText = "哥布林營地 \(current)。"
            alert.addButton(withTitle: "好")
            present(alert)
        case .failed(let reason):
            let alert = NSAlert()
            alert.messageText = "檢查更新失敗"
            alert.informativeText = "\(reason)。晚點再試一次，或是找開發者要新的版本。"
            alert.addButton(withTitle: "好")
            present(alert)
        default:
            break
        }
    }

    func offer(_ release: UpdateRelease, manual: Bool) {
        let alert = NSAlert()
        alert.messageText = "有新版本：\(release.version)"
        var body = "目前是 \(current)。"
        if !release.notes.isEmpty { body += "\n\n\(release.notes)" }
        body += "\n\n更新時哥布林營地會關掉再自己打開，進度不會不見。"
        alert.informativeText = body
        alert.addButton(withTitle: "更新")
        alert.addButton(withTitle: "以後再說")
        if !manual { alert.addButton(withTitle: "跳過這個版本") }
        switch present(alert) {
        case .alertFirstButtonReturn: download(release)
        case .alertThirdButtonReturn: settings.skippedUpdateVersion = release.version
        default: break
        }
    }

    @discardableResult
    private func present(_ alert: NSAlert) -> NSApplication.ModalResponse {
        NSApp.activate(ignoringOtherApps: true)
        return alert.runModal()
    }

    // MARK: Downloading and installing

    private var progressObservation: NSKeyValueObservation?

    func download(_ release: UpdateRelease) {
        state = .downloading(fraction: 0)
        let task = session.downloadTask(with: release.url) { [weak self] location, response, error in
            // The temporary file is gone as soon as this returns, so move it somewhere of our own first.
            var moved: URL?
            if let location {
                let dir = FileManager.default.temporaryDirectory.appendingPathComponent("GoblinCampUpdate-\(UUID().uuidString)")
                let zip = dir.appendingPathComponent("GoblinCamp-\(release.version).zip")
                try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                if (try? FileManager.default.moveItem(at: location, to: zip)) != nil { moved = zip }
            }
            DispatchQueue.main.async {
                guard let self else { return }
                self.progressObservation = nil
                if let error {
                    self.fail("下載失敗：\(error.localizedDescription)")
                    return
                }
                if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                    self.fail("下載失敗（HTTP \(http.statusCode)）")
                    return
                }
                guard let zip = moved else {
                    self.fail("下載的檔案存不起來")
                    return
                }
                self.install(zip: zip, release: release)
            }
        }
        progressObservation = task.progress.observe(\.fractionCompleted) { [weak self] progress, _ in
            DispatchQueue.main.async {
                guard let self, case .downloading = self.state else { return }
                self.state = .downloading(fraction: progress.fractionCompleted)
            }
        }
        task.resume()
    }

    private func install(zip: URL, release: UpdateRelease) {
        state = .installing
        let folder = zip.deletingLastPathComponent()
        defer { if case .failed = state { try? FileManager.default.removeItem(at: folder) } }

        // The zip is not signed by anyone we can check, so the checksum from the feed is what catches a broken
        // or swapped file; HTTPS to github.com is what says the feed itself is ours.
        if let want = release.sha256 {
            guard let data = try? Data(contentsOf: zip, options: .mappedIfSafe) else {
                fail("下載的檔案讀不到")
                return
            }
            let got = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
            guard got == want else {
                Diagnostics.note("update: sha256 \(got) != \(want)")
                fail("下載的檔案校驗不過，為了安全起見沒有安裝")
                return
            }
        }

        let unpacked = folder.appendingPathComponent("unpacked")
        guard run("/usr/bin/ditto", ["-x", "-k", zip.path, unpacked.path]) else {
            fail("解壓縮失敗")
            return
        }
        guard let newApp = (try? FileManager.default.contentsOfDirectory(at: unpacked, includingPropertiesForKeys: nil))?
            .first(where: { $0.pathExtension == "app" }) else {
            fail("更新檔裡面找不到 App")
            return
        }
        // Make sure we are about to install GoblinCamp, at the version the feed promised.
        guard let info = NSDictionary(contentsOf: newApp.appendingPathComponent("Contents/Info.plist")),
              info["CFBundleIdentifier"] as? String == Bundle.main.bundleIdentifier,
              let shipped = info["CFBundleShortVersionString"] as? String, shipped == release.version else {
            fail("更新檔看起來不是哥布林營地 \(release.version)")
            return
        }

        let target = Bundle.main.bundleURL
        guard FileManager.default.isWritableFile(atPath: target.deletingLastPathComponent().path) else {
            revealInstead(newApp, target: target)
            return
        }
        swap(newApp: newApp, target: target, folder: folder)
    }

    /// An app cannot replace itself while it is running, so a small script waits for us to go away and does it.
    private func swap(newApp: URL, target: URL, folder: URL) {
        let script = folder.appendingPathComponent("install.sh")
        let body = """
        #!/bin/bash
        # Written by GoblinCamp to finish an update; it deletes itself at the end.
        set -e
        while kill -0 \(ProcessInfo.processInfo.processIdentifier) 2>/dev/null; do sleep 0.2; done
        sleep 0.5
        rm -rf \(shellQuoted(target.path))
        /usr/bin/ditto \(shellQuoted(newApp.path)) \(shellQuoted(target.path))
        /usr/bin/xattr -dr com.apple.quarantine \(shellQuoted(target.path)) 2>/dev/null || true
        /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f \(shellQuoted(target.path)) >/dev/null 2>&1 || true
        /usr/bin/open \(shellQuoted(target.path))
        rm -rf \(shellQuoted(folder.path))
        """
        guard (try? body.write(to: script, atomically: true, encoding: .utf8)) != nil,
              (try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: script.path)) != nil else {
            fail("更新腳本寫不出來")
            return
        }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [script.path]
        do {
            try process.run()
        } catch {
            fail("更新啟動失敗：\(error.localizedDescription)")
            return
        }
        Diagnostics.note("update: quitting to install")
        NSApp.terminate(nil)
    }

    /// /Applications without write access (or an app somewhere odd): hand the new copy over in Finder instead.
    private func revealInstead(_ newApp: URL, target: URL) {
        let keep = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads/\(newApp.lastPathComponent)")
        try? FileManager.default.removeItem(at: keep)
        let shown = (try? FileManager.default.moveItem(at: newApp, to: keep)) != nil ? keep : newApp
        state = .idle
        let alert = NSAlert()
        alert.messageText = "新版下載好了，要請你自己搬一下"
        alert.informativeText = "這台 Mac 不讓哥布林營地改寫 \(target.deletingLastPathComponent().path)，所以沒辦法自己更新。\n\n把 Finder 裡的 GoblinCamp.app 拖進「應用程式」覆蓋舊的就好。"
        alert.addButton(withTitle: "在 Finder 顯示")
        alert.addButton(withTitle: "好")
        if present(alert) == .alertFirstButtonReturn {
            NSWorkspace.shared.activateFileViewerSelecting([shown])
        }
    }

    private func fail(_ reason: String) {
        Diagnostics.note("update failed: \(reason)")
        state = .failed(reason)
        if ProcessInfo.processInfo.environment["CAMP_TEST_UPDATE"] != nil { NSLog("GoblinCamp test: update failed: \(reason)"); return }
        let alert = NSAlert()
        alert.messageText = "更新沒有成功"
        alert.informativeText = "\(reason)。\n\n原本的版本沒有動過，晚點再試一次就好。"
        alert.addButton(withTitle: "好")
        present(alert)
        state = .idle
    }

    @discardableResult
    private func run(_ path: String, _ arguments: [String]) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    private func shellQuoted(_ path: String) -> String { "'" + path.replacingOccurrences(of: "'", with: "'\\''") + "'" }
}
