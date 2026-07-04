{ pkgs ? import <nixpkgs> {} }:
pkgs.runCommand "mesh-runtime-contract" {
  nativeBuildInputs = [ pkgs.gnugrep ];
} ''
  grep -q 'sourceos.mesh.runtime' ${../modules/nixos/mesh/default.nix}
  grep -q 'meshdPackage' ${../modules/nixos/mesh/default.nix}
  grep -q 'linkdPackage' ${../modules/nixos/mesh/default.nix}
  grep -q 'exitdPackage' ${../modules/nixos/mesh/default.nix}
  grep -q 'users.users' ${../modules/nixos/mesh/default.nix}
  grep -q 'systemd.services.meshd =' ${../modules/nixos/mesh/default.nix}
  grep -q 'systemd.services.meshd-linkd =' ${../modules/nixos/mesh/default.nix}
  grep -q 'systemd.services.meshd-exitd =' ${../modules/nixos/mesh/default.nix}
  grep -q 'sourceos/mesh/runtime/meshd.toml' ${../modules/nixos/mesh/default.nix}
  grep -q 'runtime.enable requires both' ${../modules/nixos/mesh/default.nix}
  mkdir -p $out
  echo validated > $out/result.txt
''
