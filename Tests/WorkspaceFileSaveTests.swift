import Foundation

func registerWorkspaceFileSaveTests() {
    let suite = "WorkspaceFile/EditorConfig"

    test(suite, "trim trailing whitespace on save") {
        let dir = Temp.directory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("trim.txt")
        try? "alpha   \nbeta\t\n".write(to: url, atomically: true, encoding: .utf8)
        let file = try WorkspaceFile.load(from: url)
        file.indentSettings.trimTrailingWhitespaceOnSave = true
        try file.save()
        let onDisk = try String(contentsOf: url, encoding: .utf8)
        try assertEqual(onDisk, "alpha\nbeta\n")
    }

    test(suite, "insert final newline on save when missing") {
        let dir = Temp.directory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("noeol.txt")
        try? "no trailing newline".write(to: url, atomically: true, encoding: .utf8)
        let file = try WorkspaceFile.load(from: url)
        file.indentSettings.insertFinalNewlineOnSave = true
        try file.save()
        let onDisk = try String(contentsOf: url, encoding: .utf8)
        try assertEqual(onDisk, "no trailing newline\n")
    }

    test(suite, "insert final newline does not double up when one is already present") {
        let dir = Temp.directory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("eol.txt")
        try? "line\n".write(to: url, atomically: true, encoding: .utf8)
        let file = try WorkspaceFile.load(from: url)
        file.indentSettings.insertFinalNewlineOnSave = true
        try file.save()
        let onDisk = try String(contentsOf: url, encoding: .utf8)
        try assertEqual(onDisk, "line\n")
    }

    test(suite, "applyEditorConfig sets indentStyle/size") {
        let dir = Temp.directory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("x.swift")
        try? "x".write(to: url, atomically: true, encoding: .utf8)
        let file = try WorkspaceFile.load(from: url)
        let cfg = EditorConfigSettings(
            indentStyle: "tab", indentSize: 8, tabWidth: nil,
            endOfLine: nil, charset: nil,
            trimTrailingWhitespace: nil, insertFinalNewline: nil
        )
        file.applyEditorConfig(cfg)
        try assertTrue(file.indentSettings.useTabs)
        try assertEqual(file.indentSettings.size, 8)
    }

    test(suite, "applyEditorConfig respects end_of_line") {
        let dir = Temp.directory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let url = dir.appendingPathComponent("x.txt")
        try? "x".write(to: url, atomically: true, encoding: .utf8)
        let file = try WorkspaceFile.load(from: url)
        var cfg = EditorConfigSettings()
        cfg.endOfLine = "crlf"
        file.applyEditorConfig(cfg)
        try assertEqual(file.lineEnding, .crlf)
    }
}
