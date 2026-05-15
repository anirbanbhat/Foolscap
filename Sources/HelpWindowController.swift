import AppKit

final class HelpWindowController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate {

    private struct Topic {
        let url: URL
        let title: String
    }

    private var topics: [Topic] = []
    private var topicTable: NSTableView!
    private var contentTextView: NSTextView!

    static var shared: HelpWindowController?

    static func show() {
        if let existing = shared {
            existing.window?.makeKeyAndOrderFront(nil)
            return
        }
        let wc = HelpWindowController()
        shared = wc
        wc.showWindow(nil)
    }

    init() {
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 820, height: 600),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false)
        win.title = "Foolscap User Guide"
        win.setFrameAutosaveName("foolscap.help.window")
        super.init(window: win)
        win.delegate = self
        buildUI()
        loadTopics()
        if !topics.isEmpty {
            topicTable.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
            renderTopic(topics[0])
        }
    }

    required init?(coder: NSCoder) { fatalError() }

    private func buildUI() {
        guard let content = window?.contentView else { return }

        let split = NSSplitView()
        split.isVertical = true
        split.dividerStyle = .thin
        split.translatesAutoresizingMaskIntoConstraints = false

        // Sidebar
        let sidebarScroll = NSScrollView()
        sidebarScroll.hasVerticalScroller = true
        sidebarScroll.autohidesScrollers = true
        sidebarScroll.borderType = .noBorder
        topicTable = NSTableView()
        topicTable.headerView = nil
        topicTable.dataSource = self
        topicTable.delegate = self
        topicTable.style = .sourceList
        topicTable.allowsMultipleSelection = false
        topicTable.usesAutomaticRowHeights = false
        topicTable.rowHeight = 28
        let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("topic"))
        col.title = "Topic"
        col.resizingMask = .autoresizingMask
        topicTable.addTableColumn(col)
        sidebarScroll.documentView = topicTable

        // Content
        let contentScroll = NSScrollView()
        contentScroll.hasVerticalScroller = true
        contentScroll.borderType = .noBorder
        contentScroll.drawsBackground = true
        contentScroll.backgroundColor = NSColor.textBackgroundColor

        contentTextView = NSTextView()
        contentTextView.isEditable = false
        contentTextView.isSelectable = true
        contentTextView.isRichText = true
        contentTextView.drawsBackground = true
        contentTextView.backgroundColor = NSColor.textBackgroundColor
        contentTextView.textContainerInset = NSSize(width: 18, height: 18)
        contentTextView.minSize = NSSize(width: 0, height: 0)
        contentTextView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        contentTextView.isVerticallyResizable = true
        contentTextView.isHorizontallyResizable = false
        contentTextView.autoresizingMask = [.width]
        contentTextView.textContainer?.widthTracksTextView = true
        contentScroll.documentView = contentTextView

        split.addArrangedSubview(sidebarScroll)
        split.addArrangedSubview(contentScroll)
        split.setHoldingPriority(.defaultLow + 1, forSubviewAt: 1)

        content.addSubview(split)
        split.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            split.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            split.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            split.topAnchor.constraint(equalTo: content.topAnchor),
            split.bottomAnchor.constraint(equalTo: content.bottomAnchor),
        ])

        DispatchQueue.main.async { split.setPosition(220, ofDividerAt: 0) }
    }

    private func loadTopics() {
        let fm = FileManager.default
        guard let docDir = HelpWindowController.docDirectoryURL() else { return }
        let urls = (try? fm.contentsOfDirectory(at: docDir, includingPropertiesForKeys: nil)) ?? []
        let mdURLs = urls.filter { $0.pathExtension.lowercased() == "md" }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
        topics = mdURLs.map { Topic(url: $0, title: HelpWindowController.titleFromFilename($0.lastPathComponent)) }
        topicTable.reloadData()
    }

    static func docDirectoryURL() -> URL? {
        if let bundled = Bundle.main.url(forResource: "doc", withExtension: nil) {
            return bundled
        }
        // Dev fallback — look next to the executable for the source-tree doc folder.
        let fm = FileManager.default
        let exe = Bundle.main.bundleURL
        let candidates = [
            exe.deletingLastPathComponent().appendingPathComponent("doc"),
            exe.deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("doc"),
        ]
        for c in candidates where fm.fileExists(atPath: c.path) { return c }
        return nil
    }

    private static func titleFromFilename(_ name: String) -> String {
        var t = (name as NSString).deletingPathExtension
        // Strip a leading "01-", "02-" sort prefix.
        if let r = t.range(of: #"^\d+-"#, options: .regularExpression) {
            t.removeSubrange(r)
        }
        return t.replacingOccurrences(of: "-", with: " ")
    }

    private func renderTopic(_ topic: Topic) {
        let markdown = (try? String(contentsOf: topic.url, encoding: .utf8)) ?? "(failed to read \(topic.url.lastPathComponent))"
        let attr = MarkdownRenderer.render(markdown)
        contentTextView.textStorage?.setAttributedString(attr)
    }

    // MARK: NSTableView

    func numberOfRows(in tableView: NSTableView) -> Int { topics.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let cell = NSTableCellView()
        let label = NSTextField(labelWithString: topics[row].title)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = NSFont.systemFont(ofSize: 12)
        label.lineBreakMode = .byTruncatingTail
        cell.textField = label
        cell.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 8),
            label.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -6),
            label.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
        ])
        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        let row = topicTable.selectedRow
        guard row >= 0 && row < topics.count else { return }
        renderTopic(topics[row])
    }
}

extension HelpWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        HelpWindowController.shared = nil
    }
}
