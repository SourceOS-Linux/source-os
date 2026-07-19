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
# Partition auto-detection (Apple Silicon NVMe layout after SourceOS prep):
#   EFI   (~500 MB, FAT32, already formatted from macOS)  → /boot/efi
#   Boot  (~1.1 GB, iso9660, NixOS installer)             → formatted ext4 → /boot
#   Root  (Linux-filesystem GPT type 0FC63DAF, largest)   → formatted ext4 → /
# Override via ROOT_DEV / BOOT_DEV / EFI_DEV environment variables if needed.
#
# Usage (as root from within the Asahi Linux environment):
#   curl -fsSL https://raw.githubusercontent.com/SourceOS-Linux/source-os/main/scripts/install-on-device.sh | sudo bash
#   OR: sudo bash /path/to/source-os/scripts/install-on-device.sh

set -euo pipefail

FLAKE_REF="${FLAKE_REF:-github:SourceOS-Linux/source-os}"
# Arch-aware default host. builder-aarch64 is the Apple Silicon target; on
# x86_64 default to stable-x86_64. Override with HOST=<name>.
# NOTE: these are server-role configs (syncd/katello/sops). A clean end-user
# desktop host does not exist yet — see the "Generic/desktop host" gap.
case "$(uname -m)" in
  x86_64)  _default_host="stable-x86_64" ;;
  aarch64|arm64) _default_host="builder-aarch64" ;;
  *)       _default_host="stable-x86_64" ;;
esac
HOST="${HOST:-$_default_host}"
MNT="${MNT:-/mnt}"
FORMAT="${FORMAT:-yes}"  # set FORMAT=no to skip mkfs

# ── Partition auto-detection ───────────────────────────────────────────────────
# Override any of ROOT_DEV / BOOT_DEV / EFI_DEV via environment to skip
# auto-detection entirely (useful when the device layout differs from standard).
#
# Standard Apple Silicon layout after SourceOS prep:
#   - EFI  (~500 MB, FAT32)        — formatted from macOS by finish-step2.sh
#   - Boot (~1.1 GB, iso9660 now)  — NixOS installer; reformatted to ext4 here
#   - Root (~171 GB, Linux type)   — GPT type 0FC63DAF (Linux filesystem)
_auto_detect_parts() {
    local nvme
    nvme=$(lsblk -dno NAME,TYPE 2>/dev/null \
        | awk '$2=="disk"{print "/dev/"$1}' | grep -m1 nvme || true)
    [[ -n "$nvme" ]] || return 1

    local linux_type="0fc63daf-8483-4772-8e79-3d69d8477de4"
    ROOT_DEV=$(lsblk -rno NAME,PARTTYPE "$nvme" 2>/dev/null \
        | awk -v t="$linux_type" 'tolower($2)==t{print "/dev/"$1}' | tail -1)
    EFI_DEV=$(lsblk -rno NAME,FSTYPE "$nvme" 2>/dev/null \
        | awk '$2=="vfat"{print "/dev/"$1}' | head -1)
    BOOT_DEV=$(lsblk -rno NAME,FSTYPE "$nvme" 2>/dev/null \
        | awk '$2=="iso9660"{print "/dev/"$1}' | head -1)

    [[ -n "$ROOT_DEV" && -n "$EFI_DEV" && -n "$BOOT_DEV" ]]
}

if [[ -z "${ROOT_DEV+x}" ]] || [[ -z "${BOOT_DEV+x}" ]] || [[ -z "${EFI_DEV+x}" ]]; then
    _auto_detect_parts || true  # sets vars; errors handled below
fi

# Validate — give actionable message if any partition is missing
RED='\033[0;31m'; NC='\033[0m'
_check_dev() {
    local var="$1" val="$2" hint="$3"
    if [[ -z "$val" ]] || [[ ! -b "$val" ]]; then
        printf "${RED}✗  ERROR:${NC} %s not found (got '%s').\n" "$var" "$val" >&2
        printf "   Set %s=<device> in the environment to override.\n" "$var" >&2
        printf "   Hint: %s\n" "$hint" >&2
        exit 1
    fi
}
_check_dev ROOT_DEV "${ROOT_DEV:-}" "lsblk -o NAME,PARTTYPE,SIZE — look for 0fc63daf Linux-filesystem type, largest"
_check_dev BOOT_DEV "${BOOT_DEV:-}" "lsblk -o NAME,FSTYPE,SIZE — look for iso9660 partition (~1.1 GB)"
_check_dev EFI_DEV  "${EFI_DEV:-}"  "lsblk -o NAME,FSTYPE,SIZE — look for vfat partition (~500 MB)"
unset -f _auto_detect_parts _check_dev

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'
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
    # shellcheck disable=SC2034  # probe kept for diagnostics; format decision uses EFI_FS below
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
