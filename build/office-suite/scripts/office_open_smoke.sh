#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

TEST_DOC="$TMPDIR/smoke.txt"
echo "SourceOS office open smoke" > "$TEST_DOC"

# Cloud mode should return a handoff URL.
CLOUD_OUT="$(SOURCEOS_OFFICE_MODE=cloud "$ROOT/build/office-suite/scripts/office_open.sh" "$TEST_DOC")"
case "$CLOUD_OUT" in
  http://*|https://*) ;;
  *)
    echo "cloud handoff smoke failed" >&2
    exit 1
    ;;
esac

# Local mode smoke only checks that the helper accepts the path and returns it.
# `soffice` availability is still enforced by the helper itself.
if command -v soffice >/dev/null 2>&1; then
  LOCAL_OUT="$(SOURCEOS_OFFICE_MODE=local "$ROOT/build/office-suite/scripts/office_open.sh" "$TEST_DOC")"
  [[ "$LOCAL_OUT" == "$TEST_DOC" ]] || {
    echo "local open smoke failed" >&2
    exit 1
  }
fi

echo "office open smoke passed"
