# Shared configuration for SourceOS public installer ISOs (x86_64 + aarch64).
# Produces a branded, bootable NixOS-based live installer that bundles the
# SourceOS install scripts so a fresh machine can be brought up offline-ish.
#
# This is the LIVE/INSTALLER environment, not the installed target system.
# The installed system is chosen by the user during install (workstation,
# server role, etc.).
{ lib, pkgs, config, ... }:
let
  release = "26.11";
in
{
  # ── Branding ────────────────────────────────────────────────────────────────
  image.fileName = lib.mkForce "sourceos-${release}-installer-${pkgs.stdenv.hostPlatform.system}.iso";
  isoImage.volumeID = lib.mkForce "SOURCEOS_${builtins.replaceStrings ["."] ["_"] release}";
  # Make the ISO writable to USB and also bootable as a CD.
  isoImage.makeEfiBootable = true;
  isoImage.makeUsbBootable = true;

  networking.hostName = lib.mkForce "sourceos-installer";

  # ── Live-environment tooling ─────────────────────────────────────────────────
  # NetworkManager so Wi-Fi works during install; the CLI tools the installer needs.
  networking.networkmanager.enable = true;

  # Allow flakes + the Determinate cache during install.
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # ── Bundle the SourceOS installer into the live image ────────────────────────
  # The install scripts ship read-only at /etc/sourceos-installer; a wrapper
  # `sourceos-install` is on PATH so the first thing a user sees works.
  environment.etc."sourceos-installer/install-image.sh".source = ../scripts/install-image.sh;
  environment.etc."sourceos-installer/install-on-device.sh".source = ../scripts/install-on-device.sh;
  environment.etc."sourceos-installer/preflight.sh".source = ../scripts/preflight.sh;

  environment.systemPackages = (with pkgs; [
    git curl jq parted gptfdisk dosfstools e2fsprogs
    rsync vim gnused gawk pciutils usbutils
  ]) ++ [
    (pkgs.writeShellScriptBin "sourceos-install" ''
      echo "SourceOS ${release} installer — clean-disk GNOME install."
      echo "You will pick a target disk and confirm before anything is erased."
      exec sudo bash /etc/sourceos-installer/install-image.sh "$@"
    '')
  ];

  # ── Friendly first-boot message ──────────────────────────────────────────────
  users.motd = ''

    ╭──────────────────────────────────────────────────────────╮
    │  SourceOS ${release} — live installer                      │
    │                                                            │
    │  Run:  sourceos-install      to install to this machine    │
    │  Wi-Fi: nmtui                to connect before installing   │
    │  Docs:  https://sourceos.org/install                       │
    ╰──────────────────────────────────────────────────────────╯
  '';

  # Installer convenience: passwordless sudo for the live user, autologin.
  services.getty.autologinUser = lib.mkDefault "nixos";

  system.stateVersion = release;
}
