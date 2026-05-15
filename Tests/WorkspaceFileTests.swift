import Foundation

func registerWorkspaceFileTests() {
    let suite = "WorkspaceFile"

    test(suite, "load reads file contents") {
        let dir = Temp.directory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("hello.txt")
        try? "hello world".write(to: url, atomically: true, encoding: .utf8)
        let file = try WorkspaceFile.load(from: url)
        try assertEqual(file.text, "hello world")
    }

    test(suite, "load detects LF") {
        let dir = Temp.directory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("lf.txt")
        try? "a\nb\nc".write(to: url, atomically: true, encoding: .utf8)
        let file = try WorkspaceFile.load(from: url)
        try assertEqual(file.lineEnding, .lf)
    }

    test(suite, "load detects CRLF and normalizes text to LF in memory") {
        let dir = Temp.directory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("crlf.txt")
        try? "a\r\nb\r\nc".write(to: url, atomically: true, encoding: .utf8)
        let file = try WorkspaceFile.load(from: url)
        try assertEqual(file.lineEnding, .crlf)
        try assertEqual(file.text, "a\nb\nc", "in-memory text should always be LF")
    }

    test(suite, "load detects CR-only and normalizes") {
        let dir = Temp.directory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("cr.txt")
        try? "a\rb\rc".write(to: url, atomically: true, encoding: .utf8)
        let file = try WorkspaceFile.load(from: url)
        try assertEqual(file.lineEnding, .cr)
        try assertEqual(file.text, "a\nb\nc")
    }

    test(suite, "load defaults encoding to utf8 for ASCII content") {
        let dir = Temp.directory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("ascii.txt")
        try? "plain ascii".write(to: url, atomically: true, encoding: .utf8)
        let file = try WorkspaceFile.load(from: url)
        try assertEqual(file.encoding, .utf8)
    }

    test(suite, "load detects language from extension") {
        let dir = Temp.directory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("main.swift")
        try? "import Foundation".write(to: url, atomically: true, encoding: .utf8)
        let file = try WorkspaceFile.load(from: url)
        try assertEqual(file.detectedLanguage, .swift)
    }

    test(suite, "save writes back to disk") {
        let dir = Temp.directory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("rw.txt")
        try? "before".write(to: url, atomically: true, encoding: .utf8)
        let file = try WorkspaceFile.load(from: url)
        file.text = "after"
        try file.save()
        let onDisk = try String(contentsOf: url, encoding: .utf8)
        try assertEqual(onDisk, "after")
    }

    test(suite, "save converts in-memory LF to CRLF when lineEnding is CRLF") {
        let dir = Temp.directory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("eol.txt")
        try? "a\nb".write(to: url, atomically: true, encoding: .utf8)
        let file = try WorkspaceFile.load(from: url)
        file.lineEnding = .crlf
        try file.save()
        let onDisk = try String(contentsOf: url, encoding: .utf8)
        try assertEqual(onDisk, "a\r\nb")
    }

    test(suite, "save preserves CRLF round-trip") {
        let dir = Temp.directory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("crlf-rt.txt")
        try? "x\r\ny\r\nz".write(to: url, atomically: true, encoding: .utf8)
        let file = try WorkspaceFile.load(from: url)
        try file.save()
        let onDisk = try String(contentsOf: url, encoding: .utf8)
        try assertEqual(onDisk, "x\r\ny\r\nz")
    }

    test(suite, "markEdited toggles isEdited") {
        let dir = Temp.directory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("e.txt")
        try? "x".write(to: url, atomically: true, encoding: .utf8)
        let file = try WorkspaceFile.load(from: url)
        try assertFalse(file.isEdited)
        file.markEdited()
        try assertTrue(file.isEdited)
    }

    test(suite, "save clears isEdited") {
        let dir = Temp.directory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("clear.txt")
        try? "x".write(to: url, atomically: true, encoding: .utf8)
        let file = try WorkspaceFile.load(from: url)
        file.markEdited()
        try assertTrue(file.isEdited)
        try file.save()
        try assertFalse(file.isEdited)
    }

    test(suite, "load nonexistent file throws") {
        let url = URL(fileURLWithPath: "/nonexistent/path/\(UUID().uuidString).txt")
        try assertThrows {
            try WorkspaceFile.load(from: url)
        }
    }

    test(suite, "editorTitle returns last path component") {
        let dir = Temp.directory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("foo.bar.txt")
        try? "x".write(to: url, atomically: true, encoding: .utf8)
        let file = try WorkspaceFile.load(from: url)
        try assertEqual(file.editorTitle, "foo.bar.txt")
    }

    test(suite, "fileURL returns the URL it was loaded from") {
        let dir = Temp.directory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("u.txt")
        try? "x".write(to: url, atomically: true, encoding: .utf8)
        let file = try WorkspaceFile.load(from: url)
        try assertEqual(file.fileURL, url)
    }
}
