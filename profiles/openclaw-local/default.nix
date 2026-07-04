{ ... }:
{
  imports = [
    ../../modules/nixos/openclaw-local-cell.nix
  ];

  sourceos.openclaw.localCell = {
    enable = true;
    modelRoute = "local-only";
    allowBrowser = false;
    allowWriteTools = false;
  };
}
