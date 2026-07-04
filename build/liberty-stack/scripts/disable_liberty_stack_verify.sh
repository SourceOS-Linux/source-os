#!/usr/bin/env bash
set -euo pipefail

SYSTEMCTL_BIN="${SYSTEMCTL_BIN:-systemctl}"
SYSTEMD_DIR="${SYSTEMD_DIR:-/etc/systemd/system}"
PURGE="${PURGE:-0}"
PREFIX="${PREFIX:-/usr/local}"
ETC_DIR="${ETC_DIR:-/etc/source-os/liberty-stack}"

if [[ -f "$SYSTEMD_DIR/liberty-stack-verify.timer" ]]; then
  "$SYSTEMCTL_BIN" disable --now liberty-stack-verify.timer || true
fi

if [[ -f "$SYSTEMD_DIR/liberty-stack-verify.service" ]]; then
  "$SYSTEMCTL_BIN" stop liberty-stack-verify.service || true
fi

"$SYSTEMCTL_BIN" daemon-reload || true

if [[ "$PURGE" == "1" ]]; then
  rm -f "$SYSTEMD_DIR/liberty-stack-verify.service"
  rm -f "$SYSTEMD_DIR/liberty-stack-verify.timer"
  rm -f "$PREFIX/lib/source-os/liberty-stack/liberty_stack_verify.sh"
  rm -f "$ETC_DIR/restic.env.example"
fi

echo "Liberty Stack verification hook disabled."
if [[ "$PURGE" == "1" ]]; then
  echo "Installed files removed."
fi
