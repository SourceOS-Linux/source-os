#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

export XDG_DATA_HOME="$TMPDIR/share"
export XDG_CONFIG_HOME="$TMPDIR/config"
export HOME="$TMPDIR/home"
mkdir -p "$HOME"

"$ROOT/build/office-suite/scripts/install_sourceos_office_shell.sh" >/dev/null

DESKTOP_FILE="$XDG_DATA_HOME/applications/sourceos-office.desktop"
OPEN_BIN="$HOME/.local/bin/sourceos-office-open"
SOURCEOS_OFFICE_BIN="$HOME/.local/bin/sourceos-office"
INSTALL_BIN="$HOME/.local/bin/install_sourceos_office_shell.sh"
VERIFY_BIN="$HOME/.local/bin/office_shell_verify.sh"
NEW_BIN="$HOME/.local/bin/office_new.sh"
CLOUD_BIN="$HOME/.local/bin/office_cloud_handoff.sh"
MIME_FILE="$XDG_CONFIG_HOME/mimeapps.list"
TEST_DOC="$TMPDIR/demo.txt"
NEW_DOC="$TMPDIR/new-writer.fodt"
echo "SourceOS office shell smoke" > "$TEST_DOC"

[[ -f "$DESKTOP_FILE" ]] || {
  echo "office shell installer smoke failed: missing desktop entry" >&2
  exit 1
}

[[ -x "$OPEN_BIN" ]] || {
  echo "office shell installer smoke failed: missing office open launcher" >&2
  exit 1
}

[[ -x "$SOURCEOS_OFFICE_BIN" ]] || {
  echo "office shell installer smoke failed: missing sourceos-office command" >&2
  exit 1
}

[[ -x "$INSTALL_BIN" ]] || {
  echo "office shell installer smoke failed: missing install_sourceos_office_shell helper" >&2
  exit 1
}

[[ -x "$VERIFY_BIN" ]] || {
  echo "office shell installer smoke failed: missing office_shell_verify helper" >&2
  exit 1
}

[[ -x "$NEW_BIN" ]] || {
  echo "office shell installer smoke failed: missing office_new helper" >&2
  exit 1
}

[[ -x "$CLOUD_BIN" ]] || {
  echo "office shell installer smoke failed: missing cloud handoff helper" >&2
  exit 1
}

[[ -f "$MIME_FILE" ]] || {
  echo "office shell installer smoke failed: missing MIME defaults" >&2
  exit 1
}

OUT="$(SOURCEOS_OFFICE_MODE=cloud "$SOURCEOS_OFFICE_BIN" open "$TEST_DOC")"
case "$OUT" in
  http://*|https://*) ;;
  *)
    echo "office shell installer smoke failed: installed sourceos-office open path did not return URL" >&2
    exit 1
    ;;
esac

VERIFY_OUT="$($SOURCEOS_OFFICE_BIN verify)"
[[ "$VERIFY_OUT" == *"office shell verification passed"* ]] || {
  echo "office shell installer smoke failed: installed verify path did not pass" >&2
  exit 1
}

FAKEBIN="$TMPDIR/fakebin"
mkdir -p "$FAKEBIN"
cat > "$FAKEBIN/lampstand" <<EOF
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$TEST_DOC"
EOF
chmod +x "$FAKEBIN/lampstand"

SEARCH_OUT="$(PATH="$FAKEBIN:$PATH" SOURCEOS_OFFICE_MODE=cloud "$SOURCEOS_OFFICE_BIN" search demo)"
case "$SEARCH_OUT" in
  http://*|https://*) ;;
  *)
    echo "office shell installer smoke failed: installed sourceos-office search path did not return URL" >&2
    exit 1
    ;;
esac

NEW_OUT="$($SOURCEOS_OFFICE_BIN new writer "$NEW_DOC")"
[[ "$NEW_OUT" == "$NEW_DOC" ]] || {
  echo "office shell installer smoke failed: installed sourceos-office new path did not return created file" >&2
  exit 1
}
[[ -f "$NEW_DOC" ]] || {
  echo "office shell installer smoke failed: installed sourceos-office new path did not create file" >&2
  exit 1
}

grep -q "SourceOS sovereign writer template placeholder" "$NEW_DOC" || {
  echo "office shell installer smoke failed: created writer file does not contain template payload" >&2
  exit 1
}

DEFAULT_NEW_OUT="$($SOURCEOS_OFFICE_BIN new writer)"
case "$DEFAULT_NEW_OUT" in
  "$HOME"/Documents/SourceOS/agent-output/*.fodt) ;;
  *)
    echo "office shell installer smoke failed: default new path did not use SourceOS agent-output" >&2
    exit 1
    ;;
esac
[[ -f "$DEFAULT_NEW_OUT" ]] || {
  echo "office shell installer smoke failed: default new path did not create file" >&2
  exit 1
}

grep -q "SourceOS sovereign writer template placeholder" "$DEFAULT_NEW_OUT" || {
  echo "office shell installer smoke failed: default writer file does not contain template payload" >&2
  exit 1
}

"$SOURCEOS_OFFICE_BIN" install >/dev/null

echo "office shell installer smoke passed"
