#!/usr/bin/env bash
set -euo pipefail

# Validate the GNOME dock/extension lane for workstation-v0.
# Emits key=value lines for CI, status, and doctor integration.
# This helper is read-only: it does not install or enable extensions.

have(){ command -v "$1" >/dev/null 2>&1; }

extension_present(){
  local uuid=$1
  if ! have gnome-extensions; then
    printf 'unknown\n'
    return
  fi
  if gnome-extensions list 2>/dev/null | grep -Fxq "$uuid"; then
    printf 'present\n'
  else
    printf 'missing\n'
  fi
}

favorite_apps_state(){
  if ! have gsettings; then
    printf 'unknown\n'
    return
  fi
  local value
  value="$(gsettings get org.gnome.shell favorite-apps 2>/dev/null || true)"
  if [[ -z "$value" ]]; then
    printf 'unknown\n'
    return
  fi
  if grep -Fq 'org.gnome.Nautilus.desktop' <<<"$value" && grep -Fq 'org.gnome.Terminal.desktop' <<<"$value"; then
    printf 'present\n'
  else
    printf 'partial\n'
  fi
}

main(){
  local dash appindicator favorites lane_ok
  dash="$(extension_present 'dash-to-dock@micxgx.gmail.com')"
  appindicator="$(extension_present 'appindicatorsupport@rgcjonas.gmail.com')"
  favorites="$(favorite_apps_state)"
  lane_ok=no

  if have gnome-extensions; then
    printf 'gnome_extensions=present\n'
  else
    printf 'gnome_extensions=missing\n'
  fi

  if have gsettings; then
    printf 'gsettings=present\n'
  else
    printf 'gsettings=missing\n'
  fi

  printf 'dash_to_dock=%s\n' "$dash"
  printf 'appindicator=%s\n' "$appindicator"
  printf 'favorite_apps_visibility=%s\n' "$favorites"

  if [[ "$dash" == "present" && "$appindicator" == "present" && "$favorites" == "present" ]]; then
    lane_ok=yes
  fi
  printf 'gnome_dock_extension_lane_ok=%s\n' "$lane_ok"
}

main "$@"
