import Foundation

func registerSyntaxHighlighterTests() {
    let suite = "SyntaxHighlighter"

    test(suite, "detect swift") {
        try assertEqual(SyntaxHighlighter.detect(filename: "foo.swift"), .swift)
    }
    test(suite, "detect python .py") {
        try assertEqual(SyntaxHighlighter.detect(filename: "foo.py"), .python)
    }
    test(suite, "detect python .pyw") {
        try assertEqual(SyntaxHighlighter.detect(filename: "foo.pyw"), .python)
    }
    test(suite, "detect js .js") {
        try assertEqual(SyntaxHighlighter.detect(filename: "foo.js"), .javascript)
    }
    test(suite, "detect js .mjs") {
        try assertEqual(SyntaxHighlighter.detect(filename: "foo.mjs"), .javascript)
    }
    test(suite, "detect typescript .ts → javascript") {
        try assertEqual(SyntaxHighlighter.detect(filename: "foo.ts"), .javascript)
    }
    test(suite, "detect json") {
        try assertEqual(SyntaxHighlighter.detect(filename: "package.json"), .json)
    }
    test(suite, "detect markdown .md") {
        try assertEqual(SyntaxHighlighter.detect(filename: "README.md"), .markdown)
    }
    test(suite, "detect markdown .markdown") {
        try assertEqual(SyntaxHighlighter.detect(filename: "x.markdown"), .markdown)
    }
    test(suite, "detect html") {
        try assertEqual(SyntaxHighlighter.detect(filename: "index.html"), .html)
    }
    test(suite, "detect css") {
        try assertEqual(SyntaxHighlighter.detect(filename: "style.css"), .css)
    }
    test(suite, "detect css .scss") {
        try assertEqual(SyntaxHighlighter.detect(filename: "style.scss"), .css)
    }
    test(suite, "detect yaml .yml") {
        try assertEqual(SyntaxHighlighter.detect(filename: "ci.yml"), .yaml)
    }
    test(suite, "detect yaml .yaml") {
        try assertEqual(SyntaxHighlighter.detect(filename: "ci.yaml"), .yaml)
    }
    test(suite, "detect xml") {
        try assertEqual(SyntaxHighlighter.detect(filename: "data.xml"), .xml)
    }
    test(suite, "detect plist as xml") {
        try assertEqual(SyntaxHighlighter.detect(filename: "Info.plist"), .xml)
    }
    test(suite, "detect svg as xml") {
        try assertEqual(SyntaxHighlighter.detect(filename: "icon.svg"), .xml)
    }
    test(suite, "detect shell .sh") {
        try assertEqual(SyntaxHighlighter.detect(filename: "build.sh"), .shell)
    }
    test(suite, "detect shell .zsh") {
        try assertEqual(SyntaxHighlighter.detect(filename: "x.zsh"), .shell)
    }
    test(suite, "detect c .c") {
        try assertEqual(SyntaxHighlighter.detect(filename: "main.c"), .c)
    }
    test(suite, "detect c header") {
        try assertEqual(SyntaxHighlighter.detect(filename: "foo.h"), .c)
    }
    test(suite, "detect cpp .cpp") {
        try assertEqual(SyntaxHighlighter.detect(filename: "main.cpp"), .cpp)
    }
    test(suite, "detect cpp .cc") {
        try assertEqual(SyntaxHighlighter.detect(filename: "main.cc"), .cpp)
    }
    test(suite, "detect go") {
        try assertEqual(SyntaxHighlighter.detect(filename: "main.go"), .go)
    }
    test(suite, "detect rust") {
        try assertEqual(SyntaxHighlighter.detect(filename: "lib.rs"), .rust)
    }
    test(suite, "detect plain for unknown extension") {
        try assertEqual(SyntaxHighlighter.detect(filename: "foo.xyz"), .plain)
    }
    test(suite, "detect plain for no extension") {
        try assertEqual(SyntaxHighlighter.detect(filename: "Makefile"), .plain)
    }
    test(suite, "detect uppercase extension is case-insensitive") {
        try assertEqual(SyntaxHighlighter.detect(filename: "FOO.SWIFT"), .swift)
    }
    test(suite, "detect empty filename") {
        try assertEqual(SyntaxHighlighter.detect(filename: ""), .plain)
    }

    // hasMultilineConstructs
    test(suite, "plain has no multi-line constructs") {
        try assertFalse(SyntaxHighlighter.hasMultilineConstructs(.plain))
    }
    test(suite, "swift has multi-line (block comments + triple-quoted strings)") {
        try assertTrue(SyntaxHighlighter.hasMultilineConstructs(.swift))
    }
    test(suite, "python has multi-line (triple-quoted strings)") {
        try assertTrue(SyntaxHighlighter.hasMultilineConstructs(.python))
    }
    test(suite, "json has no multi-line constructs") {
        try assertFalse(SyntaxHighlighter.hasMultilineConstructs(.json))
    }
    test(suite, "markdown has multi-line (fenced code)") {
        try assertTrue(SyntaxHighlighter.hasMultilineConstructs(.markdown))
    }
    test(suite, "html has multi-line (comments)") {
        try assertTrue(SyntaxHighlighter.hasMultilineConstructs(.html))
    }

    // rules
    test(suite, "rules for plain is empty") {
        try assertEqual(SyntaxHighlighter.rules(for: .plain).count, 0)
    }
    test(suite, "rules for swift is non-empty") {
        try assertTrue(SyntaxHighlighter.rules(for: .swift).count > 0)
    }

    // All languages appear in allCases
    test(suite, "allCases covers expected languages") {
        let expected: Set<SyntaxHighlighter.Language> = [
            .plain, .swift, .python, .javascript, .json, .markdown,
            .html, .css, .yaml, .xml, .shell, .c, .cpp, .go, .rust
        ]
        let actual = Set(SyntaxHighlighter.Language.allCases)
        try assertEqual(actual, expected)
    }

    test(suite, "display name uses friendly form") {
        try assertEqual(SyntaxHighlighter.Language.javascript.displayName, "JavaScript")
        try assertEqual(SyntaxHighlighter.Language.cpp.displayName, "C++")
        try assertEqual(SyntaxHighlighter.Language.plain.displayName, "Plain Text")
    }
}
