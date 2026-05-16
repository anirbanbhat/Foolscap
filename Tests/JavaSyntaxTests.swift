import Foundation

func registerJavaSyntaxTests() {
    let suite = "Java/SyntaxHighlighter"

    test(suite, "java extension detected") {
        try assertEqual(SyntaxHighlighter.detect(filename: "Foo.java"), .java)
    }
    test(suite, "java uppercase extension still detected") {
        try assertEqual(SyntaxHighlighter.detect(filename: "Foo.JAVA"), .java)
    }
    test(suite, "java has multi-line constructs (block comments + text blocks)") {
        try assertTrue(SyntaxHighlighter.hasMultilineConstructs(.java))
    }
    test(suite, "java rules are non-empty") {
        try assertTrue(SyntaxHighlighter.rules(for: .java).count > 0)
    }
    test(suite, "java appears in allCases") {
        try assertTrue(SyntaxHighlighter.Language.allCases.contains(.java))
    }
    test(suite, "java display name") {
        try assertEqual(SyntaxHighlighter.Language.java.displayName, "Java")
    }
    test(suite, "Java has a snippet registry") {
        try assertTrue(SnippetEngine.snippets(for: .java).count > 0)
    }
    test(suite, "Java psvm snippet expands to main method") {
        let sn = SnippetEngine.snippet(trigger: "psvm", in: .java)
        try assertNotNil(sn)
        let e = SnippetEngine.expand(sn!)
        try assertContains(e.text, "public static void main(String[] args)")
    }
}
