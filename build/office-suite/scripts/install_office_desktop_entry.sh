#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
DESKTOP_SRC="$ROOT/build/office-suite/desktop/sourceos-office.desktop"
BIN_SRC="$ROOT/build/office-suite/scripts/office_open.sh"
CLOUD_SRC="$ROOT/build/office-suite/scripts/office_cloud_handoff.sh"
SEARCH_SRC="$ROOT/build/office-suite/scripts/office_search_handoff.sh"
SEARCH_OPEN_SRC="$ROOT/build/office-suite/scripts/office_search_open.sh"
APP_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
BIN_DIR="$HOME/.local/bin"

mkdir -p "$APP_DIR" "$BIN_DIR"
cp "$DESKTOP_SRC" "$APP_DIR/sourceos-office.desktop"
cp "$BIN_SRC" "$BIN_DIR/sourceos-office-open"
cp "$CLOUD_SRC" "$BIN_DIR/office_cloud_handoff.sh"
cp "$SEARCH_SRC" "$BIN_DIR/office_search_handoff.sh"
cp "$SEARCH_OPEN_SRC" "$BIN_DIR/office_search_open.sh"
chmod +x "$BIN_DIR/sourceos-office-open" "$BIN_DIR/office_cloud_handoff.sh" "$BIN_DIR/office_search_handoff.sh" "$BIN_DIR/office_search_open.sh"

"$ROOT/build/office-suite/scripts/install_office_mime_defaults.sh" >/dev/null

echo "installed desktop entry to $APP_DIR/sourceos-office.desktop"
echo "installed launcher helper to $BIN_DIR/sourceos-office-open"
echo "installed cloud handoff helper to $BIN_DIR/office_cloud_handoff.sh"
echo "installed search helpers to $BIN_DIR"
echo "installed office MIME defaults"
