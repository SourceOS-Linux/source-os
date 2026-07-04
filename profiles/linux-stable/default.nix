{ ... }:
{
  imports = [
    ../../modules/build/default.nix
    ../../modules/nixos/mesh/default.nix
  ];

  sourceos.build = {
    role = "linux-stable";
    channel = "stable";
  };

  sourceos.mesh = {
    enable = true;
    role = "relay";
    manager = "networkd";
  };
}
