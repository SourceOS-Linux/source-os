{ config, lib, pkgs, self, ... }:
{
  imports = [
    ../../profiles/linux-dev/default.nix
    # hardware-configuration.nix is device-specific.
    # After Asahi install, run `nixos-generate-config` on the device and
    # place the result at /etc/nixos/hardware-configuration.nix, or pass
    # it via `--impure` with a local path override.
  ];

  networking.hostName = "builder-aarch64";

  sourceos.build = {
    role = "builder-aarch64";
    channel = "dev";
  };

  # Apple Silicon hardware support (module wired in via flake.nix
  # nixosConfigurations.builder-aarch64 modules list).
  hardware.asahi = {
    enable = true;
    setupAsahiSound = true;
    experimentalGpuAcceleration = true;
  };

  # Boot via systemd-boot: Asahi installer places m1n1 + U-Boot which
  # expose an EFI stub. NixOS picks it up via systemd-boot.
  # canTouchEfiVariables = false is mandatory — modifying EFI vars on
  # Apple Silicon can prevent booting macOS.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = false;

  # Flakes required for sourceos-syncd and prophet CLI
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Trusted substituters for the SourceOS binary cache (populated by Katello
  # after the content view is published)
  nix.settings.trusted-substituters = [
    "https://cache.nixos.org"
    "http://127.0.0.1:8101"
  ];
  nix.settings.trusted-public-keys = [
    "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
  ];

  users.users.sourceos = {
    isNormalUser = true;
    extraGroups = [ "wheel" "video" "audio" "networkmanager" ];
    # Set password post-install via `passwd sourceos` — never commit credentials
  };

  security.sudo.wheelNeedsPassword = false;

  # ── SOPS secrets ────────────────────────────────────────────────────────────
  # secrets.yaml is encrypted with the device age key generated at enrollment.
  # Encrypt with: sops --encrypt --age $(cat /etc/sourceos/age.pub) secrets.yaml
  # The plaintext file is never committed to the repo.
  sops.defaultSopsFile = ./secrets.yaml;
  sops.age.keyFile = "/etc/sourceos/age.key";
  sops.secrets.katello-password = {
    owner = "sourceos-syncd";
    group = "sourceos-syncd";
    mode = "0400";
  };

  # ── sourceos-syncd daemon ────────────────────────────────────────────────────
  # Polls local Katello every 5 min; applies new stable content view versions.
  # Password loaded via SOPS-managed secret (not committed to repo).
  sourceos.syncd = {
    enable = true;
    # package and sourceosBoot.package must point to built derivations.
    # These are set below as overrides once the package derivations exist.
    # For now, use placeholder that will be replaced with the real package.
    katelloUrl = "https://127.0.0.1:8443";
    lifecycleEnv = "stable";
    locus = "local";
    flakeRef = "github:SociOS-Linux/source-os#builder-aarch64";
    pollInterval = 300;
    noVerifySsl = true;
    katelloPasswordFile = config.sops.secrets.katello-password.path;
    # signingPublicKey: set after generating the minisign key pair.
    # Generate: minisign -G -p /etc/sourceos/nix-cache.pub -s /run/secrets/nix-cache.key
    # Then embed the public key string here.
    healthCheck = {
      enable = true;
      delayAfterBootSec = 120;
      rollbackOnFailure = true;
    };
  };

  system.stateVersion = "25.05";
}
