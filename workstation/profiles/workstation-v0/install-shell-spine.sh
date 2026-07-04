#!/usr/bin/env bash
set -euo pipefail

PROFILE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$PROFILE_DIR/../.." && pwd)"
SRC_DIR="$PROFILE_DIR/config"
DST_BASE="${XDG_CONFIG_HOME:-$HOME/.config}/sourceos"

info(){ printf "INFO: %s\n" "$*" >&2; }
err(){ printf "ERROR: %s\n" "$*\n" >&2; }

copy_spine() {
  mkdir -p "$DST_BASE/shell"
  cp -f "$SRC_DIR/shell/common.sh" "$DST_BASE/shell/common.sh"
  cp -f "$SRC_DIR/shell/zshrc.snippet" "$DST_BASE/shell/zshrc.snippet"
  cp -f "$SRC_DIR/shell/bashrc.snippet" "$DST_BASE/shell/bashrc.snippet"
  chmod 0644 "$DST_BASE/shell/"*.sh "$DST_BASE/shell/"*.snippet || true
}

print_instructions() {
  cat <<EOF

SourceOS shell spine installed to:
  $DST_BASE/shell/

Enable it by sourcing one line in your shell rc:

  # Zsh: add to ~/.zshrc
  source $DST_BASE/shell/zshrc.snippet

  # Bash: add to ~/.bashrc
  . $DST_BASE/shell/bashrc.snippet

This installer does NOT auto-edit rc files in v0.
EOF
}

main(){
  copy_spine
  print_instructions
}

main "$@"
