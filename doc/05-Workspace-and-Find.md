# Workspaces and Find in Files

A *workspace* is a project folder you've opened with **File ▸ Open Folder…**
(⇧⌘O). It gives you a sidebar file tree on the left and a tabbed editor area
on the right.

## The file tree

- Single-click a file to open it as a tab.
- Double-click a folder to expand or collapse it.
- The tree skips common noise: `.git`, `.svn`, `node_modules`, `.build`,
  `DerivedData`, `Pods`, `build`, `__pycache__`, `target`, `dist`, `.next`,
  `.idea`, `.vscode`, `.DS_Store`, and similar.

## Tabs

Tabs in a workspace window are independent from macOS native window tabs.
They behave like a typical editor tab strip — switch with the mouse, or cycle
in most-recently-used order with **⌃⇥** and **⌃⇧⇥**.

A leading `•` on a tab name means it has unsaved changes. Closing a dirty tab
prompts to Save, Discard, or Cancel.

## Find in Workspace

**Edit ▸ Find ▸ Find in Workspace…** (⇧⌘F) opens a search sheet on the
workspace window.

- The query field accepts a literal string by default. Tick **Regex** to treat
  it as a `NSRegularExpression`-style pattern.
- Tick **Case sensitive** to make the search exact-case.
- Press **Return** or click **Search** to run.
- Results are listed by file, line number, and the matching line. Double-click
  any result to open the file and jump to that match.

## What's searched

Find in Workspace walks the workspace folder recursively. It skips:

- Files with binary-ish extensions (images, audio/video, archives, fonts,
  compiled artefacts, design files — `.png`, `.zip`, `.dylib`, `.o`, `.ttf`,
  `.psd`, etc.)
- Files larger than 5 MB
- Files whose bytes are neither valid UTF-8 nor Latin-1

Results are capped at 5,000 matches per search to keep the UI responsive.

## Multiple workspaces

Each call to **Open Folder…** creates a separate workspace window. Opening
the same folder twice brings the existing window forward instead of
duplicating it.

## Session restore

On quit Foolscap remembers the list of open workspaces *and* any standalone
files. On the next launch, if you start the app with no document, it restores
that session. Launching by double-clicking a file does **not** trigger the
restore — Foolscap only opens what you asked for.
