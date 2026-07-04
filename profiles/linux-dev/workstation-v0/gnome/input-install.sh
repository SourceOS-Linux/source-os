#!/usr/bin/env bash
set -euo pipefail

# Install keyboard remap backend(s) for workstation-v0.
# Strategy:
# - Primary (Fedora/Wayland/GNOME): input-remapper
# - Compatibility assets: xremap template (MIT) for advanced per-app remapping
# - Kinto is treated as an X11 compatibility lane and is NOT auto-installed here
#
# Env:
# - SOURCEOS_REMAP_BACKEND=input-remapper|xremap|kinto (default: input-remapper)

info(){ printf "INFO: %s\n" "$*" >&2; }
warn(){ printf "WARN: %s\n" "$*" >&2; }
err(){ printf "ERROR: %s\n" "$*" >&2; }

have(){ command -v "$1" >/dev/null 2>&1; }

backend(){
  printf '%s\n' "${SOURCEOS_REMAP_BACKEND:-input-remapper}"
}

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
  local pkg=$1
  if have rpm-ostree; then
    sudo rpm-ostree install "$pkg" || true
    return
  fi
  if have dnf; then
    sudo dnf install -y "$pkg" || true
    return
  fi
}

write_xremap_template(){
  local dst_dir="${XDG_CONFIG_HOME:-$HOME/.config}/sourceos/input"
  mkdir -p "$dst_dir"
  cat > "$dst_dir/xremap-macos-compat.yml" <<'EOF'
# SourceOS xremap compatibility template
# Intended for GNOME Wayland/X11 advanced remapping.
# Apply manually if you choose the xremap compatibility lane.
modmap:
  - name: SourceOS mac-like modifiers
    remap:
      CapsLock: Esc
      Control_L: Super_L
      Super_L: Alt_L
      Alt_L: Control_L
      Control_R: Super_R
      Super_R: Alt_R
      Alt_R: Control_R
EOF
  info "wrote xremap compatibility template: $dst_dir/xremap-macos-compat.yml"
}

main(){
  if ! is_gnome; then
    warn "GNOME not detected; skipping input backend install"
    exit 0
  fi

  local b
  b="$(backend)"
  case "$b" in
    input-remapper)
      local id
      id="$(os_id)"
      if [[ "$id" == "fedora" ]]; then
        info "Installing primary remap backend: input-remapper"
        install_pkg_fedora input-remapper
      else
        warn "Unsupported distro for primary packaged input-remapper install (id=$id)"
      fi
      write_xremap_template
      ;;
    xremap)
      warn "xremap compatibility lane selected; not auto-installing binary in this profile"
      write_xremap_template
      ;;
    kinto)
      warn "Kinto compatibility lane selected; not auto-installing in Wayland-first profile"
      warn "Kinto depends on xkeysnail/X11 and is treated as an explicit compatibility path"
      write_xremap_template
      ;;
    *)
      err "unknown SOURCEOS_REMAP_BACKEND=$b"
      exit 2
      ;;
  esac
}

main "$@"
