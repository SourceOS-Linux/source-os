#!/usr/bin/env bash
set -euo pipefail

PROFILE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST="$PROFILE_DIR/manifest.yaml"

err() { printf "ERROR: %s\n" "$*" >&2; }
info() { printf "INFO: %s\n" "$*" >&2; }

have() { command -v "$1" >/dev/null 2>&1; }

os_id() {
  if [[ "$(uname -s)" == "Darwin" ]]; then
    echo "macos"
    return
  fi
  if [[ -r /etc/os-release ]]; then
    . /etc/os-release
    echo "${ID:-linux}"
  else
    echo "linux"
  fi
}

install_brew() {
  # We do not auto-run remote scripts here. We require brew to be preinstalled.
  err "Homebrew not found. Install Homebrew first, then re-run." 
  err "macOS: https://brew.sh (inspect before running)"
  err "Linuxbrew: https://docs.brew.sh/Homebrew-on-Linux"
  exit 2
}

install_user_brew_packages() {
  if ! have brew; then
    install_brew
  fi

  info "Installing USER packages via brew (manifest-driven)."

  # NOTE: minimal parser: extract lines under 'brew:' and '- ' entries.
  awk '
    $0 ~ /^\s*brew:\s*$/ {in=1; next}
    in && $0 ~ /^\s*- / {gsub(/^\s*- /, ""); print; next}
    in && $0 ~ /^\s*[^-[:space:]]/ {exit}
  ' "$MANIFEST" | while read -r pkg; do
    [[ -z "$pkg" ]] && continue
    info "brew install $pkg"
    brew install "$pkg" || true
  done
}

install_system_packages() {
  local id
  id="$(os_id)"

  if have rpm-ostree; then
    info "Detected rpm-ostree. Installing SYSTEM packages (may require reboot)."
    sudo rpm-ostree install git openssh-clients podman toolbox wl-clipboard jq || true
    info "If rpm-ostree applied new packages, reboot before proceeding."
    return
  fi

  if have dnf; then
    info "Installing SYSTEM packages via dnf."
    sudo dnf install -y git openssh-clients podman toolbox wl-clipboard jq || true
    return
  fi

  err "No supported system package manager detected (rpm-ostree or dnf)."
  err "OS id: $id"
  exit 2
}

install_shell_spine() {
  local spine="$PROFILE_DIR/install-shell-spine.sh"
  if [[ -x "$spine" ]]; then
    info "Installing shell spine (fzf/atuin/zoxide/direnv + clipboard helpers)"
    "$spine"
  else
    err "shell spine installer missing: $spine"
    return 1
  fi
}

main() {
  if [[ ! -f "$MANIFEST" ]]; then
    err "manifest not found: $MANIFEST"
    exit 2
  fi

  install_system_packages
  install_user_brew_packages
  install_shell_spine

  info "Workstation profile install complete (v0)."
  info "Next: run doctor: $PROFILE_DIR/doctor.sh"
}

main "$@"
