# Layer-1.5 install-to-disk test: prove the REAL clean-disk installer
# (scripts/install-image.sh) partitions a blank disk, installs SourceOS, and the
# installed system BOOTS FROM DISK on its own bootloader — not just that the
# edition config boots (that's edition-server-boot).
#
# Two phases on one disk (the nixpkgs installer-test pattern):
#   1. `installer` VM (NixOS installation environment) runs install-image.sh
#      against a blank /dev/vda, installing a PREBUILT server toplevel offline.
#   2. The same disk is rebooted as `target` (useBootLoader) — we assert it comes
#      up to multi-user.target off its own systemd-boot ESP.
#
# Uses the server edition (smallest closure). Heavy (full install + 2 boots), so
# it's wired opt-in in CI (image-tests run_install), not a required PR gate.
#
# Run: nix build .#checks.x86_64-linux.edition-server-install -L
{ pkgs, self }:
let
  lib = pkgs.lib;

  # The exact system installed onto the target disk. Filesystem layout matches
  # what install-image.sh creates: ext4 root labeled "nixos", vfat ESP labeled
  # "EFI" mounted at /boot, systemd-boot (canTouchEfiVariables=false).
  targetSystem = (pkgs.nixos ({ modulesPath, ... }: {
    imports = [
      self.nixosModules.server
      (modulesPath + "/testing/test-instrumentation.nix")
    ];
    boot.loader.systemd-boot.enable = true;
    boot.loader.grub.enable = lib.mkForce false;
    boot.loader.efi.canTouchEfiVariables = false;
    fileSystems."/"     = { device = "/dev/disk/by-label/nixos"; fsType = "ext4"; };
    fileSystems."/boot" = { device = "/dev/disk/by-label/EFI";   fsType = "vfat"; };
    networking.hostName = "sourceos";
    # root is left passwordless by test-instrumentation.nix (login-free console).
  })).config.system.build.toplevel;
in
pkgs.testers.runNixOSTest {
  name = "edition-server-install";

  # installation-device.nix sets nixpkgs.overlays, which conflicts with the
  # read-only pkgs runNixOSTest installs by default.
  node.pkgsReadOnly = false;

  nodes = {
    # Phase 1: the installation environment. Its OWN root runs from /dev/vdb so
    # /dev/vda stays blank for the install (and becomes the target's boot disk).
    installer = { config, pkgs, lib, modulesPath, ... }: {
      imports = [ (modulesPath + "/profiles/installation-device.nix") ];

      virtualisation.emptyDiskImages = [ 2048 ]; # /dev/vdb = installer root
      virtualisation.rootDevice = "/dev/vdb";
      virtualisation.diskSize = 8192;            # /dev/vda = blank install target
      virtualisation.memorySize = 3072;
      virtualisation.cores = 2;

      # /dev/vdb starts blank — auto-format it as the installer's root so the
      # installer environment boots. systemd initrd uses autoFormat; the classic
      # initrd path mke2fs's it in postDeviceCommands.
      virtualisation.fileSystems."/".autoFormat = config.boot.initrd.systemd.enable;
      boot.initrd.extraUtilsCommands = lib.mkIf (!config.boot.initrd.systemd.enable) ''
        copy_bin_and_libs ${pkgs.e2fsprogs}/bin/mke2fs
      '';
      boot.initrd.postDeviceCommands = lib.mkIf (!config.boot.initrd.systemd.enable) ''
        FSTYPE=$(blkid -o value -s TYPE /dev/vdb || true)
        PARTTYPE=$(blkid -o value -s PTTYPE /dev/vdb || true)
        if test -z "$FSTYPE" -a -z "$PARTTYPE"; then
            mke2fs -t ext4 /dev/vdb
        fi
      '';

      # No network in the sandbox: the target closure must already be present.
      # It is seeded read-only via the shared host store (extraDependencies).
      nix.settings.substituters = lib.mkForce [ ];
      system.extraDependencies = [ targetSystem ];

      # The real installer script + the tools it shells out to.
      environment.etc."sourceos/install-image.sh".source = ../../scripts/install-image.sh;
      environment.systemPackages = with pkgs; [
        gptfdisk dosfstools e2fsprogs util-linux parted nixos-install-tools
      ];
    };

    # Phase 2: same disk, booting on its own bootloader this time.
    target = { ... }: {
      virtualisation.useBootLoader = true;
      virtualisation.useEFIBoot = true;
      virtualisation.useDefaultFilesystems = false;
      virtualisation.efi.keepVariables = false;
      # Placeholder root; the real one is whatever the installer wrote to /dev/vda.
      virtualisation.fileSystems."/" = {
        device = "/dev/disk/by-label/nixos";
        fsType = "ext4";
      };
    };
  };

  testScript = ''
    installer.start()
    installer.wait_for_unit("multi-user.target")

    with subtest("Clean-disk installer partitions /dev/vda and installs SourceOS"):
        installer.succeed(
            "SOURCEOS_ASSUME_YES=1 bash /etc/sourceos/install-image.sh "
            "--edition server --system ${targetSystem} /dev/vda >&2"
        )

    with subtest("Installer created the expected GPT layout + filesystems"):
        installer.succeed("test -b /dev/vda1")  # ESP
        installer.succeed("test -b /dev/vda2")  # root
        installer.succeed("blkid /dev/vda1 | grep -q 'LABEL=\"EFI\"'")
        installer.succeed("blkid /dev/vda2 | grep -q 'LABEL=\"nixos\"'")

    with subtest("Shut the installer down cleanly"):
        installer.succeed("sync")
        installer.shutdown()

    # Same machine, different boot: now boot from the freshly installed disk.
    target.state_dir = installer.state_dir

    with subtest("The installed system boots from disk on its own bootloader"):
        target.start()
        target.wait_for_unit("multi-user.target")

    with subtest("systemd-boot was installed to the ESP"):
        target.wait_for_unit("local-fs.target")
        target.succeed("test -e /boot/EFI/systemd/systemd-bootx64.efi")
        target.succeed("test -e /boot/loader/loader.conf")

    with subtest("It is the SourceOS server edition we installed"):
        target.succeed("test \"$(hostname)\" = sourceos")
        target.succeed("id sourceos")
        target.succeed("systemctl is-active sshd.service")
        # server edition is headless
        target.fail("systemctl is-active display-manager.service")
  '';
}
