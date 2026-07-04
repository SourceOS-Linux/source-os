#!/usr/bin/env bash
set -euo pipefail

SYSTEMCTL_BIN="${SYSTEMCTL_BIN:-systemctl}"
SYSTEMD_DIR="${SYSTEMD_DIR:-/etc/systemd/system}"

if [[ ! -f "$SYSTEMD_DIR/liberty-stack-verify.service" ]]; then
  echo "missing unit: $SYSTEMD_DIR/liberty-stack-verify.service" >&2
  exit 2
fi

if [[ ! -f "$SYSTEMD_DIR/liberty-stack-verify.timer" ]]; then
  echo "missing timer: $SYSTEMD_DIR/liberty-stack-verify.timer" >&2
  exit 2
fi

"$SYSTEMCTL_BIN" daemon-reload
"$SYSTEMCTL_BIN" enable --now liberty-stack-verify.timer
"$SYSTEMCTL_BIN" status --no-pager liberty-stack-verify.timer || true
