#!/usr/bin/env bash
set -euo pipefail

# Installs the SourceOS workstation CLI into user scope.
# Target: ~/.local/bin/sourceos

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BIN_SRC="$ROOT_DIR/workstation/bin/sourceos"
DEST_DIR="${HOME}/.local/bin"
DEST_BIN="$DEST_DIR/sourceos"

info(){ printf "INFO: %s\n" "$*" >&2; }
err(){ printf "ERROR: %s\n" "$*" >&2; }

main(){
  if [[ ! -x "$BIN_SRC" ]]; then
    err "sourceos CLI not found or not executable: $BIN_SRC"
    exit 2
  fi

  mkdir -p "$DEST_DIR"
  cp -f "$BIN_SRC" "$DEST_BIN"
  chmod +x "$DEST_BIN"

  info "installed: $DEST_BIN"

  if [[ ":$PATH:" != *":$DEST_DIR:"* ]]; then
    info "NOTE: ~/.local/bin is not on PATH. Add one line to your shell rc:"
    info "  export PATH=\"$DEST_DIR:\$PATH\""
  fi
}

main "$@"
