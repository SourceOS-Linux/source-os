#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

export XDG_CONFIG_HOME="$TMPDIR/config"

"$ROOT/build/office-suite/scripts/install_office_mime_defaults.sh" >/dev/null

TARGET="$XDG_CONFIG_HOME/mimeapps.list"
[[ -f "$TARGET" ]] || {
  echo "mime defaults install smoke failed: missing mimeapps.list" >&2
  exit 1
}

grep -q "application/vnd.oasis.opendocument.text=libreoffice-writer.desktop" "$TARGET" || {
  echo "mime defaults install smoke failed: missing writer association" >&2
  exit 1
}

echo "mime defaults install smoke passed"
