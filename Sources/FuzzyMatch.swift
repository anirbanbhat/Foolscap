import Foundation

/// Cheap subsequence fuzzy matcher. Returns nil when the query doesn't
/// fit as a subsequence of the candidate; otherwise an integer score where
/// higher is better. Scoring rewards consecutive matches and matches that
/// fall on word boundaries.
enum FuzzyMatch {

    private static let boundarySeparators: Set<Character> = [" ", "/", "\\", "-", "_", ".", ":"]

    static func score(query: String, in candidate: String) -> Int? {
        if query.isEmpty { return 0 }
        let q = Array(query.lowercased())
        let c = Array(candidate.lowercased())
        if q.count > c.count { return nil }

        var qi = 0
        var score = 0
        var lastMatchedIdx = -2
        var matched = 0

        for (idx, ch) in c.enumerated() {
            guard qi < q.count else { break }
            if ch == q[qi] {
                if lastMatchedIdx + 1 == idx {
                    score += 8                      // consecutive bonus
                }
                if idx == 0 || boundarySeparators.contains(c[idx - 1]) {
                    score += 14                     // word-boundary bonus
                }
                lastMatchedIdx = idx
                matched += 1
                qi += 1
            }
        }
        if qi < q.count { return nil }
        score += matched * 3
        score -= candidate.count / 8                // gentle penalty for very long strings
        return score
    }

    /// Filter and sort items by score against the query. Items with no match
    /// are dropped; ties broken alphabetically by `key`.
    static func filter<T>(_ items: [T], query: String, key: (T) -> String) -> [T] {
        if query.isEmpty { return items }
        var scored: [(item: T, score: Int, k: String)] = []
        scored.reserveCapacity(items.count)
        for item in items {
            let k = key(item)
            if let s = score(query: query, in: k) {
                scored.append((item, s, k))
            }
        }
        scored.sort { a, b in
            if a.score != b.score { return a.score > b.score }
            return a.k.localizedStandardCompare(b.k) == .orderedAscending
        }
        return scored.map { $0.item }
    }
}
