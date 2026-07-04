{ ... }:
{
  imports = [
    ../../modules/build/default.nix
    ../../modules/nixos/mesh/default.nix
    ../../modules/nixos/sourceos-shell/default.nix
  ];

  sourceos.build = {
    role = "linux-dev";
    channel = "dev";
  };

  sourceos.mesh = {
    enable = true;
    role = "builder";
    manager = "networkd";
  };
}
