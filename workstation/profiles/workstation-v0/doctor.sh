#!/usr/bin/env bash
set -euo pipefail

PROFILE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST="$PROFILE_DIR/manifest.yaml"

fail=0

info() { printf "INFO: %s\n" "$*" >&2; }
warn() { printf "WARN: %s\n" "$*" >&2; }
err()  { printf "ERROR: %s\n" "$*" >&2; }

have() { command -v "$1" >/dev/null 2>&1; }

check() {
  local bin=$1
  if have "$bin"; then
    info "ok: $bin"
  else
    err "missing: $bin"
    fail=1
  fi
}

os_id() {
  if [[ "$(uname -s)" == "Darwin" ]]; then
    echo "macos"; return
  fi
  if [[ -r /etc/os-release ]]; then
    . /etc/os-release
    echo "${ID:-linux}"
  else
    echo "linux"
  fi
}

main() {
  info "Doctor: workstation-v0"
  info "OS: $(os_id)"

  # Baseline expectations
  check git
  check ssh

  # System layer signals
  if have rpm-ostree; then
    info "rpm-ostree: present"
  else
    warn "rpm-ostree: not present (ok on non-ostree distros)"
  fi

  if have podman; then
    info "ok: podman"
  else
    warn "missing: podman (required for toolbox-based workflows)"
  fi

  # USER tools
  # We treat brew as the primary userland provider for parity.
  if have brew; then
    info "ok: brew"
  else
    warn "missing: brew (USER layer likely incomplete)"
  fi

  # Core CLI UX
  check fzf
  check atuin
  check bat
  check zoxide
  check yazi
  check eza
  check gum
  check direnv
  check rg
  check fd
  check tmux

  # Git UX
  check gh
  check lazygit
  check tig

  # JSON
  check jnv
  check gojq

  # K8s
  check k9s

  # File motion
  check rclone
  check mc
  check rsync

  if [[ $fail -ne 0 ]]; then
    err "doctor: FAIL"
    exit 2
  fi

  info "doctor: OK"
}

main "$@"
