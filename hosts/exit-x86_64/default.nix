{ self, pkgs, syncdPkg, bootPkg, config, ... }:
{
  imports = [
    ../../profiles/linux-stable/default.nix
  ];

  networking.hostName = "exit-x86_64";

  sourceos.build = {
    role = "exit-x86_64";
    channel = "stable";
  };

  sourceos.mesh = {
    role = "exit";
    runtime = {
      enable = true;
      meshdPackage = self.packages.${pkgs.system}.meshd;
      linkdPackage = self.packages.${pkgs.system}.meshd-linkd;
      exitdPackage = self.packages.${pkgs.system}.meshd-exitd;
    };
  };

  # ── SOPS secrets ────────────────────────────────────────────────────────────
  sops.validateSopsFiles = false;
  sops.age.keyFile = "/etc/sourceos/age.key";
  sops.secrets.katello-password = {
    sopsFile = "/etc/sourceos/secrets.yaml";
    owner = "sourceos-syncd";
    group = "sourceos-syncd";
    mode = "0400";
  };

  # ── sourceos-syncd ───────────────────────────────────────────────────────────
  sourceos.syncd = {
    enable = true;
    package = syncdPkg;
    sourceosBoot.package = bootPkg;
    katelloUrl = "https://127.0.0.1:8443";
    contentView = "sourceos-x86_64";
    lifecycleEnv = "stable";
    locus = "local";
    flakeRef = "github:SociOS-Linux/source-os#exit-x86_64";
    pollInterval = 300;
    noVerifySsl = true;
    katelloPasswordFile = config.sops.secrets.katello-password.path;
    healthCheck = {
      enable = true;
      delayAfterBootSec = 120;
      rollbackOnFailure = true;
    };
  };
}
