import Foundation

final class FileTreeNode {

    let url: URL
    let isDirectory: Bool
    private var childrenCache: [FileTreeNode]?

    /// Names to skip when listing a directory.
    private static let skippedNames: Set<String> = [
        ".git", ".svn", ".hg",
        "node_modules", ".npm", ".yarn",
        ".build", "DerivedData", "Pods", "build", ".gradle",
        ".idea", ".vscode",
        ".DS_Store",
        "__pycache__", ".pytest_cache", ".venv", "venv", ".tox",
        "target", "dist", "out", ".next"
    ]

    init(url: URL, isDirectory: Bool) {
        self.url = url
        self.isDirectory = isDirectory
    }

    var name: String { url.lastPathComponent }

    var children: [FileTreeNode] {
        if let cached = childrenCache { return cached }
        guard isDirectory else { childrenCache = []; return [] }
        let fm = FileManager.default
        let urls = (try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: [.isDirectoryKey, .nameKey], options: [.skipsHiddenFiles])) ?? []
        let nodes = urls
            .filter { !FileTreeNode.skippedNames.contains($0.lastPathComponent) }
            .map { u -> FileTreeNode in
                var isDir: ObjCBool = false
                fm.fileExists(atPath: u.path, isDirectory: &isDir)
                return FileTreeNode(url: u, isDirectory: isDir.boolValue)
            }
            .sorted { a, b in
                if a.isDirectory != b.isDirectory { return a.isDirectory && !b.isDirectory }
                return a.name.localizedStandardCompare(b.name) == .orderedAscending
            }
        childrenCache = nodes
        return nodes
    }

    func invalidateChildren() {
        childrenCache = nil
    }
}
