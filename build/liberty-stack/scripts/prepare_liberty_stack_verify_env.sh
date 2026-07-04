#!/usr/bin/env bash
set -euo pipefail

ETC_DIR="${ETC_DIR:-/etc/source-os/liberty-stack}"
EXAMPLE="$ETC_DIR/restic.env.example"
TARGET="$ETC_DIR/restic.env"

install -d "$ETC_DIR"

if [[ ! -f "$EXAMPLE" ]]; then
  echo "missing example environment file: $EXAMPLE" >&2
  exit 2
fi

if [[ -f "$TARGET" ]]; then
  echo "environment file already exists: $TARGET"
  exit 0
fi

cp "$EXAMPLE" "$TARGET"
echo "created $TARGET from example; review and set real values before enabling the timer"
