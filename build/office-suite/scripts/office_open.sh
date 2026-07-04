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

MODE="${SOURCEOS_OFFICE_MODE:-local}"

case "$MODE" in
  cloud)
    "$(dirname "$0")/office_cloud_handoff.sh" "$INPUT"
    ;;
  local|sovereign|interoperability|migration)
    if ! command -v soffice >/dev/null 2>&1; then
      echo "soffice not found" >&2
      exit 1
    fi
    soffice "$INPUT" >/dev/null 2>&1 || true
    echo "$INPUT"
    ;;
  *)
    echo "unknown SOURCEOS_OFFICE_MODE: $MODE" >&2
    exit 2
    ;;
esac
