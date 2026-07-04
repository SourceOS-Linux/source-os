# SourceOS x86_64 public installer ISO.
# Built via nixos-generators `install-iso` format (see flake.nix).
{ ... }:
{
  imports = [ ./installer-common.nix ];
  # System is set by nixos-generators (flake.nix). Arch-specific installer
  # tweaks for x86_64 go here.
}
