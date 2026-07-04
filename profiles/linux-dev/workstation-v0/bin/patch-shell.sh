#!/usr/bin/env bash
set -euo pipefail

# Patch shell rc files to:
# - ensure $HOME/.local/bin is on PATH
# - source the SourceOS shell spine (`$XDG_CONFIG_HOME/sourceos/shell/common.sh`)
#
# Idempotent: uses a marker block.
# Modes:
# - apply (default)
# - dry-run (for apply)
# - revert (remove the marker block)
#
# Output:
# - human logs to stderr
# - optional machine-readable JSON to stdout via --json
#
# CI/test hook:
# - SOURCEOS_RC_FILES may be set to a colon-separated list of rc files.

MODE="apply"          # apply|dry-run|revert
EMIT_JSON=0            # 0|1

info(){ printf "INFO: %s\n" "$*" >&2; }
warn(){ printf "WARN: %s\n" "$*" >&2; }
err(){ printf "ERROR: %s\n" "$*" >&2; }

marker_start="# >>> sourceos workstation-v0 >>>"
marker_end="# <<< sourceos workstation-v0 <<<"

RESULT_ACTIONS=()
RESULT_FILES=()

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
  RESULT_ACTIONS+=("$1")
  RESULT_FILES+=("$2")
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

count_action(){
  local needle=$1
  local count=0
  local i
  for ((i=0;i<${#RESULT_ACTIONS[@]};i++)); do
    if [[ "${RESULT_ACTIONS[$i]}" == "$needle" ]]; then
      count=$((count + 1))
    fi
  done
  printf '%d' "$count"
}

emit_json(){
  local i
  printf '{'
  printf '"kind":"sourceos.fix.shell"'
  printf ',"mode":"%s"' "$(json_escape "$MODE")"
  printf ',"ok":true'
  printf ',"summary":{'
  printf '"patched":%s' "$(count_action patched)"
  printf ',"would_patch":%s' "$(count_action would_patch)"
  printf ',"reverted":%s' "$(count_action reverted)"
  printf ',"already_patched":%s' "$(count_action already_patched)"
  printf ',"no_patch":%s' "$(count_action no_patch)"
  printf ',"missing_file":%s' "$(count_action missing_file)"
  printf '}'
  printf ',"results":['
  for ((i=0;i<${#RESULT_ACTIONS[@]};i++)); do
    [[ $i -gt 0 ]] && printf ','
    printf '{"file":"%s","action":"%s"}' \
      "$(json_escape "${RESULT_FILES[$i]}")" \
      "$(json_escape "${RESULT_ACTIONS[$i]}")"
  done
  printf ']'
  printf '}'
  printf '\n'
}

block() {
  # NOTE: Dollar signs are escaped so we do not bake the *current* PATH into the rc file.
  cat <<EOF
${marker_start}
# Added by SourceOS Workstation v0
export PATH="\$HOME/.local/bin:\$PATH"
spine_path="\${XDG_CONFIG_HOME:-\$HOME/.config}/sourceos/shell/common.sh"
if [ -f "\$spine_path" ]; then
  . "\$spine_path"
fi
${marker_end}
EOF
}

rc_candidates() {
  if [[ -n "${SOURCEOS_RC_FILES:-}" ]]; then
    local IFS=':'
    # shellcheck disable=SC2206
    read -r -a arr <<<"${SOURCEOS_RC_FILES}"
    for f in "${arr[@]}"; do
      [[ -n "$f" ]] && printf '%s\n' "$f"
    done
    return 0
  fi

  printf '%s\n' "$HOME/.bashrc" "$HOME/.zshrc"
}

has_block() {
  local f=$1
  grep -Fqx "$marker_start" "$f" 2>/dev/null
}

apply_to_file() {
  local f=$1

  if [[ ! -e "$f" ]]; then
    warn "rc file not found (skipping): $f"
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

revert_from_file() {
  local f=$1

  if [[ ! -e "$f" ]]; then
    warn "rc file not found (skipping): $f"
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

  while IFS= read -r rc; do
    if [[ "$MODE" == "revert" ]]; then
      revert_from_file "$rc"
    else
      apply_to_file "$rc"
    fi
  done < <(rc_candidates)

  info "done"
  if [[ "$MODE" == "dry-run" ]]; then
    info "re-run with: $0 apply"
  fi

  if [[ "$EMIT_JSON" == "1" ]]; then
    emit_json
  fi
}

main "$@"
