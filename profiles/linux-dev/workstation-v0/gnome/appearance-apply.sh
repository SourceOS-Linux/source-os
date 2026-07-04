#!/usr/bin/env bash
set -euo pipefail

# Apply bounded GNOME appearance defaults for workstation-v0.
# This intentionally avoids replacing GNOME Shell, libadwaita, or requiring
# proprietary fonts/themes. It only applies stable GNOME interface settings.

info(){ printf "INFO: %s\n" "$*" >&2; }
warn(){ printf "WARN: %s\n" "$*" >&2; }

have(){ command -v "$1" >/dev/null 2>&1; }

is_gnome(){
  [[ "${XDG_CURRENT_DESKTOP:-}" == *GNOME* ]] && return 0
  [[ "${DESKTOP_SESSION:-}" == *gnome* ]] && return 0
  return 1
}

set_if_writable(){
  local schema=$1
  local key=$2
  shift 2
  if ! have gsettings; then
    return 0
  fi
  if gsettings writable "$schema" "$key" >/dev/null 2>&1; then
    gsettings set "$schema" "$key" "$@" >/dev/null || true
    info "set: $schema $key"
  else
    warn "not writable or missing: $schema $key"
  fi
}

main(){
  if ! have gsettings; then
    warn "gsettings not found; skipping appearance defaults"
    exit 0
  fi

  if ! is_gnome; then
    warn "GNOME not detected; skipping appearance defaults"
    exit 0
  fi

  local color_scheme="${SOURCEOS_GNOME_COLOR_SCHEME:-default}"
  case "$color_scheme" in
    default|prefer-dark|prefer-light) ;;
    *)
      warn "invalid SOURCEOS_GNOME_COLOR_SCHEME=$color_scheme; using default"
      color_scheme="default"
      ;;
  esac

  info "Applying bounded GNOME appearance defaults"

  set_if_writable org.gnome.desktop.interface color-scheme "'$color_scheme'"
  set_if_writable org.gnome.desktop.interface cursor-size 24
  set_if_writable org.gnome.desktop.interface text-scaling-factor 1.0
  set_if_writable org.gnome.desktop.interface gtk-enable-primary-paste false
  set_if_writable org.gnome.desktop.interface overlay-scrolling true
  set_if_writable org.gnome.desktop.interface font-antialiasing "'grayscale'"
  set_if_writable org.gnome.desktop.interface font-hinting "'slight'"
  set_if_writable org.gnome.desktop.wm.preferences titlebar-font "'Cantarell Bold 11'"

  info "GNOME appearance defaults applied"
}

main "$@"
