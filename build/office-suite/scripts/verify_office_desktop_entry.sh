#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
DESKTOP_FILE="$ROOT/build/office-suite/desktop/sourceos-office.desktop"
INSTALLER="$ROOT/build/office-suite/scripts/install_office_desktop_entry.sh"
MIME_INSTALLER="$ROOT/build/office-suite/scripts/install_office_mime_defaults.sh"

[[ -f "$DESKTOP_FILE" ]] || {
  echo "missing desktop entry source" >&2
  exit 1
}

[[ -x "$INSTALLER" ]] || {
  echo "missing desktop entry installer" >&2
  exit 1
}

[[ -x "$MIME_INSTALLER" ]] || {
  echo "missing MIME defaults installer" >&2
  exit 1
}

grep -q "sourceos-office-open" "$DESKTOP_FILE" || {
  echo "desktop entry does not reference launcher helper" >&2
  exit 1
}

echo "office desktop entry verification passed"
