import Foundation

// Register all test suites. Each file's register*Tests() call appends to TestRegistry.
registerStringConversionsTests()
registerSyntaxHighlighterTests()
registerMarkdownRendererTests()
registerFindInFilesTests()
registerFileTreeNodeTests()
registerDocumentTests()
registerWorkspaceFileTests()
registerFuzzyMatchTests()
registerEditorConfigTests()
registerSymbolExtractorTests()
registerFileIndexTests()
registerIndentSettingsTests()
registerWorkspaceFileSaveTests()

// Run.
var passed = 0
var failed = 0
var failures: [(String, String, String)] = []   // suite, test, message

let start = Date()
var lastSuite = ""
for (suite, name, block) in TestRegistry.tests {
    if suite != lastSuite {
        FileHandle.standardOutput.write(Data("\n[\(suite)]\n".utf8))
        lastSuite = suite
    }
    // Print test name BEFORE running so a crash points at the offending test.
    FileHandle.standardOutput.write(Data("  → \(name)\n".utf8))
    do {
        try block()
        passed += 1
        FileHandle.standardOutput.write(Data("  ✓ \(name)\n".utf8))
    } catch let f as TestFailure {
        failed += 1
        failures.append((suite, name, f.message))
        FileHandle.standardOutput.write(Data("  ✗ \(name)\n    \(f.message)\n".utf8))
    } catch {
        failed += 1
        failures.append((suite, name, "unexpected error: \(error)"))
        FileHandle.standardOutput.write(Data("  ✗ \(name)\n    unexpected error: \(error)\n".utf8))
    }
}
let elapsed = Date().timeIntervalSince(start)

let summary = "\n\(passed) passed, \(failed) failed in \(String(format: "%.2f", elapsed))s\n"
FileHandle.standardOutput.write(Data(summary.utf8))

exit(failed == 0 ? 0 : 1)
