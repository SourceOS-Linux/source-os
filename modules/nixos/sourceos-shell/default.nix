{ config, lib, pkgs, ... }:
let
  cfg = config.sourceos.shell;
in
{
  options.sourceos.shell = {
    enable = lib.mkEnableOption "SourceOS shell Linux realization";

    packageRoot = lib.mkOption {
      type = lib.types.str;
      default = "/opt/sourceos-shell";
      description = "Filesystem root where the sourceos-shell runtime is expected to be installed.";
    };

    shellPort = lib.mkOption {
      type = lib.types.port;
      default = 4173;
      description = "Default local port for the sourceos-shell web runtime.";
    };

    routerPort = lib.mkOption {
      type = lib.types.port;
      default = 7071;
      description = "Local port for the sourceos-shell router bridge service.";
    };

    pdfSecurePort = lib.mkOption {
      type = lib.types.port;
      default = 7072;
      description = "Local port for the sourceos-shell pdf-secure service.";
    };

    docdPort = lib.mkOption {
      type = lib.types.port;
      default = 7073;
      description = "Local port for the sourceos-shell derive/docd service.";
    };

    searchProvider = {
      mode = lib.mkOption {
        type = lib.types.enum [ "linux-native" "command-bus" "shell-native" ];
        default = "command-bus";
        description = "Search routing mode during shell rollout.";
      };

      linuxFileProvider = lib.mkOption {
        type = lib.types.enum [ "lampstand" "fd" "locate" ];
        default = "lampstand";
        description = "Linux-native file search provider used when scope=files.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    environment.etc."sourceos-shell/README".text = ''
      SourceOS shell Linux realization scaffold.
      packageRoot=${cfg.packageRoot}
      shellPort=${toString cfg.shellPort}
      routerPort=${toString cfg.routerPort}
      pdfSecurePort=${toString cfg.pdfSecurePort}
      docdPort=${toString cfg.docdPort}
      searchProvider.mode=${cfg.searchProvider.mode}
      searchProvider.linuxFileProvider=${cfg.searchProvider.linuxFileProvider}
    '';

    environment.etc."sourceos-shell/search-provider.json".text = builtins.toJSON {
      mode = cfg.searchProvider.mode;
      linuxFileProvider = cfg.searchProvider.linuxFileProvider;
      invariant = "no_redundant_file_search";
      scopes = {
        apps = "launcher";
        files = "linux-native-only";
        web = "browser-agent";
      };
      notes = [
        "Lampstand is the Linux-native file authority for scope=files."
        "The command bus remains a frontend and must not perform a second file-search pass."
      ];
    };

    # Services are gated on the runtime binary existing at packageRoot.
    # They are inert before the sourceos-shell runtime package is deployed
    # (e.g. via Katello content). Same ConditionPathExists pattern as harmonia.

    systemd.services.sourceos-shell = {
      description = "SourceOS shell runtime";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      unitConfig.ConditionPathExists = "${cfg.packageRoot}/bin/sourceos-shell";
      serviceConfig = {
        Type = "exec";
        ExecStart = "${cfg.packageRoot}/bin/sourceos-shell --port ${toString cfg.shellPort}";
        Restart = "on-failure";
        RestartSec = "5s";
        DynamicUser = true;
        BindReadOnlyPaths = [ "/etc/sourceos-shell" ];
      };
    };

    systemd.services.sourceos-router = {
      description = "SourceOS shell router bridge";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      unitConfig.ConditionPathExists = "${cfg.packageRoot}/bin/sourceos-router";
      serviceConfig = {
        Type = "exec";
        ExecStart = "${cfg.packageRoot}/bin/sourceos-router --port ${toString cfg.routerPort}";
        Restart = "on-failure";
        RestartSec = "5s";
        DynamicUser = true;
        BindReadOnlyPaths = [ "/etc/sourceos-shell" ];
      };
    };

    systemd.services.sourceos-pdf-secure = {
      description = "SourceOS shell pdf-secure service";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      unitConfig.ConditionPathExists = "${cfg.packageRoot}/bin/sourceos-pdf-secure";
      serviceConfig = {
        Type = "exec";
        ExecStart = "${cfg.packageRoot}/bin/sourceos-pdf-secure --port ${toString cfg.pdfSecurePort}";
        Restart = "on-failure";
        RestartSec = "5s";
        DynamicUser = true;
        BindReadOnlyPaths = [ "/etc/sourceos-shell" ];
      };
    };

    systemd.services.sourceos-docd = {
      description = "SourceOS shell docd derive service";
      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];
      unitConfig.ConditionPathExists = "${cfg.packageRoot}/bin/sourceos-docd";
      serviceConfig = {
        Type = "exec";
        ExecStart = "${cfg.packageRoot}/bin/sourceos-docd --port ${toString cfg.docdPort}";
        Restart = "on-failure";
        RestartSec = "5s";
        DynamicUser = true;
        BindReadOnlyPaths = [ "/etc/sourceos-shell" ];
      };
    };
  };
}
