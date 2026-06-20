{ lib, ... }:
{
  imports = [ ../hosts/stable-x86_64/default.nix ];
  sourceos.build.role = "release-x86_64-image";
  boot.isContainer = lib.mkForce false;
}
