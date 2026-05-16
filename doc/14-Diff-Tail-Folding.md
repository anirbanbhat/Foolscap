# Diff View, Tail Mode, Code Folding

## Diff view — compare two files

**File ▸ Compare Two Files…** opens two file pickers in sequence. After
choosing a "left" and a "right" file, Foolscap opens a side-by-side diff
window.

- Each row is one line; rows align so unchanged lines sit on the same row
  on both sides.
- **Removed** lines (present on the left but not the right) get a red
  background on the left, blank on the right.
- **Added** lines (present on the right but not the left) get a green
  background on the right, blank on the left.
- The two scroll views are synchronised: scrolling either pane scrolls the
  other.

The diff is computed with a standard LCS algorithm — O(N×M) in lines on
both sides. Fine up to several thousand lines; slow on very large files.
There is no in-line word diff or syntax highlighting inside the diff view in
v5.

## Tail mode — follow a file as it grows

**File ▸ Tail Mode (Follow File)** (⇧⌘T) toggles tail mode on the front
standalone document window.

When tail mode is on:

- Every time the file changes on disk, the buffer silently reloads — no
  prompt.
- The editor scrolls to the bottom after each reload.
- Editing is disabled (the text view becomes read-only) so a write under
  your caret can't surprise you.

Turn it off again with the same menu item to resume normal editing.

This is built on `NSFilePresenter`, the same machinery Foolscap uses for
external-change detection in normal mode. The only difference is the
silent-reload + scroll-to-end behaviour.

### When tail mode helps

- Watching a log file from a running process
- Watching a build log update incrementally
- Watching a file that gets rewritten by a script

For files that already exist in a workspace window, tail mode currently
applies only to the standalone tabbed-document flow (File ▸ Open). Opening
the log via **File ▸ Open** and then toggling tail mode is the path.

## Code folding

Three commands live under the **View** menu:

| Action | Shortcut |
|---|---|
| Fold at Current Line | ⌥⌘. |
| Fold All | (menu only) |
| Unfold All | (menu only) |

Foolscap detects fold-able regions in two ways:

| Languages | Strategy |
|---|---|
| Swift, JavaScript, C, C++, Go, Rust, Java, JSON, CSS | brace pairs (`{…}`) outside string/comment context |
| Python, YAML | indent-based regions (a deeper-indented block) |
| Markdown | heading-bounded sections (each `#…######` opens a fold to the next equal-or-higher heading) |
| HTML, XML | brace-fallback — works for many JS-style embedded blocks but not for tag nesting |

When you fold a region, the glyphs inside it are hidden via a custom
`NSLayoutManager` delegate (`.null` glyph property). The text is **not**
deleted from the buffer — it's still there, takes part in find/replace,
and reappears when you unfold.

### Limitations

This is the most experimental feature in v5. Things to know:

- **No gutter triangles yet.** Toggling a fold is menu-driven (or the
  shortcut above). A clickable triangle in the line-number ruler is on
  the v6 list.
- **No "fold placeholder" line.** When code is hidden, you don't see a
  `[…]` marker — the lines just disappear. The cursor can still be
  positioned inside the hidden range, which is occasionally confusing.
- **Edits inside a folded range don't refresh fold detection.** Use
  Unfold All and Fold All after major restructuring.
- **String and comment heuristics are simple.** Braces inside string
  interpolation (`"\(foo)"` in Swift, template literals in JS) or weird
  preprocessor branches in C can confuse the matcher. Run *Unfold All* if
  things look wrong.

Folding is most reliable for clean, idiomatic source code in the C-family
languages.
