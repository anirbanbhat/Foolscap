import AppKit

struct FindResult {
    let url: URL
    let lineNumber: Int
    let lineText: String
    let matchRangeInLine: NSRange
}

enum FindInFiles {

    private static let skippedExtensions: Set<String> = [
        "png","jpg","jpeg","gif","tiff","bmp","ico","webp","heic",
        "mp3","wav","flac","aac","ogg","m4a",
        "mp4","mov","avi","mkv","webm",
        "pdf","zip","tar","gz","bz2","7z","xz","rar",
        "dylib","so","a","o","exe","bin","dat",
        "ttf","otf","woff","woff2",
        "psd","sketch","fig","ai","key","numbers","pages"
    ]
    private static let maxFileSize = 5 * 1024 * 1024  // 5 MB

    static func present(in workspace: WorkspaceWindowController) {
        let panel = FindInFilesPanel(workspace: workspace)
        panel.show()
    }

    static func search(query: String, root: URL, caseSensitive: Bool, regex: Bool) -> [FindResult] {
        guard !query.isEmpty else { return [] }
        let regexOpts: NSRegularExpression.Options = caseSensitive ? [] : [.caseInsensitive]
        let pattern: String = regex ? query : NSRegularExpression.escapedPattern(for: query)
        guard let re = try? NSRegularExpression(pattern: pattern, options: regexOpts) else { return [] }

        var results: [FindResult] = []
        let fm = FileManager.default
        let keys: [URLResourceKey] = [.isRegularFileKey, .fileSizeKey, .isDirectoryKey]
        guard let en = fm.enumerator(at: root, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles], errorHandler: nil) else { return [] }

        let skippedDirs: Set<String> = [".git",".svn","node_modules",".build","DerivedData","Pods","build",".gradle","__pycache__",".venv","venv","target","dist","out",".next",".vscode",".idea"]

        for case let url as URL in en {
            if skippedDirs.contains(url.lastPathComponent) {
                en.skipDescendants()
                continue
            }
            guard let vals = try? url.resourceValues(forKeys: Set(keys)) else { continue }
            if vals.isDirectory == true { continue }
            let ext = url.pathExtension.lowercased()
            if skippedExtensions.contains(ext) { continue }
            if let size = vals.fileSize, size > maxFileSize { continue }

            guard let data = try? Data(contentsOf: url),
                  let content = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1)
            else { continue }

            let lines = content.components(separatedBy: "\n")
            for (i, rawLine) in lines.enumerated() {
                let nsLine = rawLine as NSString
                let lineRange = NSRange(location: 0, length: nsLine.length)
                re.enumerateMatches(in: rawLine, options: [], range: lineRange) { match, _, _ in
                    if let m = match {
                        results.append(FindResult(url: url, lineNumber: i + 1, lineText: rawLine, matchRangeInLine: m.range))
                    }
                }
                if results.count > 5000 { return results }
            }
        }
        return results
    }
}

final class FindInFilesPanel: NSWindowController, NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate {

    weak var workspace: WorkspaceWindowController?

    private var queryField: NSTextField!
    private var regexCheck: NSButton!
    private var caseCheck: NSButton!
    private var statusLabel: NSTextField!
    private var resultsTable: NSTableView!
    private var results: [FindResult] = []

    init(workspace: WorkspaceWindowController) {
        self.workspace = workspace
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 480),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false)
        win.title = "Find in Files — \(workspace.rootURL.lastPathComponent)"
        super.init(window: win)
        buildUI()
    }

    required init?(coder: NSCoder) { fatalError() }

    func show() {
        guard let parent = workspace?.window else { return }
        parent.beginSheet(self.window!, completionHandler: nil)
        window?.makeFirstResponder(queryField)
    }

    @IBAction func close(_ sender: Any?) {
        if let win = self.window, let parent = workspace?.window {
            parent.endSheet(win)
        }
    }

    private func buildUI() {
        guard let content = window?.contentView else { return }

        queryField = NSTextField()
        queryField.translatesAutoresizingMaskIntoConstraints = false
        queryField.placeholderString = "Search…"
        queryField.font = NSFont.systemFont(ofSize: 13)
        queryField.target = self
        queryField.action = #selector(runSearch(_:))

        regexCheck = NSButton(checkboxWithTitle: "Regex", target: nil, action: nil)
        caseCheck = NSButton(checkboxWithTitle: "Case sensitive", target: nil, action: nil)
        regexCheck.translatesAutoresizingMaskIntoConstraints = false
        caseCheck.translatesAutoresizingMaskIntoConstraints = false

        let searchButton = NSButton(title: "Search", target: self, action: #selector(runSearch(_:)))
        searchButton.keyEquivalent = "\r"
        searchButton.translatesAutoresizingMaskIntoConstraints = false

        let closeButton = NSButton(title: "Close", target: self, action: #selector(close(_:)))
        closeButton.keyEquivalent = "\u{1B}" // Esc
        closeButton.translatesAutoresizingMaskIntoConstraints = false

        statusLabel = NSTextField(labelWithString: "")
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        statusLabel.textColor = NSColor.secondaryLabelColor
        statusLabel.font = NSFont.systemFont(ofSize: 11)

        let scroll = NSScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder

        resultsTable = NSTableView()
        resultsTable.dataSource = self
        resultsTable.delegate = self
        resultsTable.allowsMultipleSelection = false
        resultsTable.target = self
        resultsTable.doubleAction = #selector(openResult(_:))
        let fileCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("file"))
        fileCol.title = "File"
        fileCol.width = 220
        let lineCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("line"))
        lineCol.title = "Line"
        lineCol.width = 50
        let textCol = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("text"))
        textCol.title = "Match"
        textCol.width = 380
        resultsTable.addTableColumn(fileCol)
        resultsTable.addTableColumn(lineCol)
        resultsTable.addTableColumn(textCol)
        scroll.documentView = resultsTable

        content.addSubview(queryField)
        content.addSubview(regexCheck)
        content.addSubview(caseCheck)
        content.addSubview(searchButton)
        content.addSubview(closeButton)
        content.addSubview(statusLabel)
        content.addSubview(scroll)

        NSLayoutConstraint.activate([
            queryField.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 12),
            queryField.topAnchor.constraint(equalTo: content.topAnchor, constant: 14),
            queryField.trailingAnchor.constraint(equalTo: searchButton.leadingAnchor, constant: -8),

            searchButton.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -12),
            searchButton.centerYAnchor.constraint(equalTo: queryField.centerYAnchor),

            regexCheck.leadingAnchor.constraint(equalTo: queryField.leadingAnchor),
            regexCheck.topAnchor.constraint(equalTo: queryField.bottomAnchor, constant: 8),
            caseCheck.leadingAnchor.constraint(equalTo: regexCheck.trailingAnchor, constant: 14),
            caseCheck.centerYAnchor.constraint(equalTo: regexCheck.centerYAnchor),
            statusLabel.leadingAnchor.constraint(equalTo: caseCheck.trailingAnchor, constant: 20),
            statusLabel.centerYAnchor.constraint(equalTo: regexCheck.centerYAnchor),
            statusLabel.trailingAnchor.constraint(lessThanOrEqualTo: content.trailingAnchor, constant: -12),

            scroll.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 12),
            scroll.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -12),
            scroll.topAnchor.constraint(equalTo: regexCheck.bottomAnchor, constant: 10),
            scroll.bottomAnchor.constraint(equalTo: closeButton.topAnchor, constant: -10),

            closeButton.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -12),
            closeButton.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -12),
        ])
    }

    @IBAction func runSearch(_ sender: Any?) {
        guard let workspace = workspace else { return }
        let q = queryField.stringValue
        let useRegex = regexCheck.state == .on
        let caseSensitive = caseCheck.state == .on
        statusLabel.stringValue = "Searching…"
        results = []
        resultsTable.reloadData()

        let root = workspace.rootURL
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let found = FindInFiles.search(query: q, root: root, caseSensitive: caseSensitive, regex: useRegex)
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.results = found
                self.statusLabel.stringValue = "\(found.count) match\(found.count == 1 ? "" : "es")"
                self.resultsTable.reloadData()
            }
        }
    }

    @objc private func openResult(_ sender: Any?) {
        let row = resultsTable.clickedRow
        guard row >= 0 && row < results.count, let workspace = workspace else { return }
        let r = results[row]
        guard let file = workspace.openFile(at: r.url), let editor = file.editor else { return }
        editor.jumpToLineAndRange(line: r.lineNumber, rangeInLine: r.matchRangeInLine)
        close(nil)
    }

    // MARK: Table

    func numberOfRows(in tableView: NSTableView) -> Int { results.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let r = results[row]
        let id = tableColumn?.identifier.rawValue ?? ""
        let cell = NSTableCellView()
        let tf = NSTextField(labelWithString: "")
        tf.translatesAutoresizingMaskIntoConstraints = false
        tf.font = NSFont.systemFont(ofSize: 12)
        tf.lineBreakMode = .byTruncatingTail
        switch id {
        case "file":
            let rel = r.url.path.replacingOccurrences(of: workspace?.rootURL.path ?? "", with: "")
                .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            tf.stringValue = rel
        case "line":
            tf.stringValue = "\(r.lineNumber)"
            tf.alignment = .right
            tf.textColor = NSColor.secondaryLabelColor
        case "text":
            tf.stringValue = r.lineText.trimmingCharacters(in: .whitespaces)
            tf.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        default:
            tf.stringValue = ""
        }
        cell.textField = tf
        cell.addSubview(tf)
        NSLayoutConstraint.activate([
            tf.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 2),
            tf.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -2),
            tf.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
        ])
        return cell
    }
}
