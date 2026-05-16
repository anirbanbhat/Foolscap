import AppKit

/// Colour palette consumed by the syntax highlighter and the editor chrome.
/// Themes are registered in `ThemeRegistry`; the active theme is read from
/// `ThemeRegistry.current` and survives across launches via UserDefaults.
struct Theme: Equatable {
    let id: String
    let displayName: String

    let background: NSColor
    let text: NSColor
    let keyword: NSColor
    let string: NSColor
    let number: NSColor
    let comment: NSColor
    let typeName: NSColor
    let decorator: NSColor
    let punctuation: NSColor
    let heading: NSColor
    let tag: NSColor
    let attr: NSColor
}

enum ThemeRegistry {

    private static let defaultsKey = "foolscap.theme.id"

    static let `default` = Theme(
        id: "system",
        displayName: "System Default",
        background: .textBackgroundColor,
        text: .textColor,
        keyword: .systemPink,
        string: .systemRed,
        number: .systemOrange,
        comment: .systemGreen,
        typeName: .systemTeal,
        decorator: .systemPurple,
        punctuation: .secondaryLabelColor,
        heading: .systemBlue,
        tag: .systemBlue,
        attr: .systemPurple
    )

    static let solarizedLight = Theme(
        id: "solarized-light",
        displayName: "Solarized Light",
        background: NSColor(srgbRed: 0.99, green: 0.96, blue: 0.89, alpha: 1.0),
        text: NSColor(srgbRed: 0.40, green: 0.48, blue: 0.51, alpha: 1.0),
        keyword: NSColor(srgbRed: 0.52, green: 0.60, blue: 0.00, alpha: 1.0),
        string: NSColor(srgbRed: 0.16, green: 0.63, blue: 0.60, alpha: 1.0),
        number: NSColor(srgbRed: 0.83, green: 0.21, blue: 0.51, alpha: 1.0),
        comment: NSColor(srgbRed: 0.58, green: 0.63, blue: 0.63, alpha: 1.0),
        typeName: NSColor(srgbRed: 0.71, green: 0.54, blue: 0.00, alpha: 1.0),
        decorator: NSColor(srgbRed: 0.42, green: 0.44, blue: 0.77, alpha: 1.0),
        punctuation: NSColor(srgbRed: 0.51, green: 0.58, blue: 0.59, alpha: 1.0),
        heading: NSColor(srgbRed: 0.15, green: 0.55, blue: 0.82, alpha: 1.0),
        tag: NSColor(srgbRed: 0.86, green: 0.20, blue: 0.18, alpha: 1.0),
        attr: NSColor(srgbRed: 0.42, green: 0.44, blue: 0.77, alpha: 1.0)
    )

    static let solarizedDark = Theme(
        id: "solarized-dark",
        displayName: "Solarized Dark",
        background: NSColor(srgbRed: 0.00, green: 0.17, blue: 0.21, alpha: 1.0),
        text: NSColor(srgbRed: 0.51, green: 0.58, blue: 0.59, alpha: 1.0),
        keyword: NSColor(srgbRed: 0.52, green: 0.60, blue: 0.00, alpha: 1.0),
        string: NSColor(srgbRed: 0.16, green: 0.63, blue: 0.60, alpha: 1.0),
        number: NSColor(srgbRed: 0.83, green: 0.21, blue: 0.51, alpha: 1.0),
        comment: NSColor(srgbRed: 0.40, green: 0.48, blue: 0.51, alpha: 1.0),
        typeName: NSColor(srgbRed: 0.71, green: 0.54, blue: 0.00, alpha: 1.0),
        decorator: NSColor(srgbRed: 0.42, green: 0.44, blue: 0.77, alpha: 1.0),
        punctuation: NSColor(srgbRed: 0.40, green: 0.48, blue: 0.51, alpha: 1.0),
        heading: NSColor(srgbRed: 0.15, green: 0.55, blue: 0.82, alpha: 1.0),
        tag: NSColor(srgbRed: 0.86, green: 0.20, blue: 0.18, alpha: 1.0),
        attr: NSColor(srgbRed: 0.42, green: 0.44, blue: 0.77, alpha: 1.0)
    )

    static let oneDark = Theme(
        id: "one-dark",
        displayName: "One Dark",
        background: NSColor(srgbRed: 0.157, green: 0.173, blue: 0.204, alpha: 1.0),
        text: NSColor(srgbRed: 0.671, green: 0.698, blue: 0.749, alpha: 1.0),
        keyword: NSColor(srgbRed: 0.776, green: 0.471, blue: 0.867, alpha: 1.0),
        string: NSColor(srgbRed: 0.596, green: 0.765, blue: 0.475, alpha: 1.0),
        number: NSColor(srgbRed: 0.820, green: 0.604, blue: 0.400, alpha: 1.0),
        comment: NSColor(srgbRed: 0.361, green: 0.396, blue: 0.443, alpha: 1.0),
        typeName: NSColor(srgbRed: 0.898, green: 0.753, blue: 0.482, alpha: 1.0),
        decorator: NSColor(srgbRed: 0.816, green: 0.529, blue: 0.439, alpha: 1.0),
        punctuation: NSColor(srgbRed: 0.671, green: 0.698, blue: 0.749, alpha: 1.0),
        heading: NSColor(srgbRed: 0.380, green: 0.686, blue: 0.937, alpha: 1.0),
        tag: NSColor(srgbRed: 0.910, green: 0.435, blue: 0.455, alpha: 1.0),
        attr: NSColor(srgbRed: 0.820, green: 0.604, blue: 0.400, alpha: 1.0)
    )

    static let monokai = Theme(
        id: "monokai",
        displayName: "Monokai",
        background: NSColor(srgbRed: 0.157, green: 0.157, blue: 0.157, alpha: 1.0),
        text: NSColor(srgbRed: 0.973, green: 0.973, blue: 0.949, alpha: 1.0),
        keyword: NSColor(srgbRed: 0.976, green: 0.149, blue: 0.447, alpha: 1.0),
        string: NSColor(srgbRed: 0.902, green: 0.859, blue: 0.455, alpha: 1.0),
        number: NSColor(srgbRed: 0.682, green: 0.506, blue: 1.000, alpha: 1.0),
        comment: NSColor(srgbRed: 0.459, green: 0.443, blue: 0.369, alpha: 1.0),
        typeName: NSColor(srgbRed: 0.400, green: 0.851, blue: 0.937, alpha: 1.0),
        decorator: NSColor(srgbRed: 0.651, green: 0.886, blue: 0.180, alpha: 1.0),
        punctuation: NSColor(srgbRed: 0.973, green: 0.973, blue: 0.949, alpha: 1.0),
        heading: NSColor(srgbRed: 0.992, green: 0.592, blue: 0.122, alpha: 1.0),
        tag: NSColor(srgbRed: 0.976, green: 0.149, blue: 0.447, alpha: 1.0),
        attr: NSColor(srgbRed: 0.651, green: 0.886, blue: 0.180, alpha: 1.0)
    )

    static let all: [Theme] = [
        ThemeRegistry.default,
        ThemeRegistry.solarizedLight,
        ThemeRegistry.solarizedDark,
        ThemeRegistry.oneDark,
        ThemeRegistry.monokai,
    ]

    static var current: Theme {
        let id = UserDefaults.standard.string(forKey: defaultsKey) ?? ThemeRegistry.default.id
        return all.first(where: { $0.id == id }) ?? ThemeRegistry.default
    }

    static func setCurrent(_ theme: Theme) {
        UserDefaults.standard.set(theme.id, forKey: defaultsKey)
        NotificationCenter.default.post(name: .themeDidChange, object: theme)
    }

    static func theme(withID id: String) -> Theme? {
        return all.first { $0.id == id }
    }
}

extension Notification.Name {
    static let themeDidChange = Notification.Name("foolscap.themeDidChange")
}
