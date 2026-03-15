#!/usr/bin/env bash
# Set Firebase secret GEMINI_API_KEY from environment variable.
# Usage:
#   export GEMINI_API_KEY="your-api-key"
#   ./scripts/set-gemini-secret.sh
# Or from .env:
#   set -a; source .env; set +a; ./scripts/set-gemini-secret.sh

set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT_DIR"

if [[ -z "${GEMINI_API_KEY:-}" ]]; then
  echo "Error: GEMINI_API_KEY is not set."
  echo "Export it or source a .env file, then run this script again."
  echo "Example: export GEMINI_API_KEY=\"your-key-here\""
  exit 1
fi

echo -n "$GEMINI_API_KEY" | firebase functions:secrets:set GEMINI_API_KEY --data-file=-
echo "GEMINI_API_KEY secret set successfully."
