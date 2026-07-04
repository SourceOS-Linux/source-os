# SourceOS Server edition — headless, general-purpose server. Builds on
# profiles/base. No desktop; SSH on by default; sensible firewall. Distinct
# from the internal build/Katello node role (hosts/stable-x86_64 et al.).
{ lib, pkgs, ... }:
{
  imports = [ ../base/default.nix ];

  # Headless: no display stack.
  services.xserver.enable = lib.mkDefault false;

  # Remote administration.
  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = lib.mkDefault true;  # first login; harden to keys later
    };
  };

  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 ];
  };

  # Server-useful CLI.
  environment.systemPackages = with pkgs; [ htop tmux rsync ];

  # Trim closure a little for a server image.
  documentation.nixos.enable = lib.mkDefault false;
}
