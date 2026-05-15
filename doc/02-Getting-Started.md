# Getting Started

## Opening files

- **File ▸ New** (⌘N) creates an untitled document in a new window.
- **File ▸ Open…** (⌘O) opens an existing file in a new window — or as a new
  tab in the front window when "Prefer Tabs" is set in System Settings ▸
  Desktop & Dock.
- **File ▸ Open Folder…** (⇧⌘O) opens a project folder as a *workspace* with a
  sidebar file tree. Click a file in the sidebar to open it as a tab inside
  the workspace window.
- **File ▸ Open Recent** shows the last files you've opened.

You can also drag files onto the Foolscap dock icon.

## Saving

- **File ▸ Save** (⌘S) saves the current tab.
- **File ▸ Save As…** (⇧⌘S) writes the current document to a new location.
- **Autosave**: untitled documents and files in user-writable locations
  autosave automatically.
- **Revert**: File ▸ Revert to Saved discards in-memory changes.

## Encoding & line endings

The bottom status bar of every editor shows three pop-ups:

- **Language** — overrides the auto-detected syntax mode
- **Encoding** — the encoding Foolscap will use the *next time it saves* this
  file (UTF-8 is default; falls back to UTF-16 / Latin-1 / Windows-1252 /
  Mac Roman when reading)
- **Line endings** — `LF` / `CRLF` / `CR`. Changing this converts line endings
  on the next save.

Foolscap stores text internally as LF and converts on read and write, so you
won't see CR or CRLF inside the editor itself.

## When a file changes on disk

If a file you have open is modified by another application, Foolscap detects
the change and:

- **Auto-reloads** if your in-memory copy is unchanged.
- **Prompts you** if you have unsaved edits, asking whether to reload from
  disk or keep your version.

## Closing

⌘W closes the front tab (or window in single-file mode). If the tab has
unsaved changes, you'll be asked whether to save, discard, or cancel.
