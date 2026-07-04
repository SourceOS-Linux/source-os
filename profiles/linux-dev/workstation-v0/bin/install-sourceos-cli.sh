#!/usr/bin/env bash
set -euo pipefail

# Install profile-local workstation helper CLIs to user scope.
# Targets:
# - ~/.local/bin/sourceos
# - ~/.local/bin/mac-screenshot.sh

PROFILE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCEOS_IMPL="$PROFILE_DIR/bin/sourceos"
SCREENSHOT_IMPL="$PROFILE_DIR/bin/mac-screenshot.sh"

DEST_DIR="${HOME}/.local/bin"
SOURCEOS_DEST="$DEST_DIR/sourceos"
SCREENSHOT_DEST="$DEST_DIR/mac-screenshot.sh"

CFG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/sourceos"
PROFILE_FILE="$CFG_DIR/profile.path"

info(){ printf "INFO: %s\n" "$*" >&2; }
warn(){ printf "WARN: %s\n" "$*" >&2; }
err(){ printf "ERROR: %s\n" "$*" >&2; }

install_sourceos_wrapper(){
  cat > "$SOURCEOS_DEST" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

PROFILE_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/sourceos/profile.path"
PROFILE_DIR="$(cat "$PROFILE_FILE" 2>/dev/null || true)"

if [[ -z "$PROFILE_DIR" ]]; then
  echo "ERROR: SourceOS profile path file missing or empty: $PROFILE_FILE" >&2
  echo "Re-run the workstation profile installer to regenerate it." >&2
  exit 2
fi

export SOURCEOS_PROFILE_DIR="$PROFILE_DIR"
exec "$PROFILE_DIR/bin/sourceos" "$@"
EOF
  chmod +x "$SOURCEOS_DEST"
}

install_screenshot_wrapper(){
  cat > "$SCREENSHOT_DEST" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

PROFILE_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/sourceos/profile.path"
PROFILE_DIR="$(cat "$PROFILE_FILE" 2>/dev/null || true)"

if [[ -z "$PROFILE_DIR" ]]; then
  echo "ERROR: SourceOS profile path file missing or empty: $PROFILE_FILE" >&2
  echo "Re-run the workstation profile installer to regenerate it." >&2
  exit 2
fi

exec bash "$PROFILE_DIR/bin/mac-screenshot.sh" "$@"
EOF
  chmod +x "$SCREENSHOT_DEST"
}

main(){
  [[ -x "$SOURCEOS_IMPL" ]] || { err "sourceos helper missing: $SOURCEOS_IMPL"; exit 2; }
  [[ -f "$SCREENSHOT_IMPL" ]] || { err "screenshot helper missing: $SCREENSHOT_IMPL"; exit 2; }

  mkdir -p "$DEST_DIR"
  mkdir -p "$CFG_DIR"

  printf '%s\n' "$PROFILE_DIR" > "$PROFILE_FILE"

  install_sourceos_wrapper
  install_screenshot_wrapper

  info "installed wrapper: $SOURCEOS_DEST"
  info "installed wrapper: $SCREENSHOT_DEST"
  info "pinned profile dir: $PROFILE_FILE"

  if [[ ":$PATH:" != *":$DEST_DIR:"* ]]; then
    warn "$DEST_DIR is not on PATH. Add it to your shell rc before using sourceos or mac-screenshot.sh."
  fi
}

main "$@"
