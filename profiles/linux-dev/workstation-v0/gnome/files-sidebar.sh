#!/usr/bin/env bash
set -euo pipefail

# Seed GTK/Nautilus sidebar bookmarks for a Finder-like baseline.
# Safe to run repeatedly.

info(){ printf "INFO: %s\n" "$*" >&2; }

bookmarks_file(){
  printf '%s/gtk-3.0/bookmarks\n' "${XDG_CONFIG_HOME:-$HOME/.config}"
}

uri_for(){
  local path=$1
  python3 - "$path" <<'PY'
import pathlib, sys
print(pathlib.Path(sys.argv[1]).expanduser().resolve().as_uri())
PY
}

ensure_bookmark(){
  local path=$1
  local label=$2
  local f uri line
  f="$(bookmarks_file)"
  uri="$(uri_for "$path")"
  line="$uri $label"
  mkdir -p "$(dirname "$f")"
  touch "$f"
  if ! grep -Fqx "$line" "$f"; then
    printf '%s\n' "$line" >> "$f"
    info "bookmark: $label -> $path"
  fi
}

main(){
  mkdir -p "$HOME/Desktop" "$HOME/Documents" "$HOME/Downloads" "$HOME/Pictures" "$HOME/Pictures/Screenshots" "$HOME/Music" "$HOME/Videos" "$HOME/Public"

  ensure_bookmark "$HOME/Desktop" Desktop
  ensure_bookmark "$HOME/Documents" Documents
  ensure_bookmark "$HOME/Downloads" Downloads
  ensure_bookmark "$HOME/Pictures" Pictures
  ensure_bookmark "$HOME/Pictures/Screenshots" Screenshots
  ensure_bookmark "$HOME/Music" Music
  ensure_bookmark "$HOME/Videos" Videos
  ensure_bookmark "$HOME/Public" Public
}

main "$@"
