import AppKit

/// One page of the main window: the view it shows on the right, and what to do when it comes up or goes away.
protocol MainPane: AnyObject {
    var paneView: NSView { get }
    /// Just before it is shown (refresh, start timers).
    func paneWillShow()
    /// It was switched away from, or the window closed (stop timers, keep what was typed).
    func paneDidHide()
}

extension MainPane {
    func paneWillShow() {}
    func paneDidHide() {}
}

/// The app's one big window: a sidebar of pages on the left (the big world, quests, what happened, the workshop, the roster,
/// the notes, the account, the manual) and the page picked on the right, like any Mac app. The camp itself keeps its own
/// small window (or the desktop): this one is for looking things up and doing things.
final class MainWindow: NSObject, NSWindowDelegate, NSTableViewDataSource, NSTableViewDelegate, NSToolbarDelegate {
    enum Page: String, CaseIterable {
        case camp, world, quests, feed, workshop, roster, notes, account, manual

        var title: String {
            switch self {
            case .camp: return "營地"
            case .world: return "大世界"
            case .quests: return "任務"
            case .feed: return "動態"
            case .workshop: return "工坊"
            case .roster: return "\(Characters.current.noun)名冊"
            case .notes: return "便利貼"
            case .account: return "帳號"
            case .manual: return "說明手冊"
            }
        }

        /// The narrowest the page can be: the camp very small (a corner of the desktop), the web pages lay themselves out for
        /// a phone when narrow, the Mac's own pages need their room.
        var minWidth: CGFloat {
            switch self {
            case .camp: return 300
            case .world, .quests, .feed: return 360
            case .account, .manual: return 420
            case .workshop: return 600
            case .notes: return 620
            case .roster: return 720
            }
        }

        var symbol: String {
            switch self {
            case .camp: return "tent"
            case .world: return "globe.asia.australia"
            case .quests: return "checklist"
            case .feed: return "clock.arrow.circlepath"
            case .workshop: return "hammer"
            case .roster: return "person.3"
            case .notes: return "note.text"
            case .account: return "person.crop.circle"
            case .manual: return "book"
            }
        }
    }

    let window: NSWindow
    private let split = NSSplitViewController()
    private let sidebar = NSTableView()
    private let holder = NSViewController()
    /// The pages offered right now (the big world, quests and what happened need an account); asked again each time it opens.
    var pages: () -> [Page] = { Page.allCases }
    /// Makes (or hands back) a page's pane.
    var pane: (Page) -> MainPane? = { _ in nil }
    private var shown: [Page] = []
    private(set) var current: Page?
    private var currentPane: MainPane?

    var isVisible: Bool { window.isVisible && !window.isMiniaturized }
    func isShowing(_ page: Page) -> Bool { isVisible && current == page }

    override init() {
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1180, height: 780),
                          styleMask: [.titled, .closable, .resizable, .miniaturizable, .fullSizeContentView], backing: .buffered, defer: false)
        super.init()
        window.title = "哥布林營地"
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 300, height: 240) // (small enough for a corner of the desktop: the sidebar folds away first; each page sets its own, `fit`)
        window.delegate = self
        window.toolbarStyle = .unified
        let toolbar = NSToolbar(identifier: "GoblinCampMain")
        toolbar.delegate = self
        toolbar.displayMode = .iconOnly
        window.toolbar = toolbar

        let column = NSTableColumn(identifier: .init("page"))
        sidebar.addTableColumn(column)
        sidebar.headerView = nil
        sidebar.style = .sourceList
        sidebar.rowHeight = 30
        sidebar.dataSource = self
        sidebar.delegate = self
        let scroll = NSScrollView()
        scroll.documentView = sidebar
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = false
        let side = NSViewController()
        side.view = scroll
        let sideItem = NSSplitViewItem(sidebarWithViewController: side)
        sideItem.minimumThickness = 170
        sideItem.maximumThickness = 260
        sideItem.canCollapse = true
        if #available(macOS 14.0, *) { sideItem.canCollapseFromWindowResize = true } // (made narrow: the sidebar goes, the page stays)
        holder.view = NSView()
        let mainItem = NSSplitViewItem(viewController: holder)
        mainItem.minimumThickness = 300
        split.addSplitViewItem(sideItem)
        split.addSplitViewItem(mainItem)
        split.splitView.autosaveName = "GoblinCampMainSplit"
        window.contentViewController = split
        window.setContentSize(NSSize(width: 1180, height: 780))
        if !window.setFrameUsingName("GoblinCampMain") { window.center() }
        window.setFrameAutosaveName("GoblinCampMain")
    }

    /// Opens the window on `page` (or on the page it was last on) and brings it in front (`activate`: the app too; not when
    /// it opens by itself at launch).
    func show(_ page: Page? = nil, activate: Bool = true) {
        reloadSidebar()
        let wanted = page ?? current ?? Page(rawValue: Settings.shared.mainPage ?? "") ?? shown.first ?? .workshop
        select(shown.contains(wanted) ? wanted : (shown.first ?? .manual))
        if window.isMiniaturized { window.deminiaturize(nil) }
        if activate {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
        } else {
            window.orderFrontRegardless()
        }
    }

    /// The sidebar again (after signing in or out), keeping the page if it is still offered.
    func reloadSidebar() {
        shown = pages()
        sidebar.reloadData()
        if let current, let row = shown.firstIndex(of: current) {
            sidebar.selectRowIndexes([row], byExtendingSelection: false)
        } else if current != nil, window.isVisible {
            select(shown.first ?? .manual)
        }
    }

    func close() { window.orderOut(nil); hideCurrent() }

    private func select(_ page: Page) {
        if let row = shown.firstIndex(of: page), sidebar.selectedRow != row {
            sidebar.selectRowIndexes([row], byExtendingSelection: false) // (comes back through the delegate)
        }
        guard page != current || currentPane == nil else { currentPane?.paneWillShow(); return }
        hideCurrent()
        guard let pane = pane(page) else { return }
        current = page
        currentPane = pane
        Settings.shared.mainPage = page.rawValue
        let view = pane.paneView
        view.translatesAutoresizingMaskIntoConstraints = false
        holder.view.addSubview(view)
        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: holder.view.safeAreaLayoutGuide.topAnchor),
            view.leadingAnchor.constraint(equalTo: holder.view.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: holder.view.trailingAnchor),
            view.bottomAnchor.constraint(equalTo: holder.view.bottomAnchor),
        ])
        window.subtitle = ""
        window.title = page.title
        fit(page)
        pane.paneWillShow()
    }

    /// The window no narrower than the page needs (made wider if it is, with the sidebar if it shows).
    private func fit(_ page: Page) {
        let side = split.splitViewItems.first
        let sideWidth = side?.isCollapsed == false ? (side?.viewController.view.frame.width ?? 170) : 0
        window.contentMinSize = NSSize(width: page.minWidth, height: 240)
        let need = page.minWidth + sideWidth
        guard let content = window.contentView, content.frame.width < need else { return }
        var frame = window.frame
        frame.size.width += need - content.frame.width
        if let screen = window.screen?.visibleFrame, frame.maxX > screen.maxX { frame.origin.x = max(screen.minX, screen.maxX - frame.width) }
        window.setFrame(frame, display: true, animate: window.isVisible)
    }

    private func hideCurrent() {
        guard let pane = currentPane else { return }
        pane.paneView.removeFromSuperview()
        pane.paneDidHide()
        currentPane = nil
    }

    // MARK: Window

    func windowWillClose(_ notification: Notification) { hideCurrent() }

    /// The sidebar folded away because the window was made narrow (opened again when it is wide again; not if folded by hand).
    private var foldedForSize = false

    func windowDidResize(_ notification: Notification) {
        guard let side = split.splitViewItems.first else { return }
        let width = window.frame.width
        if width < 560, !side.isCollapsed {
            foldedForSize = true
            side.isCollapsed = true
        } else if width >= 700, side.isCollapsed, foldedForSize {
            foldedForSize = false
            side.isCollapsed = false
        }
    }

    func windowDidBecomeKey(_ notification: Notification) {
        if currentPane == nil, let current { select(current) } // (closed and opened again)
    }

    // MARK: Sidebar

    func numberOfRows(in tableView: NSTableView) -> Int { shown.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let page = shown[row]
        let id = NSUserInterfaceItemIdentifier("pageCell")
        let cell = (tableView.makeView(withIdentifier: id, owner: self) as? NSTableCellView) ?? {
            let c = NSTableCellView()
            c.identifier = id
            let image = NSImageView()
            let text = NSTextField(labelWithString: "")
            text.font = .systemFont(ofSize: 13)
            for v in [image, text] as [NSView] { v.translatesAutoresizingMaskIntoConstraints = false; c.addSubview(v) }
            c.imageView = image
            c.textField = text
            NSLayoutConstraint.activate([
                image.leadingAnchor.constraint(equalTo: c.leadingAnchor, constant: 4),
                image.centerYAnchor.constraint(equalTo: c.centerYAnchor),
                image.widthAnchor.constraint(equalToConstant: 20),
                text.leadingAnchor.constraint(equalTo: image.trailingAnchor, constant: 8),
                text.trailingAnchor.constraint(equalTo: c.trailingAnchor, constant: -4),
                text.centerYAnchor.constraint(equalTo: c.centerYAnchor),
            ])
            return c
        }()
        cell.imageView?.image = NSImage(systemSymbolName: page.symbol, accessibilityDescription: page.title)
        cell.textField?.stringValue = page.title
        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        let row = sidebar.selectedRow
        guard shown.indices.contains(row) else { return }
        select(shown[row])
    }

    // MARK: Toolbar (the button that folds the sidebar away)

    func toolbarAllowedItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] { [.toggleSidebar, .sidebarTrackingSeparator, .flexibleSpace] }
    func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] { [.toggleSidebar, .sidebarTrackingSeparator] }
    func toolbar(_ toolbar: NSToolbar, itemForItemIdentifier id: NSToolbarItem.Identifier, willBeInsertedIntoToolbar flag: Bool) -> NSToolbarItem? { NSToolbarItem(itemIdentifier: id) }
}
