#!/usr/bin/env bash
set -euo pipefail

# Apply SourceOS fusuma defaults for workstation-v0.
# - writes ~/.config/fusuma/config.yml if absent
# - installs a user systemd service if available
# - safe to run repeatedly

info(){ printf "INFO: %s\n" "$*" >&2; }
warn(){ printf "WARN: %s\n" "$*" >&2; }

have(){ command -v "$1" >/dev/null 2>&1; }

is_gnome(){
  [[ "${XDG_CURRENT_DESKTOP:-}" == *GNOME* ]] && return 0
  [[ "${DESKTOP_SESSION:-}" == *gnome* ]] && return 0
  return 1
}

write_config(){
  local cfg_dir="${XDG_CONFIG_HOME:-$HOME/.config}/fusuma"
  local cfg="$cfg_dir/config.yml"
  mkdir -p "$cfg_dir"

  if [[ -f "$cfg" ]]; then
    info "fusuma config already present: $cfg"
    return 0
  fi

  cat > "$cfg" <<'EOF'
swipe:
  3:
    left:
      command: "xdotool key alt+Right"
    right:
      command: "xdotool key alt+Left"
    up:
      command: "xdotool key super"
    down:
      command: "xdotool key super"
  4:
    left:
      command: "xdotool key ctrl+alt+Right"
    right:
      command: "xdotool key ctrl+alt+Left"
pinch:
  2:
    in:
      command: "xdotool key ctrl+minus"
    out:
      command: "xdotool key ctrl+plus"
threshold:
  swipe: 0.8
  pinch: 0.2
interval:
  swipe: 0.6
  pinch: 0.2
EOF

  info "wrote fusuma config: $cfg"
}

write_service(){
  local svc_dir="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user"
  local svc="$svc_dir/sourceos-fusuma.service"
  mkdir -p "$svc_dir"

  cat > "$svc" <<'EOF'
[Unit]
Description=SourceOS Fusuma gestures
After=graphical-session.target
PartOf=graphical-session.target

[Service]
Type=simple
ExecStart=fusuma
Restart=on-failure
RestartSec=2

[Install]
WantedBy=default.target
EOF

  info "wrote user service: $svc"

  if have systemctl; then
    systemctl --user daemon-reload || true
    systemctl --user enable sourceos-fusuma.service || true
  fi
}

main(){
  if ! is_gnome; then
    warn "GNOME not detected; skipping fusuma apply"
    exit 0
  fi

  write_config
  write_service
}

main "$@"
