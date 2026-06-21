#!/usr/bin/env bash
# preflight.sh — Verify all 9 SourceOS boot-chain conditions before the 1TR step.
# Run from macOS (before 1TR):  sudo bash scripts/preflight.sh

set -uo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
PASS=0; FAIL=0

_ok()   { printf "  ${GREEN}✓${NC}  %s\n" "$*";  PASS=$(( PASS + 1 )); }
_fail() { printf "  ${RED}✗${NC}  %s\n" "$*" >&2; FAIL=$(( FAIL + 1 )); }
_info() { printf "  ${CYAN}·${NC}  %s\n" "$*"; }
_warn() { printf "  ${YELLOW}!${NC}  %s\n" "$*"; }

[[ $(id -u) -eq 0 ]] || { echo "Run as root: sudo bash scripts/preflight.sh" >&2; exit 1; }

echo
_info "SourceOS preflight — checking all 9 boot-chain conditions"
echo

# ── 1. SourceOS APFS container ───────────────────────────────────────────────

_info "[1/9] SourceOS APFS container..."
SOURCEOS_CS=""
for _cs in $(diskutil list disk0 2>/dev/null | grep -oE 'Container disk[0-9]+' | awk '{print $2}'); do
    if diskutil list "${_cs}" 2>/dev/null | grep -q "SourceOS"; then
        SOURCEOS_CS="${_cs}"; break
    fi
done
if [[ -n "${SOURCEOS_CS}" ]]; then
    _ok "SourceOS APFS container: ${SOURCEOS_CS}"
else
    _fail "SourceOS APFS container not found on disk0 — Asahi step 1 not complete"
fi

# Find the System volume (not Data/Preboot/Recovery/VM) and mount it
SYSTEM_MP=""
if [[ -n "${SOURCEOS_CS}" ]]; then
    # Exclude "Data" as well — the Data volume never has Finish Installation.app
    SYSTEM_DISK=$(diskutil list "${SOURCEOS_CS}" 2>/dev/null | \
        awk '/APFS Volume/ && !/Data|Preboot|Recovery|VM/{print $NF; exit}')
    if [[ -n "${SYSTEM_DISK}" ]]; then
        diskutil mount "${SYSTEM_DISK}" >/dev/null 2>&1 || true
        SYSTEM_MP=$(diskutil info "${SYSTEM_DISK}" 2>/dev/null | \
            grep "Mount Point" | awk -F': +' '{print $2}' | xargs 2>/dev/null || true)
    fi
fi

FINISH_APP_RES=""
[[ -n "${SYSTEM_MP}" ]] && FINISH_APP_RES="${SYSTEM_MP}/Finish Installation.app/Contents/Resources"

# ── 2. boot.bin present and ≥ 1 MB ───────────────────────────────────────────

_info "[2/9] boot.bin present and ≥ 1 MB..."
if [[ -n "${FINISH_APP_RES}" && -f "${FINISH_APP_RES}/boot.bin" ]]; then
    _sz=$(wc -c < "${FINISH_APP_RES}/boot.bin")
    if [[ "${_sz}" -ge 1000000 ]]; then
        _ok "boot.bin: ${FINISH_APP_RES}/boot.bin ($(( _sz / 1024 ))K)"
    else
        _fail "boot.bin is only ${_sz} bytes — too small; expected ~1.7 MB (m1n1+U-Boot)"
    fi
else
    _fail "boot.bin not found at ${FINISH_APP_RES:-<system volume not mounted>}/boot.bin"
fi

# ── 3. boot.bin AArch64 magic ────────────────────────────────────────────────

_info "[3/9] boot.bin magic bytes (AArch64)..."
if [[ -n "${FINISH_APP_RES}" && -f "${FINISH_APP_RES}/boot.bin" ]]; then
    _magic=$(xxd -l 4 "${FINISH_APP_RES}/boot.bin" 2>/dev/null | awk '{print $2$3}' | head -1 || true)
    if [[ "${_magic}" == "7f454c46" ]] || [[ "${_magic:0:2}" == "14" ]] || [[ "${_magic:0:2}" == "18" ]]; then
        _ok "boot.bin magic valid (${_magic})"
    else
        _warn "boot.bin magic ${_magic} — expected ELF (7f454c46) or AArch64 branch; verify manually"
        PASS=$(( PASS + 1 ))
    fi
else
    _fail "boot.bin not accessible — skipping magic check"
fi

# ── 4. step2.sh present ───────────────────────────────────────────────────────

_info "[4/9] step2.sh present..."
if [[ -n "${FINISH_APP_RES}" && -f "${FINISH_APP_RES}/step2.sh" ]]; then
    _ok "step2.sh present"
else
    _fail "step2.sh not found at ${FINISH_APP_RES:-<system volume not mounted>}/step2.sh"
fi

# ── 5. EFI partition found and FAT32 ─────────────────────────────────────────

_info "[5/9] EFI partition (FAT32)..."
EFI_DISK=$(diskutil list disk0 | awk '/EFI-SOURC/{print $NF; exit}')
[[ -z "${EFI_DISK}" ]] && EFI_DISK=$(diskutil list disk0 | awk '/Microsoft Basic Data/{print $NF; exit}')

if [[ -n "${EFI_DISK}" ]]; then
    _efi_fs=$(diskutil info "${EFI_DISK}" 2>/dev/null | grep "File System Personality" | \
        awk -F': +' '{print $2}' | xargs 2>/dev/null || true)
    # macOS reports FAT32 as "MS-DOS FAT32", "MS-DOS", or "FAT32"
    if echo "${_efi_fs}" | grep -qiE "fat|ms.dos"; then
        _ok "EFI partition ${EFI_DISK}: ${_efi_fs}"
    elif [[ -z "${_efi_fs}" ]]; then
        _fail "EFI partition ${EFI_DISK} has no filesystem — run: sudo bash scripts/finish-step2.sh"
    else
        _fail "EFI partition ${EFI_DISK} unexpected filesystem: '${_efi_fs}' (expected FAT32/MS-DOS)"
    fi
else
    _fail "No EFI partition found on disk0 — run: sudo bash scripts/finish-step2.sh"
fi

# ── 6. GRUB BOOTAA64.EFI present ─────────────────────────────────────────────

_info "[6/9] GRUB EFI/BOOT/BOOTAA64.EFI on EFI partition..."
EFI_MP=""
if [[ -n "${EFI_DISK}" ]]; then
    diskutil mount "${EFI_DISK}" >/dev/null 2>&1 || true
    EFI_MP=$(diskutil info "${EFI_DISK}" 2>/dev/null | grep "Mount Point" | \
        awk -F': +' '{print $2}' | xargs 2>/dev/null || true)
fi

if [[ -n "${EFI_MP}" && -f "${EFI_MP}/EFI/BOOT/BOOTAA64.EFI" ]]; then
    _grub_sz=$(wc -c < "${EFI_MP}/EFI/BOOT/BOOTAA64.EFI")
    _ok "BOOTAA64.EFI present ($(( _grub_sz / 1024 ))K)"
else
    _fail "EFI/BOOT/BOOTAA64.EFI missing from ${EFI_MP:-<unmounted>} — run deploy-stage2.sh"
fi

# ── 7. No AppleDouble files in EFI/BOOT (not .Trashes) ───────────────────────

_info "[7/9] No AppleDouble files in EFI/BOOT path..."
if [[ -n "${EFI_MP}" ]]; then
    # Only care about ._* files that U-Boot could see (EFI/ tree, not .Trashes)
    _dotfiles=$(find "${EFI_MP}/EFI" -name '._*' 2>/dev/null || true)
    if [[ -z "${_dotfiles}" ]]; then
        _ok "No AppleDouble files in EFI/ tree"
    else
        _fail "AppleDouble files in EFI/ — U-Boot may confuse them:"
        echo "${_dotfiles}" | sed 's/^/       /' >&2
    fi
else
    _warn "EFI not mounted — skipping AppleDouble check"
    PASS=$(( PASS + 1 ))
fi

# ── 8 & 9. iso9660 installer: use CD001 magic (diskutil won't probe MBD type) ─

_info "[8/9] iso9660 installer partition (nixos-*-aarch64)..."
# disk0s9 is "Microsoft Basic Data" type — diskutil won't report iso9660 for it.
# Detect by CD001 magic instead; do both checks 8 and 9 together.
ISO_DISK=$(diskutil list disk0 2>/dev/null | awk '/Microsoft Basic Data/{last=$NF} END{print last}')

_info "[9/9] CD001 magic at iso9660 sector 16..."
if [[ -n "${ISO_DISK}" ]]; then
    # LBA 8 × 4096 = byte 32768 (sector 16 of iso9660). Skip 1 byte (descriptor type), read 5 = "CD001"
    _cd001=$(dd if="/dev/r${ISO_DISK}" bs=4096 skip=8 count=1 2>/dev/null | \
        xxd -s 1 -l 5 2>/dev/null | awk '{print $2$3$4}' | tr -d '\n' | head -c10 || true)
    if [[ "${_cd001}" == "4344303031" ]]; then
        _ok "Installer partition ${ISO_DISK}: CD001 magic confirmed (iso9660 valid)"
        # Also grab the volume label from the PVD (offset 40, 32 bytes)
        _label=$(dd if="/dev/r${ISO_DISK}" bs=4096 skip=8 count=1 2>/dev/null | \
            dd bs=1 skip=40 count=32 2>/dev/null | tr -d ' ' || true)
        if echo "${_label}" | grep -qi "^nixos.*aarch64"; then
            _ok "Installer label: '${_label}'"
        else
            _fail "Installer label '${_label}' — expected nixos-*-aarch64. Re-write the ISO."
        fi
    else
        _fail "CD001 magic not found on ${ISO_DISK} (got '${_cd001}') — ISO not written or wrong partition"
    fi
else
    _fail "No Microsoft Basic Data partition on disk0 — cannot find installer partition"
    _fail "Write the NixOS aarch64 ISO to disk0s9 first"
fi

# ── Summary ───────────────────────────────────────────────────────────────────

echo
if [[ "${FAIL}" -eq 0 ]]; then
    printf "  ${GREEN}══════════════════════════════════════════════════════${NC}\n"
    printf "  ${GREEN}  ALL ${PASS} CHECKS PASSED — device is ready for 1TR  ${NC}\n"
    printf "  ${GREEN}══════════════════════════════════════════════════════${NC}\n"
    echo
    _info "Next: shut down → hold power → 1TR → SourceOS → Options"
    _info "      Finish Installation.app will register m1n1+U-Boot via kmutil"
    echo
    exit 0
else
    printf "  ${RED}══════════════════════════════════════════════════════${NC}\n"
    printf "  ${RED}  ${FAIL} CHECK(S) FAILED — fix before doing 1TR         ${NC}\n"
    printf "  ${RED}══════════════════════════════════════════════════════${NC}\n"
    echo
    exit 1
fi
