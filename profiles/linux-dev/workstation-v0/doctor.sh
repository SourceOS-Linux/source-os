#!/usr/bin/env bash
set -euo pipefail

fail=0
EMIT_JSON=0

RESULT_LEVELS=()
RESULT_NAMES=()
RESULT_MESSAGES=()

info(){ printf "INFO: %s\n" "$*" >&2; }
warn(){ printf "WARN: %s\n" "$*" >&2; }
err(){ printf "ERROR: %s\n" "$*" >&2; fail=1; }

have(){ command -v "$1" >/dev/null 2>&1; }

parse_args(){
  local arg
  for arg in "$@"; do
    case "$arg" in
      --json)
        EMIT_JSON=1
        ;;
      *)
        err "unknown argument: $arg (use --json)"
        exit 2
        ;;
    esac
  done
}

record_result(){
  RESULT_LEVELS+=("$1")
  RESULT_NAMES+=("$2")
  RESULT_MESSAGES+=("$3")
}

json_escape(){
  local s=${1:-}
  s=${s//\\/\\\\}
  s=${s//"/\\"}
  s=${s//$'\n'/\\n}
  s=${s//$'\r'/\\r}
  s=${s//$'\t'/\\t}
  printf '%s' "$s"
}

count_level(){
  local needle=$1
  local count=0
  local i
  for ((i=0;i<${#RESULT_LEVELS[@]};i++)); do
    if [[ "${RESULT_LEVELS[$i]}" == "$needle" ]]; then
      count=$((count + 1))
    fi
  done
  printf '%d' "$count"
}

emit_json(){
  local i
  local ok=true
  if [[ $fail -ne 0 ]]; then
    ok=false
  fi

  printf '{'
  printf '"kind":"sourceos.doctor"'
  printf ',"profile":"linux-dev/workstation-v0"'
  printf ',"ok":%s' "$ok"
  printf ',"summary":{'
  printf '"ok":%s' "$(count_level ok)"
  printf ',"warn":%s' "$(count_level warn)"
  printf ',"error":%s' "$(count_level error)"
  printf ',"info":%s' "$(count_level info)"
  printf '}'
  printf ',"results":['
  for ((i=0;i<${#RESULT_LEVELS[@]};i++)); do
    [[ $i -gt 0 ]] && printf ','
    printf '{"level":"%s","name":"%s","message":"%s"}' \
      "$(json_escape "${RESULT_LEVELS[$i]}")" \
      "$(json_escape "${RESULT_NAMES[$i]}")" \
      "$(json_escape "${RESULT_MESSAGES[$i]}")"
  done
  printf ']'
  printf '}'
  printf '\n'
}

check(){
  local bin=$1
  if have "$bin"; then
    info "ok: $bin"
    record_result ok "$bin" "present"
  else
    err "missing: $bin"
    record_result error "$bin" "missing"
  fi
}

gnome_detect(){
  [[ "${XDG_CURRENT_DESKTOP:-}" == *GNOME* ]] && return 0
  [[ "${DESKTOP_SESSION:-}" == *gnome* ]] && return 0
  return 1
}

check_gnome_extension(){
  local uuid=$1
  if ! have gnome-extensions; then
    warn "gnome-extensions missing; cannot validate extension: $uuid"
    record_result warn "gnome-extension:$uuid" "gnome-extensions missing; cannot validate"
    return 0
  fi

  if gnome-extensions list | grep -qx "$uuid"; then
    info "gnome-ext present: $uuid"
    record_result ok "gnome-extension:$uuid" "present"
  else
    warn "gnome-ext missing: $uuid"
    record_result warn "gnome-extension:$uuid" "missing"
  fi
}

check_sourceos_binding(){
  if ! have sourceos; then
    err "missing: sourceos"
    record_result error "sourceos-binding" "sourceos not found on PATH"
    return
  fi

  local expected
  expected="$(cd "$(dirname "$0")" && pwd)"

  local got
  got="$(sourceos profile path 2>/dev/null || true)"

  if [[ -z "$got" ]]; then
    err "sourceos present but 'sourceos profile path' failed"
    record_result error "sourceos-binding" "sourceos profile path failed"
    return
  fi

  if [[ "$got" != "$expected" ]]; then
    err "sourceos points to different profile dir: got=$got expected=$expected"
    record_result error "sourceos-binding" "profile mismatch"
    return
  fi

  info "ok: sourceos (profile bound)"
  record_result ok "sourceos-binding" "profile bound"
}

check_launcher(){
  if have fuzzel || have wofi || have rofi; then
    info "ok: launcher (fuzzel/wofi/rofi)"
    record_result ok launcher "present (fuzzel/wofi/rofi)"
    return
  fi
  err "missing: launcher (need fuzzel/wofi/rofi for sourceos palette)"
  record_result error launcher "missing (need fuzzel/wofi/rofi)"
}

check_input_backend(){
  if have input-remapper-control; then
    info "ok: input backend (input-remapper)"
    record_result ok input-backend "input-remapper"
    return
  fi
  if have xremap; then
    info "ok: input backend (xremap compatibility)"
    record_result ok input-backend "xremap"
    return
  fi
  if have xkeysnail; then
    info "ok: input backend (xkeysnail / kinto compatibility)"
    record_result ok input-backend "xkeysnail"
    return
  fi

  warn "no keyboard remap backend detected (input-remapper/xremap/xkeysnail)"
  record_result warn input-backend "missing (input-remapper/xremap/xkeysnail)"
}

check_fusuma_lane(){
  local cfg="${XDG_CONFIG_HOME:-$HOME/.config}/fusuma/config.yml"
  local svc="${XDG_CONFIG_HOME:-$HOME/.config}/systemd/user/sourceos-fusuma.service"

  if have fusuma; then
    info "ok: fusuma"
    record_result ok fusuma "binary present"
  else
    warn "fusuma missing"
    record_result warn fusuma "binary missing"
  fi

  if [[ -f "$cfg" ]]; then
    info "ok: fusuma config"
    record_result ok fusuma-config "$cfg"
  else
    warn "fusuma config missing: $cfg"
    record_result warn fusuma-config "missing"
  fi

  if [[ -f "$svc" ]]; then
    info "ok: fusuma user service"
    record_result ok fusuma-service "$svc"
  else
    warn "fusuma user service missing: $svc"
    record_result warn fusuma-service "missing"
  fi

  if id -nG "$USER" 2>/dev/null | grep -qw input; then
    info "ok: user is in input group"
    record_result ok input-group "present"
  else
    warn "user is not in input group (fusuma may lack device access)"
    record_result warn input-group "missing"
  fi
}

check_lampstand_lane(){
  local search_helper="$(cd "$(dirname "$0")" && pwd)/bin/sourceos-search.sh"

  if [[ -f "$search_helper" ]]; then
    info "ok: sourceos search helper"
    record_result ok sourceos-search-helper "$search_helper"
  else
    warn "sourceos search helper missing: $search_helper"
    record_result warn sourceos-search-helper "missing"
  fi

  if have lampstand; then
    info "ok: lampstand"
    record_result ok lampstand "binary present"
    return
  fi

  if have python3 && python3 -c 'import lampstand.cli' >/dev/null 2>&1; then
    info "ok: lampstand python module"
    record_result ok lampstand "python module importable"
    return
  fi

  warn "lampstand missing (search surface exists but backend is unavailable)"
  record_result warn lampstand "missing backend"
}

check_lampstand_unit(){
  local helper="$(cd "$(dirname "$0")" && pwd)/bin/check-lampstand-unit.sh"
  local out unit_file enabled active

  if [[ ! -f "$helper" ]]; then
    warn "Lampstand unit helper missing: $helper"
    record_result warn lampstand-unit-helper "missing"
    return
  fi

  if ! out="$(bash "$helper" 2>/dev/null)"; then
    warn "Lampstand unit helper failed"
    record_result warn lampstand-unit "helper failed"
    return
  fi

  unit_file="$(awk -F= '$1=="unit_file" {print $2}' <<<"$out" | tail -n1)"
  enabled="$(awk -F= '$1=="enabled" {print $2}' <<<"$out" | tail -n1)"
  active="$(awk -F= '$1=="active" {print $2}' <<<"$out" | tail -n1)"

  if [[ "$unit_file" == "present" ]]; then
    info "ok: Lampstand user unit file"
    record_result ok lampstand-unit-file "present"
  else
    warn "Lampstand user unit file missing"
    record_result warn lampstand-unit-file "missing"
  fi

  case "$enabled" in
    yes)
      info "ok: Lampstand user unit enabled"
      record_result ok lampstand-unit-enabled "yes"
      ;;
    no)
      warn "Lampstand user unit not enabled"
      record_result warn lampstand-unit-enabled "no"
      ;;
    *)
      info "Lampstand user unit enabled state unknown"
      record_result info lampstand-unit-enabled "unknown"
      ;;
  esac

  case "$active" in
    yes)
      info "ok: Lampstand user unit active"
      record_result ok lampstand-unit-active "yes"
      ;;
    no)
      warn "Lampstand user unit not active"
      record_result warn lampstand-unit-active "no"
      ;;
    *)
      info "Lampstand user unit active state unknown"
      record_result info lampstand-unit-active "unknown"
      ;;
  esac
}

check_workstation_polish(){
  local helper="$(cd "$(dirname "$0")" && pwd)/bin/check-workstation-polish.sh"
  local out policy_ok

  if [[ ! -f "$helper" ]]; then
    warn "workstation polish helper missing: $helper"
    record_result warn workstation-polish-helper "missing"
    return
  fi

  if ! out="$(bash "$helper" 2>/dev/null)"; then
    warn "workstation polish helper failed"
    record_result warn workstation-polish "helper failed"
    return
  fi

  if grep -Fqx 'mac_polish.helper=present' <<<"$out"; then
    info "ok: Mac polish helper signal"
    record_result ok mac-polish-helper "present"
  else
    warn "Mac polish helper signal missing"
    record_result warn mac-polish-helper "missing"
  fi

  if grep -Fqx 'keyboard_policy.helper=present' <<<"$out"; then
    info "ok: keyboard policy helper signal"
    record_result ok keyboard-policy-helper "present"
  else
    warn "keyboard policy helper signal missing"
    record_result warn keyboard-policy-helper "missing"
  fi

  policy_ok="$(awk -F= '$1=="keyboard_policy.policy_ok" {print $2}' <<<"$out" | tail -n1)"
  if [[ "$policy_ok" == "yes" ]]; then
    info "ok: keyboard policy valid"
    record_result ok keyboard-policy "valid"
  else
    warn "keyboard policy is not valid"
    record_result warn keyboard-policy "invalid"
  fi
}

check_gsettings_equals(){
  local schema=$1
  local key=$2
  local expected=$3
  local name=$4
  local got
  got=$(gsettings get "$schema" "$key" 2>/dev/null || true)
  if [[ "$got" == "$expected" ]]; then
    info "ok: $name"
    record_result ok "$name" "$expected"
  else
    warn "$name mismatch: got=${got:-unset} expected=$expected"
    record_result warn "$name" "expected=$expected got=${got:-unset}"
  fi
}

check_gsettings_contains(){
  local schema=$1
  local key=$2
  local needle=$3
  local name=$4
  local got
  got=$(gsettings get "$schema" "$key" 2>/dev/null || true)
  if grep -Fq "$needle" <<<"$got"; then
    info "ok: $name"
    record_result ok "$name" "$needle"
  else
    warn "$name missing: $needle"
    record_result warn "$name" "missing $needle"
  fi
}

check_mac_defaults(){
  check_gsettings_equals org.gnome.desktop.wm.preferences button-layout "'close,minimize,maximize:'" mac-button-layout
  check_gsettings_equals org.gnome.desktop.interface enable-hot-corners "false" mac-hot-corners
  check_gsettings_equals org.gnome.desktop.interface clock-format "'12h'" mac-clock-format
  check_gsettings_contains org.gnome.settings-daemon.plugins.media-keys custom-keybindings "custom1" mac-custom-files-keybinding
  check_gsettings_contains org.gnome.settings-daemon.plugins.media-keys custom-keybindings "custom2" mac-custom-terminal-keybinding
  check_gsettings_equals org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/ binding "'<Super>e'" mac-files-binding
  check_gsettings_equals org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom2/ binding "'<Super>Return'" mac-terminal-binding
}

main(){
  parse_args "$@"

  info "doctor: linux-dev/workstation-v0"

  check git
  check ssh
  check podman
  check toolbox
  check wl-copy
  check jq

  if have xclip; then
    info "ok: xclip"
    record_result ok xclip "present"
  else
    info "note: xclip missing (only needed on X11)"
    record_result info xclip "missing optional (only needed on X11)"
  fi

  check brew
  check_sourceos_binding

  check fzf
  check atuin
  check bat
  check zoxide
  check eza
  check yazi
  check gum
  check direnv
  check rg
  check fd
  check tmux
  check lazygit
  check gh
  check tig

  check sesh
  check procs
  check sd
  check entr
  check curlie

  check jnv
  check gojq

  check rclone
  check mc
  check rsync
  check_lampstand_lane
  check_lampstand_unit
  check_workstation_polish

  if gnome_detect; then
    record_result info gnome "detected"
    check_launcher
    check_input_backend
    check_fusuma_lane

    if have gsettings; then
      info "gnome: detected; gsettings present"
      record_result ok gsettings "present"

      local base="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/"
      local custom0="${base}custom0/"
      local bindings
      bindings=$(gsettings get org.gnome.settings-daemon.plugins.media-keys custom-keybindings || true)
      info "gnome: custom-keybindings = ${bindings}"
      record_result info gnome-custom-keybindings "$bindings"
      local hk
      hk=$(gsettings get org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:${custom0} binding 2>/dev/null || true)
      if [[ -n "$hk" ]]; then
        info "gnome: hotkey binding = ${hk}"
        record_result info gnome-hotkey "$hk"
      fi

      check_mac_defaults
    else
      warn "gnome: detected but gsettings missing"
      record_result warn gsettings "missing on GNOME host"
    fi

    check_gnome_extension 'dash-to-dock@micxgx.gmail.com'
    check_gnome_extension 'appindicatorsupport@rgcjonas.gmail.com'

  else
    info "gnome: not detected (ok)"
    record_result info gnome "not detected"
  fi

  if [[ "$EMIT_JSON" == "1" ]]; then
    emit_json
  fi

  if [[ $fail -ne 0 ]]; then
    info "doctor: FAIL"
    exit 2
  fi

  info "doctor: OK"
}

main "$@"
