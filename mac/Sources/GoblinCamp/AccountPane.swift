import AppKit

/// 帳號, a page of the main window: who is signed in, how the notes are syncing, the friend code, and the buttons (登入或註冊,
/// 登入中的裝置, 登出). The sign-in form itself stays a small window of its own (AccountWindow), like any app's.
final class AccountPane: NSObject, MainPane {
    struct Content {
        var heading: String
        var lines: [String]
        var buttons: [(title: String, action: () -> Void)]
    }

    let paneView = NSView(frame: NSRect(x: 0, y: 0, width: 600, height: 500))
    /// What to show now (AppDelegate knows the account and the sync).
    var content: () -> Content = { Content(heading: "", lines: [], buttons: []) }
    private let stack = NSStackView()
    private var timer: Timer?

    override init() {
        super.init()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        paneView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: paneView.topAnchor, constant: 28),
            stack.leadingAnchor.constraint(equalTo: paneView.leadingAnchor, constant: 32),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: paneView.trailingAnchor, constant: -32),
        ])
    }

    func paneWillShow() {
        refresh()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in self?.refresh() } // ("已同步・3 分鐘前")
    }

    func paneDidHide() {
        timer?.invalidate()
        timer = nil
    }

    func refresh() {
        let now = content()
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        let heading = NSTextField(labelWithString: now.heading)
        heading.font = .systemFont(ofSize: 20, weight: .bold)
        stack.addArrangedSubview(heading)
        for line in now.lines where !line.isEmpty {
            let l = NSTextField(wrappingLabelWithString: line)
            l.font = .systemFont(ofSize: 13)
            l.textColor = .secondaryLabelColor
            l.isSelectable = true
            l.preferredMaxLayoutWidth = 520
            stack.addArrangedSubview(l)
        }
        let buttons = NSStackView(views: now.buttons.map { b in
            let button = ClosureButton(title: b.title) { [weak self] in b.action(); self?.refresh() }
            button.bezelStyle = .rounded
            return button
        })
        buttons.spacing = 8
        stack.setCustomSpacing(18, after: stack.arrangedSubviews.last ?? heading)
        stack.addArrangedSubview(buttons)
    }
}
