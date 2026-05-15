#!/usr/bin/env bash
# Build Foolscap.app from Swift sources without an Xcode project.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="foolscap"
APP_DIR="$ROOT/build/$APP_NAME.app"
MACOS_DIR="$APP_DIR/Contents/MacOS"
RES_DIR="$APP_DIR/Contents/Resources"
BIN="$MACOS_DIR/$APP_NAME"

echo ">> Cleaning build dir"
rm -rf "$ROOT/build"
mkdir -p "$MACOS_DIR" "$RES_DIR"

echo ">> Copying Info.plist"
cp "$ROOT/Info.plist" "$APP_DIR/Contents/Info.plist"

if [ -d "$ROOT/doc" ]; then
    echo ">> Copying documentation"
    cp -R "$ROOT/doc" "$RES_DIR/doc"
fi

# Gather all .swift sources (portable; macOS ships bash 3.2 without mapfile)
SOURCES=()
while IFS= read -r f; do
    SOURCES+=("$f")
done < <(find "$ROOT/Sources" -name '*.swift' | sort)
echo ">> Compiling ${#SOURCES[@]} Swift source files"

# Module name is "foolscap" — referenced from Info.plist NSDocumentClass = foolscap.Document
xcrun swiftc \
  -module-name "$APP_NAME" \
  -O \
  -framework AppKit \
  -framework Foundation \
  -o "$BIN" \
  "${SOURCES[@]}"

echo ">> Ad-hoc signing"
codesign --force --deep --sign - "$APP_DIR"

echo ">> Done: $APP_DIR"
