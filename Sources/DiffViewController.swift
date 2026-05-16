import AppKit

/// Side-by-side line diff viewer. A panel with two synchronized scroll views;
/// each row painted with the appropriate background colour for its diff kind.
final class DiffViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {

    private let leftURL: URL
    private let rightURL: URL
    private var rows: [DiffEngine.Row] = []
    private var leftLines: [String] = []
    private var rightLines: [String] = []

    init(left: URL, right: URL) {
        self.leftURL = left
        self.rightURL = right
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func loadView() {
        let root = NSView(frame: NSRect(x: 0, y: 0, width: 1000, height: 640))

        leftLines = (try? String(contentsOf: leftURL, encoding: .utf8))?.components(separatedBy: "\n") ?? []
        rightLines = (try? String(contentsOf: rightURL, encoding: .utf8))?.components(separatedBy: "\n") ?? []
        rows = DiffEngine.rows(left: leftLines, right: rightLines)

        let split = NSSplitView()
        split.isVertical = true
        split.dividerStyle = .thin
        split.translatesAutoresizingMaskIntoConstraints = false

        let leftPane = makePane(title: leftURL.lastPathComponent, side: .left)
        let rightPane = makePane(title: rightURL.lastPathComponent, side: .right)

        split.addArrangedSubview(leftPane.container)
        split.addArrangedSubview(rightPane.container)
        root.addSubview(split)
        NSLayoutConstraint.activate([
            split.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            split.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            split.topAnchor.constraint(equalTo: root.topAnchor),
            split.bottomAnchor.constraint(equalTo: root.bottomAnchor),
        ])

        self.view = root

        // Synchronise vertical scroll between the two tables.
        NotificationCenter.default.addObserver(self, selector: #selector(syncScroll(_:)), name: NSView.boundsDidChangeNotification, object: leftPane.scrollView.contentView)
        NotificationCenter.default.addObserver(self, selector: #selector(syncScroll(_:)), name: NSView.boundsDidChangeNotification, object: rightPane.scrollView.contentView)
        leftPane.scrollView.contentView.postsBoundsChangedNotifications = true
        rightPane.scrollView.contentView.postsBoundsChangedNotifications = true
        self.leftScrollView = leftPane.scrollView
        self.rightScrollView = rightPane.scrollView
        self.leftTable = leftPane.table
        self.rightTable = rightPane.table

        leftPane.table.reloadData()
        rightPane.table.reloadData()
    }

    deinit { NotificationCenter.default.removeObserver(self) }

    private weak var leftScrollView: NSScrollView?
    private weak var rightScrollView: NSScrollView?
    private weak var leftTable: NSTableView?
    private weak var rightTable: NSTableView?
    private var scrollSyncing = false

    @objc private func syncScroll(_ n: Notification) {
        guard !scrollSyncing, let source = n.object as? NSClipView else { return }
        scrollSyncing = true
        defer { scrollSyncing = false }
        let other: NSClipView?
        if source === leftScrollView?.contentView {
            other = rightScrollView?.contentView
        } else {
            other = leftScrollView?.contentView
        }
        if let other = other {
            var pt = other.bounds.origin
            pt.y = source.bounds.origin.y
            other.scroll(to: pt)
        }
    }

    private struct Pane {
        let container: NSView
        let scrollView: NSScrollView
        let table: NSTableView
    }

    private func makePane(title: String, side: Side) -> Pane {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let header = NSTextField(labelWithString: title)
        header.font = NSFont.boldSystemFont(ofSize: 12)
        header.translatesAutoresizingMaskIntoConstraints = false
        header.lineBreakMode = .byTruncatingMiddle

        let scroll = NSScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = true
        scroll.autohidesScrollers = false
        scroll.borderType = .noBorder
        scroll.drawsBackground = true
        scroll.backgroundColor = NSColor.textBackgroundColor

        let table = DiffTableView()
        table.headerView = nil
        table.usesAlternatingRowBackgroundColors = false
        table.gridStyleMask = []
        table.rowSizeStyle = .small
        table.allowsMultipleSelection = false
        let lineCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("line"))
        lineCol.width = 44
        let contentCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(side == .left ? "left" : "right"))
        contentCol.resizingMask = .autoresizingMask
        table.addTableColumn(lineCol)
        table.addTableColumn(contentCol)
        table.dataSource = self
        table.delegate = self
        table.side = side
        scroll.documentView = table

        container.addSubview(header)
        container.addSubview(scroll)
        NSLayoutConstraint.activate([
            header.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),
            header.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -8),
            header.topAnchor.constraint(equalTo: container.topAnchor, constant: 6),

            scroll.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            scroll.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 6),
            scroll.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
        return Pane(container: container, scrollView: scroll, table: table)
    }

    // MARK: NSTableViewDataSource

    func numberOfRows(in tableView: NSTableView) -> Int { rows.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let table = tableView as? DiffTableView else { return nil }
        let r = rows[row]
        let cell = NSTableCellView()
        let label = NSTextField(labelWithString: "")
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        label.lineBreakMode = .byClipping
        label.maximumNumberOfLines = 1

        switch tableColumn?.identifier.rawValue {
        case "line":
            let num: Int? = (table.side == .left) ? r.leftLine : r.rightLine
            label.stringValue = num.map { "\($0)" } ?? ""
            label.alignment = .right
            label.textColor = .secondaryLabelColor
            label.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        case "left":
            let line: String? = r.leftLine.flatMap { idx in idx - 1 < leftLines.count ? leftLines[idx - 1] : nil }
            label.stringValue = line ?? ""
        case "right":
            let line: String? = r.rightLine.flatMap { idx in idx - 1 < rightLines.count ? rightLines[idx - 1] : nil }
            label.stringValue = line ?? ""
        default:
            break
        }
        cell.addSubview(label)
        cell.textField = label
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 6),
            label.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -6),
            label.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
        ])
        return cell
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        guard let table = tableView as? DiffTableView else { return nil }
        let r = rows[row]
        let rv = DiffRowView()
        switch r.kind {
        case .unchanged:
            rv.tint = nil
        case .removed:
            // Tint applies only to the side that owns this row.
            rv.tint = (table.side == .left) ? NSColor.systemRed.withAlphaComponent(0.18) : nil
        case .added:
            rv.tint = (table.side == .right) ? NSColor.systemGreen.withAlphaComponent(0.18) : nil
        }
        return rv
    }
}

private final class DiffTableView: NSTableView {
    var side: DiffViewController.Side = .left
}

extension DiffViewController {
    enum Side { case left, right }
}

private final class DiffRowView: NSTableRowView {
    var tint: NSColor?
    override func drawBackground(in dirtyRect: NSRect) {
        if let tint = tint {
            tint.setFill()
            dirtyRect.fill()
        } else {
            super.drawBackground(in: dirtyRect)
        }
    }
}
