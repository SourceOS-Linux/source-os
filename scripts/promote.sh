#!/usr/bin/env bash
# Promote the latest (or a specific) sourceos-builder-aarch64 content view
# version through dev → candidate → stable in the local Katello instance.
#
# Usage:
#   bash scripts/promote.sh                         # promote latest
#   bash scripts/promote.sh --version 1.3           # promote specific version
#   bash scripts/promote.sh --to stable             # promote only to stable
#   bash scripts/promote.sh --dry-run               # print plan, do nothing
#
# After promotion, sourceos-syncd will detect the new stable version
# within SOURCEOS_POLL_INTERVAL seconds (default 300) and apply the update.

set -euo pipefail

KATELLO_URL="${FOREMAN_URL:-https://127.0.0.1:8443}"
KATELLO_USER="${FOREMAN_USER:-admin}"
ORG="${SOURCEOS_ORG:-SocioProphet}"
CV_NAME="${SOURCEOS_CV:-sourceos-builder-aarch64}"
TARGET_ENVS=("dev" "candidate" "stable")
CV_VERSION=""
DRY_RUN=0
KATELLO_PW_FILE="${SOURCEOS_DIR:-/etc/sourceos}/katello-admin-password"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'

ok()   { printf "  ${GREEN}✓${NC}  %s\n" "$*"; }
info() { printf "  ${CYAN}·${NC}  %s\n" "$*"; }
warn() { printf "  ${YELLOW}!${NC}  %s\n" "$*"; }
die()  { printf "  ${RED}✗  ERROR:${NC} %s\n" "$*" >&2; exit 1; }

usage() {
    sed -n 's/^# //p' "$0" | head -12
    exit 0
}

# ── Args ──────────────────────────────────────────────────────────────────────

while [[ $# -gt 0 ]]; do
    case "$1" in
        --version)   CV_VERSION="$2"; shift 2 ;;
        --to)        TARGET_ENVS=("$2"); shift 2 ;;
        --dry-run)   DRY_RUN=1; shift ;;
        --katello-url) KATELLO_URL="$2"; shift 2 ;;
        --org)       ORG="$2"; shift 2 ;;
        --help|-h)   usage ;;
        *)           die "Unknown argument: $1" ;;
    esac
done

# ── Credentials ───────────────────────────────────────────────────────────────

if [[ -n "${FOREMAN_PASSWORD:-}" ]]; then
    KATELLO_PASSWORD="${FOREMAN_PASSWORD}"
elif [[ -f "${KATELLO_PW_FILE}" ]]; then
    KATELLO_PASSWORD=$(cat "${KATELLO_PW_FILE}")
else
    die "Katello password not found. Set FOREMAN_PASSWORD or ensure ${KATELLO_PW_FILE} exists."
fi

# ── Hammer wrapper ────────────────────────────────────────────────────────────

hammer() {
    docker exec katello-foreman hammer \
        --server "${KATELLO_URL}" \
        --username "${KATELLO_USER}" \
        --password "${KATELLO_PASSWORD}" \
        "$@"
}

# ── Discover version ──────────────────────────────────────────────────────────

if [[ -z "${CV_VERSION}" ]]; then
    info "Querying latest content view version..."
    CV_VERSION=$(hammer --output json content-view version list \
        --organization "${ORG}" \
        --content-view "${CV_NAME}" 2>/dev/null | \
        python3 -c "
import json, sys
vs = json.load(sys.stdin)
if not vs: sys.exit(1)
print(sorted(vs, key=lambda v: v['ID'])[-1]['Version'])
") || die "Could not determine latest CV version — is Katello running? (docker ps)"
fi

info "Content view: ${CV_NAME}"
info "Version:      ${CV_VERSION}"
info "Org:          ${ORG}"
info "Promoting to: ${TARGET_ENVS[*]}"
[[ $DRY_RUN -eq 1 ]] && warn "DRY RUN — no changes will be made"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# ── Promote ───────────────────────────────────────────────────────────────────

echo

for env in "${TARGET_ENVS[@]}"; do
    if [[ $DRY_RUN -eq 1 ]]; then
        info "[dry-run] would promote v${CV_VERSION} → ${env}"
        continue
    fi

    info "Promoting v${CV_VERSION} → ${env}..."
    if hammer content-view version promote \
        --organization "${ORG}" \
        --content-view "${CV_NAME}" \
        --version "${CV_VERSION}" \
        --to-lifecycle-environment "${env}" 2>/dev/null; then
        ok "v${CV_VERSION} → ${env}"
    else
        warn "Promotion to ${env} skipped (already at this version or previous env not promoted)"
    fi

    CHANNEL_FILE="${REPO_ROOT}/channels/${env}.json"
    if [[ -f "${CHANNEL_FILE}" ]]; then
        PROMOTED_AT=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
        python3 - <<PYEOF
import json

path = '${CHANNEL_FILE}'
with open(path) as f:
    d = json.load(f)

d['artifact_set'] = 'urn:srcos:cv:${CV_NAME}:${CV_VERSION}'
d['promoted_at']  = '${PROMOTED_AT}'
approved = d.get('approved_by', [])
if 'promote.sh' not in approved:
    approved.append('promote.sh')
d['approved_by'] = approved

with open(path, 'w') as f:
    json.dump(d, f, indent=2)
    f.write('\n')
PYEOF
        ok "Updated channels/${env}.json"
    fi
done

echo

if [[ $DRY_RUN -eq 0 ]]; then
    POLL_INTERVAL="${SOURCEOS_POLL_INTERVAL:-300}"
    ok "Done. sourceos-syncd will detect v${CV_VERSION} in stable within ${POLL_INTERVAL}s."
    info "Force immediate check: systemctl restart sourceos-syncd"
    info "Watch: journalctl -u sourceos-syncd -f"
    info "Verify: sourceos-syncd sync status"
fi
