import AppKit

/// Hosts up to two EditorViewControllers backed by the same NSTextStorage.
///
/// Single-editor case: the container view is a plain NSView and the editor's
/// view is pinned to all four edges. We deliberately do **not** use
/// NSSplitView with a single arranged subview — on macOS Tahoe this often
/// leaves the editor compressed to its status-bar height, manifesting as
/// blank tabs with the status bar floating at the top of the editor area.
///
/// Split case: when the user requests a split, we insert an NSSplitView
/// containing *two* arranged subviews and re-pin the container. NSSplitView's
/// arranged-subview constraints behave correctly once there are two children
/// to lay out.
final class TabContainerViewController: NSViewController {

    weak var file: WorkspaceFile?
    private(set) var editors: [EditorViewController] = []
    private var splitView: NSSplitView?

    init(file: WorkspaceFile) {
        super.init(nibName: nil, bundle: nil)
        self.file = file
    }

    required init?(coder: NSCoder) { fatalError() }

    override func loadView() {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false
        self.view = container
        addPrimaryEditor()
    }

    /// Primary editor — fired on first attach.
    var primary: EditorViewController? { editors.first }

    private func addPrimaryEditor() {
        guard let file = file else { fatalError("TabContainer without file") }
        let storage = file.acquireTextStorage()
        let editor = EditorViewController(textStorage: storage)
        editor.host = file
        editors.append(editor)
        file.editors.append(editor)
        addChild(editor)
        editor.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(editor.view)
        NSLayoutConstraint.activate([
            editor.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            editor.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            editor.view.topAnchor.constraint(equalTo: view.topAnchor),
            editor.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        editor.applyLoadedText()
    }

    func split() {
        guard editors.count == 1, let primary = editors.first, let file = file else { return }

        let sv = NSSplitView()
        sv.isVertical = true
        sv.dividerStyle = .thin
        sv.translatesAutoresizingMaskIntoConstraints = false

        primary.view.removeFromSuperview()
        sv.addArrangedSubview(primary.view)

        // Second editor sharing the same NSTextStorage.
        let secondary = EditorViewController(textStorage: file.acquireTextStorage())
        secondary.host = file
        editors.append(secondary)
        file.editors.append(secondary)
        addChild(secondary)
        sv.addArrangedSubview(secondary.view)

        view.addSubview(sv)
        NSLayoutConstraint.activate([
            sv.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            sv.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            sv.topAnchor.constraint(equalTo: view.topAnchor),
            sv.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        self.splitView = sv

        secondary.applyLoadedText()
        view.window?.makeFirstResponder(secondary.view)
    }

    func unsplit() {
        guard editors.count > 1, let secondary = editors.last, let primary = editors.first else { return }
        secondary.view.removeFromSuperview()
        secondary.removeFromParent()
        editors.removeLast()
        file?.editors.removeAll { $0 === secondary }

        // Tear down the split view and re-pin the primary editor directly.
        primary.view.removeFromSuperview()
        splitView?.removeFromSuperview()
        splitView = nil

        primary.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(primary.view)
        NSLayoutConstraint.activate([
            primary.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            primary.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            primary.view.topAnchor.constraint(equalTo: view.topAnchor),
            primary.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        view.window?.makeFirstResponder(primary.view)
    }

    var isSplit: Bool { editors.count > 1 }
}
