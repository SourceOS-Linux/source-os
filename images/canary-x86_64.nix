{ lib, ... }:
{
  imports = [ ../hosts/canary-x86_64/default.nix ];
  sourceos.build.role = "canary-x86_64-image";
  # nixos-generators provides boot.loader and fileSystems for each format.
  # isContainer=true suppresses boot assembly — force off for image builds.
  boot.isContainer = lib.mkForce false;
}
