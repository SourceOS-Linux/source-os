#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
OUT="$($ROOT/build/office-suite/scripts/sourceos-office help)"

[[ "$OUT" == *"usage: sourceos-office"* ]] || {
  echo "sourceos-office smoke failed" >&2
  exit 1
}

echo "sourceos-office smoke passed"
