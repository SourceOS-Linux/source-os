# SourceOS Desktop edition — GNOME. The end-user workstation installed from the
# public ISO. Builds on profiles/base (no syncd/Katello/sops/mesh): a fresh
# install boots straight to GDM with zero enrollment.
#
# The imperative GNOME "polish" layer (profiles/linux-dev/workstation-v0) can be
# applied on top after first boot via its apply.sh; it is not required to boot.
{ lib, pkgs, ... }:
{
  imports = [ ../base/default.nix ];

  # ── Desktop ───────────────────────────────────────────────────────────────
  services.xserver.enable = true;            # X/Xwayland + keymap plumbing
  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;
  services.xserver.xkb.layout = "us";

  # Audio (PipeWire) + printing.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };
  services.printing.enable = true;

  users.users.sourceos.extraGroups = [ "video" "audio" ];

  environment.systemPackages = with pkgs; [ firefox gnome-tweaks ];
  environment.gnome.excludePackages = with pkgs; [ gnome-tour epiphany geary ];
}
