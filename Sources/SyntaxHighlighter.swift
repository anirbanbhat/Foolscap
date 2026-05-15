import AppKit

enum SyntaxHighlighter {

    enum Language: String, CaseIterable {
        case plain
        case swift
        case python
        case javascript
        case json
        case markdown
        case html
        case css
        case yaml
        case xml
        case shell
        case c
        case cpp
        case go
        case rust

        var displayName: String {
            switch self {
            case .plain: return "Plain Text"
            case .swift: return "Swift"
            case .python: return "Python"
            case .javascript: return "JavaScript"
            case .json: return "JSON"
            case .markdown: return "Markdown"
            case .html: return "HTML"
            case .css: return "CSS"
            case .yaml: return "YAML"
            case .xml: return "XML"
            case .shell: return "Shell"
            case .c: return "C"
            case .cpp: return "C++"
            case .go: return "Go"
            case .rust: return "Rust"
            }
        }
    }

    struct Theme {
        let text: NSColor
        let keyword: NSColor
        let string: NSColor
        let number: NSColor
        let comment: NSColor
        let typeName: NSColor
        let decorator: NSColor
        let punctuation: NSColor
        let heading: NSColor
        let tag: NSColor
        let attr: NSColor

        static let `default` = Theme(
            text: NSColor.textColor,
            keyword: NSColor.systemPink,
            string: NSColor.systemRed,
            number: NSColor.systemOrange,
            comment: NSColor.systemGreen,
            typeName: NSColor.systemTeal,
            decorator: NSColor.systemPurple,
            punctuation: NSColor.secondaryLabelColor,
            heading: NSColor.systemBlue,
            tag: NSColor.systemBlue,
            attr: NSColor.systemPurple
        )
    }

    struct Rule {
        let regex: NSRegularExpression
        let color: NSColor
        let bold: Bool
        let multiline: Bool

        init(_ pattern: String, _ color: NSColor, bold: Bool = false, multiline: Bool = false, options: NSRegularExpression.Options = []) {
            // Force-try: patterns are compile-time constants.
            self.regex = try! NSRegularExpression(pattern: pattern, options: options)
            self.color = color
            self.bold = bold
            self.multiline = multiline
        }
    }

    static func detect(filename: String) -> Language {
        let ext = (filename as NSString).pathExtension.lowercased()
        switch ext {
        case "swift": return .swift
        case "py", "pyw": return .python
        case "js", "mjs", "cjs", "jsx", "ts", "tsx": return .javascript
        case "json": return .json
        case "md", "markdown": return .markdown
        case "html", "htm", "xhtml": return .html
        case "css", "scss", "sass", "less": return .css
        case "yaml", "yml": return .yaml
        case "xml", "plist", "svg": return .xml
        case "sh", "bash", "zsh", "fish", "ksh", "command": return .shell
        case "c", "h": return .c
        case "cpp", "cxx", "cc", "hpp", "hxx", "hh": return .cpp
        case "go": return .go
        case "rs": return .rust
        default: return .plain
        }
    }

    private static var ruleCache: [Language: [Rule]] = [:]

    static func rules(for lang: Language, theme: Theme = .default) -> [Rule] {
        if let cached = ruleCache[lang] { return cached }
        let rules: [Rule]
        switch lang {
        case .plain:
            rules = []
        case .swift:
            rules = [
                Rule(#"/\*[\s\S]*?\*/"#, theme.comment, multiline: true),
                Rule(#""""[\s\S]*?""""#, theme.string, multiline: true),
                Rule(#"\b(class|struct|enum|protocol|extension|func|var|let|if|else|guard|switch|case|default|for|in|while|repeat|do|try|catch|throw|throws|rethrows|return|break|continue|fallthrough|where|as|is|nil|true|false|self|Self|super|import|public|private|fileprivate|internal|open|static|final|override|init|deinit|associatedtype|typealias|inout|defer|async|await|actor|some|any|lazy|weak|unowned|mutating|nonmutating|convenience|required|@objc|@available|@discardableResult|@escaping|@autoclosure|@MainActor|@Sendable)\b"#, theme.keyword, bold: true),
                Rule(#""(?:\\.|[^"\\])*""#, theme.string),
                Rule(#"//[^\n]*"#, theme.comment),
                Rule(#"\b\d+(\.\d+)?\b"#, theme.number),
                Rule(#"\b[A-Z][A-Za-z0-9_]*\b"#, theme.typeName),
            ]
        case .python:
            rules = [
                Rule(#""""[\s\S]*?""""#, theme.string, multiline: true),
                Rule(#"'''[\s\S]*?'''"#, theme.string, multiline: true),
                Rule(#"\b(False|None|True|and|as|assert|async|await|break|class|continue|def|del|elif|else|except|finally|for|from|global|if|import|in|is|lambda|nonlocal|not|or|pass|raise|return|try|while|with|yield|match|case)\b"#, theme.keyword, bold: true),
                Rule(#""(?:\\.|[^"\\\n])*""#, theme.string),
                Rule(#"'(?:\\.|[^'\\\n])*'"#, theme.string),
                Rule(#"#[^\n]*"#, theme.comment),
                Rule(#"@[A-Za-z_][A-Za-z0-9_\.]*"#, theme.decorator),
                Rule(#"\b\d+(\.\d+)?\b"#, theme.number),
            ]
        case .javascript:
            rules = [
                Rule(#"/\*[\s\S]*?\*/"#, theme.comment, multiline: true),
                Rule(#"`(?:\\.|[^`\\])*`"#, theme.string, multiline: true),
                Rule(#"\b(var|let|const|function|return|if|else|for|while|do|switch|case|default|break|continue|new|this|super|class|extends|import|export|from|as|default|typeof|instanceof|in|of|try|catch|finally|throw|async|await|yield|true|false|null|undefined|void|delete|interface|type|enum|namespace|module|public|private|protected|static|readonly|abstract)\b"#, theme.keyword, bold: true),
                Rule(#""(?:\\.|[^"\\\n])*""#, theme.string),
                Rule(#"'(?:\\.|[^'\\\n])*'"#, theme.string),
                Rule(#"//[^\n]*"#, theme.comment),
                Rule(#"\b\d+(\.\d+)?\b"#, theme.number),
                Rule(#"\b[A-Z][A-Za-z0-9_]*\b"#, theme.typeName),
            ]
        case .json:
            rules = [
                Rule(#""(?:\\.|[^"\\])*"\s*(?=:)"#, theme.typeName, bold: true),
                Rule(#""(?:\\.|[^"\\])*""#, theme.string),
                Rule(#"\b(true|false|null)\b"#, theme.keyword, bold: true),
                Rule(#"-?\b\d+(\.\d+)?([eE][+-]?\d+)?\b"#, theme.number),
                Rule(#"[\{\}\[\],:]"#, theme.punctuation),
            ]
        case .markdown:
            rules = [
                Rule(#"```[\s\S]*?```"#, theme.string, multiline: true),
                Rule(#"^#{1,6}\s+[^\n]*"#, theme.heading, bold: true, options: [.anchorsMatchLines]),
                Rule(#"\*\*[^*\n]+\*\*"#, theme.text, bold: true),
                Rule(#"__[^_\n]+__"#, theme.text, bold: true),
                Rule(#"\*[^*\n]+\*"#, theme.keyword),
                Rule(#"_[^_\n]+_"#, theme.keyword),
                Rule(#"`[^`\n]+`"#, theme.string),
                Rule(#"\[[^\]]+\]\([^)]+\)"#, theme.typeName),
                Rule(#"^>\s.*"#, theme.comment, options: [.anchorsMatchLines]),
                Rule(#"^(\s*[-*+]|\s*\d+\.)\s+"#, theme.decorator, options: [.anchorsMatchLines]),
            ]
        case .html:
            rules = [
                Rule(#"<!--[\s\S]*?-->"#, theme.comment, multiline: true),
                Rule(#"<!\[CDATA\[[\s\S]*?\]\]>"#, theme.string, multiline: true),
                Rule(#"<\?[\s\S]*?\?>"#, theme.decorator, multiline: true),
                Rule(#""(?:\\.|[^"\\])*""#, theme.string),
                Rule(#"'(?:\\.|[^'\\])*'"#, theme.string),
                Rule(#"</?[A-Za-z][A-Za-z0-9_-]*"#, theme.tag, bold: true),
                Rule(#"\b[A-Za-z_-]+(?=\s*=)"#, theme.attr),
                Rule(#"/?>"#, theme.tag),
                Rule(#"&[#A-Za-z0-9]+;"#, theme.decorator),
            ]
        case .css:
            rules = [
                Rule(#"/\*[\s\S]*?\*/"#, theme.comment, multiline: true),
                Rule(#""(?:\\.|[^"\\])*""#, theme.string),
                Rule(#"'(?:\\.|[^'\\])*'"#, theme.string),
                Rule(#"#[A-Fa-f0-9]{3,8}\b"#, theme.number),
                Rule(#"-?\b\d+(\.\d+)?(px|em|rem|%|vh|vw|pt|deg|s|ms)?\b"#, theme.number),
                Rule(#"@[a-zA-Z-]+"#, theme.decorator),
                Rule(#"\b[a-z-]+(?=\s*:)"#, theme.attr),
                Rule(#"[.#][A-Za-z_][A-Za-z0-9_-]*"#, theme.tag, bold: true),
                Rule(#":[a-z-]+(\([^)]*\))?"#, theme.decorator),
                Rule(#"!important"#, theme.keyword, bold: true),
            ]
        case .yaml:
            rules = [
                Rule(#"#[^\n]*"#, theme.comment),
                Rule(#""(?:\\.|[^"\\])*""#, theme.string),
                Rule(#"'(?:\\.|[^'\\])*'"#, theme.string),
                Rule(#"^\s*-\s+"#, theme.decorator, options: [.anchorsMatchLines]),
                Rule(#"^\s*[A-Za-z_][A-Za-z0-9_-]*(?=\s*:)"#, theme.attr, options: [.anchorsMatchLines]),
                Rule(#"\b(true|false|null|yes|no|on|off|~)\b"#, theme.keyword, bold: true),
                Rule(#"-?\b\d+(\.\d+)?\b"#, theme.number),
                Rule(#"^---\s*$"#, theme.punctuation, options: [.anchorsMatchLines]),
            ]
        case .xml:
            rules = [
                Rule(#"<!--[\s\S]*?-->"#, theme.comment, multiline: true),
                Rule(#"<!\[CDATA\[[\s\S]*?\]\]>"#, theme.string, multiline: true),
                Rule(#"<\?[\s\S]*?\?>"#, theme.decorator, multiline: true),
                Rule(#""(?:\\.|[^"\\])*""#, theme.string),
                Rule(#"'(?:\\.|[^'\\])*'"#, theme.string),
                Rule(#"</?[A-Za-z_][A-Za-z0-9_:.-]*"#, theme.tag, bold: true),
                Rule(#"\b[A-Za-z_][A-Za-z0-9_:.-]*(?=\s*=)"#, theme.attr),
                Rule(#"/?>"#, theme.tag),
            ]
        case .shell:
            rules = [
                Rule(#""(?:\\.|[^"\\])*""#, theme.string),
                Rule(#"'[^']*'"#, theme.string),
                Rule(#"#[^\n]*"#, theme.comment),
                Rule(#"\b(if|then|else|elif|fi|case|esac|for|in|while|do|done|until|function|return|break|continue|exit|export|local|readonly|declare|typeset|alias|unalias|set|unset|shift|source|eval|exec|trap|test|true|false|select)\b"#, theme.keyword, bold: true),
                Rule(#"\$\{[^}]+\}"#, theme.decorator),
                Rule(#"\$[A-Za-z_][A-Za-z0-9_]*"#, theme.decorator),
                Rule(#"\$\d+"#, theme.decorator),
                Rule(#"^\s*[A-Za-z_][A-Za-z0-9_]*(?=\s*\(\s*\))"#, theme.typeName, options: [.anchorsMatchLines]),
            ]
        case .c, .cpp:
            let cppExtra = lang == .cpp ? "|class|namespace|template|typename|public|private|protected|virtual|override|final|new|delete|this|nullptr|using|operator|friend|explicit|mutable|constexpr|noexcept|decltype|auto|try|catch|throw" : ""
            rules = [
                Rule(#"/\*[\s\S]*?\*/"#, theme.comment, multiline: true),
                Rule(#"^\s*#\s*\w+[^\n]*"#, theme.decorator, options: [.anchorsMatchLines]),
                Rule("\\b(if|else|for|while|do|switch|case|default|break|continue|return|goto|sizeof|typedef|struct|union|enum|static|extern|const|volatile|register|inline|void|char|short|int|long|float|double|signed|unsigned|bool|true|false|NULL\(cppExtra))\\b", theme.keyword, bold: true),
                Rule(#""(?:\\.|[^"\\\n])*""#, theme.string),
                Rule(#"'(?:\\.|[^'\\\n])*'"#, theme.string),
                Rule(#"//[^\n]*"#, theme.comment),
                Rule(#"\b\d+(\.\d+)?[fFlLuU]*\b"#, theme.number),
                Rule(#"\b[A-Z][A-Z0-9_]+\b"#, theme.typeName),
            ]
        case .go:
            rules = [
                Rule(#"/\*[\s\S]*?\*/"#, theme.comment, multiline: true),
                Rule(#"`[^`]*`"#, theme.string, multiline: true),
                Rule(#"\b(break|case|chan|const|continue|default|defer|else|fallthrough|for|func|go|goto|if|import|interface|map|package|range|return|select|struct|switch|type|var|true|false|nil|iota|make|new|len|cap|append|copy|delete|panic|recover|close|complex|real|imag)\b"#, theme.keyword, bold: true),
                Rule(#"\b(bool|byte|complex64|complex128|error|float32|float64|int|int8|int16|int32|int64|rune|string|uint|uint8|uint16|uint32|uint64|uintptr|any)\b"#, theme.typeName, bold: true),
                Rule(#""(?:\\.|[^"\\\n])*""#, theme.string),
                Rule(#"//[^\n]*"#, theme.comment),
                Rule(#"\b\d+(\.\d+)?\b"#, theme.number),
            ]
        case .rust:
            rules = [
                Rule(#"/\*[\s\S]*?\*/"#, theme.comment, multiline: true),
                Rule(#"\b(as|async|await|break|const|continue|crate|dyn|else|enum|extern|false|fn|for|if|impl|in|let|loop|match|mod|move|mut|pub|ref|return|self|Self|static|struct|super|trait|true|type|unsafe|use|where|while|box|union|macro_rules)\b"#, theme.keyword, bold: true),
                Rule(#"\b(i8|i16|i32|i64|i128|isize|u8|u16|u32|u64|u128|usize|f32|f64|bool|char|str|String|Vec|Option|Result|Box|Rc|Arc)\b"#, theme.typeName, bold: true),
                Rule(#""(?:\\.|[^"\\])*""#, theme.string),
                Rule(#"'(?:\\.|[^'\\])'"#, theme.string),
                Rule(#"//[^\n]*"#, theme.comment),
                Rule(#"#!?\[[^\]]+\]"#, theme.decorator),
                Rule(#"\b\d+(\.\d+)?\b"#, theme.number),
                Rule(#"'[a-z_][a-z0-9_]*"#, theme.decorator),
            ]
        }
        ruleCache[lang] = rules
        return rules
    }

    static func hasMultilineConstructs(_ lang: Language) -> Bool {
        return rules(for: lang).contains { $0.multiline }
    }

    // Compute the range to rehighlight after an edit.
    // For languages with multi-line constructs (block comments, triple-quoted
    // strings, template literals, etc.), a small paragraph window can miss
    // openers/closers and leave stale colors. Strategy:
    //   - Plain or no-multiline language → just the edited paragraph.
    //   - Multiline-capable + small buffer → rehighlight whole buffer.
    //   - Large buffer → extend by a large window around the edit.
    static func rangeForRehighlight(in textStorage: NSTextStorage,
                                    editedRange: NSRange,
                                    language: Language) -> NSRange {
        let nsString = textStorage.string as NSString
        let len = nsString.length
        let para = nsString.paragraphRange(for: editedRange)
        guard hasMultilineConstructs(language) else { return para }
        if len <= 200_000 {
            return NSRange(location: 0, length: len)
        }
        // Large file: extend by ~50KB around the edit.
        let start = max(0, para.location - 50_000)
        let end = min(len, NSMaxRange(para) + 50_000)
        return NSRange(location: start, length: end - start)
    }

    static func highlight(_ storage: NSTextStorage, range: NSRange, language: Language, font: NSFont) {
        let baseAttrs: [NSAttributedString.Key: Any] = [
            .foregroundColor: Theme.default.text,
            .font: font
        ]
        storage.setAttributes(baseAttrs, range: range)
        guard language != .plain else { return }

        let boldFont = NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask)
        let str = storage.string
        for rule in rules(for: language) {
            rule.regex.enumerateMatches(in: str, options: [], range: range) { match, _, _ in
                guard let m = match else { return }
                var attrs: [NSAttributedString.Key: Any] = [.foregroundColor: rule.color]
                if rule.bold { attrs[.font] = boldFont }
                storage.addAttributes(attrs, range: m.range)
            }
        }
    }
}
