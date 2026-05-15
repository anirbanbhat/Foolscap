import AppKit

/// A reusable fuzzy-filter panel — one text field, one table, esc/enter.
/// Used by ⌘P (workspace files) and ⌘R (symbols in current buffer).
final class QuickPanelController: NSWindowController, NSTextFieldDelegate, NSTableViewDataSource, NSTableViewDelegate {

    struct Item {
        let title: String
        let subtitle: String?
        let key: String
        let payload: Any
    }

    var items: [Item] = []
    var onSelect: ((Item) -> Void)?
    var placeholder: String = "Filter…"

    private var queryField: NSTextField!
    private var table: NSTableView!
    private var filtered: [Item] = []

    init() {
        let win = QuickPanelWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 360),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        win.titleVisibility = .hidden
        win.titlebarAppearsTransparent = true
        win.isMovableByWindowBackground = true
        win.level = .modalPanel
        win.hidesOnDeactivate = true
        super.init(window: win)
        buildUI()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func buildUI() {
        guard let content = window?.contentView else { return }

        queryField = NSTextField()
        queryField.placeholderString = placeholder
        queryField.font = NSFont.systemFont(ofSize: 16)
        queryField.translatesAutoresizingMaskIntoConstraints = false
        queryField.delegate = self
        queryField.focusRingType = .none

        let scroll = NSScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.borderType = .noBorder
        scroll.drawsBackground = false

        table = NSTableView()
        table.headerView = nil
        table.dataSource = self
        table.delegate = self
        table.allowsMultipleSelection = false
        table.style = .plain
        table.rowHeight = 36
        table.target = self
        table.doubleAction = #selector(commit)
        table.action = #selector(commit)
        let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("row"))
        col.resizingMask = .autoresizingMask
        table.addTableColumn(col)
        scroll.documentView = table

        content.addSubview(queryField)
        content.addSubview(scroll)

        NSLayoutConstraint.activate([
            queryField.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 14),
            queryField.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -14),
            queryField.topAnchor.constraint(equalTo: content.topAnchor, constant: 14),

            scroll.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 6),
            scroll.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -6),
            scroll.topAnchor.constraint(equalTo: queryField.bottomAnchor, constant: 10),
            scroll.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -6),
        ])
    }

    func present(over parent: NSWindow) {
        guard let win = self.window else { return }
        queryField.stringValue = ""
        applyFilter()
        // Centre over parent.
        let parentFrame = parent.frame
        let size = win.frame.size
        let origin = NSPoint(x: parentFrame.midX - size.width / 2, y: parentFrame.midY - size.height / 2 + 80)
        win.setFrameOrigin(origin)
        win.makeKeyAndOrderFront(nil)
        win.makeFirstResponder(queryField)
    }

    @objc private func commit() {
        let row = table.selectedRow
        guard row >= 0 && row < filtered.count else { return }
        let item = filtered[row]
        window?.close()
        onSelect?(item)
    }

    private func applyFilter() {
        let q = queryField.stringValue
        filtered = FuzzyMatch.filter(items, query: q) { $0.key }
        table.reloadData()
        if !filtered.isEmpty {
            table.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        }
    }

    // MARK: NSTextFieldDelegate

    func controlTextDidChange(_ obj: Notification) {
        applyFilter()
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        switch commandSelector {
        case #selector(NSResponder.moveDown(_:)):
            moveSelection(by: 1); return true
        case #selector(NSResponder.moveUp(_:)):
            moveSelection(by: -1); return true
        case #selector(NSResponder.insertNewline(_:)):
            commit(); return true
        case #selector(NSResponder.cancelOperation(_:)):
            window?.close(); return true
        default:
            return false
        }
    }

    private func moveSelection(by delta: Int) {
        guard !filtered.isEmpty else { return }
        let cur = table.selectedRow
        var next = cur + delta
        next = max(0, min(filtered.count - 1, next))
        table.selectRowIndexes(IndexSet(integer: next), byExtendingSelection: false)
        table.scrollRowToVisible(next)
    }

    // MARK: NSTableView

    func numberOfRows(in tableView: NSTableView) -> Int { filtered.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let item = filtered[row]
        let cell = NSTableCellView()
        let title = NSTextField(labelWithString: item.title)
        title.font = NSFont.systemFont(ofSize: 13)
        title.translatesAutoresizingMaskIntoConstraints = false
        title.lineBreakMode = .byTruncatingTail
        cell.addSubview(title)

        if let subtitle = item.subtitle {
            let sub = NSTextField(labelWithString: subtitle)
            sub.font = NSFont.systemFont(ofSize: 11)
            sub.textColor = NSColor.secondaryLabelColor
            sub.translatesAutoresizingMaskIntoConstraints = false
            sub.lineBreakMode = .byTruncatingTail
            cell.addSubview(sub)
            NSLayoutConstraint.activate([
                title.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 10),
                title.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -10),
                title.topAnchor.constraint(equalTo: cell.topAnchor, constant: 3),
                sub.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 10),
                sub.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -10),
                sub.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 1),
            ])
        } else {
            NSLayoutConstraint.activate([
                title.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 10),
                title.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -10),
                title.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            ])
        }
        return cell
    }
}

/// NSPanel subclass that can become key — needed so the text field accepts focus.
final class QuickPanelWindow: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
