import AppKit

final class EditorTextView: NSTextView {

    var showIndentGuides: Bool = false {
        didSet { needsDisplay = true }
    }
    var indentSettings: IndentSettings = .default
    var autoCloseBrackets: Bool = true

    /// Pairs that get auto-closed. Map of opener → closer.
    private static let pairs: [Character: Character] = [
        "(": ")",
        "[": "]",
        "{": "}",
        "\"": "\"",
        "'": "'",
        "`": "`",
    ]
    private static let closers: Set<Character> = [")", "]", "}", "\"", "'", "`"]

    override var acceptsFirstResponder: Bool { true }

    override func awakeFromNib() {
        super.awakeFromNib()
        configure()
    }

    convenience init() {
        let storage = NSTextStorage()
        let layout = NSLayoutManager()
        storage.addLayoutManager(layout)
        let container = NSTextContainer(containerSize: NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude))
        container.widthTracksTextView = true
        layout.addTextContainer(container)
        self.init(frame: .zero, textContainer: container)
        configure()
    }

    convenience init(textStorage: NSTextStorage) {
        let layout = NSLayoutManager()
        textStorage.addLayoutManager(layout)
        let container = NSTextContainer(containerSize: NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude))
        container.widthTracksTextView = true
        layout.addTextContainer(container)
        self.init(frame: .zero, textContainer: container)
        configure()
    }

    private func configure() {
        isRichText = false
        importsGraphics = false
        allowsUndo = true
        isAutomaticQuoteSubstitutionEnabled = false
        isAutomaticDashSubstitutionEnabled = false
        isAutomaticTextReplacementEnabled = false
        isAutomaticSpellingCorrectionEnabled = false
        isContinuousSpellCheckingEnabled = false
        isGrammarCheckingEnabled = false
        isAutomaticLinkDetectionEnabled = false
        isAutomaticDataDetectionEnabled = false
        smartInsertDeleteEnabled = false
        usesFindBar = true
        isIncrementalSearchingEnabled = true
        font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        textContainerInset = NSSize(width: 4, height: 6)
        backgroundColor = NSColor.textBackgroundColor
        insertionPointColor = NSColor.textColor
        textColor = NSColor.textColor
        isEditable = true
        isSelectable = true
        autoresizingMask = [.width]
    }

    override func insertTab(_ sender: Any?) {
        insertText(indentSettings.tabInsertion, replacementRange: selectedRange())
    }

    override func insertNewline(_ sender: Any?) {
        let nsString = string as NSString
        let sel = selectedRange()
        let lineRange = nsString.lineRange(for: NSRange(location: sel.location, length: 0))
        let line = nsString.substring(with: NSRange(location: lineRange.location, length: sel.location - lineRange.location))
        var indent = ""
        for ch in line {
            if ch == " " || ch == "\t" { indent.append(ch) } else { break }
        }
        super.insertNewline(sender)
        if !indent.isEmpty {
            insertText(indent, replacementRange: selectedRange())
        }
    }

    /// Override the universal text-input entry point so auto-close, "skip
    /// closer", and "wrap selection" all happen no matter how the character
    /// arrived (keyboard, paste, IME).
    override func insertText(_ string: Any, replacementRange: NSRange) {
        guard autoCloseBrackets, let s = string as? String, s.count == 1, let ch = s.first else {
            super.insertText(string, replacementRange: replacementRange)
            return
        }
        let nsString = self.string as NSString
        let sel = selectedRange()

        // Wrap selection: when something is selected and an opener is typed,
        // wrap the selection with opener…closer.
        if sel.length > 0, let closer = EditorTextView.pairs[ch] {
            let selected = nsString.substring(with: sel)
            let replacement = String(ch) + selected + String(closer)
            if shouldChangeText(in: sel, replacementString: replacement) {
                replaceCharacters(in: sel, with: replacement)
                didChangeText()
                setSelectedRange(NSRange(location: sel.location + 1, length: sel.length))
            }
            return
        }

        // Skip-over a closer if we're sitting right before one.
        if EditorTextView.closers.contains(ch),
           sel.length == 0,
           sel.location < nsString.length,
           nsString.character(at: sel.location) == ch.asciiValue.map(unichar.init) ?? 0 {
            setSelectedRange(NSRange(location: sel.location + 1, length: 0))
            return
        }

        // Auto-close: type an opener, also insert the closer.
        if let closer = EditorTextView.pairs[ch], sel.length == 0 {
            // For " and ', skip the pair if the cursor is inside a word.
            if (ch == "\"" || ch == "'" || ch == "`") && isInsideWord(at: sel.location, in: nsString) {
                super.insertText(string, replacementRange: replacementRange)
                return
            }
            let pair = String(ch) + String(closer)
            if shouldChangeText(in: sel, replacementString: pair) {
                replaceCharacters(in: sel, with: pair)
                didChangeText()
                setSelectedRange(NSRange(location: sel.location + 1, length: 0))
            }
            return
        }

        super.insertText(string, replacementRange: replacementRange)
    }

    private func isInsideWord(at index: Int, in nsString: NSString) -> Bool {
        if index <= 0 || index >= nsString.length { return false }
        let prev = nsString.character(at: index - 1)
        // Letter or digit before the caret → likely typing inside a contraction.
        guard let scalar = UnicodeScalar(prev) else { return false }
        return CharacterSet.alphanumerics.contains(scalar)
    }

    // Pair-aware backspace: when caret is between an opener and its matching
    // empty closer, delete both.
    override func deleteBackward(_ sender: Any?) {
        if autoCloseBrackets, selectedRange().length == 0 {
            let sel = selectedRange()
            let s = self.string as NSString
            if sel.location > 0 && sel.location < s.length {
                let prev = s.character(at: sel.location - 1)
                let next = s.character(at: sel.location)
                if let pCh = UnicodeScalar(prev).map(Character.init),
                   let nCh = UnicodeScalar(next).map(Character.init),
                   EditorTextView.pairs[pCh] == nCh {
                    let range = NSRange(location: sel.location - 1, length: 2)
                    if shouldChangeText(in: range, replacementString: "") {
                        replaceCharacters(in: range, with: "")
                        didChangeText()
                    }
                    return
                }
            }
        }
        super.deleteBackward(sender)
    }

    // MARK: Word completion from buffer

    override func completions(forPartialWordRange charRange: NSRange,
                              indexOfSelectedItem index: UnsafeMutablePointer<Int>?) -> [String]? {
        let nsString = self.string as NSString
        guard charRange.length > 0 || charRange.location >= 0 else { return nil }
        let prefix = nsString.substring(with: charRange)
        // Collect all word-like tokens from the buffer.
        guard let regex = try? NSRegularExpression(pattern: #"[A-Za-z_][A-Za-z0-9_]*"#, options: []) else {
            return nil
        }
        let full = NSRange(location: 0, length: nsString.length)
        var freq: [String: Int] = [:]
        regex.enumerateMatches(in: self.string, options: [], range: full) { match, _, _ in
            guard let m = match else { return }
            // Exclude the word currently being typed at the caret.
            if m.range == charRange { return }
            let w = nsString.substring(with: m.range)
            if w.count < 2 { return }
            freq[w, default: 0] += 1
        }
        let prefixLower = prefix.lowercased()
        let candidates = freq.keys.filter { w in
            prefixLower.isEmpty || w.lowercased().hasPrefix(prefixLower)
        }
        let sorted = candidates.sorted { a, b in
            let fa = freq[a] ?? 0
            let fb = freq[b] ?? 0
            if fa != fb { return fa > fb }
            return a.localizedStandardCompare(b) == .orderedAscending
        }
        if let index = index, !sorted.isEmpty { index.pointee = 0 }
        return Array(sorted.prefix(50))
    }

    // MARK: Indent guides

    override func drawBackground(in rect: NSRect) {
        super.drawBackground(in: rect)
        guard showIndentGuides,
              let lm = layoutManager,
              let tc = textContainer,
              let font = self.font else { return }

        let nsString = string as NSString
        let visibleRect = self.visibleRect.intersection(rect)
        let visibleGlyphRange = lm.glyphRange(forBoundingRect: visibleRect, in: tc)
        guard visibleGlyphRange.length > 0 || nsString.length == 0 else { return }

        let charWidth = "x".size(withAttributes: [.font: font]).width
        let indentCols = CGFloat(max(1, indentSettings.size))
        let stepWidth = charWidth * indentCols
        guard stepWidth > 0.5 else { return }

        let color = NSColor.separatorColor.withAlphaComponent(0.5)
        color.setStroke()
        let inset = textContainerInset

        var glyphIndex = visibleGlyphRange.location
        while glyphIndex < NSMaxRange(visibleGlyphRange) {
            let charIndex = lm.characterIndexForGlyph(at: glyphIndex)
            let lineRange = nsString.lineRange(for: NSRange(location: charIndex, length: 0))

            var cols = 0
            var i = lineRange.location
            while i < NSMaxRange(lineRange) && i < nsString.length {
                let c = nsString.character(at: i)
                if c == 0x20 { cols += 1; i += 1 }
                else if c == 0x09 { cols += indentSettings.size; i += 1 }
                else { break }
            }
            let levels = cols / max(1, indentSettings.size)

            let lineGlyphRange = lm.glyphRange(forCharacterRange: lineRange, actualCharacterRange: nil)
            let lineRect = lm.boundingRect(forGlyphRange: lineGlyphRange, in: tc)
            let y0 = lineRect.minY + inset.height
            let y1 = lineRect.maxY + inset.height

            if levels >= 1 {
                let path = NSBezierPath()
                path.lineWidth = 0.5
                for level in 1...levels {
                    let x = inset.width + CGFloat(level) * stepWidth + 0.5
                    path.move(to: NSPoint(x: x, y: y0))
                    path.line(to: NSPoint(x: x, y: y1))
                }
                path.stroke()
            }

            glyphIndex = NSMaxRange(lineGlyphRange)
            if lineGlyphRange.length == 0 { break }
        }
    }
}
