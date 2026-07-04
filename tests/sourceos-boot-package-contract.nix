{ pkgs ? import <nixpkgs> {} }:
pkgs.runCommand "sourceos-boot-package-contract" {
  nativeBuildInputs = [ pkgs.gnugrep ];
} ''
  test -f ${../packages/sourceos-boot/default.nix}
  grep -q 'buildPythonApplication' ${../packages/sourceos-boot/default.nix}
  grep -q 'sourceos-boot' ${../packages/sourceos-boot/default.nix}
  grep -q 'sourceos_boot.cli' ${../packages/sourceos-boot/default.nix}
  grep -q 'sourceos-boot-src' ${../packages/sourceos-boot/default.nix}
  grep -q 'sourceos-boot = pkgs.callPackage ./packages/sourceos-boot/default.nix' ${../flake.nix}
  grep -q 'sourceos-boot-src' ${../flake.nix}
  mkdir -p $out
  echo validated > $out/result.txt
''
