#!/usr/bin/env bash
set -euo pipefail

# Lightweight Lampstand user-unit check for workstation-v0.
# Emits simple key=value lines so doctor/status paths can consume it without
# depending on JSON tooling.

unit_path(){
  printf '%s/systemd/user/sourceos-lampstand.service\n' "${XDG_CONFIG_HOME:-$HOME/.config}"
}

have(){ command -v "$1" >/dev/null 2>&1; }

svc='sourceos-lampstand.service'
path="$(unit_path)"

printf 'unit=%s\n' "$svc"
printf 'path=%s\n' "$path"

if [[ -f "$path" ]]; then
  printf 'unit_file=present\n'
else
  printf 'unit_file=missing\n'
fi

if have systemctl; then
  if systemctl --user is-enabled "$svc" >/dev/null 2>&1; then
    printf 'enabled=yes\n'
  else
    printf 'enabled=no\n'
  fi

  if systemctl --user is-active "$svc" >/dev/null 2>&1; then
    printf 'active=yes\n'
  else
    printf 'active=no\n'
  fi
else
  printf 'enabled=unknown\n'
  printf 'active=unknown\n'
fi
