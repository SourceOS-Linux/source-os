#!/bin/sh
# get-sourceos.sh — Seamless SourceOS install on Apple Silicon (M1/M2/M3…).
#
# Run this in macOS Terminal:
#   curl -fsSL https://get.sourceos.org | sh
#   (or: curl -fsSL https://raw.githubusercontent.com/SourceOS-Linux/source-os/main/scripts/get-sourceos.sh | sh)
#
# It wraps the OFFICIAL Asahi Linux installer, pointed at the SourceOS OS
# package. The Asahi installer does all the hard parts for you: it resizes
# macOS, creates partitions, installs firmware, installs the m1n1 + U-Boot
# bootloader, and walks you through the one-time recovery (1TR) step.
#
# The 1TR step — shut down, hold the power button until "startup options",
# then authenticate — is REQUIRED by Apple's secure boot and cannot be
# automated by anyone. The installer tells you exactly when and how.
#
# Override the OS package source (e.g. to pin a version) with:
#   SOURCEOS_INSTALLER_DATA=<url> curl -fsSL https://get.sourceos.org | sh
set -e

DEFAULT_DATA="https://github.com/SourceOS-Linux/source-os/releases/latest/download/installer_data.json"
INSTALLER_DATA="${SOURCEOS_INSTALLER_DATA:-$DEFAULT_DATA}"

if [ "$(uname -s)" != "Darwin" ]; then
  echo "This installer runs from macOS on Apple Silicon. For Intel/AMD or generic"
  echo "ARM machines, download an installer ISO from https://sourceos.org/download"
  exit 1
fi

cat <<'BANNER'
  ┌────────────────────────────────────────────────────────────┐
  │  SourceOS — Apple Silicon installer                          │
  │                                                              │
  │  Powered by the Asahi Linux installer. It will:              │
  │   1. Resize macOS and create the SourceOS partitions         │
  │   2. Install firmware + the m1n1/U-Boot bootloader           │
  │   3. Guide you through the one-time recovery (1TR) step       │
  │                                                              │
  │  macOS stays installed and bootable. Nothing is erased       │
  │  without your explicit confirmation.                         │
  └────────────────────────────────────────────────────────────┘
BANNER

echo
echo ">> Using OS package manifest: $INSTALLER_DATA"
echo ">> Launching the Asahi installer..."
echo

# The upstream Asahi installer honors INSTALLER_DATA to point at a custom
# os package manifest, so only SourceOS is offered.
export INSTALLER_DATA
curl -fsSL https://alx.sh | sh
