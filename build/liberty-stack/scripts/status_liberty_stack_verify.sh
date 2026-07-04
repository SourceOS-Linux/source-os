#!/usr/bin/env bash
set -euo pipefail

SYSTEMCTL_BIN="${SYSTEMCTL_BIN:-systemctl}"

"$SYSTEMCTL_BIN" status --no-pager liberty-stack-verify.timer || true
"$SYSTEMCTL_BIN" status --no-pager liberty-stack-verify.service || true
