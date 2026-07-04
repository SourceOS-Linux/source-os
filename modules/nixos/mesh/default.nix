{ config, lib, pkgs, ... }:
let
  cfg = config.sourceos.mesh;

  unique = values:
    lib.length values == lib.length (lib.unique values);

  runtimeEnabled = cfg.runtime.enable;
  exitRuntimeEnabled = runtimeEnabled && cfg.runtime.enableExitHelper && cfg.role == "exit";

  runtimeConfigDir = "/etc/${cfg.runtime.configDirectory}";
  runtimeNftDir = "${runtimeConfigDir}/nftables";
  runtimeSocketDir = "/run/${cfg.runtime.runtimeDirectoryName}";

  netdevTemplate =
    lib.replaceStrings
      [
        "Name=mesh0"
        "PrivateKey=@mesh0"
        "FirewallMark=0x110"
        "RouteTable=110"
      ]
      [
        "Name=${cfg.interfaceName}"
        "PrivateKey=@${cfg.interfaceName}"
        "FirewallMark=${cfg.fwmarks.private}"
        "RouteTable=${toString cfg.routeTables.private}"
      ]
      (builtins.readFile ../../../linux/systemd-networkd/50-mesh0.netdev);

  networkTemplate =
    lib.replaceStrings
      [
        "Name=mesh0"
        "Table=110"
        "FirewallMark=0x110"
        "Table=120"
        "FirewallMark=0x120"
      ]
      [
        "Name=${cfg.interfaceName}"
        "Table=${toString cfg.routeTables.private}"
        "FirewallMark=${cfg.fwmarks.private}"
        "Table=${toString cfg.routeTables.exit}"
        "FirewallMark=${cfg.fwmarks.exit}"
      ]
      (builtins.readFile ../../../linux/systemd-networkd/50-mesh0.network);

  nmTemplate =
    lib.replaceStrings
      [
        "id=wg-mesh"
        "interface-name=wg-mesh"
        "route-table=120"
        "routing-rule1=priority 10020 fwmark 0x120 table 120"
      ]
      [
        "id=${cfg.interfaceName}"
        "interface-name=${cfg.interfaceName}"
        "route-table=${toString cfg.routeTables.exit}"
        "routing-rule1=priority 10020 fwmark ${cfg.fwmarks.exit} table ${toString cfg.routeTables.exit}"
      ]
      (builtins.readFile ../../../linux/networkmanager/wg-mesh.nmconnection);

  meshdConfigText = ''
    [identity]
    role = "${cfg.role}"
    manager = "${cfg.manager}"
    interface = "${cfg.interfaceName}"

    [paths]
    manifest = "/etc/sourceos/mesh/manifest.json"
    control_socket = "unix:${runtimeSocketDir}/meshd.sock"
    link_socket = "unix:${runtimeSocketDir}/linkd.sock"

    [routing]
    private_fwmark = "${cfg.fwmarks.private}"
    exit_fwmark = "${cfg.fwmarks.exit}"
    private_route_table = ${toString cfg.routeTables.private}
    exit_route_table = ${toString cfg.routeTables.exit}
    onion_route_table = ${toString cfg.routeTables.onion}
    mix_route_table = ${toString cfg.routeTables.mix}
  '';

  exitdConfigText = ''
    [exit]
    interface = "${cfg.interfaceName}"
    nft_policy = "${runtimeNftDir}/mesh-exit.nft"
    allow_full_tunnel = ${if cfg.role == "exit" then "true" else "false"}

    [routing]
    exit_fwmark = "${cfg.fwmarks.exit}"
    exit_route_table = ${toString cfg.routeTables.exit}
  '';

  manifestJson = builtins.toJSON {
    version = "sourceos-mesh-realization/v0";
    role = cfg.role;
    manager = cfg.manager;
    interface = cfg.interfaceName;
    routeTables = cfg.routeTables;
    fwmarks = cfg.fwmarks;
    activateTemplates = cfg.activateTemplates;
    pathTemplates = [ "P0-direct" "P1-relay" "P2-microcascade" "P3-onion" "P4-mix" ];
    runtime = {
      enabled = runtimeEnabled;
      exitHelperEnabled = exitRuntimeEnabled;
      configDirectory = runtimeConfigDir;
      socketDirectory = runtimeSocketDir;
    };
  };
in
{
  options.sourceos.mesh = {
    enable = lib.mkEnableOption "SourceOS mesh Linux estate realization";

    role = lib.mkOption {
      type = lib.types.enum [ "peer" "relay" "exit" "bridge" "introducer" "service" "builder" ];
      default = "peer";
      description = "Logical mesh role carried by this realized host profile.";
    };

    manager = lib.mkOption {
      type = lib.types.enum [ "networkd" "networkmanager" ];
      default = "networkd";
      description = "Primary Linux network manager expected to realize the mesh templates on this host.";
    };

    interfaceName = lib.mkOption {
      type = lib.types.str;
      default = "mesh0";
      description = "Logical WireGuard interface name for the mesh underlay.";
    };

    activateTemplates = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Install realized template files into active manager locations in /etc in addition to the SourceOS mesh scaffold path.";
    };

    routeTables = {
      private = lib.mkOption {
        type = lib.types.ints.positive;
        default = 110;
        description = "Route table for direct private mesh traffic.";
      };

      exit = lib.mkOption {
        type = lib.types.ints.positive;
        default = 120;
        description = "Route table for full-tunnel exit traffic.";
      };

      onion = lib.mkOption {
        type = lib.types.ints.positive;
        default = 130;
        description = "Reserved route table for the onion rail.";
      };

      mix = lib.mkOption {
        type = lib.types.ints.positive;
        default = 140;
        description = "Reserved route table for the mix rail.";
      };
    };

    fwmarks = {
      private = lib.mkOption {
        type = lib.types.str;
        default = "0x110";
        description = "fwmark used for direct private mesh traffic.";
      };

      exit = lib.mkOption {
        type = lib.types.str;
        default = "0x120";
        description = "fwmark used for full-tunnel exit traffic.";
      };

      onion = lib.mkOption {
        type = lib.types.str;
        default = "0x130";
        description = "Reserved fwmark for the onion rail.";
      };

      mix = lib.mkOption {
        type = lib.types.str;
        default = "0x140";
        description = "Reserved fwmark for the mix rail.";
      };
    };

    runtime = {
      enable = lib.mkEnableOption "mesh runtime services";

      enableExitHelper = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable the exit helper automatically when runtime services are enabled on an exit-role host.";
      };

      manageUsers = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Manage the meshd system user and group from the NixOS module.";
      };

      user = lib.mkOption {
        type = lib.types.str;
        default = "meshd";
        description = "User account used by the unprivileged mesh control-plane daemon.";
      };

      group = lib.mkOption {
        type = lib.types.str;
        default = "meshd";
        description = "Primary group used by the unprivileged mesh control-plane daemon.";
      };

      stateDirectoryName = lib.mkOption {
        type = lib.types.str;
        default = "meshd";
        description = "StateDirectory name for meshd runtime state.";
      };

      runtimeDirectoryName = lib.mkOption {
        type = lib.types.str;
        default = "meshd";
        description = "RuntimeDirectory name for meshd sockets and short-lived state.";
      };

      configDirectory = lib.mkOption {
        type = lib.types.str;
        default = "meshd";
        description = "Relative directory name under /etc used for runtime configuration material.";
      };

      meshdPackage = lib.mkOption {
        type = lib.types.nullOr lib.types.package;
        default = null;
        example = lib.literalExpression "pkgs.meshd";
        description = "Package providing the `meshd` executable.";
      };

      linkdPackage = lib.mkOption {
        type = lib.types.nullOr lib.types.package;
        default = null;
        example = lib.literalExpression "pkgs.meshd-linkd";
        description = "Package providing the `meshd-linkd` executable.";
      };

      exitdPackage = lib.mkOption {
        type = lib.types.nullOr lib.types.package;
        default = null;
        example = lib.literalExpression "pkgs.meshd-exitd";
        description = "Package providing the `meshd-exitd` executable.";
      };
    };

    realize = {
      networkTemplates = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Realize the network-manager-facing mesh template files under /etc/sourceos/mesh/.";
      };

      systemdUnits = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Realize the merged systemd unit templates under /etc/sourceos/mesh/.";
      };

      nftablesExit = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Realize the nftables exit template when the host role is exit.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = unique [ cfg.routeTables.private cfg.routeTables.exit cfg.routeTables.onion cfg.routeTables.mix ];
        message = "sourceos.mesh.routeTables values must be unique.";
      }
      {
        assertion = unique [ cfg.fwmarks.private cfg.fwmarks.exit cfg.fwmarks.onion cfg.fwmarks.mix ];
        message = "sourceos.mesh.fwmarks values must be unique.";
      }
      {
        assertion = (!runtimeEnabled) || (cfg.runtime.meshdPackage != null && cfg.runtime.linkdPackage != null);
        message = "sourceos.mesh.runtime.enable requires both sourceos.mesh.runtime.meshdPackage and sourceos.mesh.runtime.linkdPackage.";
      }
      {
        assertion = (!exitRuntimeEnabled) || (cfg.runtime.exitdPackage != null);
        message = "sourceos.mesh runtime exit-helper enablement requires sourceos.mesh.runtime.exitdPackage on exit-role hosts.";
      }
    ];

    users.groups = lib.optionalAttrs (runtimeEnabled && cfg.runtime.manageUsers) {
      "${cfg.runtime.group}" = {};
    };

    users.users = lib.optionalAttrs (runtimeEnabled && cfg.runtime.manageUsers) {
      "${cfg.runtime.user}" = {
        isSystemUser = true;
        group = cfg.runtime.group;
        description = "SourceOS mesh control-plane daemon user";
      };
    };

    environment.etc = lib.mkMerge [
      {
        "sourceos/mesh/manifest.json".text = manifestJson;
        "sourceos/mesh/README".text = ''
          SourceOS mesh realization scaffold.
          Role: ${cfg.role}
          Manager: ${cfg.manager}
          Interface: ${cfg.interfaceName}
          Runtime enabled: ${if runtimeEnabled then "yes" else "no"}
        '';
        "sourceos/mesh/runtime/meshd.toml".text = meshdConfigText;
      }
      (lib.optionalAttrs exitRuntimeEnabled {
        "sourceos/mesh/runtime/exits.toml".text = exitdConfigText;
      })
      (lib.optionalAttrs cfg.realize.networkTemplates {
        "sourceos/mesh/systemd-networkd/50-${cfg.interfaceName}.netdev".text = netdevTemplate;
        "sourceos/mesh/systemd-networkd/50-${cfg.interfaceName}.network".text = networkTemplate;
        "sourceos/mesh/networkmanager/${cfg.interfaceName}.nmconnection".text = nmTemplate;
      })
      (lib.optionalAttrs cfg.realize.systemdUnits {
        "sourceos/mesh/systemd/meshd.service".source = ../../../linux/systemd/meshd.service;
        "sourceos/mesh/systemd/meshd-linkd.service".source = ../../../linux/systemd/meshd-linkd.service;
        "sourceos/mesh/systemd/meshd-exitd.service".source = ../../../linux/systemd/meshd-exitd.service;
      })
      (lib.optionalAttrs (cfg.role == "exit" && cfg.realize.nftablesExit) {
        "sourceos/mesh/nftables/mesh-exit.nft".source = ../../../linux/nftables/mesh-exit.nft;
      })
      (lib.optionalAttrs (cfg.activateTemplates && cfg.manager == "networkd") {
        "systemd/network/50-${cfg.interfaceName}.netdev".text = netdevTemplate;
        "systemd/network/50-${cfg.interfaceName}.network".text = networkTemplate;
      })
      (lib.optionalAttrs (cfg.activateTemplates && cfg.manager == "networkmanager") {
        "NetworkManager/system-connections/${cfg.interfaceName}.nmconnection".text = nmTemplate;
      })
      (lib.optionalAttrs (cfg.activateTemplates && cfg.realize.systemdUnits) {
        "systemd/system/meshd.service".source = ../../../linux/systemd/meshd.service;
        "systemd/system/meshd-linkd.service".source = ../../../linux/systemd/meshd-linkd.service;
        "systemd/system/meshd-exitd.service".source = ../../../linux/systemd/meshd-exitd.service;
      })
      (lib.optionalAttrs (cfg.activateTemplates && runtimeEnabled) {
        "${cfg.runtime.configDirectory}/meshd.toml".text = meshdConfigText;
      })
      (lib.optionalAttrs (cfg.activateTemplates && exitRuntimeEnabled) {
        "${cfg.runtime.configDirectory}/exits.toml".text = exitdConfigText;
      })
      (lib.optionalAttrs (cfg.activateTemplates && cfg.role == "exit" && cfg.realize.nftablesExit) {
        "${cfg.runtime.configDirectory}/nftables/mesh-exit.nft".source = ../../../linux/nftables/mesh-exit.nft;
      })
    ];

    systemd.services.meshd = lib.mkIf runtimeEnabled {
      description = "Mesh control-plane daemon";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      serviceConfig = {
        Type = "notify";
        User = cfg.runtime.user;
        Group = cfg.runtime.group;
        StateDirectory = cfg.runtime.stateDirectoryName;
        RuntimeDirectory = cfg.runtime.runtimeDirectoryName;
        ExecStart = "${cfg.runtime.meshdPackage}/bin/meshd --config ${runtimeConfigDir}/meshd.toml --listen unix:${runtimeSocketDir}/meshd.sock";
        Restart = "on-failure";
        RestartSec = "2s";
        NoNewPrivileges = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        PrivateDevices = true;
        ProtectControlGroups = true;
        ProtectKernelLogs = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        ProtectClock = true;
        ProtectHostname = true;
        LockPersonality = true;
        MemoryDenyWriteExecute = true;
        RestrictSUIDSGID = true;
        RestrictRealtime = true;
        RestrictNamespaces = true;
        SystemCallArchitectures = "native";
        RestrictAddressFamilies = [ "AF_UNIX" "AF_INET" "AF_INET6" ];
        CapabilityBoundingSet = "";
        AmbientCapabilities = "";
      };
    };

    systemd.services.meshd-linkd = lib.mkIf runtimeEnabled {
      description = "Mesh privileged link helper";
      wantedBy = [ "multi-user.target" ];
      after = [ "meshd.service" ];
      requires = [ "meshd.service" ];
      serviceConfig = {
        Type = "notify";
        User = "root";
        Group = "root";
        RuntimeDirectory = cfg.runtime.runtimeDirectoryName;
        ExecStart = "${cfg.runtime.linkdPackage}/bin/meshd-linkd --rpc unix:${runtimeSocketDir}/linkd.sock --control unix:${runtimeSocketDir}/meshd.sock";
        Restart = "on-failure";
        RestartSec = "2s";
        NoNewPrivileges = true;
        PrivateTmp = true;
        PrivateDevices = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ProtectControlGroups = true;
        ProtectKernelLogs = true;
        ProtectClock = true;
        LockPersonality = true;
        MemoryDenyWriteExecute = true;
        RestrictSUIDSGID = true;
        RestrictRealtime = true;
        RestrictNamespaces = true;
        SystemCallArchitectures = "native";
        RestrictAddressFamilies = [ "AF_UNIX" "AF_NETLINK" "AF_INET" "AF_INET6" ];
        CapabilityBoundingSet = [ "CAP_NET_ADMIN" "CAP_NET_RAW" ];
        AmbientCapabilities = [ "CAP_NET_ADMIN" "CAP_NET_RAW" ];
      };
    };

    systemd.services.meshd-exitd = lib.mkIf exitRuntimeEnabled {
      description = "Mesh exit helper";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" "meshd-linkd.service" ];
      wants = [ "network-online.target" ];
      requires = [ "meshd-linkd.service" ];
      serviceConfig = {
        Type = "simple";
        User = "root";
        Group = "root";
        ExecStart = "${cfg.runtime.exitdPackage}/bin/meshd-exitd --config ${runtimeConfigDir}/exits.toml --nft ${runtimeNftDir}/mesh-exit.nft";
        Restart = "on-failure";
        RestartSec = "2s";
        NoNewPrivileges = true;
        PrivateTmp = true;
        PrivateDevices = true;
        ProtectSystem = "strict";
        ProtectHome = true;
        ProtectControlGroups = true;
        ProtectKernelLogs = true;
        ProtectClock = true;
        LockPersonality = true;
        MemoryDenyWriteExecute = true;
        RestrictSUIDSGID = true;
        RestrictRealtime = true;
        RestrictNamespaces = true;
        SystemCallArchitectures = "native";
        RestrictAddressFamilies = [ "AF_UNIX" "AF_NETLINK" "AF_INET" "AF_INET6" ];
        CapabilityBoundingSet = [ "CAP_NET_ADMIN" "CAP_NET_RAW" ];
        AmbientCapabilities = [ "CAP_NET_ADMIN" "CAP_NET_RAW" ];
      };
    };
  };
}
