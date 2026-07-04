#!/usr/bin/env bash
# finish-step2.sh — Complete the Asahi installer second step so the M2 boots
# directly into m1n1+U-Boot instead of stalling at the USB proxy.
#
# RUN THIS FROM macOS (not from Linux / not from 1TR).
#
# Background
# ──────────
# The Asahi installer has two steps:
#   Step 1 (macOS): registers m1n1 stage-1 as a custom kernel via kmutil,
#          creates the SourceOS APFS stub, downloads firmware.
#   Step 2 (1TR):   lowers the boot-security level (bputil -nc) and
#          registers the m1n1+U-Boot combined binary as the raw boot
#          payload (kmutil configure-boot -c boot.bin --raw).
#
# The device currently stalls at the m1n1 USB proxy because step 2 was
# never run.  The boot.bin (m1n1+U-Boot, ~1.7 MB) is already present in
# the Finish Installation app inside the SourceOS APFS stub.  All that is
# needed is to run step 2 from 1TR.
#
# What this script does (from macOS):
#   1. Verifies the SourceOS stub mounts and boot.bin is present.
#   2. Formats the EFI partition (disk0s4, currently 0-byte / no filesystem)
#      as FAT32 so U-Boot can find its ESP on first Linux boot.
#   3. Prints step-by-step instructions for completing step 2 from 1TR.
#
# Usage:
#   sudo bash scripts/finish-step2.sh
#
# After running this script, follow the printed 1TR instructions, then:
#   1. Insert the NixOS installer USB (built with deploy-stage2.sh).
#   2. Hold power → startup options → select SourceOS → boots m1n1+U-Boot.
#   3. U-Boot → boots from USB → NixOS installer.
#   4. Run: sudo bash /path/to/source-os/scripts/install-on-device.sh
#   5. Reboot → SourceOS → run: sudo bash /opt/source-os/scripts/enroll.sh

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
ok()   { printf "  ${GREEN}✓${NC}  %s\n" "$*"; }
info() { printf "  ${CYAN}·${NC}  %s\n" "$*"; }
warn() { printf "  ${YELLOW}!${NC}  %s\n" "$*"; }
die()  { printf "  ${RED}✗  ERROR:${NC} %s\n" "$*" >&2; exit 1; }

[[ $(id -u) -eq 0 ]] || die "Must run as root (sudo bash scripts/finish-step2.sh)"

echo
info "SourceOS — finishing Asahi installer step 2"
echo

# ── Step 1: Verify SourceOS stub ─────────────────────────────────────────────

info "Detecting SourceOS APFS container on disk0..."

SOURCEOS_CS=""
for _cs in $(diskutil list disk0 2>/dev/null | grep -oE 'Container disk[0-9]+' | awk '{print $2}'); do
    if diskutil list "${_cs}" 2>/dev/null | grep -q "SourceOS"; then
        SOURCEOS_CS="${_cs}"; break
    fi
done
[[ -n "${SOURCEOS_CS}" ]] || \
    die "Cannot find SourceOS APFS container on disk0. Is Asahi step 1 complete?"
ok "SourceOS APFS container: ${SOURCEOS_CS}"

SYSTEM_DISK=$(diskutil list "${SOURCEOS_CS}" 2>/dev/null | \
    awk '/APFS Volume/ && !/Preboot|Recovery|VM/{print $NF; exit}')
PREBOOT_DISK=$(diskutil list "${SOURCEOS_CS}" 2>/dev/null | \
    awk '/APFS Volume.*Preboot/{print $NF; exit}')
[[ -n "${SYSTEM_DISK}" ]]  || die "Cannot find SourceOS System volume in ${SOURCEOS_CS}"
[[ -n "${PREBOOT_DISK}" ]] || die "Cannot find SourceOS Preboot volume in ${SOURCEOS_CS}"

# EFI: prefer a partition labeled EFI-SOURC; fall back to first FAT32 on disk0
EFI_DISK=$(diskutil list disk0 | awk '/EFI-SOURC/{print $NF; exit}')
if [[ -z "${EFI_DISK}" ]]; then
    EFI_DISK=$(diskutil list disk0 | awk '/Microsoft Basic Data/{print $NF; exit}')
fi
[[ -n "${EFI_DISK}" ]] || die "Cannot find EFI partition on disk0. Reformat it manually."

info "Mounting SourceOS volumes..."
diskutil mount "${PREBOOT_DISK}" >/dev/null 2>&1 || true
diskutil mount "${SYSTEM_DISK}"  >/dev/null 2>&1 || true

PREBOOT_MP=$(diskutil info "${PREBOOT_DISK}" 2>/dev/null | grep "Mount Point" | awk -F': +' '{print $2}' | xargs)
SYSTEM_MP=$(diskutil info "${SYSTEM_DISK}"  2>/dev/null | grep "Mount Point" | awk -F': +' '{print $2}' | xargs)

[[ -n "${PREBOOT_MP}" && -d "${PREBOOT_MP}" ]] || die "SourceOS Preboot (${PREBOOT_DISK}) did not mount"
[[ -n "${SYSTEM_MP}"  && -d "${SYSTEM_MP}"  ]] || die "SourceOS System (${SYSTEM_DISK}) did not mount"

ok "SourceOS Preboot: ${PREBOOT_MP}"
ok "SourceOS System:  ${SYSTEM_MP}"

BOOT_BIN="${SYSTEM_MP}/Finish Installation.app/Contents/Resources/boot.bin"
STEP2_SH="${SYSTEM_MP}/Finish Installation.app/Contents/Resources/step2.sh"

[[ -f "${BOOT_BIN}" ]] || die "boot.bin missing at ${BOOT_BIN} — re-run the Asahi installer step 1"
[[ -f "${STEP2_SH}" ]] || die "step2.sh missing at ${STEP2_SH} — SourceOS stub may be corrupted"

BOOT_BIN_SIZE=$(wc -c < "${BOOT_BIN}")
ok "boot.bin present: ${BOOT_BIN} (${BOOT_BIN_SIZE} bytes)"

# Sanity check: boot.bin should be at least 1 MB (m1n1+U-Boot)
if [[ "${BOOT_BIN_SIZE}" -lt 1000000 ]]; then
    warn "boot.bin is unusually small (${BOOT_BIN_SIZE} bytes < 1 MB)."
    warn "Expected ~1.7 MB (m1n1+U-Boot combined)."
    warn "The boot.bin.v1.5.2.bak in the same directory was the previous version."
    die "boot.bin may be corrupted — inspect and replace before continuing."
fi
ok "boot.bin size looks valid ($(( BOOT_BIN_SIZE / 1024 / 1024 )) MB)"

# ── Step 2: Format EFI partition ─────────────────────────────────────────────

info "Checking EFI partition (${EFI_DISK})..."
EFI_TOTAL=$(diskutil info "${EFI_DISK}" 2>/dev/null | grep "Volume Total Space" | grep -oE '[0-9]+ Bytes' | awk '{print $1}' || echo "0")
EFI_LABEL=$(diskutil info "${EFI_DISK}" 2>/dev/null | grep "Volume Name" | awk -F': +' '{print $2}' | xargs || echo "")

if [[ "${EFI_TOTAL:-0}" == "0" ]]; then
    info "EFI partition has no filesystem (Volume Total Space = 0) — formatting as FAT32..."
    diskutil eraseVolume FAT32 "EFI-SOURC" "${EFI_DISK}"
    ok "EFI partition formatted as FAT32 (label: EFI-SOURC)"
else
    ok "EFI partition already has filesystem: ${EFI_LABEL} (${EFI_TOTAL} bytes)"
fi

# ── Step 3: Unmount SourceOS volumes ─────────────────────────────────────────

info "Unmounting SourceOS volumes..."
diskutil unmount "${SYSTEM_MP}"  >/dev/null 2>&1 || true
diskutil unmount "${PREBOOT_MP}" >/dev/null 2>&1 || true
ok "Volumes unmounted"

# ── Step 4: Print 1TR instructions ───────────────────────────────────────────

echo
printf "${GREEN}══════════════════════════════════════════════════════════════${NC}\n"
printf "${GREEN}  EFI formatted ✓  boot.bin ready ✓  — Next: run step 2 in 1TR${NC}\n"
printf "${GREEN}══════════════════════════════════════════════════════════════${NC}\n"
echo
info "HOW TO COMPLETE STEP 2 (ONE TRUE RECOVERY):"
echo
warn "  1. Shut down this Mac completely (Apple → Shut Down)."
warn "     Wait 10 seconds until the screen is fully dark."
echo
warn "  2. Press and HOLD the power button."
warn "     Keep holding until you see 'Loading startup options...' on screen."
warn "     (Do NOT tap — hold continuously from a cold/dark state.)"
echo
warn "  3. In the startup picker, select  SourceOS  (NOT macOS)."
warn "     Then click 'Options' below it."
echo
warn "  4. Enter your macOS credentials when prompted."
echo
warn "  5. A Terminal window will open automatically running:"
warn "     'Finish Installation.app' (the Asahi installer step 2)."
warn "     If it does NOT open automatically:"
warn "       • Open Terminal from Utilities menu"
warn "       • Run: bash '/Volumes/SourceOS/Finish Installation.app/Contents/Resources/step2.sh'"
echo
warn "  6. Follow prompts — you will be asked for credentials TWICE:"
warn "       a. bputil: lowers boot security for SourceOS (normal — does NOT affect macOS)"
warn "       b. kmutil: registers the m1n1+U-Boot binary as the boot payload"
echo
warn "  7. The script reboots the system when done."
echo
info "AFTER STEP 2 REBOOTS:"
echo
warn "  8. Boot picks → select SourceOS → device now boots directly to U-Boot."
warn "     (No more proxy stall.)"
echo
warn "  9. INSERT NixOS installer USB BEFORE selecting SourceOS in step 8."
warn "     Build the USB first if you haven't:  bash scripts/deploy-stage2.sh --usb /dev/diskX"
echo
warn " 10. U-Boot boots from USB → NixOS installer → login as root → run:"
warn "     sudo bash /path/to/source-os/scripts/install-on-device.sh"
echo
warn " 11. After install: reboot → SourceOS NixOS → run:"
warn "     sudo bash /opt/source-os/scripts/enroll.sh"
echo
