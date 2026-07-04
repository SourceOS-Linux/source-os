#!/usr/bin/env bash
set -euo pipefail

PROFILE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFEST="$PROFILE_DIR/manifest.yaml"

err(){ printf "ERROR: %s\n" "$*" >&2; }
info(){ printf "INFO: %s\n" "$*" >&2; }
warn(){ printf "WARN: %s\n" "$*" >&2; }

have(){ command -v "$1" >/dev/null 2>&1; }

autopatch_enabled(){
  case "${SOURCEOS_AUTOPATCH_SHELL:-0}" in
    1|true|TRUE|yes|YES) return 0 ;;
    *) return 1 ;;
  esac
}

install_system(){
  local packages=(git openssh-clients podman toolbox wl-clipboard jq xclip sushi gnome-screenshot)
  if have rpm-ostree; then
    info "rpm-ostree detected: installing SYSTEM layer (may require reboot)"
    sudo rpm-ostree install "${packages[@]}" || true
    info "If new packages were layered, reboot before continuing."
    return
  fi
  if have dnf; then
    info "dnf detected: installing SYSTEM layer"
    sudo dnf install -y "${packages[@]}" || true
    return
  fi
  err "No rpm-ostree/dnf found; cannot apply SYSTEM layer"
  exit 2
}

install_brew(){
  err "brew not found. Install brew first, then re-run."
  exit 2
}

install_user(){
  if ! have brew; then
    install_brew
  fi
  info "Installing USER packages via brew (manifest-driven)."
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

install_shell_spine(){
  local dst="${XDG_CONFIG_HOME:-$HOME/.config}/sourceos/shell"
  mkdir -p "$dst"
  cp -f "$PROFILE_DIR/shell/common.sh" "$dst/common.sh"
  if [[ -f "$PROFILE_DIR/shell/common.fish" ]]; then
    cp -f "$PROFILE_DIR/shell/common.fish" "$dst/common.fish"
  fi
  info "shell spine installed: $dst"
  info "Enable by sourcing it from your shell rc or use the autopatch helpers."
}

install_sourceos_cli(){
  local script="$PROFILE_DIR/bin/install-sourceos-cli.sh"
  if [[ -x "$script" ]]; then
    info "Installing SourceOS helper CLI to ~/.local/bin"
    "$script" || warn "sourceos CLI install failed (non-fatal)"
  else
    warn "sourceos CLI installer not found: $script"
  fi
}

install_lampstand_backend(){
  local script="$PROFILE_DIR/bin/install-lampstand.sh"
  if [[ -x "$script" ]]; then
    info "Installing Lampstand backend (best-effort)"
    "$script" || warn "Lampstand install failed (non-fatal)"
  else
    warn "Lampstand installer not found: $script"
  fi
}

patch_shell_rc_if_enabled(){
  if ! autopatch_enabled; then
    return 0
  fi

  local all_script="$PROFILE_DIR/bin/patch-all.sh"
  if [[ -x "$all_script" ]]; then
    info "Autopatch enabled: applying composite shell/fish patch helper"
    "$all_script" apply || warn "composite patch helper failed (non-fatal)"
    return 0
  fi

  local sh_script="$PROFILE_DIR/bin/patch-shell.sh"
  if [[ -x "$sh_script" ]]; then
    info "Autopatch enabled: patching shell rc files"
    "$sh_script" apply || warn "shell rc patch failed (non-fatal)"
  else
    warn "autopatch enabled but patch helper missing: $sh_script"
  fi

  local fish_script="$PROFILE_DIR/bin/patch-fish.sh"
  if [[ -x "$fish_script" ]]; then
    info "Autopatch enabled: patching fish config (if present)"
    "$fish_script" apply || warn "fish config patch failed (non-fatal)"
  fi
}

apply_gnome_baseline(){
  local script="$PROFILE_DIR/gnome/apply.sh"
  if [[ -x "$script" ]]; then
    info "Applying GNOME baseline (best-effort)"
    "$script" || warn "GNOME baseline apply failed (non-fatal)"
  else
    warn "GNOME baseline script not found: $script"
  fi
}

apply_gnome_extensions(){
  local script="$PROFILE_DIR/gnome/extensions-install.sh"
  if [[ -x "$script" ]]; then
    info "Applying GNOME extension pinset (best-effort)"
    "$script" || warn "GNOME extensions apply failed (non-fatal)"
  else
    warn "GNOME extensions installer not found: $script"
  fi
}

apply_gnome_appearance(){
  local script="$PROFILE_DIR/gnome/appearance-apply.sh"
  if [[ -f "$script" ]]; then
    info "Applying GNOME appearance defaults (best-effort)"
    bash "$script" || warn "GNOME appearance defaults failed (non-fatal)"
  else
    warn "GNOME appearance script not found: $script"
  fi
}

apply_files_sidebar(){
  local script="$PROFILE_DIR/gnome/files-sidebar.sh"
  if [[ -f "$script" ]]; then
    info "Applying Files sidebar defaults (best-effort)"
    bash "$script" || warn "Files sidebar defaults failed (non-fatal)"
  else
    warn "Files sidebar script not found: $script"
  fi
}

apply_input_install(){
  local script="$PROFILE_DIR/gnome/input-install.sh"
  if [[ -x "$script" ]]; then
    info "Installing input remap lane (best-effort)"
    "$script" || warn "input lane install failed (non-fatal)"
  else
    warn "input install script not found: $script"
  fi
}

apply_fusuma_install(){
  local script="$PROFILE_DIR/gnome/fusuma-install.sh"
  if [[ -x "$script" ]]; then
    info "Installing fusuma gesture lane (best-effort)"
    "$script" || warn "fusuma install failed (non-fatal)"
  else
    warn "fusuma install script not found: $script"
  fi
}

apply_fusuma_config(){
  local script="$PROFILE_DIR/gnome/fusuma-apply.sh"
  if [[ -x "$script" ]]; then
    info "Applying fusuma defaults (best-effort)"
    "$script" || warn "fusuma apply failed (non-fatal)"
  else
    warn "fusuma apply script not found: $script"
  fi
}

apply_launcher_install(){
  local script="$PROFILE_DIR/gnome/launcher-install.sh"
  if [[ -x "$script" ]]; then
    info "Installing launcher (best-effort)"
    "$script" || warn "launcher install failed (non-fatal)"
  else
    warn "launcher install script not found: $script"
  fi
}

apply_palette_hotkey(){
  local script="$PROFILE_DIR/gnome/palette-hotkey.sh"
  if [[ -x "$script" ]]; then
    info "Setting palette hotkey (best-effort)"
    "$script" || warn "palette hotkey setup failed (non-fatal)"
  else
    warn "palette hotkey script not found: $script"
  fi
}

apply_mac_defaults(){
  local script="$PROFILE_DIR/gnome/mac-defaults.sh"
  if [[ -x "$script" ]]; then
    info "Applying mac-like GNOME defaults pack (best-effort)"
    "$script" || warn "mac defaults pack failed (non-fatal)"
  else
    warn "mac defaults script not found: $script"
  fi
}

main(){
  [[ -f "$MANIFEST" ]] || { err "manifest missing: $MANIFEST"; exit 2; }
  install_system
  install_user
  install_shell_spine
  install_sourceos_cli
  install_lampstand_backend
  patch_shell_rc_if_enabled
  apply_gnome_baseline
  apply_gnome_extensions
  apply_gnome_appearance
  apply_files_sidebar
  apply_input_install
  apply_fusuma_install
  apply_fusuma_config
  apply_launcher_install
  apply_palette_hotkey
  apply_mac_defaults
  info "installed workstation-v0 (linux-dev)"
  info "next: ./doctor.sh"
}

main "$@"
