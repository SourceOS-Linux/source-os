# Layer-1 boot test: the Server edition boots headless with SSH + firewall.
# Run: nix build .#checks.x86_64-linux.edition-server-boot
{ pkgs, self }:
pkgs.testers.runNixOSTest {
  name = "edition-server-boot";
  nodes.machine = { ... }: {
    imports = [ self.nixosModules.server ];
    virtualisation = { memorySize = 1024; cores = 1; };
  };
  testScript = ''
    machine.start()
    machine.wait_for_unit("multi-user.target")
    machine.wait_for_unit("sshd.service")
    machine.succeed("systemctl is-active sshd.service")
    machine.succeed("systemctl is-active firewall.service")
    # No display manager on a server.
    machine.fail("systemctl is-active display-manager.service")
    machine.succeed("id sourceos")
  '';
}
