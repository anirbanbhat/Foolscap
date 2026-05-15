import Foundation

func registerFileTreeNodeTests() {
    let suite = "FileTreeNode"

    test(suite, "empty directory has no children") {
        let dir = Temp.directory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let node = FileTreeNode(url: dir, isDirectory: true)
        try assertEqual(node.children.count, 0)
    }

    test(suite, "file has no children") {
        let dir = Temp.directory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let f = dir.appendingPathComponent("file.txt")
        try? "x".write(to: f, atomically: true, encoding: .utf8)
        let node = FileTreeNode(url: f, isDirectory: false)
        try assertEqual(node.children.count, 0)
    }

    test(suite, "lists files and folders") {
        let dir = Temp.directory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let fm = FileManager.default
        try? "a".write(to: dir.appendingPathComponent("a.txt"), atomically: true, encoding: .utf8)
        try? "b".write(to: dir.appendingPathComponent("b.txt"), atomically: true, encoding: .utf8)
        try? fm.createDirectory(at: dir.appendingPathComponent("sub"), withIntermediateDirectories: true)
        let node = FileTreeNode(url: dir, isDirectory: true)
        try assertEqual(node.children.count, 3)
    }

    test(suite, "directories appear before files") {
        let dir = Temp.directory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let fm = FileManager.default
        try? "x".write(to: dir.appendingPathComponent("aaa.txt"), atomically: true, encoding: .utf8)
        try? fm.createDirectory(at: dir.appendingPathComponent("zzz"), withIntermediateDirectories: true)
        let node = FileTreeNode(url: dir, isDirectory: true)
        try assertEqual(node.children.count, 2)
        try assertTrue(node.children[0].isDirectory, "first child should be the directory")
        try assertFalse(node.children[1].isDirectory, "second child should be the file")
    }

    test(suite, "skips .git directory") {
        let dir = Temp.directory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let fm = FileManager.default
        try? fm.createDirectory(at: dir.appendingPathComponent(".git"), withIntermediateDirectories: true)
        try? "real".write(to: dir.appendingPathComponent("kept.txt"), atomically: true, encoding: .utf8)
        let node = FileTreeNode(url: dir, isDirectory: true)
        try assertEqual(node.children.count, 1)
        try assertEqual(node.children[0].name, "kept.txt")
    }

    test(suite, "skips node_modules") {
        let dir = Temp.directory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let fm = FileManager.default
        try? fm.createDirectory(at: dir.appendingPathComponent("node_modules"), withIntermediateDirectories: true)
        try? "real".write(to: dir.appendingPathComponent("kept.txt"), atomically: true, encoding: .utf8)
        let node = FileTreeNode(url: dir, isDirectory: true)
        try assertEqual(node.children.count, 1)
    }

    test(suite, "name uses lastPathComponent") {
        let dir = Temp.directory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let f = dir.appendingPathComponent("hello.swift")
        try? "x".write(to: f, atomically: true, encoding: .utf8)
        let node = FileTreeNode(url: f, isDirectory: false)
        try assertEqual(node.name, "hello.swift")
    }

    test(suite, "invalidateChildren resets cache") {
        let dir = Temp.directory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let node = FileTreeNode(url: dir, isDirectory: true)
        try assertEqual(node.children.count, 0)
        try? "new".write(to: dir.appendingPathComponent("new.txt"), atomically: true, encoding: .utf8)
        // Without invalidation, cached value would still be 0.
        try assertEqual(node.children.count, 0, "cached")
        node.invalidateChildren()
        try assertEqual(node.children.count, 1, "after invalidate")
    }

    test(suite, "children sort case-insensitively") {
        let dir = Temp.directory()
        defer { try? FileManager.default.removeItem(at: dir) }
        try? "x".write(to: dir.appendingPathComponent("Banana.txt"), atomically: true, encoding: .utf8)
        try? "x".write(to: dir.appendingPathComponent("apple.txt"), atomically: true, encoding: .utf8)
        let node = FileTreeNode(url: dir, isDirectory: true)
        try assertEqual(node.children.count, 2)
        try assertEqual(node.children[0].name, "apple.txt")
        try assertEqual(node.children[1].name, "Banana.txt")
    }
}
