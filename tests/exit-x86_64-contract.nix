{ pkgs ? import <nixpkgs> {} }:
pkgs.runCommand "exit-x86_64-contract" {
  nativeBuildInputs = [ pkgs.gnugrep ];
} ''
  test -f ${../hosts/exit-x86_64/default.nix}
  grep -q '../../profiles/linux-stable/default.nix' ${../hosts/exit-x86_64/default.nix}
  grep -q 'networking.hostName = "exit-x86_64"' ${../hosts/exit-x86_64/default.nix}
  grep -q 'sourceos.mesh = {' ${../hosts/exit-x86_64/default.nix}
  grep -qE 'role = (lib\.mkForce )?"exit"' ${../hosts/exit-x86_64/default.nix}
  grep -q 'exitdPackage = self.packages' ${../hosts/exit-x86_64/default.nix}
  mkdir -p $out
  echo validated > $out/result.txt
''
