import Foundation

/// Per-editor caret-position history. Maintains a "back" stack of recently
/// visited positions and a separate "forward" stack populated when you jump
/// back. Mirrors the model used by most editor "back / forward" buttons.
final class CursorHistory {

    /// Two positions are considered "the same place" if they share a line —
    /// stops every keystroke from polluting the back stack.
    private let groupingDistance: Int = 25

    private(set) var back: [Int] = []
    private(set) var forward: [Int] = []
    private var current: Int? = nil

    private let capacity: Int = 200

    func recordCurrent(_ index: Int) {
        if let cur = current, abs(cur - index) < groupingDistance {
            current = index
            return
        }
        if let cur = current {
            back.append(cur)
            if back.count > capacity { back.removeFirst() }
        }
        current = index
        // A new explicit recording invalidates the forward stack.
        forward.removeAll()
    }

    /// Jump to the previous position; returns the index to navigate to, or nil.
    func goBack() -> Int? {
        guard let target = back.popLast() else { return nil }
        if let cur = current { forward.append(cur) }
        current = target
        return target
    }

    /// Jump to the next position; returns the index to navigate to, or nil.
    func goForward() -> Int? {
        guard let target = forward.popLast() else { return nil }
        if let cur = current { back.append(cur) }
        current = target
        return target
    }

    var canGoBack: Bool { !back.isEmpty }
    var canGoForward: Bool { !forward.isEmpty }
}
