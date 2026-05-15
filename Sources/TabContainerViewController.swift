import AppKit

/// Hosts up to two EditorViewControllers backed by the same NSTextStorage.
/// Used inside each NSTabViewItem of a workspace window so that "Split Editor"
/// can swap a single editor for a side-by-side pair without rebuilding the tab.
final class TabContainerViewController: NSViewController {

    weak var file: WorkspaceFile?
    private(set) var editors: [EditorViewController] = []
    private var splitView: NSSplitView!

    init(file: WorkspaceFile) {
        super.init(nibName: nil, bundle: nil)
        self.file = file
    }

    required init?(coder: NSCoder) { fatalError() }

    override func loadView() {
        splitView = NSSplitView()
        splitView.isVertical = true
        splitView.dividerStyle = .thin
        splitView.translatesAutoresizingMaskIntoConstraints = false
        self.view = splitView

        addEditor()
    }

    /// Primary editor — fired on first attach.
    var primary: EditorViewController? { editors.first }

    @discardableResult
    func addEditor() -> EditorViewController {
        guard let file = file else { fatalError("TabContainer without file") }
        let storage = file.acquireTextStorage()
        let editor = EditorViewController(textStorage: storage)
        editor.host = file
        editors.append(editor)
        file.editors.append(editor)
        addChild(editor)
        splitView.addArrangedSubview(editor.view)
        editor.applyLoadedText()
        return editor
    }

    func split() {
        guard editors.count == 1 else { return }
        let second = addEditor()
        view.window?.makeFirstResponder(second.view)
    }

    func unsplit() {
        guard editors.count > 1, let secondary = editors.last else { return }
        secondary.view.removeFromSuperview()
        secondary.removeFromParent()
        editors.removeLast()
        file?.editors.removeAll { $0 === secondary }
        if let primary = editors.first {
            view.window?.makeFirstResponder(primary.view)
        }
    }

    var isSplit: Bool { editors.count > 1 }
}
