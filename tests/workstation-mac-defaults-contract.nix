{ pkgs ? import <nixpkgs> {} }:
pkgs.runCommand "workstation-mac-defaults-contract" {
  nativeBuildInputs = [ pkgs.gnugrep ];
} ''
  test -f ${../profiles/linux-dev/workstation-v0/gnome/mac-defaults.sh}
  grep -q "enable-hot-corners false" ${../profiles/linux-dev/workstation-v0/gnome/mac-defaults.sh}
  grep -q "clock-format '12h'" ${../profiles/linux-dev/workstation-v0/gnome/mac-defaults.sh}
  grep -q "locate-pointer true" ${../profiles/linux-dev/workstation-v0/gnome/mac-defaults.sh}
  grep -q "click-policy 'double'" ${../profiles/linux-dev/workstation-v0/gnome/mac-defaults.sh}
  grep -q "show-delete-permanently true" ${../profiles/linux-dev/workstation-v0/gnome/mac-defaults.sh}
  grep -q "favorite-apps" ${../profiles/linux-dev/workstation-v0/gnome/mac-defaults.sh}
  grep -q 'set_custom_binding custom1 "SourceOS Files"' ${../profiles/linux-dev/workstation-v0/gnome/mac-defaults.sh}
  grep -q 'set_custom_binding custom2 "SourceOS Terminal"' ${../profiles/linux-dev/workstation-v0/gnome/mac-defaults.sh}
  mkdir -p $out
  echo validated > $out/result.txt
''
