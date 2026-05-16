import Foundation

struct Snippet: Equatable {
    let trigger: String
    let body: String
    let description: String
}

struct ExpandedSnippet: Equatable {
    let text: String
    /// Range, in `text`, of the first tab stop's placeholder. The caller
    /// should set the editor's selection here so the user can immediately
    /// type to replace it. nil if the snippet has no tab stops.
    let firstStopRange: NSRange?
}

enum SnippetEngine {

    /// Tab-trigger snippets per language. Body uses TextMate-style
    /// `${N:default}` tab stops; `\n` is inserted as a real newline.
    static func snippets(for lang: SyntaxHighlighter.Language) -> [Snippet] {
        return registry[lang] ?? []
    }

    static func snippet(trigger: String, in lang: SyntaxHighlighter.Language) -> Snippet? {
        return snippets(for: lang).first { $0.trigger == trigger }
    }

    /// Replace `${N:default}` with `default` and return the final string plus
    /// the absolute range of the first tab stop's placeholder. Stops with no
    /// default text (`${N}`) get an empty placeholder; their range has length 0.
    static func expand(_ snippet: Snippet) -> ExpandedSnippet {
        let body = snippet.body
        var out = ""
        var firstStop: NSRange?
        var lowestStopSeen = Int.max

        var i = body.startIndex
        while i < body.endIndex {
            let c = body[i]
            if c == "$", let next = body.index(i, offsetBy: 1, limitedBy: body.endIndex), next < body.endIndex, body[next] == "{" {
                // ${N:default} or ${N}
                if let close = body[next...].firstIndex(of: "}") {
                    let inner = String(body[body.index(after: next)..<close])
                    let (stop, def) = parseStop(inner)
                    let nsLocation = (out as NSString).length
                    out += def
                    if let s = stop, s < lowestStopSeen {
                        lowestStopSeen = s
                        firstStop = NSRange(location: nsLocation, length: (def as NSString).length)
                    }
                    i = body.index(after: close)
                    continue
                }
            }
            out.append(c)
            i = body.index(after: i)
        }

        return ExpandedSnippet(text: out, firstStopRange: firstStop)
    }

    private static func parseStop(_ inner: String) -> (Int?, String) {
        // Forms:  "1"         → stop 1, no default
        //         "1:hello"   → stop 1, default "hello"
        if let colon = inner.firstIndex(of: ":") {
            let numPart = inner[..<colon]
            let def = String(inner[inner.index(after: colon)...])
            return (Int(numPart), def)
        }
        return (Int(inner), "")
    }

    // MARK: Built-in registry

    private static let registry: [SyntaxHighlighter.Language: [Snippet]] = [
        .swift: [
            Snippet(trigger: "func", body: "func ${1:name}(${2:args}) ${3:-> ReturnType }{\n    ${0}\n}", description: "Swift function"),
            Snippet(trigger: "class", body: "class ${1:Name} {\n    ${0}\n}", description: "Swift class"),
            Snippet(trigger: "struct", body: "struct ${1:Name} {\n    ${0}\n}", description: "Swift struct"),
            Snippet(trigger: "enum", body: "enum ${1:Name} {\n    case ${0}\n}", description: "Swift enum"),
            Snippet(trigger: "if", body: "if ${1:condition} {\n    ${0}\n}", description: "if"),
            Snippet(trigger: "guard", body: "guard ${1:condition} else {\n    ${2:return}\n}\n${0}", description: "guard"),
            Snippet(trigger: "for", body: "for ${1:item} in ${2:collection} {\n    ${0}\n}", description: "for-in"),
            Snippet(trigger: "print", body: "print(${1:value})${0}", description: "print"),
        ],
        .python: [
            Snippet(trigger: "def", body: "def ${1:name}(${2:args}):\n    ${0}", description: "function"),
            Snippet(trigger: "class", body: "class ${1:Name}:\n    def __init__(self${2:, args}):\n        ${0}", description: "class"),
            Snippet(trigger: "if", body: "if ${1:condition}:\n    ${0}", description: "if"),
            Snippet(trigger: "for", body: "for ${1:item} in ${2:iterable}:\n    ${0}", description: "for"),
            Snippet(trigger: "try", body: "try:\n    ${1:body}\nexcept ${2:Exception} as e:\n    ${0}", description: "try/except"),
            Snippet(trigger: "main", body: "if __name__ == \"__main__\":\n    ${0}", description: "main guard"),
        ],
        .javascript: [
            Snippet(trigger: "function", body: "function ${1:name}(${2:args}) {\n    ${0}\n}", description: "function"),
            Snippet(trigger: "class", body: "class ${1:Name} {\n    constructor(${2:args}) {\n        ${0}\n    }\n}", description: "class"),
            Snippet(trigger: "if", body: "if (${1:condition}) {\n    ${0}\n}", description: "if"),
            Snippet(trigger: "for", body: "for (let ${1:i} = 0; ${1:i} < ${2:n}; ${1:i}++) {\n    ${0}\n}", description: "for"),
            Snippet(trigger: "arrow", body: "(${1:args}) => {\n    ${0}\n}", description: "arrow function"),
            Snippet(trigger: "log", body: "console.log(${1:value});${0}", description: "console.log"),
        ],
        .java: [
            Snippet(trigger: "psvm", body: "public static void main(String[] args) {\n    ${0}\n}", description: "main method"),
            Snippet(trigger: "sout", body: "System.out.println(${1:value});${0}", description: "println"),
            Snippet(trigger: "class", body: "public class ${1:Name} {\n    ${0}\n}", description: "public class"),
            Snippet(trigger: "if", body: "if (${1:condition}) {\n    ${0}\n}", description: "if"),
            Snippet(trigger: "for", body: "for (int ${1:i} = 0; ${1:i} < ${2:n}; ${1:i}++) {\n    ${0}\n}", description: "for"),
            Snippet(trigger: "try", body: "try {\n    ${1:body}\n} catch (${2:Exception} e) {\n    ${0}\n}", description: "try/catch"),
        ],
        .go: [
            Snippet(trigger: "func", body: "func ${1:name}(${2:args}) ${3:returnType} {\n    ${0}\n}", description: "function"),
            Snippet(trigger: "if", body: "if ${1:condition} {\n    ${0}\n}", description: "if"),
            Snippet(trigger: "for", body: "for ${1:i} := 0; ${1:i} < ${2:n}; ${1:i}++ {\n    ${0}\n}", description: "for"),
            Snippet(trigger: "main", body: "package main\n\nimport \"fmt\"\n\nfunc main() {\n    ${0}\n}", description: "package main"),
        ],
        .rust: [
            Snippet(trigger: "fn", body: "fn ${1:name}(${2:args}) ${3:-> ReturnType }{\n    ${0}\n}", description: "function"),
            Snippet(trigger: "if", body: "if ${1:condition} {\n    ${0}\n}", description: "if"),
            Snippet(trigger: "match", body: "match ${1:value} {\n    ${2:pattern} => ${0},\n}", description: "match"),
            Snippet(trigger: "impl", body: "impl ${1:Type} {\n    ${0}\n}", description: "impl"),
        ],
        .c: [
            Snippet(trigger: "main", body: "int main(int argc, char *argv[]) {\n    ${0}\n    return 0;\n}", description: "main"),
            Snippet(trigger: "if", body: "if (${1:condition}) {\n    ${0}\n}", description: "if"),
            Snippet(trigger: "for", body: "for (int ${1:i} = 0; ${1:i} < ${2:n}; ${1:i}++) {\n    ${0}\n}", description: "for"),
        ],
        .cpp: [
            Snippet(trigger: "main", body: "int main(int argc, char *argv[]) {\n    ${0}\n    return 0;\n}", description: "main"),
            Snippet(trigger: "if", body: "if (${1:condition}) {\n    ${0}\n}", description: "if"),
            Snippet(trigger: "for", body: "for (int ${1:i} = 0; ${1:i} < ${2:n}; ${1:i}++) {\n    ${0}\n}", description: "for"),
            Snippet(trigger: "class", body: "class ${1:Name} {\npublic:\n    ${0}\n};", description: "class"),
        ],
        .shell: [
            Snippet(trigger: "if", body: "if ${1:condition}; then\n    ${0}\nfi", description: "if"),
            Snippet(trigger: "for", body: "for ${1:i} in ${2:items}; do\n    ${0}\ndone", description: "for"),
            Snippet(trigger: "fn", body: "${1:name}() {\n    ${0}\n}", description: "function"),
        ],
    ]
}
