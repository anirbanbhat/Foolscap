# EditorConfig Support

Foolscap reads `.editorconfig` files when opening a file and applies the
project's per-file conventions automatically. No setup — drop a
`.editorconfig` next to (or above) your code and Foolscap respects it.

## How resolution works

When a file is opened, Foolscap walks up from the file's directory looking
for `.editorconfig` files. Each file found contributes settings; the
**nearest-to-the-file** value wins. Ascent stops when a config has
`root = true` at the top of the file, or when the filesystem root is
reached.

A file's `.editorconfig` settings apply only if the section's glob pattern
matches the file's path relative to the config's directory.

## Supported keys

| Key | Effect |
|---|---|
| `indent_style` | `space` → soft tabs, `tab` → hard tabs |
| `indent_size` | Number of columns per indent level |
| `tab_width` | Used as `indent_size` if `indent_size` isn't set |
| `end_of_line` | `lf` / `crlf` / `cr` — applied on next save |
| `charset` | `utf-8`, `utf-8-bom`, `latin1`, `utf-16be`, `utf-16le` |
| `trim_trailing_whitespace` | `true` strips trailing whitespace on save |
| `insert_final_newline` | `true` appends a newline if the file doesn't end with one |
| `root` | `true` halts the walk-up search at that directory |

Keys Foolscap recognises but currently ignores:

- `max_line_length`
- `spelling_language`
- Any key Foolscap doesn't list above

## Glob syntax

The matcher implements a useful subset of the EditorConfig glob spec:

| Pattern | Meaning |
|---|---|
| `*` | Any chars except `/` |
| `**` | Any chars including `/` |
| `?` | A single char except `/` |
| `[abc]` | One of `a`, `b`, `c` |
| `[!abc]` | Any char except those |
| `{a,b,c}` | Any of the alternatives |

The match is anchored on both sides — `*.swift` does **not** match `foo.swift.bak`.

## Worked example

A typical Swift project at `/repo`:

```
# /repo/.editorconfig
root = true

[*]
indent_style = space
indent_size = 4
end_of_line = lf
charset = utf-8
trim_trailing_whitespace = true
insert_final_newline = true

[*.{md,yml,yaml}]
indent_size = 2

[Makefile]
indent_style = tab
```

Opening `/repo/Sources/Foo.swift` resolves to: 4-space soft tabs, LF, UTF-8,
trim trailing whitespace, insert final newline.

Opening `/repo/README.md` resolves to the same, except `indent_size = 2`.

Opening `/repo/Makefile` resolves to: hard tabs, LF, UTF-8, trim trailing
whitespace, insert final newline.

## Limitations

- Foolscap does not currently watch `.editorconfig` files. To pick up
  edits, close and reopen the affected files.
- There's no per-Document UI showing which `.editorconfig` was applied —
  the language / encoding / EOL pop-ups in the status bar reflect the
  resolved values, but don't say *why*.
- Glob alternation `{a,b,c}` does not support nested classes like `{[a-z],b}`.
