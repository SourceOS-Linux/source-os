#!/usr/bin/env bash
set -euo pipefail

PREFIX="${1:-/usr/local}"
SYSTEMD_DIR="${SYSTEMD_DIR:-/etc/systemd/system}"
ETC_DIR="${ETC_DIR:-/etc/source-os/liberty-stack}"

install -d "$PREFIX/lib/source-os/liberty-stack"
install -d "$SYSTEMD_DIR"
install -d "$ETC_DIR"

install -m 0755 build/liberty-stack/scripts/liberty_stack_verify.sh "$PREFIX/lib/source-os/liberty-stack/liberty_stack_verify.sh"
install -m 0644 build/liberty-stack/restic.env.example "$ETC_DIR/restic.env.example"
install -m 0644 build/liberty-stack/systemd/liberty-stack-verify.service "$SYSTEMD_DIR/liberty-stack-verify.service"
install -m 0644 build/liberty-stack/systemd/liberty-stack-verify.timer "$SYSTEMD_DIR/liberty-stack-verify.timer"

echo "Installed Liberty Stack verification assets to:"
echo "  script: $PREFIX/lib/source-os/liberty-stack/liberty_stack_verify.sh"
echo "  env example: $ETC_DIR/restic.env.example"
echo "  units: $SYSTEMD_DIR/liberty-stack-verify.service + .timer"
echo "Next: copy restic.env.example to restic.env, set values, then enable the timer."
