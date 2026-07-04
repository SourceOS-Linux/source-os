{ pkgs ? import <nixpkgs> {} }:
pkgs.runCommand "sourceos-syncd-package-contract" {
  nativeBuildInputs = [ pkgs.gnugrep ];
} ''
  test -f ${../packages/sourceos-syncd/default.nix}
  grep -q 'buildPythonApplication' ${../packages/sourceos-syncd/default.nix}
  grep -q 'sourceos-syncd' ${../packages/sourceos-syncd/default.nix}
  grep -q 'sourceos_syncd.cli' ${../packages/sourceos-syncd/default.nix}
  grep -q 'sourceos-syncd-src' ${../packages/sourceos-syncd/default.nix}
  grep -q 'sourceos-syncd = pkgs.callPackage ./packages/sourceos-syncd/default.nix' ${../flake.nix}
  grep -q 'sourceos-syncd-src' ${../flake.nix}
  mkdir -p $out
  echo validated > $out/result.txt
''
