#!/usr/bin/env bash
# run-vm.sh — Portable QEMU launcher for SourceOS image testing.
# Boots a bootable SourceOS disk image (qcow2/raw) with a graphical display so a
# GUI agent (Agent-S, via the harness) can drive it. Accelerator is chosen per
# host: KVM on Linux (GCP/CI), HVF on macOS.
#
# Env:
#   IMG    path to a bootable disk image (e.g. a desktop qcow2)   [required]
#   ARCH   x86_64 | aarch64                                       [default x86_64]
#   MEM    guest RAM in MB                                        [default 4096]
#   VNC    VNC display number to expose (e.g. :0 → 5900)          [default :0]
#   HEADLESS  1 = no host window (display only via VNC)           [default 1]
#
# The harness starts this in the background, then drives the screen.
set -euo pipefail

IMG="${IMG:?set IMG=/path/to/bootable.qcow2}"
ARCH="${ARCH:-x86_64}"
MEM="${MEM:-4096}"
VNC="${VNC:-:0}"
HEADLESS="${HEADLESS:-1}"

# Accelerator + firmware per host/arch.
OS="$(uname -s)"
ACCEL=""; MACHINE=""; BIOS=()
case "$ARCH" in
  x86_64)
    QEMU="qemu-system-x86_64"; MACHINE="q35"
    if [ "$OS" = "Linux" ] && [ -e /dev/kvm ]; then ACCEL="kvm"; \
    elif [ "$OS" = "Darwin" ]; then ACCEL="hvf"; else ACCEL="tcg"; fi
    ;;
  aarch64)
    QEMU="qemu-system-aarch64"; MACHINE="virt"
    if [ "$OS" = "Linux" ] && [ -e /dev/kvm ]; then ACCEL="kvm"; \
    elif [ "$OS" = "Darwin" ]; then ACCEL="hvf"; else ACCEL="tcg"; fi
    # aarch64 needs explicit UEFI firmware; resolve a common path or override via UEFI.
    UEFI="${UEFI:-$(ls /usr/share/qemu-efi-aarch64/QEMU_EFI.fd /usr/share/AAVMF/AAVMF_CODE.fd 2>/dev/null | head -1 || true)}"
    [ -n "${UEFI:-}" ] && BIOS=(-bios "$UEFI")
    ;;
  *) echo "unsupported ARCH=$ARCH" >&2; exit 1 ;;
esac
command -v "$QEMU" >/dev/null 2>&1 || { echo "missing $QEMU (install qemu)"; exit 1; }

DISPLAY_ARGS=(-display none -vnc "$VNC")
[ "$HEADLESS" != "1" ] && DISPLAY_ARGS=(-display gtk)

echo "[run-vm] $QEMU accel=$ACCEL mem=${MEM}M img=$IMG vnc=$VNC"
exec "$QEMU" \
  -machine "$MACHINE" -accel "$ACCEL" -cpu max -smp 2 -m "$MEM" \
  "${BIOS[@]}" \
  -drive file="$IMG",if=virtio,format=qcow2,snapshot=on \
  -netdev user,id=n0 -device virtio-net-pci,netdev=n0 \
  -device virtio-vga-gl -device qemu-xhci -device usb-tablet -device usb-kbd \
  "${DISPLAY_ARGS[@]}"
