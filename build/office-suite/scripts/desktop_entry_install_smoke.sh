#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

export XDG_DATA_HOME="$TMPDIR/share"
export XDG_CONFIG_HOME="$TMPDIR/config"
export HOME="$TMPDIR/home"
mkdir -p "$HOME"

"$ROOT/build/office-suite/scripts/install_office_desktop_entry.sh" >/dev/null

DESKTOP_FILE="$XDG_DATA_HOME/applications/sourceos-office.desktop"
BIN_FILE="$HOME/.local/bin/sourceos-office-open"
CLOUD_FILE="$HOME/.local/bin/office_cloud_handoff.sh"
SEARCH_FILE="$HOME/.local/bin/office_search_handoff.sh"
SEARCH_OPEN_FILE="$HOME/.local/bin/office_search_open.sh"
MIME_FILE="$XDG_CONFIG_HOME/mimeapps.list"

[[ -f "$DESKTOP_FILE" ]] || {
  echo "desktop entry install smoke failed: missing desktop file" >&2
  exit 1
}

[[ -x "$BIN_FILE" ]] || {
  echo "desktop entry install smoke failed: missing launcher helper" >&2
  exit 1
}

[[ -x "$CLOUD_FILE" ]] || {
  echo "desktop entry install smoke failed: missing cloud handoff helper" >&2
  exit 1
}

[[ -x "$SEARCH_FILE" ]] || {
  echo "desktop entry install smoke failed: missing search handoff helper" >&2
  exit 1
}

[[ -x "$SEARCH_OPEN_FILE" ]] || {
  echo "desktop entry install smoke failed: missing search open helper" >&2
  exit 1
}

[[ -f "$MIME_FILE" ]] || {
  echo "desktop entry install smoke failed: missing MIME defaults" >&2
  exit 1
}

grep -q "application/vnd.oasis.opendocument.text=libreoffice-writer.desktop" "$MIME_FILE" || {
  echo "desktop entry install smoke failed: missing writer MIME association" >&2
  exit 1
}

grep -q "sourceos-office-open" "$DESKTOP_FILE" || {
  echo "desktop entry install smoke failed: desktop entry does not reference launcher helper" >&2
  exit 1
}

echo "desktop entry install smoke passed"
