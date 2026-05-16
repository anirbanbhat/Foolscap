# Tab Management + Wrap Guide

## Pin a tab

In a workspace window, **Window ▸ Pin / Unpin Tab** flips the pinned state of
the front tab.

- Pinned tabs are marked with `●` in front of the filename and always sort
  to the **left** of unpinned tabs.
- Pinning preserves the visible order otherwise — pin two tabs and they keep
  the same relative order, now in front of everything else.
- Unpinning sends the tab back to the unpinned zone, also keeping relative
  order.

## Reorder tabs

| Action | Shortcut |
|---|---|
| Move active tab left | ⌃⇧[ |
| Move active tab right | ⌃⇧] |

- A pinned tab can't move past the pinned/unpinned boundary — Foolscap
  beeps if you try.
- Similarly, an unpinned tab can't slip in front of a pinned one.

Drag-to-reorder via the mouse is not currently implemented — that requires a
custom tab strip and is on the future-features list.

## Wrap guide

A faint vertical line at a configurable column, drawn through the editor's
text area. Useful for keeping code under a 80- or 100-column rule.

| Action | Where |
|---|---|
| Toggle guide at column 80 (default) | View ▸ Wrap Guide at Column 80 |
| Set the column number explicitly | View ▸ Set Wrap Guide Column… |

The column is per-editor — split panes can each have their own setting (or
none).

Currently the column setting is not persisted across launches; it resets to
"off" on each restart. A persistent preference is on the list for v6.
