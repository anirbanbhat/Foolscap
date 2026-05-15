import AppKit

/// Anything that can host an EditorViewController: an NSDocument (for tabbed
/// document windows) or a WorkspaceFile (for files opened inside a workspace
/// window's tab view). Decouples the editor from NSDocument lifecycle.
protocol EditingHost: AnyObject {
    var text: String { get set }
    var encoding: String.Encoding { get set }
    var lineEnding: LineEnding { get set }
    var detectedLanguage: SyntaxHighlighter.Language { get set }
    var editorTitle: String { get }
    var fileURL: URL? { get }
    var indentSettings: IndentSettings { get set }
    func markEdited()
    func notifyEditorCleared()
}

extension EditingHost {
    func notifyEditorCleared() {}
}
