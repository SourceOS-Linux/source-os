#!/usr/bin/env bash
set -euo pipefail

# Install and enable GNOME extension pinset for workstation-v0 (linux-dev).
# - Prefers distro packages (Fedora) for stability.
# - Uses gnome-extensions for enable.
# - Safe to run repeatedly.

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
    echo "${ID:-linux}"
  else
    echo "linux"
  fi
}

install_pkgs_fedora(){
  # Prefer rpm-ostree when available.
  if have rpm-ostree; then
    info "Installing GNOME extension RPMs via rpm-ostree (may require reboot)"
    sudo rpm-ostree install gnome-shell-extension-dash-to-dock gnome-shell-extension-appindicator || true
    return
  fi
  if have dnf; then
    info "Installing GNOME extension RPMs via dnf"
    sudo dnf install -y gnome-shell-extension-dash-to-dock gnome-shell-extension-appindicator || true
    return
  fi
  warn "No rpm-ostree/dnf found; skipping package install"
}

enable_ext(){
  local uuid=$1
  if ! have gnome-extensions; then
    warn "gnome-extensions not found; cannot enable $uuid"
    return 0
  fi

  # Only enable if present.
  if gnome-extensions list | grep -qx "$uuid"; then
    gnome-extensions enable "$uuid" || true
    info "enabled: $uuid"
  else
    warn "extension not present (uuid): $uuid"
  fi
}

apply_dash_to_dock_defaults(){
  if ! have gsettings; then
    warn "gsettings not found; skipping dash-to-dock defaults"
    return 0
  fi

  # Defaults tuned for mac-like dock behavior.
  gsettings set org.gnome.shell.extensions.dash-to-dock dock-position 'BOTTOM'
  gsettings set org.gnome.shell.extensions.dash-to-dock autohide true
  gsettings set org.gnome.shell.extensions.dash-to-dock intellihide true
  gsettings set org.gnome.shell.extensions.dash-to-dock dash-max-icon-size 36
}

main(){
  if ! is_gnome; then
    warn "GNOME not detected; skipping extension pinset"
    exit 0
  fi

  local id
  id="$(os_id)"
  if [[ "$id" == "fedora" ]]; then
    install_pkgs_fedora
  else
    warn "Unsupported distro for packaged extension installs (id=$id); skipping install"
  fi

  enable_ext 'dash-to-dock@micxgx.gmail.com'
  enable_ext 'appindicatorsupport@rgcjonas.gmail.com'

  apply_dash_to_dock_defaults

  info "GNOME extension pinset complete"
  info "NOTE: You may need to log out/in (or reboot on rpm-ostree) for shell extensions to load."
}

main "$@"
