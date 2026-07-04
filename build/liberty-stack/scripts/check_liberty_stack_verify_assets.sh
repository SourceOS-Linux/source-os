#!/usr/bin/env bash
set -euo pipefail

PREFIX="${PREFIX:-/usr/local}"
SYSTEMD_DIR="${SYSTEMD_DIR:-/etc/systemd/system}"
ETC_DIR="${ETC_DIR:-/etc/source-os/liberty-stack}"

SCRIPT_OK="false"
SERVICE_OK="false"
TIMER_OK="false"
PRESET_OK="false"
ENV_EXAMPLE_OK="false"

[[ -f "$PREFIX/lib/source-os/liberty-stack/liberty_stack_verify.sh" ]] && SCRIPT_OK="true"
[[ -f "$SYSTEMD_DIR/liberty-stack-verify.service" ]] && SERVICE_OK="true"
[[ -f "$SYSTEMD_DIR/liberty-stack-verify.timer" ]] && TIMER_OK="true"
[[ -f "$SYSTEMD_DIR/liberty-stack-verify.preset" ]] && PRESET_OK="true"
[[ -f "$ETC_DIR/restic.env.example" ]] && ENV_EXAMPLE_OK="true"

printf '{"script":%s,"service":%s,"timer":%s,"preset":%s,"env_example":%s}\n' \
  "$SCRIPT_OK" "$SERVICE_OK" "$TIMER_OK" "$PRESET_OK" "$ENV_EXAMPLE_OK"
