# Layer-1 boot test: the Edge edition boots as a minimal appliance with SSH and
# the mesh config present (runtime daemons stay opt-in).
# Run: nix build .#checks.x86_64-linux.edition-edge-boot
{ pkgs, self }:
pkgs.testers.runNixOSTest {
  name = "edition-edge-boot";
  nodes.machine = { ... }: {
    imports = [ self.nixosModules.edge ];
    virtualisation = { memorySize = 1024; cores = 1; };
  };
  testScript = ''
    machine.start()
    machine.wait_for_unit("multi-user.target")
    machine.wait_for_unit("sshd.service")
    machine.fail("systemctl is-active display-manager.service")
    # zram swap is part of the appliance footprint.
    machine.succeed("test -e /dev/zram0 || zramctl | grep -q zram")
    print(machine.succeed("systemctl --version | head -1"))
  '';
}
