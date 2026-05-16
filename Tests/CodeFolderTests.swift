import Foundation

func registerCodeFolderTests() {
    let suite = "CodeFolder"

    test(suite, "plain text has no folds") {
        let folds = CodeFolder.detectFolds(in: "just\nsome\ntext\n", language: .plain)
        try assertEqual(folds.count, 0)
    }

    test(suite, "single brace block in Swift") {
        let src = "func foo() {\n    return 1\n}\n"
        let folds = CodeFolder.detectFolds(in: src, language: .swift)
        try assertEqual(folds.count, 1)
        try assertEqual(folds[0].headLine, 1)
        try assertEqual(folds[0].endLine, 3)
    }

    test(suite, "two parallel brace blocks") {
        let src = "fn a() {\n  x\n}\n\nfn b() {\n  y\n}\n"
        let folds = CodeFolder.detectFolds(in: src, language: .rust)
        try assertEqual(folds.count, 2)
    }

    test(suite, "nested brace blocks") {
        let src = "class C {\n    fn foo() {\n        x\n    }\n}\n"
        let folds = CodeFolder.detectFolds(in: src, language: .rust)
        // Two folds: inner foo and outer class
        try assertEqual(folds.count, 2)
    }

    test(suite, "braces inside line comment are ignored") {
        let src = "fn a() {\n    // dummy { not a brace\n    return\n}\n"
        let folds = CodeFolder.detectFolds(in: src, language: .swift)
        try assertEqual(folds.count, 1)
    }

    test(suite, "braces inside string are ignored") {
        let src = "let s = \"{not a brace}\"\nfn b() {\n    return\n}\n"
        let folds = CodeFolder.detectFolds(in: src, language: .swift)
        try assertEqual(folds.count, 1)
    }

    test(suite, "python indent fold around def") {
        let src = "def foo():\n    a = 1\n    b = 2\n\ndef bar():\n    c = 3\n"
        let folds = CodeFolder.detectFolds(in: src, language: .python)
        try assertEqual(folds.count, 2)
    }

    test(suite, "yaml indent fold") {
        let src = "root:\n  child:\n    grand\n  sibling: 1\n"
        let folds = CodeFolder.detectFolds(in: src, language: .yaml)
        try assertTrue(folds.count >= 1)
    }

    test(suite, "markdown heading folds") {
        let src = "# Top\nfoo\n## Sub\nbar\n## Sub2\nbaz\n"
        let folds = CodeFolder.detectFolds(in: src, language: .markdown)
        // Top contains both subs; each sub is also a fold.
        try assertTrue(folds.count >= 2)
    }

    test(suite, "brace fold hidden range covers between {…}") {
        let src = "fn a() {\n  x\n}\n"
        let folds = CodeFolder.detectFolds(in: src, language: .rust)
        try assertEqual(folds.count, 1)
        let f = folds[0]
        // The hidden range starts right after the opening { (offset 8: "fn a() {").
        try assertEqual(f.hiddenRange.location, 8)
    }
}
