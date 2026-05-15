import Foundation

struct FileIndexEntry: Equatable {
    let url: URL
    /// Path of the file relative to the workspace root, displayed in pickers.
    let relativePath: String
}

enum FileIndex {

    private static let skipDirs: Set<String> = [
        ".git", ".svn", ".hg",
        "node_modules", ".npm", ".yarn",
        ".build", "DerivedData", "Pods", "build", ".gradle",
        ".idea", ".vscode",
        ".DS_Store",
        "__pycache__", ".pytest_cache", ".venv", "venv", ".tox",
        "target", "dist", "out", ".next"
    ]

    private static let skipExtensions: Set<String> = [
        "png","jpg","jpeg","gif","tiff","bmp","ico","webp","heic",
        "mp3","wav","flac","aac","ogg","m4a",
        "mp4","mov","avi","mkv","webm",
        "pdf","zip","tar","gz","bz2","7z","xz","rar",
        "dylib","so","a","o","exe","bin","dat",
        "ttf","otf","woff","woff2",
        "psd","sketch","fig","ai","key","numbers","pages"
    ]

    /// Recursive walk over the workspace; returns text-like files only.
    static func walk(root: URL) -> [FileIndexEntry] {
        let fm = FileManager.default
        let basePath = root.standardizedFileURL.path
        let keys: [URLResourceKey] = [.isRegularFileKey, .isDirectoryKey]
        guard let enumerator = fm.enumerator(at: root, includingPropertiesForKeys: keys, options: [.skipsHiddenFiles], errorHandler: nil) else {
            return []
        }
        var entries: [FileIndexEntry] = []
        for case let url as URL in enumerator {
            if skipDirs.contains(url.lastPathComponent) {
                enumerator.skipDescendants()
                continue
            }
            guard let values = try? url.resourceValues(forKeys: Set(keys)) else { continue }
            if values.isDirectory == true { continue }
            let ext = url.pathExtension.lowercased()
            if skipExtensions.contains(ext) { continue }

            let p = url.standardizedFileURL.path
            var rel = p
            if rel.hasPrefix(basePath) {
                rel = String(rel.dropFirst(basePath.count))
                if rel.hasPrefix("/") { rel.removeFirst() }
            }
            entries.append(FileIndexEntry(url: url, relativePath: rel))
        }
        entries.sort { $0.relativePath.localizedStandardCompare($1.relativePath) == .orderedAscending }
        return entries
    }
}
