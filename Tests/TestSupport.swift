import Foundation

// Lightweight test framework — we don't have full Xcode (only Command Line
// Tools), so no XCTest. Tests register themselves into a global list and the
// runner walks it, catches assertion errors, and prints a summary.

struct TestFailure: Error {
    let message: String
}

enum TestRegistry {
    static var tests: [(suite: String, name: String, run: () throws -> Void)] = []
}

func test(_ suite: String, _ name: String, _ block: @escaping () throws -> Void) {
    TestRegistry.tests.append((suite, name, block))
}

func assertEqual<T: Equatable>(_ actual: T, _ expected: T, _ message: String = "", file: StaticString = #file, line: UInt = #line) throws {
    if actual != expected {
        throw TestFailure(message: "\(file):\(line): expected \"\(expected)\", got \"\(actual)\" \(message)")
    }
}

func assertTrue(_ condition: Bool, _ message: String = "", file: StaticString = #file, line: UInt = #line) throws {
    if !condition {
        throw TestFailure(message: "\(file):\(line): expected true — \(message)")
    }
}

func assertFalse(_ condition: Bool, _ message: String = "", file: StaticString = #file, line: UInt = #line) throws {
    if condition {
        throw TestFailure(message: "\(file):\(line): expected false — \(message)")
    }
}

func assertContains(_ haystack: String, _ needle: String, file: StaticString = #file, line: UInt = #line) throws {
    if !haystack.contains(needle) {
        throw TestFailure(message: "\(file):\(line): expected to contain \"\(needle)\" in \"\(haystack)\"")
    }
}

func assertNotContains(_ haystack: String, _ needle: String, file: StaticString = #file, line: UInt = #line) throws {
    if haystack.contains(needle) {
        throw TestFailure(message: "\(file):\(line): unexpectedly contained \"\(needle)\" in \"\(haystack)\"")
    }
}

func assertNotNil<T>(_ value: T?, _ message: String = "", file: StaticString = #file, line: UInt = #line) throws {
    if value == nil {
        throw TestFailure(message: "\(file):\(line): expected non-nil — \(message)")
    }
}

func assertNil<T>(_ value: T?, _ message: String = "", file: StaticString = #file, line: UInt = #line) throws {
    if value != nil {
        throw TestFailure(message: "\(file):\(line): expected nil — \(message)")
    }
}

func assertThrows<T>(_ block: () throws -> T, file: StaticString = #file, line: UInt = #line) throws {
    do {
        _ = try block()
        throw TestFailure(message: "\(file):\(line): expected throw, got success")
    } catch is TestFailure {
        // Re-raise — that's our own failure.
        throw TestFailure(message: "\(file):\(line): expected throw, got success")
    } catch {
        // Expected.
    }
}

// MARK: Temp filesystem helpers

enum Temp {
    static func directory() -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("foolscap-tests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func writing(_ contents: String, named name: String = "file.txt", encoding: String.Encoding = .utf8) -> URL {
        let dir = directory()
        let f = dir.appendingPathComponent(name)
        try? contents.data(using: encoding)?.write(to: f)
        return f
    }
}
