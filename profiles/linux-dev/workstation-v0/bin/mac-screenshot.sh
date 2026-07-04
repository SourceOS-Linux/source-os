#!/usr/bin/env bash
set -euo pipefail

# Mac-style screenshot helper for SourceOS workstation-v0.
# Intended GNOME bindings:
# - Super+Shift+3 -> full screen
# - Super+Shift+4 -> area selection
# - Super+Shift+5 -> interactive screenshot UI

err(){ printf "ERROR: %s\n" "$*" >&2; }
info(){ printf "INFO: %s\n" "$*" >&2; }
have(){ command -v "$1" >/dev/null 2>&1; }

screenshot_dir(){
  printf '%s\n' "${SOURCEOS_SCREENSHOT_DIR:-$HOME/Pictures/Screenshots}"
}

stamp(){ date +%Y-%m-%d-%H%M%S; }

open_dir(){
  local d=$1
  if have xdg-open; then
    xdg-open "$d" >/dev/null 2>&1 || true
  elif have open; then
    open "$d" >/dev/null 2>&1 || true
  fi
}

shot(){
  local mode=$1
  local d out
  d="$(screenshot_dir)"
  mkdir -p "$d"
  out="$d/Screenshot-$(stamp).png"

  if ! have gnome-screenshot; then
    err "gnome-screenshot is not installed"
    exit 127
  fi

  case "$mode" in
    screen)
      gnome-screenshot -f "$out"
      ;;
    area)
      gnome-screenshot -a -f "$out"
      ;;
    window)
      gnome-screenshot -w -f "$out"
      ;;
    interactive)
      gnome-screenshot -i
      exit 0
      ;;
    *)
      err "unknown screenshot mode: $mode (use screen|area|window|interactive|open-dir)"
      exit 2
      ;;
  esac

  info "wrote: $out"
}

main(){
  case "${1:-screen}" in
    screen|area|window|interactive)
      shot "$1"
      ;;
    open-dir)
      mkdir -p "$(screenshot_dir)"
      open_dir "$(screenshot_dir)"
      ;;
    -h|--help|help)
      cat <<'EOF'
Usage: mac-screenshot.sh [screen|area|window|interactive|open-dir]
EOF
      ;;
    *)
      shot "$1"
      ;;
  esac
}

main "$@"
