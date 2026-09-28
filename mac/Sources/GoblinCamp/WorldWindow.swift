import AppKit
import WebKit

/// 大世界: the web page's map, parties and reports in a window of the Mac's own (server/WORLD.md §15). It opens signed in
/// as this Mac's account (a one-time link from the server), so nobody types a password twice.
final class WorldWindow: NSObject, WKNavigationDelegate {
    private let window: NSWindow
    private let web: WKWebView
    private let api: APIClient
    private let status = NSTextField(labelWithString: "")

    init(api: APIClient) {
        self.api = api
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default() // (the cookie stays, so the page works between openings too)
        web = WKWebView(frame: NSRect(x: 0, y: 0, width: 440, height: 820), configuration: config)
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 440, height: 820), styleMask: [.titled, .closable, .resizable, .miniaturizable], backing: .buffered, defer: false)
        super.init()
        window.title = "大世界"
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 360, height: 560)
        window.setFrameAutosaveName("GoblinCampWorld")
        web.navigationDelegate = self
        web.autoresizingMask = [.width, .height]
        web.setValue(false, forKey: "drawsBackground") // (the page's own green shows while it loads)
        let content = NSView(frame: web.frame)
        content.wantsLayer = true
        content.layer?.backgroundColor = NSColor(calibratedRed: 0.18, green: 0.29, blue: 0.16, alpha: 1).cgColor
        content.addSubview(web)
        status.textColor = .white
        status.alignment = .center
        status.frame = NSRect(x: 20, y: 400, width: 400, height: 20)
        status.autoresizingMask = [.width, .minYMargin, .maxYMargin]
        content.addSubview(status)
        window.contentView = content
        if !window.setFrameUsingName("GoblinCampWorld") { window.center() }
    }

    /// Opens (or brings back) the window, signed in, at `path`.
    func show(path: String = "/world") {
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        status.stringValue = "連線中…"
        status.isHidden = false
        Task { @MainActor in
            do {
                let url = try await api.handoff(to: path)
                web.load(URLRequest(url: url))
            } catch let error as APIError {
                status.stringValue = error.isOffline ? "連不上伺服器，大世界要連網才能玩。" : error.message
            } catch {
                status.stringValue = error.localizedDescription
            }
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { status.isHidden = true }

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
