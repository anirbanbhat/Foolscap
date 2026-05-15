import Foundation

enum StringConversions {

    /// Split a string into "words" using non-alphanumeric and case-boundary cues.
    private static func words(_ s: String) -> [String] {
        // First split on any non-alphanumeric run.
        let raw = s.unicodeScalars.split { !($0.value < 128 && (CharacterSet.alphanumerics.contains($0))) }.map(String.init)
        // Then split each chunk on lower→upper boundaries (camelCase → camel, Case).
        var result: [String] = []
        for chunk in raw {
            var cur = ""
            var prev: Character? = nil
            for ch in chunk {
                if let p = prev, p.isLowercase, ch.isUppercase {
                    if !cur.isEmpty { result.append(cur) }
                    cur = String(ch)
                } else {
                    cur.append(ch)
                }
                prev = ch
            }
            if !cur.isEmpty { result.append(cur) }
        }
        return result
    }

    static func camelCase(_ s: String) -> String {
        let ws = words(s)
        guard !ws.isEmpty else { return s }
        var out = ws[0].lowercased()
        for w in ws.dropFirst() {
            out += w.prefix(1).uppercased() + w.dropFirst().lowercased()
        }
        return out
    }

    static func pascalCase(_ s: String) -> String {
        return words(s).map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }.joined()
    }

    static func snakeCase(_ s: String) -> String {
        return words(s).map { $0.lowercased() }.joined(separator: "_")
    }

    static func kebabCase(_ s: String) -> String {
        return words(s).map { $0.lowercased() }.joined(separator: "-")
    }

    // Minimal HTML entity encode/decode — covers the common five plus numeric.
    static func htmlEncode(_ s: String) -> String {
        var out = ""
        out.reserveCapacity(s.count)
        for ch in s {
            switch ch {
            case "&": out += "&amp;"
            case "<": out += "&lt;"
            case ">": out += "&gt;"
            case "\"": out += "&quot;"
            case "'": out += "&#39;"
            default: out.append(ch)
            }
        }
        return out
    }

    static func htmlDecode(_ s: String) -> String {
        // Use NSAttributedString's HTML importer — handles all entities.
        guard let data = s.data(using: .utf8) else { return s }
        let opts: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue,
        ]
        if let attr = try? NSAttributedString(data: data, options: opts, documentAttributes: nil) {
            return attr.string
        }
        return s
    }
}
