#!/usr/bin/env bash
# SourceOS Apple Silicon stage-2 boot deployment.
#
# Builds the nixos-apple-silicon installer ISO (637 MB) using the local
# lima-nixbuilder aarch64 VM, then writes it to a USB drive.  Once booted
# from USB via m1nt / U-Boot, run install-on-device.sh to install SourceOS.
#
# Prerequisites:
#   - lima-nixbuilder VM running: limactl start nixbuilder
#   - A USB drive (≥ 1 GB) that can be ERASED
#   - step2.sh already completed on the device (m1nt registered with kmutil)
#
# Usage:
#   bash scripts/deploy-stage2.sh [--usb /dev/diskX] [--dry-run]
#
# Alternatively — if Fedora (Asahi Linux) is already on the device:
#   Boot Fedora → run nixos-infect → enroll.sh  (see docs/bootstrap/M2_ENROLL.md)

set -euo pipefail

USB_DEV=""
DRY_RUN=0
LIMA_VM="nixbuilder"
ISO_CACHE="${HOME}/Library/Caches/sourceos/nixos-apple-silicon-installer.iso"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
ok()   { printf "  ${GREEN}✓${NC}  %s\n" "$*"; }
info() { printf "  ${CYAN}·${NC}  %s\n" "$*"; }
warn() { printf "  ${YELLOW}!${NC}  %s\n" "$*"; }
die()  { printf "  ${RED}✗  ERROR:${NC} %s\n" "$*" >&2; exit 1; }

while [[ $# -gt 0 ]]; do
    case "$1" in
        --usb)    USB_DEV="$2"; shift 2 ;;
        --dry-run) DRY_RUN=1; shift ;;
        --help|-h) grep '^#' "$0" | head -25 | sed 's/^# //'; exit 0 ;;
        *) die "Unknown argument: $1" ;;
    esac
done

[[ $DRY_RUN -eq 1 ]] && warn "DRY RUN — no writes will be performed"

echo
info "SourceOS Apple Silicon stage-2 deployment"
echo

# ── Step 1: Verify lima-nixbuilder is running ─────────────────────────────────

info "Checking lima nixbuilder VM..."
if ! limactl list 2>/dev/null | grep -q "^${LIMA_VM}.*Running"; then
    warn "Lima VM '${LIMA_VM}' is not running."
    info "Start it with: limactl start ${LIMA_VM}"
    die "Lima VM not running"
fi
ok "lima-nixbuilder is running"

# ── Step 2: Build installer ISO on lima ──────────────────────────────────────

info "Building nixos-apple-silicon installer ISO on lima (this takes ~3 min)..."

if [[ $DRY_RUN -eq 0 ]]; then
    LIMA_STORE_PATH=$(limactl shell "${LIMA_VM}" -- \
        nix build github:tpwrules/nixos-apple-silicon#installer-bootstrap \
        --no-link --print-out-paths 2>/dev/null | tail -1)

    [[ -n "${LIMA_STORE_PATH}" ]] || die "installer-bootstrap build produced no output"

    # Find the ISO file inside the store output directory
    LIMA_ISO=$(limactl shell "${LIMA_VM}" -- \
        bash -c "find '${LIMA_STORE_PATH}/iso' -name '*.iso' | head -1")

    [[ -n "${LIMA_ISO}" ]] || die "No .iso file found in ${LIMA_STORE_PATH}/iso"
    ok "Built: ${LIMA_ISO}"
else
    LIMA_ISO="/nix/store/EXAMPLE/iso/nixos-aarch64.iso"
    warn "[dry-run] would build github:tpwrules/nixos-apple-silicon#installer-bootstrap"
fi

# ── Step 3: Copy ISO from lima to macOS ──────────────────────────────────────

mkdir -p "$(dirname "${ISO_CACHE}")"

if [[ $DRY_RUN -eq 0 ]]; then
    if [[ -f "${ISO_CACHE}" ]]; then
        ok "ISO already cached at ${ISO_CACHE}"
    else
        info "Copying ISO from lima VM to ${ISO_CACHE} (~637 MB)..."
        # Get lima SSH port dynamically
        LIMA_PORT=$(limactl list --json 2>/dev/null | \
            python3 -c "import json,sys; vms=[json.loads(l) for l in sys.stdin if l.strip()]; \
            vm=next((v for v in vms if v['name']=='${LIMA_VM}'),None); \
            print(vm['sshLocalPort'] if vm else '')")
        [[ -n "${LIMA_PORT}" ]] || die "Could not determine lima SSH port"

        # shellcheck disable=SC2034  # diagnostic capture, kept intentionally
        LIMA_KEY="$(limactl shell "${LIMA_VM}" -- \
            bash -c 'cat /proc/1/environ 2>/dev/null | tr \\0 \\n | grep SSH_AUTH' 2>/dev/null || true)"

        scp -P "${LIMA_PORT}" \
            -i "${HOME}/.lima/_config/user" \
            -o StrictHostKeyChecking=no \
            -o UserKnownHostsFile=/dev/null \
            -o IdentitiesOnly=yes \
            "$(whoami)@127.0.0.1:${LIMA_ISO}" \
            "${ISO_CACHE}"
        ok "ISO saved to ${ISO_CACHE}"
    fi
else
    warn "[dry-run] would copy ISO from lima:${LIMA_ISO} → ${ISO_CACHE}"
fi

# ── Step 4: Write ISO to USB ──────────────────────────────────────────────────

if [[ -z "${USB_DEV}" ]]; then
    echo
    warn "No USB device specified (--usb /dev/diskX)."
    echo
    info "Available removable disks:"
    diskutil list external physical 2>/dev/null | grep -E "^/dev|SIZE" | head -20 || true
    echo
    info "Identify your USB drive above, then run:"
    info "  bash scripts/deploy-stage2.sh --usb /dev/diskX"
    echo
    info "Or use the ALTERNATIVE PATH (if Fedora Asahi already on device):"
    info "  1. Reboot → select Fedora in startup picker"
    info "  2. From Fedora:  curl -L https://raw.githubusercontent.com/elitak/nixos-infect/master/nixos-infect | NIX_CHANNEL=nixos-unstable NO_REBOOT=1 bash"
    info "  3. Clone:  git clone https://github.com/SourceOS-Linux/source-os.git /opt/source-os"
    info "  4. Reboot into NixOS"
    info "  5. sudo bash /opt/source-os/scripts/enroll.sh"
    echo
    [[ $DRY_RUN -eq 1 ]] && { warn "DRY RUN complete."; exit 0; }
    exit 0
fi

# Validate USB device
diskutil info "${USB_DEV}" >/dev/null 2>&1 || die "Device ${USB_DEV} not found"

DISK_NAME=$(diskutil info "${USB_DEV}" | grep "Device / Media Name" | awk -F': ' '{print $2}' | xargs)
DISK_SIZE=$(diskutil info "${USB_DEV}" | grep "Disk Size" | awk -F': ' '{print $2}' | awk '{print $1,$2}')
# shellcheck disable=SC2034  # informational probe, kept intentionally
IS_INTERNAL=$(diskutil info "${USB_DEV}" | grep "Solid State" | head -1)

echo
warn "About to ERASE ${USB_DEV} (${DISK_NAME}, ${DISK_SIZE})"
warn "This is IRREVERSIBLE and will destroy all data on ${USB_DEV}."
echo
read -rp "Type YES to continue: " confirm
[[ "${confirm}" == "YES" ]] || die "Aborted."

if [[ $DRY_RUN -eq 0 ]]; then
    info "Unmounting ${USB_DEV}..."
    diskutil unmountDisk "${USB_DEV}" || true

    # Convert /dev/diskX → /dev/rdiskX for raw access (much faster)
    RAW_DEV="${USB_DEV/\/dev\/disk/\/dev\/rdisk}"

    info "Writing ISO to ${RAW_DEV} (~637 MB, ~30–90 sec)..."
    sudo dd if="${ISO_CACHE}" of="${RAW_DEV}" bs=4m conv=sync status=progress
    sync

    info "Syncing..."
    diskutil eject "${USB_DEV}" 2>/dev/null || true
    ok "USB drive written and ejected."
else
    warn "[dry-run] would: diskutil unmountDisk ${USB_DEV} && sudo dd if=${ISO_CACHE} of=${USB_DEV/\/dev\/disk/\/dev\/rdisk} bs=4m"
fi

# ── Step 5: Boot instructions ─────────────────────────────────────────────────

echo
ok "Stage-2 deployment complete."
echo
info "Boot sequence:"
info "  1. Insert USB drive into the Mac"
info "  2. Reboot — hold power button to enter Startup Options"
info "  3. Select the NixOS USB drive"
info "  4. Wait for NixOS installer to boot (~1-2 min)"
info "  5. Run install-on-device.sh as root:"
info ""
info "     curl -fsSL https://raw.githubusercontent.com/SourceOS-Linux/source-os/main/scripts/install-on-device.sh | sudo bash"
info ""
info "  6. After install-on-device.sh completes and you reboot into SourceOS:"
info "     sudo bash /opt/source-os/scripts/enroll.sh"
echo
