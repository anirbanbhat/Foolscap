import Foundation

struct IndentSettings: Equatable {
    var useTabs: Bool = false
    var size: Int = 4
    var trimTrailingWhitespaceOnSave: Bool = false
    var insertFinalNewlineOnSave: Bool = false

    static let `default` = IndentSettings()

    /// Returns the string to insert when the Tab key is pressed.
    var tabInsertion: String {
        if useTabs { return "\t" }
        return String(repeating: " ", count: max(1, size))
    }
}
