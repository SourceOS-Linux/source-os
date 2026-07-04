#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "usage: $0 <office-file>" >&2
  exit 1
fi

INPUT="$1"
if [[ ! -f "$INPUT" ]]; then
  echo "missing input: $INPUT" >&2
  exit 1
fi

BASE_URL="${SOURCEOS_OFFICE_CLOUD_BASE_URL:-http://127.0.0.1:8080}"
ENCODED_PATH="$(python3 - <<'PY' "$INPUT"
import sys, urllib.parse
print(urllib.parse.quote(sys.argv[1]))
PY
)"
TARGET="${BASE_URL}/open?path=${ENCODED_PATH}"

if command -v xdg-open >/dev/null 2>&1; then
  xdg-open "$TARGET" >/dev/null 2>&1 || true
fi

echo "$TARGET"
