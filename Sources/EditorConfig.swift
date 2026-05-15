import Foundation

/// Subset of EditorConfig support — enough to honour the most-used keys.
/// Doesn't implement the full spec: see https://spec.editorconfig.org/ for the
/// missing edges (max line length, spelling locale, nested {a,b,c} alternation
/// inside [classes], etc.).
struct EditorConfigSettings: Equatable {
    var indentStyle: String?               // "space" or "tab"
    var indentSize: Int?
    var tabWidth: Int?
    var endOfLine: String?                 // "lf" / "crlf" / "cr"
    var charset: String?                   // "utf-8" / "latin1" / "utf-16be" / "utf-16le"
    var trimTrailingWhitespace: Bool?
    var insertFinalNewline: Bool?
}

enum EditorConfigLoader {

    /// Walk up from `fileURL`'s directory collecting `.editorconfig` files. The
    /// nearest-to-file wins for any given key; ascent stops if a config has
    /// `root = true` at the top level.
    static func resolve(for fileURL: URL) -> EditorConfigSettings {
        var settings = EditorConfigSettings()
        var dir = fileURL.standardizedFileURL.deletingLastPathComponent()
        let fm = FileManager.default
        var visited: Set<String> = []

        // Collect configs leaf-to-root; later we apply root-to-leaf so leaf wins.
        var configs: [(URL, [Section])] = []
        var iterations = 0
        while iterations < 64 {
            iterations += 1
            let key = dir.standardizedFileURL.path
            if visited.contains(key) { break }
            visited.insert(key)
            let cfgURL = dir.appendingPathComponent(".editorconfig")
            if fm.fileExists(atPath: cfgURL.path),
               let contents = try? String(contentsOf: cfgURL, encoding: .utf8) {
                let parsed = parse(contents)
                configs.append((cfgURL, parsed.sections))
                if parsed.root { break }
            }
            let parent = dir.deletingLastPathComponent()
            if parent.standardizedFileURL.path == dir.standardizedFileURL.path { break }
            dir = parent
        }

        // Apply root-to-leaf so closer configs override farther ones.
        for (cfgURL, sections) in configs.reversed() {
            let cfgDir = cfgURL.deletingLastPathComponent()
            let relPath = relative(of: fileURL, to: cfgDir)
            for section in sections {
                if Glob.matches(pattern: section.pattern, path: relPath) {
                    apply(section.settings, into: &settings)
                }
            }
        }
        return settings
    }

    private static func relative(of file: URL, to base: URL) -> String {
        let f = file.standardizedFileURL.path
        let b = base.standardizedFileURL.path
        if f.hasPrefix(b) {
            var rel = String(f.dropFirst(b.count))
            if rel.hasPrefix("/") { rel.removeFirst() }
            return rel
        }
        return file.lastPathComponent
    }

    private static func apply(_ raw: [String: String], into settings: inout EditorConfigSettings) {
        if let v = raw["indent_style"]?.lowercased() { settings.indentStyle = v }
        if let v = raw["indent_size"], let n = Int(v) { settings.indentSize = n }
        if let v = raw["tab_width"], let n = Int(v) { settings.tabWidth = n }
        if let v = raw["end_of_line"]?.lowercased() { settings.endOfLine = v }
        if let v = raw["charset"]?.lowercased() { settings.charset = v }
        if let v = raw["trim_trailing_whitespace"] { settings.trimTrailingWhitespace = parseBool(v) }
        if let v = raw["insert_final_newline"] { settings.insertFinalNewline = parseBool(v) }
    }

    private static func parseBool(_ s: String) -> Bool? {
        switch s.lowercased() {
        case "true", "1", "yes": return true
        case "false", "0", "no": return false
        default: return nil
        }
    }

    // MARK: Parser

    struct Section {
        let pattern: String
        var settings: [String: String]
    }

    struct ParsedFile {
        let root: Bool
        let sections: [Section]
    }

    static func parse(_ contents: String) -> ParsedFile {
        var root = false
        var sections: [Section] = []
        var preamble: [String: String] = [:]
        var current: Section? = nil

        for rawLine in contents.components(separatedBy: "\n") {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }
            if line.hasPrefix("#") || line.hasPrefix(";") { continue }
            if line.hasPrefix("[") && line.hasSuffix("]") {
                if let c = current { sections.append(c) }
                let pat = String(line.dropFirst().dropLast()).trimmingCharacters(in: .whitespaces)
                current = Section(pattern: pat, settings: [:])
                continue
            }
            // key = value
            guard let eq = line.firstIndex(of: "=") else { continue }
            let key = line[..<eq].trimmingCharacters(in: .whitespaces).lowercased()
            let value = line[line.index(after: eq)...].trimmingCharacters(in: .whitespaces)
            if current != nil {
                current!.settings[key] = value
            } else {
                if key == "root", parseBool(value) == true { root = true }
                preamble[key] = value
            }
        }
        if let c = current { sections.append(c) }
        return ParsedFile(root: root, sections: sections)
    }
}

/// EditorConfig-flavoured glob matcher. Handles:
///   *      — any chars except `/`
///   **     — any chars including `/`
///   ?      — single char except `/`
///   [abc]  — character class
///   [!abc] — negated character class
///   {a,b}  — alternation
enum Glob {

    static func matches(pattern: String, path: String) -> Bool {
        // Expand {a,b,c} alternation by enumerating the alternatives.
        let expanded = expandAlternation(pattern)
        for p in expanded {
            if matchSingle(pattern: p, path: path) { return true }
        }
        return false
    }

    static func expandAlternation(_ pattern: String) -> [String] {
        guard let open = pattern.firstIndex(of: "{") else { return [pattern] }
        // Find matching close brace.
        var depth = 0
        var closeIdx: String.Index? = nil
        var i = open
        while i < pattern.endIndex {
            let c = pattern[i]
            if c == "{" { depth += 1 }
            else if c == "}" {
                depth -= 1
                if depth == 0 { closeIdx = i; break }
            }
            i = pattern.index(after: i)
        }
        guard let close = closeIdx else { return [pattern] }
        let prefix = String(pattern[..<open])
        let suffix = String(pattern[pattern.index(after: close)...])
        let inner = String(pattern[pattern.index(after: open)..<close])
        let parts = splitTopLevelCommas(inner)
        var result: [String] = []
        for part in parts {
            for tail in expandAlternation(suffix) {
                let composed = prefix + part + tail
                result.append(contentsOf: expandAlternation(composed))
            }
        }
        return result
    }

    private static func splitTopLevelCommas(_ s: String) -> [String] {
        var parts: [String] = []
        var depth = 0
        var current = ""
        for ch in s {
            if ch == "{" { depth += 1; current.append(ch) }
            else if ch == "}" { depth -= 1; current.append(ch) }
            else if ch == "," && depth == 0 {
                parts.append(current); current = ""
            } else {
                current.append(ch)
            }
        }
        parts.append(current)
        return parts
    }

    /// Convert a glob (without `{a,b}` alternation, which is pre-expanded) to a
    /// regex and match `path` against it. The match is anchored both sides.
    static func matchSingle(pattern: String, path: String) -> Bool {
        var regex = "^"
        let chars = Array(pattern)
        var i = 0
        while i < chars.count {
            let c = chars[i]
            switch c {
            case "*":
                if i + 1 < chars.count && chars[i + 1] == "*" {
                    regex += ".*"
                    i += 2
                    continue
                }
                regex += "[^/]*"
            case "?":
                regex += "[^/]"
            case "[":
                // Find matching ]
                var j = i + 1
                while j < chars.count && chars[j] != "]" { j += 1 }
                if j >= chars.count {
                    regex += "\\["
                } else {
                    var cls = String(chars[(i+1)..<j])
                    if cls.hasPrefix("!") {
                        cls.removeFirst()
                        regex += "[^" + cls + "]"
                    } else {
                        regex += "[" + cls + "]"
                    }
                    i = j
                }
            case ".", "(", ")", "+", "|", "^", "$", "\\":
                regex += "\\\(c)"
            default:
                regex.append(c)
            }
            i += 1
        }
        regex += "$"
        guard let re = try? NSRegularExpression(pattern: regex, options: []) else { return false }
        let range = NSRange(location: 0, length: (path as NSString).length)
        return re.firstMatch(in: path, options: [], range: range) != nil
    }
}
