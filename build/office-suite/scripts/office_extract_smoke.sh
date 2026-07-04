#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
TEMPLATE="$ROOT/build/office-suite/templates/sovereign/sourceos-default-writer.fodt"
EXTRACTOR="$ROOT/build/office-suite/scripts/extract_office_semantic_units.sh"

if [[ ! -f "$TEMPLATE" ]]; then
  echo "missing template: $TEMPLATE" >&2
  exit 1
fi

if [[ ! -x "$EXTRACTOR" ]]; then
  chmod +x "$EXTRACTOR" 2>/dev/null || true
fi

if ! command -v soffice >/dev/null 2>&1; then
  echo "soffice not found; skipping extraction smoke" >&2
  exit 0
fi

OUT="$($EXTRACTOR "$TEMPLATE")"
[[ "$OUT" == *"SourceOS sovereign writer template placeholder."* ]] || {
  echo "extraction smoke failed" >&2
  exit 1
}

echo "office extraction smoke passed"
