{ pkgs ? import <nixpkgs> {} }:
pkgs.runCommand "sourceos-shell-keyboard-equivalence-contract" {
  nativeBuildInputs = [ pkgs.gnugrep ];
} ''
  test -f ${../linux/desktop/sourceos-keyboard-equivalence.conf}
  grep -q 'mode=kinto-bridge' ${../linux/desktop/sourceos-keyboard-equivalence.conf}
  grep -q 'platform-model=mac-like' ${../linux/desktop/sourceos-keyboard-equivalence.conf}
  grep -q 'terminal-model=mac-terminal-like' ${../linux/desktop/sourceos-keyboard-equivalence.conf}
  grep -q '# GUI lanes' ${../linux/desktop/sourceos-keyboard-equivalence.conf}
  grep -q '# Terminal lanes' ${../linux/desktop/sourceos-keyboard-equivalence.conf}
  grep -q 'invariant=gui_terminal_split_explicit' ${../linux/desktop/sourceos-keyboard-equivalence.conf}
  mkdir -p $out
  echo validated > $out/result.txt
''
