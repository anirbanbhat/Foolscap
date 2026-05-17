import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {

    private static let sessionKey = "foolscap.session.openURLs"
    private static let workspaceSessionKey = "foolscap.session.workspaces"

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = true
        buildMainMenu()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationWillTerminate(_ notification: Notification) {
        let urls = NSDocumentController.shared.documents.compactMap { $0.fileURL?.absoluteString }
        UserDefaults.standard.set(urls, forKey: AppDelegate.sessionKey)
        let workspaces = WorkspaceWindowController.allWorkspaces.map { $0.rootURL.absoluteString }
        UserDefaults.standard.set(workspaces, forKey: AppDelegate.workspaceSessionKey)
    }

    func applicationOpenUntitledFile(_ sender: NSApplication) -> Bool {
        var openedAnything = false

        let workspaces = (UserDefaults.standard.stringArray(forKey: AppDelegate.workspaceSessionKey) ?? [])
            .compactMap(URL.init(string:))
            .filter { FileManager.default.fileExists(atPath: $0.path) }
        for url in workspaces {
            openWorkspace(at: url)
            openedAnything = true
        }

        let raw = UserDefaults.standard.stringArray(forKey: AppDelegate.sessionKey) ?? []
        let urls = raw.compactMap(URL.init(string:))
            .filter { FileManager.default.fileExists(atPath: $0.path) }
        for url in urls {
            NSDocumentController.shared.openDocument(withContentsOf: url, display: true) { _, _, _ in }
            openedAnything = true
        }

        return openedAnything
    }

    // MARK: Workspace actions

    private var diffWindows: [NSWindowController] = []

    @IBAction func toggleTailMode(_ sender: Any?) {
        // Only applies to a standalone Document window (the typical "open a
        // log file" case). No-op otherwise.
        guard let doc = NSDocumentController.shared.currentDocument as? Document else {
            NSSound.beep(); return
        }
        doc.isTailing.toggle()
        doc.editorViewController?.setReadOnly(doc.isTailing)
        if doc.isTailing {
            doc.editorViewController?.scrollToEnd()
        }
        if let menu = sender as? NSMenuItem {
            menu.state = doc.isTailing ? .on : .off
        }
    }

    @IBAction func compareTwoFiles(_ sender: Any?) {
        let leftPanel = NSOpenPanel()
        leftPanel.message = "Choose the LEFT file"
        leftPanel.allowsMultipleSelection = false
        leftPanel.canChooseDirectories = false
        guard leftPanel.runModal() == .OK, let left = leftPanel.url else { return }

        let rightPanel = NSOpenPanel()
        rightPanel.message = "Choose the RIGHT file"
        rightPanel.allowsMultipleSelection = false
        rightPanel.canChooseDirectories = false
        guard rightPanel.runModal() == .OK, let right = rightPanel.url else { return }

        let vc = DiffViewController(left: left, right: right)
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1100, height: 720),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        win.title = "Diff: \(left.lastPathComponent) ↔ \(right.lastPathComponent)"
        win.contentViewController = vc
        let wc = NSWindowController(window: win)
        wc.showWindow(nil)
        diffWindows.append(wc)
    }

    @IBAction func openFolder(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Open"
        panel.message = "Choose a folder to open as workspace"
        guard panel.runModal() == .OK, let url = panel.url else { return }

        // If a workspace window is already key, ask: replace it, or open a
        // new window? If none is open, skip the prompt and just open a new one.
        let activeWorkspace = NSApp.keyWindow?.windowController as? WorkspaceWindowController
        if let active = activeWorkspace, active.rootURL != url {
            let alert = NSAlert()
            alert.messageText = "Open '\(url.lastPathComponent)' as a workspace?"
            alert.informativeText = "Open in the current window (replacing '\(active.rootURL.lastPathComponent)') or in a new window?"
            alert.addButton(withTitle: "New Window")
            alert.addButton(withTitle: "Current Window")
            alert.addButton(withTitle: "Cancel")
            let resp = alert.runModal()
            switch resp {
            case .alertFirstButtonReturn:
                openWorkspace(at: url)
            case .alertSecondButtonReturn:
                replaceWorkspace(active, with: url)
            default:
                return
            }
        } else {
            openWorkspace(at: url)
        }
    }

    private func openWorkspace(at url: URL) {
        if let existing = WorkspaceWindowController.allWorkspaces.first(where: { $0.rootURL == url }) {
            existing.window?.makeKeyAndOrderFront(nil)
            return
        }
        let wc = WorkspaceWindowController(folderURL: url)
        wc.showWindow(nil)
    }

    /// Replace the current workspace window: close it (honouring unsaved
    /// changes) then open a new one at the chosen URL at the same screen
    /// location.
    private func replaceWorkspace(_ existing: WorkspaceWindowController, with url: URL) {
        let frame = existing.window?.frame
        guard existing.window?.delegate?.windowShouldClose?(existing.window!) ?? true else { return }
        existing.window?.close()
        let wc = WorkspaceWindowController(folderURL: url)
        if let f = frame { wc.window?.setFrame(f, display: true) }
        wc.showWindow(nil)
    }

    // Workspace-aware actions: when a workspace window is key, route to it.

    @IBAction func saveActiveTab(_ sender: Any?) {
        if let wc = NSApp.keyWindow?.windowController as? WorkspaceWindowController {
            wc.saveCurrentTab()
        } else {
            NSApp.sendAction(#selector(NSDocument.save(_:)), to: nil, from: sender)
        }
    }

    @IBAction func closeActiveTab(_ sender: Any?) {
        if let wc = NSApp.keyWindow?.windowController as? WorkspaceWindowController {
            wc.closeCurrentTab()
        } else {
            NSApp.sendAction(#selector(NSWindow.performClose(_:)), to: nil, from: sender)
        }
    }

    @IBAction func findInWorkspace(_ sender: Any?) {
        guard let wc = NSApp.keyWindow?.windowController as? WorkspaceWindowController else {
            NSSound.beep(); return
        }
        wc.showFindInFiles(sender)
    }

    @IBAction func cycleTabsMRU(_ sender: Any?) {
        if let wc = NSApp.keyWindow?.windowController as? WorkspaceWindowController {
            wc.cycleTabsMRU(sender)
        }
    }

    @IBAction func cycleTabsMRUReverse(_ sender: Any?) {
        if let wc = NSApp.keyWindow?.windowController as? WorkspaceWindowController {
            wc.cycleTabsMRUReverse(sender)
        }
    }

    @IBAction func selectNextTab(_ sender: Any?) {
        if let wc = NSApp.keyWindow?.windowController as? WorkspaceWindowController {
            wc.selectNextTab(sender)
        }
    }

    @IBAction func selectPreviousTab(_ sender: Any?) {
        if let wc = NSApp.keyWindow?.windowController as? WorkspaceWindowController {
            wc.selectPreviousTab(sender)
        }
    }

    @IBAction func quickFileSwitcher(_ sender: Any?) {
        if let wc = NSApp.keyWindow?.windowController as? WorkspaceWindowController {
            wc.showQuickFileSwitcher(sender)
        } else {
            NSSound.beep()
        }
    }

    @IBAction func quickSymbolSwitcher(_ sender: Any?) {
        if let wc = NSApp.keyWindow?.windowController as? WorkspaceWindowController {
            wc.showSymbolSwitcher(sender)
        } else {
            NSSound.beep()
        }
    }

    @IBAction func splitEditor(_ sender: Any?) {
        if let wc = NSApp.keyWindow?.windowController as? WorkspaceWindowController {
            wc.splitCurrentTab(sender)
        }
    }

    @IBAction func toggleActiveTabPin(_ sender: Any?) {
        if let wc = NSApp.keyWindow?.windowController as? WorkspaceWindowController {
            wc.togglePinActiveTab(sender)
        } else { NSSound.beep() }
    }

    @IBAction func moveTabLeftAction(_ sender: Any?) {
        if let wc = NSApp.keyWindow?.windowController as? WorkspaceWindowController {
            wc.moveActiveTabLeft(sender)
        } else { NSSound.beep() }
    }

    @IBAction func moveTabRightAction(_ sender: Any?) {
        if let wc = NSApp.keyWindow?.windowController as? WorkspaceWindowController {
            wc.moveActiveTabRight(sender)
        } else { NSSound.beep() }
    }

    @IBAction func selectTheme(_ sender: Any?) {
        guard let item = sender as? NSMenuItem, let id = item.representedObject as? String,
              let theme = ThemeRegistry.theme(withID: id) else { return }
        ThemeRegistry.setCurrent(theme)
        SyntaxHighlighter.invalidateRuleCache()
        // Update checkmarks
        if let parent = item.menu {
            for sibling in parent.items { sibling.state = (sibling === item) ? .on : .off }
        }
    }

    @IBAction func closeSplit(_ sender: Any?) {
        if let wc = NSApp.keyWindow?.windowController as? WorkspaceWindowController {
            wc.unsplitCurrentTab(sender)
        }
    }

    // MARK: Menu

    private func buildMainMenu() {
        let mainMenu = NSMenu()

        // App menu
        let appItem = NSMenuItem()
        mainMenu.addItem(appItem)
        let appMenu = NSMenu()
        appItem.submenu = appMenu
        let appName = ProcessInfo.processInfo.processName
        appMenu.addItem(withTitle: "About \(appName)", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        let services = NSMenuItem(title: "Services", action: nil, keyEquivalent: "")
        let servicesMenu = NSMenu()
        services.submenu = servicesMenu
        NSApp.servicesMenu = servicesMenu
        appMenu.addItem(services)
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Hide \(appName)", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        let hideOthers = NSMenuItem(title: "Hide Others", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        hideOthers.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(hideOthers)
        appMenu.addItem(withTitle: "Show All", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: "")
        appMenu.addItem(NSMenuItem.separator())
        appMenu.addItem(withTitle: "Quit \(appName)", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        // File menu
        let fileItem = NSMenuItem()
        mainMenu.addItem(fileItem)
        let fileMenu = NSMenu(title: "File")
        fileItem.submenu = fileMenu
        fileMenu.addItem(withTitle: "New", action: #selector(NSDocumentController.newDocument(_:)), keyEquivalent: "n")
        fileMenu.addItem(withTitle: "Open…", action: #selector(NSDocumentController.openDocument(_:)), keyEquivalent: "o")
        let openFolderItem = NSMenuItem(title: "Open Folder…", action: #selector(openFolder(_:)), keyEquivalent: "o")
        openFolderItem.keyEquivalentModifierMask = [.command, .shift]
        openFolderItem.target = self
        fileMenu.addItem(openFolderItem)
        // Note: macOS auto-injects the "Open Recent" submenu (with the clock
        // glyph) when the app declares document types in Info.plist and has
        // standard NSDocumentController actions wired above. We don't add a
        // second one manually here — doing so produced a duplicate item.
        fileMenu.addItem(NSMenuItem.separator())
        let close = NSMenuItem(title: "Close", action: #selector(closeActiveTab(_:)), keyEquivalent: "w")
        close.target = self
        fileMenu.addItem(close)
        let save = NSMenuItem(title: "Save", action: #selector(saveActiveTab(_:)), keyEquivalent: "s")
        save.target = self
        fileMenu.addItem(save)
        let saveAs = NSMenuItem(title: "Save As…", action: #selector(NSDocument.saveAs(_:)), keyEquivalent: "S")
        saveAs.keyEquivalentModifierMask = [.command, .shift]
        fileMenu.addItem(saveAs)
        fileMenu.addItem(withTitle: "Revert to Saved", action: #selector(NSDocument.revertToSaved(_:)), keyEquivalent: "")
        fileMenu.addItem(NSMenuItem.separator())
        let compareItem = NSMenuItem(title: "Compare Two Files…", action: #selector(compareTwoFiles(_:)), keyEquivalent: "")
        compareItem.target = self
        fileMenu.addItem(compareItem)
        let tailItem = NSMenuItem(title: "Tail Mode (Follow File)", action: #selector(toggleTailMode(_:)), keyEquivalent: "t")
        tailItem.keyEquivalentModifierMask = [.command, .shift]
        tailItem.target = self
        fileMenu.addItem(tailItem)
        fileMenu.addItem(NSMenuItem.separator())
        fileMenu.addItem(withTitle: "Page Setup…", action: #selector(NSDocument.runPageLayout(_:)), keyEquivalent: "P")
        fileMenu.addItem(withTitle: "Print…", action: #selector(NSDocument.printDocument(_:)), keyEquivalent: "p")

        // Edit menu
        let editItem = NSMenuItem()
        mainMenu.addItem(editItem)
        let editMenu = NSMenu(title: "Edit")
        editItem.submenu = editMenu
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        let redo = NSMenuItem(title: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(redo)
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Delete", action: #selector(NSText.delete(_:)), keyEquivalent: "")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenu.addItem(NSMenuItem.separator())

        // Find submenu
        let findItem = NSMenuItem(title: "Find", action: nil, keyEquivalent: "")
        let findMenu = NSMenu(title: "Find")
        findItem.submenu = findMenu
        let find = NSMenuItem(title: "Find…", action: #selector(NSResponder.performTextFinderAction(_:)), keyEquivalent: "f")
        find.tag = NSTextFinder.Action.showFindInterface.rawValue
        findMenu.addItem(find)
        let findReplace = NSMenuItem(title: "Find and Replace…", action: #selector(NSResponder.performTextFinderAction(_:)), keyEquivalent: "f")
        findReplace.tag = NSTextFinder.Action.showReplaceInterface.rawValue
        findReplace.keyEquivalentModifierMask = [.command, .option]
        findMenu.addItem(findReplace)
        let findNext = NSMenuItem(title: "Find Next", action: #selector(NSResponder.performTextFinderAction(_:)), keyEquivalent: "g")
        findNext.tag = NSTextFinder.Action.nextMatch.rawValue
        findMenu.addItem(findNext)
        let findPrev = NSMenuItem(title: "Find Previous", action: #selector(NSResponder.performTextFinderAction(_:)), keyEquivalent: "G")
        findPrev.tag = NSTextFinder.Action.previousMatch.rawValue
        findPrev.keyEquivalentModifierMask = [.command, .shift]
        findMenu.addItem(findPrev)
        let useSelection = NSMenuItem(title: "Use Selection for Find", action: #selector(NSResponder.performTextFinderAction(_:)), keyEquivalent: "e")
        useSelection.tag = NSTextFinder.Action.setSearchString.rawValue
        findMenu.addItem(useSelection)
        findMenu.addItem(NSMenuItem.separator())
        let findInFiles = NSMenuItem(title: "Find in Workspace…", action: #selector(findInWorkspace(_:)), keyEquivalent: "f")
        findInFiles.keyEquivalentModifierMask = [.command, .shift]
        findInFiles.target = self
        findMenu.addItem(findInFiles)
        editMenu.addItem(findItem)

        let gotoLine = NSMenuItem(title: "Go to Line…", action: #selector(EditorViewController.gotoLine(_:)), keyEquivalent: "l")
        editMenu.addItem(gotoLine)

        let toggleComment = NSMenuItem(title: "Toggle Line Comment", action: #selector(EditorViewController.toggleLineComment(_:)), keyEquivalent: "/")
        toggleComment.keyEquivalentModifierMask = [.command]
        editMenu.addItem(toggleComment)

        let cursorBack = NSMenuItem(title: "Navigate Back", action: #selector(EditorViewController.cursorBack(_:)), keyEquivalent: "-")
        cursorBack.keyEquivalentModifierMask = [.control, .option]
        editMenu.addItem(cursorBack)
        let cursorForward = NSMenuItem(title: "Navigate Forward", action: #selector(EditorViewController.cursorForward(_:)), keyEquivalent: "=")
        cursorForward.keyEquivalentModifierMask = [.control, .option]
        editMenu.addItem(cursorForward)

        // Navigate submenu
        let navItem = NSMenuItem(title: "Navigate", action: nil, keyEquivalent: "")
        let navMenu = NSMenu(title: "Navigate")
        navItem.submenu = navMenu
        let gotoFile = NSMenuItem(title: "Go to File…", action: #selector(quickFileSwitcher(_:)), keyEquivalent: "p")
        gotoFile.target = self
        navMenu.addItem(gotoFile)
        let gotoSymbol = NSMenuItem(title: "Go to Symbol…", action: #selector(quickSymbolSwitcher(_:)), keyEquivalent: "r")
        gotoSymbol.target = self
        navMenu.addItem(gotoSymbol)
        editMenu.addItem(navItem)

        // Mark submenu
        let markItem = NSMenuItem(title: "Mark", action: nil, keyEquivalent: "")
        let markMenu = NSMenu(title: "Mark")
        markItem.submenu = markMenu
        let markAll = NSMenuItem(title: "Mark All Occurrences of Selection", action: #selector(EditorViewController.markAllOccurrencesOfSelection(_:)), keyEquivalent: "m")
        markAll.keyEquivalentModifierMask = [.command, .shift]
        markMenu.addItem(markAll)
        markMenu.addItem(withTitle: "Clear All Marks", action: #selector(EditorViewController.clearAllMarks(_:)), keyEquivalent: "")
        editMenu.addItem(markItem)

        // Autocomplete
        let complete = NSMenuItem(title: "Complete", action: #selector(EditorViewController.triggerCompletion(_:)), keyEquivalent: String(UnicodeScalar(0x1B)!))
        complete.keyEquivalentModifierMask = [.option]
        editMenu.addItem(complete)

        // Lines submenu
        let linesItem = NSMenuItem(title: "Lines", action: nil, keyEquivalent: "")
        let linesMenu = NSMenu(title: "Lines")
        linesItem.submenu = linesMenu
        let dupLine = NSMenuItem(title: "Duplicate Line", action: #selector(EditorViewController.duplicateLine(_:)), keyEquivalent: "d")
        dupLine.keyEquivalentModifierMask = [.command, .shift]
        linesMenu.addItem(dupLine)
        let delLine = NSMenuItem(title: "Delete Line", action: #selector(EditorViewController.deleteLine(_:)), keyEquivalent: "k")
        delLine.keyEquivalentModifierMask = [.command, .shift]
        linesMenu.addItem(delLine)
        let moveUp = NSMenuItem(title: "Move Line Up", action: #selector(EditorViewController.moveLineUp(_:)), keyEquivalent: String(UnicodeScalar(NSUpArrowFunctionKey)!))
        moveUp.keyEquivalentModifierMask = [.option]
        linesMenu.addItem(moveUp)
        let moveDown = NSMenuItem(title: "Move Line Down", action: #selector(EditorViewController.moveLineDown(_:)), keyEquivalent: String(UnicodeScalar(NSDownArrowFunctionKey)!))
        moveDown.keyEquivalentModifierMask = [.option]
        linesMenu.addItem(moveDown)
        linesMenu.addItem(NSMenuItem.separator())
        linesMenu.addItem(withTitle: "Sort Lines", action: #selector(EditorViewController.sortLines(_:)), keyEquivalent: "")
        linesMenu.addItem(withTitle: "Trim Trailing Whitespace", action: #selector(EditorViewController.trimTrailingWhitespace(_:)), keyEquivalent: "")
        linesMenu.addItem(withTitle: "Tabs → Spaces", action: #selector(EditorViewController.convertTabsToSpaces(_:)), keyEquivalent: "")
        linesMenu.addItem(withTitle: "Spaces → Tabs", action: #selector(EditorViewController.convertSpacesToTabs(_:)), keyEquivalent: "")
        editMenu.addItem(linesItem)

        // Convert submenu (case + encode/decode)
        let convertItem = NSMenuItem(title: "Convert", action: nil, keyEquivalent: "")
        let convertMenu = NSMenu(title: "Convert")
        convertItem.submenu = convertMenu
        convertMenu.addItem(withTitle: "UPPERCASE", action: #selector(EditorViewController.uppercaseSelection(_:)), keyEquivalent: "")
        convertMenu.addItem(withTitle: "lowercase", action: #selector(EditorViewController.lowercaseSelection(_:)), keyEquivalent: "")
        convertMenu.addItem(withTitle: "Title Case", action: #selector(EditorViewController.titlecaseSelection(_:)), keyEquivalent: "")
        convertMenu.addItem(withTitle: "iNVERT cASE", action: #selector(EditorViewController.invertCaseSelection(_:)), keyEquivalent: "")
        convertMenu.addItem(NSMenuItem.separator())
        convertMenu.addItem(withTitle: "camelCase", action: #selector(EditorViewController.camelCaseSelection(_:)), keyEquivalent: "")
        convertMenu.addItem(withTitle: "PascalCase", action: #selector(EditorViewController.pascalCaseSelection(_:)), keyEquivalent: "")
        convertMenu.addItem(withTitle: "snake_case", action: #selector(EditorViewController.snakeCaseSelection(_:)), keyEquivalent: "")
        convertMenu.addItem(withTitle: "kebab-case", action: #selector(EditorViewController.kebabCaseSelection(_:)), keyEquivalent: "")
        convertMenu.addItem(NSMenuItem.separator())
        convertMenu.addItem(withTitle: "Base64 Encode", action: #selector(EditorViewController.encodeBase64(_:)), keyEquivalent: "")
        convertMenu.addItem(withTitle: "Base64 Decode", action: #selector(EditorViewController.decodeBase64(_:)), keyEquivalent: "")
        convertMenu.addItem(withTitle: "URL Encode", action: #selector(EditorViewController.encodeURL(_:)), keyEquivalent: "")
        convertMenu.addItem(withTitle: "URL Decode", action: #selector(EditorViewController.decodeURL(_:)), keyEquivalent: "")
        convertMenu.addItem(withTitle: "HTML Encode", action: #selector(EditorViewController.encodeHTML(_:)), keyEquivalent: "")
        convertMenu.addItem(withTitle: "HTML Decode", action: #selector(EditorViewController.decodeHTML(_:)), keyEquivalent: "")
        editMenu.addItem(convertItem)

        // Bookmarks submenu
        let bookmarksItem = NSMenuItem(title: "Bookmarks", action: nil, keyEquivalent: "")
        let bookmarksMenu = NSMenu(title: "Bookmarks")
        bookmarksItem.submenu = bookmarksMenu
        let toggleBM = NSMenuItem(title: "Toggle Bookmark", action: #selector(EditorViewController.toggleBookmark(_:)), keyEquivalent: String(UnicodeScalar(NSF2FunctionKey)!))
        toggleBM.keyEquivalentModifierMask = [.command]
        bookmarksMenu.addItem(toggleBM)
        let nextBM = NSMenuItem(title: "Next Bookmark", action: #selector(EditorViewController.nextBookmark(_:)), keyEquivalent: String(UnicodeScalar(NSF2FunctionKey)!))
        nextBM.keyEquivalentModifierMask = []
        bookmarksMenu.addItem(nextBM)
        let prevBM = NSMenuItem(title: "Previous Bookmark", action: #selector(EditorViewController.previousBookmark(_:)), keyEquivalent: String(UnicodeScalar(NSF2FunctionKey)!))
        prevBM.keyEquivalentModifierMask = [.shift]
        bookmarksMenu.addItem(prevBM)
        bookmarksMenu.addItem(withTitle: "Clear All Bookmarks", action: #selector(EditorViewController.clearAllBookmarks(_:)), keyEquivalent: "")
        editMenu.addItem(bookmarksItem)

        // View menu
        let viewItem = NSMenuItem()
        mainMenu.addItem(viewItem)
        let viewMenu = NSMenu(title: "View")
        viewItem.submenu = viewMenu
        let toggleWrap = NSMenuItem(title: "Toggle Word Wrap", action: #selector(EditorViewController.toggleWordWrap(_:)), keyEquivalent: "j")
        viewMenu.addItem(toggleWrap)
        let toggleLineNumbers = NSMenuItem(title: "Toggle Line Numbers", action: #selector(EditorViewController.toggleLineNumbers(_:)), keyEquivalent: "l")
        toggleLineNumbers.keyEquivalentModifierMask = [.command, .shift]
        viewMenu.addItem(toggleLineNumbers)
        let toggleIndents = NSMenuItem(title: "Toggle Indent Guides", action: #selector(EditorViewController.toggleIndentGuides(_:)), keyEquivalent: "i")
        toggleIndents.keyEquivalentModifierMask = [.command, .shift]
        viewMenu.addItem(toggleIndents)
        let toggleInvis = NSMenuItem(title: "Show Invisibles", action: #selector(EditorViewController.toggleShowInvisibles(_:)), keyEquivalent: "u")
        toggleInvis.keyEquivalentModifierMask = [.command, .shift]
        viewMenu.addItem(toggleInvis)
        let toggleMinimap = NSMenuItem(title: "Show Minimap", action: #selector(EditorViewController.toggleMinimap(_:)), keyEquivalent: "m")
        toggleMinimap.keyEquivalentModifierMask = [.command, .option]
        viewMenu.addItem(toggleMinimap)
        let toggleAutoClose = NSMenuItem(title: "Auto-Close Brackets", action: #selector(EditorViewController.toggleAutoClosePairs(_:)), keyEquivalent: "")
        viewMenu.addItem(toggleAutoClose)
        viewMenu.addItem(NSMenuItem.separator())
        let splitItem = NSMenuItem(title: "Split Editor", action: #selector(splitEditor(_:)), keyEquivalent: "\\")
        splitItem.keyEquivalentModifierMask = [.command]
        splitItem.target = self
        viewMenu.addItem(splitItem)
        let unsplitItem = NSMenuItem(title: "Close Split", action: #selector(closeSplit(_:)), keyEquivalent: "\\")
        unsplitItem.keyEquivalentModifierMask = [.command, .shift]
        unsplitItem.target = self
        viewMenu.addItem(unsplitItem)
        viewMenu.addItem(NSMenuItem.separator())
        let increaseFont = NSMenuItem(title: "Increase Font Size", action: #selector(EditorViewController.increaseFontSize(_:)), keyEquivalent: "+")
        viewMenu.addItem(increaseFont)
        let decreaseFont = NSMenuItem(title: "Decrease Font Size", action: #selector(EditorViewController.decreaseFontSize(_:)), keyEquivalent: "-")
        viewMenu.addItem(decreaseFont)
        viewMenu.addItem(NSMenuItem.separator())
        let toggleGuide = NSMenuItem(title: "Wrap Guide at Column 80", action: #selector(EditorViewController.toggleWrapGuide(_:)), keyEquivalent: "")
        viewMenu.addItem(toggleGuide)
        let setGuide = NSMenuItem(title: "Set Wrap Guide Column…", action: #selector(EditorViewController.setWrapGuideColumn(_:)), keyEquivalent: "")
        viewMenu.addItem(setGuide)
        viewMenu.addItem(NSMenuItem.separator())
        let foldHere = NSMenuItem(title: "Fold at Current Line", action: #selector(EditorViewController.foldAtCurrentLine(_:)), keyEquivalent: ".")
        foldHere.keyEquivalentModifierMask = [.command, .option]
        viewMenu.addItem(foldHere)
        viewMenu.addItem(withTitle: "Fold All", action: #selector(EditorViewController.foldAll(_:)), keyEquivalent: "")
        viewMenu.addItem(withTitle: "Unfold All", action: #selector(EditorViewController.unfoldAll(_:)), keyEquivalent: "")

        // Theme menu
        let themeItem = NSMenuItem()
        mainMenu.addItem(themeItem)
        let themeMenu = NSMenu(title: "Theme")
        themeItem.submenu = themeMenu
        for t in ThemeRegistry.all {
            let item = NSMenuItem(title: t.displayName, action: #selector(selectTheme(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = t.id
            item.state = (t.id == ThemeRegistry.current.id) ? .on : .off
            themeMenu.addItem(item)
        }

        // Syntax menu
        let syntaxItem = NSMenuItem()
        mainMenu.addItem(syntaxItem)
        let syntaxMenu = NSMenu(title: "Syntax")
        syntaxItem.submenu = syntaxMenu
        for lang in SyntaxHighlighter.Language.allCases {
            let item = NSMenuItem(title: lang.displayName, action: #selector(EditorViewController.setLanguage(_:)), keyEquivalent: "")
            item.representedObject = lang.rawValue
            syntaxMenu.addItem(item)
        }

        // Window menu
        let windowItem = NSMenuItem()
        mainMenu.addItem(windowItem)
        let windowMenu = NSMenu(title: "Window")
        windowItem.submenu = windowMenu
        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(withTitle: "Zoom", action: #selector(NSWindow.performZoom(_:)), keyEquivalent: "")
        windowMenu.addItem(NSMenuItem.separator())
        let mru = NSMenuItem(title: "Switch to Next Tab (MRU)", action: #selector(cycleTabsMRU(_:)), keyEquivalent: "\t")
        mru.keyEquivalentModifierMask = [.control]
        mru.target = self
        windowMenu.addItem(mru)
        let mruBack = NSMenuItem(title: "Switch to Previous Tab (MRU)", action: #selector(cycleTabsMRUReverse(_:)), keyEquivalent: "\t")
        mruBack.keyEquivalentModifierMask = [.control, .shift]
        mruBack.target = self
        windowMenu.addItem(mruBack)
        let nextTab = NSMenuItem(title: "Select Next Tab", action: #selector(selectNextTab(_:)), keyEquivalent: "]")
        nextTab.keyEquivalentModifierMask = [.command, .shift]
        nextTab.target = self
        windowMenu.addItem(nextTab)
        let prevTab = NSMenuItem(title: "Select Previous Tab", action: #selector(selectPreviousTab(_:)), keyEquivalent: "[")
        prevTab.keyEquivalentModifierMask = [.command, .shift]
        prevTab.target = self
        windowMenu.addItem(prevTab)
        windowMenu.addItem(NSMenuItem.separator())
        let pinItem = NSMenuItem(title: "Pin / Unpin Tab", action: #selector(toggleActiveTabPin(_:)), keyEquivalent: "")
        pinItem.target = self
        windowMenu.addItem(pinItem)
        let moveLeft = NSMenuItem(title: "Move Tab Left", action: #selector(moveTabLeftAction(_:)), keyEquivalent: "[")
        moveLeft.keyEquivalentModifierMask = [.control, .shift]
        moveLeft.target = self
        windowMenu.addItem(moveLeft)
        let moveRight = NSMenuItem(title: "Move Tab Right", action: #selector(moveTabRightAction(_:)), keyEquivalent: "]")
        moveRight.keyEquivalentModifierMask = [.control, .shift]
        moveRight.target = self
        windowMenu.addItem(moveRight)
        windowMenu.addItem(NSMenuItem.separator())
        windowMenu.addItem(withTitle: "Bring All to Front", action: #selector(NSApplication.arrangeInFront(_:)), keyEquivalent: "")
        NSApp.windowsMenu = windowMenu

        // Help menu
        let helpItem = NSMenuItem()
        mainMenu.addItem(helpItem)
        let helpMenu = NSMenu(title: "Help")
        helpItem.submenu = helpMenu
        let helpEntry = NSMenuItem(title: "Foolscap User Guide", action: #selector(showUserGuide(_:)), keyEquivalent: "?")
        helpEntry.keyEquivalentModifierMask = [.command]
        helpEntry.target = self
        helpMenu.addItem(helpEntry)
        NSApp.helpMenu = helpMenu

        NSApp.mainMenu = mainMenu
    }

    @IBAction func showUserGuide(_ sender: Any?) {
        HelpWindowController.show()
    }
}
