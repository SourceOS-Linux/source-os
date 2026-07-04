# SourceOS Desktop edition — GNOME. The end-user workstation installed from the
# public ISO. Builds on profiles/base (no syncd/Katello/sops/mesh): a fresh
# install boots straight to GDM with zero enrollment.
#
# The imperative GNOME "polish" layer (profiles/linux-dev/workstation-v0) can be
# applied on top after first boot via its apply.sh; it is not required to boot.
{ lib, pkgs, ... }:
let
  # BearBrowser — the SourceOS default browser (Gecko + anti-fingerprint engine
  # patches), packaged in packages/browser/bearbrowser.nix. Built via callPackage
  # so this works in any module-eval context (the boot VM tests don't pass `self`).
  # The prebuilt release artifact is x86_64-only for now, so fall back to Firefox
  # on aarch64 until an aarch64 BearBrowser build exists.
  isX86 = pkgs.stdenv.hostPlatform.system == "x86_64-linux";
  bearbrowser = pkgs.callPackage ../../packages/browser/bearbrowser.nix { };
  browser = if isX86 then bearbrowser else pkgs.firefox;
  browserDesktop = if isX86 then "bearbrowser.desktop" else "firefox.desktop";
in
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

  # BearBrowser replaces Firefox as the shipped browser on the SourceOS desktop
  # (x86_64; Firefox fallback on aarch64 until an aarch64 build exists).
  environment.systemPackages = [ browser ] ++ (with pkgs; [ gnome-tweaks ]);
  environment.gnome.excludePackages = with pkgs; [ gnome-tour epiphany geary ];

  # Make it the default browser (http/https + html).
  xdg.mime.defaultApplications = {
    "text/html" = browserDesktop;
    "x-scheme-handler/http" = browserDesktop;
    "x-scheme-handler/https" = browserDesktop;
    "x-scheme-handler/about" = browserDesktop;
    "x-scheme-handler/unknown" = browserDesktop;
  };
}
