# Asserts the OS build pins its consumed (vendored) dependencies with integrity,
# and that the verifier accepts the lock shape. hellgraph is consumed vendored,
# never forked — this check fails the build if the pin is missing or malformed.
{ pkgs ? import <nixpkgs> {} }:
pkgs.runCommand "sovereign-vendor-contract" {
  nativeBuildInputs = [ pkgs.python3 pkgs.gnugrep ];
} ''
  lock=${../vendor/hellgraph.lock.json}
  grep -q '"name": "hellgraph"' $lock
  grep -q '"tag": "v0.4.45"' $lock
  grep -q '"git_archive_tar"' $lock
  grep -q '"reason"' $lock
  grep -q '"license": "MIT"' $lock
  # the verifier validates the lock shape (no checkout in the sandbox → shape-only)
  python3 ${../tools/verify_vendor.py} --vendor-dir ${../vendor}
  mkdir -p $out
  echo validated > $out/result.txt
''
