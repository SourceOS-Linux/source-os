{ self, pkgs, syncdPkg, bootPkg, config, ... }:
{
  imports = [
    ../../profiles/linux-candidate/default.nix
  ];

  networking.hostName = "canary-x86_64";

  # Cloud/VM target — boot and filesystems managed by the platform image.
  boot.isContainer = true;

  sourceos.build = {
    role = "canary-x86_64";
    channel = "candidate";
  };

  sourceos.mesh.runtime = {
    enable = true;
    meshdPackage = self.packages.${pkgs.system}.meshd;
    linkdPackage = self.packages.${pkgs.system}.meshd-linkd;
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
    lifecycleEnv = "candidate";
    locus = "local";
    flakeRef = "github:SourceOS-Linux/source-os#canary-x86_64";
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
