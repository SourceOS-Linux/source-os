#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MISSING=0

for name in \
  prepare_liberty_stack_verify_env.sh \
  install_liberty_stack_verify.sh \
  enable_liberty_stack_verify.sh \
  status_liberty_stack_verify.sh \
  health_liberty_stack_verify.sh
  do
  if [[ ! -f "$SCRIPT_DIR/$name" ]]; then
    echo "missing helper: $SCRIPT_DIR/$name" >&2
    MISSING=1
  fi
done

if [[ "$MISSING" -ne 0 ]]; then
  exit 2
fi

echo '{"ok":true,"bootstrap_contract":"complete"}'
