import Foundation

/// Per-language line-comment tokens and the toggle algorithm.
enum CommentToggle {

    /// Line-comment marker for a given language, or nil if the language has none.
    static func lineToken(for language: SyntaxHighlighter.Language) -> String? {
        switch language {
        case .swift, .javascript, .c, .cpp, .go, .rust, .css, .java:
            return "//"
        case .python, .shell, .yaml:
            return "#"
        case .markdown, .json, .xml, .html, .plain:
            return nil
        }
    }

    /// Returns the line-comment marker the existing toggle code uses. Convenience
    /// for the menu-state UI.
    static func canToggleLineComment(in language: SyntaxHighlighter.Language) -> Bool {
        return lineToken(for: language) != nil
    }

    /// Result of a toggle: the new full text for the affected line range,
    /// plus the selection range within the new text. Caller is responsible
    /// for applying this back through NSTextView's shouldChangeText flow.
    struct ToggleResult: Equatable {
        let replacement: String
        let newSelectionLength: Int
    }

    /// Toggle the line comment for `lineBlock` (one or more newline-terminated
    /// lines) using `token`.
    ///
    /// Rules:
    /// - Find the smallest indentation among non-empty lines.
    /// - If *every* non-empty line is already commented at that indent: uncomment.
    /// - Otherwise: comment by inserting `<token> ` at the common indent column.
    ///
    /// Returns nil for an empty/whitespace-only block.
    static func toggle(lineBlock: String, token: String) -> ToggleResult? {
        if lineBlock.isEmpty { return nil }
        let lines = splitLinesPreservingEndings(lineBlock)
        // Compute the column at which to insert / strip the marker = the
        // smallest leading whitespace prefix across non-empty content lines.
        var minIndent = Int.max
        var hasContent = false
        for entry in lines {
            let body = entry.body
            if body.trimmingCharacters(in: .whitespaces).isEmpty { continue }
            hasContent = true
            let indent = body.prefix { $0 == " " || $0 == "\t" }.count
            minIndent = min(minIndent, indent)
        }
        if !hasContent { return nil }
        if minIndent == Int.max { minIndent = 0 }

        let markerWithSpace = token + " "

        // Decide direction: if every content line already starts with token at the
        // common indent, we uncomment.
        let allCommented = lines.allSatisfy { entry in
            let body = entry.body
            if body.trimmingCharacters(in: .whitespaces).isEmpty { return true }
            let chars = Array(body)
            guard chars.count >= minIndent else { return false }
            let after = String(chars[minIndent...])
            return after.hasPrefix(markerWithSpace) || after.hasPrefix(token)
        }

        var out = ""
        for entry in lines {
            let body = entry.body
            let trimmed = body.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                // Empty line — leave untouched.
                out += body + entry.terminator
                continue
            }
            if allCommented {
                // Strip the marker (with optional trailing space) at indent.
                let chars = Array(body)
                let before = String(chars[..<minIndent])
                var after = String(chars[minIndent...])
                if after.hasPrefix(markerWithSpace) {
                    after = String(after.dropFirst(markerWithSpace.count))
                } else if after.hasPrefix(token) {
                    after = String(after.dropFirst(token.count))
                }
                out += before + after + entry.terminator
            } else {
                let chars = Array(body)
                let before = String(chars[..<minIndent])
                let after = String(chars[minIndent...])
                out += before + markerWithSpace + after + entry.terminator
            }
        }
        return ToggleResult(replacement: out, newSelectionLength: (out as NSString).length)
    }

    private struct LineEntry {
        let body: String
        let terminator: String
    }

    private static func splitLinesPreservingEndings(_ s: String) -> [LineEntry] {
        var result: [LineEntry] = []
        var i = s.startIndex
        while i < s.endIndex {
            var j = i
            while j < s.endIndex && s[j] != "\n" {
                j = s.index(after: j)
            }
            let body = String(s[i..<j])
            let terminator: String
            if j < s.endIndex {
                terminator = "\n"
                j = s.index(after: j)
            } else {
                terminator = ""
            }
            result.append(LineEntry(body: body, terminator: terminator))
            i = j
        }
        return result
    }
}
