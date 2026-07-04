#!/usr/bin/env bash
set -euo pipefail

# Install an open-source launcher for the SourceOS palette.
# Wayland-first preference: fuzzel (MIT)
# Fallbacks: wofi (GPL-3.0-only), rofi (GPL)

info(){ printf "INFO: %s\n" "$*" >&2; }
warn(){ printf "WARN: %s\n" "$*" >&2; }

have(){ command -v "$1" >/dev/null 2>&1; }

is_gnome(){
  [[ "${XDG_CURRENT_DESKTOP:-}" == *GNOME* ]] && return 0
  [[ "${DESKTOP_SESSION:-}" == *gnome* ]] && return 0
  return 1
}

os_id(){
  if [[ -r /etc/os-release ]]; then
    . /etc/os-release
    echo "${ID:-linux}"
  else
    echo "linux"
  fi
}

install_fedora(){
  # Prefer fuzzel (Wayland-first).
  if have rpm-ostree; then
    info "Installing launcher via rpm-ostree"
    sudo rpm-ostree install fuzzel || true
    return
  fi

  if have dnf; then
    info "Installing launcher via dnf"
    sudo dnf install -y fuzzel || true
    return
  fi
}

main(){
  if have fuzzel || have wofi || have rofi; then
    info "launcher already present (fuzzel/wofi/rofi)"
    exit 0
  fi

  if ! is_gnome; then
    warn "GNOME not detected; skipping launcher install"
    exit 0
  fi

  local id
  id="$(os_id)"

  if [[ "$id" == "fedora" ]]; then
    install_fedora
  else
    warn "Unsupported distro for launcher install (id=$id). Install fuzzel/wofi/rofi manually."
    exit 0
  fi

  if have fuzzel || have wofi || have rofi; then
    info "launcher installed"
  else
    warn "no launcher found after install attempt (expected: fuzzel)"
  fi
}

main "$@"
