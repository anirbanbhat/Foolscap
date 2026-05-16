#!/usr/bin/env bash
# Print the next minor version tag based on the highest existing v*.*.* tag.
# Examples:
#   no tags         → v0.1.0
#   v0.1.0 latest   → v0.2.0
#   v1.4.7 latest   → v1.5.0
#
# Used by .github/workflows/release.yml.
set -euo pipefail

LATEST="$(git tag --list 'v*.*.*' --sort=-v:refname | head -1 || true)"

if [ -z "$LATEST" ]; then
    echo "v0.1.0"
    exit 0
fi

STRIPPED="${LATEST#v}"
IFS='.' read -r MAJOR MINOR _PATCH <<<"$STRIPPED"

if ! [[ "$MAJOR" =~ ^[0-9]+$ && "$MINOR" =~ ^[0-9]+$ ]]; then
    echo "next-minor.sh: cannot parse '$LATEST' as semver" >&2
    exit 1
fi

echo "v${MAJOR}.$((MINOR + 1)).0"
