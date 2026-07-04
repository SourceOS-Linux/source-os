# SourceOS base — shared foundation for every public edition (desktop, server,
# edge). Deliberately free of the build/content-lifecycle machinery
# (sourceos-syncd, Katello, sops): a downloaded edition boots with zero
# enrollment. The installer (scripts/install-image.sh) composes one edition
# module on top of this via a generated per-machine flake.
{ lib, pkgs, ... }:
{
  # Flakes + a modern Nix CLI everywhere.
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Networking that works headless or on a desktop.
  networking.networkmanager.enable = lib.mkDefault true;

  # Default user; password is set interactively at install time (no baked-in pw).
  users.users.sourceos = {
    isNormalUser = true;
    description = "SourceOS";
    extraGroups = [ "wheel" "networkmanager" ];
  };
  security.sudo.wheelNeedsPassword = lib.mkDefault true;

  # Generic UEFI boot (Apple Silicon uses its own module, not these editions).
  boot.loader.systemd-boot.enable = lib.mkDefault true;
  boot.loader.efi.canTouchEfiVariables = lib.mkDefault true;

  environment.systemPackages = with pkgs; [ vim git curl ];

  time.timeZone = lib.mkDefault "UTC";
  i18n.defaultLocale = lib.mkDefault "en_US.UTF-8";
  system.stateVersion = "26.11";
}
