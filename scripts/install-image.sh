#!/usr/bin/env bash
# install-image.sh — SourceOS clean-disk installer for the public ISO (PC / ARM).
#
# This is the BLANK-DISK path: it creates a fresh GPT layout (ESP + root) on a
# target disk and installs the SourceOS GNOME desktop. For Apple Silicon use the
# Asahi path (get-sourceos.sh); for a disk that is already partitioned by the
# Asahi flow use install-on-device.sh.
#
# SAFETY: this ERASES the target disk. It requires an explicit disk argument,
# refuses the disk the live system is running from, shows the plan, and waits
# for you to type the disk name to confirm.
#
# Usage (run as root in the SourceOS live installer):
#   sudo install-image.sh                              # interactive disk pick, desktop edition
#   sudo install-image.sh /dev/nvme0n1                 # target disk, desktop edition
#   sudo install-image.sh --edition server /dev/sda    # server edition
#   sudo install-image.sh --edition edge   /dev/sda    # edge/appliance edition
#
# Env overrides: FLAKE_REF (default github:SourceOS-Linux/source-os),
#                HOSTNAME (default sourceos).
set -euo pipefail

FLAKE_REF="${FLAKE_REF:-github:SourceOS-Linux/source-os}"
TARGET_HOSTNAME="${HOSTNAME:-sourceos}"
MNT=/mnt

# ── Args ──────────────────────────────────────────────────────────────────────
# --edition <desktop|server|edge>   base edition (default desktop)
# --system  <store-path>            install a PREBUILT system toplevel instead of
#                                   composing+building a flake (faster; offline;
#                                   used by the install-to-disk test). Env: SOURCEOS_SYSTEM.
# --assume-yes                      skip the interactive typed confirmation (for
#                                   unattended/automated installs). Env: SOURCEOS_ASSUME_YES=1.
EDITION="desktop"
PREBUILT_SYSTEM="${SOURCEOS_SYSTEM:-}"
ASSUME_YES="${SOURCEOS_ASSUME_YES:-0}"
ARGS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --edition)     EDITION="${2:?--edition needs a value: desktop|server|edge}"; shift 2 ;;
    --system)      PREBUILT_SYSTEM="${2:?--system needs a store path}"; shift 2 ;;
    --assume-yes|-y) ASSUME_YES=1; shift ;;
    --) shift; while [[ $# -gt 0 ]]; do ARGS+=("$1"); shift; done ;;
    -*) echo "Unknown flag '$1'" >&2; exit 1 ;;
    *)  ARGS+=("$1"); shift ;;
  esac
done
set -- "${ARGS[@]:-}"
case "$EDITION" in
  desktop) MODULE="desktop-gnome" ;;
  server)  MODULE="server" ;;
  edge)    MODULE="edge" ;;
  *) echo "Unknown edition '$EDITION' (use: desktop | server | edge)" >&2; exit 1 ;;
esac
MODULE="${MODULE_OVERRIDE:-$MODULE}"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
ok()   { printf "  ${GREEN}✓${NC}  %s\n" "$*"; }
info() { printf "  ${CYAN}·${NC}  %s\n" "$*"; }
warn() { printf "  ${YELLOW}!${NC}  %s\n" "$*"; }
die()  { printf "  ${RED}✗  ERROR:${NC} %s\n" "$*" >&2; exit 1; }

[[ $(id -u) -eq 0 ]] || die "Run as root (sudo install-image.sh)"

# ── Identify the disk the live system runs from, so we never offer/erase it ──
LIVE_SRC="$(findmnt -no SOURCE / 2>/dev/null || true)"
LIVE_DISK=""
[[ -n "$LIVE_SRC" ]] && LIVE_DISK="/dev/$(lsblk -no PKNAME "$LIVE_SRC" 2>/dev/null | head -1)"

list_disks() { lsblk -dno NAME,SIZE,MODEL,TYPE | awk '$NF=="disk"{print "/dev/"$1"  "$2"  "substr($0, index($0,$3))}'; }

# ── Choose target ─────────────────────────────────────────────────────────────
TARGET="${1:-}"
if [[ -z "$TARGET" ]]; then
  echo; info "Available disks (the live USB/ISO disk is excluded):"; echo
  list_disks | grep -v -- "${LIVE_DISK:-__none__}" | sed 's/^/    /'
  echo
  read -rp "  Target disk (e.g. /dev/nvme0n1 or /dev/sda): " TARGET
fi
[[ -b "$TARGET" ]] || die "Not a block device: $TARGET"
[[ "$TARGET" != "$LIVE_DISK" ]] || die "Refusing to erase the live medium ($TARGET)."

# ── Confirm (typed) ───────────────────────────────────────────────────────────
SIZE="$(lsblk -dno SIZE "$TARGET")"
echo
warn "About to ERASE ${TARGET} (${SIZE}) and install SourceOS:"
echo  "      1. New GPT label"
echo  "      2. ESP   512 MiB  FAT32  → /boot"
echo  "      3. Root  rest      ext4   → /   (${EDITION} edition)"
echo
if [[ "$ASSUME_YES" == "1" ]]; then
  warn "--assume-yes: skipping typed confirmation for ${TARGET}."
else
  read -rp "  Type the disk name ('${TARGET}') to confirm: " CONFIRM
  [[ "$CONFIRM" == "$TARGET" ]] || die "Confirmation did not match. Aborted — nothing changed."
fi

# Partition suffix: nvme0n1 -> nvme0n1p1 ; sda -> sda1
part() { case "$TARGET" in *[0-9]) echo "${TARGET}p$1" ;; *) echo "${TARGET}$1" ;; esac; }
ESP="$(part 1)"; ROOT="$(part 2)"

# ── Partition + format ────────────────────────────────────────────────────────
info "Partitioning ${TARGET}..."
wipefs -a "$TARGET" >/dev/null 2>&1 || true
sgdisk --zap-all "$TARGET" >/dev/null
sgdisk -n1:0:+512M -t1:ef00 -c1:EFI "$TARGET" >/dev/null
sgdisk -n2:0:0     -t2:8300 -c2:nixos "$TARGET" >/dev/null
partprobe "$TARGET" 2>/dev/null || true; udevadm settle 2>/dev/null || true; sleep 1

info "Formatting..."
mkfs.fat -F32 -n EFI "$ESP" >/dev/null
mkfs.ext4 -F -L nixos "$ROOT" >/dev/null
ok "ESP=$ESP  ROOT=$ROOT"

# ── Mount ─────────────────────────────────────────────────────────────────────
mount "$ROOT" "$MNT"
mkdir -p "$MNT/boot"
mount "$ESP" "$MNT/boot"

if [[ -n "$PREBUILT_SYSTEM" ]]; then
  # ── Install a PREBUILT system toplevel (offline; used by the install test) ──
  [[ -e "$PREBUILT_SYSTEM" ]] || die "--system path does not exist: $PREBUILT_SYSTEM"
  info "Installing prebuilt system: $PREBUILT_SYSTEM"
  nixos-install --root "$MNT" --system "$PREBUILT_SYSTEM" --no-root-passwd --no-channel-copy
else
  # ── Compose a per-machine flake: hardware-config + the SourceOS module ──
  info "Generating hardware configuration..."
  nixos-generate-config --root "$MNT" --no-filesystems >/dev/null 2>&1 || nixos-generate-config --root "$MNT"
  # Keep the generated hardware-configuration.nix; replace configuration with a
  # flake that pulls SourceOS and applies the edition module.
  NIXDIR="$MNT/etc/nixos"
  mkdir -p "$NIXDIR"
  cat > "$NIXDIR/flake.nix" <<EOF
{
  description = "SourceOS machine";
  inputs.sourceos.url = "${FLAKE_REF}";
  inputs.nixpkgs.follows = "sourceos/nixpkgs";
  outputs = { self, nixpkgs, sourceos }: {
    nixosConfigurations.${TARGET_HOSTNAME} = nixpkgs.lib.nixosSystem {
      modules = [
        ./hardware-configuration.nix
        sourceos.nixosModules.${MODULE}
        { networking.hostName = "${TARGET_HOSTNAME}"; }
      ];
    };
  };
}
EOF
  ok "Wrote $NIXDIR/flake.nix (module: ${MODULE})"

  # ── Install ─────────────────────────────────────────────────────────────────
  info "Running nixos-install (this builds the system; grab a coffee)..."
  nixos-install --root "$MNT" --flake "$NIXDIR#${TARGET_HOSTNAME}" --no-channel-copy
fi

# ── Password (interactive installs only; unattended uses --no-root-passwd) ──────
if [[ "$ASSUME_YES" != "1" && -z "$PREBUILT_SYSTEM" ]]; then
  echo; info "Set a password for the 'sourceos' user:"
  nixos-enter --root "$MNT" -c 'passwd sourceos'
fi

echo
ok "SourceOS installed to ${TARGET}."
info "Remove the USB and reboot. After first boot you can apply the GNOME polish layer:"
info "  bash <(curl -fsSL https://raw.githubusercontent.com/SourceOS-Linux/source-os/main/profiles/linux-dev/workstation-v0/gnome/apply.sh)"
echo
if [[ "$ASSUME_YES" == "1" ]]; then
  umount -R "$MNT" 2>/dev/null || true
  ok "--assume-yes: install complete, left unmounted (no reboot)."
else
  read -rp "  Reboot now? [y/N] " R; [[ "${R:-N}" =~ ^[Yy]$ ]] && { umount -R "$MNT"; reboot; }
fi
