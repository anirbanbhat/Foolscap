import Foundation

func registerFuzzyMatchTests() {
    let suite = "FuzzyMatch"

    test(suite, "empty query scores everything 0") {
        try assertEqual(FuzzyMatch.score(query: "", in: "anything"), 0)
    }
    test(suite, "exact substring matches") {
        let s = FuzzyMatch.score(query: "foo", in: "foo.swift")
        try assertNotNil(s)
        try assertTrue(s! > 0)
    }
    test(suite, "non-matching subsequence returns nil") {
        try assertNil(FuzzyMatch.score(query: "xyz", in: "alphabet"))
    }
    test(suite, "subsequence still matches") {
        try assertNotNil(FuzzyMatch.score(query: "abc", in: "a-b-c"))
    }
    test(suite, "case insensitive") {
        try assertNotNil(FuzzyMatch.score(query: "FOO", in: "foobar"))
    }
    test(suite, "consecutive match scores higher than scattered") {
        let consecutive = FuzzyMatch.score(query: "abc", in: "abcxyz")!
        let scattered = FuzzyMatch.score(query: "abc", in: "axbxcx")!
        try assertTrue(consecutive > scattered, "consecutive should beat scattered")
    }
    test(suite, "word-boundary match scores higher") {
        let boundary = FuzzyMatch.score(query: "us", in: "user_service.swift")!
        let mid = FuzzyMatch.score(query: "us", in: "yourusernamefile.swift")!
        try assertTrue(boundary > mid)
    }
    test(suite, "query longer than candidate fails") {
        try assertNil(FuzzyMatch.score(query: "aaaaaa", in: "ab"))
    }

    test(suite, "filter sorts by score descending") {
        let items = ["zebra.swift", "alpha.swift", "abc.swift"]
        let r = FuzzyMatch.filter(items, query: "ab") { $0 }
        // "abc.swift" should win (consecutive AB at start)
        try assertEqual(r.first, "abc.swift")
    }
    test(suite, "filter drops non-matches") {
        let items = ["foo.swift", "bar.swift", "baz.swift"]
        let r = FuzzyMatch.filter(items, query: "xyz") { $0 }
        try assertEqual(r.count, 0)
    }
    test(suite, "filter with empty query returns input order") {
        let items = ["foo", "bar"]
        let r = FuzzyMatch.filter(items, query: "") { $0 }
        try assertEqual(r, items)
    }
}
