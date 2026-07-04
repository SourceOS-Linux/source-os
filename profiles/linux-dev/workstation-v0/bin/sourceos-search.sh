#!/usr/bin/env bash
set -euo pipefail

err(){ printf "ERROR: %s\n" "$*" >&2; }
info(){ printf "INFO: %s\n" "$*" >&2; }
warn(){ printf "WARN: %s\n" "$*" >&2; }

have(){ command -v "$1" >/dev/null 2>&1; }

cache_dir(){ echo "${XDG_CACHE_HOME:-$HOME/.cache}/sourceos"; }
service_name(){ echo "sourceos-lampstand.service"; }

open_file(){
  local p=$1
  if have xdg-open; then xdg-open "$p" >/dev/null 2>&1 || true
  elif have open; then open "$p" >/dev/null 2>&1 || true
  else warn "no opener found; wrote: $p"
  fi
}

run_lampstand(){
  if have lampstand; then lampstand "$@"; return; fi
  if have python3 && python3 -c 'import lampstand.cli' >/dev/null 2>&1; then
    python3 -m lampstand.cli "$@"; return
  fi
  err "Lampstand is not available on PATH and the Python module is not importable."
  return 127
}

run_user_service(){
  local action=$1
  local svc
  svc="$(service_name)"

  case "$action" in
    status)
      systemctl --user status "$svc" --no-pager
      ;;
    start|stop|restart)
      systemctl --user "$action" "$svc"
      ;;
    enable)
      systemctl --user enable "$svc"
      ;;
    logs)
      journalctl --user -u "$svc" --no-pager -n 200
      ;;
    *)
      err "unknown service action: $action (use status|start|stop|restart|enable|logs)"
      return 2
      ;;
  esac
}

usage(){
  cat <<'EOF'
Usage:
  sourceos-search.sh [--limit N] [--snippet] [--prompt] [--open|--write <path>] [query...]
  sourceos-search.sh health [--open|--write <path>]
  sourceos-search.sh stats [--open|--write <path>]
  sourceos-search.sh index [--root <path>]...
  sourceos-search.sh service status|start|stop|restart|enable|logs [--open|--write <path>]
EOF
}

write_or_print(){
  local out=$1
  local default_name=$2
  if [[ "$SEARCH_OPEN" == "1" || -n "$SEARCH_WRITE_PATH" ]]; then
    local path="$SEARCH_WRITE_PATH"
    if [[ -z "$path" ]]; then mkdir -p "$(cache_dir)"; path="$(cache_dir)/$default_name"; fi
    mkdir -p "$(dirname "$path")"
    printf '%s\n' "$out" > "$path"
    info "wrote: $path"
    [[ "$SEARCH_OPEN" == "1" ]] && open_file "$path"
    return 0
  fi
  printf '%s\n' "$out"
}

SEARCH_LIMIT=20
SEARCH_SNIPPET=0
SEARCH_PROMPT=0
SEARCH_OPEN=0
SEARCH_WRITE_PATH=""
QUERY_PARTS=()
LAMPSTAND_ROOTS=()
MODE="query"
SERVICE_ACTION=""

case "${1:-}" in
  health|stats|index)
    MODE="$1"
    shift
    ;;
  service)
    MODE="service"
    shift
    SERVICE_ACTION="${1:-}"
    [[ -n "$SERVICE_ACTION" ]] || { err "service requires an action"; usage; exit 2; }
    shift || true
    ;;
esac

while [[ $# -gt 0 ]]; do
  case "$1" in
    --limit) shift; [[ $# -gt 0 ]] || { err "--limit requires a value"; exit 2; }; SEARCH_LIMIT="$1"; shift ;;
    --snippet) SEARCH_SNIPPET=1; shift ;;
    --prompt) SEARCH_PROMPT=1; shift ;;
    --open) SEARCH_OPEN=1; shift ;;
    --write) shift; [[ $# -gt 0 ]] || { err "--write requires a path"; exit 2; }; SEARCH_WRITE_PATH="$1"; shift ;;
    --root) shift; [[ $# -gt 0 ]] || { err "--root requires a path"; exit 2; }; LAMPSTAND_ROOTS+=("$1"); shift ;;
    -h|--help) usage; exit 0 ;;
    *) QUERY_PARTS+=("$1"); shift ;;
  esac
done

case "$MODE" in
  health)
    set +e
    out="$(run_lampstand health 2>&1)"
    rc=$?
    set -e
    write_or_print "$out" lampstand-health.json
    exit "$rc"
    ;;
  stats)
    out="$(run_lampstand stats)"
    write_or_print "$out" lampstand-stats.json
    exit 0
    ;;
  index)
    args=(index)
    for root in "${LAMPSTAND_ROOTS[@]}"; do args+=(--root "$root"); done
    run_lampstand "${args[@]}"
    exit $?
    ;;
  service)
    set +e
    out="$(run_user_service "$SERVICE_ACTION" 2>&1)"
    rc=$?
    set -e
    write_or_print "$out" "lampstand-service-$SERVICE_ACTION.txt"
    exit "$rc"
    ;;
esac

if [[ ${#QUERY_PARTS[@]} -eq 0 && "$SEARCH_PROMPT" == "1" ]]; then
  if have fuzzel; then q="$(printf '\n' | fuzzel --dmenu --prompt 'search> ' || true)"
  elif have wofi; then q="$(printf '\n' | wofi --dmenu --prompt 'search> ' || true)"
  elif have rofi; then q="$(printf '\n' | rofi -dmenu -p 'search> ' || true)"
  elif have fzf; then q="$(printf '\n' | fzf --print-query --prompt='search> ' | head -n1 || true)"
  else err "no prompt-capable launcher found"; exit 2
  fi
  [[ -n "$q" ]] && QUERY_PARTS+=("$q")
fi

query="${QUERY_PARTS[*]:-}"
[[ -n "$query" ]] || { err "search requires a query or --prompt"; exit 2; }

args=(query "$query" --limit "$SEARCH_LIMIT")
[[ "$SEARCH_SNIPPET" == "1" ]] && args+=(--snippet)

if [[ "$SEARCH_OPEN" == "1" || -n "$SEARCH_WRITE_PATH" ]]; then
  out="$(run_lampstand "${args[@]}")"
  write_or_print "$out" search.txt
  exit 0
fi

run_lampstand "${args[@]}"
