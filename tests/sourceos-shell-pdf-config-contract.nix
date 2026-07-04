{ pkgs ? import <nixpkgs> {} }:
pkgs.runCommand "sourceos-shell-pdf-config-contract" {
  nativeBuildInputs = [ pkgs.gnugrep ];
} ''
  grep -q 'pdf-stack.json' ${../modules/nixos/sourceos-shell/default.nix}
  grep -q 'service = "sourceos-docd"' ${../modules/nixos/sourceos-shell/default.nix}
  grep -q 'service = "sourceos-pdf-secure"' ${../modules/nixos/sourceos-shell/default.nix}
  grep -q 'artifact_manifest_required' ${../modules/nixos/sourceos-shell/default.nix}
  grep -q 'signed_and_validation_reports_flow_from_runtime' ${../modules/nixos/sourceos-shell/default.nix}
  mkdir -p $out
  echo validated > $out/result.txt
''
