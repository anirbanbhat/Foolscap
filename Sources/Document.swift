import AppKit

enum LineEnding: String, CaseIterable {
    case lf
    case crlf
    case cr

    var displayName: String {
        switch self {
        case .lf: return "LF"
        case .crlf: return "CRLF"
        case .cr: return "CR"
        }
    }

    var string: String {
        switch self {
        case .lf: return "\n"
        case .crlf: return "\r\n"
        case .cr: return "\r"
        }
    }
}

extension String.Encoding {
    static let allSupported: [String.Encoding] = [.utf8, .utf16, .utf16LittleEndian, .utf16BigEndian, .isoLatin1, .windowsCP1252, .macOSRoman, .ascii]

    var displayName: String {
        switch self {
        case .utf8: return "UTF-8"
        case .utf16: return "UTF-16"
        case .utf16LittleEndian: return "UTF-16 LE"
        case .utf16BigEndian: return "UTF-16 BE"
        case .isoLatin1: return "ISO Latin 1"
        case .windowsCP1252: return "Windows-1252"
        case .macOSRoman: return "Mac Roman"
        case .ascii: return "ASCII"
        default: return "Encoding \(rawValue)"
        }
    }
}

final class Document: NSDocument, EditingHost {

    var text: String = ""
    var encoding: String.Encoding = .utf8
    var lineEnding: LineEnding = .lf
    var detectedLanguage: SyntaxHighlighter.Language = .plain
    var indentSettings: IndentSettings = .default

    weak var editorViewController: EditorViewController?

    var editorTitle: String { displayName ?? "Untitled" }

    func markEdited() {
        updateChangeCount(.changeDone)
    }

    func notifyEditorCleared() {
        editorViewController?.handleDocumentCleared()
    }

    override func updateChangeCount(_ change: NSDocument.ChangeType) {
        super.updateChangeCount(change)
        if change == .changeCleared {
            notifyEditorCleared()
        }
    }

    override class var autosavesInPlace: Bool { true }

    override func makeWindowControllers() {
        let editor = EditorViewController()
        editor.host = self
        self.editorViewController = editor

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 900, height: 650),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.contentViewController = editor
        window.tabbingMode = .preferred
        window.tabbingIdentifier = "foolscap.editor"
        window.setFrameAutosaveName("foolscap.editor.window")
        window.isRestorable = true

        let wc = NSWindowController(window: window)
        addWindowController(wc)
        editor.applyLoadedText()
    }

    override func data(ofType typeName: String) throws -> Data {
        if let ed = editorViewController, let str = ed.currentText() {
            text = str
        }
        // Normalize to chosen EOL on write.
        let normalized = Document.normalizeLineEndings(text, to: lineEnding)
        guard let data = normalized.data(using: encoding, allowLossyConversion: false)
            ?? normalized.data(using: .utf8) else {
            throw NSError(domain: NSCocoaErrorDomain, code: NSFileWriteUnknownError)
        }
        return data
    }

    override func read(from data: Data, ofType typeName: String) throws {
        let candidates: [String.Encoding] = [.utf8, .utf16, .isoLatin1, .windowsCP1252, .macOSRoman]
        for enc in candidates {
            if let s = String(data: data, encoding: enc) {
                self.encoding = enc
                self.lineEnding = Document.detectLineEnding(in: s)
                self.text = s.replacingOccurrences(of: "\r\n", with: "\n")
                                  .replacingOccurrences(of: "\r", with: "\n")
                detectedLanguage = SyntaxHighlighter.detect(filename: self.fileURL?.lastPathComponent ?? "")
                if let url = self.fileURL {
                    // Walk the EditorConfig chain on a background queue —
                    // see WorkspaceFile.resolveEditorConfigAsync for the
                    // rationale.
                    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                        let cfg = EditorConfigLoader.resolve(for: url)
                        DispatchQueue.main.async {
                            self?.applyEditorConfig(cfg)
                            self?.editorViewController?.applyHostIndentSettings()
                        }
                    }
                }
                editorViewController?.applyLoadedText()
                return
            }
        }
        throw NSError(domain: NSCocoaErrorDomain, code: NSFileReadInapplicableStringEncodingError)
    }

    private func applyEditorConfig(_ cfg: EditorConfigSettings) {
        if let style = cfg.indentStyle { indentSettings.useTabs = (style == "tab") }
        if let size = cfg.indentSize { indentSettings.size = size }
        else if let tw = cfg.tabWidth { indentSettings.size = tw }
        if let trim = cfg.trimTrailingWhitespace { indentSettings.trimTrailingWhitespaceOnSave = trim }
        if let final = cfg.insertFinalNewline { indentSettings.insertFinalNewlineOnSave = final }
        if let eol = cfg.endOfLine {
            switch eol {
            case "lf": lineEnding = .lf
            case "crlf": lineEnding = .crlf
            case "cr": lineEnding = .cr
            default: break
            }
        }
    }

    func updateText(_ newText: String) {
        guard text != newText else { return }
        text = newText
        updateChangeCount(.changeDone)
    }

    static func detectLineEnding(in s: String) -> LineEnding {
        if s.contains("\r\n") { return .crlf }
        if s.contains("\r") { return .cr }
        return .lf
    }

    static func normalizeLineEndings(_ s: String, to eol: LineEnding) -> String {
        let lf = s.replacingOccurrences(of: "\r\n", with: "\n")
                  .replacingOccurrences(of: "\r", with: "\n")
        switch eol {
        case .lf: return lf
        case .crlf: return lf.replacingOccurrences(of: "\n", with: "\r\n")
        case .cr: return lf.replacingOccurrences(of: "\n", with: "\r")
        }
    }

    // MARK: External change detection

    override func presentedItemDidChange() {
        DispatchQueue.main.async { [weak self] in
            self?.handleExternalChange()
        }
    }

    /// Tail-mode flag. When true the document silently reloads on every disk
    /// change and the editor scrolls to the bottom — the classic `tail -f`
    /// behaviour. Editing is disabled while tailing.
    var isTailing: Bool = false

    private func handleExternalChange() {
        guard let url = fileURL else { return }
        let fm = FileManager.default
        guard let attrs = try? fm.attributesOfItem(atPath: url.path),
              let diskDate = attrs[.modificationDate] as? Date else { return }
        let knownDate = fileModificationDate ?? .distantPast
        guard diskDate > knownDate else { return }

        if isTailing {
            try? revert(toContentsOf: url, ofType: fileType ?? "public.plain-text")
            editorViewController?.scrollToEnd()
            return
        }

        if !isDocumentEdited {
            try? revert(toContentsOf: url, ofType: fileType ?? "public.plain-text")
            return
        }

        let alert = NSAlert()
        alert.messageText = "File Changed on Disk"
        alert.informativeText = "\(url.lastPathComponent) was modified by another application. Your version has unsaved changes — reload from disk?"
        alert.addButton(withTitle: "Reload")
        alert.addButton(withTitle: "Keep My Version")
        if alert.runModal() == .alertFirstButtonReturn {
            try? revert(toContentsOf: url, ofType: fileType ?? "public.plain-text")
        } else {
            updateChangeCount(.changeDone)
        }
    }
}
