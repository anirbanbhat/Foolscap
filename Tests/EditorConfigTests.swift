import Foundation

func registerEditorConfigTests() {
    let suite = "EditorConfig/parse"

    test(suite, "empty input parses to nothing") {
        let p = EditorConfigLoader.parse("")
        try assertFalse(p.root)
        try assertEqual(p.sections.count, 0)
    }

    test(suite, "root = true marks file as terminator") {
        let p = EditorConfigLoader.parse("root = true\n")
        try assertTrue(p.root)
    }

    test(suite, "simple section with one rule") {
        let p = EditorConfigLoader.parse("[*]\nindent_style = space\nindent_size = 2\n")
        try assertEqual(p.sections.count, 1)
        try assertEqual(p.sections[0].pattern, "*")
        try assertEqual(p.sections[0].settings["indent_style"], "space")
        try assertEqual(p.sections[0].settings["indent_size"], "2")
    }

    test(suite, "multiple sections") {
        let cfg = "[*.swift]\nindent_size = 4\n\n[*.py]\nindent_size = 2"
        let p = EditorConfigLoader.parse(cfg)
        try assertEqual(p.sections.count, 2)
        try assertEqual(p.sections[0].pattern, "*.swift")
        try assertEqual(p.sections[1].pattern, "*.py")
    }

    test(suite, "comment lines are ignored") {
        let cfg = "[*]\n# this is a comment\n; this too\nindent_size = 4"
        let p = EditorConfigLoader.parse(cfg)
        try assertEqual(p.sections[0].settings["indent_size"], "4")
    }

    test(suite, "keys are normalized to lowercase") {
        let p = EditorConfigLoader.parse("[*]\nINDENT_STYLE = space")
        try assertEqual(p.sections[0].settings["indent_style"], "space")
    }

    test(suite, "blank lines tolerated") {
        let p = EditorConfigLoader.parse("\n\n[*]\n\nindent_size = 4\n\n")
        try assertEqual(p.sections[0].settings["indent_size"], "4")
    }

    let g = "EditorConfig/glob"

    test(g, "* matches single file") {
        try assertTrue(Glob.matches(pattern: "*.swift", path: "foo.swift"))
    }
    test(g, "* does not match across path separator") {
        try assertFalse(Glob.matches(pattern: "*.swift", path: "dir/foo.swift"))
    }
    test(g, "** matches across path separator") {
        try assertTrue(Glob.matches(pattern: "**/*.swift", path: "a/b/c.swift"))
    }
    test(g, "{a,b} alternation matches either") {
        try assertTrue(Glob.matches(pattern: "*.{swift,py}", path: "x.swift"))
        try assertTrue(Glob.matches(pattern: "*.{swift,py}", path: "x.py"))
        try assertFalse(Glob.matches(pattern: "*.{swift,py}", path: "x.go"))
    }
    test(g, "? matches single char") {
        try assertTrue(Glob.matches(pattern: "f?o.swift", path: "foo.swift"))
        try assertFalse(Glob.matches(pattern: "f?o.swift", path: "fooo.swift"))
    }
    test(g, "character class matches one of") {
        try assertTrue(Glob.matches(pattern: "[abc].txt", path: "a.txt"))
        try assertFalse(Glob.matches(pattern: "[abc].txt", path: "d.txt"))
    }
    test(g, "negated character class") {
        try assertTrue(Glob.matches(pattern: "[!abc].txt", path: "d.txt"))
        try assertFalse(Glob.matches(pattern: "[!abc].txt", path: "a.txt"))
    }
    test(g, "anchored on both sides") {
        try assertFalse(Glob.matches(pattern: "*.swift", path: "foo.swift.bak"))
    }

    let r = "EditorConfig/resolve"

    test(r, "resolves indent_size from .editorconfig next to file") {
        let dir = Temp.directory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let cfg = "root = true\n[*.swift]\nindent_style = space\nindent_size = 2\nend_of_line = lf\n"
        try? cfg.write(to: dir.appendingPathComponent(".editorconfig"), atomically: true, encoding: .utf8)
        let target = dir.appendingPathComponent("file.swift")
        try? "x".write(to: target, atomically: true, encoding: .utf8)
        let settings = EditorConfigLoader.resolve(for: target)
        try assertEqual(settings.indentStyle, "space")
        try assertEqual(settings.indentSize, 2)
        try assertEqual(settings.endOfLine, "lf")
    }

    test(r, "resolves nothing when no .editorconfig present") {
        let dir = Temp.directory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let target = dir.appendingPathComponent("file.swift")
        try? "x".write(to: target, atomically: true, encoding: .utf8)
        let settings = EditorConfigLoader.resolve(for: target)
        try assertNil(settings.indentStyle)
        try assertNil(settings.indentSize)
    }

    test(r, "non-matching glob is ignored") {
        let dir = Temp.directory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let cfg = "root = true\n[*.py]\nindent_size = 2\n"
        try? cfg.write(to: dir.appendingPathComponent(".editorconfig"), atomically: true, encoding: .utf8)
        let target = dir.appendingPathComponent("file.swift")
        try? "x".write(to: target, atomically: true, encoding: .utf8)
        let settings = EditorConfigLoader.resolve(for: target)
        try assertNil(settings.indentSize)
    }
}
