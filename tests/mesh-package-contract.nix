{ pkgs ? import <nixpkgs> {} }:
pkgs.runCommand "mesh-package-contract" {
  nativeBuildInputs = [ pkgs.gnugrep ];
} ''
  test -f ${../packages/mesh/meshd.nix}
  test -f ${../packages/mesh/meshd-linkd.nix}
  test -f ${../packages/mesh/meshd-exitd.nix}
  grep -q 'packages = forAllSystems' ${../flake.nix}
  grep -q 'meshd = pkgs.callPackage ./packages/mesh/meshd.nix' ${../flake.nix}
  grep -q 'meshd-linkd = pkgs.callPackage ./packages/mesh/meshd-linkd.nix' ${../flake.nix}
  grep -q 'meshd-exitd = pkgs.callPackage ./packages/mesh/meshd-exitd.nix' ${../flake.nix}
  grep -q 'register-helper' ${../packages/mesh/meshd.nix}
  grep -q 'render-link-plan' ${../packages/mesh/meshd.nix}
  grep -q 'refresh-registration' ${../packages/mesh/meshd-linkd.nix}
  grep -q 'validate_nft' ${../packages/mesh/meshd-exitd.nix}
  grep -q 'systemd-notify' ${../packages/mesh/meshd.nix}
  grep -q 'systemd-notify' ${../packages/mesh/meshd-linkd.nix}
  grep -q 'systemd-notify' ${../packages/mesh/meshd-exitd.nix}
  mkdir -p $out
  echo validated > $out/result.txt
''
