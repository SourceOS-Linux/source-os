{ pkgs ? import <nixpkgs> {} }:
pkgs.runCommand "sourceos-shell-pdf-stack-contract" {
  nativeBuildInputs = [ pkgs.gnugrep ];
} ''
  test -f ${../linux/systemd/sourceos-pdf-secure.service}
  test -f ${../linux/systemd/sourceos-docd.service}
  grep -q 'pdfSecurePort = lib.mkOption' ${../modules/nixos/sourceos-shell/default.nix}
  grep -q 'docdPort = lib.mkOption' ${../modules/nixos/sourceos-shell/default.nix}
  grep -q 'systemd.services.sourceos-pdf-secure' ${../modules/nixos/sourceos-shell/default.nix}
  grep -q 'systemd.services.sourceos-docd' ${../modules/nixos/sourceos-shell/default.nix}
  grep -q 'sourceos-pdf-secure' ${../linux/systemd/sourceos-pdf-secure.service}
  grep -q 'sourceos-docd' ${../linux/systemd/sourceos-docd.service}
  mkdir -p $out
  echo validated > $out/result.txt
''
