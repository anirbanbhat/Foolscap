# Tips and Tricks

## Quick conversions on selection

Most of the **Edit ▸ Convert** actions act on the current selection — but if
nothing is selected, they fall back to acting on the whole document. This
makes them handy for one-shot file-wide cleanups (e.g. *Trim Trailing
Whitespace* over the entire buffer in one keystroke).

## Auto-indent

Pressing Return copies the leading whitespace of the current line onto the
new one. To break out of an indent block, hit Return and then Backspace once
per indent level — or use **Shift-Tab** to dedent (standard macOS behaviour).

## Tab inserts four spaces

Foolscap uses soft tabs by default — a Tab key insert produces four spaces.
If you need actual tab characters, you can paste them, or run **Edit ▸ Lines
▸ Spaces → Tabs** after typing.

## Find: hidden powers

The Find bar (⌘F) is the standard macOS `NSTextFinder` UI and supports:

- **⌥ + Return** in the find field — toggles **Insert Tab Character** and
  similar special characters
- The little magnifying-glass menu has filter options: Contains, Starts With,
  Ends With, Full Word, and a Recent Searches submenu.
- ⌘E sets the find string to the current selection without opening the bar.

## Two ways to highlight

When you select a word, every other occurrence in the file glows yellow.
That's the *occurrence highlight*. To turn it off, just collapse the
selection (click anywhere or press Escape).

## Bookmarks survive edits

Bookmarks are anchored to character positions and shift correctly when you
insert or delete text above them. Editing the line that holds a bookmark
keeps the bookmark on that line.

## Change-history stripes

The thin coloured stripe at the right edge of the line-number gutter shows
edit state per line:

- **Orange** — modified since the last save
- **Green** — modified, then saved (still differs from the version on disk
  when you opened the file)
- **None** — untouched since open

The orange-to-green transition happens automatically on save.

## Folders to ignore

The workspace tree and Find in Workspace both skip `.git`, `node_modules`,
build directories, and so on. If a directory you want to see is being hidden,
verify its name isn't in the skip list (see *Workspaces and Find*) and file
an issue.

## Encoding gotchas

Foolscap is permissive on read (it tries UTF-8 → UTF-16 → Latin-1 →
Windows-1252 → Mac Roman) but strict on write — if the active encoding can't
represent the current characters, it falls back to UTF-8 silently. Use the
encoding pop-up on the status bar to pick something explicit before saving.
