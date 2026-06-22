#!/usr/bin/env bash
set -euo pipefail

# Apply a mac-like GNOME defaults pack for workstation-v0.
# Safe to run repeatedly.
# Scope intentionally focuses on behavior and shell ergonomics, not deep theming.

info(){ printf "INFO: %s\n" "$*" >&2; }
warn(){ printf "WARN: %s\n" "$*" >&2; }

have(){ command -v "$1" >/dev/null 2>&1; }

is_gnome(){
  [[ "${XDG_CURRENT_DESKTOP:-}" == *GNOME* ]] && return 0
  [[ "${DESKTOP_SESSION:-}" == *gnome* ]] && return 0
  return 1
}

set_key(){
  local schema=$1; shift
  local key=$1; shift
  gsettings set "$schema" "$key" "$*" >/dev/null || true
}

set_custom_binding(){
  local slot=$1
  local name=$2
  local command=$3
  local binding=$4
  local base="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/"
  local path="${base}${slot}/"

  gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:${path} name "$name" || true
  gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:${path} command "$command" || true
  gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:${path} binding "$binding" || true
}

main(){
  if ! have gsettings; then
    warn "gsettings not found; skipping mac defaults pack"
    exit 0
  fi

  if ! is_gnome; then
    warn "GNOME not detected; skipping mac defaults pack"
    exit 0
  fi

  info "Applying mac-like GNOME defaults pack"

  # Interface / shell behavior
  set_key org.gnome.desktop.interface enable-hot-corners false
  set_key org.gnome.desktop.interface show-battery-percentage true
  set_key org.gnome.desktop.interface clock-show-weekday true
  set_key org.gnome.desktop.interface clock-show-date true
  set_key org.gnome.desktop.interface clock-format '12h'
  set_key org.gnome.desktop.interface locate-pointer true
  set_key org.gnome.desktop.sound event-sounds false
  set_key org.gnome.desktop.sound input-feedback-sounds false

  # Files / Finder-like behavior
  set_key org.gnome.nautilus.preferences click-policy 'double'
  set_key org.gnome.nautilus.preferences show-delete-permanently true

  # Screenshots
  mkdir -p "$HOME/Pictures/Screenshots"

  # Favorites / dock seed (best-effort)
  set_key org.gnome.shell favorite-apps "['org.gnome.Nautilus.desktop', 'org.gnome.Terminal.desktop', 'bearbrowser.desktop', 'org.gnome.Settings.desktop']"

  # Preserve palette hotkey in custom0, then add Finder/Terminal/screenshot bindings.
  local base="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/"
  local custom0="${base}custom0/"
  local custom1="${base}custom1/"
  local custom2="${base}custom2/"
  local custom3="${base}custom3/"
  local custom4="${base}custom4/"
  local custom5="${base}custom5/"
  local custom6="${base}custom6/"
  gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings "['${custom0}', '${custom1}', '${custom2}', '${custom3}', '${custom4}', '${custom5}', '${custom6}']" || true

  set_custom_binding custom1 "SourceOS Files" "nautilus --new-window" "<Super>e"
  set_custom_binding custom2 "SourceOS Terminal" "gnome-terminal" "<Super>Return"
  set_custom_binding custom3 "SourceOS Screenshot Screen" "mac-screenshot.sh screen" "<Super><Shift>3"
  set_custom_binding custom4 "SourceOS Screenshot Area" "mac-screenshot.sh area" "<Super><Shift>4"
  set_custom_binding custom5 "SourceOS Screenshot Interactive" "mac-screenshot.sh interactive" "<Super><Shift>5"
  set_custom_binding custom6 "SourceOS Screenshots Folder" "mac-screenshot.sh open-dir" "<Super><Shift>6"

  info "Mac-like GNOME defaults pack applied"
}

main "$@"
