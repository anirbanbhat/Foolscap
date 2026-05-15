import Foundation

func registerFindInFilesTests() {
    let suite = "FindInFiles"

    func makeTree() -> URL {
        let dir = Temp.directory()
        let fm = FileManager.default
        try? "alpha beta gamma\nsecond line".write(to: dir.appendingPathComponent("a.txt"), atomically: true, encoding: .utf8)
        try? "BETA only".write(to: dir.appendingPathComponent("b.txt"), atomically: true, encoding: .utf8)
        try? fm.createDirectory(at: dir.appendingPathComponent("sub"), withIntermediateDirectories: true)
        try? "deeply nested beta".write(to: dir.appendingPathComponent("sub/c.txt"), atomically: true, encoding: .utf8)
        // Should be skipped: .git directory
        try? fm.createDirectory(at: dir.appendingPathComponent(".git"), withIntermediateDirectories: true)
        try? "secret beta".write(to: dir.appendingPathComponent(".git/HEAD"), atomically: true, encoding: .utf8)
        // Should be skipped: image extension
        try? "beta inside image".write(to: dir.appendingPathComponent("img.png"), atomically: true, encoding: .utf8)
        // Should be skipped: node_modules
        try? fm.createDirectory(at: dir.appendingPathComponent("node_modules"), withIntermediateDirectories: true)
        try? "module beta".write(to: dir.appendingPathComponent("node_modules/x.js"), atomically: true, encoding: .utf8)
        return dir
    }

    test(suite, "empty query returns no results") {
        let dir = makeTree()
        defer { try? FileManager.default.removeItem(at: dir) }
        let r = FindInFiles.search(query: "", root: dir, caseSensitive: false, regex: false)
        try assertEqual(r.count, 0)
    }

    test(suite, "case-insensitive literal finds all 'beta' (excluding skipped paths)") {
        let dir = makeTree()
        defer { try? FileManager.default.removeItem(at: dir) }
        let r = FindInFiles.search(query: "beta", root: dir, caseSensitive: false, regex: false)
        // Expected hits: a.txt (1), b.txt (1: "BETA"), sub/c.txt (1)
        try assertEqual(r.count, 3)
    }

    test(suite, "case-sensitive does not match BETA when looking for beta") {
        let dir = makeTree()
        defer { try? FileManager.default.removeItem(at: dir) }
        let r = FindInFiles.search(query: "beta", root: dir, caseSensitive: true, regex: false)
        // a.txt + sub/c.txt only
        try assertEqual(r.count, 2)
    }

    test(suite, "regex query") {
        let dir = makeTree()
        defer { try? FileManager.default.removeItem(at: dir) }
        let r = FindInFiles.search(query: "[bB]ETA|beta", root: dir, caseSensitive: true, regex: true)
        try assertTrue(r.count >= 3)
    }

    test(suite, "skips .git directory") {
        let dir = makeTree()
        defer { try? FileManager.default.removeItem(at: dir) }
        let r = FindInFiles.search(query: "secret", root: dir, caseSensitive: false, regex: false)
        try assertEqual(r.count, 0, "Found a hit inside .git, which should have been skipped")
    }

    test(suite, "skips node_modules directory") {
        let dir = makeTree()
        defer { try? FileManager.default.removeItem(at: dir) }
        let r = FindInFiles.search(query: "module beta", root: dir, caseSensitive: false, regex: false)
        try assertEqual(r.count, 0)
    }

    test(suite, "skips files with image extension") {
        let dir = makeTree()
        defer { try? FileManager.default.removeItem(at: dir) }
        let r = FindInFiles.search(query: "beta inside image", root: dir, caseSensitive: false, regex: false)
        try assertEqual(r.count, 0)
    }

    test(suite, "result reports correct line number") {
        let dir = Temp.directory()
        defer { try? FileManager.default.removeItem(at: dir) }
        try? "first\nmatch here\nthird".write(to: dir.appendingPathComponent("x.txt"), atomically: true, encoding: .utf8)
        let r = FindInFiles.search(query: "match", root: dir, caseSensitive: false, regex: false)
        try assertEqual(r.count, 1)
        try assertEqual(r[0].lineNumber, 2)
    }

    test(suite, "result reports correct match range in line") {
        let dir = Temp.directory()
        defer { try? FileManager.default.removeItem(at: dir) }
        try? "prefix-target-suffix".write(to: dir.appendingPathComponent("x.txt"), atomically: true, encoding: .utf8)
        let r = FindInFiles.search(query: "target", root: dir, caseSensitive: false, regex: false)
        try assertEqual(r.count, 1)
        try assertEqual(r[0].matchRangeInLine.location, 7)
        try assertEqual(r[0].matchRangeInLine.length, 6)
    }

    test(suite, "multi-occurrence on same line returns multiple matches") {
        let dir = Temp.directory()
        defer { try? FileManager.default.removeItem(at: dir) }
        try? "foo bar foo bar foo".write(to: dir.appendingPathComponent("x.txt"), atomically: true, encoding: .utf8)
        let r = FindInFiles.search(query: "foo", root: dir, caseSensitive: false, regex: false)
        try assertEqual(r.count, 3)
    }
}
