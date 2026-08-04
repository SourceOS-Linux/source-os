{ config, lib, pkgs, ... }:

let
  cfg = config.sourceos.hellgraph;
in
{
  options.sourceos.hellgraph = {
    enable = lib.mkEnableOption "HellGraph always-on graph service (local-only; p2p superpeer opt-in)";

    package = lib.mkOption {
      type = lib.types.package;
      description = "The hellgraph package to run.";
    };

    superpeer = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "OPT-IN: join the p2p superpeer mesh. Default off — the graph service is local-only and sovereign.";
      };
      bootstrapKeyFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = "Path to a file holding HELLGRAPH_BOOTSTRAP_KEY (read via LoadCredential) when p2p is enabled.";
      };
    };

    extraEnvironment = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = "Extra environment for startSuperPeerFromEnv (e.g. port/store overrides).";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.hellgraph = {
      description = "HellGraph always-on graph service (local-only; p2p superpeer opt-in)";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      # local-only by default: no bootstrap key means startSuperPeerFromEnv serves the local graph
      # only. p2p federation is opt-in and the key is supplied via a systemd credential, never inline.
      environment = cfg.extraEnvironment;

      serviceConfig = {
        Type = "simple";
        DynamicUser = true;
        StateDirectory = "hellgraph";
        ExecStart = "${cfg.package}/bin/hellgraph-superpeer";
        Restart = "always";
        RestartSec = 5;
        # hardening
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
      } // lib.optionalAttrs (cfg.superpeer.enable && cfg.superpeer.bootstrapKeyFile != null) {
        LoadCredential = [ "bootstrap-key:${cfg.superpeer.bootstrapKeyFile}" ];
        Environment = [ "HELLGRAPH_BOOTSTRAP_KEY_FILE=%d/bootstrap-key" ];
      };
    };
  };
}
