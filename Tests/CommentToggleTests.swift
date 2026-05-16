import Foundation

func registerCommentToggleTests() {
    let suite = "CommentToggle"

    test(suite, "lineToken Swift is //") {
        try assertEqual(CommentToggle.lineToken(for: .swift), "//")
    }
    test(suite, "lineToken Python is #") {
        try assertEqual(CommentToggle.lineToken(for: .python), "#")
    }
    test(suite, "lineToken Java is //") {
        try assertEqual(CommentToggle.lineToken(for: .java), "//")
    }
    test(suite, "lineToken JSON is nil") {
        try assertNil(CommentToggle.lineToken(for: .json))
    }
    test(suite, "lineToken Plain is nil") {
        try assertNil(CommentToggle.lineToken(for: .plain))
    }
    test(suite, "canToggleLineComment for swift is true") {
        try assertTrue(CommentToggle.canToggleLineComment(in: .swift))
    }
    test(suite, "canToggleLineComment for plain is false") {
        try assertFalse(CommentToggle.canToggleLineComment(in: .plain))
    }

    test(suite, "comment single line") {
        let r = CommentToggle.toggle(lineBlock: "let x = 1\n", token: "//")
        try assertEqual(r?.replacement, "// let x = 1\n")
    }
    test(suite, "uncomment single line") {
        let r = CommentToggle.toggle(lineBlock: "// let x = 1\n", token: "//")
        try assertEqual(r?.replacement, "let x = 1\n")
    }
    test(suite, "comment multiple lines uses common indent") {
        let block = "    let a = 1\n    let b = 2\n"
        let r = CommentToggle.toggle(lineBlock: block, token: "//")
        try assertEqual(r?.replacement, "    // let a = 1\n    // let b = 2\n")
    }
    test(suite, "uncomment multiple lines") {
        let block = "    // a\n    // b\n"
        let r = CommentToggle.toggle(lineBlock: block, token: "//")
        try assertEqual(r?.replacement, "    a\n    b\n")
    }
    test(suite, "comment ignores blank lines") {
        let block = "let a = 1\n\nlet b = 2\n"
        let r = CommentToggle.toggle(lineBlock: block, token: "//")
        try assertEqual(r?.replacement, "// let a = 1\n\n// let b = 2\n")
    }
    test(suite, "all whitespace block returns nil") {
        let r = CommentToggle.toggle(lineBlock: "   \n\n", token: "//")
        try assertNil(r)
    }
    test(suite, "empty input returns nil") {
        let r = CommentToggle.toggle(lineBlock: "", token: "//")
        try assertNil(r)
    }
    test(suite, "mixed commented and not commented → comment all (the new state)") {
        // Two lines, one already has //, one doesn't.
        // Our rule: if NOT all are commented, we comment all.
        let block = "// already\nnot yet\n"
        let r = CommentToggle.toggle(lineBlock: block, token: "//")
        try assertEqual(r?.replacement, "// // already\n// not yet\n")
    }
    test(suite, "uncomment respects marker with or without trailing space") {
        let block = "//a\n// b\n"
        let r = CommentToggle.toggle(lineBlock: block, token: "//")
        try assertEqual(r?.replacement, "a\nb\n")
    }
    test(suite, "Python # works") {
        let r = CommentToggle.toggle(lineBlock: "x = 1\n", token: "#")
        try assertEqual(r?.replacement, "# x = 1\n")
    }
    test(suite, "Last line without trailing newline") {
        let r = CommentToggle.toggle(lineBlock: "let x = 1", token: "//")
        try assertEqual(r?.replacement, "// let x = 1")
    }
}
