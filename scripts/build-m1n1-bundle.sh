#!/usr/bin/env bash
# build-m1n1-bundle.sh — Build a reproducible Apple Silicon boot bundle:
#   stage1  m1n1.macho   (CHAINLOADING=1 chainloader, blessed via kmutil)
#   stage2  boot.bin     (m1n1 + U-Boot + devicetrees, lives on the ESP)
#   grub    BOOTAA64.EFI (aarch64 GRUB with the iso9660 module)
#
# This is the ADVANCED / fallback path. Most users should use the official
# Asahi installer integration (scripts/get-sourceos.sh) which sources m1n1 and
# U-Boot from upstream Asahi and never needs this bundle. Use this when building
# a custom/offline image or pinning a specific m1n1.
#
# Runs on aarch64-linux (a CI self-hosted aarch64 runner, or the GCP no-SSH
# arm64 lane). NOT runnable on macOS — it cross-builds Linux/EFI binaries.
#
# Usage:
#   bash scripts/build-m1n1-bundle.sh OUTDIR [VERSION]
#
# Output (in OUTDIR):
#   m1n1.macho  boot.bin  BOOTAA64.EFI  manifest.json  SHA256SUMS
set -euo pipefail

OUTDIR="${1:?usage: build-m1n1-bundle.sh OUTDIR [VERSION]}"
VERSION="${2:-$(date -u +%Y%m%d)}"
mkdir -p "$OUTDIR"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

log() { printf '[m1n1-bundle] %s\n' "$*"; }

# ── 1. Obtain m1n1 + U-Boot ──────────────────────────────────────────────────
# Preferred: the nixos-apple-silicon flake packages (matches the running kernel).
# Fallback: build m1n1 from source with RELEASE=1 CHAINLOADING=1.
M1N1_MACHO=""; BOOT_BIN=""
if command -v nix >/dev/null 2>&1; then
  log "Trying nixos-apple-silicon flake packages..."
  NAS="github:tpwrules/nixos-apple-silicon"
  # uboot-asahi ships m1n1+u-boot already assembled as u-boot-nodtb.bin + m1n1;
  # the flake's 'm1n1' package is the chainloading stage1.
  if nix build --no-link --print-out-paths "$NAS#m1n1" 2>"$WORK/nas-m1n1.log"; then
    M1N1_OUT="$(nix build --no-link --print-out-paths "$NAS#m1n1" 2>/dev/null)"
    # stage1 macho for kmutil
    find "$M1N1_OUT" -name 'm1n1*.macho' -exec cp {} "$WORK/m1n1.macho" \; 2>/dev/null || true
    [ -f "$WORK/m1n1.macho" ] && M1N1_MACHO="$WORK/m1n1.macho"
  fi
  if nix build --no-link --print-out-paths "$NAS#uboot-asahi" 2>"$WORK/nas-uboot.log"; then
    UBOOT_OUT="$(nix build --no-link --print-out-paths "$NAS#uboot-asahi" 2>/dev/null)"
    # The assembled m1n1+u-boot payload (stage2) — name varies by version.
    find "$UBOOT_OUT" \( -name 'u-boot*.bin' -o -name 'boot.bin' -o -name 'm1n1*.bin' \) \
      -size +500k -exec cp {} "$WORK/boot.bin" \; 2>/dev/null || true
    [ -f "$WORK/boot.bin" ] && BOOT_BIN="$WORK/boot.bin"
  fi
fi

if [ -z "$M1N1_MACHO" ]; then
  log "Flake path unavailable — building m1n1 from source (RELEASE=1 CHAINLOADING=1)."
  command -v rustc >/dev/null 2>&1 || {
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain nightly
    # shellcheck disable=SC1091
    . "$HOME/.cargo/env"
  }
  rustup target add aarch64-unknown-none-softfloat 2>/dev/null || true
  git clone --recursive --depth=1 https://github.com/AsahiLinux/m1n1.git "$WORK/m1n1"
  make -C "$WORK/m1n1" RELEASE=1 CHAINLOADING=1 -j"$(nproc)"
  cp "$WORK/m1n1/build/m1n1.macho" "$WORK/m1n1.macho"
  M1N1_MACHO="$WORK/m1n1.macho"
fi

[ -n "$M1N1_MACHO" ] || { log "FATAL: could not obtain m1n1.macho"; exit 1; }

# ── 2. GRUB aarch64 EFI with iso9660 ─────────────────────────────────────────
if command -v grub-mkimage >/dev/null 2>&1 || command -v grub2-mkimage >/dev/null 2>&1; then
  GRUB_MKIMAGE="$(command -v grub-mkimage || command -v grub2-mkimage)"
  log "Building BOOTAA64.EFI via $GRUB_MKIMAGE"
  "$GRUB_MKIMAGE" -O arm64-efi -o "$WORK/BOOTAA64.EFI" -p /EFI/BOOT \
    normal linux iso9660 part_gpt fat ext2 search search_label configfile echo all_video
fi

# ── 3. Assemble bundle ───────────────────────────────────────────────────────
cp "$M1N1_MACHO" "$OUTDIR/m1n1.macho"
[ -n "$BOOT_BIN" ] && cp "$BOOT_BIN" "$OUTDIR/boot.bin" || log "WARN: no stage2 boot.bin (provide via nixos-apple-silicon or Asahi installer)"
[ -f "$WORK/BOOTAA64.EFI" ] && cp "$WORK/BOOTAA64.EFI" "$OUTDIR/BOOTAA64.EFI" || log "WARN: no GRUB BOOTAA64.EFI (grub-mkimage absent)"

# Manifest + checksums
cat > "$OUTDIR/manifest.json" <<EOF
{
  "name": "sourceos-m1n1-bundle",
  "version": "$VERSION",
  "arch": "aarch64",
  "builtAt": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "components": {
    "stage1": "m1n1.macho",
    "stage2": "boot.bin",
    "grub":   "BOOTAA64.EFI"
  },
  "notes": "stage1 blessed via kmutil from 1TR; stage2 + GRUB go on the ESP."
}
EOF

( cd "$OUTDIR" && sha256sum m1n1.macho boot.bin BOOTAA64.EFI manifest.json 2>/dev/null > SHA256SUMS || \
  shasum -a 256 m1n1.macho boot.bin BOOTAA64.EFI manifest.json 2>/dev/null > SHA256SUMS )

log "Bundle ready in $OUTDIR:"
ls -lh "$OUTDIR"
