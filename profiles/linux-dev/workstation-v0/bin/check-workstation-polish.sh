#!/usr/bin/env bash
set -euo pipefail

# Aggregate workstation polish validation helper.
# Consumes small key=value helpers and emits section-prefixed key=value lines.
# This is intentionally shell-only so it can feed CI, doctor, and status.

profile_dir(){
  cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd
}

emit_section(){
  local section=$1
  local helper=$2

  if [[ ! -f "$helper" ]]; then
    printf '%s.helper=missing\n' "$section"
    return 0
  fi

  printf '%s.helper=present\n' "$section"
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    printf '%s.%s\n' "$section" "$line"
  done < <(bash "$helper" 2>/dev/null || true)
}

main(){
  local pdir
  pdir="$(profile_dir)"
  printf 'profile_dir=%s\n' "$pdir"
  emit_section mac_polish "$pdir/bin/check-mac-polish.sh"
  emit_section keyboard_policy "$pdir/bin/check-keyboard-policy.sh"
  emit_section shortcut_map "$pdir/bin/check-shortcut-map-contract.sh"
  emit_section gnome_dock "$pdir/bin/check-gnome-dock-extension.sh"
}

main "$@"
