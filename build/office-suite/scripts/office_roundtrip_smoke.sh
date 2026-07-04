#!/usr/bin/env bash
set -euo pipefail

if ! command -v soffice >/dev/null 2>&1; then
  echo "soffice not found" >&2
  exit 1
fi

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

cat > "$TMPDIR/smoke.odt" <<'EOF'
This is a SourceOS office roundtrip smoke placeholder.
EOF

# Convert via LibreOffice headless as a smoke path.
soffice --headless --convert-to pdf --outdir "$TMPDIR" "$TMPDIR/smoke.odt" >/dev/null 2>&1 || {
  echo "LibreOffice headless conversion failed" >&2
  exit 1
}

if [[ ! -f "$TMPDIR/smoke.pdf" ]]; then
  echo "roundtrip smoke failed: missing PDF output" >&2
  exit 1
fi

echo "office roundtrip smoke passed"
