#!/usr/bin/env bash
set -euo pipefail

# Lightweight Mac-polish validation helper for workstation-v0.
# Emits key=value lines so doctor/status can consume it without extra tooling.

have(){ command -v "$1" >/dev/null 2>&1; }

profile_dir(){
  cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd
}

screenshot_dir(){
  printf '%s\n' "${SOURCEOS_SCREENSHOT_DIR:-$HOME/Pictures/Screenshots}"
}

binding_value(){
  local slot=$1
  local base="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/"
  local path="${base}${slot}/"
  if have gsettings; then
    gsettings get org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:${path} binding 2>/dev/null || true
  fi
}

contains_binding_slot(){
  local slot=$1
  if have gsettings; then
    gsettings get org.gnome.settings-daemon.plugins.media-keys custom-keybindings 2>/dev/null | grep -Fq "$slot" && return 0
  fi
  return 1
}

print_present(){
  local key=$1
  local path=$2
  if [[ -e "$path" ]]; then
    printf '%s=present\n' "$key"
  else
    printf '%s=missing\n' "$key"
  fi
}

main(){
  local pdir sdir
  pdir="$(profile_dir)"
  sdir="$(screenshot_dir)"

  printf 'profile_dir=%s\n' "$pdir"
  print_present screenshot_helper "$pdir/bin/mac-screenshot.sh"

  if have mac-screenshot.sh; then
    printf 'screenshot_wrapper=present\n'
  else
    printf 'screenshot_wrapper=missing\n'
  fi

  if have gnome-screenshot; then
    printf 'gnome_screenshot=present\n'
  else
    printf 'gnome_screenshot=missing\n'
  fi

  if have sushi; then
    printf 'sushi=present\n'
  else
    printf 'sushi=missing\n'
  fi

  if [[ -d "$sdir" ]]; then
    printf 'screenshot_dir=present\n'
  else
    printf 'screenshot_dir=missing\n'
  fi
  printf 'screenshot_dir_path=%s\n' "$sdir"

  if have gsettings; then
    printf 'gsettings=present\n'
    for slot in custom3 custom4 custom5 custom6; do
      if contains_binding_slot "$slot"; then
        printf '%s_slot=present\n' "$slot"
      else
        printf '%s_slot=missing\n' "$slot"
      fi
      printf '%s_binding=%s\n' "$slot" "$(binding_value "$slot")"
    done
  else
    printf 'gsettings=missing\n'
  fi
}

main "$@"
