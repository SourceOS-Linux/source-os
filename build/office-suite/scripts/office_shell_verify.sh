#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
APP_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"
DESKTOP_FILE="$APP_DIR/sourceos-office.desktop"
MIME_FILE="$CONFIG_DIR/mimeapps.list"

if [[ -x "$SCRIPT_DIR/sourceos-office-open" ]]; then
  [[ -f "$DESKTOP_FILE" ]] || {
    echo "office shell verification failed: missing desktop entry" >&2
    exit 1
  }

  [[ -x "$SCRIPT_DIR/sourceos-office" ]] || {
    echo "office shell verification failed: missing sourceos-office command" >&2
    exit 1
  }

  [[ -x "$SCRIPT_DIR/sourceos-office-open" ]] || {
    echo "office shell verification failed: missing sourceos-office-open helper" >&2
    exit 1
  }

  [[ -x "$SCRIPT_DIR/office_cloud_handoff.sh" ]] || {
    echo "office shell verification failed: missing cloud handoff helper" >&2
    exit 1
  }

  [[ -x "$SCRIPT_DIR/office_search_handoff.sh" ]] || {
    echo "office shell verification failed: missing search handoff helper" >&2
    exit 1
  }

  [[ -x "$SCRIPT_DIR/office_search_open.sh" ]] || {
    echo "office shell verification failed: missing search open helper" >&2
    exit 1
  }

  [[ -f "$MIME_FILE" ]] || {
    echo "office shell verification failed: missing MIME defaults" >&2
    exit 1
  }

  TMPDIR="$(mktemp -d)"
  trap 'rm -rf "$TMPDIR"' EXIT
  TEST_DOC="$TMPDIR/verify.txt"
  echo "SourceOS office verify" > "$TEST_DOC"

  OUT="$(SOURCEOS_OFFICE_MODE=cloud "$SCRIPT_DIR/sourceos-office" open "$TEST_DOC")"
  case "$OUT" in
    http://*|https://*) ;;
    *)
      echo "office shell verification failed: installed open path did not return URL" >&2
      exit 1
      ;;
  esac

  echo "office shell verification passed"
  exit 0
fi

"$ROOT/build/office-suite/scripts/verify_office_desktop_entry.sh"

if [[ -x "$ROOT/build/office-suite/scripts/verify_office_suite_profile.sh" ]]; then
  "$ROOT/build/office-suite/scripts/verify_office_suite_profile.sh"
fi

if [[ -x "$ROOT/build/office-suite/scripts/install_sourceos_office_shell_smoke.sh" ]]; then
  "$ROOT/build/office-suite/scripts/install_sourceos_office_shell_smoke.sh"
fi

echo "office shell verification passed"
