#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

"$SCRIPT_DIR/prepare_liberty_stack_verify_env.sh"
"$SCRIPT_DIR/install_liberty_stack_verify.sh"
"$SCRIPT_DIR/enable_liberty_stack_verify.sh"
"$SCRIPT_DIR/status_liberty_stack_verify.sh" || true
"$SCRIPT_DIR/health_liberty_stack_verify.sh" || true
