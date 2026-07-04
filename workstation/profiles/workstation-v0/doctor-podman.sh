#!/usr/bin/env bash
set -euo pipefail

info() { printf "INFO: %s\n" "$*" >&2; }
warn() { printf "WARN: %s\n" "$*" >&2; }
err()  { printf "ERROR: %s\n" "$*" >&2; }

have() { command -v "$1" >/dev/null 2>&1; }

if ! have podman; then
  err "missing: podman"
  exit 2
fi

info "ok: podman"

if podman machine ls >/dev/null 2>&1; then
  info "ok: podman machine ls"
else
  warn "podman machine unavailable or unsupported on this host"
fi

if podman system connection list >/dev/null 2>&1; then
  info "ok: podman system connection list"
else
  warn "podman system connection list failed"
fi
