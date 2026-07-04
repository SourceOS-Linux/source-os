#!/usr/bin/env bash
# SourceOS builder-aarch64 health check.
#
# Checks every component in the stack and prints a single summary table.
# Exit 0 = all checks passed. Exit 1 = one or more checks failed.
#
# Usage: bash scripts/doctor.sh [--json]

set -euo pipefail

JSON_MODE=0
[[ "${1:-}" == "--json" ]] && JSON_MODE=1

KATELLO_URL="${SOURCEOS_KATELLO_URL:-https://127.0.0.1:8443}"
STORE_ROOT="${SOURCEOS_STORE_ROOT:-/var/lib/sourceos-syncd}"
SOURCEOS_DIR="${SOURCEOS_DIR:-/etc/sourceos}"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

pass()  { printf "  ${GREEN}✓${NC}  %-36s %s\n" "$1" "$2"; }
fail()  { printf "  ${RED}✗${NC}  %-36s %s\n" "$1" "$2"; }
warn()  { printf "  ${YELLOW}!${NC}  %-36s %s\n" "$1" "$2"; }
note()  { printf "       %-36s %s\n" "" "$1"; }

declare -A CHECK_STATUS  # "pass" | "fail" | "warn"
declare -A CHECK_DETAIL

record() {
    local name="$1" status="$2" detail="${3:-}"
    CHECK_STATUS["$name"]="$status"
    CHECK_DETAIL["$name"]="$detail"
    case "$status" in
        pass) pass "$name" "$detail" ;;
        fail) fail "$name" "$detail" ;;
        warn) warn "$name" "$detail" ;;
    esac
}

check_systemd_unit() {
    local unit="$1" label="$2"
    if ! command -v systemctl &>/dev/null; then
        record "$label" "warn" "not a systemd host"
        return
    fi
    local state
    state=$(systemctl is-active "$unit" 2>/dev/null || echo "inactive")
    if [[ "$state" == "active" ]]; then
        local uptime
        uptime=$(systemctl show -p ActiveEnterTimestamp --value "$unit" 2>/dev/null | \
            awk '{print $1,$2}' || echo "")
        record "$label" "pass" "active since ${uptime:-unknown}"
    else
        record "$label" "fail" "state: ${state}"
    fi
}

check_http() {
    local url="$1" label="$2" extra="${3:-}"
    if curl -fsSk --max-time 5 "$url" &>/dev/null; then
        record "$label" "pass" "$url"
    else
        record "$label" "fail" "unreachable: $url $extra"
    fi
}

fmt_age() {
    local iso="$1"
    local ts now age
    ts=$(date -d "$iso" +%s 2>/dev/null || date -jf "%Y-%m-%dT%H:%M:%S" "${iso%%.*}" +%s 2>/dev/null || echo 0)
    now=$(date +%s)
    age=$(( now - ts ))
    if   [[ $age -lt 120 ]];    then echo "${age}s ago"
    elif [[ $age -lt 7200 ]];   then echo "$(( age / 60 ))m ago"
    elif [[ $age -lt 172800 ]]; then echo "$(( age / 3600 ))h ago"
    else                             echo "$(( age / 86400 ))d ago"
    fi
}

# ── Header ────────────────────────────────────────────────────────────────────

if [[ $JSON_MODE -eq 0 ]]; then
    echo
    printf "${CYAN}${BOLD}SourceOS Builder Health Check${NC}  $(date -u '+%Y-%m-%dT%H:%M:%SZ')\n"
    printf "%s\n" "$(printf '─%.0s' {1..60})"
fi

# ── 1. NixOS + Asahi ──────────────────────────────────────────────────────────

NIXOS_VER=$(nixos-version 2>/dev/null || echo "unknown")
record "NixOS version" "pass" "$NIXOS_VER"

KERNEL=$(uname -r)
if echo "$KERNEL" | grep -qi "asahi\|apple"; then
    record "Asahi kernel" "pass" "$KERNEL"
else
    record "Asahi kernel" "warn" "$KERNEL (not asahi-branded)"
fi

# ── 2. Docker + Foreman+Katello ───────────────────────────────────────────────

if command -v docker &>/dev/null && systemctl is-active docker &>/dev/null 2>&1; then
    CONTAINERS=$(docker ps --filter "name=katello" --format "{{.Names}}" 2>/dev/null | wc -l)
    if [[ "$CONTAINERS" -ge 3 ]]; then
        record "Docker" "pass" "${CONTAINERS} katello containers running"
    else
        record "Docker" "warn" "only ${CONTAINERS}/3 katello containers up"
    fi
else
    record "Docker" "fail" "not running"
fi

check_http "${KATELLO_URL}/api/v2/status" "Foreman+Katello API" "(check: docker ps)"

# ── 3. Nix binary cache ───────────────────────────────────────────────────────

check_systemd_unit "harmonia" "harmonia (Nix cache)"
check_systemd_unit "nginx" "nginx (cache proxy)"
check_http "http://127.0.0.1:8101/nix-cache-info" "Nix cache :8101"

if curl -fsSk --max-time 5 "http://127.0.0.1:8101/nix-cache-info.minisig" &>/dev/null; then
    # Verify the signature is valid
    if [[ -f "${SOURCEOS_DIR}/nix-cache.pub" ]]; then
        TMP=$(mktemp /tmp/nix-cache-info-XXXXX)
        curl -fsSk http://127.0.0.1:8101/nix-cache-info > "$TMP" 2>/dev/null
        TMPSIG=$(mktemp /tmp/nix-cache-info-XXXXX.minisig)
        curl -fsSk http://127.0.0.1:8101/nix-cache-info.minisig > "$TMPSIG" 2>/dev/null
        if minisign -V -p "${SOURCEOS_DIR}/nix-cache.pub" -m "$TMP" -x "$TMPSIG" &>/dev/null; then
            record "nix-cache-info minisig" "pass" "signature valid"
        else
            record "nix-cache-info minisig" "fail" "signature invalid — re-sign: step 8 of enroll.sh"
        fi
        rm -f "$TMP" "$TMPSIG"
    else
        record "nix-cache-info minisig" "warn" "endpoint serves file but no public key at ${SOURCEOS_DIR}/nix-cache.pub"
    fi
else
    record "nix-cache-info minisig" "fail" "not served at /nix-cache-info.minisig"
fi

# ── 4. SOPS + secrets ─────────────────────────────────────────────────────────

if [[ -f "${SOURCEOS_DIR}/age.key" ]]; then
    record "Age key" "pass" "${SOURCEOS_DIR}/age.key"
else
    record "Age key" "fail" "missing — run enroll.sh step 3"
fi

if [[ -f "${SOURCEOS_DIR}/secrets.yaml" ]]; then
    if python3 -c "
import sys
d = open('${SOURCEOS_DIR}/secrets.yaml').read()
sys.exit(0 if 'sops' in d else 1)
" 2>/dev/null; then
        record "SOPS secrets" "pass" "${SOURCEOS_DIR}/secrets.yaml (encrypted)"
    else
        record "SOPS secrets" "fail" "file exists but not SOPS-encrypted"
    fi
else
    record "SOPS secrets" "fail" "missing — run enroll.sh step 6"
fi

# ── 5. sourceos-syncd daemon ──────────────────────────────────────────────────

check_systemd_unit "sourceos-syncd" "sourceos-syncd daemon"

# Last receipt
LAST_RECEIPT=""
if command -v sourceos-syncd &>/dev/null; then
    LAST_RECEIPT=$(sourceos-syncd receipts last --store-root "${STORE_ROOT}" 2>/dev/null || echo "")
fi

if [[ -n "${LAST_RECEIPT}" ]]; then
    OUTCOME=$(echo "${LAST_RECEIPT}" | python3 -c "import json,sys; print(json.load(sys.stdin).get('outcome','?'))" 2>/dev/null || echo "?")
    ISSUED=$(echo "${LAST_RECEIPT}" | python3 -c "import json,sys; print(json.load(sys.stdin).get('issuedAt','?'))" 2>/dev/null || echo "?")
    AGE=$(fmt_age "$ISSUED")
    RECEIPT_COUNT=$(ls "${STORE_ROOT}/receipts/"*.json 2>/dev/null | wc -l || echo 0)
    if [[ "$OUTCOME" == "applied" || "$OUTCOME" == "no_change" || "$OUTCOME" == "dry_run" ]]; then
        record "Last sync receipt" "pass" "outcome=${OUTCOME}  ${AGE}  (${RECEIPT_COUNT} total)"
    else
        record "Last sync receipt" "warn" "outcome=${OUTCOME}  ${AGE}"
    fi
    CURRENT_VERSION=$(cat "${STORE_ROOT}/current-version" 2>/dev/null || echo "none")
    record "Current tracked version" "pass" "${CURRENT_VERSION}"
else
    record "Last sync receipt" "warn" "no receipts yet — daemon may be starting"
fi

# ── 6. sourceos-boot + health-check timer ────────────────────────────────────

check_systemd_unit "sourceos-health-check.timer" "health-check timer"

if command -v sourceos-boot &>/dev/null; then
    record "sourceos-boot CLI" "pass" "$(sourceos-boot --version 2>/dev/null || echo 'present')"
else
    record "sourceos-boot CLI" "fail" "not in PATH"
fi

# ── 7. enroll.nix ─────────────────────────────────────────────────────────────

REPO_ROOT="${SOURCEOS_REPO_ROOT:-/opt/sourceos/source-os}"
ENROLL_NIX="${REPO_ROOT}/hosts/builder-aarch64/enroll.nix"
if [[ -f "${ENROLL_NIX}" ]]; then
    record "enroll.nix" "pass" "${ENROLL_NIX}"
else
    record "enroll.nix" "warn" "missing — run enroll.sh to generate device settings"
fi

# ── Summary ───────────────────────────────────────────────────────────────────

FAILED=0
WARNED=0
for k in "${!CHECK_STATUS[@]}"; do
    [[ "${CHECK_STATUS[$k]}" == "fail" ]] && FAILED=$((FAILED + 1))
    [[ "${CHECK_STATUS[$k]}" == "warn" ]] && WARNED=$((WARNED + 1))
done

echo
printf "%s\n" "$(printf '─%.0s' {1..60})"

if [[ $JSON_MODE -eq 1 ]]; then
    python3 - <<PYEOF
import json
checks = {}
$(for k in "${!CHECK_STATUS[@]}"; do
    echo "checks[$(printf '%q' "$k")] = {\"status\": $(printf '%q' "${CHECK_STATUS[$k]}"), \"detail\": $(printf '%q' "${CHECK_DETAIL[$k]:-}")};"
done)
print(json.dumps({"healthy": ${FAILED} == 0, "failed": ${FAILED}, "warned": ${WARNED}, "checks": checks}, indent=2))
PYEOF
elif [[ $FAILED -eq 0 ]]; then
    printf "${GREEN}${BOLD}  All checks passed${NC}"
    [[ $WARNED -gt 0 ]] && printf "  (${WARNED} warning(s))"
    echo
else
    printf "${RED}${BOLD}  ${FAILED} check(s) FAILED${NC}"
    [[ $WARNED -gt 0 ]] && printf "  (${WARNED} warning(s))"
    echo
    echo
    echo "  To re-run enrollment: sudo bash scripts/enroll.sh"
fi
echo

exit $FAILED
