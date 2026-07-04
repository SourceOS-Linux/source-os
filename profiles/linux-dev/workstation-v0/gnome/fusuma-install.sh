#!/usr/bin/env bash
set -euo pipefail

# Install fusuma and its runtime dependencies for workstation-v0.
# Fedora lane follows upstream guidance:
# - libinput
# - ruby
# - xdotool (for shortcut dispatch)
# - gem install fusuma
# - membership in input group

info(){ printf "INFO: %s\n" "$*" >&2; }
warn(){ printf "WARN: %s\n" "$*" >&2; }
err(){ printf "ERROR: %s\n" "$*" >&2; }

have(){ command -v "$1" >/dev/null 2>&1; }

is_gnome(){
  [[ "${XDG_CURRENT_DESKTOP:-}" == *GNOME* ]] && return 0
  [[ "${DESKTOP_SESSION:-}" == *gnome* ]] && return 0
  return 1
}

os_id(){
  if [[ -r /etc/os-release ]]; then
    . /etc/os-release
    printf '%s\n' "${ID:-linux}"
  else
    printf '%s\n' linux
  fi
}

install_pkg_fedora(){
  if have rpm-ostree; then
    sudo rpm-ostree install "$@" || true
    return
  fi
  if have dnf; then
    sudo dnf install -y "$@" || true
    return
  fi
}

main(){
  if ! is_gnome; then
    warn "GNOME not detected; skipping fusuma install"
    exit 0
  fi

  local id
  id="$(os_id)"
  if [[ "$id" != "fedora" ]]; then
    warn "Unsupported distro for packaged fusuma dependency install (id=$id)"
    exit 0
  fi

  info "Installing fusuma dependencies"
  install_pkg_fedora libinput ruby xdotool

  if have gem; then
    if have fusuma; then
      info "fusuma already installed"
    else
      sudo gem install fusuma || true
    fi
  else
    warn "gem not found after ruby install; skipping fusuma gem install"
  fi

  if getent group input >/dev/null 2>&1; then
    sudo gpasswd -a "$USER" input || true
    warn "Added $USER to input group (if not already). New login may be required."
  else
    warn "input group not found; fusuma may lack device access"
  fi
}

main "$@"
