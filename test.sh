#!/usr/bin/env bash
# Compile a CLI test binary from Sources/ (excluding main.swift) + Tests/,
# then run it. No XCTest dependency — we have a lightweight runner in
# Tests/TestSupport.swift.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$ROOT/build"
BIN="$BUILD_DIR/foolscap-tests"

mkdir -p "$BUILD_DIR"

# Gather sources, excluding main.swift (we have our own entry in Tests/main_tests.swift).
SOURCES=()
while IFS= read -r f; do
    SOURCES+=("$f")
done < <(find "$ROOT/Sources" -name '*.swift' ! -name 'main.swift' | sort)
while IFS= read -r f; do
    SOURCES+=("$f")
done < <(find "$ROOT/Tests" -name '*.swift' | sort)

echo ">> Compiling ${#SOURCES[@]} files for test binary"

xcrun swiftc \
  -framework AppKit \
  -framework Foundation \
  -o "$BIN" \
  "${SOURCES[@]}"

echo ">> Running tests"
"$BIN"
