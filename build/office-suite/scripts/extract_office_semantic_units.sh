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

EXT="${INPUT##*.}"
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

case "$EXT" in
  odt|docx|doc|rtf)
    if ! command -v soffice >/dev/null 2>&1; then
      echo "soffice not found" >&2
      exit 1
    fi
    soffice --headless --convert-to txt:Text --outdir "$TMPDIR" "$INPUT" >/dev/null 2>&1 || {
      echo "LibreOffice extraction failed" >&2
      exit 1
    }
    TXT_OUT="$TMPDIR/$(basename "${INPUT%.*}").txt"
    if [[ ! -f "$TXT_OUT" ]]; then
      echo "missing extracted text output" >&2
      exit 1
    fi
    cat "$TXT_OUT"
    ;;
  txt|md)
    cat "$INPUT"
    ;;
  *)
    echo "unsupported extension for local extraction: $EXT" >&2
    exit 2
    ;;
esac
