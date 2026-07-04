{ pkgs ? import <nixpkgs> {} }:
pkgs.runCommand "mesh-host-runtime-contract" {
  nativeBuildInputs = [ pkgs.gnugrep ];
} ''
  grep -q 'specialArgs = { inherit self; };' ${../flake.nix}
  grep -q '{ self, pkgs, ... }:' ${../hosts/canary-x86_64/default.nix}
  grep -q '{ self, pkgs, ... }:' ${../hosts/stable-x86_64/default.nix}
  grep -q '{ self, pkgs, ... }:' ${../hosts/exit-x86_64/default.nix}
  grep -q 'sourceos.mesh.runtime = {' ${../hosts/canary-x86_64/default.nix}
  grep -q 'sourceos.mesh.runtime = {' ${../hosts/stable-x86_64/default.nix}
  grep -q 'runtime = {' ${../hosts/exit-x86_64/default.nix}
  grep -q 'meshdPackage = self.packages.${pkgs.system}.meshd;' ${../hosts/canary-x86_64/default.nix}
  grep -q 'linkdPackage = self.packages.${pkgs.system}.meshd-linkd;' ${../hosts/canary-x86_64/default.nix}
  grep -q 'meshdPackage = self.packages.${pkgs.system}.meshd;' ${../hosts/stable-x86_64/default.nix}
  grep -q 'linkdPackage = self.packages.${pkgs.system}.meshd-linkd;' ${../hosts/stable-x86_64/default.nix}
  grep -q 'role = "exit"' ${../hosts/exit-x86_64/default.nix}
  grep -q 'exitdPackage = self.packages.${pkgs.system}.meshd-exitd;' ${../hosts/exit-x86_64/default.nix}
  mkdir -p $out
  echo validated > $out/result.txt
''
