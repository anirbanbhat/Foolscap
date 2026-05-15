import Foundation

struct SourceSymbol: Equatable {
    let name: String
    let kind: String        // "func", "class", "heading", etc.
    let lineNumber: Int     // 1-based
    let charIndex: Int      // start-of-line character index
}

enum SymbolExtractor {

    static func symbols(in text: String, language: SyntaxHighlighter.Language) -> [SourceSymbol] {
        switch language {
        case .swift:      return scan(text, rules: swiftRules)
        case .python:     return scan(text, rules: pythonRules)
        case .javascript: return scan(text, rules: javascriptRules)
        case .c, .cpp:    return scan(text, rules: cRules)
        case .go:         return scan(text, rules: goRules)
        case .rust:       return scan(text, rules: rustRules)
        case .shell:      return scan(text, rules: shellRules)
        case .markdown:   return scan(text, rules: markdownRules)
        case .css:        return scan(text, rules: cssRules)
        default:          return []
        }
    }

    // MARK: Per-language rules

    private struct Rule {
        let pattern: String
        let kind: String
        let captureIndex: Int   // which group holds the symbol name
    }

    private static let swiftRules: [Rule] = [
        Rule(pattern: #"(?m)^[ \t]*(?:public|private|internal|fileprivate|open|@\w+\s+)*\s*(?:static\s+|final\s+|override\s+|class\s+|mutating\s+)*\bfunc\s+(\w+)"#, kind: "func", captureIndex: 1),
        Rule(pattern: #"(?m)^[ \t]*(?:public|private|internal|fileprivate|open|final\s+)*\s*class\s+(\w+)"#, kind: "class", captureIndex: 1),
        Rule(pattern: #"(?m)^[ \t]*(?:public|private|internal|fileprivate|open)*\s*struct\s+(\w+)"#, kind: "struct", captureIndex: 1),
        Rule(pattern: #"(?m)^[ \t]*(?:public|private|internal|fileprivate|open)*\s*enum\s+(\w+)"#, kind: "enum", captureIndex: 1),
        Rule(pattern: #"(?m)^[ \t]*(?:public|private|internal|fileprivate|open)*\s*protocol\s+(\w+)"#, kind: "protocol", captureIndex: 1),
        Rule(pattern: #"(?m)^[ \t]*extension\s+([A-Za-z_][\w.]*)"#, kind: "extension", captureIndex: 1),
    ]

    private static let pythonRules: [Rule] = [
        Rule(pattern: #"(?m)^[ \t]*def\s+(\w+)"#, kind: "def", captureIndex: 1),
        Rule(pattern: #"(?m)^[ \t]*class\s+(\w+)"#, kind: "class", captureIndex: 1),
        Rule(pattern: #"(?m)^[ \t]*async\s+def\s+(\w+)"#, kind: "def", captureIndex: 1),
    ]

    private static let javascriptRules: [Rule] = [
        Rule(pattern: #"(?m)^[ \t]*(?:export\s+)?(?:async\s+)?function\s*\*?\s*(\w+)"#, kind: "function", captureIndex: 1),
        Rule(pattern: #"(?m)^[ \t]*(?:export\s+)?class\s+(\w+)"#, kind: "class", captureIndex: 1),
        Rule(pattern: #"(?m)^[ \t]*(?:export\s+)?(?:const|let|var)\s+(\w+)\s*=\s*(?:async\s*)?\([^)]*\)\s*=>"#, kind: "function", captureIndex: 1),
        Rule(pattern: #"(?m)^[ \t]*(?:export\s+)?(?:const|let|var)\s+(\w+)\s*=\s*(?:async\s+)?function"#, kind: "function", captureIndex: 1),
    ]

    private static let cRules: [Rule] = [
        Rule(pattern: #"(?m)^[A-Za-z_][\w\s\*]*?\s+(\w+)\s*\([^)]*\)\s*\{"#, kind: "func", captureIndex: 1),
        Rule(pattern: #"(?m)^typedef\s+struct\s+(?:\w+\s+)?(\w+)"#, kind: "typedef", captureIndex: 1),
        Rule(pattern: #"(?m)^struct\s+(\w+)\s*\{"#, kind: "struct", captureIndex: 1),
        Rule(pattern: #"(?m)^class\s+(\w+)"#, kind: "class", captureIndex: 1),
        Rule(pattern: #"(?m)^namespace\s+(\w+)"#, kind: "namespace", captureIndex: 1),
    ]

    private static let goRules: [Rule] = [
        Rule(pattern: #"(?m)^func\s*(?:\([^)]*\)\s*)?(\w+)\s*\("#, kind: "func", captureIndex: 1),
        Rule(pattern: #"(?m)^type\s+(\w+)\s+struct"#, kind: "struct", captureIndex: 1),
        Rule(pattern: #"(?m)^type\s+(\w+)\s+interface"#, kind: "interface", captureIndex: 1),
        Rule(pattern: #"(?m)^type\s+(\w+)\s+"#, kind: "type", captureIndex: 1),
    ]

    private static let rustRules: [Rule] = [
        Rule(pattern: #"(?m)^[ \t]*(?:pub(?:\([^)]*\))?\s+)?(?:async\s+)?fn\s+(\w+)"#, kind: "fn", captureIndex: 1),
        Rule(pattern: #"(?m)^[ \t]*(?:pub(?:\([^)]*\))?\s+)?struct\s+(\w+)"#, kind: "struct", captureIndex: 1),
        Rule(pattern: #"(?m)^[ \t]*(?:pub(?:\([^)]*\))?\s+)?enum\s+(\w+)"#, kind: "enum", captureIndex: 1),
        Rule(pattern: #"(?m)^[ \t]*(?:pub(?:\([^)]*\))?\s+)?trait\s+(\w+)"#, kind: "trait", captureIndex: 1),
        Rule(pattern: #"(?m)^[ \t]*impl(?:<[^>]+>)?\s+(?:[\w<>,\s]+\s+for\s+)?(\w+)"#, kind: "impl", captureIndex: 1),
    ]

    private static let shellRules: [Rule] = [
        Rule(pattern: #"(?m)^[ \t]*function\s+(\w+)"#, kind: "function", captureIndex: 1),
        Rule(pattern: #"(?m)^[ \t]*(\w+)\s*\(\s*\)\s*\{"#, kind: "function", captureIndex: 1),
    ]

    private static let markdownRules: [Rule] = [
        Rule(pattern: #"(?m)^#{1,6}\s+(.+)$"#, kind: "heading", captureIndex: 1),
    ]

    private static let cssRules: [Rule] = [
        Rule(pattern: #"(?m)^([\.#][A-Za-z_][\w-]*)"#, kind: "selector", captureIndex: 1),
    ]

    // MARK: Scanner

    private static func scan(_ text: String, rules: [Rule]) -> [SourceSymbol] {
        let ns = text as NSString
        var symbols: [SourceSymbol] = []
        let lineStartIndices = computeLineStarts(text: text, length: ns.length)

        for rule in rules {
            guard let re = try? NSRegularExpression(pattern: rule.pattern, options: []) else { continue }
            re.enumerateMatches(in: text, options: [], range: NSRange(location: 0, length: ns.length)) { match, _, _ in
                guard let m = match, m.numberOfRanges > rule.captureIndex else { return }
                let capture = m.range(at: rule.captureIndex)
                guard capture.location != NSNotFound else { return }
                let name = ns.substring(with: capture).trimmingCharacters(in: .whitespaces)
                // Use the captured name's position rather than the full match
                // start — `^…\s*` rules can otherwise stretch onto a preceding
                // blank line.
                let lineNumber = lineNumberFor(charIndex: capture.location, in: lineStartIndices)
                let lineStart = lineStartIndices[max(0, lineNumber - 1)]
                symbols.append(SourceSymbol(name: name, kind: rule.kind, lineNumber: lineNumber, charIndex: lineStart))
            }
        }

        // Order by line; if two symbols share a line, keep the earlier rule first.
        symbols.sort { $0.lineNumber < $1.lineNumber }
        return symbols
    }

    private static func computeLineStarts(text: String, length: Int) -> [Int] {
        var starts: [Int] = [0]
        let ns = text as NSString
        var i = 0
        while i < length {
            let r = ns.range(of: "\n", options: [], range: NSRange(location: i, length: length - i))
            if r.location == NSNotFound { break }
            starts.append(r.location + 1)
            i = r.location + 1
        }
        return starts
    }

    private static func lineNumberFor(charIndex: Int, in lineStarts: [Int]) -> Int {
        // Binary search for the largest line start <= charIndex.
        var lo = 0
        var hi = lineStarts.count - 1
        while lo < hi {
            let mid = (lo + hi + 1) / 2
            if lineStarts[mid] <= charIndex {
                lo = mid
            } else {
                hi = mid - 1
            }
        }
        return lo + 1
    }
}
