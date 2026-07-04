# SourceOS Edge edition — minimal headless appliance for edge/network nodes.
# Builds on profiles/base, trimmed for a small footprint, and wires the SourceOS
# mesh config (meshd/linkd/exitd). The mesh *runtime* (the daemons) is opt-in
# (sourceos.mesh.runtime.enable + a meshd package) so the base image needs no
# extra packages and stays small; an edge deployment turns the runtime on.
{ lib, pkgs, ... }:
{
  imports = [
    ../base/default.nix
    ../../modules/nixos/mesh/default.nix
  ];

  # Headless appliance.
  services.xserver.enable = lib.mkDefault false;
  services.openssh = {
    enable = true;
    settings.PermitRootLogin = "no";
  };
  networking.firewall.enable = lib.mkDefault true;

  # Mesh-ready: emit the mesh config/templates for a relay node. The runtime
  # daemons are enabled per-deployment (needs the meshd package wired in).
  sourceos.mesh = {
    enable = true;
    role = lib.mkDefault "relay";
    manager = "networkd";
  };

  # Small-footprint defaults for an appliance.
  documentation.enable = lib.mkDefault false;
  zramSwap.enable = lib.mkDefault true;
  services.journald.extraConfig = lib.mkDefault "SystemMaxUse=200M";
}
