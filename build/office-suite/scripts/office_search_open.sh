#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "usage: $0 <query>" >&2
  exit 1
fi

QUERY="$1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

if [[ -x "$SCRIPT_DIR/office_search_handoff.sh" ]]; then
  SEARCH_HELPER="$SCRIPT_DIR/office_search_handoff.sh"
elif [[ -x "$ROOT/build/office-suite/scripts/office_search_handoff.sh" ]]; then
  SEARCH_HELPER="$ROOT/build/office-suite/scripts/office_search_handoff.sh"
else
  echo "office_search_handoff.sh not found" >&2
  exit 1
fi

if [[ -x "$SCRIPT_DIR/sourceos-office-open" ]]; then
  OPEN_HELPER="$SCRIPT_DIR/sourceos-office-open"
elif [[ -x "$SCRIPT_DIR/office_open.sh" ]]; then
  OPEN_HELPER="$SCRIPT_DIR/office_open.sh"
elif [[ -x "$ROOT/build/office-suite/scripts/office_open.sh" ]]; then
  OPEN_HELPER="$ROOT/build/office-suite/scripts/office_open.sh"
else
  echo "office open helper not found" >&2
  exit 1
fi

SEARCH_OUT="$($SEARCH_HELPER "$QUERY" 2>/dev/null || true)"
FIRST_PATH="$(printf '%s\n' "$SEARCH_OUT" | head -n 1)"

if [[ -z "$FIRST_PATH" ]]; then
  echo "no search results" >&2
  exit 3
fi

if [[ ! -f "$FIRST_PATH" ]]; then
  echo "$FIRST_PATH"
  exit 0
fi

"$OPEN_HELPER" "$FIRST_PATH"
