import AppKit

/// NSTabView subclass that supports a right-click context menu on individual
/// tabs. The actual menu is built by the WorkspaceWindowController; this
/// class only handles hit-testing the click location to figure out which
/// tab was right-clicked.
final class WorkspaceTabView: NSTabView {

    weak var workspaceController: WorkspaceWindowController?

    override func menu(for event: NSEvent) -> NSMenu? {
        let point = convert(event.locationInWindow, from: nil)
        guard let item = tabViewItem(at: point) else {
            return super.menu(for: event)
        }
        return workspaceController?.contextMenu(forTab: item)
    }

    override func mouseDown(with event: NSEvent) {
        if event.modifierFlags.contains(.control), popUpContextMenu(for: event) {
            return
        }
        super.mouseDown(with: event)
    }

    override func rightMouseDown(with event: NSEvent) {
        if popUpContextMenu(for: event) {
            return
        }
        super.rightMouseDown(with: event)
    }

    @discardableResult
    private func popUpContextMenu(for event: NSEvent) -> Bool {
        let point = convert(event.locationInWindow, from: nil)
        guard let item = tabViewItem(at: point),
              let menu = workspaceController?.contextMenu(forTab: item) else {
            return false
        }
        NSMenu.popUpContextMenu(menu, with: event, for: self)
        return true
    }
}
