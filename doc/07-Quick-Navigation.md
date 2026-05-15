# Quick Navigation

Foolscap has two fuzzy-filter panels that get you to a file or a symbol
without leaving the keyboard.

## Go to File (⌘P)

In a workspace window, **⌘P** opens a panel listing every file in the
workspace. Type to filter; results re-rank as you type.

- The match is a **subsequence** — typing `vc` matches `ViewController.swift`,
  `usrc` matches `Users/anirb/src/foo.swift`.
- Scoring rewards consecutive matches and matches at word boundaries (slashes,
  underscores, dots, hyphens), so the most-targeted file usually ends up at
  the top.
- ↑ / ↓ move the selection, **Return** opens it, **Esc** dismisses.

The file list uses the same skip rules as Find in Workspace: `.git`,
`node_modules`, `.build`, `DerivedData`, `Pods`, image / archive / binary
extensions, etc.

## Go to Symbol (⌘R)

**⌘R** opens a panel listing the symbols (functions, classes, structs,
headings, …) declared in the **currently focused tab**.

- Each row shows the symbol name, its kind, and the line it lives on.
- **Return** jumps to that line; the editor becomes the focused window.

Supported languages and what counts as a "symbol":

| Language | Extracted |
|---|---|
| Swift | `func`, `class`, `struct`, `enum`, `protocol`, `extension` |
| Python | `def` (sync + async), `class` |
| JavaScript / TypeScript | `function`, `class`, arrow-function consts |
| C / C++ | top-level `func`, `struct`, `class`, `namespace`, `typedef struct` |
| Go | `func` (with or without receiver), `type … struct`, `type … interface` |
| Rust | `fn`, `struct`, `enum`, `trait`, `impl` |
| Shell | `function foo`, `foo() {` |
| Markdown | `# Heading` (every level) |
| CSS | top-level `.class` / `#id` selectors |

Other languages (JSON, YAML, XML, plain text) report no symbols and ⌘R will
beep instead of opening an empty panel.

## Limitations

- The symbol scan is regex-based and language-naive. Identifiers inside
  multi-line comments, conditional preprocessor branches, or string literals
  can occasionally be picked up.
- Symbols inside nested types are listed as top-level entries — there's no
  hierarchical outline.
- The file index is rebuilt on every ⌘P invocation (no background watcher).
  For very large workspaces (>50k files), expect a small delay opening the
  panel.
