import Foundation

/// Detection of fold-able ranges in source text.
///
/// Two strategies depending on language:
///   - Brace languages (C-family + Java/Go/Rust/Swift/JavaScript/JSON/CSS):
///     pair `{` and `}` outside string/comment context (approximated — we
///     don't fully tokenize).
///   - Indent-based languages (Python, YAML, Markdown headings):
///     a region begins when a line is *more* indented than its predecessor
///     and ends when indent returns.
///
/// Output is a list of folds. Each fold's `headLine` is the gutter line that
/// shows the fold triangle; `hiddenRange` is the *character* range that gets
/// hidden when folded (typically from the end of `headLine` to the end of the
/// closing line, inclusive of its newline).
enum CodeFolder {

    struct Fold: Equatable {
        let headLine: Int            // 1-based line containing the fold trigger
        let endLine: Int             // 1-based last line in the fold
        let hiddenRange: NSRange     // character range to hide when folded
    }

    static func detectFolds(in text: String, language: SyntaxHighlighter.Language) -> [Fold] {
        switch language {
        case .swift, .javascript, .c, .cpp, .go, .rust, .java, .css, .json:
            return braceFolds(in: text)
        case .python, .yaml:
            return indentFolds(in: text)
        case .markdown:
            return markdownFolds(in: text)
        case .html, .xml:
            return braceFolds(in: text)   // covers nested tags poorly but better than nothing
        default:
            return []
        }
    }

    // MARK: Brace folds

    private static func braceFolds(in text: String) -> [Fold] {
        let ns = text as NSString
        let length = ns.length
        let lineStarts = computeLineStarts(ns)

        struct Open {
            let charIndex: Int
            let line: Int
        }
        var stack: [Open] = []
        var folds: [Fold] = []
        var inLineComment = false
        var inBlockComment = false
        var inString: Character? = nil

        for i in 0..<length {
            let c = Character(UnicodeScalar(ns.character(at: i)) ?? UnicodeScalar(0)!)
            // Newline ends a line comment.
            if c == "\n" {
                inLineComment = false
                continue
            }
            if inLineComment { continue }
            if inBlockComment {
                if c == "/" && i > 0 && ns.character(at: i - 1) == 0x2A { inBlockComment = false }
                continue
            }
            if let q = inString {
                if c == "\\" { continue }   // skip next
                if c == q { inString = nil }
                continue
            }
            // Detect comment / string starts.
            if c == "/" && i + 1 < length {
                let next = ns.character(at: i + 1)
                if next == 0x2F { inLineComment = true; continue }
                if next == 0x2A { inBlockComment = true; continue }
            }
            if c == "\"" || c == "'" || c == "`" { inString = c; continue }
            if c == "{" {
                stack.append(Open(charIndex: i, line: lineNumber(for: i, in: lineStarts)))
            } else if c == "}" {
                guard let open = stack.popLast() else { continue }
                let endLine = lineNumber(for: i, in: lineStarts)
                if endLine > open.line {
                    let hideStart = open.charIndex + 1
                    let lineRange = ns.lineRange(for: NSRange(location: i, length: 0))
                    let hideEnd = NSMaxRange(lineRange)
                    let hidden = NSRange(location: hideStart, length: max(0, hideEnd - hideStart - 1))
                    folds.append(Fold(headLine: open.line, endLine: endLine, hiddenRange: hidden))
                }
            }
        }
        return folds.sorted { $0.headLine < $1.headLine }
    }

    // MARK: Indent folds

    private static func indentFolds(in text: String) -> [Fold] {
        let ns = text as NSString
        let length = ns.length
        let lineStarts = computeLineStarts(ns)
        let lineCount = lineStarts.count

        // Compute indent (in space-equivalents, tab = 4) per line.
        var indents: [Int] = []
        var contentLines: Set<Int> = []
        for i in 0..<lineCount {
            let start = lineStarts[i]
            let end = (i + 1 < lineCount) ? lineStarts[i + 1] : length
            var indent = 0
            var hasContent = false
            var p = start
            while p < end {
                let c = ns.character(at: p)
                if c == 0x20 { indent += 1; p += 1 }
                else if c == 0x09 { indent += 4; p += 1 }
                else if c == 0x0A { break }
                else { hasContent = true; break }
            }
            indents.append(indent)
            if hasContent { contentLines.insert(i) }
        }

        var folds: [Fold] = []
        for headIdx in 0..<lineCount {
            guard contentLines.contains(headIdx) else { continue }
            let headIndent = indents[headIdx]
            // Look for the next content line; if it's more indented, start a fold.
            var nextContent = headIdx + 1
            while nextContent < lineCount && !contentLines.contains(nextContent) {
                nextContent += 1
            }
            guard nextContent < lineCount, indents[nextContent] > headIndent else { continue }
            // Walk forward until indent returns to <= headIndent at a content line.
            var endIdx = nextContent
            var probe = nextContent + 1
            while probe < lineCount {
                if contentLines.contains(probe) && indents[probe] <= headIndent { break }
                endIdx = probe
                probe += 1
            }
            // hiddenRange: from end-of-headLine to end-of-endLine (inclusive of newline).
            let headLineRange = ns.lineRange(for: NSRange(location: lineStarts[headIdx], length: 0))
            let endLineStart = lineStarts[endIdx]
            let endLineRange = ns.lineRange(for: NSRange(location: endLineStart, length: 0))
            let hideStart = NSMaxRange(headLineRange) - 1   // back up over the head line's '\n'
            let hideEnd = NSMaxRange(endLineRange)
            guard hideStart < hideEnd else { continue }
            let hidden = NSRange(location: hideStart + 1, length: hideEnd - hideStart - 1)
            folds.append(Fold(headLine: headIdx + 1, endLine: endIdx + 1, hiddenRange: hidden))
        }
        return folds.sorted { $0.headLine < $1.headLine }
    }

    // MARK: Markdown folds (section by heading level)

    private static func markdownFolds(in text: String) -> [Fold] {
        let ns = text as NSString
        let length = ns.length
        let lines = (text as NSString).components(separatedBy: "\n")
        let lineStarts = computeLineStarts(ns)

        struct Section { let level: Int; let line: Int; let charIndex: Int }
        var stack: [Section] = []
        var folds: [Fold] = []

        for (i, line) in lines.enumerated() {
            // Match leading hashes.
            var level = 0
            for ch in line {
                if ch == "#" { level += 1 } else { break }
            }
            if level == 0 || level > 6 { continue }
            // Pop sections whose level >= this one — they end here.
            while let top = stack.last, top.level >= level {
                let stEnd = lineStarts[i]   // end-of-prev section is start of this heading
                let endLineNum = i   // 1-based: i is 0-based index of the new heading line
                let hideStart = top.charIndex
                let hideLen = max(0, stEnd - hideStart - 1)
                folds.append(Fold(headLine: top.line, endLine: endLineNum, hiddenRange: NSRange(location: hideStart + 1, length: hideLen)))
                stack.removeLast()
            }
            // Heading starts a new section.
            let lineCharStart = lineStarts[i]
            let lineRange = ns.lineRange(for: NSRange(location: lineCharStart, length: 0))
            stack.append(Section(level: level, line: i + 1, charIndex: NSMaxRange(lineRange) - 1))
        }
        // Flush remaining sections at end of file.
        while let top = stack.popLast() {
            let hideStart = top.charIndex
            let hideEnd = length
            let hideLen = max(0, hideEnd - hideStart - 1)
            folds.append(Fold(headLine: top.line, endLine: lines.count, hiddenRange: NSRange(location: hideStart + 1, length: hideLen)))
        }
        return folds.sorted { $0.headLine < $1.headLine }
    }

    // MARK: Helpers

    private static func computeLineStarts(_ ns: NSString) -> [Int] {
        var starts: [Int] = [0]
        var i = 0
        let length = ns.length
        while i < length {
            let r = ns.range(of: "\n", options: [], range: NSRange(location: i, length: length - i))
            if r.location == NSNotFound { break }
            starts.append(r.location + 1)
            i = r.location + 1
        }
        return starts
    }

    private static func lineNumber(for charIndex: Int, in starts: [Int]) -> Int {
        var lo = 0
        var hi = starts.count - 1
        while lo < hi {
            let mid = (lo + hi + 1) / 2
            if starts[mid] <= charIndex { lo = mid } else { hi = mid - 1 }
        }
        return lo + 1
    }
}
