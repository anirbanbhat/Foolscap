import AppKit

/// Produces small, tinted SF Symbol icons for use in the workspace sidebar.
/// Each known file extension maps to a (SF Symbol, tint colour) pair —
/// unknown extensions fall back to the system file icon.
enum FileIcon {

    private struct Style {
        let symbol: String
        let color: NSColor
    }

    private static let byExtension: [String: Style] = [
        // Swift / Apple
        "swift":     Style(symbol: "swift",                              color: .systemOrange),
        // C-family
        "c":         Style(symbol: "c.square",                           color: NSColor(srgbRed: 0.40, green: 0.55, blue: 0.85, alpha: 1)),
        "h":         Style(symbol: "c.square",                           color: NSColor(srgbRed: 0.55, green: 0.55, blue: 0.55, alpha: 1)),
        "cpp":       Style(symbol: "c.square",                           color: NSColor(srgbRed: 0.60, green: 0.35, blue: 0.75, alpha: 1)),
        "cxx":       Style(symbol: "c.square",                           color: NSColor(srgbRed: 0.60, green: 0.35, blue: 0.75, alpha: 1)),
        "cc":        Style(symbol: "c.square",                           color: NSColor(srgbRed: 0.60, green: 0.35, blue: 0.75, alpha: 1)),
        "hpp":       Style(symbol: "c.square",                           color: NSColor(srgbRed: 0.50, green: 0.50, blue: 0.60, alpha: 1)),
        "hxx":       Style(symbol: "c.square",                           color: NSColor(srgbRed: 0.50, green: 0.50, blue: 0.60, alpha: 1)),
        "hh":        Style(symbol: "c.square",                           color: NSColor(srgbRed: 0.50, green: 0.50, blue: 0.60, alpha: 1)),
        // Other languages
        "py":        Style(symbol: "chevron.left.forwardslash.chevron.right", color: NSColor(srgbRed: 0.25, green: 0.55, blue: 0.80, alpha: 1)),
        "pyw":       Style(symbol: "chevron.left.forwardslash.chevron.right", color: NSColor(srgbRed: 0.25, green: 0.55, blue: 0.80, alpha: 1)),
        "js":        Style(symbol: "j.square.fill",                      color: NSColor(srgbRed: 0.95, green: 0.85, blue: 0.20, alpha: 1)),
        "mjs":       Style(symbol: "j.square.fill",                      color: NSColor(srgbRed: 0.95, green: 0.85, blue: 0.20, alpha: 1)),
        "cjs":       Style(symbol: "j.square.fill",                      color: NSColor(srgbRed: 0.95, green: 0.85, blue: 0.20, alpha: 1)),
        "jsx":       Style(symbol: "j.square.fill",                      color: NSColor(srgbRed: 0.30, green: 0.75, blue: 0.85, alpha: 1)),
        "ts":        Style(symbol: "t.square.fill",                      color: NSColor(srgbRed: 0.20, green: 0.50, blue: 0.80, alpha: 1)),
        "tsx":       Style(symbol: "t.square.fill",                      color: NSColor(srgbRed: 0.20, green: 0.50, blue: 0.80, alpha: 1)),
        "go":        Style(symbol: "g.square.fill",                      color: NSColor(srgbRed: 0.00, green: 0.68, blue: 0.85, alpha: 1)),
        "rs":        Style(symbol: "gearshape.2.fill",                   color: NSColor(srgbRed: 0.85, green: 0.42, blue: 0.20, alpha: 1)),
        "java":      Style(symbol: "cup.and.saucer.fill",                color: NSColor(srgbRed: 0.85, green: 0.40, blue: 0.30, alpha: 1)),
        // Web
        "html":      Style(symbol: "globe",                              color: NSColor(srgbRed: 0.90, green: 0.40, blue: 0.20, alpha: 1)),
        "htm":       Style(symbol: "globe",                              color: NSColor(srgbRed: 0.90, green: 0.40, blue: 0.20, alpha: 1)),
        "xhtml":     Style(symbol: "globe",                              color: NSColor(srgbRed: 0.90, green: 0.40, blue: 0.20, alpha: 1)),
        "css":       Style(symbol: "paintbrush.fill",                    color: NSColor(srgbRed: 0.20, green: 0.50, blue: 0.85, alpha: 1)),
        "scss":      Style(symbol: "paintbrush.fill",                    color: NSColor(srgbRed: 0.85, green: 0.40, blue: 0.55, alpha: 1)),
        "sass":      Style(symbol: "paintbrush.fill",                    color: NSColor(srgbRed: 0.85, green: 0.40, blue: 0.55, alpha: 1)),
        "less":      Style(symbol: "paintbrush.fill",                    color: NSColor(srgbRed: 0.30, green: 0.40, blue: 0.65, alpha: 1)),
        // Data
        "json":      Style(symbol: "curlybraces",                        color: NSColor(srgbRed: 0.85, green: 0.65, blue: 0.20, alpha: 1)),
        "yaml":      Style(symbol: "list.bullet.indent",                 color: NSColor(srgbRed: 0.80, green: 0.30, blue: 0.30, alpha: 1)),
        "yml":       Style(symbol: "list.bullet.indent",                 color: NSColor(srgbRed: 0.80, green: 0.30, blue: 0.30, alpha: 1)),
        "xml":       Style(symbol: "doc.text",                           color: NSColor(srgbRed: 0.30, green: 0.65, blue: 0.65, alpha: 1)),
        "plist":     Style(symbol: "doc.badge.gearshape",                color: NSColor(srgbRed: 0.30, green: 0.65, blue: 0.65, alpha: 1)),
        "svg":       Style(symbol: "photo.fill",                         color: NSColor(srgbRed: 0.75, green: 0.55, blue: 0.20, alpha: 1)),
        "toml":      Style(symbol: "list.bullet.indent",                 color: NSColor(srgbRed: 0.55, green: 0.40, blue: 0.30, alpha: 1)),
        // Shell / scripts
        "sh":        Style(symbol: "terminal.fill",                      color: NSColor(srgbRed: 0.35, green: 0.65, blue: 0.35, alpha: 1)),
        "bash":      Style(symbol: "terminal.fill",                      color: NSColor(srgbRed: 0.35, green: 0.65, blue: 0.35, alpha: 1)),
        "zsh":       Style(symbol: "terminal.fill",                      color: NSColor(srgbRed: 0.35, green: 0.65, blue: 0.35, alpha: 1)),
        "fish":      Style(symbol: "terminal.fill",                      color: NSColor(srgbRed: 0.35, green: 0.65, blue: 0.35, alpha: 1)),
        "command":   Style(symbol: "terminal.fill",                      color: NSColor(srgbRed: 0.35, green: 0.65, blue: 0.35, alpha: 1)),
        // Docs
        "md":        Style(symbol: "doc.richtext.fill",                  color: NSColor(srgbRed: 0.40, green: 0.40, blue: 0.85, alpha: 1)),
        "markdown":  Style(symbol: "doc.richtext.fill",                  color: NSColor(srgbRed: 0.40, green: 0.40, blue: 0.85, alpha: 1)),
        "txt":       Style(symbol: "doc.text",                           color: NSColor.secondaryLabelColor),
        "log":       Style(symbol: "scroll.fill",                        color: NSColor.secondaryLabelColor),
        // Config / misc
        "lock":      Style(symbol: "lock.fill",                          color: NSColor.secondaryLabelColor),
        "env":       Style(symbol: "key.fill",                           color: NSColor(srgbRed: 0.80, green: 0.70, blue: 0.30, alpha: 1)),
        "gitignore": Style(symbol: "minus.diamond.fill",                 color: NSColor(srgbRed: 0.90, green: 0.45, blue: 0.30, alpha: 1)),
        "editorconfig": Style(symbol: "ruler.fill",                      color: NSColor.secondaryLabelColor),
        "license":   Style(symbol: "scroll.fill",                        color: NSColor(srgbRed: 0.70, green: 0.55, blue: 0.20, alpha: 1)),
    ]

    /// Special filenames (no extension or unusual ones) checked before extension lookup.
    private static let byFilename: [String: Style] = [
        "makefile":    Style(symbol: "hammer.fill",          color: NSColor(srgbRed: 0.60, green: 0.45, blue: 0.20, alpha: 1)),
        "dockerfile":  Style(symbol: "cube.box.fill",        color: NSColor(srgbRed: 0.20, green: 0.55, blue: 0.85, alpha: 1)),
        "readme.md":   Style(symbol: "info.circle.fill",     color: NSColor(srgbRed: 0.20, green: 0.55, blue: 0.85, alpha: 1)),
        "readme":      Style(symbol: "info.circle.fill",     color: NSColor(srgbRed: 0.20, green: 0.55, blue: 0.85, alpha: 1)),
        "license":     Style(symbol: "scroll.fill",          color: NSColor(srgbRed: 0.70, green: 0.55, blue: 0.20, alpha: 1)),
        ".gitignore":  Style(symbol: "minus.diamond.fill",   color: NSColor(srgbRed: 0.90, green: 0.45, blue: 0.30, alpha: 1)),
        ".editorconfig": Style(symbol: "ruler.fill",         color: NSColor.secondaryLabelColor),
        ".env":        Style(symbol: "key.fill",             color: NSColor(srgbRed: 0.80, green: 0.70, blue: 0.30, alpha: 1)),
        "info.plist":  Style(symbol: "doc.badge.gearshape",  color: NSColor(srgbRed: 0.30, green: 0.65, blue: 0.65, alpha: 1)),
        "build.sh":    Style(symbol: "hammer.fill",          color: NSColor(srgbRed: 0.35, green: 0.65, blue: 0.35, alpha: 1)),
        "test.sh":     Style(symbol: "checkmark.seal.fill",  color: NSColor(srgbRed: 0.35, green: 0.65, blue: 0.45, alpha: 1)),
    ]

    private static let directoryStyle = Style(symbol: "folder.fill", color: NSColor(srgbRed: 0.45, green: 0.65, blue: 0.85, alpha: 1))
    private static let openDirectoryStyle = Style(symbol: "folder.fill", color: NSColor(srgbRed: 0.55, green: 0.75, blue: 0.95, alpha: 1))
    private static let unknownStyle = Style(symbol: "doc", color: NSColor.secondaryLabelColor)

    /// Cache by (symbol + RGB) so repeated outline-view cell renders are
    /// near-free. Without this, scrolling the sidebar would lockFocus-tint
    /// fresh images on every redraw.
    private static var cache: [String: NSImage] = [:]

    static func icon(for url: URL, isDirectory: Bool) -> NSImage {
        let style = resolveStyle(for: url, isDirectory: isDirectory)
        let key = style.symbol + ":" + colorKey(style.color)
        if let cached = cache[key] { return cached }
        let img = renderSymbol(style)
        cache[key] = img
        return img
    }

    private static func resolveStyle(for url: URL, isDirectory: Bool) -> Style {
        if isDirectory { return directoryStyle }
        let nameLower = url.lastPathComponent.lowercased()
        if let s = byFilename[nameLower] { return s }
        let ext = url.pathExtension.lowercased()
        if let s = byExtension[ext] { return s }
        return unknownStyle
    }

    private static func renderSymbol(_ style: Style) -> NSImage {
        // Use SymbolConfiguration(paletteColors:) instead of lockFocus
        // tinting — orders of magnitude faster and avoids the implicit
        // off-screen window lockFocus would otherwise allocate per call.
        let sizing = NSImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
        let paletted = NSImage.SymbolConfiguration(paletteColors: [style.color])
        let combined = sizing.applying(paletted)
        return NSImage(systemSymbolName: style.symbol, accessibilityDescription: nil)?
                .withSymbolConfiguration(combined)
            ?? NSImage(size: NSSize(width: 14, height: 14))
    }

    private static func colorKey(_ color: NSColor) -> String {
        guard let rgb = color.usingColorSpace(.sRGB) else { return color.description }
        return String(format: "%.3f,%.3f,%.3f,%.3f",
                      rgb.redComponent, rgb.greenComponent, rgb.blueComponent, rgb.alphaComponent)
    }
}
