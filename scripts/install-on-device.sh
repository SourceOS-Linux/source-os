#!/usr/bin/env bash
# install-on-device.sh — Install SourceOS NixOS from within an Asahi Linux
# environment already booted on the device.
#
# Run this FROM the device after booting into the existing Asahi Linux
# (select "SourceOS" in the macOS boot picker, boot into whatever installer
# or base Linux is there, then run this script).
#
# What it does:
#   1. Installs Nix (multi-user) if not already present.
#   2. Formats the root and /boot partitions (EFI is left untouched).
#   3. Mounts the partition tree under /mnt.
#   4. Runs nixos-install with the SourceOS builder-aarch64 config.
#   5. Copies enroll.sh and repo into /mnt for post-install enrollment.
#
# Partition assumptions (Apple Silicon NVMe, verified via diskutil on macOS):
#   nvme0n1p4  — EFI  (FAT32, /boot/efi)           PARTUUID 23567348-cfb2-44af-905e-5fec69587f35
#   nvme0n1p5  — /boot (ext4, 1.1 GB)               PARTUUID c952115c-eafb-4836-8ba2-6f62a31bab66
#   nvme0n1p6  — /     (ext4, 171 GB)               PARTUUID 295e2392-cca2-4ddb-8532-f9517990ceb7
#
# Usage (as root from within the Asahi Linux environment):
#   curl -fsSL https://raw.githubusercontent.com/SourceOS-Linux/source-os/main/scripts/install-on-device.sh | sudo bash
#   OR: sudo bash /path/to/source-os/scripts/install-on-device.sh

set -euo pipefail

FLAKE_REF="${FLAKE_REF:-github:SourceOS-Linux/source-os}"
HOST="${HOST:-builder-aarch64}"
ROOT_DEV="${ROOT_DEV:-/dev/disk/by-partuuid/295e2392-cca2-4ddb-8532-f9517990ceb7}"
BOOT_DEV="${BOOT_DEV:-/dev/disk/by-partuuid/c952115c-eafb-4836-8ba2-6f62a31bab66}"
EFI_DEV="${EFI_DEV:-/dev/disk/by-partuuid/23567348-cfb2-44af-905e-5fec69587f35}"
MNT="${MNT:-/mnt}"
FORMAT="${FORMAT:-yes}"  # set FORMAT=no to skip mkfs

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
ok()   { printf "  ${GREEN}✓${NC}  %s\n" "$*"; }
info() { printf "  ${CYAN}·${NC}  %s\n" "$*"; }
warn() { printf "  ${YELLOW}!${NC}  %s\n" "$*"; }
die()  { printf "  ${RED}✗  ERROR:${NC} %s\n" "$*" >&2; exit 1; }

[[ $(id -u) -eq 0 ]] || die "Must run as root"

echo
info "SourceOS NixOS device installation"
info "Host config: ${HOST}"
info "Flake:       ${FLAKE_REF}"
echo

# ── Step 1: Ensure Nix is available ──────────────────────────────────────────

if ! command -v nix >/dev/null 2>&1; then
    info "Nix not found — installing via Determinate Systems installer..."
    curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
    # shellcheck source=/dev/null
    . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh || true
    ok "Nix installed"
else
    ok "Nix already available: $(nix --version)"
fi

# ── Step 2: Format partitions ─────────────────────────────────────────────────

if [[ "${FORMAT}" == "yes" ]]; then
    # Detect whether EFI partition needs formatting (0-byte size = no filesystem).
    EFI_SIZE=$(lsblk -bno SIZE "${EFI_DEV}" 2>/dev/null || blockdev --getsize64 "${EFI_DEV}" 2>/dev/null || echo "0")
    EFI_FS=$(blkid -s TYPE -o value "${EFI_DEV}" 2>/dev/null || true)
    FORMAT_EFI="no"
    if [[ -z "${EFI_FS}" ]]; then
        FORMAT_EFI="yes"
        warn "EFI partition has no filesystem — will format as FAT32."
    fi

    warn "About to FORMAT the SourceOS root and /boot partitions."
    warn "Root:  ${ROOT_DEV}"
    warn "Boot:  ${BOOT_DEV}"
    [[ "${FORMAT_EFI}" == "yes" ]] && warn "EFI:   ${EFI_DEV}  (FAT32 — no existing filesystem detected)"
    echo
    read -rp "Type YES to continue: " confirm
    [[ "${confirm}" == "YES" ]] || die "Aborted."

    if [[ "${FORMAT_EFI}" == "yes" ]]; then
        info "Formatting EFI (FAT32)..."
        mkfs.vfat -F 32 -n EFI "${EFI_DEV}"
        ok "EFI formatted"
    fi

    info "Formatting root (ext4)..."
    mkfs.ext4 -L nixos "${ROOT_DEV}"
    ok "Root formatted"

    info "Formatting /boot (ext4)..."
    mkfs.ext4 -L boot "${BOOT_DEV}"
    ok "/boot formatted"
else
    warn "FORMAT=no — skipping mkfs (reuse existing filesystems)"
fi

# ── Step 3: Mount ─────────────────────────────────────────────────────────────

info "Mounting partition tree under ${MNT}..."
mount "${ROOT_DEV}" "${MNT}"
mkdir -p "${MNT}/boot"
mount "${BOOT_DEV}" "${MNT}/boot"
mkdir -p "${MNT}/boot/efi"
mount "${EFI_DEV}" "${MNT}/boot/efi"
ok "Mounted: / → ${ROOT_DEV}, /boot → ${BOOT_DEV}, /boot/efi → ${EFI_DEV}"

# ── Step 4: Firmware availability check ──────────────────────────────────────

ASAHI_FW=""
for candidate in "${MNT}/boot/efi/asahi" "${MNT}/boot/asahi"; do
    if [[ -f "${candidate}/all_firmware.tar.gz" ]]; then
        ASAHI_FW="${candidate}"
        ok "Found Apple Silicon firmware at: ${ASAHI_FW}"
        break
    fi
done

if [[ -z "${ASAHI_FW}" ]]; then
    warn "Apple Silicon firmware not found at expected locations."
    warn "Wi-Fi and Bluetooth will not work after installation."
    warn "To fix later: re-run Asahi installer, or copy firmware manually."
fi

# ── Step 5: nixos-install ─────────────────────────────────────────────────────

info "Running nixos-install..."
info "Config: ${FLAKE_REF}#${HOST}"
echo

# nixos-install is provided by the nixos-install-tools package.
if ! command -v nixos-install >/dev/null 2>&1; then
    info "Installing nixos-install-tools..."
    nix-env -iA nixpkgs.nixos-install-tools 2>/dev/null || \
        nix profile install nixpkgs#nixos-install-tools
fi

nixos-install \
    --root "${MNT}" \
    --flake "${FLAKE_REF}#${HOST}" \
    --impure \
    --no-channel-copy

ok "nixos-install complete"

# ── Step 6: Set initial password ─────────────────────────────────────────────

echo
info "Set initial password for the 'sourceos' user:"
nixos-enter --root "${MNT}" -c 'passwd sourceos'

# ── Step 7: Copy repo for post-install enrollment ─────────────────────────────

REPO_DST="${MNT}/opt/source-os"
if [[ -d /opt/source-os ]] || [[ -d /opt/sourceos/source-os ]] || [[ -d "${HOME}/dev/source-os" ]]; then
    SRC_REPO="${HOME}/dev/source-os"
    [[ -d /opt/sourceos/source-os ]] && SRC_REPO="/opt/sourceos/source-os"
    [[ -d /opt/source-os ]] && SRC_REPO="/opt/source-os"
    info "Copying source-os repo to ${REPO_DST}..."
    mkdir -p "${REPO_DST}"
    cp -r "${SRC_REPO}/." "${REPO_DST}/"
    ok "Repo copied to ${REPO_DST}"
    info "After reboot, run: sudo bash /opt/source-os/scripts/enroll.sh"
fi

# ── Done ──────────────────────────────────────────────────────────────────────

echo
ok "SourceOS installation complete."
info "Unmounting..."
umount -R "${MNT}"
echo
info "Reboot and select 'SourceOS' in the boot picker to boot the new system."
info "Then run:  sudo bash /opt/source-os/scripts/enroll.sh"
echo
