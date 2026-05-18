#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_YML="$ROOT/Project.yml"

current="$(grep 'CURRENT_PROJECT_VERSION:' "$PROJECT_YML" | head -1 | sed -E 's/.*"([0-9]+)".*/\1/')"
next=$((current + 1))

sed -i '' -E "s/CURRENT_PROJECT_VERSION: \"[0-9]+\"/CURRENT_PROJECT_VERSION: \"$next\"/" "$PROJECT_YML"

echo "Build number bumped: $current → $next"
echo "Run 'make generate' before archiving."
