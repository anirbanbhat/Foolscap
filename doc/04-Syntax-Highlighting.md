# Syntax Highlighting

Foolscap detects the language from the file extension when you open a file. To
override the detection, pick a language from the **Syntax** menu or from the
language pop-up on the left side of the editor's status bar.

## Built-in languages

| Language | Extensions |
|---|---|
| Swift | `.swift` |
| Python | `.py`, `.pyw` |
| JavaScript / TypeScript | `.js` `.mjs` `.cjs` `.jsx` `.ts` `.tsx` |
| JSON | `.json` |
| Markdown | `.md`, `.markdown` |
| HTML | `.html`, `.htm`, `.xhtml` |
| CSS | `.css`, `.scss`, `.sass`, `.less` |
| YAML | `.yaml`, `.yml` |
| XML | `.xml`, `.plist`, `.svg` |
| Shell | `.sh`, `.bash`, `.zsh`, `.fish`, `.ksh`, `.command` |
| C | `.c`, `.h` |
| C++ | `.cpp`, `.cxx`, `.cc`, `.hpp`, `.hxx`, `.hh` |
| Go | `.go` |
| Rust | `.rs` |
| Java | `.java` |

If the extension doesn't match anything, Foolscap uses **Plain Text** mode and
draws everything in the standard text colour.

## How it works

Highlighting is regex-based. Each language defines a small set of patterns for
keywords, strings, numbers, comments, types, and so on. On each edit the
highlighter re-evaluates the changed region; for languages with multi-line
constructs (block comments, triple-quoted strings, template literals) it
re-evaluates the entire buffer when the file is under 200 KB, and a 100 KB
window around the edit for larger files.

## What it's not

There's no language server integration, no semantic colouring, no parser. The
highlighter knows the shape of source files, not their meaning. Code with
unusual macros, heredocs, or string syntaxes may colour imperfectly.

## Decorations layered on top

In addition to syntax colouring, Foolscap automatically applies:

- **Matching bracket highlight** — when the caret is next to `(`, `[`, or `{`,
  its partner is dimly highlighted.
- **Occurrence highlight** — selecting a word draws a yellow background on
  every other occurrence in the file.
- **Indent guides** — vertical separator lines at every 4-column indent
  boundary (toggle with ⇧⌘I).
- **Change-history stripes** in the gutter — orange for lines modified since
  the last save, green for lines that *were* modified and have since been
  saved.
