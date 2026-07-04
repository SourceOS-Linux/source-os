#!/usr/bin/env bash
set -euo pipefail

# Install Lampstand for workstation-v0 and optionally enable a user service.
# Strategy:
# - prefer a local checkout at ~/dev/lampstand (or SOURCEOS_LAMPSTAND_SRC)
# - otherwise install from the public git URL via pipx
# - write a user systemd unit for lampstandd if the daemon entrypoint exists

info(){ printf "INFO: %s\n" "$*" >&2; }
warn(){ printf "WARN: %s\n" "$*" >&2; }
err(){ printf "ERROR: %s\n" "$*" >&2; }

have(){ command -v "$1" >/dev/null 2>&1; }

lampstand_src(){
  local local_src="${SOURCEOS_LAMPSTAND_SRC:-$HOME/dev/lampstand}"
  if [[ -f "$local_src/pyproject.toml" ]]; then
    printf '%s\n' "$local_src"
    return
  fi
  printf '%s\n' 'git+https://github.com/SocioProphet/lampstand.git'
}

ensure_pipx(){
  if have pipx; then
    return 0
  fi
  if have brew; then
    info "Installing pipx via brew (best-effort)"
    brew install pipx || true
  fi
  have pipx
}

install_lampstand(){
  local src
  src="$(lampstand_src)"
  info "Installing Lampstand via pipx from: $src"
  pipx install --force "$src"
}

write_user_service(){
  local bin="$HOME/.local/bin/lampstandd"
  if [[ ! -x "$bin" ]]; then
    warn "lampstandd not found at $bin; skipping user service"
    return 0
  fi

  local svc_dir="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
  local svc="$svc_dir/sourceos-lampstand.service"
  mkdir -p "$svc_dir"

  cat > "$svc" <<'EOF'
[Unit]
Description=SourceOS Lampstand search daemon
After=graphical-session.target
PartOf=graphical-session.target

[Service]
Type=simple
ExecStart=%h/.local/bin/lampstandd --root %h --rpc unixjson
Restart=on-failure
RestartSec=2

[Install]
WantedBy=default.target
EOF

  info "wrote user service: $svc"

  if have systemctl; then
    systemctl --user daemon-reload || true
    systemctl --user enable sourceos-lampstand.service || true
    systemctl --user restart sourceos-lampstand.service || true
  fi
}

main(){
  if ! ensure_pipx; then
    warn "pipx is not available; skipping Lampstand install"
    exit 0
  fi

  install_lampstand || {
    warn "Lampstand install failed (non-fatal)"
    exit 0
  }

  write_user_service || warn "Lampstand user service setup failed (non-fatal)"
}

main "$@"
