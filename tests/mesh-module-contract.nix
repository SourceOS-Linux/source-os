{ pkgs ? import <nixpkgs> {} }:
pkgs.runCommand "mesh-module-contract" {
  nativeBuildInputs = [ pkgs.gnugrep ];
} ''
  test -f ${../modules/nixos/mesh/default.nix}
  grep -q '../../modules/nixos/mesh/default.nix' ${../profiles/linux-dev/default.nix}
  grep -q '../../modules/nixos/mesh/default.nix' ${../profiles/linux-candidate/default.nix}
  grep -q '../../modules/nixos/mesh/default.nix' ${../profiles/linux-stable/default.nix}
  grep -q 'role = "builder"' ${../profiles/linux-dev/default.nix}
  grep -q 'role = "peer"' ${../profiles/linux-candidate/default.nix}
  grep -q 'role = "relay"' ${../profiles/linux-stable/default.nix}
  grep -q 'activateTemplates' ${../modules/nixos/mesh/default.nix}
  grep -q 'environment.etc' ${../modules/nixos/mesh/default.nix}
  mkdir -p $out
  echo validated > $out/result.txt
''
