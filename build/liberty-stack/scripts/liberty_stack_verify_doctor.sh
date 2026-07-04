#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

STATUS_JSON="$($SCRIPT_DIR/status_liberty_stack_verify.sh 2>/dev/null || true)"
HEALTH_JSON="$($SCRIPT_DIR/health_liberty_stack_verify.sh 2>/dev/null || true)"
ASSET_JSON="$($SCRIPT_DIR/check_liberty_stack_verify_assets.sh 2>/dev/null || true)"

printf '{"status":%s,"health":%s,"assets":%s}\n' \
  "${STATUS_JSON:-null}" "${HEALTH_JSON:-null}" "${ASSET_JSON:-null}"
