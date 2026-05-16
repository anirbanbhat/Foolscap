# Snippets and Themes

## Snippets — tab-triggered expansions

Type a snippet's trigger word, then press **Tab**. Foolscap replaces the
trigger with the snippet's expanded body and positions the selection on the
first tab stop's placeholder.

Example (Swift): type `func`, press Tab →

```swift
func name(args) -> ReturnType {
    
}
```

with `name` selected, ready to be typed over.

### Built-in snippets by language

| Language | Triggers |
|---|---|
| Swift | `func`, `class`, `struct`, `enum`, `if`, `guard`, `for`, `print` |
| Python | `def`, `class`, `if`, `for`, `try`, `main` |
| JavaScript / TypeScript | `function`, `class`, `if`, `for`, `arrow`, `log` |
| Java | `psvm`, `sout`, `class`, `if`, `for`, `try` |
| Go | `func`, `if`, `for`, `main` |
| Rust | `fn`, `if`, `match`, `impl` |
| C / C++ | `main`, `if`, `for`, `class` (C++ only) |
| Shell | `if`, `for`, `fn` |

When the word before the caret matches a registered trigger, Tab expands the
snippet. When it doesn't, Tab does the usual indent insertion.

### Snippet body syntax

Snippets use TextMate-style placeholders:

| Form | Meaning |
|---|---|
| `${1:default}` | First tab stop with default text "default". When the snippet expands, the selection is placed over this text so you can type to replace it. |
| `${2}` | Tab stop with no default — gives a zero-length selection at that point. |
| `$0` | Conceptually "final cursor location", currently treated as just text. |
| `\n` | Literal newline (Swift string escape in the registry). |

Multi-stop navigation (Tab to advance between stops) is not yet implemented
— v5 only honours the lowest-numbered stop. Higher-numbered stops are still
expanded inline at their default text.

## Themes

**Theme** in the menu bar (between Syntax and Window) lets you switch the
syntax-highlighter palette. Available themes:

| ID | Name | Background |
|---|---|---|
| `system` | System Default | follows light/dark |
| `solarized-light` | Solarized Light | cream |
| `solarized-dark` | Solarized Dark | dark teal |
| `one-dark` | One Dark | charcoal |
| `monokai` | Monokai | warm black |

The choice is **persisted across launches** via `UserDefaults`. Pick once,
have it stick.

All open editors re-highlight when the theme changes — the highlighter rule
cache is invalidated and the colours regenerate from the new palette.

### Caveats

- Themes only colour syntax — they do not change the chrome of the window,
  the gutter, the status bar, or the workspace sidebar. macOS handles
  light/dark there based on the system Appearance setting.
- Per-editor or per-language overrides are not supported in v5; the theme
  is global.
