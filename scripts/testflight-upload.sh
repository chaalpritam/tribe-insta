#!/usr/bin/env bash
# Upload the IPA from `make archive` to App Store Connect.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
IPA="${1:-$ROOT/build/export/tribe-insta.ipa}"

if [[ ! -f "$IPA" ]]; then
  echo "IPA not found: $IPA" >&2
  echo "Run: DEVELOPMENT_TEAM=XXXXXXXXXX make archive" >&2
  exit 1
fi

xcrun altool --upload-app -f "$IPA" -t ios \
  --apiKey "${APP_STORE_CONNECT_API_KEY:-}" \
  --apiIssuer "${APP_STORE_CONNECT_ISSUER_ID:-}"
