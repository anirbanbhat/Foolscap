import Foundation

func registerDiffEngineTests() {
    let suite = "DiffEngine"

    test(suite, "identical inputs produce all-equal ops") {
        let ops = DiffEngine.diff(["a", "b", "c"], ["a", "b", "c"])
        try assertEqual(ops.count, 3)
        for op in ops {
            if case .equal = op {} else { try assertTrue(false, "expected equal") }
        }
    }

    test(suite, "empty left → all additions") {
        let ops = DiffEngine.diff([], ["x", "y"])
        try assertEqual(ops.count, 2)
        for op in ops {
            if case .added = op {} else { try assertTrue(false) }
        }
    }

    test(suite, "empty right → all removals") {
        let ops = DiffEngine.diff(["x", "y"], [])
        try assertEqual(ops.count, 2)
        for op in ops {
            if case .removed = op {} else { try assertTrue(false) }
        }
    }

    test(suite, "one removal in the middle") {
        let ops = DiffEngine.diff(["a", "b", "c"], ["a", "c"])
        // Expect: equal a, removed b, equal c
        try assertEqual(ops.count, 3)
        if case .removed(let line) = ops[1] {
            try assertEqual(line, 2)
        } else {
            try assertTrue(false, "expected removed at index 1")
        }
    }

    test(suite, "one addition in the middle") {
        let ops = DiffEngine.diff(["a", "c"], ["a", "b", "c"])
        try assertEqual(ops.count, 3)
        if case .added(let line) = ops[1] {
            try assertEqual(line, 2)
        } else {
            try assertTrue(false, "expected added at index 1")
        }
    }

    test(suite, "rows decompose into side-by-side display") {
        let rows = DiffEngine.rows(left: ["a", "b", "c"], right: ["a", "c"])
        try assertEqual(rows.count, 3)
        try assertEqual(rows[0].kind, .unchanged)
        try assertEqual(rows[1].kind, .removed)
        try assertEqual(rows[2].kind, .unchanged)
    }

    test(suite, "rows handle replacement (remove + add)") {
        let rows = DiffEngine.rows(left: ["a", "b", "c"], right: ["a", "X", "c"])
        // b is removed, X is added — two rows for the middle position.
        try assertEqual(rows.count, 4)
        try assertEqual(rows[0].kind, .unchanged)
        try assertEqual(rows[3].kind, .unchanged)
    }

    test(suite, "lines splits on newline") {
        let parts = DiffEngine.lines("a\nb\nc")
        try assertEqual(parts, ["a", "b", "c"])
    }
}
