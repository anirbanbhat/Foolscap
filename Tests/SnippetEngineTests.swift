import Foundation

func registerSnippetEngineTests() {
    let suite = "SnippetEngine"

    test(suite, "swift snippets are non-empty") {
        try assertTrue(SnippetEngine.snippets(for: .swift).count > 0)
    }
    test(suite, "plain language has no snippets") {
        try assertEqual(SnippetEngine.snippets(for: .plain).count, 0)
    }
    test(suite, "trigger lookup hits a known snippet") {
        try assertNotNil(SnippetEngine.snippet(trigger: "func", in: .swift))
    }
    test(suite, "trigger lookup misses unknown trigger") {
        try assertNil(SnippetEngine.snippet(trigger: "definitelynotreal", in: .swift))
    }
    test(suite, "expand simple stop with default") {
        let s = Snippet(trigger: "x", body: "hello ${1:name}", description: "")
        let e = SnippetEngine.expand(s)
        try assertEqual(e.text, "hello name")
        try assertNotNil(e.firstStopRange)
        try assertEqual(e.firstStopRange?.location, 6)
        try assertEqual(e.firstStopRange?.length, 4)
    }
    test(suite, "expand empty stop has zero-length first range") {
        let s = Snippet(trigger: "x", body: "x = ${1}", description: "")
        let e = SnippetEngine.expand(s)
        try assertEqual(e.text, "x = ")
        try assertEqual(e.firstStopRange?.location, 4)
        try assertEqual(e.firstStopRange?.length, 0)
    }
    test(suite, "first-stop wins when multiple stops present") {
        let s = Snippet(trigger: "x", body: "a${2:two}b${1:one}c", description: "")
        let e = SnippetEngine.expand(s)
        try assertEqual(e.text, "atwobonec")
        // First stop should be ${1:one} not ${2:two}, so the range points at "one".
        try assertEqual(e.firstStopRange?.location, 5)
        try assertEqual(e.firstStopRange?.length, 3)
    }
    test(suite, "expand without stops returns no range") {
        let s = Snippet(trigger: "x", body: "static text", description: "")
        let e = SnippetEngine.expand(s)
        try assertEqual(e.text, "static text")
        try assertNil(e.firstStopRange)
    }
    test(suite, "newlines in body are preserved") {
        let s = Snippet(trigger: "x", body: "{\n    ${1:body}\n}", description: "")
        let e = SnippetEngine.expand(s)
        try assertEqual(e.text, "{\n    body\n}")
    }
}
