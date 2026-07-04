#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "usage: $0 <query>" >&2
  exit 1
fi

QUERY="$1"

if command -v lampstand >/dev/null 2>&1; then
  lampstand query "$QUERY" --limit 10 || true
  exit 0
fi

SOCKET="${XDG_RUNTIME_DIR:-/tmp}/lampstand.sock"
if [[ -S "$SOCKET" ]]; then
  printf '{"method":"query","query":"%s","limit":10}\n' "$QUERY" | socat - UNIX-CONNECT:"$SOCKET" || true
  exit 0
fi

echo "lampstand not available" >&2
exit 2
