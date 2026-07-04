#!/usr/bin/env bash
set -euo pipefail

# Apply minimal GNOME baseline settings for workstation-v0.
# Safe to run repeatedly.

info(){ printf "INFO: %s\n" "$*" >&2; }
warn(){ printf "WARN: %s\n" "$*" >&2; }

have(){ command -v "$1" >/dev/null 2>&1; }

is_gnome(){
  # Best-effort detection.
  if [[ "${XDG_CURRENT_DESKTOP:-}" == *GNOME* ]]; then
    return 0
  fi
  if [[ "${DESKTOP_SESSION:-}" == *gnome* ]]; then
    return 0
  fi
  return 1
}

set_if(){
  # set_if <schema> <key> <value...>
  local schema=$1; shift
  local key=$1; shift
  local value=("$@")
  gsettings set "$schema" "$key" "${value[*]}" >/dev/null
}

main(){
  if ! have gsettings; then
    warn "gsettings not found; skipping GNOME baseline"
    exit 0
  fi

  if ! is_gnome; then
    warn "GNOME not detected (XDG_CURRENT_DESKTOP=${XDG_CURRENT_DESKTOP:-unset}); skipping"
    exit 0
  fi

  info "Applying GNOME baseline settings"

  # Window buttons (mac-like: left)
  set_if org.gnome.desktop.wm.preferences button-layout "close,minimize,maximize:"

  # Touchpad
  set_if org.gnome.desktop.peripherals.touchpad tap-to-click true
  set_if org.gnome.desktop.peripherals.touchpad natural-scroll true

  # UI indicators
  set_if org.gnome.desktop.interface show-battery-percentage true
  set_if org.gnome.desktop.interface clock-show-weekday true

  # Workspaces
  set_if org.gnome.mutter dynamic-workspaces true

  info "GNOME baseline applied"
}

main "$@"
