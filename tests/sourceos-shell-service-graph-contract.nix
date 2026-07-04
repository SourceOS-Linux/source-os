{ pkgs ? import <nixpkgs> {} }:
pkgs.runCommand "sourceos-shell-service-graph-contract" {
  nativeBuildInputs = [ pkgs.gnugrep ];
} ''
  test -f ${../linux/systemd/sourceos-shell.target}
  grep -q 'sourceos-shell.service sourceos-router.service sourceos-pdf-secure.service sourceos-docd.service' ${../linux/systemd/sourceos-shell.target}
  grep -q 'systemd.targets.sourceos-shell' ${../modules/nixos/sourceos-shell/default.nix}
  grep -q 'partOf = \[ "sourceos-shell.target" \]' ${../modules/nixos/sourceos-shell/default.nix}
  grep -q 'sourceos-shell.target' ${../docs/sourceos-shell-service-graph.md}
  mkdir -p $out
  echo validated > $out/result.txt
''
