#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
FAIL=0

require_file() {
  local path="$1"
  if [[ ! -f "$ROOT/$path" ]]; then
    echo "missing: $path" >&2
    FAIL=1
  else
    echo "ok: $path"
  fi
}

require_file "build/office-suite/profiles/sourceos-office-profile.toml"
require_file "configs/libreoffice/sourceos-office.xcu"
require_file "configs/fontconfig/office-font-substitutions.conf"
require_file "configs/mime/sourceos-office-mimeapps.list"
require_file "build/office-suite/templates/sovereign/sourceos-default-writer.fodt"
require_file "build/office-suite/scripts/office_cloud_handoff.sh"
require_file "build/office-suite/scripts/office_open.sh"
require_file "build/office-suite/scripts/office_open_smoke.sh"
require_file "build/office-suite/scripts/office_extract_smoke.sh"
require_file "build/office-suite/scripts/office_search_handoff.sh"
require_file "build/office-suite/scripts/office_search_open.sh"
require_file "build/office-suite/scripts/office_search_open_smoke.sh"

if [[ $FAIL -ne 0 ]]; then
  echo "office suite profile verification failed" >&2
  exit 1
fi

echo "office suite profile verification passed"
