{ config, lib, pkgs, ... }:
let
  cfg = config.sourceos.openclaw.localCell;
in {
  options.sourceos.openclaw.localCell = {
    enable = lib.mkEnableOption "bounded local-first OpenClaw cell";

    stateDir = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/openclaw-local";
      description = "State directory for the local OpenClaw cell.";
    };

    bindAddress = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Loopback bind address for the local OpenClaw gateway.";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 18789;
      description = "Gateway port for the local OpenClaw cell.";
    };

    modelRoute = lib.mkOption {
      type = lib.types.enum [ "local-only" "local-preferred" ];
      default = "local-only";
      description = "Initial model routing mode for the bounded local cell.";
    };

    allowBrowser = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether browser automation is allowed for this local cell.";
    };

    allowWriteTools = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether write-capable tools are enabled for this local cell.";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.bindAddress == "127.0.0.1";
        message = "OpenClaw local cell must remain loopback-bound in the default SourceOS profile.";
      }
      {
        assertion = cfg.allowBrowser == false;
        message = "OpenClaw local cell browser automation must remain disabled by default.";
      }
      {
        assertion = cfg.allowWriteTools == false;
        message = "OpenClaw local cell write-capable tools must remain disabled by default.";
      }
    ];

    systemd.services.openclaw-local-cell = {
      description = "OpenClaw local-first bounded cell";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      serviceConfig = {
        Type = "simple";
        User = "root";
        ExecStart = "${pkgs.bash}/bin/bash -lc 'echo OpenClaw local cell placeholder > /dev/null; sleep infinity'";
        StateDirectory = "openclaw-local";
        Restart = "on-failure";
      };
      environment = {
        OPENCLAW_BIND = cfg.bindAddress;
        OPENCLAW_PORT = builtins.toString cfg.port;
        OPENCLAW_MODEL_ROUTE = cfg.modelRoute;
        OPENCLAW_STATE_DIR = cfg.stateDir;
      };
    };
  };
}
