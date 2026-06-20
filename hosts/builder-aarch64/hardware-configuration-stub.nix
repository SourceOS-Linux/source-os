# hardware-configuration-stub.nix
#
# Stub used in CI and when building from non-device environments.
# Provides minimal hardware declarations so the NixOS configuration evaluates
# without the device-specific hardware-configuration.nix.
#
# On the actual M2 device, hardware-configuration.nix (gitignored) takes
# precedence. Run `sudo bash scripts/enroll.sh` to generate it.
{ lib, ... }:
{
  boot.initrd.availableKernelModules = [ "nvme" "usbhid" "sd_mod" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ ];
  boot.extraModulePackages = [ ];

  # Stub fileSystems — not bootable; device-specific hardware-configuration.nix
  # provides the real partition UUIDs.
  fileSystems."/" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-label/boot";
    fsType = "ext4";
  };

  fileSystems."/boot/efi" = {
    device = "/dev/disk/by-label/ESP";
    fsType = "vfat";
    options = [ "fmask=0022" "dmask=0022" ];
  };

  swapDevices = [ ];

  # Firmware extraction disabled in stub: no path to Apple peripheral firmware.
  hardware.asahi.extractPeripheralFirmware = false;

  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";
}
