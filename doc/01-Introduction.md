# Welcome to Foolscap

Foolscap is a native macOS text and code editor in the spirit of Notepad++. It
is built with AppKit and Swift — no Electron, no webview, no JavaScript. It
opens fast, feels native, and stays out of your way.

## What it does well

- **Plain text and code editing** for files of any extension
- **Syntax highlighting** for 15 languages out of the box
- **Tabbed editing** using native macOS window tabs, plus an in-window tabbed
  workspace mode when you open a folder
- **Find / Find in Files** — single buffer or recursive across a workspace
- **Line numbers, indent guides, invisible-character display**
- **Bracket matching**, occurrence highlighting, and a change-history gutter
- **Standard macOS behaviours** — autosave-in-place, document recovery, encoding
  detection, native macOS Find bar

## What it is *not*

- Not an IDE. There's no language server, no debugger, no build integration.
- Not a plugin host. Customisation lives in the source tree.
- Not a Markdown previewer or word processor.

## Two editing modes

| Mode | When to use | How to start |
|---|---|---|
| **Single-file tabbed** | One-off edits, jumping between unrelated files | File ▸ Open (⌘O), File ▸ New (⌘N) |
| **Workspace** | Working inside a project folder | File ▸ Open Folder (⇧⌘O) |

The same editor features (highlighting, line numbers, find, etc.) work in both
modes. The workspace mode adds a file-tree sidebar and **Find in Workspace**.

Read the other pages in this guide to learn the keyboard shortcuts, supported
languages, and the workspace + Find-in-Files flow.
