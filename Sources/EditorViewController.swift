import AppKit

final class EditorViewController: NSViewController, NSTextStorageDelegate, NSTextViewDelegate, NSLayoutManagerDelegate {

    weak var host: EditingHost?

    private var scrollView: NSScrollView!
    var textView: EditorTextView!
    private var ruler: LineNumberRulerView!

    private var statusBar: NSView!
    private var langPopup: NSPopUpButton!
    private var encodingPopup: NSPopUpButton!
    private var eolPopup: NSPopUpButton!
    private var cursorLabel: NSTextField!

    private var language: SyntaxHighlighter.Language = .plain
    private var fontSize: CGFloat = 13
    private var showLineNumbers = true

    private var suppressHighlight = false

    private var bookmarks: [Int] = []
    private var modifiedLineStarts: Set<Int> = []
    private var savedLineStarts: Set<Int> = []
    private var markedLineStarts: Set<Int> = []
    private var markedText: String?    // current marked phrase, if any

    let cursorHistory = CursorHistory()
    private var suppressHistoryRecording = false

    /// Code folding state. `availableFolds` is the result of running CodeFolder
    /// over the current buffer; `foldedRanges` is the subset currently hidden.
    private(set) var availableFolds: [CodeFolder.Fold] = []
    private var foldedRanges: [NSRange] = []

    private let injectedStorage: NSTextStorage?
    private var minimapView: MinimapView?
    private var scrollTrailingConstraint: NSLayoutConstraint?

    init(textStorage: NSTextStorage? = nil) {
        self.injectedStorage = textStorage
        super.init(nibName: nil, bundle: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(themeChanged), name: .themeDidChange, object: nil)
    }

    required init?(coder: NSCoder) {
        self.injectedStorage = nil
        super.init(coder: coder)
        NotificationCenter.default.addObserver(self, selector: #selector(themeChanged), name: .themeDidChange, object: nil)
    }

    deinit { NotificationCenter.default.removeObserver(self) }

    @objc private func themeChanged() {
        guard isViewLoaded else { return }
        textView.backgroundColor = ThemeRegistry.current.background
        textView.textColor = ThemeRegistry.current.text
        rehighlightAll()
    }

    override func loadView() {
        let root = NSView(frame: NSRect(x: 0, y: 0, width: 900, height: 650))
        root.autoresizingMask = [.width, .height]

        scrollView = NSScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = true
        scrollView.backgroundColor = NSColor.textBackgroundColor

        if let storage = injectedStorage {
            textView = EditorTextView(textStorage: storage)
        } else {
            textView = EditorTextView()
        }
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.frame = NSRect(x: 0, y: 0, width: 800, height: 600)
        textView.textContainer?.containerSize = NSSize(width: 800, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        textView.delegate = self
        // Only the primary editor on a shared text storage handles the
        // storage-level delegate work (syntax highlight, change history,
        // bookmark/mark shifting). Secondary split-view editors leave the
        // existing delegate intact.
        if textView.textStorage?.delegate == nil {
            textView.textStorage?.delegate = self
        }
        textView.layoutManager?.delegate = self
        textView.font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        textView.backgroundColor = ThemeRegistry.current.background
        textView.textColor = ThemeRegistry.current.text

        scrollView.documentView = textView
        scrollView.hasVerticalRuler = true
        scrollView.rulersVisible = showLineNumbers

        ruler = LineNumberRulerView(textView: textView)
        scrollView.verticalRulerView = ruler

        statusBar = buildStatusBar()

        root.addSubview(scrollView)
        root.addSubview(statusBar)

        let scrollTrailing = scrollView.trailingAnchor.constraint(equalTo: root.trailingAnchor)
        self.scrollTrailingConstraint = scrollTrailing

        NSLayoutConstraint.activate([
            statusBar.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            statusBar.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            statusBar.bottomAnchor.constraint(equalTo: root.bottomAnchor),
            statusBar.heightAnchor.constraint(equalToConstant: 24),

            scrollView.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            scrollTrailing,
            scrollView.topAnchor.constraint(equalTo: root.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: statusBar.topAnchor),
        ])

        self.view = root
    }

    private func buildStatusBar() -> NSView {
        let bar = NSView()
        bar.wantsLayer = true
        bar.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        bar.translatesAutoresizingMaskIntoConstraints = false

        let topLine = NSView()
        topLine.wantsLayer = true
        topLine.layer?.backgroundColor = NSColor.separatorColor.cgColor
        topLine.translatesAutoresizingMaskIntoConstraints = false
        bar.addSubview(topLine)

        langPopup = makePopup()
        for l in SyntaxHighlighter.Language.allCases {
            let item = NSMenuItem(title: l.displayName, action: nil, keyEquivalent: "")
            item.representedObject = l.rawValue
            langPopup.menu?.addItem(item)
        }
        langPopup.target = self
        langPopup.action = #selector(languagePopupChanged(_:))

        encodingPopup = makePopup()
        for e in String.Encoding.allSupported {
            let item = NSMenuItem(title: e.displayName, action: nil, keyEquivalent: "")
            item.representedObject = NSNumber(value: e.rawValue)
            encodingPopup.menu?.addItem(item)
        }
        encodingPopup.target = self
        encodingPopup.action = #selector(encodingPopupChanged(_:))

        eolPopup = makePopup()
        for e in LineEnding.allCases {
            let item = NSMenuItem(title: e.displayName, action: nil, keyEquivalent: "")
            item.representedObject = e.rawValue
            eolPopup.menu?.addItem(item)
        }
        eolPopup.target = self
        eolPopup.action = #selector(eolPopupChanged(_:))

        cursorLabel = NSTextField(labelWithString: "")
        cursorLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        cursorLabel.textColor = NSColor.secondaryLabelColor
        cursorLabel.alignment = .right
        cursorLabel.translatesAutoresizingMaskIntoConstraints = false

        let stack = NSStackView(views: [langPopup, encodingPopup, eolPopup])
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        bar.addSubview(stack)
        bar.addSubview(cursorLabel)

        NSLayoutConstraint.activate([
            topLine.leadingAnchor.constraint(equalTo: bar.leadingAnchor),
            topLine.trailingAnchor.constraint(equalTo: bar.trailingAnchor),
            topLine.topAnchor.constraint(equalTo: bar.topAnchor),
            topLine.heightAnchor.constraint(equalToConstant: 0.5),

            stack.leadingAnchor.constraint(equalTo: bar.leadingAnchor, constant: 6),
            stack.centerYAnchor.constraint(equalTo: bar.centerYAnchor),

            cursorLabel.trailingAnchor.constraint(equalTo: bar.trailingAnchor, constant: -10),
            cursorLabel.centerYAnchor.constraint(equalTo: bar.centerYAnchor),
        ])
        return bar
    }

    private func makePopup() -> NSPopUpButton {
        let p = NSPopUpButton(frame: .zero, pullsDown: false)
        p.bezelStyle = .recessed
        p.isBordered = false
        p.font = NSFont.systemFont(ofSize: 11)
        p.translatesAutoresizingMaskIntoConstraints = false
        return p
    }

    func applyLoadedText() {
        guard isViewLoaded, let host = host else { return }
        suppressHighlight = true
        if injectedStorage == nil {
            textView.string = host.text
        }
        suppressHighlight = false
        textView.indentSettings = host.indentSettings
        language = host.detectedLanguage
        textView.snippetLanguage = host.detectedLanguage
        rehighlightAll()
        syncStatusBar()
        updateStatus()
        bookmarks.removeAll()
        modifiedLineStarts.removeAll()
        savedLineStarts.removeAll()
        markedLineStarts.removeAll()
        markedText = nil
        ruler.bookmarkLineStarts = []
        ruler.modifiedLineStarts = []
        ruler.savedLineStarts = []
        ruler.markedLineStarts = []
        if view.window?.contentViewController === self {
            view.window?.title = host.editorTitle
        }
    }

    func currentText() -> String? {
        return textView?.string
    }

    /// Called by the host when changes have been cleared (e.g. after a save).
    /// Transitions "modified" stripes → "saved" stripes.
    /// Scroll to the very end of the buffer. Used by tail mode.
    func scrollToEnd() {
        guard isViewLoaded else { return }
        let length = (textView.string as NSString).length
        textView.setSelectedRange(NSRange(location: length, length: 0))
        textView.scrollRangeToVisible(NSRange(location: length, length: 0))
    }

    /// Make the text view read-only (used by tail mode to prevent typing into
    /// a buffer that's being rewritten under us).
    func setReadOnly(_ readOnly: Bool) {
        guard isViewLoaded else { return }
        textView.isEditable = !readOnly
    }

    func handleDocumentCleared() {
        savedLineStarts.formUnion(modifiedLineStarts)
        modifiedLineStarts.removeAll()
        ruler.modifiedLineStarts = modifiedLineStarts
        ruler.savedLineStarts = savedLineStarts
    }

    private func rehighlightAll() {
        guard let storage = textView.textStorage else { return }
        let full = NSRange(location: 0, length: (storage.string as NSString).length)
        let font = textView.font ?? NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        SyntaxHighlighter.highlight(storage, range: full, language: language, font: font)
    }

    private func syncStatusBar() {
        langPopup.selectItem(withTitle: language.displayName)
        if let host = host {
            encodingPopup.selectItem(withTitle: host.encoding.displayName)
            eolPopup.selectItem(withTitle: host.lineEnding.displayName)
        }
    }

    private func updateStatus() {
        let nsStr = textView.string as NSString
        let sel = textView.selectedRange()
        var line = 1, col = 1
        if sel.location <= nsStr.length {
            var i = 0
            while i < sel.location {
                let r = nsStr.range(of: "\n", options: [], range: NSRange(location: i, length: sel.location - i))
                if r.location == NSNotFound { col = sel.location - i + 1; break }
                line += 1
                i = r.location + 1
                col = sel.location - i + 1
            }
        }
        let chars = nsStr.length
        var status = "Ln \(line), Col \(col)   \(chars) chars"
        if sel.length > 0 {
            status = "Ln \(line), Col \(col)   sel \(sel.length)   \(chars) chars"
        }
        cursorLabel.stringValue = status
    }

    // MARK: NSTextStorageDelegate

    func textStorage(_ textStorage: NSTextStorage,
                     didProcessEditing editedMask: NSTextStorageEditActions,
                     range editedRange: NSRange,
                     changeInLength delta: Int) {
        guard editedMask.contains(.editedCharacters), !suppressHighlight else { return }
        let range = SyntaxHighlighter.rangeForRehighlight(in: textStorage, editedRange: editedRange, language: language)
        let font = textView.font ?? NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        SyntaxHighlighter.highlight(textStorage, range: range, language: language, font: font)

        if delta != 0 {
            let oldEditStart = editedRange.location
            let oldEditEnd = NSMaxRange(editedRange) - delta
            bookmarks = bookmarks.map { mark -> Int in
                if mark < oldEditStart { return mark }
                if mark >= oldEditEnd { return mark + delta }
                return oldEditStart
            }
            modifiedLineStarts = Set(modifiedLineStarts.map { shift($0, editStart: oldEditStart, editEnd: oldEditEnd, delta: delta) })
            savedLineStarts = Set(savedLineStarts.map { shift($0, editStart: oldEditStart, editEnd: oldEditEnd, delta: delta) })
        }
        let len = (textStorage.string as NSString).length
        bookmarks.removeAll { $0 >= len }
        modifiedLineStarts = modifiedLineStarts.filter { $0 < len }
        savedLineStarts = savedLineStarts.filter { $0 < len }
        normalizeBookmarks()

        // Mark all line starts in the edited paragraph as modified.
        let nsString = textStorage.string as NSString
        let paragraph = nsString.paragraphRange(for: editedRange)
        var i = paragraph.location
        while i <= NSMaxRange(paragraph) && i < nsString.length {
            let lineRange = nsString.lineRange(for: NSRange(location: i, length: 0))
            modifiedLineStarts.insert(lineRange.location)
            savedLineStarts.remove(lineRange.location)
            i = NSMaxRange(lineRange)
            if lineRange.length == 0 { break }
        }
        recomputeMarkedLines()
        minimapView?.needsDisplay = true
    }

    private func shift(_ mark: Int, editStart: Int, editEnd: Int, delta: Int) -> Int {
        if mark < editStart { return mark }
        if mark >= editEnd { return mark + delta }
        return editStart
    }

    private func normalizeBookmarks() {
        let nsString = textView.string as NSString
        let len = nsString.length
        bookmarks = bookmarks.map { idx -> Int in
            guard idx < len else { return idx }
            return nsString.lineRange(for: NSRange(location: idx, length: 0)).location
        }
        var seen: Set<Int> = []
        bookmarks = bookmarks.filter { seen.insert($0).inserted }
        bookmarks.sort()
    }

    private func publishMarkers() {
        ruler.bookmarkLineStarts = Set(bookmarks)
        ruler.modifiedLineStarts = modifiedLineStarts
        ruler.savedLineStarts = savedLineStarts
        ruler.markedLineStarts = markedLineStarts
    }

    private func recomputeMarkedLines() {
        markedLineStarts.removeAll()
        guard let needle = markedText, !needle.isEmpty else { publishMarkers(); return }
        let nsString = textView.string as NSString
        let pattern = NSRegularExpression.escapedPattern(for: needle)
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            publishMarkers(); return
        }
        regex.enumerateMatches(in: textView.string, options: [], range: NSRange(location: 0, length: nsString.length)) { match, _, _ in
            guard let m = match else { return }
            let lineStart = nsString.lineRange(for: NSRange(location: m.range.location, length: 0)).location
            markedLineStarts.insert(lineStart)
        }
        publishMarkers()
    }

    // MARK: NSTextViewDelegate

    func textDidChange(_ notification: Notification) {
        host?.text = textView.string
        host?.markEdited()
        updateStatus()
    }

    func textViewDidChangeSelection(_ notification: Notification) {
        updateStatus()
        updateSelectionDecorations()
        if !suppressHistoryRecording {
            cursorHistory.recordCurrent(textView.selectedRange().location)
        }
    }

    // MARK: Selection decorations

    private func updateSelectionDecorations() {
        guard let layoutManager = textView.layoutManager else { return }
        let nsString = textView.string as NSString
        let full = NSRange(location: 0, length: nsString.length)
        layoutManager.removeTemporaryAttribute(.backgroundColor, forCharacterRange: full)

        let sel = textView.selectedRange()

        if sel.length > 0 && sel.length <= 100 && sel.location + sel.length <= nsString.length {
            let needle = nsString.substring(with: sel)
            if !needle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !needle.contains("\n") {
                let escaped = NSRegularExpression.escapedPattern(for: needle)
                if let regex = try? NSRegularExpression(pattern: escaped, options: []) {
                    let color = NSColor.systemYellow.withAlphaComponent(0.35)
                    regex.enumerateMatches(in: textView.string, options: [], range: full) { match, _, _ in
                        guard let m = match else { return }
                        if NSEqualRanges(m.range, sel) { return }
                        layoutManager.addTemporaryAttribute(.backgroundColor, value: color, forCharacterRange: m.range)
                    }
                }
            }
        }

        if sel.length == 0 {
            highlightMatchingBracket(at: sel.location, layoutManager: layoutManager, nsString: nsString)
        }
    }

    private static let openers: [unichar] = [40, 91, 123]
    private static let closers: [unichar] = [41, 93, 125]

    private func highlightMatchingBracket(at caret: Int, layoutManager: NSLayoutManager, nsString: NSString) {
        var bracketIndex: Int = -1
        var bracketChar: unichar = 0
        var isOpener = false

        if caret > 0 {
            let c = nsString.character(at: caret - 1)
            if EditorViewController.openers.contains(c) {
                bracketIndex = caret - 1; bracketChar = c; isOpener = true
            } else if EditorViewController.closers.contains(c) {
                bracketIndex = caret - 1; bracketChar = c; isOpener = false
            }
        }
        if bracketIndex < 0 && caret < nsString.length {
            let c = nsString.character(at: caret)
            if EditorViewController.openers.contains(c) {
                bracketIndex = caret; bracketChar = c; isOpener = true
            } else if EditorViewController.closers.contains(c) {
                bracketIndex = caret; bracketChar = c; isOpener = false
            }
        }
        guard bracketIndex >= 0 else { return }

        let matchChar: unichar
        if isOpener {
            matchChar = EditorViewController.closers[EditorViewController.openers.firstIndex(of: bracketChar)!]
        } else {
            matchChar = EditorViewController.openers[EditorViewController.closers.firstIndex(of: bracketChar)!]
        }
        guard let matchIndex = findMatching(from: bracketIndex, opener: bracketChar, closer: matchChar, forward: isOpener, in: nsString) else { return }

        let color = NSColor.systemBlue.withAlphaComponent(0.30)
        layoutManager.addTemporaryAttribute(.backgroundColor, value: color, forCharacterRange: NSRange(location: bracketIndex, length: 1))
        layoutManager.addTemporaryAttribute(.backgroundColor, value: color, forCharacterRange: NSRange(location: matchIndex, length: 1))
    }

    private func findMatching(from start: Int, opener selfChar: unichar, closer matchChar: unichar, forward: Bool, in nsString: NSString) -> Int? {
        var depth = 1
        if forward {
            var i = start + 1
            while i < nsString.length {
                let c = nsString.character(at: i)
                if c == selfChar { depth += 1 }
                else if c == matchChar { depth -= 1; if depth == 0 { return i } }
                i += 1
            }
        } else {
            var i = start - 1
            while i >= 0 {
                let c = nsString.character(at: i)
                if c == selfChar { depth += 1 }
                else if c == matchChar { depth -= 1; if depth == 0 { return i } }
                i -= 1
            }
        }
        return nil
    }

    // MARK: View toggles

    @IBAction func toggleWordWrap(_ sender: Any?) {
        guard let container = textView.textContainer else { return }
        if container.widthTracksTextView {
            container.widthTracksTextView = false
            container.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
            textView.isHorizontallyResizable = true
            textView.autoresizingMask = [.width]
            scrollView.hasHorizontalScroller = true
        } else {
            container.widthTracksTextView = true
            container.containerSize = NSSize(width: scrollView.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
            textView.isHorizontallyResizable = false
            scrollView.hasHorizontalScroller = false
            textView.frame.size.width = scrollView.contentSize.width
        }
        textView.needsLayout = true
        textView.needsDisplay = true
    }

    @IBAction func toggleLineNumbers(_ sender: Any?) {
        showLineNumbers.toggle()
        scrollView.rulersVisible = showLineNumbers
    }

    @IBAction func toggleIndentGuides(_ sender: Any?) {
        textView.showIndentGuides.toggle()
        textView.needsDisplay = true
    }

    @IBAction func toggleShowInvisibles(_ sender: Any?) {
        guard let lm = textView.layoutManager else { return }
        lm.showsInvisibleCharacters.toggle()
        textView.needsDisplay = true
    }

    @IBAction func toggleWrapGuide(_ sender: Any?) {
        if textView.wrapGuideColumn == nil {
            textView.wrapGuideColumn = 80
        } else {
            textView.wrapGuideColumn = nil
        }
    }

    @IBAction func setWrapGuideColumn(_ sender: Any?) {
        let alert = NSAlert()
        alert.messageText = "Wrap Guide Column"
        alert.informativeText = "Show a vertical guideline at this column (0 to disable)."
        alert.addButton(withTitle: "Set")
        alert.addButton(withTitle: "Cancel")
        let tf = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        tf.stringValue = String(textView.wrapGuideColumn ?? 80)
        alert.accessoryView = tf
        alert.window.initialFirstResponder = tf
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        let raw = tf.stringValue.trimmingCharacters(in: .whitespaces)
        if let n = Int(raw), n > 0 {
            textView.wrapGuideColumn = n
        } else {
            textView.wrapGuideColumn = nil
        }
    }

    @IBAction func increaseFontSize(_ sender: Any?) { fontSize = min(48, fontSize + 1); applyFont() }
    @IBAction func decreaseFontSize(_ sender: Any?) { fontSize = max(8, fontSize - 1); applyFont() }

    private func applyFont() {
        let font = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
        textView.font = font
        rehighlightAll()
        ruler.needsDisplay = true
    }

    @IBAction func setLanguage(_ sender: Any?) {
        guard let item = sender as? NSMenuItem,
              let raw = item.representedObject as? String,
              let lang = SyntaxHighlighter.Language(rawValue: raw) else { return }
        applyLanguage(lang)
    }

    @objc private func languagePopupChanged(_ sender: NSPopUpButton) {
        guard let raw = sender.selectedItem?.representedObject as? String,
              let lang = SyntaxHighlighter.Language(rawValue: raw) else { return }
        applyLanguage(lang)
    }

    private func applyLanguage(_ lang: SyntaxHighlighter.Language) {
        language = lang
        host?.detectedLanguage = lang
        textView.snippetLanguage = lang
        rehighlightAll()
        syncStatusBar()
        updateStatus()
    }

    @objc private func encodingPopupChanged(_ sender: NSPopUpButton) {
        guard let raw = sender.selectedItem?.representedObject as? NSNumber else { return }
        let enc = String.Encoding(rawValue: UInt(truncating: raw))
        host?.encoding = enc
        host?.markEdited()
    }

    @objc private func eolPopupChanged(_ sender: NSPopUpButton) {
        guard let raw = sender.selectedItem?.representedObject as? String,
              let eol = LineEnding(rawValue: raw) else { return }
        host?.lineEnding = eol
        host?.markEdited()
    }

    // MARK: Code folding

    @IBAction func foldAtCurrentLine(_ sender: Any?) {
        recomputeFoldsIfNeeded()
        let nsString = textView.string as NSString
        let caretLine = currentLineNumber()
        // Largest fold whose headLine == caret line, or the smallest fold that
        // contains the caret line.
        let candidate = availableFolds
            .filter { $0.headLine == caretLine }
            .first
            ?? availableFolds.first(where: { $0.headLine < caretLine && $0.endLine >= caretLine })
        guard let fold = candidate else { NSSound.beep(); return }
        if let existingIdx = foldedRanges.firstIndex(where: { NSEqualRanges($0, fold.hiddenRange) }) {
            foldedRanges.remove(at: existingIdx)
        } else {
            foldedRanges.append(fold.hiddenRange)
        }
        invalidateGlyphs()
        _ = nsString   // silence unused
    }

    @IBAction func foldAll(_ sender: Any?) {
        recomputeFoldsIfNeeded()
        foldedRanges = availableFolds.map { $0.hiddenRange }
        invalidateGlyphs()
    }

    @IBAction func unfoldAll(_ sender: Any?) {
        foldedRanges.removeAll()
        invalidateGlyphs()
    }

    private func currentLineNumber() -> Int {
        let nsString = textView.string as NSString
        let caret = textView.selectedRange().location
        var line = 1
        var i = 0
        while i < caret {
            let r = nsString.range(of: "\n", options: [], range: NSRange(location: i, length: caret - i))
            if r.location == NSNotFound { break }
            line += 1
            i = r.location + 1
        }
        return line
    }

    private func recomputeFoldsIfNeeded() {
        availableFolds = CodeFolder.detectFolds(in: textView.string, language: language)
    }

    private func invalidateGlyphs() {
        guard let lm = textView.layoutManager, let storage = textView.textStorage else { return }
        let full = NSRange(location: 0, length: storage.length)
        lm.invalidateGlyphs(forCharacterRange: full, changeInLength: 0, actualCharacterRange: nil)
        lm.invalidateLayout(forCharacterRange: full, actualCharacterRange: nil)
        lm.ensureLayout(for: textView.textContainer!)
        textView.needsDisplay = true
    }

    // MARK: NSLayoutManagerDelegate — hide glyphs inside folded ranges

    func layoutManager(_ layoutManager: NSLayoutManager,
                       shouldGenerateGlyphs glyphs: UnsafePointer<CGGlyph>,
                       properties props: UnsafePointer<NSLayoutManager.GlyphProperty>,
                       characterIndexes charIndexes: UnsafePointer<Int>,
                       font aFont: NSFont,
                       forGlyphRange glyphRange: NSRange) -> Int {
        guard !foldedRanges.isEmpty else { return 0 }
        var modifiedProps = Array(UnsafeBufferPointer(start: props, count: glyphRange.length))
        var modified = false
        for i in 0..<glyphRange.length {
            let charIdx = charIndexes[i]
            for foldedRange in foldedRanges {
                if NSLocationInRange(charIdx, foldedRange) {
                    modifiedProps[i] = .null
                    modified = true
                    break
                }
            }
        }
        guard modified else { return 0 }
        modifiedProps.withUnsafeBufferPointer { buf in
            layoutManager.setGlyphs(glyphs,
                                    properties: buf.baseAddress!,
                                    characterIndexes: charIndexes,
                                    font: aFont,
                                    forGlyphRange: glyphRange)
        }
        return glyphRange.length
    }

    // MARK: Cursor history

    @IBAction func cursorBack(_ sender: Any?) {
        guard let target = cursorHistory.goBack() else { NSSound.beep(); return }
        navigate(to: target)
    }

    @IBAction func cursorForward(_ sender: Any?) {
        guard let target = cursorHistory.goForward() else { NSSound.beep(); return }
        navigate(to: target)
    }

    private func navigate(to charIndex: Int) {
        let nsString = textView.string as NSString
        let safe = min(charIndex, nsString.length)
        suppressHistoryRecording = true
        textView.setSelectedRange(NSRange(location: safe, length: 0))
        textView.scrollRangeToVisible(NSRange(location: safe, length: 0))
        textView.window?.makeFirstResponder(textView)
        suppressHistoryRecording = false
    }

    // MARK: Toggle line comment

    @IBAction func toggleLineComment(_ sender: Any?) {
        guard let token = CommentToggle.lineToken(for: language) else {
            NSSound.beep(); return
        }
        let nsString = textView.string as NSString
        let sel = textView.selectedRange()
        // Expand to whole-line range.
        let startLine = nsString.lineRange(for: NSRange(location: sel.location, length: 0))
        let endProbe = max(sel.location, NSMaxRange(sel) - 1)
        let endLine = nsString.lineRange(for: NSRange(location: min(endProbe, nsString.length), length: 0))
        let block = NSRange(location: startLine.location, length: NSMaxRange(endLine) - startLine.location)
        guard block.length > 0 else { return }
        let original = nsString.substring(with: block)
        guard let result = CommentToggle.toggle(lineBlock: original, token: token) else { return }
        if textView.shouldChangeText(in: block, replacementString: result.replacement) {
            textView.replaceCharacters(in: block, with: result.replacement)
            textView.didChangeText()
            textView.setSelectedRange(NSRange(location: block.location, length: (result.replacement as NSString).length))
        }
    }

    // MARK: Goto

    @IBAction func gotoLine(_ sender: Any?) {
        let alert = NSAlert()
        alert.messageText = "Go to Line"
        alert.informativeText = "Enter a line number:"
        alert.addButton(withTitle: "Go")
        alert.addButton(withTitle: "Cancel")
        let tf = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        tf.placeholderString = "1"
        alert.accessoryView = tf
        alert.window.initialFirstResponder = tf
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        if let n = Int(tf.stringValue.trimmingCharacters(in: .whitespaces)), n > 0 {
            jumpToLine(n)
        }
    }

    func jumpToLine(_ targetLine: Int) {
        jumpToLineAndRange(line: targetLine, rangeInLine: nil)
    }

    func jumpToLineAndRange(line targetLine: Int, rangeInLine: NSRange?) {
        let nsString = textView.string as NSString
        var i = 0
        var current = 1
        while i < nsString.length && current < targetLine {
            let r = nsString.lineRange(for: NSRange(location: i, length: 0))
            i = NSMaxRange(r)
            current += 1
        }
        let loc = min(i, nsString.length)
        let lineRange = loc < nsString.length
            ? nsString.lineRange(for: NSRange(location: loc, length: 0))
            : NSRange(location: loc, length: 0)
        let selection: NSRange
        if let r = rangeInLine, r.location + r.length <= lineRange.length {
            selection = NSRange(location: lineRange.location + r.location, length: r.length)
        } else {
            selection = NSRange(location: lineRange.location, length: 0)
        }
        textView.setSelectedRange(selection)
        textView.scrollRangeToVisible(lineRange)
        textView.window?.makeFirstResponder(textView)
    }

    // MARK: Line ops

    @IBAction func duplicateLine(_ sender: Any?) {
        let nsString = textView.string as NSString
        let lineRange = nsString.lineRange(for: textView.selectedRange())
        let lineText = nsString.substring(with: lineRange)
        let insertText = lineText.hasSuffix("\n") ? lineText : "\n" + lineText
        let insertRange = NSRange(location: NSMaxRange(lineRange), length: 0)
        if textView.shouldChangeText(in: insertRange, replacementString: insertText) {
            textView.replaceCharacters(in: insertRange, with: insertText)
            textView.didChangeText()
        }
    }

    @IBAction func deleteLine(_ sender: Any?) {
        let nsString = textView.string as NSString
        let lineRange = nsString.lineRange(for: textView.selectedRange())
        if textView.shouldChangeText(in: lineRange, replacementString: "") {
            textView.replaceCharacters(in: lineRange, with: "")
            textView.didChangeText()
        }
    }

    @IBAction func moveLineUp(_ sender: Any?) {
        let nsString = textView.string as NSString
        let sel = textView.selectedRange()
        let lineRange = nsString.lineRange(for: sel)
        guard lineRange.location > 0 else { return }
        let prevLine = nsString.lineRange(for: NSRange(location: lineRange.location - 1, length: 0))
        let combined = NSRange(location: prevLine.location, length: NSMaxRange(lineRange) - prevLine.location)
        var prevText = nsString.substring(with: prevLine)
        var lineText = nsString.substring(with: lineRange)
        if !lineText.hasSuffix("\n") {
            if prevText.hasSuffix("\n") { prevText.removeLast() }
            lineText = lineText + "\n"
        }
        let newText = lineText + prevText
        if textView.shouldChangeText(in: combined, replacementString: newText) {
            textView.replaceCharacters(in: combined, with: newText)
            textView.didChangeText()
            let newCaret = prevLine.location + (sel.location - lineRange.location)
            textView.setSelectedRange(NSRange(location: newCaret, length: 0))
        }
    }

    @IBAction func moveLineDown(_ sender: Any?) {
        let nsString = textView.string as NSString
        let sel = textView.selectedRange()
        let lineRange = nsString.lineRange(for: sel)
        let endOfLine = NSMaxRange(lineRange)
        guard endOfLine < nsString.length else { return }
        let nextLine = nsString.lineRange(for: NSRange(location: endOfLine, length: 0))
        let combined = NSRange(location: lineRange.location, length: NSMaxRange(nextLine) - lineRange.location)
        var lineText = nsString.substring(with: lineRange)
        var nextText = nsString.substring(with: nextLine)
        if !nextText.hasSuffix("\n") {
            if lineText.hasSuffix("\n") { lineText.removeLast() }
            nextText = nextText + "\n"
        }
        let newText = nextText + lineText
        if textView.shouldChangeText(in: combined, replacementString: newText) {
            textView.replaceCharacters(in: combined, with: newText)
            textView.didChangeText()
            let newCaret = lineRange.location + (nextText as NSString).length + (sel.location - lineRange.location)
            textView.setSelectedRange(NSRange(location: min(newCaret, (textView.string as NSString).length), length: 0))
        }
    }

    @IBAction func sortLines(_ sender: Any?) {
        let nsString = textView.string as NSString
        let sel = textView.selectedRange()
        let workRange: NSRange
        if sel.length == 0 {
            workRange = NSRange(location: 0, length: nsString.length)
        } else {
            let startLine = nsString.lineRange(for: NSRange(location: sel.location, length: 0))
            let endProbe = max(sel.location, NSMaxRange(sel) - 1)
            let endLine = nsString.lineRange(for: NSRange(location: endProbe, length: 0))
            workRange = NSRange(location: startLine.location, length: NSMaxRange(endLine) - startLine.location)
        }
        let block = nsString.substring(with: workRange)
        let endsWithNewline = block.hasSuffix("\n")
        var lines = block.components(separatedBy: "\n")
        if endsWithNewline { lines.removeLast() }
        lines.sort()
        var result = lines.joined(separator: "\n")
        if endsWithNewline { result += "\n" }
        if textView.shouldChangeText(in: workRange, replacementString: result) {
            textView.replaceCharacters(in: workRange, with: result)
            textView.didChangeText()
        }
    }

    @IBAction func trimTrailingWhitespace(_ sender: Any?) {
        let s = textView.string
        var lines = s.components(separatedBy: "\n")
        for i in lines.indices {
            while let last = lines[i].last, last == " " || last == "\t" {
                lines[i].removeLast()
            }
        }
        let result = lines.joined(separator: "\n")
        let full = NSRange(location: 0, length: (s as NSString).length)
        if textView.shouldChangeText(in: full, replacementString: result) {
            textView.replaceCharacters(in: full, with: result)
            textView.didChangeText()
        }
    }

    @IBAction func convertTabsToSpaces(_ sender: Any?) {
        applyFullBufferTransform { $0.replacingOccurrences(of: "\t", with: "    ") }
    }

    @IBAction func convertSpacesToTabs(_ sender: Any?) {
        applyFullBufferTransform { $0.replacingOccurrences(of: "    ", with: "\t") }
    }

    private func applyFullBufferTransform(_ transform: (String) -> String) {
        let s = textView.string
        let full = NSRange(location: 0, length: (s as NSString).length)
        let result = transform(s)
        if textView.shouldChangeText(in: full, replacementString: result) {
            textView.replaceCharacters(in: full, with: result)
            textView.didChangeText()
        }
    }

    // MARK: Selection transform — used for case + encode/decode actions

    private func applySelectionTransform(_ transform: (String) -> String) {
        let nsString = textView.string as NSString
        var range = textView.selectedRange()
        if range.length == 0 {
            // Operate on whole document if nothing selected.
            range = NSRange(location: 0, length: nsString.length)
        }
        let original = nsString.substring(with: range)
        let result = transform(original)
        if textView.shouldChangeText(in: range, replacementString: result) {
            textView.replaceCharacters(in: range, with: result)
            textView.didChangeText()
            textView.setSelectedRange(NSRange(location: range.location, length: (result as NSString).length))
        }
    }

    @IBAction func uppercaseSelection(_ sender: Any?) { applySelectionTransform { $0.uppercased() } }
    @IBAction func lowercaseSelection(_ sender: Any?) { applySelectionTransform { $0.lowercased() } }
    @IBAction func titlecaseSelection(_ sender: Any?) { applySelectionTransform { $0.capitalized } }
    @IBAction func invertCaseSelection(_ sender: Any?) {
        applySelectionTransform { s in
            String(s.map { c in
                if c.isUppercase { return Character(c.lowercased()) }
                if c.isLowercase { return Character(c.uppercased()) }
                return c
            })
        }
    }
    @IBAction func camelCaseSelection(_ sender: Any?) { applySelectionTransform { StringConversions.camelCase($0) } }
    @IBAction func snakeCaseSelection(_ sender: Any?) { applySelectionTransform { StringConversions.snakeCase($0) } }
    @IBAction func kebabCaseSelection(_ sender: Any?) { applySelectionTransform { StringConversions.kebabCase($0) } }
    @IBAction func pascalCaseSelection(_ sender: Any?) { applySelectionTransform { StringConversions.pascalCase($0) } }

    @IBAction func encodeBase64(_ sender: Any?) {
        applySelectionTransform { Data($0.utf8).base64EncodedString() }
    }
    @IBAction func decodeBase64(_ sender: Any?) {
        applySelectionTransform { s in
            guard let d = Data(base64Encoded: s.trimmingCharacters(in: .whitespacesAndNewlines)),
                  let str = String(data: d, encoding: .utf8) else { return s }
            return str
        }
    }
    @IBAction func encodeURL(_ sender: Any?) {
        applySelectionTransform { $0.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0 }
    }
    @IBAction func decodeURL(_ sender: Any?) {
        applySelectionTransform { $0.removingPercentEncoding ?? $0 }
    }
    @IBAction func encodeHTML(_ sender: Any?) {
        applySelectionTransform { StringConversions.htmlEncode($0) }
    }
    @IBAction func decodeHTML(_ sender: Any?) {
        applySelectionTransform { StringConversions.htmlDecode($0) }
    }

    // MARK: Bookmarks

    @IBAction func toggleBookmark(_ sender: Any?) {
        let nsString = textView.string as NSString
        let lineRange = nsString.lineRange(for: textView.selectedRange())
        let mark = lineRange.location
        if let idx = bookmarks.firstIndex(of: mark) {
            bookmarks.remove(at: idx)
        } else {
            bookmarks.append(mark)
            bookmarks.sort()
        }
        publishMarkers()
    }

    @IBAction func nextBookmark(_ sender: Any?) {
        let nsString = textView.string as NSString
        let cur = nsString.lineRange(for: textView.selectedRange()).location
        if let next = bookmarks.first(where: { $0 > cur }) ?? bookmarks.first {
            textView.setSelectedRange(NSRange(location: next, length: 0))
            textView.scrollRangeToVisible(NSRange(location: next, length: 0))
        }
    }

    @IBAction func previousBookmark(_ sender: Any?) {
        let nsString = textView.string as NSString
        let cur = nsString.lineRange(for: textView.selectedRange()).location
        if let prev = bookmarks.reversed().first(where: { $0 < cur }) ?? bookmarks.last {
            textView.setSelectedRange(NSRange(location: prev, length: 0))
            textView.scrollRangeToVisible(NSRange(location: prev, length: 0))
        }
    }

    @IBAction func clearAllBookmarks(_ sender: Any?) {
        bookmarks.removeAll()
        publishMarkers()
    }

    // MARK: Mark all matches

    @IBAction func markAllOccurrencesOfSelection(_ sender: Any?) {
        let sel = textView.selectedRange()
        let nsString = textView.string as NSString
        guard sel.length > 0 && sel.length <= 200 else { return }
        let needle = nsString.substring(with: sel)
        if needle.contains("\n") || needle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return }
        markedText = needle
        recomputeMarkedLines()
    }

    @IBAction func clearAllMarks(_ sender: Any?) {
        markedText = nil
        markedLineStarts.removeAll()
        publishMarkers()
    }

    // MARK: Autocomplete

    @IBAction func triggerCompletion(_ sender: Any?) {
        textView.complete(sender)
    }

    // MARK: Auto-close toggle

    @IBAction func toggleAutoClosePairs(_ sender: Any?) {
        textView.autoCloseBrackets.toggle()
    }

    // MARK: Minimap toggle

    @IBAction func toggleMinimap(_ sender: Any?) {
        if minimapView == nil {
            let mv = MinimapView(textView: textView, scrollView: scrollView)
            mv.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(mv)
            scrollTrailingConstraint?.isActive = false
            let newTrailing = scrollView.trailingAnchor.constraint(equalTo: mv.leadingAnchor)
            NSLayoutConstraint.activate([
                newTrailing,
                mv.topAnchor.constraint(equalTo: scrollView.topAnchor),
                mv.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
                mv.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                mv.widthAnchor.constraint(equalToConstant: 96),
            ])
            scrollTrailingConstraint = newTrailing
            minimapView = mv
        } else {
            minimapView?.removeFromSuperview()
            minimapView = nil
            scrollTrailingConstraint?.isActive = false
            let newTrailing = scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
            newTrailing.isActive = true
            scrollTrailingConstraint = newTrailing
        }
    }
}
