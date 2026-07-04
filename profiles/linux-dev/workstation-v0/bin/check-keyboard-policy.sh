#!/usr/bin/env bash
set -euo pipefail

# Validate workstation-v0 keyboard/remap policy without requiring root access.
# Emits key=value lines for doctor/status or CI consumption.

have(){ command -v "$1" >/dev/null 2>&1; }

profile_dir(){
  cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd
}

backend(){
  printf '%s\n' "${SOURCEOS_REMAP_BACKEND:-input-remapper}"
}

template_path(){
  printf '%s/sourceos/input/xremap-macos-compat.yml\n' "${XDG_CONFIG_HOME:-$HOME/.config}"
}

present_or_missing(){
  if have "$1"; then
    printf 'present\n'
  else
    printf 'missing\n'
  fi
}

main(){
  local pdir b tmpl backend_valid input_remapper xremap_bin xkeysnail selected_available policy_ok
  pdir="$(profile_dir)"
  b="$(backend)"
  tmpl="$(template_path)"
  backend_valid=no
  selected_available=unknown
  policy_ok=no

  printf 'profile_dir=%s\n' "$pdir"
  printf 'default_backend=input-remapper\n'
  printf 'primary_backend=input-remapper\n'
  printf 'compatibility_backends=xremap,kinto\n'
  printf 'wayland_first=yes\n'
  printf 'kinto_auto_install=no\n'
  printf 'selected_backend=%s\n' "$b"

  case "$b" in
    input-remapper|xremap|kinto)
      backend_valid=yes
      ;;
  esac
  printf 'backend_valid=%s\n' "$backend_valid"

  input_remapper="$(present_or_missing input-remapper-control)"
  xremap_bin="$(present_or_missing xremap)"
  xkeysnail="$(present_or_missing xkeysnail)"

  printf 'input_remapper=%s\n' "$input_remapper"
  printf 'xremap=%s\n' "$xremap_bin"
  printf 'xkeysnail=%s\n' "$xkeysnail"

  case "$b" in
    input-remapper)
      selected_available="$input_remapper"
      ;;
    xremap)
      selected_available="$xremap_bin"
      ;;
    kinto)
      selected_available="$xkeysnail"
      ;;
    *)
      selected_available=invalid
      ;;
  esac
  printf 'selected_backend_available=%s\n' "$selected_available"

  if [[ -f "$tmpl" ]]; then
    printf 'xremap_template=present\n'
  else
    printf 'xremap_template=missing\n'
  fi
  printf 'xremap_template_path=%s\n' "$tmpl"

  if [[ -f "$pdir/gnome/input-install.sh" ]]; then
    printf 'input_installer=present\n'
  else
    printf 'input_installer=missing\n'
  fi

  if [[ "$backend_valid" == "yes" ]]; then
    policy_ok=yes
  fi
  printf 'policy_ok=%s\n' "$policy_ok"
}

main "$@"
