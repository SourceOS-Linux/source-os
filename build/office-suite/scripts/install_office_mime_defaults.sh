#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
MIME_SRC="$ROOT/configs/mime/sourceos-office-mimeapps.list"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"

mkdir -p "$CONFIG_DIR"
cp "$MIME_SRC" "$CONFIG_DIR/mimeapps.list"

echo "installed MIME defaults to $CONFIG_DIR/mimeapps.list"
