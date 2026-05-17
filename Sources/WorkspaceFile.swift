import AppKit

final class WorkspaceFile: EditingHost {

    let url: URL
    var text: String
    var encoding: String.Encoding
    var lineEnding: LineEnding
    var detectedLanguage: SyntaxHighlighter.Language
    var indentSettings: IndentSettings = .default
    private(set) var isEdited: Bool = false
    var isPinned: Bool = false

    /// Created lazily on first editor attach so split-view editors share storage.
    private var sharedStorage: NSTextStorage?

    weak var owner: WorkspaceWindowController?
    var editors: [EditorViewController] = []
    var editor: EditorViewController? { editors.first }

    var editorTitle: String { url.lastPathComponent }
    var fileURL: URL? { url }

    init(url: URL, text: String, encoding: String.Encoding, lineEnding: LineEnding, language: SyntaxHighlighter.Language) {
        self.url = url
        self.text = text
        self.encoding = encoding
        self.lineEnding = lineEnding
        self.detectedLanguage = language
    }

    static func load(from url: URL) throws -> WorkspaceFile {
        let data = try Data(contentsOf: url)
        let candidates: [String.Encoding] = [.utf8, .utf16, .isoLatin1, .windowsCP1252, .macOSRoman]
        for enc in candidates {
            if let s = String(data: data, encoding: enc) {
                let eol: LineEnding = s.contains("\r\n") ? .crlf : s.contains("\r") ? .cr : .lf
                let normalized = s.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
                let lang = SyntaxHighlighter.detect(filename: url.lastPathComponent)
                let file = WorkspaceFile(url: url, text: normalized, encoding: enc, lineEnding: eol, language: lang)
                // Resolve EditorConfig in the background. The walk does
                // fileExists checks up the directory tree, which can stall
                // the main thread when parent directories live in iCloud /
                // network mounts.
                file.resolveEditorConfigAsync()
                return file
            }
        }
        throw NSError(domain: NSCocoaErrorDomain, code: NSFileReadInapplicableStringEncodingError)
    }

    /// Run EditorConfig walk on a background queue, then apply on main.
    /// Settings landing slightly late is fine — the buffer is already in the
    /// editor, and indentation/EOL/encoding only matter when the user saves
    /// or hits Tab, by which time we've returned to the main thread anyway.
    func resolveEditorConfigAsync() {
        let url = self.url
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let cfg = EditorConfigLoader.resolve(for: url)
            DispatchQueue.main.async { [weak self] in
                self?.applyEditorConfig(cfg)
                if let self = self {
                    for ed in self.editors {
                        ed.applyHostIndentSettings()
                    }
                }
            }
        }
    }

    /// Apply EditorConfig settings to encoding, line endings, and indent.
    func applyEditorConfig(_ cfg: EditorConfigSettings) {
        if let style = cfg.indentStyle {
            indentSettings.useTabs = (style == "tab")
        }
        if let size = cfg.indentSize {
            indentSettings.size = size
        } else if let tw = cfg.tabWidth {
            indentSettings.size = tw
        }
        if let trim = cfg.trimTrailingWhitespace {
            indentSettings.trimTrailingWhitespaceOnSave = trim
        }
        if let final = cfg.insertFinalNewline {
            indentSettings.insertFinalNewlineOnSave = final
        }
        if let eol = cfg.endOfLine {
            switch eol {
            case "lf": lineEnding = .lf
            case "crlf": lineEnding = .crlf
            case "cr": lineEnding = .cr
            default: break
            }
        }
        if let charset = cfg.charset {
            switch charset {
            case "utf-8", "utf-8-bom": encoding = .utf8
            case "latin1": encoding = .isoLatin1
            case "utf-16be": encoding = .utf16BigEndian
            case "utf-16le": encoding = .utf16LittleEndian
            default: break
            }
        }
    }

    func acquireTextStorage() -> NSTextStorage {
        if let s = sharedStorage { return s }
        let s = NSTextStorage(string: text)
        sharedStorage = s
        return s
    }

    func save() throws {
        if let storage = sharedStorage {
            text = storage.string
        } else if let ed = editor, let str = ed.currentText() {
            text = str
        }
        var processed = text
        if indentSettings.trimTrailingWhitespaceOnSave {
            processed = WorkspaceFile.stripTrailingWhitespace(processed)
        }
        if indentSettings.insertFinalNewlineOnSave && !processed.hasSuffix("\n") {
            processed += "\n"
        }
        // Sync the in-memory state with whatever we wrote.
        if processed != text {
            text = processed
            if let storage = sharedStorage {
                storage.replaceCharacters(in: NSRange(location: 0, length: storage.length), with: processed)
            }
        }
        let toWrite: String
        switch lineEnding {
        case .lf: toWrite = processed
        case .crlf: toWrite = processed.replacingOccurrences(of: "\n", with: "\r\n")
        case .cr: toWrite = processed.replacingOccurrences(of: "\n", with: "\r")
        }
        guard let data = toWrite.data(using: encoding, allowLossyConversion: false)
            ?? toWrite.data(using: .utf8) else {
            throw NSError(domain: NSCocoaErrorDomain, code: NSFileWriteUnknownError)
        }
        try data.write(to: url, options: .atomic)
        isEdited = false
        owner?.fileDidSave(self)
    }

    static func stripTrailingWhitespace(_ s: String) -> String {
        var lines = s.components(separatedBy: "\n")
        for i in lines.indices {
            while let last = lines[i].last, last == " " || last == "\t" {
                lines[i].removeLast()
            }
        }
        return lines.joined(separator: "\n")
    }

    func markEdited() {
        isEdited = true
        owner?.fileDidChangeEditedState(self)
    }

    func notifyEditorCleared() {
        for ed in editors { ed.handleDocumentCleared() }
    }
}
