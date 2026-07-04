#!/usr/bin/env bash
# build-asahi-package.sh — Build the SourceOS Apple Silicon OS package consumed
# by the official Asahi installer (referenced from asahi/installer_data.json).
#
# Produces, in OUTDIR:
#   sourceos-<version>-asahi-arm64.zip   — the installer package, containing:
#       esp/         EFI system partition tree (m1n1 stage2, GRUB, dtbs)
#       boot.img     ext4 /boot image
#       root.img     ext4 / image (the SourceOS aarch64 system)
#   <zip>.sha256
#
# Runs on aarch64-linux (CI self-hosted aarch64 runner). Uses the
# nixos-apple-silicon flake for the Apple Silicon firmware/bootloader bits, so
# m1n1 + U-Boot come from upstream Asahi — we do NOT hand-build them here.
#
# Usage: bash scripts/build-asahi-package.sh OUTDIR [VERSION]
#
# STATUS: scaffolding — the toplevel build + image assembly are wired, but the
# exact nixos-apple-silicon installer-package attribute and the esp/ layout must
# be validated on a real aarch64 builder before the seamless path is advertised.
set -euo pipefail

OUTDIR="${1:?usage: build-asahi-package.sh OUTDIR [VERSION]}"
VERSION="${2:-26.11}"
HOST="${HOST:-builder-aarch64}"
FLAKE="${FLAKE:-.}"
mkdir -p "$OUTDIR"
WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
log() { printf '[asahi-package] %s\n' "$*"; }

command -v nix >/dev/null 2>&1 || { log "FATAL: nix required"; exit 1; }
[ "$(uname -m)" = "aarch64" ] || log "WARN: not aarch64 — image build will need emulation/remote builder"

# 1. Build the SourceOS aarch64 system closure.
log "Building toplevel for $HOST ..."
TOP=$(nix build --no-link --print-out-paths --impure \
  "${FLAKE}#nixosConfigurations.${HOST}.config.system.build.toplevel")
log "toplevel: $TOP"

# 2. Obtain Apple Silicon firmware/bootloader via nixos-apple-silicon.
#    (uboot-asahi assembles m1n1 + U-Boot; firmware comes from the target's
#    own extraction during install — the installer copies it.)
NAS="github:tpwrules/nixos-apple-silicon"
log "Building uboot-asahi (m1n1 + U-Boot) ..."
UBOOT=$(nix build --no-link --print-out-paths "$NAS#uboot-asahi" 2>/dev/null || true)
[ -n "$UBOOT" ] && log "uboot-asahi: $UBOOT" || log "WARN: uboot-asahi build failed — esp/ will be incomplete"

# 3. Assemble the installer package layout.
PKGROOT="$WORK/pkg"
mkdir -p "$PKGROOT/esp/m1n1" "$PKGROOT/esp/EFI/BOOT"

# m1n1 stage2 (boot.bin) + GRUB into the ESP tree.
if [ -n "$UBOOT" ]; then
  find "$UBOOT" \( -name 'u-boot*.bin' -o -name 'm1n1*.bin' -o -name 'boot.bin' \) \
    -size +500k -exec cp {} "$PKGROOT/esp/m1n1/boot.bin" \; 2>/dev/null || true
fi
if command -v grub-mkimage >/dev/null 2>&1 || command -v grub2-mkimage >/dev/null 2>&1; then
  GM="$(command -v grub-mkimage || command -v grub2-mkimage)"
  "$GM" -O arm64-efi -o "$PKGROOT/esp/EFI/BOOT/BOOTAA64.EFI" -p /EFI/BOOT \
    normal linux iso9660 part_gpt fat ext2 search search_label configfile echo all_video
fi

# 4. Build boot.img + root.img ext4 images and populate root via nixos-install.
#    root.img holds the Nix store + the system; boot.img holds the kernel/initrd.
#    Requires root (loop mount + mounts). The asahi-package CI job runs us under sudo.
if [ "$(id -u)" -ne 0 ]; then
  log "WARN: not root — creating empty sized images only; run under sudo to populate."
fi
ROOT_BYTES=$(du -sb "$TOP" | awk '{print $1}')
ROOT_MB=$(( (ROOT_BYTES / 1024 / 1024) * 13 / 10 + 1024 ))   # +30% headroom + 1G
truncate -s "${ROOT_MB}M" "$PKGROOT/root.img"
mkfs.ext4 -q -L nixos "$PKGROOT/root.img"
truncate -s 1024M "$PKGROOT/boot.img"
mkfs.ext4 -q -L boot "$PKGROOT/boot.img"
log "root.img ${ROOT_MB}M, boot.img 1024M created."

if [ "$(id -u)" -eq 0 ] && command -v nixos-install >/dev/null 2>&1; then
  log "Populating images: loop-mounting and nixos-install --system ..."
  IMG_MNT="$WORK/imgmnt"; mkdir -p "$IMG_MNT"
  mount -o loop "$PKGROOT/root.img" "$IMG_MNT"
  mkdir -p "$IMG_MNT/boot"
  mount -o loop "$PKGROOT/boot.img" "$IMG_MNT/boot"
  # Install the prebuilt system closure into the image (no bootloader install —
  # the Asahi installer wires m1n1→U-Boot→the kernel from /boot at install time).
  nixos-install --root "$IMG_MNT" --system "$TOP" --no-root-passwd --no-channel-copy --no-bootloader || \
    log "WARN: nixos-install reported an error — inspect before publishing"
  umount -R "$IMG_MNT" || true
  log "Images populated."
else
  log "NOTE: skipped population (need root + nixos-install). Empty images produced;"
  log "      the asahi-package CI job runs this under sudo on the aarch64 runner."
fi

# 5. Zip the package.
ZIP="$OUTDIR/sourceos-${VERSION}-asahi-arm64.zip"
( cd "$PKGROOT" && zip -r -q "$ZIP" esp boot.img root.img )
( cd "$OUTDIR" && sha256sum "$(basename "$ZIP")" > "$(basename "$ZIP").sha256" 2>/dev/null || \
  shasum -a 256 "$(basename "$ZIP")" > "$(basename "$ZIP").sha256" )
log "Package: $ZIP"
ls -lh "$OUTDIR"
