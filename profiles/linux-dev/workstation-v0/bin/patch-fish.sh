#!/usr/bin/env bash
set -euo pipefail

# Patch fish config to source SourceOS fish spine.
# Idempotent marker block.
# Modes:
# - apply (default)
# - dry-run
# - revert (remove the marker block)
#
# Output:
# - human logs to stderr
# - optional machine-readable JSON to stdout via --json
#
# CI/test hook:
# - SOURCEOS_FISH_CONFIG may override the fish config path.

MODE="apply"      # apply|dry-run|revert
EMIT_JSON=0        # 0|1

info(){ printf "INFO: %s\n" "$*" >&2; }
warn(){ printf "WARN: %s\n" "$*" >&2; }
err(){ printf "ERROR: %s\n" "$*" >&2; }

marker_start="# >>> sourceos workstation-v0 (fish) >>>"
marker_end="# <<< sourceos workstation-v0 (fish) <<<"

RESULT_ACTION=""
RESULT_FILE=""

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

record_result(){
  RESULT_ACTION="$1"
  RESULT_FILE="$2"
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

emit_json(){
  printf '{'
  printf '"kind":"sourceos.fix.fish"'
  printf ',"mode":"%s"' "$(json_escape "$MODE")"
  printf ',"ok":true'
  printf ',"result":{' 
  printf '"file":"%s"' "$(json_escape "$RESULT_FILE")"
  printf ',"action":"%s"' "$(json_escape "$RESULT_ACTION")"
  printf '}'
  printf '}'
  printf '\n'
}

fish_cfg(){
  if [[ -n "${SOURCEOS_FISH_CONFIG:-}" ]]; then
    printf '%s\n' "$SOURCEOS_FISH_CONFIG"
  else
    printf '%s\n' "${XDG_CONFIG_HOME:-$HOME/.config}/fish/config.fish"
  fi
}

has_block(){
  local f=$1
  grep -Fqx "$marker_start" "$f" 2>/dev/null
}

block(){
  cat <<EOF
${marker_start}
# Added by SourceOS Workstation v0
set spine_path "\${XDG_CONFIG_HOME:-\$HOME/.config}/sourceos/shell/common.fish"
if test -f "\$spine_path"
  source "\$spine_path"
end
${marker_end}
EOF
}

apply_to_file(){
  local f=$1

  if [[ ! -e "$f" ]]; then
    warn "fish config not found (skipping): $f"
    record_result missing_file "$f"
    return 0
  fi

  if has_block "$f"; then
    info "already patched: $f"
    record_result already_patched "$f"
    return 0
  fi

  if [[ "$MODE" == "dry-run" ]]; then
    info "would patch: $f"
    record_result would_patch "$f"
    return 0
  fi

  {
    printf '\n'
    block
    printf '\n'
  } >> "$f"

  info "patched: $f"
  record_result patched "$f"
}

revert_from_file(){
  local f=$1

  if [[ ! -e "$f" ]]; then
    warn "fish config not found (skipping): $f"
    record_result missing_file "$f"
    return 0
  fi

  if ! has_block "$f"; then
    info "no patch block present: $f"
    record_result no_patch "$f"
    return 0
  fi

  local tmp
  tmp="$(mktemp)"

  awk -v s="$marker_start" -v e="$marker_end" '
    $0 == s {skip=1; next}
    $0 == e {skip=0; next}
    skip {next}
    {print}
  ' "$f" > "$tmp"

  mv "$tmp" "$f"
  info "reverted: $f"
  record_result reverted "$f"
}

main(){
  parse_args "$@"

  local f
  f="$(fish_cfg)"

  if [[ "$MODE" == "revert" ]]; then
    revert_from_file "$f"
  else
    apply_to_file "$f"
  fi

  info "done"
  if [[ "$EMIT_JSON" == "1" ]]; then
    emit_json
  fi
}

main "$@"
