#!/usr/bin/env bash
set -euo pipefail

SYSTEMCTL_BIN="${SYSTEMCTL_BIN:-systemctl}"
ETC_DIR="${ETC_DIR:-/etc/source-os/liberty-stack}"
SERVICE_STATUS="unknown"
TIMER_STATUS="unknown"
ENV_PRESENT="false"

if [[ -f "$ETC_DIR/restic.env" || -f "$ETC_DIR/restic.env.example" ]]; then
  ENV_PRESENT="true"
fi

if "$SYSTEMCTL_BIN" is-active --quiet liberty-stack-verify.service; then
  SERVICE_STATUS="active"
else
  SERVICE_STATUS="inactive"
fi

if "$SYSTEMCTL_BIN" is-active --quiet liberty-stack-verify.timer; then
  TIMER_STATUS="active"
else
  TIMER_STATUS="inactive"
fi

printf '{"service_status":"%s","timer_status":"%s","env_present":%s}\n' "$SERVICE_STATUS" "$TIMER_STATUS" "$ENV_PRESENT"
