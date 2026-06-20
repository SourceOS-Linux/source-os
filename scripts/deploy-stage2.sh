#!/usr/bin/env bash
# SourceOS Apple Silicon stage-2 boot deployment.
#
# Runs on macOS from this repo root after m1nt (step2.sh) is registered.
# Mounts the EFI partition and deploys the nixos-apple-silicon installer
# bootstrap so the device can boot into a NixOS installer environment.
#
# From within that installer environment, run:
#   sudo nixos-install --flake github:SociOS-Linux/source-os#builder-aarch64
#
# Prerequisites:
#   - sudo access (for mounting EFI partition)
#   - nix with aarch64-linux builder (lima-nixbuilder VM)
#   - step2.sh already completed (m1nt registered with kmutil)
#
# Usage:
#   bash scripts/deploy-stage2.sh [--dry-run]

set -euo pipefail

EFI_DEV="/dev/disk0s4"
EFI_MOUNT="/tmp/sourceos-efi"
DRY_RUN=0

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
ok()   { printf "  ${GREEN}✓${NC}  %s\n" "$*"; }
info() { printf "  ${CYAN}·${NC}  %s\n" "$*"; }
warn() { printf "  ${YELLOW}!${NC}  %s\n" "$*"; }
die()  { printf "  ${RED}✗  ERROR:${NC} %s\n" "$*" >&2; exit 1; }

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run) DRY_RUN=1; shift ;;
        --help|-h) grep '^#' "$0" | head -20 | sed 's/^# //'; exit 0 ;;
        *) die "Unknown argument: $1" ;;
    esac
done

[[ $DRY_RUN -eq 1 ]] && warn "DRY RUN — no changes will be made"

echo
info "SourceOS Apple Silicon stage-2 deployment"
echo

# ── Step 1: Build installer-bootstrap on aarch64 builder ─────────────────────

info "Building nixos-apple-silicon installer-bootstrap (via aarch64 builder)..."
BOOTSTRAP_STORE_PATH=""
if [[ $DRY_RUN -eq 0 ]]; then
    BOOTSTRAP_STORE_PATH=$(nix build \
        github:tpwrules/nixos-apple-silicon#installer-bootstrap \
        --system aarch64-linux \
        --no-link --print-out-paths 2>&1 | tail -1)
    [[ -n "${BOOTSTRAP_STORE_PATH}" ]] || die "installer-bootstrap build produced no output"
    ok "Built: ${BOOTSTRAP_STORE_PATH}"
else
    warn "[dry-run] would build github:tpwrules/nixos-apple-silicon#installer-bootstrap"
fi

# ── Step 2: Mount EFI partition ───────────────────────────────────────────────

info "Mounting EFI partition ${EFI_DEV} → ${EFI_MOUNT}"
if [[ $DRY_RUN -eq 0 ]]; then
    sudo mkdir -p "${EFI_MOUNT}"
    sudo mount -t msdos "${EFI_DEV}" "${EFI_MOUNT}" \
        || die "Could not mount ${EFI_DEV}. Check: diskutil list | grep EFI"
    ok "Mounted ${EFI_DEV} at ${EFI_MOUNT}"
fi

# ── Step 3: Deploy bootstrap to EFI ──────────────────────────────────────────

info "Deploying installer-bootstrap to EFI partition..."
if [[ $DRY_RUN -eq 0 ]]; then
    # nixos-apple-silicon installer-bootstrap produces a directory that should
    # be copied to the root of the EFI partition.
    sudo cp -rn "${BOOTSTRAP_STORE_PATH}/." "${EFI_MOUNT}/"
    sync
    ok "Deployed installer-bootstrap to ${EFI_MOUNT}"

    # Show what was written
    echo
    info "EFI partition contents:"
    ls "${EFI_MOUNT}/"
    echo
fi

# ── Step 4: Unmount ───────────────────────────────────────────────────────────

info "Unmounting EFI partition..."
if [[ $DRY_RUN -eq 0 ]]; then
    sudo umount "${EFI_MOUNT}"
    ok "Unmounted ${EFI_MOUNT}"
fi

# ── Step 5: Format Linux partitions ──────────────────────────────────────────

echo
warn "Linux root partition (disk0s6) must be formatted before nixos-install."
warn "This requires booting into a Linux environment first."
warn "The installer-bootstrap above will provide that environment on next boot."
echo
info "Next steps after reboot into SourceOS installer:"
info "  1. Format root:  sudo mkfs.ext4 -L nixos /dev/nvme0n1p6"
info "  2. Format /boot: sudo mkfs.ext4 -L boot  /dev/nvme0n1p5"
info "  3. Mount:        sudo mount /dev/nvme0n1p6 /mnt"
info "               sudo mkdir -p /mnt/boot && sudo mount /dev/nvme0n1p5 /mnt/boot"
info "               sudo mkdir -p /mnt/boot/efi && sudo mount /dev/nvme0n1p4 /mnt/boot/efi"
info "  4. Install:      sudo nixos-install --system aarch64-linux \\"
info "                       --flake github:SociOS-Linux/source-os#builder-aarch64"
info "  5. Set password: sudo nixos-enter --root /mnt -c 'passwd sourceos'"
echo

if [[ $DRY_RUN -eq 1 ]]; then
    warn "DRY RUN complete — no changes made."
    echo
    exit 0
fi

ok "Stage-2 deployment complete."
info "Reboot and select 'SourceOS' in the boot picker to enter the installer."
info "Hold power to enter Startup Options, then select SourceOS."
echo
