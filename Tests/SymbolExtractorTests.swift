import Foundation

func registerSymbolExtractorTests() {
    let suite = "SymbolExtractor"

    test(suite, "plain text returns no symbols") {
        try assertEqual(SymbolExtractor.symbols(in: "just some words", language: .plain), [])
    }

    test(suite, "swift func is extracted") {
        let src = """
        import Foundation

        func foo() {
            print("hi")
        }

        func bar() {}
        """
        let syms = SymbolExtractor.symbols(in: src, language: .swift)
        try assertEqual(syms.count, 2)
        try assertEqual(syms[0].name, "foo")
        try assertEqual(syms[0].kind, "func")
        try assertEqual(syms[1].name, "bar")
    }

    test(suite, "swift class and struct") {
        let src = "class Foo {}\nstruct Bar {}"
        let syms = SymbolExtractor.symbols(in: src, language: .swift)
        try assertTrue(syms.contains(where: { $0.name == "Foo" && $0.kind == "class" }))
        try assertTrue(syms.contains(where: { $0.name == "Bar" && $0.kind == "struct" }))
    }

    test(suite, "swift func with access modifier") {
        let src = "public func publicFn() {}\nprivate static func staticFn() {}"
        let syms = SymbolExtractor.symbols(in: src, language: .swift)
        try assertEqual(syms.count, 2)
        try assertEqual(syms[0].name, "publicFn")
        try assertEqual(syms[1].name, "staticFn")
    }

    test(suite, "python def + class") {
        let src = "def foo():\n    pass\n\nclass Bar:\n    pass"
        let syms = SymbolExtractor.symbols(in: src, language: .python)
        try assertEqual(syms.count, 2)
        try assertEqual(syms[0].name, "foo")
        try assertEqual(syms[0].kind, "def")
        try assertEqual(syms[1].name, "Bar")
    }

    test(suite, "javascript function and class") {
        let src = "function foo() {}\nclass Bar {}\nconst baz = () => {}"
        let syms = SymbolExtractor.symbols(in: src, language: .javascript)
        let names = syms.map { $0.name }
        try assertTrue(names.contains("foo"))
        try assertTrue(names.contains("Bar"))
        try assertTrue(names.contains("baz"))
    }

    test(suite, "markdown headings are symbols") {
        let src = "# Top\n\n## Second\n\nText\n\n### Third"
        let syms = SymbolExtractor.symbols(in: src, language: .markdown)
        try assertEqual(syms.count, 3)
        try assertEqual(syms[0].name, "Top")
        try assertEqual(syms[1].name, "Second")
        try assertEqual(syms[2].name, "Third")
    }

    test(suite, "shell function") {
        let src = "function setup() {\n  :\n}\n\nteardown() {\n  :\n}"
        let syms = SymbolExtractor.symbols(in: src, language: .shell)
        let names = syms.map { $0.name }
        try assertTrue(names.contains("setup"))
        try assertTrue(names.contains("teardown"))
    }

    test(suite, "go func with receiver") {
        let src = "func (s *Server) Start() {}\nfunc TopLevel() {}"
        let syms = SymbolExtractor.symbols(in: src, language: .go)
        let names = syms.map { $0.name }
        try assertTrue(names.contains("Start"))
        try assertTrue(names.contains("TopLevel"))
    }

    test(suite, "rust fn and struct") {
        let src = "pub fn run() {}\nstruct Server {}\nimpl Server { fn new() -> Self {} }"
        let syms = SymbolExtractor.symbols(in: src, language: .rust)
        let names = syms.map { $0.name }
        try assertTrue(names.contains("run"))
        try assertTrue(names.contains("Server"))
    }

    test(suite, "symbols carry correct line numbers") {
        let src = "// comment\nclass One {}\n\nclass Two {}"
        let syms = SymbolExtractor.symbols(in: src, language: .swift)
        try assertEqual(syms.count, 2)
        try assertEqual(syms[0].lineNumber, 2)
        try assertEqual(syms[1].lineNumber, 4)
    }

    test(suite, "symbols sorted by line") {
        // Two rules might match the same line; output should still be in line order.
        let src = "class First {}\nfunc second() {}"
        let syms = SymbolExtractor.symbols(in: src, language: .swift)
        try assertEqual(syms[0].lineNumber, 1)
        try assertEqual(syms[1].lineNumber, 2)
    }
}
