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
}
