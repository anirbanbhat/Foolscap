import Foundation

func registerThemeRegistryTests() {
    let suite = "ThemeRegistry"

    test(suite, "default exists and is registered") {
        let d = ThemeRegistry.default
        try assertEqual(d.id, "system")
        try assertTrue(ThemeRegistry.all.contains(where: { $0.id == "system" }))
    }

    test(suite, "registry contains expected themes") {
        let ids = ThemeRegistry.all.map { $0.id }
        try assertTrue(ids.contains("system"))
        try assertTrue(ids.contains("solarized-light"))
        try assertTrue(ids.contains("solarized-dark"))
        try assertTrue(ids.contains("one-dark"))
        try assertTrue(ids.contains("monokai"))
    }

    test(suite, "theme(withID:) lookup") {
        try assertEqual(ThemeRegistry.theme(withID: "monokai")?.displayName, "Monokai")
        try assertNil(ThemeRegistry.theme(withID: "nonexistent"))
    }

    test(suite, "every theme has a non-empty display name") {
        for t in ThemeRegistry.all {
            try assertFalse(t.displayName.isEmpty, "theme \(t.id) has empty name")
        }
    }
}
