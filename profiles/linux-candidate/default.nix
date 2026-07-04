{ ... }:
{
  imports = [
    ../../modules/build/default.nix
    ../../modules/nixos/mesh/default.nix
  ];

  sourceos.build = {
    role = "linux-candidate";
    channel = "candidate";
  };

  sourceos.mesh = {
    enable = true;
    role = "peer";
    manager = "networkd";
  };
}
