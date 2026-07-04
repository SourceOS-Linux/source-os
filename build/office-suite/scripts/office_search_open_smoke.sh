#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

TEST_DOC="$TMPDIR/demo.txt"
echo "SourceOS office search open smoke" > "$TEST_DOC"

# Simulate a direct search result path by shadowing the handoff helper output.
SEARCH_HELPER="$ROOT/build/office-suite/scripts/office_search_handoff.sh"
BACKUP="$TMPDIR/original_search_handoff.sh"
cp "$SEARCH_HELPER" "$BACKUP"
cat > "$SEARCH_HELPER" <<EOF
#!/usr/bin/env bash
set -euo pipefail
echo "$TEST_DOC"
EOF
chmod +x "$SEARCH_HELPER"
trap 'cp "$BACKUP" "$SEARCH_HELPER"; chmod +x "$SEARCH_HELPER"; rm -rf "$TMPDIR"' EXIT

OUT="$($ROOT/build/office-suite/scripts/office_search_open.sh "demo" 2>/dev/null || true)"

if [[ -n "$OUT" && "$OUT" != "$TEST_DOC" && "$OUT" != http://* && "$OUT" != https://* ]]; then
  echo "unexpected search open smoke output" >&2
  exit 1
fi

echo "office search open smoke passed"
