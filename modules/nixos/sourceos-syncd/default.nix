{ config, lib, pkgs, ... }:
let
  cfg = config.sourceos.syncd;
  syncdPkg = cfg.package;
  bootPkg = cfg.sourceosBoot.package;

in
{
  options.sourceos.syncd = {
    enable = lib.mkEnableOption "sourceos-syncd content-view sync daemon";

    package = lib.mkOption {
      type = lib.types.package;
      description = "The sourceos-syncd package to use.";
    };

    katelloUrl = lib.mkOption {
      type = lib.types.str;
      default = "https://127.0.0.1:8443";
      description = "Foreman+Katello base URL.";
    };

    katelloUser = lib.mkOption {
      type = lib.types.str;
      default = "admin";
      description = "Katello admin username.";
    };

    katelloPassword = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Katello password (plaintext — prefer katelloPasswordFile).";
    };

    katelloPasswordFile = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Path to file containing KATELLO_PASSWORD. Loaded via systemd LoadCredential.";
    };

    org = lib.mkOption {
      type = lib.types.str;
      default = "SocioProphet";
      description = "Katello organization name.";
    };

    contentView = lib.mkOption {
      type = lib.types.str;
      default = "sourceos-builder-aarch64";
      description = "Katello content view name.";
    };

    lifecycleEnv = lib.mkOption {
      type = lib.types.enum [ "dev" "candidate" "stable" ];
      default = "stable";
      description = "Katello lifecycle environment to track.";
    };

    locus = lib.mkOption {
      type = lib.types.enum [ "local" "trusted_private" ];
      default = "local";
      description = "Execution locus. Must be 'local' or 'trusted_private' for Phase 0.";
    };

    flakeRef = lib.mkOption {
      type = lib.types.str;
      default = "github:SociOS-Linux/source-os#builder-aarch64";
      description = "NixOS flake ref passed to nixos-rebuild switch.";
    };

    pollInterval = lib.mkOption {
      type = lib.types.ints.positive;
      default = 300;
      description = "Katello poll interval in seconds.";
    };

    storeRoot = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/sourceos-syncd";
      description = "Directory for state (current-version) and receipts.";
    };

    noVerifySsl = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Skip TLS certificate verification (local dev only).";
    };

    signingPublicKey = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = ''
        minisign public key (RWS...) embedded in the image. When set, the
        daemon verifies the nix-cache-info signature before running nix copy.
        Generate with: minisign -G -p /etc/sourceos/nix-cache.pub -s /run/secrets/nix-cache.key
      '';
    };

    sourceosBoot = {
      package = lib.mkOption {
        type = lib.types.package;
        description = "The sourceos-boot package for rollback execution.";
      };
    };

    # Health check options

    healthCheck = {
      enable = lib.mkEnableOption "post-boot health check with auto-rollback" // { default = true; };

      delayAfterBootSec = lib.mkOption {
        type = lib.types.ints.positive;
        default = 120;
        description = "Seconds after boot-complete before running the health check.";
      };

      rollbackOnFailure = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Execute nixos-rebuild --rollback if health check fails.";
      };
    };
  };

  config = lib.mkIf cfg.enable {

    # ── state directory ──────────────────────────────────────────────────────
    systemd.tmpfiles.rules = [
      "d ${cfg.storeRoot} 0750 sourceos-syncd sourceos-syncd -"
      "d ${cfg.storeRoot}/receipts 0750 sourceos-syncd sourceos-syncd -"
    ];

    users.users.sourceos-syncd = {
      isSystemUser = true;
      group = "sourceos-syncd";
      description = "sourceos-syncd daemon user";
      home = cfg.storeRoot;
    };
    users.groups.sourceos-syncd = {};

    # ── sync daemon ──────────────────────────────────────────────────────────
    systemd.services.sourceos-syncd = {
      description = "SourceOS content-view sync daemon";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "simple";
        User = "sourceos-syncd";
        Group = "sourceos-syncd";
        StateDirectory = "sourceos-syncd";
        Restart = "on-failure";
        RestartSec = "30s";

        # LoadCredential places the secret at /run/credentials/<service>/<name>.
        # The daemon reads KATELLO_PASSWORD_FILE (supported since feat/content-signing)
        # so we point that env var at the credential path. This avoids putting
        # the plaintext password in the process environment.
        LoadCredential = lib.optional (cfg.katelloPasswordFile != "")
          "KATELLO_PASSWORD_SECRET:${cfg.katelloPasswordFile}";

        Environment =
          lib.optional (cfg.katelloPassword != "") "KATELLO_PASSWORD=${cfg.katelloPassword}"
          ++ lib.optional (cfg.katelloPasswordFile != "")
               "KATELLO_PASSWORD_FILE=/run/credentials/sourceos-syncd.service/KATELLO_PASSWORD_SECRET"
          ++ lib.optional (cfg.signingPublicKey != "")
               "SOURCEOS_SIGNING_PUBLIC_KEY=${cfg.signingPublicKey}";

        # Password is not passed as a CLI flag — it comes from KATELLO_PASSWORD
        # or KATELLO_PASSWORD_FILE env (set above). All other config is explicit.
        ExecStart = lib.concatStringsSep " " (
          [ "${syncdPkg}/bin/sourceos-syncd" "sync" "daemon" ]
          ++ [ "--katello-url" (lib.escapeShellArg cfg.katelloUrl) ]
          ++ [ "--katello-user" (lib.escapeShellArg cfg.katelloUser) ]
          ++ [ "--org" (lib.escapeShellArg cfg.org) ]
          ++ [ "--content-view" (lib.escapeShellArg cfg.contentView) ]
          ++ [ "--lifecycle-env" cfg.lifecycleEnv ]
          ++ [ "--locus" cfg.locus ]
          ++ [ "--flake-ref" (lib.escapeShellArg cfg.flakeRef) ]
          ++ [ "--poll-interval" (toString cfg.pollInterval) ]
          ++ [ "--store-root" (lib.escapeShellArg cfg.storeRoot) ]
          ++ lib.optional cfg.noVerifySsl "--no-verify-ssl"
          ++ lib.optional (cfg.signingPublicKey != "")
               "--signing-public-key ${lib.escapeShellArg cfg.signingPublicKey}"
        );
      };
    };

    # ── health check + auto-rollback ─────────────────────────────────────────
    systemd.services.sourceos-health-check = lib.mkIf cfg.healthCheck.enable {
      description = "SourceOS post-boot health check";
      after = [ "network-online.target" "sourceos-syncd.service" ];
      wants = [ "network-online.target" ];

      serviceConfig = {
        Type = "oneshot";
        User = "sourceos-syncd";
        RemainAfterExit = false;

        ExecStart = pkgs.writeShellScript "sourceos-health-check" ''
          set -euo pipefail
          if ${syncdPkg}/bin/sourceos-syncd sync check-health \
              --store-root ${lib.escapeShellArg cfg.storeRoot} \
              --katello-url ${lib.escapeShellArg cfg.katelloUrl} \
              ${lib.optionalString cfg.noVerifySsl "--no-verify-ssl"}; then
            exit 0
          fi

          echo "sourceos-health-check: UNHEALTHY" >&2
          ${lib.optionalString cfg.healthCheck.rollbackOnFailure ''
            echo "sourceos-health-check: triggering rollback" >&2
            ${bootPkg}/bin/sourceos-boot rollback execute --execute || true
          ''}
          exit 2
        '';
      };
    };

    systemd.timers.sourceos-health-check = lib.mkIf cfg.healthCheck.enable {
      description = "SourceOS post-boot health check timer";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "${toString cfg.healthCheck.delayAfterBootSec}s";
        Unit = "sourceos-health-check.service";
      };
    };
  };
}
