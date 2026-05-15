import Foundation

func registerIndentSettingsTests() {
    let suite = "IndentSettings"

    test(suite, "default uses 4 spaces") {
        let s = IndentSettings.default
        try assertFalse(s.useTabs)
        try assertEqual(s.size, 4)
        try assertEqual(s.tabInsertion, "    ")
    }

    test(suite, "useTabs produces a tab character") {
        var s = IndentSettings.default
        s.useTabs = true
        try assertEqual(s.tabInsertion, "\t")
    }

    test(suite, "non-default indent size") {
        var s = IndentSettings.default
        s.size = 2
        try assertEqual(s.tabInsertion, "  ")
    }

    test(suite, "zero or negative size falls back to 1 space") {
        var s = IndentSettings.default
        s.size = 0
        try assertEqual(s.tabInsertion, " ")
    }

    test(suite, "equality works") {
        let a = IndentSettings(useTabs: true, size: 2, trimTrailingWhitespaceOnSave: false, insertFinalNewlineOnSave: true)
        let b = IndentSettings(useTabs: true, size: 2, trimTrailingWhitespaceOnSave: false, insertFinalNewlineOnSave: true)
        try assertEqual(a, b)
    }
}
