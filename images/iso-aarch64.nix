# SourceOS aarch64 public installer ISO — generic ARM64 UEFI machines
# (Ampere, servers, UEFI-capable SBCs). Apple Silicon uses the Asahi path
# (scripts/get-sourceos.sh), not this ISO.
{ ... }:
{
  imports = [ ./installer-common.nix ];
  # System is set by nixos-generators (flake.nix). Arch-specific installer
  # tweaks for generic ARM64 UEFI go here.
}
