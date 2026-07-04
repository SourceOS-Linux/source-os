#!/usr/bin/env bash
set -euo pipefail

# Composite patch helper for Workstation v0.
# Runs shell and fish patch helpers in a single command surface.
# Modes:
# - apply (default)
# - dry-run
# - revert
#
# Behavior:
# - shell helper is always invoked against bash/zsh rc candidates (or SOURCEOS_RC_FILES test hook)
# - fish helper is invoked opportunistically; if fish config does not exist it exits cleanly
#
# Output:
# - human logs to stderr
# - optional machine-readable JSON to stdout via --json

MODE="apply"          # apply|dry-run|revert
EMIT_JSON=0            # 0|1
PROFILE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

info(){ printf "INFO: %s\n" "$*" >&2; }
warn(){ printf "WARN: %s\n" "$*" >&2; }
err(){ printf "ERROR: %s\n" "$*" >&2; }

parse_args(){
  local arg
  for arg in "$@"; do
    case "$arg" in
      apply|dry-run|revert)
        MODE="$arg"
        ;;
      --json)
        EMIT_JSON=1
        ;;
      *)
        err "unknown argument: $arg (use apply|dry-run|revert [--json])"
        exit 2
        ;;
    esac
  done
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

run_one(){
  local label=$1
  local script=$2

  if [[ ! -x "$script" ]]; then
    err "$label helper missing: $script"
    return 2
  fi

  info "running $label helper: $script $MODE"
  "$script" "$MODE"
}

run_one_json(){
  local label=$1
  local script=$2
  local out rc

  if [[ ! -x "$script" ]]; then
    printf '{"kind":"sourceos.fix.%s","mode":"%s","ok":false,"error":"helper missing","helper":"%s"}\n' \
      "$(json_escape "$label")" \
      "$(json_escape "$MODE")" \
      "$(json_escape "$script")"
    return 2
  fi

  set +e
  out="$($script "$MODE" --json)"
  rc=$?
  set -e

  printf '%s' "$out"
  return "$rc"
}

emit_json(){
  local shell_json=$1
  local fish_json=$2
  local ok=$3

  printf '{'
  printf '"kind":"sourceos.fix.all"'
  printf ',"mode":"%s"' "$(json_escape "$MODE")"
  printf ',"ok":%s' "$ok"
  printf ',"results":{' 
  printf '"shell":%s' "$shell_json"
  printf ',"fish":%s' "$fish_json"
  printf '}'
  printf '}'
  printf '\n'
}

main(){
  parse_args "$@"

  if [[ "$EMIT_JSON" == "1" ]]; then
    local shell_json fish_json shell_rc fish_rc ok
    set +e
    shell_json="$(run_one_json shell "$PROFILE_DIR/bin/patch-shell.sh")"
    shell_rc=$?
    fish_json="$(run_one_json fish "$PROFILE_DIR/bin/patch-fish.sh")"
    fish_rc=$?
    set -e

    ok=true
    if [[ $shell_rc -ne 0 || $fish_rc -ne 0 ]]; then
      ok=false
    fi

    emit_json "$shell_json" "$fish_json" "$ok"
    if [[ "$ok" == "false" ]]; then
      exit 2
    fi
    exit 0
  fi

  local rc=0
  run_one shell "$PROFILE_DIR/bin/patch-shell.sh" || rc=2
  run_one fish "$PROFILE_DIR/bin/patch-fish.sh" || rc=2

  info "fix-all complete ($MODE)"
  exit $rc
}

main "$@"
