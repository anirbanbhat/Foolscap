import AppKit

final class WorkspaceWindowController: NSWindowController, NSOutlineViewDataSource, NSOutlineViewDelegate, NSTabViewDelegate {

    let rootURL: URL
    private let rootNode: FileTreeNode

    private var splitView: NSSplitView!
    private var outlineView: NSOutlineView!
    private var tabView: NSTabView!

    private var openFiles: [WorkspaceFile] = []
    private var fileItemMap: [ObjectIdentifier: NSTabViewItem] = [:]

    // MRU = tab indices in most-recently-used order (front = most recent).
    private var mruOrder: [Int] = []

    static var allWorkspaces: [WorkspaceWindowController] = []

    init(folderURL: URL) {
        self.rootURL = folderURL
        self.rootNode = FileTreeNode(url: folderURL, isDirectory: true)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1100, height: 720),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false)
        window.title = folderURL.lastPathComponent
        window.setFrameAutosaveName("foolscap.workspace.\(folderURL.path)")

        super.init(window: window)

        buildUI()
        window.delegate = self
        WorkspaceWindowController.allWorkspaces.append(self)
    }

    required init?(coder: NSCoder) { fatalError() }

    private func buildUI() {
        guard let window = self.window else { return }

        splitView = NSSplitView()
        splitView.isVertical = true
        splitView.dividerStyle = .thin
        splitView.translatesAutoresizingMaskIntoConstraints = false

        // Sidebar
        let sidebarScroll = NSScrollView()
        sidebarScroll.hasVerticalScroller = true
        sidebarScroll.autohidesScrollers = true
        sidebarScroll.borderType = .noBorder
        sidebarScroll.translatesAutoresizingMaskIntoConstraints = false

        outlineView = NSOutlineView()
        outlineView.headerView = nil
        outlineView.style = .sourceList
        outlineView.dataSource = self
        outlineView.delegate = self
        outlineView.allowsMultipleSelection = false
        outlineView.indentationPerLevel = 14
        outlineView.target = self
        outlineView.doubleAction = #selector(outlineDoubleClicked(_:))
        outlineView.action = #selector(outlineClicked(_:))
        let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        col.title = "Name"
        col.isEditable = false
        col.resizingMask = .autoresizingMask
        outlineView.addTableColumn(col)
        outlineView.outlineTableColumn = col

        sidebarScroll.documentView = outlineView

        // Tab view
        let tabContainer = NSView()
        tabContainer.translatesAutoresizingMaskIntoConstraints = false

        tabView = NSTabView()
        tabView.tabViewType = .topTabsBezelBorder
        tabView.translatesAutoresizingMaskIntoConstraints = false
        tabView.delegate = self
        tabContainer.addSubview(tabView)

        let emptyLabel = NSTextField(labelWithString: "Select a file from the sidebar to open it.")
        emptyLabel.textColor = NSColor.tertiaryLabelColor
        emptyLabel.font = NSFont.systemFont(ofSize: 13)
        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        emptyLabel.identifier = NSUserInterfaceItemIdentifier("emptyHint")
        tabContainer.addSubview(emptyLabel)

        NSLayoutConstraint.activate([
            tabView.leadingAnchor.constraint(equalTo: tabContainer.leadingAnchor),
            tabView.trailingAnchor.constraint(equalTo: tabContainer.trailingAnchor),
            tabView.topAnchor.constraint(equalTo: tabContainer.topAnchor),
            tabView.bottomAnchor.constraint(equalTo: tabContainer.bottomAnchor),
            emptyLabel.centerXAnchor.constraint(equalTo: tabContainer.centerXAnchor),
            emptyLabel.centerYAnchor.constraint(equalTo: tabContainer.centerYAnchor),
        ])

        splitView.addArrangedSubview(sidebarScroll)
        splitView.addArrangedSubview(tabContainer)
        splitView.setHoldingPriority(.defaultLow + 1, forSubviewAt: 1)

        let content = NSView()
        content.addSubview(splitView)
        NSLayoutConstraint.activate([
            splitView.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            splitView.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            splitView.topAnchor.constraint(equalTo: content.topAnchor),
            splitView.bottomAnchor.constraint(equalTo: content.bottomAnchor),
        ])
        window.contentView = content

        DispatchQueue.main.async {
            self.splitView.setPosition(260, ofDividerAt: 0)
            self.outlineView.reloadData()
            self.outlineView.expandItem(self.rootNode)
        }
    }

    // MARK: Open / focus / close

    @discardableResult
    func openFile(at url: URL) -> WorkspaceFile? {
        if let existing = openFiles.first(where: { $0.url == url }) {
            focusFile(existing)
            return existing
        }
        let file: WorkspaceFile
        do {
            file = try WorkspaceFile.load(from: url)
        } catch {
            NSAlert(error: error).runModal()
            return nil
        }
        file.owner = self

        let container = TabContainerViewController(file: file)

        let item = NSTabViewItem(viewController: container)
        item.label = file.editorTitle
        tabView.addTabViewItem(item)
        fileItemMap[ObjectIdentifier(file)] = item
        openFiles.append(file)
        tabView.selectTabViewItem(item)
        bumpMRU(forIndex: tabView.indexOfTabViewItem(item))
        updateEmptyHint()
        return file
    }

    func focusFile(_ file: WorkspaceFile) {
        guard let item = fileItemMap[ObjectIdentifier(file)] else { return }
        tabView.selectTabViewItem(item)
        bumpMRU(forIndex: tabView.indexOfTabViewItem(item))
    }

    func closeCurrentTab() {
        guard let item = tabView.selectedTabViewItem else { return }
        guard let file = openFiles.first(where: { fileItemMap[ObjectIdentifier($0)] === item }) else { return }
        if file.isEdited {
            let alert = NSAlert()
            alert.messageText = "Save changes to \(file.url.lastPathComponent)?"
            alert.informativeText = "Your changes will be lost if you don't save them."
            alert.addButton(withTitle: "Save")
            alert.addButton(withTitle: "Discard")
            alert.addButton(withTitle: "Cancel")
            let r = alert.runModal()
            if r == .alertFirstButtonReturn {
                do { try file.save() } catch { NSAlert(error: error).runModal(); return }
            } else if r == .alertThirdButtonReturn {
                return
            }
        }
        let idx = tabView.indexOfTabViewItem(item)
        tabView.removeTabViewItem(item)
        fileItemMap.removeValue(forKey: ObjectIdentifier(file))
        openFiles.removeAll { $0 === file }
        // Rebuild MRU (indices shifted).
        rebuildMRU(removingIndex: idx)
        updateEmptyHint()
    }

    func saveCurrentTab() {
        guard let item = tabView.selectedTabViewItem,
              let file = openFiles.first(where: { fileItemMap[ObjectIdentifier($0)] === item })
        else { return }
        do {
            try file.save()
        } catch {
            NSAlert(error: error).runModal()
        }
    }

    // Called by WorkspaceFile after edit/save.
    func fileDidChangeEditedState(_ file: WorkspaceFile) {
        guard let item = fileItemMap[ObjectIdentifier(file)] else { return }
        let pin = file.isPinned ? "● " : ""
        let dirty = file.isEdited ? "• " : ""
        item.label = pin + dirty + file.editorTitle
    }

    // MARK: Pin + reorder

    @IBAction func togglePinActiveTab(_ sender: Any?) {
        guard let item = tabView.selectedTabViewItem,
              let container = item.viewController as? TabContainerViewController,
              let file = container.file else { NSSound.beep(); return }
        file.isPinned.toggle()
        fileDidChangeEditedState(file)
        resortTabsKeepingSelection()
    }

    @IBAction func moveActiveTabLeft(_ sender: Any?) {
        guard let item = tabView.selectedTabViewItem else { return }
        let idx = tabView.indexOfTabViewItem(item)
        guard idx > 0 else { NSSound.beep(); return }
        let leftItem = tabView.tabViewItems[idx - 1]
        if pinState(of: leftItem) && !pinState(of: item) {
            NSSound.beep(); return   // can't cross into pinned zone
        }
        tabView.removeTabViewItem(item)
        tabView.insertTabViewItem(item, at: idx - 1)
        tabView.selectTabViewItem(item)
    }

    @IBAction func moveActiveTabRight(_ sender: Any?) {
        guard let item = tabView.selectedTabViewItem else { return }
        let idx = tabView.indexOfTabViewItem(item)
        guard idx < tabView.numberOfTabViewItems - 1 else { NSSound.beep(); return }
        let rightItem = tabView.tabViewItems[idx + 1]
        if pinState(of: item) && !pinState(of: rightItem) {
            NSSound.beep(); return   // a pinned tab can't move past its boundary
        }
        tabView.removeTabViewItem(item)
        tabView.insertTabViewItem(item, at: idx + 1)
        tabView.selectTabViewItem(item)
    }

    private func pinState(of item: NSTabViewItem) -> Bool {
        guard let c = item.viewController as? TabContainerViewController, let f = c.file else { return false }
        return f.isPinned
    }

    private func resortTabsKeepingSelection() {
        let items = tabView.tabViewItems
        let pinned = items.filter { pinState(of: $0) }
        let unpinned = items.filter { !pinState(of: $0) }
        let newOrder = pinned + unpinned
        if newOrder.map({ ObjectIdentifier($0) }) == items.map({ ObjectIdentifier($0) }) { return }
        let selected = tabView.selectedTabViewItem
        for item in items { tabView.removeTabViewItem(item) }
        for item in newOrder { tabView.addTabViewItem(item) }
        if let selected = selected { tabView.selectTabViewItem(selected) }
    }

    func fileDidSave(_ file: WorkspaceFile) {
        fileDidChangeEditedState(file)
        for ed in file.editors { ed.handleDocumentCleared() }
    }

    private func updateEmptyHint() {
        guard let hint = window?.contentView?.subviews.first(where: { $0.identifier?.rawValue == "emptyHint" }) as? NSTextField else {
            // Hint is nested in tabContainer; search recursively.
            findEmptyHint()?.isHidden = !openFiles.isEmpty
            return
        }
        hint.isHidden = !openFiles.isEmpty
    }

    private func findEmptyHint() -> NSTextField? {
        guard let root = window?.contentView else { return nil }
        var stack: [NSView] = [root]
        while let v = stack.popLast() {
            if let tf = v as? NSTextField, tf.identifier?.rawValue == "emptyHint" { return tf }
            stack.append(contentsOf: v.subviews)
        }
        return nil
    }

    // MARK: MRU

    private func bumpMRU(forIndex idx: Int) {
        guard idx >= 0 else { return }
        mruOrder.removeAll { $0 == idx }
        mruOrder.insert(idx, at: 0)
    }

    private func rebuildMRU(removingIndex removed: Int) {
        var rebuilt: [Int] = []
        for old in mruOrder where old != removed {
            rebuilt.append(old > removed ? old - 1 : old)
        }
        mruOrder = rebuilt
    }

    @IBAction func cycleTabsMRU(_ sender: Any?) {
        // Go to next-most-recent (index 1 if exists, else first non-current).
        guard tabView.numberOfTabViewItems > 1 else { return }
        let current = tabView.indexOfTabViewItem(tabView.selectedTabViewItem ?? NSTabViewItem())
        let target: Int
        if mruOrder.count >= 2 {
            target = mruOrder[1]
        } else {
            target = (current + 1) % tabView.numberOfTabViewItems
        }
        if target >= 0 && target < tabView.numberOfTabViewItems {
            tabView.selectTabViewItem(at: target)
            bumpMRU(forIndex: target)
        }
    }

    @IBAction func cycleTabsMRUReverse(_ sender: Any?) {
        guard tabView.numberOfTabViewItems > 1 else { return }
        if let last = mruOrder.last, last < tabView.numberOfTabViewItems {
            tabView.selectTabViewItem(at: last)
            bumpMRU(forIndex: last)
        }
    }

    // MARK: NSTabViewDelegate

    func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
        guard let item = tabViewItem else { return }
        bumpMRU(forIndex: tabView.indexOfTabViewItem(item))
        if let container = item.viewController as? TabContainerViewController, let primary = container.primary {
            // Force the editor's view tree to lay out *now* — without this,
            // tabs that were added while the main thread was previously
            // blocked could become visible with a zero-frame text view.
            container.view.needsLayout = true
            container.view.layoutSubtreeIfNeeded()
            primary.textView.needsLayout = true
            primary.textView.needsDisplay = true
            window?.makeFirstResponder(primary.textView)
        }
    }

    // MARK: NSOutlineViewDataSource

    func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
        let node = (item as? FileTreeNode) ?? rootNode
        return node.children.count
    }

    func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
        let node = (item as? FileTreeNode) ?? rootNode
        return node.children[index]
    }

    func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
        guard let node = item as? FileTreeNode else { return false }
        return node.isDirectory
    }

    // MARK: NSOutlineViewDelegate

    func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
        guard let node = item as? FileTreeNode else { return nil }
        let cell = NSTableCellView()

        let icon = NSImageView()
        icon.translatesAutoresizingMaskIntoConstraints = false
        let image = FileIcon.icon(for: node.url, isDirectory: node.isDirectory)
        image.size = NSSize(width: 16, height: 16)
        icon.image = image

        let text = NSTextField(labelWithString: node.name)
        text.translatesAutoresizingMaskIntoConstraints = false
        text.font = NSFont.systemFont(ofSize: 12)
        text.lineBreakMode = .byTruncatingTail

        cell.addSubview(icon)
        cell.addSubview(text)
        cell.imageView = icon
        cell.textField = text

        NSLayoutConstraint.activate([
            icon.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 2),
            icon.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 16),
            icon.heightAnchor.constraint(equalToConstant: 16),
            text.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 4),
            text.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -2),
            text.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
        ])
        return cell
    }

    @objc private func outlineClicked(_ sender: Any?) {
        // Single click — only open files, not directories.
        guard let node = outlineView.item(atRow: outlineView.selectedRow) as? FileTreeNode,
              !node.isDirectory else { return }
        openFile(at: node.url)
    }

    @objc private func outlineDoubleClicked(_ sender: Any?) {
        guard let node = outlineView.item(atRow: outlineView.clickedRow) as? FileTreeNode else { return }
        if node.isDirectory {
            if outlineView.isItemExpanded(node) {
                outlineView.collapseItem(node)
            } else {
                outlineView.expandItem(node)
            }
        }
    }

    // MARK: Find in Files

    @IBAction func showFindInFiles(_ sender: Any?) {
        FindInFiles.present(in: self)
    }

    // MARK: Quick switchers

    private var activeQuickPanel: QuickPanelController?

    @IBAction func showQuickFileSwitcher(_ sender: Any?) {
        let entries = FileIndex.walk(root: rootURL)
        let items = entries.map { e in
            QuickPanelController.Item(
                title: e.url.lastPathComponent,
                subtitle: e.relativePath,
                key: e.relativePath,
                payload: e.url
            )
        }
        let panel = QuickPanelController()
        panel.placeholder = "Go to file…"
        panel.items = items
        panel.onSelect = { [weak self] item in
            self?.activeQuickPanel = nil
            if let url = item.payload as? URL {
                self?.openFile(at: url)
            }
        }
        if let win = self.window {
            activeQuickPanel = panel
            panel.present(over: win)
            NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: panel.window, queue: .main) { [weak self] _ in
                self?.activeQuickPanel = nil
            }
        }
    }

    @IBAction func showSymbolSwitcher(_ sender: Any?) {
        guard let item = tabView.selectedTabViewItem,
              let container = item.viewController as? TabContainerViewController,
              let editor = container.primary,
              let file = container.file else {
            NSSound.beep(); return
        }
        let text = editor.currentText() ?? ""
        let symbols = SymbolExtractor.symbols(in: text, language: file.detectedLanguage)
        guard !symbols.isEmpty else {
            NSSound.beep(); return
        }
        let items = symbols.map { sym in
            QuickPanelController.Item(
                title: sym.name,
                subtitle: "\(sym.kind) — line \(sym.lineNumber)",
                key: sym.name,
                payload: sym
            )
        }
        let panel = QuickPanelController()
        panel.placeholder = "Go to symbol…"
        panel.items = items
        panel.onSelect = { [weak self] item in
            self?.activeQuickPanel = nil
            if let sym = item.payload as? SourceSymbol {
                editor.jumpToLine(sym.lineNumber)
            }
        }
        if let win = self.window {
            activeQuickPanel = panel
            panel.present(over: win)
            NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: panel.window, queue: .main) { [weak self] _ in
                self?.activeQuickPanel = nil
            }
        }
    }

    // MARK: Split actions

    @IBAction func splitCurrentTab(_ sender: Any?) {
        guard let item = tabView.selectedTabViewItem,
              let container = item.viewController as? TabContainerViewController else { return }
        container.split()
    }

    @IBAction func unsplitCurrentTab(_ sender: Any?) {
        guard let item = tabView.selectedTabViewItem,
              let container = item.viewController as? TabContainerViewController else { return }
        container.unsplit()
    }
}

extension WorkspaceWindowController: NSWindowDelegate {

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        let dirty = openFiles.filter { $0.isEdited }
        if dirty.isEmpty { return true }
        let alert = NSAlert()
        alert.messageText = "Save changes to \(dirty.count) file\(dirty.count == 1 ? "" : "s")?"
        alert.addButton(withTitle: "Save All")
        alert.addButton(withTitle: "Discard")
        alert.addButton(withTitle: "Cancel")
        let r = alert.runModal()
        if r == .alertFirstButtonReturn {
            for f in dirty {
                do { try f.save() }
                catch { NSAlert(error: error).runModal(); return false }
            }
        } else if r == .alertThirdButtonReturn {
            return false
        }
        return true
    }

    func windowWillClose(_ notification: Notification) {
        WorkspaceWindowController.allWorkspaces.removeAll { $0 === self }
    }
}
