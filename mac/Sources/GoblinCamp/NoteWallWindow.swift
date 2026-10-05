import AppKit

/// 便利貼牆: every note in one page of the main window, for when there are too many for the desktop. A list on the left (search, and
/// 全部 / 待辦 / 備忘), the note picked on the right: its words, 待辦 or 備忘, its paper, whether it is on the desktop,
/// a memo's lines to copy (and open, for a web address), a todo's times. Notes kept in the wall have no window on the
/// desktop; one ticked 放在桌面上 gets its window back.
final class NoteWallWindow: NSObject, NSTableViewDataSource, NSTableViewDelegate, NSTextViewDelegate, NSSearchFieldDelegate, MainPane {
    private let notes: NoteController
    let paneView = NSView(frame: NSRect(x: 0, y: 0, width: 780, height: 520))
    private let table = NSTableView()
    private let search = NSSearchField()
    private let filter = NSSegmentedControl(labels: ["全部", "待辦", "備忘"], trackingMode: .selectOne, target: nil, action: nil)
    private let editorBox = NSView()
    private let empty = NSTextField(labelWithString: "左邊選一張便利貼，或按「＋ 待辦」「＋ 備忘」新增一張。")
    private let kind = NSSegmentedControl(labels: ["待辦（可以設提醒）", "備忘（不用時間）"], trackingMode: .selectOne, target: nil, action: nil)
    private let text = NSTextView()
    private let desk = NSButton(checkboxWithTitle: "放在桌面上", target: nil, action: nil)
    private let color = NSPopUpButton()
    private let times = NSTextField(labelWithString: "")
    private let remindButton = NSButton(title: "設提醒…", target: nil, action: nil)
    private let dueButton = NSButton(title: "目標時間…", target: nil, action: nil)
    private let linesTitle = NSTextField(labelWithString: "每一行")
    private let lines = NSStackView()
    private var shown: [StickyNote] = []
    private var selectedID: String?
    private var typing: Timer?
    /// A memo with lines: the words get half the height, the lines the rest.
    private var textHalf: NSLayoutConstraint?

    init(notes: NoteController) {
        self.notes = notes
        super.init()
        build()
    }

    /// Picks a note (when the page opens on it).
    func select(_ id: String) {
        reload()
        pick(id)
    }

    /// Showing in the main window.
    private(set) var isVisible = false
    var contentView: NSView? { paneView }

    func paneWillShow() {
        isVisible = true
        reload()
    }

    func paneDidHide() {
        isVisible = false
        commitTyping()
    }

    // MARK: Layout

    private func build() {
        let content = paneView

        // the bar along the top
        search.placeholderString = "搜尋便利貼"
        search.delegate = self
        filter.selectedSegment = 0
        filter.target = self
        filter.action = #selector(filterChanged)
        let addTodo = NSButton(title: "＋ 待辦", target: self, action: #selector(newTodo))
        let addMemo = NSButton(title: "＋ 備忘", target: self, action: #selector(newMemo))
        let tidy = NSButton(title: "桌面上的全部收進牆", target: self, action: #selector(putAllAway))
        tidy.toolTip = "桌面上的便利貼全部收進這裡（之後可以一張一張勾「放在桌面上」）"
        let bar = NSStackView(views: [search, filter, NSView(), addTodo, addMemo, tidy])
        bar.orientation = .horizontal
        bar.spacing = 8
        search.widthAnchor.constraint(equalToConstant: 170).isActive = true

        // the list
        let column = NSTableColumn(identifier: .init("note"))
        column.resizingMask = .autoresizingMask
        table.addTableColumn(column)
        table.headerView = nil
        table.rowHeight = 46
        table.style = .inset
        table.dataSource = self
        table.delegate = self
        let listScroll = NSScrollView()
        listScroll.documentView = table
        listScroll.hasVerticalScroller = true
        listScroll.drawsBackground = false

        // the note picked
        kind.target = self
        kind.action = #selector(kindChanged)
        text.isRichText = false
        text.allowsUndo = true
        text.font = .systemFont(ofSize: 14)
        text.delegate = self
        text.textContainerInset = NSSize(width: 6, height: 6)
        let textScroll = NSScrollView()
        textScroll.documentView = text
        textScroll.hasVerticalScroller = true
        textScroll.borderType = .bezelBorder
        text.minSize = NSSize(width: 0, height: 0)
        text.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        text.isVerticallyResizable = true
        text.autoresizingMask = [.width]
        text.textContainer?.widthTracksTextView = true
        desk.target = self
        desk.action = #selector(deskChanged)
        for paper in NotePaper.all { color.addItem(withTitle: paper.name) }
        color.target = self
        color.action = #selector(colorChanged)
        remindButton.target = self
        remindButton.action = #selector(setRemind)
        dueButton.target = self
        dueButton.action = #selector(setDue)
        times.textColor = .secondaryLabelColor
        times.lineBreakMode = .byTruncatingTail
        linesTitle.font = .boldSystemFont(ofSize: 12)
        linesTitle.textColor = .secondaryLabelColor
        lines.orientation = .vertical
        lines.alignment = .leading
        lines.spacing = 4
        let linesScroll = NSScrollView()
        let linesHolder = FlippedView()
        linesHolder.addSubview(lines)
        lines.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            lines.topAnchor.constraint(equalTo: linesHolder.topAnchor),
            lines.leadingAnchor.constraint(equalTo: linesHolder.leadingAnchor),
            lines.trailingAnchor.constraint(equalTo: linesHolder.trailingAnchor),
            lines.bottomAnchor.constraint(lessThanOrEqualTo: linesHolder.bottomAnchor),
        ])
        linesScroll.documentView = linesHolder
        linesScroll.hasVerticalScroller = true
        linesScroll.drawsBackground = false
        linesHolder.translatesAutoresizingMaskIntoConstraints = false
        linesHolder.widthAnchor.constraint(equalTo: linesScroll.contentView.widthAnchor).isActive = true

        let findButton = NSButton(title: "在桌面上找它", target: self, action: #selector(findOnDesk))
        let deleteButton = NSButton(title: "刪除", target: self, action: #selector(deleteNote))
        let timeRow = NSStackView(views: [times, remindButton, dueButton])
        timeRow.spacing = 6
        let options = NSStackView(views: [desk, NSTextField(labelWithString: "紙："), color, NSView(), findButton, deleteButton])
        options.spacing = 8
        let editor = NSStackView(views: [kind, textScroll, timeRow, linesTitle, linesScroll, options])
        editor.orientation = .vertical
        editor.alignment = .leading
        editor.spacing = 8
        for v in [kind, textScroll, timeRow, linesScroll, options] { v.widthAnchor.constraint(equalTo: editor.widthAnchor).isActive = true }
        textScroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 150).isActive = true
        linesScroll.heightAnchor.constraint(greaterThanOrEqualToConstant: 60).isActive = true
        textHalf = textScroll.heightAnchor.constraint(equalTo: editor.heightAnchor, multiplier: 0.42)
        editor.setHuggingPriority(.defaultLow, for: .vertical)
        textScroll.setContentHuggingPriority(.defaultLow, for: .vertical)
        editorBox.addSubview(editor)
        editorBox.addSubview(empty)
        empty.textColor = .secondaryLabelColor
        empty.alignment = .center

        for v in [bar, listScroll, editorBox, editor, empty] { v.translatesAutoresizingMaskIntoConstraints = false }
        content.addSubview(bar)
        content.addSubview(listScroll)
        content.addSubview(editorBox)
        NSLayoutConstraint.activate([
            bar.topAnchor.constraint(equalTo: content.topAnchor, constant: 12),
            bar.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 12),
            bar.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -12),
            listScroll.topAnchor.constraint(equalTo: bar.bottomAnchor, constant: 10),
            listScroll.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 8),
            listScroll.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -8),
            listScroll.widthAnchor.constraint(equalToConstant: 260),
            editorBox.topAnchor.constraint(equalTo: bar.bottomAnchor, constant: 10),
            editorBox.leadingAnchor.constraint(equalTo: listScroll.trailingAnchor, constant: 12),
            editorBox.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -12),
            editorBox.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -12),
            editor.topAnchor.constraint(equalTo: editorBox.topAnchor),
            editor.leadingAnchor.constraint(equalTo: editorBox.leadingAnchor),
            editor.trailingAnchor.constraint(equalTo: editorBox.trailingAnchor),
            editor.bottomAnchor.constraint(equalTo: editorBox.bottomAnchor),
            empty.centerXAnchor.constraint(equalTo: editorBox.centerXAnchor),
            empty.centerYAnchor.constraint(equalTo: editorBox.centerYAnchor),
        ])
        showEditor(nil)
    }

    // MARK: The list

    /// The notes to list: by the filter and the search, todos not done first, then by when they changed.
    func reload() {
        let q = search.stringValue.trimmingCharacters(in: .whitespaces).lowercased()
        let want = filter.selectedSegment
        shown = notes.store.live
            .filter { want == 0 || (want == 1 && !$0.isMemo) || (want == 2 && $0.isMemo) }
            .filter { q.isEmpty || $0.text.lowercased().contains(q) || $0.goblinName.contains(q) }
            .sorted { a, b in
                if a.done != b.done { return !a.done }
                return a.updatedAt > b.updatedAt
            }
        table.reloadData()
        if let id = selectedID, let row = shown.firstIndex(where: { $0.id == id }) {
            table.selectRowIndexes([row], byExtendingSelection: false)
            if text.window?.firstResponder !== text { showEditor(shown[row]) } else { refreshSide(shown[row]) }
        } else {
            showEditor(nil)
        }
    }

    func numberOfRows(in tableView: NSTableView) -> Int { shown.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let note = shown[row]
        let cell = NoteWallRow()
        cell.set(note)
        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        let row = table.selectedRow
        commitTyping()
        selectedID = row >= 0 && row < shown.count ? shown[row].id : nil
        showEditor(selectedID.flatMap { id in shown.first { $0.id == id } })
    }

    private func pick(_ id: String) {
        guard let row = shown.firstIndex(where: { $0.id == id }) else { return }
        table.selectRowIndexes([row], byExtendingSelection: false)
        table.scrollRowToVisible(row)
    }

    func controlTextDidChange(_ obj: Notification) { reload() }
    @objc private func filterChanged() { reload() }

    // MARK: The note picked

    private func showEditor(_ note: StickyNote?) {
        editorBox.subviews.first?.isHidden = note == nil
        empty.isHidden = note != nil
        guard let note else { return }
        text.string = note.text
        refreshSide(note)
    }

    /// Everything but the words (so typing is not disturbed).
    private func refreshSide(_ note: StickyNote) {
        kind.selectedSegment = note.isMemo ? 1 : 0
        desk.state = note.onDesk ? .on : .off
        color.selectItem(at: NotePaper.all.firstIndex { $0.id == note.color } ?? 0)
        let todo = !note.isMemo
        remindButton.isHidden = !todo
        dueButton.isHidden = !todo
        var parts: [String] = []
        if let r = note.remindAt { parts.append("提醒 " + NoteTime.text(r)) }
        if let d = note.dueAt { parts.append("目標 " + NoteTime.text(d)) }
        if note.done { parts.append("完成了") }
        times.stringValue = todo ? (parts.isEmpty ? "沒有設時間" : parts.joined(separator: "・")) : ""
        times.isHidden = !todo
        fillLines(note)
    }

    /// A memo's lines, each with 複製 (and 開啟 for a web address).
    private func fillLines(_ note: StickyNote) {
        for v in lines.arrangedSubviews { v.removeFromSuperview() }
        let list = note.text.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        linesTitle.isHidden = !note.isMemo || list.isEmpty
        lines.superview?.enclosingScrollView?.isHidden = linesTitle.isHidden
        textHalf?.isActive = !linesTitle.isHidden
        guard note.isMemo else { return }
        for line in list.prefix(40) {
            let url = line.range(of: #"https?://\S+"#, options: .regularExpression).map { String(line[$0]) }
            let label = NSTextField(labelWithString: line)
            label.lineBreakMode = .byTruncatingTail
            label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            let copy = smallButton("複製") { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(url ?? line, forType: .string) }
            var row: [NSView] = [label, NSView(), copy]
            if let url, let link = URL(string: url) { row.append(smallButton("開啟") { NSWorkspace.shared.open(link) }) }
            let stack = NSStackView(views: row)
            stack.spacing = 6
            lines.addArrangedSubview(stack)
            stack.widthAnchor.constraint(equalTo: lines.widthAnchor).isActive = true
        }
    }

    // words: kept a moment after typing stops
    func textDidChange(_ notification: Notification) {
        typing?.invalidate()
        typing = Timer.scheduledTimer(withTimeInterval: 0.6, repeats: false) { [weak self] _ in self?.commitTyping() }
    }

    private func commitTyping() {
        typing?.invalidate()
        typing = nil
        guard let id = selectedID, let note = notes.store.note(id), note.text != text.string else { return }
        let value = text.string
        notes.change(id) { $0.text = value }
    }

    @objc private func kindChanged() {
        guard let id = selectedID else { return }
        notes.setKind(id, memo: kind.selectedSegment == 1)
    }

    @objc private func deskChanged() {
        guard let id = selectedID else { return }
        notes.setDesk(id, desk.state == .on)
    }

    @objc private func colorChanged() {
        guard let id = selectedID, NotePaper.all.indices.contains(color.indexOfSelectedItem) else { return }
        let paper = NotePaper.all[color.indexOfSelectedItem]
        notes.change(id) { $0.color = paper.id }
    }

    @objc private func setRemind() { if let id = selectedID { notes.pickTime(for: id, reminder: true) } }
    @objc private func setDue() { if let id = selectedID { notes.pickTime(for: id, reminder: false) } }

    @objc private func findOnDesk() {
        guard let id = selectedID else { return }
        if notes.store.note(id)?.onDesk == false { notes.setDesk(id, true) }
        notes.bringForward(id)
    }

    @objc private func deleteNote() {
        guard let id = selectedID else { return }
        notes.confirmDelete(id)
    }

    @objc private func newTodo() { add(memo: false) }
    @objc private func newMemo() { add(memo: true) }

    private func add(memo: Bool) {
        // a new note starts in the wall (tick 放在桌面上 to put it on the desktop)
        let note = notes.newNote(edit: false, memo: memo)
        if !memo { notes.setDesk(note.id, false) }
        filter.selectedSegment = 0
        search.stringValue = ""
        selectedID = note.id
        reload()
        pick(note.id)
        paneView.window?.makeFirstResponder(text)
    }

    @objc private func putAllAway() { notes.putAllInWall() }
}

/// One note in the wall's list: its paper colour, its first line, and what it is.
private final class NoteWallRow: NSTableCellView {
    private let swatch = NSView()
    private let title = NSTextField(labelWithString: "")
    private let detail = NSTextField(labelWithString: "")

    init() {
        super.init(frame: .zero)
        swatch.wantsLayer = true
        swatch.layer?.cornerRadius = 4
        swatch.layer?.borderWidth = 1
        swatch.layer?.borderColor = NSColor(calibratedWhite: 0, alpha: 0.2).cgColor
        title.font = .systemFont(ofSize: 13, weight: .semibold)
        title.lineBreakMode = .byTruncatingTail
        detail.font = .systemFont(ofSize: 11)
        detail.textColor = .secondaryLabelColor
        detail.lineBreakMode = .byTruncatingTail
        for v in [swatch, title, detail] {
            v.translatesAutoresizingMaskIntoConstraints = false
            addSubview(v)
        }
        NSLayoutConstraint.activate([
            swatch.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 6),
            swatch.centerYAnchor.constraint(equalTo: centerYAnchor),
            swatch.widthAnchor.constraint(equalToConstant: 14),
            swatch.heightAnchor.constraint(equalToConstant: 30),
            title.leadingAnchor.constraint(equalTo: swatch.trailingAnchor, constant: 8),
            title.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -6),
            title.topAnchor.constraint(equalTo: topAnchor, constant: 5),
            detail.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            detail.trailingAnchor.constraint(equalTo: title.trailingAnchor),
            detail.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 1),
        ])
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    func set(_ note: StickyNote) {
        swatch.layer?.backgroundColor = NotePaper.named(note.color).fill.cgColor
        let first = note.text.split(separator: "\n", omittingEmptySubsequences: true).first.map(String.init) ?? "（空白的便利貼）"
        title.stringValue = first
        var parts = [note.isMemo ? "備忘" : "待辦", note.onDesk ? "在桌面" : "在牆上"]
        if note.done { parts.append("完成了") } else if let r = note.remindAt { parts.append("提醒 " + NoteTime.text(r)) }
        detail.stringValue = parts.joined(separator: "・")
        alphaValue = note.done ? 0.55 : 1
    }
}

/// A view whose origin is at the top, so a stack grows downward inside a scroll view.
private final class FlippedView: NSView {
    override var isFlipped: Bool { true }
}

private func smallButton(_ title: String, _ action: @escaping () -> Void) -> NSButton {
    let button = ClosureButton(title: title, action: action)
    button.bezelStyle = .rounded
    button.controlSize = .small
    return button
}
