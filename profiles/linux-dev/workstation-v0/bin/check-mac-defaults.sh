#!/usr/bin/env bash
set -euo pipefail

# Validate the workstation-v0 GNOME mac-defaults script without running GNOME.
# Emits key=value lines for CI/reviewer consumption.

profile_dir(){
  cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd
}

present(){
  local key=$1
  local pattern=$2
  local file=$3
  if grep -Fq "$pattern" "$file" 2>/dev/null; then
    printf '%s=present\n' "$key"
  else
    printf '%s=missing\n' "$key"
  fi
}

main(){
  local pdir script
  pdir="$(profile_dir)"
  script="$pdir/gnome/mac-defaults.sh"

  if [[ -s "$script" ]]; then
    printf 'mac_defaults_script=present\n'
  else
    printf 'mac_defaults_script=missing\n'
    exit 0
  fi

  present hot_corners_disabled "enable-hot-corners false" "$script"
  present clock_12h "clock-format '12h'" "$script"
  present locate_pointer "locate-pointer true" "$script"
  present nautilus_double_click "org.gnome.nautilus.preferences click-policy 'double'" "$script"
  present dock_favorites_seed "org.gnome.shell favorite-apps" "$script"
  present files_binding "<Super>e" "$script"
  present terminal_binding "<Super>Return" "$script"
  present screenshot_screen_binding "<Super><Shift>3" "$script"
  present screenshot_area_binding "<Super><Shift>4" "$script"
  present screenshot_ui_binding "<Super><Shift>5" "$script"
  present screenshot_folder_binding "<Super><Shift>6" "$script"
  present screenshot_directory 'Pictures/Screenshots' "$script"
}

main "$@"
