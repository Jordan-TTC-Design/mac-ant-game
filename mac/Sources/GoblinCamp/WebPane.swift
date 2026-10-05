import AppKit
import WebKit

/// A page of the web app in the main window (大世界, 任務, 動態: server/WORLD.md §15). It opens signed in as this Mac's
/// account (a one-time link from the server), so nobody types a password twice. The page knows it is in the Mac
/// ("GoblinCampMac" in its user agent): it leaves out the phone's tab bar and lays itself out for a wide window.
final class WebPane: NSObject, MainPane, WKNavigationDelegate, WKUIDelegate {
    let paneView: NSView
    private let web: WKWebView
    private let api: APIClient
    private let path: String
    private let status = NSTextField(labelWithString: "")
    /// Loaded once (signed in); after that the page keeps itself up to date.
    private var loaded = false

    /// One cookie jar for all the panes, so signing in once does for all of them.
    private static let data = WKWebsiteDataStore.default()

    init(api: APIClient, path: String) {
        self.api = api
        self.path = path
        let config = WKWebViewConfiguration()
        config.websiteDataStore = WebPane.data // (the cookie stays, so the page works between openings too)
        config.applicationNameForUserAgent = "GoblinCampMac"
        web = WKWebView(frame: NSRect(x: 0, y: 0, width: 900, height: 700), configuration: config)
        paneView = NSView(frame: web.frame)
        super.init()
        web.navigationDelegate = self
        web.uiDelegate = self // (the page's 確定？ questions: without this they silently answer no)
        web.autoresizingMask = [.width, .height]
        web.setValue(false, forKey: "drawsBackground") // (the page's own green shows while it loads)
        paneView.wantsLayer = true
        paneView.layer?.backgroundColor = NSColor(calibratedRed: 0.18, green: 0.29, blue: 0.16, alpha: 1).cgColor
        paneView.addSubview(web)
        status.textColor = .white
        status.alignment = .center
        status.frame = NSRect(x: 20, y: 340, width: 860, height: 20)
        status.autoresizingMask = [.width, .minYMargin, .maxYMargin]
        paneView.addSubview(status)
    }

    func paneWillShow() {
        if !loaded { load() }
    }

    /// The app version whose web pages were last loaded: after an update, the web app's offline copy (its service worker and
    /// caches) is thrown away first, or the old pages it kept ask for files the server no longer has (a blank page).
    private static var freshFor: String?

    private static func freshen() async {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
        guard freshFor == nil else { return }
        freshFor = version
        guard Settings.shared.webFreshVersion != version else { return }
        let kinds: Set<String> = [WKWebsiteDataTypeServiceWorkerRegistrations, WKWebsiteDataTypeFetchCache, WKWebsiteDataTypeDiskCache, WKWebsiteDataTypeMemoryCache]
        await data.removeData(ofTypes: kinds, modifiedSince: .distantPast)
        Settings.shared.webFreshVersion = version
    }

    /// Loads `path` (or another page of the app) signed in.
    func load(_ to: String? = nil) {
        status.stringValue = "連線中…"
        status.isHidden = false
        Task { @MainActor in
            await WebPane.freshen()
            do {
                let url = try await api.handoff(to: to ?? path)
                web.load(URLRequest(url: url))
                loaded = true
            } catch let error as APIError {
                status.stringValue = error.isOffline ? "連不上伺服器，這一頁要連網才能看。" : error.message
            } catch {
                status.stringValue = error.localizedDescription
            }
        }
    }

    /// Reloads what is showing (signed out and in again: the old page belongs to someone else).
    func reset() {
        loaded = false
        web.loadHTMLString("", baseURL: nil)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { status.isHidden = true }

    // MARK: The page's alert() and confirm(), as sheets on the window

    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        let alert = NSAlert()
        alert.messageText = message
        alert.addButton(withTitle: "好")
        guard let window = paneView.window else { alert.runModal(); return completionHandler() }
        alert.beginSheetModal(for: window) { _ in completionHandler() }
    }

    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        let alert = NSAlert()
        let lines = message.components(separatedBy: "\n\n")
        alert.messageText = lines[0]
        alert.informativeText = lines.dropFirst().joined(separator: "\n\n")
        alert.addButton(withTitle: "確定")
        alert.addButton(withTitle: "取消")
        guard let window = paneView.window else { return completionHandler(alert.runModal() == .alertFirstButtonReturn) }
        alert.beginSheetModal(for: window) { answer in completionHandler(answer == .alertFirstButtonReturn) }
    }

    /// Tests: the page as it is now, into a PNG, and where it is.
    func snapshotForTesting(to path: String, done: @escaping (String) -> Void) {
        web.takeSnapshot(with: nil) { image, _ in
            if let tiff = image?.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff), let png = rep.representation(using: .png, properties: [:]) {
                try? png.write(to: URL(fileURLWithPath: path))
            }
            done(self.web.url?.absoluteString ?? "(none)")
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        status.stringValue = "載入失敗：\(error.localizedDescription)"
        status.isHidden = false
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        status.stringValue = "載入失敗：\(error.localizedDescription)"
        status.isHidden = false
    }

    /// Links to other sites (the map's credits, for instance) open in the browser, not in here.
    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if let url = action.request.url, let host = url.host, action.navigationType == .linkActivated, host != api.serverHost {
            NSWorkspace.shared.open(url)
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }
}
