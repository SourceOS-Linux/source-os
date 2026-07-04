#!/usr/bin/env bash
set -euo pipefail

# Validate the workstation-v0 shortcut map contract without changing bindings.
# Emits key=value lines for CI/reviewer consumption.

repo_root(){
  local here
  here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  cd "$here/../../.." && pwd
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
  local root doc
  root="$(repo_root)"
  doc="$root/docs/workstation/shortcut-map.md"

  if [[ -s "$doc" ]]; then
    printf 'shortcut_map=present\n'
  else
    printf 'shortcut_map=missing\n'
    exit 0
  fi

  present active_palette 'Super+Space' "$doc"
  present active_files 'Super+E' "$doc"
  present active_terminal 'Super+Return' "$doc"
  present active_screenshot_screen 'Super+Shift+3' "$doc"
  present active_screenshot_area 'Super+Shift+4' "$doc"
  present active_screenshot_ui 'Super+Shift+5' "$doc"
  present active_screenshot_folder 'Super+Shift+6' "$doc"
  present compatibility_input_remapper 'input-remapper' "$doc"
  present compatibility_xremap 'xremap' "$doc"
  present compatibility_kinto 'Kinto' "$doc"
  present planned_marker 'planned' "$doc"
  present non_goal_marker 'non-goal' "$doc"
  present boundary_marker 'does not modify keybindings' "$doc"
}

main "$@"
