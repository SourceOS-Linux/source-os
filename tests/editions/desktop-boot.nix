# Layer-1 boot test: the Desktop (GNOME) edition boots to the display manager
# in a QEMU VM. Deterministic, no LLM. Run: nix build .#checks.x86_64-linux.edition-desktop-boot
{ pkgs, self }:
pkgs.testers.runNixOSTest {
  name = "edition-desktop-boot";
  nodes.machine = { ... }: {
    imports = [ self.nixosModules.desktop-gnome ];
    virtualisation = {
      memorySize = 3072;   # GNOME + GDM need headroom
      cores = 2;
      diskSize = 8192;
    };
  };
  testScript = ''
    machine.start()
    machine.wait_for_unit("display-manager.service")
    machine.wait_for_unit("graphical.target")
    # GDM greeter should be listening; no failed units at the graphical boundary.
    machine.succeed("systemctl is-active display-manager.service")
    machine.succeed("test -z \"$(systemctl --failed --no-legend --plain | grep -v gnome-remote-desktop || true)\"")
    print(machine.succeed("systemctl --version | head -1"))
  '';
}
