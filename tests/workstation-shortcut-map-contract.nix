{ pkgs ? import <nixpkgs> {} }:
pkgs.runCommand "workstation-shortcut-map-contract" {
  nativeBuildInputs = [ pkgs.gnugrep ];
} ''
  # Document must exist and be non-empty
  test -s ${../docs/workstation/shortcut-map.md}

  # Active screenshot bindings must be present
  grep -q "Super+Shift+3" ${../docs/workstation/shortcut-map.md}
  grep -q "Super+Shift+4" ${../docs/workstation/shortcut-map.md}
  grep -q "Super+Shift+5" ${../docs/workstation/shortcut-map.md}
  grep -q "Super+Shift+6" ${../docs/workstation/shortcut-map.md}

  # Palette and app-launch bindings must be documented
  grep -q "Super+Space" ${../docs/workstation/shortcut-map.md}
  grep -q "Super+E"     ${../docs/workstation/shortcut-map.md}
  grep -q "Super+Return" ${../docs/workstation/shortcut-map.md}

  # Document must distinguish active from proposed/future bindings
  grep -q "Active bindings"   ${../docs/workstation/shortcut-map.md}
  grep -q "future"            ${../docs/workstation/shortcut-map.md}
  grep -q "non-active\|non.active\|NOT currently enforced" ${../docs/workstation/shortcut-map.md}

  # Helper references must be present
  grep -q "mac-defaults.sh"    ${../docs/workstation/shortcut-map.md}
  grep -q "palette-hotkey.sh"  ${../docs/workstation/shortcut-map.md}
  grep -q "doctor.sh"          ${../docs/workstation/shortcut-map.md}

  mkdir -p $out
  echo validated > $out/result.txt
''
