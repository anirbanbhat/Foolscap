import Foundation

func registerDocumentTests() {
    let suite = "Document/LineEnding"

    // detectLineEnding
    test(suite, "detect LF") {
        try assertEqual(Document.detectLineEnding(in: "a\nb\nc"), .lf)
    }
    test(suite, "detect CRLF") {
        try assertEqual(Document.detectLineEnding(in: "a\r\nb\r\nc"), .crlf)
    }
    test(suite, "detect CR alone") {
        try assertEqual(Document.detectLineEnding(in: "a\rb\rc"), .cr)
    }
    test(suite, "detect mixed prefers CRLF when present") {
        try assertEqual(Document.detectLineEnding(in: "a\r\nb\nc"), .crlf)
    }
    test(suite, "detect empty string defaults to LF") {
        try assertEqual(Document.detectLineEnding(in: ""), .lf)
    }
    test(suite, "detect no line endings defaults to LF") {
        try assertEqual(Document.detectLineEnding(in: "single line"), .lf)
    }

    // normalizeLineEndings
    test(suite, "normalize CRLF→LF") {
        try assertEqual(Document.normalizeLineEndings("a\r\nb", to: .lf), "a\nb")
    }
    test(suite, "normalize CR→LF") {
        try assertEqual(Document.normalizeLineEndings("a\rb", to: .lf), "a\nb")
    }
    test(suite, "normalize LF→CRLF") {
        try assertEqual(Document.normalizeLineEndings("a\nb", to: .crlf), "a\r\nb")
    }
    test(suite, "normalize LF→CR") {
        try assertEqual(Document.normalizeLineEndings("a\nb", to: .cr), "a\rb")
    }
    test(suite, "normalize mixed input → LF") {
        try assertEqual(Document.normalizeLineEndings("a\r\nb\rc\nd", to: .lf), "a\nb\nc\nd")
    }
    test(suite, "normalize mixed input → CRLF") {
        try assertEqual(Document.normalizeLineEndings("a\r\nb\rc\nd", to: .crlf), "a\r\nb\r\nc\r\nd")
    }
    test(suite, "normalize empty string") {
        try assertEqual(Document.normalizeLineEndings("", to: .crlf), "")
    }
    test(suite, "normalize no-newline string stays unchanged") {
        try assertEqual(Document.normalizeLineEndings("abc", to: .crlf), "abc")
    }

    // LineEnding enum
    let eolSuite = "LineEnding"
    test(eolSuite, "LF display name") {
        try assertEqual(LineEnding.lf.displayName, "LF")
    }
    test(eolSuite, "CRLF display name") {
        try assertEqual(LineEnding.crlf.displayName, "CRLF")
    }
    test(eolSuite, "CR display name") {
        try assertEqual(LineEnding.cr.displayName, "CR")
    }
    test(eolSuite, "LF string") {
        try assertEqual(LineEnding.lf.string, "\n")
    }
    test(eolSuite, "CRLF string") {
        try assertEqual(LineEnding.crlf.string, "\r\n")
    }
    test(eolSuite, "CR string") {
        try assertEqual(LineEnding.cr.string, "\r")
    }
    test(eolSuite, "allCases covers LF/CRLF/CR") {
        try assertEqual(Set(LineEnding.allCases), Set([.lf, .crlf, .cr]))
    }

    // Encoding extension
    let encSuite = "String.Encoding"
    test(encSuite, "utf8 display name") {
        try assertEqual(String.Encoding.utf8.displayName, "UTF-8")
    }
    test(encSuite, "utf16 display name") {
        try assertEqual(String.Encoding.utf16.displayName, "UTF-16")
    }
    test(encSuite, "isoLatin1 display name") {
        try assertEqual(String.Encoding.isoLatin1.displayName, "ISO Latin 1")
    }
    test(encSuite, "allSupported includes utf8") {
        try assertTrue(String.Encoding.allSupported.contains(.utf8))
    }
    test(encSuite, "allSupported includes all common encodings") {
        let s = Set(String.Encoding.allSupported)
        try assertTrue(s.contains(.utf8))
        try assertTrue(s.contains(.utf16))
        try assertTrue(s.contains(.isoLatin1))
        try assertTrue(s.contains(.windowsCP1252))
        try assertTrue(s.contains(.macOSRoman))
        try assertTrue(s.contains(.ascii))
    }
}
