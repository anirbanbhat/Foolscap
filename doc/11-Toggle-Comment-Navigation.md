# Toggle Comment + Cursor Navigation

## Toggle line comment (⌘/)

Select one or more lines and press **⌘/** to comment them in or out using
the active language's line-comment marker.

- The marker is inserted at the **common indentation column** of the selection
  (the smallest leading-whitespace prefix among non-empty lines), so a block
  of indented code stays neatly aligned.
- A second press **uncomments** when *every* non-empty line in the selection
  is already commented at that column. Otherwise it comments everything.
- Pure-whitespace lines are skipped — they're neither commented nor counted.
- Works on a single-line selection too: just put the caret anywhere on the
  line and hit ⌘/.

### Language coverage

| Languages | Marker |
|---|---|
| Swift, JavaScript/TypeScript, C, C++, Go, Rust, Java, CSS | `//` |
| Python, Shell, YAML | `#` |
| Markdown, JSON, XML, HTML, Plain Text | (no marker — ⌘/ beeps) |

JSON and XML deliberately have no toggle even though they technically support
comment forms — the ⌘/ flow assumes a single-line marker.

## Cursor history

Foolscap tracks where you've been editing. Every "distant" selection move
(further than ~25 characters from the previous one) pushes the previous
location onto a back stack.

| Action | Shortcut |
|---|---|
| Navigate back to previous edit location | ⌃⌥− |
| Navigate forward | ⌃⌥= |

- The back stack holds up to 200 entries per editor.
- A new edit / jump invalidates the forward stack — same model as a browser.
- Each editor (and each pane in a split) has its own independent history.

### What counts as "distant enough" to record

Two adjacent keystrokes typing on the same line don't pollute the history.
Two selection changes more than ~25 characters apart do. The threshold is
the smallest value that keeps the history useful without recording every
arrow-key press.
