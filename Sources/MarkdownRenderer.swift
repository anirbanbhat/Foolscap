import AppKit

/// Minimal Markdown-to-NSAttributedString renderer used by the in-app help
/// window. AppKit's `AttributedString(markdown:)` flattens block-level
/// structure, so we convert to HTML ourselves and let NSAttributedString's
/// HTML loader handle paragraphs / headings / lists / tables.
enum MarkdownRenderer {

    static func render(_ markdown: String) -> NSAttributedString {
        let html = wrap(toHTML(markdown))
        guard let data = html.data(using: .utf8) else {
            return NSAttributedString(string: markdown)
        }
        let options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue,
        ]
        guard let attr = try? NSAttributedString(data: data, options: options, documentAttributes: nil) else {
            return NSAttributedString(string: markdown)
        }
        return reskin(attr)
    }

    // MARK: HTML emission

    static func toHTML(_ md: String) -> String {
        let lines = md.components(separatedBy: "\n")
        var html = ""
        var i = 0
        var listStack: [String] = []   // "ul" or "ol"

        func closeListsAbove(level: Int) {
            while listStack.count > level {
                html += "</\(listStack.removeLast())>\n"
            }
        }

        while i < lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty {
                closeListsAbove(level: 0)
                i += 1
                continue
            }

            // Code fence
            if line.hasPrefix("```") {
                closeListsAbove(level: 0)
                html += "<pre><code>"
                i += 1
                while i < lines.count && !lines[i].hasPrefix("```") {
                    html += escapeHTML(lines[i]) + "\n"
                    i += 1
                }
                if i < lines.count { i += 1 }
                html += "</code></pre>\n"
                continue
            }

            // Heading (must come before paragraph)
            if line.hasPrefix("#") {
                closeListsAbove(level: 0)
                var level = 0
                let chars = Array(line)
                while level < chars.count && chars[level] == "#" { level += 1 }
                let text = String(chars.dropFirst(level)).trimmingCharacters(in: .whitespaces)
                let h = min(level, 6)
                html += "<h\(h)>\(inlineHTML(text))</h\(h)>\n"
                i += 1
                continue
            }

            // Horizontal rule
            if trimmed == "---" || trimmed == "***" || trimmed == "___" {
                closeListsAbove(level: 0)
                html += "<hr/>\n"
                i += 1
                continue
            }

            // Block quote (may span multiple lines)
            if line.hasPrefix(">") {
                closeListsAbove(level: 0)
                var quote = String(line.dropFirst()).trimmingCharacters(in: .whitespaces)
                i += 1
                while i < lines.count && lines[i].hasPrefix(">") {
                    quote += " " + String(lines[i].dropFirst()).trimmingCharacters(in: .whitespaces)
                    i += 1
                }
                html += "<blockquote><p>\(inlineHTML(quote))</p></blockquote>\n"
                continue
            }

            // Unordered list item
            if let r = line.range(of: #"^[ \t]*[-*+] +"#, options: .regularExpression) {
                if listStack.last != "ul" {
                    closeListsAbove(level: 0)
                    html += "<ul>\n"
                    listStack.append("ul")
                }
                let content = String(line[r.upperBound...])
                html += "<li>\(inlineHTML(content))</li>\n"
                i += 1
                continue
            }
            // Ordered list item
            if let r = line.range(of: #"^[ \t]*\d+\. +"#, options: .regularExpression) {
                if listStack.last != "ol" {
                    closeListsAbove(level: 0)
                    html += "<ol>\n"
                    listStack.append("ol")
                }
                let content = String(line[r.upperBound...])
                html += "<li>\(inlineHTML(content))</li>\n"
                i += 1
                continue
            }

            // Table (line starts and ends with |)
            if trimmed.hasPrefix("|") && trimmed.hasSuffix("|") && trimmed.count > 2 {
                closeListsAbove(level: 0)
                var rows: [[String]] = []
                while i < lines.count {
                    let t = lines[i].trimmingCharacters(in: .whitespaces)
                    guard t.hasPrefix("|") && t.hasSuffix("|") else { break }
                    let cells = t.dropFirst().dropLast().components(separatedBy: "|").map {
                        $0.trimmingCharacters(in: .whitespaces)
                    }
                    rows.append(cells)
                    i += 1
                }
                guard !rows.isEmpty else { continue }
                let header = rows[0]
                var data = Array(rows.dropFirst())
                if let first = data.first, isSeparatorRow(first) {
                    data.removeFirst()
                }
                html += "<table><thead><tr>"
                for h in header { html += "<th>\(inlineHTML(h))</th>" }
                html += "</tr></thead><tbody>\n"
                for row in data {
                    html += "<tr>"
                    for cell in row { html += "<td>\(inlineHTML(cell))</td>" }
                    html += "</tr>\n"
                }
                html += "</tbody></table>\n"
                continue
            }

            // Paragraph — accumulate consecutive non-blank, non-structural lines
            closeListsAbove(level: 0)
            var para = line.trimmingCharacters(in: .whitespaces)
            i += 1
            while i < lines.count {
                let l = lines[i]
                let s = l.trimmingCharacters(in: .whitespaces)
                if s.isEmpty { break }
                if l.hasPrefix("#") || l.hasPrefix("```") || l.hasPrefix(">") { break }
                if s.hasPrefix("|") && s.hasSuffix("|") { break }
                if l.range(of: #"^[ \t]*[-*+] +"#, options: .regularExpression) != nil { break }
                if l.range(of: #"^[ \t]*\d+\. +"#, options: .regularExpression) != nil { break }
                para += " " + s
                i += 1
            }
            html += "<p>\(inlineHTML(para))</p>\n"
        }
        closeListsAbove(level: 0)
        return html
    }

    static func isSeparatorRow(_ cells: [String]) -> Bool {
        return cells.allSatisfy { cell in
            let c = cell.trimmingCharacters(in: .whitespaces)
            return !c.isEmpty && c.allSatisfy { ch in
                ch == "-" || ch == ":" || ch == " "
            }
        }
    }

    // MARK: Inline transformations

    /// Convert inline Markdown features (code spans, bold, italic, links) inside
    /// a piece of HTML-escaped text. Order matters: code first, then bold, then
    /// italic, then links — so `**foo**` doesn't get italicised mid-replacement.
    static func inlineHTML(_ raw: String) -> String {
        var s = escapeHTML(raw)
        s = replace(s, pattern: #"`([^`]+)`"#, template: "<code>$1</code>")
        s = replace(s, pattern: #"\*\*([^*\n]+)\*\*"#, template: "<strong>$1</strong>")
        s = replace(s, pattern: #"__([^_\n]+)__"#, template: "<strong>$1</strong>")
        s = replace(s, pattern: #"(?<!\*)\*([^*\n]+)\*(?!\*)"#, template: "<em>$1</em>")
        s = replace(s, pattern: #"(?<!_)_([^_\n]+)_(?!_)"#, template: "<em>$1</em>")
        s = replace(s, pattern: #"\[([^\]]+)\]\(([^)]+)\)"#, template: "<a href=\"$2\">$1</a>")
        return s
    }

    private static func replace(_ s: String, pattern: String, template: String) -> String {
        guard let re = try? NSRegularExpression(pattern: pattern, options: []) else { return s }
        let range = NSRange(location: 0, length: (s as NSString).length)
        return re.stringByReplacingMatches(in: s, options: [], range: range, withTemplate: template)
    }

    static func escapeHTML(_ s: String) -> String {
        var out = ""
        out.reserveCapacity(s.count)
        for ch in s {
            switch ch {
            case "&": out += "&amp;"
            case "<": out += "&lt;"
            case ">": out += "&gt;"
            case "\"": out += "&quot;"
            default: out.append(ch)
            }
        }
        return out
    }

    // MARK: Theme-aware post-processing

    /// HTML parser sets explicit RGB colors and font sizes; rewrite them so the
    /// document looks correct in both light and dark mode.
    private static func reskin(_ attr: NSAttributedString) -> NSAttributedString {
        let m = NSMutableAttributedString(attributedString: attr)
        let full = NSRange(location: 0, length: m.length)
        m.removeAttribute(.foregroundColor, range: full)
        m.addAttribute(.foregroundColor, value: NSColor.labelColor, range: full)
        // Re-style: keep font sizes set by the HTML parser, but if we hit a
        // monospace font, give it a subtle code background.
        m.enumerateAttribute(.font, in: full, options: []) { value, r, _ in
            guard let f = value as? NSFont else { return }
            let isMono = f.fontDescriptor.symbolicTraits.contains(.monoSpace) || f.fontName.lowercased().contains("mono") || f.fontName.lowercased().contains("courier")
            if isMono {
                m.addAttribute(.backgroundColor, value: NSColor.controlBackgroundColor.withAlphaComponent(0.6), range: r)
            }
        }
        return m
    }

    // MARK: Wrapping HTML with style

    private static func wrap(_ body: String) -> String {
        return """
        <html><head><meta charset="utf-8"/><style>
        body { font-family: -apple-system, "SF Pro Text", system-ui, sans-serif; font-size: 13px; line-height: 1.55; margin: 0; padding: 0; }
        h1 { font-size: 24px; font-weight: 700; margin: 18px 0 8px 0; }
        h2 { font-size: 19px; font-weight: 700; margin: 16px 0 6px 0; }
        h3 { font-size: 15px; font-weight: 700; margin: 12px 0 4px 0; }
        h4, h5, h6 { font-size: 13px; font-weight: 700; margin: 10px 0 4px 0; }
        p { margin: 6px 0 10px 0; }
        ul, ol { margin: 4px 0 10px 0; padding-left: 28px; }
        li { margin: 3px 0; }
        code { font-family: "SF Mono", Menlo, Monaco, monospace; font-size: 12px; padding: 1px 4px; }
        pre { font-family: "SF Mono", Menlo, Monaco, monospace; font-size: 12px; padding: 10px; margin: 8px 0 12px 0; line-height: 1.4; }
        pre code { padding: 0; }
        table { border-collapse: collapse; margin: 8px 0 14px 0; }
        th, td { border: 1px solid #999; padding: 5px 10px; text-align: left; vertical-align: top; }
        th { font-weight: 700; }
        blockquote { margin: 8px 0 8px 16px; font-style: italic; }
        hr { border: 0; border-top: 1px solid #888; margin: 16px 0; }
        a { text-decoration: underline; }
        </style></head><body>
        \(body)
        </body></html>
        """
    }
}
