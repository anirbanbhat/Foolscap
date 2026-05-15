# Split View and Minimap

## Split editor

Inside a workspace window, **View ▸ Split Editor** (⌘\\) splits the
current tab into two side-by-side editors of the **same file**. Edits made
in either pane appear instantly in the other — both panes share a single
text buffer.

- The two panes have independent **scroll positions** and **cursors**, so
  you can be looking at the top and bottom of a long file at the same time.
- **⇧⌘\\** closes the split, leaving only the primary pane.
- The split is per-tab — switching to another tab returns to that tab's
  layout. New tabs always start un-split.

### What's shared vs. what's not

| Property | Shared | Per-pane |
|---|---|---|
| Buffer contents | ✓ | — |
| Encoding / EOL / language | ✓ | — |
| Cursor / selection | — | ✓ |
| Scroll position | — | ✓ |
| Font size | — | ✓ |
| Word-wrap state | — | ✓ |
| Bookmarks, mark-all, change history | — | primary pane only |

The "primary pane only" behaviours follow from how the text storage
delegate is wired: only one editor handles storage-level callbacks, so the
gutter markers are bookkeeping kept on that single editor.

### Limitations

- Only one split at a time (two panes total). No three-way splits.
- Splits are always **vertical** (left/right). Horizontal (top/bottom)
  isn't built yet.
- Splits don't apply to standalone (non-workspace) document windows.

## Minimap

**View ▸ Show Minimap** (⌥⌘M) adds a column on the right side of the editor
showing a zoomed-out outline of the buffer. Each text line becomes a short
horizontal stroke whose length is proportional to the line's character
count, and a translucent rectangle marks the currently-visible viewport.

- Click anywhere on the minimap to scroll the editor to that point.
- Drag in the minimap to scrub.
- The minimap toggles per-editor; in a split view, each pane can have its
  minimap on or off independently.

### Why it's a sketch, not a render

Real text rendering at 2 pt produces unreadable blobs and costs more CPU
than the sketch you actually use. Drawing one stroke per line preserves
the *shape* of the file (where the code is dense, where the blank lines
are, where long lines stick out) without any of the cost of glyph
rendering. If you want to identify the section you're navigating to, the
viewport rectangle plus the file's visual signature is usually enough.
