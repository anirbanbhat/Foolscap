import Foundation

func registerFileIndexTests() {
    let suite = "FileIndex"

    test(suite, "empty directory returns empty index") {
        let dir = Temp.directory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let entries = FileIndex.walk(root: dir)
        try assertEqual(entries.count, 0)
    }

    test(suite, "lists text files in flat directory") {
        let dir = Temp.directory()
        defer { try? FileManager.default.removeItem(at: dir) }
        try? "a".write(to: dir.appendingPathComponent("a.txt"), atomically: true, encoding: .utf8)
        try? "b".write(to: dir.appendingPathComponent("b.swift"), atomically: true, encoding: .utf8)
        let entries = FileIndex.walk(root: dir)
        try assertEqual(entries.count, 2)
    }

    test(suite, "skips binary extensions") {
        let dir = Temp.directory()
        defer { try? FileManager.default.removeItem(at: dir) }
        try? "x".write(to: dir.appendingPathComponent("a.png"), atomically: true, encoding: .utf8)
        try? "y".write(to: dir.appendingPathComponent("b.swift"), atomically: true, encoding: .utf8)
        let entries = FileIndex.walk(root: dir)
        try assertEqual(entries.count, 1)
        try assertEqual(entries[0].relativePath, "b.swift")
    }

    test(suite, "recurses into subdirectories") {
        let dir = Temp.directory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let sub = dir.appendingPathComponent("sub")
        try? FileManager.default.createDirectory(at: sub, withIntermediateDirectories: true)
        try? "a".write(to: dir.appendingPathComponent("top.txt"), atomically: true, encoding: .utf8)
        try? "b".write(to: sub.appendingPathComponent("nested.txt"), atomically: true, encoding: .utf8)
        let entries = FileIndex.walk(root: dir)
        try assertEqual(entries.count, 2)
        try assertTrue(entries.contains(where: { $0.relativePath == "top.txt" }))
        try assertTrue(entries.contains(where: { $0.relativePath == "sub/nested.txt" }))
    }

    test(suite, "skips .git directory") {
        let dir = Temp.directory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let git = dir.appendingPathComponent(".git")
        try? FileManager.default.createDirectory(at: git, withIntermediateDirectories: true)
        try? "x".write(to: git.appendingPathComponent("HEAD"), atomically: true, encoding: .utf8)
        try? "y".write(to: dir.appendingPathComponent("real.swift"), atomically: true, encoding: .utf8)
        let entries = FileIndex.walk(root: dir)
        try assertEqual(entries.count, 1)
        try assertEqual(entries[0].relativePath, "real.swift")
    }

    test(suite, "skips node_modules") {
        let dir = Temp.directory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let nm = dir.appendingPathComponent("node_modules")
        try? FileManager.default.createDirectory(at: nm, withIntermediateDirectories: true)
        try? "x".write(to: nm.appendingPathComponent("dep.js"), atomically: true, encoding: .utf8)
        try? "y".write(to: dir.appendingPathComponent("app.js"), atomically: true, encoding: .utf8)
        let entries = FileIndex.walk(root: dir)
        try assertEqual(entries.count, 1)
    }

    test(suite, "results are sorted by relative path") {
        let dir = Temp.directory()
        defer { try? FileManager.default.removeItem(at: dir) }
        try? "x".write(to: dir.appendingPathComponent("z.swift"), atomically: true, encoding: .utf8)
        try? "y".write(to: dir.appendingPathComponent("a.swift"), atomically: true, encoding: .utf8)
        try? "z".write(to: dir.appendingPathComponent("m.swift"), atomically: true, encoding: .utf8)
        let entries = FileIndex.walk(root: dir)
        try assertEqual(entries.map { $0.relativePath }, ["a.swift", "m.swift", "z.swift"])
    }
}
