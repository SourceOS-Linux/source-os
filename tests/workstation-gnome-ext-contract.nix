{ pkgs ? import <nixpkgs> {} }:
pkgs.runCommand "workstation-gnome-ext-contract" {
  nativeBuildInputs = [ pkgs.bash pkgs.gnugrep ];
} ''
  helper=${../profiles/linux-dev/workstation-v0/gnome/check-gnome-extensions.sh}

  # File must exist and be non-empty
  test -f "$helper"
  test -s "$helper"

  # Syntax check
  bash -n "$helper"

  # Static: required keys must be referenced in the script
  grep -q 'gnome_detected'       "$helper"
  grep -q 'gnome_extensions_cli' "$helper"
  grep -q 'gsettings'            "$helper"
  grep -q 'dash_to_dock'         "$helper"
  grep -q 'appindicator'         "$helper"
  grep -q 'favorite_apps'        "$helper"
  grep -q 'dock_position'        "$helper"
  grep -q 'dock_autohide'        "$helper"
  grep -q 'dock_intellihide'     "$helper"

  # Static: pinned extension UUIDs must be present
  grep -q 'dash-to-dock@micxgx.gmail.com'          "$helper"
  grep -q 'appindicatorsupport@rgcjonas.gmail.com'  "$helper"

  # Runtime: run helper in non-GNOME sandbox (no GNOME session, no dbus)
  helper_out=$(bash "$helper")
  grep -F 'gnome_detected='       <<<"$helper_out"
  grep -F 'gnome_extensions_cli=' <<<"$helper_out"
  grep -F 'gsettings='            <<<"$helper_out"
  grep -F 'dash_to_dock='         <<<"$helper_out"
  grep -F 'appindicator='         <<<"$helper_out"
  grep -F 'favorite_apps='        <<<"$helper_out"
  grep -F 'dock_position='        <<<"$helper_out"
  grep -F 'dock_autohide='        <<<"$helper_out"
  grep -F 'dock_intellihide='     <<<"$helper_out"

  mkdir -p $out
  echo validated > $out/result.txt
''
