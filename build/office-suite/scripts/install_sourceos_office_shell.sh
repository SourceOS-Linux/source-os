#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
BIN_DIR="$HOME/.local/bin"

"$ROOT/build/office-suite/scripts/install_office_desktop_entry.sh"
"$ROOT/build/office-suite/scripts/verify_office_desktop_entry.sh"

mkdir -p "$BIN_DIR"
cp "$ROOT/build/office-suite/scripts/sourceos-office" "$BIN_DIR/sourceos-office"
cp "$ROOT/build/office-suite/scripts/install_sourceos_office_shell.sh" "$BIN_DIR/install_sourceos_office_shell.sh"
cp "$ROOT/build/office-suite/scripts/office_shell_verify.sh" "$BIN_DIR/office_shell_verify.sh"
cp "$ROOT/build/office-suite/scripts/office_new.sh" "$BIN_DIR/office_new.sh"
cp "$ROOT/build/office-suite/templates/sovereign/sourceos-default-writer.fodt" "$BIN_DIR/sourceos-default-writer.fodt"
chmod +x "$BIN_DIR/sourceos-office" "$BIN_DIR/install_sourceos_office_shell.sh" "$BIN_DIR/office_shell_verify.sh" "$BIN_DIR/office_new.sh"

if [[ -x "$ROOT/build/office-suite/scripts/verify_office_suite_profile.sh" ]]; then
  "$ROOT/build/office-suite/scripts/verify_office_suite_profile.sh"
fi

echo "installed sourceos-office to $BIN_DIR/sourceos-office"
echo "installed install_sourceos_office_shell.sh to $BIN_DIR/install_sourceos_office_shell.sh"
echo "installed office_shell_verify.sh to $BIN_DIR/office_shell_verify.sh"
echo "installed office_new.sh to $BIN_DIR/office_new.sh"
echo "installed sourceos-default-writer.fodt to $BIN_DIR/sourceos-default-writer.fodt"
echo "SourceOS office shell install completed"
