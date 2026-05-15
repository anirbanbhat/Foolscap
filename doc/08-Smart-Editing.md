# Smart Editing

## Auto-close brackets and quotes

Type any of `(`, `[`, `{`, `"`, `'`, `` ` `` and Foolscap inserts the matching
closer, leaving the caret between them.

- **Wrap selection** — if you have text selected and type an opener, the
  selection is wrapped instead of replaced (`foo` → `(foo)`).
- **Skip over** — if your caret is right before a closer that's already
  there, retyping that closer just moves the caret forward instead of
  inserting another one.
- **Pair-aware backspace** — deleting an opener when the cursor sits right
  after it (and an empty closer is right next) also deletes the closer.
- **Inside-word smart-quote suppression** — quotes are not auto-paired when
  the caret is in the middle of a word (so contractions like `don't` are not
  ruined).

Disable via **View ▸ Auto-Close Brackets**.

## Word autocomplete from buffer

Press **⌥ESC** to trigger word completion. Foolscap scans the current buffer
for identifier-shaped tokens (letters, digits, underscore — minimum length 2)
and shows the matches that start with the prefix at your caret.

- Results are ranked by **frequency in the buffer** first, then alphabetical.
- The word you're currently typing isn't suggested as a completion of itself.
- This is buffer-local — there's no language server, no cross-file index, no
  type-aware filtering.

This is intentional: it's a fast macro-like recall for symbols you've already
typed, not a smart code-completion engine. Use it for matching function
names, variable names, and string keys.

## Mark all matches

Select a word and choose **Edit ▸ Mark ▸ Mark All Occurrences of Selection**
(⇧⌘M). Foolscap finds every occurrence of that exact string in the buffer
and draws a small purple stripe in the gutter for each line that contains it.

- The marks persist as you edit — they're recomputed automatically whenever
  the text changes.
- Use **Edit ▸ Mark ▸ Clear All Marks** to remove them.
- This is separate from selection-occurrence highlighting (the yellow glow on
  every other match while you have a selection active). Marks survive
  collapsing the selection.

Notepad++ has five mark "styles" (Mark 1–5). Foolscap has one — if you want
more, ask.

## Combinations

- **⇧⌘M then ⌘P** — mark every occurrence of a symbol, then jump to a
  different file to compare.
- **⌘R then ⇧⌘M** — jump to a function definition, then highlight every call
  site in the file's gutter.
