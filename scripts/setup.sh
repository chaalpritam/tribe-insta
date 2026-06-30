#!/usr/bin/env bash
# Ensure tribe-core-swift exists at tribe-insta/tribe-core-swift before opening Xcode.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [[ -f tribe-core-swift/Package.swift ]]; then
  echo "setup: tribe-core-swift already present"
  exit 0
fi

if [[ -f ../tribe-core-swift/Package.swift ]]; then
  /bin/ln -sfn ../tribe-core-swift tribe-core-swift
  echo "setup: linked tribe-core-swift -> ../tribe-core-swift (monorepo)"
  exit 0
fi

echo "setup: tribe-core-swift missing. From tribe-insta/, run one of:" >&2
echo "  git submodule update --init tribe-core-swift" >&2
echo "  git clone https://github.com/chaalpritam/tribe-core-swift.git tribe-core-swift" >&2
exit 1
