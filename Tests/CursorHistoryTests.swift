import Foundation

func registerCursorHistoryTests() {
    let suite = "CursorHistory"

    test(suite, "fresh history can't go back or forward") {
        let h = CursorHistory()
        try assertFalse(h.canGoBack)
        try assertFalse(h.canGoForward)
        try assertNil(h.goBack())
        try assertNil(h.goForward())
    }

    test(suite, "two distant recordings allow one back") {
        let h = CursorHistory()
        h.recordCurrent(0)
        h.recordCurrent(1000)
        try assertTrue(h.canGoBack)
        let target = h.goBack()
        try assertEqual(target, 0)
    }

    test(suite, "back, then forward returns to original") {
        let h = CursorHistory()
        h.recordCurrent(0)
        h.recordCurrent(1000)
        _ = h.goBack()
        try assertTrue(h.canGoForward)
        let f = h.goForward()
        try assertEqual(f, 1000)
    }

    test(suite, "nearby recordings are coalesced") {
        let h = CursorHistory()
        h.recordCurrent(0)
        h.recordCurrent(2)
        h.recordCurrent(5)
        // All within groupingDistance (25) so we should see back stack empty.
        try assertFalse(h.canGoBack)
    }

    test(suite, "a new recording invalidates forward") {
        let h = CursorHistory()
        h.recordCurrent(0)
        h.recordCurrent(1000)
        _ = h.goBack()
        try assertTrue(h.canGoForward)
        h.recordCurrent(2000)
        try assertFalse(h.canGoForward)
    }

    test(suite, "back stack respects capacity") {
        let h = CursorHistory()
        for i in 0..<400 {
            h.recordCurrent(i * 100)
        }
        // Internally we keep 200 entries. We can verify by counting goBack calls.
        var count = 0
        while h.goBack() != nil { count += 1 }
        try assertTrue(count <= 200, "back stack should not exceed capacity")
    }
}
