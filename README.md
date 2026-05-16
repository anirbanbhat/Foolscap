# Foolscap

Native macOS text and code editor in the spirit of Notepad++.
AppKit and Swift — no Electron, no webview, no JavaScript.

Foolscap opens fast, feels native, and stays out of your way. It's built
without an Xcode project (one shell script, one binary) and the entire
source tree is under 7,000 lines.

---

## Install

### From a release (recommended)

1. Go to the **[Releases](../../releases)** page.
2. Download the latest `Foolscap-vX.Y.Z.dmg`.
3. Open the disk image and drag **Foolscap.app** into your **Applications**
   folder.
4. The first time you launch it, macOS may warn that the developer is
   unidentified. Either:
   - Right-click **Foolscap.app** in Applications and choose **Open**, then
     confirm in the dialog, **or**
   - Strip the quarantine flag from the terminal:
     ```sh
     xattr -dr com.apple.quarantine /Applications/Foolscap.app
     ```

The `.dmg` is ad-hoc signed only — it is not notarized through Apple's
Developer Program. That's the source of the Gatekeeper warning and is
expected.

You can verify the download against the `.sha256` file attached to the
release:

```sh
shasum -a 256 Foolscap-vX.Y.Z.dmg
```

### From source

Requirements:

- macOS 13 or later
- Xcode Command Line Tools — install with `xcode-select --install`

```sh
git clone <this-repo-url>
cd Foolscap
./build.sh
open build/foolscap.app
```

`build.sh` compiles every Swift file under `Sources/` into a self-contained,
ad-hoc-signed `Foolscap.app` bundle. No Xcode project, no Swift Package
Manager.

---

## Features

- **Tabbed editing** in two modes
  - *Single-file* — native macOS window tabs
  - *Workspace* — open a folder (⇧⌘O), get a sidebar file tree and in-window tabs
- **Find** in the current buffer (⌘F) and **Find in Workspace** (⇧⌘F) with regex and case-sensitivity options
- **Quick navigation**
  - **Go to File** (⌘P) — fuzzy file picker across the workspace
  - **Go to Symbol** (⌘R) — fuzzy symbol picker in the current buffer
  - **Go to Line** (⌘L)
- **Syntax highlighting** for Swift, Python, JavaScript/TypeScript, JSON, Markdown, HTML, CSS, YAML, XML, shell, C, C++, Go, Rust
- **Smart editing**
  - Auto-close brackets and quotes
  - Word autocomplete from the buffer (⌥ESC)
  - Bracket matching
  - Occurrence highlight on selection
- **Visual aids**
  - Line numbers, indent guides (⇧⌘I), invisible characters (⇧⌘U)
  - Minimap (⌥⌘M) and split editor (⌘\)
  - Change-history stripes in the gutter (orange = unsaved, green = saved-modified)
- **Line operations** — duplicate (⇧⌘D), delete (⇧⌘K), move (⌥↑/↓), sort, trim trailing whitespace
- **Bookmarks** (⌘F2 / F2 / ⇧F2) and **mark all matches** (⇧⌘M)
- **EditorConfig** support — `indent_style`, `indent_size`, `end_of_line`,
  `charset`, `trim_trailing_whitespace`, `insert_final_newline`
- **Encoding & line-ending switchers** in the status bar (UTF-8/16/Latin-1/CP1252/Mac Roman, LF/CRLF/CR)
- **External-change detection** — auto-reload clean buffers, prompt for dirty ones
- **Session restore** — reopen the last set of files and workspaces on launch
- **Case conversion** + Base64 / URL / HTML encode-decode
- **In-app user guide** — Help ▸ Foolscap User Guide (⌘?)

For the full reference, see the **[user guide](doc/)**:

| Page | Topic |
|---|---|
| [01](doc/01-Introduction.md) | Introduction |
| [02](doc/02-Getting-Started.md) | Getting Started |
| [03](doc/03-Keyboard-Shortcuts.md) | Keyboard Shortcuts |
| [04](doc/04-Syntax-Highlighting.md) | Syntax Highlighting |
| [05](doc/05-Workspace-and-Find.md) | Workspaces and Find in Files |
| [06](doc/06-Tips.md) | Tips |
| [07](doc/07-Quick-Navigation.md) | Quick Navigation (⌘P / ⌘R) |
| [08](doc/08-Smart-Editing.md) | Smart Editing |
| [09](doc/09-EditorConfig.md) | EditorConfig Support |
| [10](doc/10-Split-and-Minimap.md) | Split View and Minimap |

---

## Tests

```sh
./test.sh
```

A lightweight CLI test runner (no XCTest dependency) compiles `Sources/`
plus `Tests/` into a single binary and runs the suite. Current coverage:
**216 tests** across string conversions, syntax detection, the Markdown
renderer, Find in Files, fuzzy matching, EditorConfig parsing + glob
matching, the symbol extractor, the file index, indent settings, document
line-ending handling, and the workspace-file load/save round-trip.

UI code (menu construction, NSTextView drawing, ruler, sidebar, tab view)
is not unit-tested — it requires UI automation.

---

## Project layout

```
Sources/                    # Swift sources, compiled as one module
Tests/                      # Test sources + lightweight runner
doc/                        # User-guide Markdown (bundled into the .app)
.github/workflows/release.yml  # Tag-triggered build → .dmg → GitHub release
build.sh                    # Compile sources into Foolscap.app
test.sh                     # Compile + run the test suite
Info.plist                  # Bundle metadata, document types
```

---

## Releasing

The release workflow lives in [`.github/workflows/release.yml`](.github/workflows/release.yml).
It runs on `macos-latest` and triggers on any tag matching `v*`.

To cut a release:

```sh
git tag v0.1.0
git push origin v0.1.0
```

The workflow runs the tests, builds the app, packages it into
`Foolscap-v0.1.0.dmg` with a drag-to-`/Applications` shortcut, generates a
SHA-256 sidecar, and publishes a GitHub release with auto-generated
changelog notes.

You can also trigger the workflow manually from the **Actions** tab —
useful for testing the release pipeline without bumping a tag.

---

## Status

Foolscap is feature-complete enough to use as a daily-driver plain-text /
code editor. It is **not** an IDE — there is no language server, no
debugger, no build integration. It is **not** a Markdown previewer or a
word processor.

Known limitations are documented per-feature in the [user guide](doc/). A
short list:

- Code folding is not implemented
- Split view has a single layout (vertical, two panes)
- No multi-caret editing
- No plugin system
- The .dmg is not notarized

---

## License

TBD.
