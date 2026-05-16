import Foundation

/// Line-level diff using the longest-common-subsequence (LCS) approach.
/// O(N×M) time and space — fine for files up to a few thousand lines, which
/// is the sweet spot for a UI-driven diff viewer.
enum DiffEngine {

    enum Op: Equatable {
        case equal(left: Int, right: Int)   // line in left, line in right (1-based)
        case removed(left: Int)
        case added(right: Int)
    }

    /// Returns a sequence of diff ops describing how to transform `left` into
    /// `right`. Both arrays are zero-indexed; the `left`/`right` fields in
    /// each op are 1-based to match how line numbers are usually shown.
    static func diff(_ left: [String], _ right: [String]) -> [Op] {
        let n = left.count
        let m = right.count

        // Build LCS length matrix.
        var lcs = Array(repeating: Array(repeating: 0, count: m + 1), count: n + 1)
        for i in 0..<n {
            for j in 0..<m {
                if left[i] == right[j] {
                    lcs[i + 1][j + 1] = lcs[i][j] + 1
                } else {
                    lcs[i + 1][j + 1] = max(lcs[i + 1][j], lcs[i][j + 1])
                }
            }
        }

        // Walk backwards to produce ops.
        var ops: [Op] = []
        var i = n
        var j = m
        while i > 0 && j > 0 {
            if left[i - 1] == right[j - 1] {
                ops.append(.equal(left: i, right: j))
                i -= 1; j -= 1
            } else if lcs[i - 1][j] >= lcs[i][j - 1] {
                ops.append(.removed(left: i))
                i -= 1
            } else {
                ops.append(.added(right: j))
                j -= 1
            }
        }
        while i > 0 { ops.append(.removed(left: i)); i -= 1 }
        while j > 0 { ops.append(.added(right: j)); j -= 1 }

        return ops.reversed()
    }

    /// Compact summary used by the UI: one row per "aligned" position.
    struct Row: Equatable {
        let leftLine: Int?
        let rightLine: Int?
        let kind: Kind

        enum Kind: Equatable {
            case unchanged
            case removed
            case added
        }
    }

    /// Convert raw ops into a list of side-by-side rows. Equal lines map to
    /// (leftLine, rightLine), removals to (leftLine, nil), additions to
    /// (nil, rightLine).
    static func rows(left: [String], right: [String]) -> [Row] {
        let ops = diff(left, right)
        return ops.map { op in
            switch op {
            case .equal(let l, let r): return Row(leftLine: l, rightLine: r, kind: .unchanged)
            case .removed(let l):      return Row(leftLine: l, rightLine: nil, kind: .removed)
            case .added(let r):        return Row(leftLine: nil, rightLine: r, kind: .added)
            }
        }
    }

    /// Convenience: split a text blob into lines (no trailing-newline trick).
    static func lines(_ text: String) -> [String] {
        return text.components(separatedBy: "\n")
    }
}
