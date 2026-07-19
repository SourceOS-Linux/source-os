#!/usr/bin/env bash
set -euo pipefail

# Lightweight GNOME extension/dock status helper for workstation-v0.
# Emits key=value lines so doctor/status/CI can reason about the dock and
# extension lane without broad GNOME rewrites.
# Safe to run outside a GNOME session; degrades gracefully to "unknown".

have(){ command -v "$1" >/dev/null 2>&1; }

is_gnome(){
  [[ "${XDG_CURRENT_DESKTOP:-}" == *GNOME* ]] && return 0
  [[ "${DESKTOP_SESSION:-}" == *gnome* ]] && return 0
  return 1
}

# Returns: enabled | present | missing | unknown
ext_status(){
  local uuid=$1
  if ! have gnome-extensions; then
    printf 'unknown\n'
    return
  fi
  if gnome-extensions list --enabled 2>/dev/null | grep -qx "$uuid"; then
    printf 'enabled\n'
    return
  fi
  if gnome-extensions list 2>/dev/null | grep -qx "$uuid"; then
    printf 'present\n'
    return
  fi
  printf 'missing\n'
}

gsetting_get(){
  local schema=$1 key=$2
  if have gsettings; then
    gsettings get "$schema" "$key" 2>/dev/null || printf 'unknown\n'
  else
    printf 'unknown\n'
  fi
}

main(){
  if is_gnome; then
    printf 'gnome_detected=yes\n'
  else
    printf 'gnome_detected=no\n'
  fi

  if have gnome-extensions; then
    printf 'gnome_extensions_cli=present\n'
  else
    printf 'gnome_extensions_cli=missing\n'
  fi

  if have gsettings; then
    printf 'gsettings=present\n'
  else
    printf 'gsettings=missing\n'
  fi

  printf 'dash_to_dock=%s\n'  "$(ext_status 'dash-to-dock@micxgx.gmail.com')"
  printf 'appindicator=%s\n'  "$(ext_status 'appindicatorsupport@rgcjonas.gmail.com')"

  printf 'favorite_apps=%s\n'     "$(gsetting_get org.gnome.shell favorite-apps)"
  printf 'dock_position=%s\n'     "$(gsetting_get org.gnome.shell.extensions.dash-to-dock dock-position)"
  printf 'dock_autohide=%s\n'     "$(gsetting_get org.gnome.shell.extensions.dash-to-dock autohide)"
  printf 'dock_intellihide=%s\n'  "$(gsetting_get org.gnome.shell.extensions.dash-to-dock intellihide)"
}

main "$@"
