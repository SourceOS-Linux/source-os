#!/usr/bin/env bash
# Build a SourceOS NixOS configuration, populate the local Nix binary cache,
# publish a new Katello content view version, and update the channel file.
#
# Usage:
#   bash scripts/build-and-push.sh                           # builder-aarch64, write dev channel
#   bash scripts/build-and-push.sh --host canary-x86_64     # different target
#   bash scripts/build-and-push.sh --promote candidate       # build + promote through candidate
#   bash scripts/build-and-push.sh --promote stable          # build + promote all the way to stable
#   bash scripts/build-and-push.sh --dry-run                 # print plan, no changes
#
# Environment:
#   FOREMAN_URL       Katello base URL  (default: https://127.0.0.1:8443)
#   FOREMAN_PASSWORD  Katello admin password
#   SOURCEOS_ORG      Katello org name  (default: SocioProphet)
#   SOURCEOS_HOST     host target       (default: builder-aarch64)

set -euo pipefail

HOST="${SOURCEOS_HOST:-builder-aarch64}"
ORG="${SOURCEOS_ORG:-SocioProphet}"
KATELLO_URL="${FOREMAN_URL:-https://127.0.0.1:8443}"
KATELLO_USER="${FOREMAN_USER:-admin}"
KATELLO_PW_FILE="${SOURCEOS_DIR:-/etc/sourceos}/katello-admin-password"
PROMOTE_TO=""
DRY_RUN=0
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'

ok()   { printf "  ${GREEN}✓${NC}  %s\n" "$*"; }
info() { printf "  ${CYAN}·${NC}  %s\n" "$*"; }
warn() { printf "  ${YELLOW}!${NC}  %s\n" "$*"; }
die()  { printf "  ${RED}✗  ERROR:${NC} %s\n" "$*" >&2; exit 1; }

usage() { sed -n 's/^# //p' "$0" | head -15; exit 0; }

# ── Args ──────────────────────────────────────────────────────────────────────

while [[ $# -gt 0 ]]; do
    case "$1" in
        --host)      HOST="$2"; shift 2 ;;
        --promote)   PROMOTE_TO="$2"; shift 2 ;;
        --dry-run)   DRY_RUN=1; shift ;;
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

# ── Resolve content view from builder manifest ────────────────────────────────

BUILDERS_JSON="${REPO_ROOT}/builders/${HOST}.json"
[[ -f "${BUILDERS_JSON}" ]] || die "No builder manifest at ${BUILDERS_JSON}"

CV_NAME=$(python3 -c "
import json, sys
d = json.load(open('${BUILDERS_JSON}'))
cv = d.get('content_view')
if not cv:
    sys.exit(1)
print(cv)
" 2>/dev/null) || die "builders/${HOST}.json is missing 'content_view' field. Add it and retry."

CHANNEL=$(python3 -c "
import json
print(json.load(open('${BUILDERS_JSON}')).get('channel', 'dev'))
" 2>/dev/null || echo "dev")

# aarch64 configs have gitignored hardware-configuration.nix → need --impure.
NIX_FLAGS=""
[[ "${HOST}" == *"aarch64"* ]] && NIX_FLAGS="--impure"

NIX_TARGET=".#nixosConfigurations.${HOST}.config.system.build.toplevel"

# ── Hammer wrapper ────────────────────────────────────────────────────────────

hammer() {
    docker exec katello-foreman hammer \
        --server "${KATELLO_URL}" \
        --username "${KATELLO_USER}" \
        --password "${KATELLO_PASSWORD}" \
        "$@"
}

# ── Promote-env ladder ────────────────────────────────────────────────────────
# Katello lifecycle requires sequential promotion: Library→dev→candidate→stable.
# Map --promote target to the full ordered set of envs to advance through.

declare -a PROMOTE_ENVS=()
case "${PROMOTE_TO}" in
    "")          ;;
    dev)         PROMOTE_ENVS=("dev") ;;
    candidate)   PROMOTE_ENVS=("dev" "candidate") ;;
    stable)      PROMOTE_ENVS=("dev" "candidate" "stable") ;;
    *)           die "--promote must be dev, candidate, or stable" ;;
esac

# ── Preflight ─────────────────────────────────────────────────────────────────

echo
printf "${BOLD}SourceOS build-and-push${NC}  host=${HOST}  cv=${CV_NAME}  org=${ORG}\n"
printf "%s\n" "$(printf '─%.0s' {1..65})"
[[ $DRY_RUN -eq 1 ]] && warn "DRY RUN — no changes will be made"
echo

info "Checking Katello container..."
if [[ $DRY_RUN -eq 0 ]] && ! docker inspect katello-foreman &>/dev/null; then
    die "katello-foreman container is not running.
       Start it: docker compose -f <prophet-platform>/infra/local/docker-compose.foreman-katello.yml up -d"
fi
ok "Katello container up"

# ── Step 1: nix build ─────────────────────────────────────────────────────────

info "Building ${NIX_TARGET} ${NIX_FLAGS}..."
if [[ $DRY_RUN -eq 1 ]]; then
    info "[dry-run] nix build ${NIX_TARGET} ${NIX_FLAGS}"
else
    cd "${REPO_ROOT}"
    nix build ${NIX_TARGET} ${NIX_FLAGS} || die "nix build failed"
    STORE_PATH="$(readlink -f result)"
    ok "Build complete: ${STORE_PATH}"
fi

GIT_COMMIT=$(git -C "${REPO_ROOT}" rev-parse HEAD)
GIT_SHORT=$(git  -C "${REPO_ROOT}" rev-parse --short HEAD)
BUILT_AT=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

FLAKE_LOCK_REV=$(python3 -c "
import json
lock = json.load(open('${REPO_ROOT}/flake.lock'))
print(lock['nodes']['nixpkgs']['locked'].get('rev', 'unknown'))
" 2>/dev/null || echo "unknown")

# ── Step 2: Publish new content view version ──────────────────────────────────

info "Publishing new content view version for ${CV_NAME}..."
if [[ $DRY_RUN -eq 1 ]]; then
    info "[dry-run] hammer content-view publish --name ${CV_NAME}"
    CV_VERSION="<dry-run>"
else
    hammer content-view publish \
        --organization "${ORG}" \
        --name "${CV_NAME}" \
        --description "Built from ${GIT_SHORT} at ${BUILT_AT}" \
        || die "hammer content-view publish failed. Is the CV set up? Run: bash scripts/katello-sourceos-setup.sh"

    CV_VERSION=$(hammer --output json content-view version list \
        --organization "${ORG}" \
        --content-view "${CV_NAME}" 2>/dev/null | \
        python3 -c "
import json, sys
vs = json.load(sys.stdin)
if not vs:
    sys.exit(1)
print(sorted(vs, key=lambda v: v['ID'])[-1]['Version'])
") || die "Could not read back CV version after publish"
    ok "Published content view version ${CV_VERSION}"
fi

# ── Step 3: Update channels/dev.json (or the host's base channel) ─────────────

CHANNEL_FILE="${REPO_ROOT}/channels/${CHANNEL}.json"
info "Updating ${CHANNEL_FILE}..."
if [[ $DRY_RUN -eq 1 ]]; then
    info "[dry-run] would write cv=${CV_VERSION} commit=${GIT_SHORT} to channels/${CHANNEL}.json"
else
    python3 - <<PYEOF
import json, sys

path = '${CHANNEL_FILE}'
with open(path) as f:
    d = json.load(f)

d['artifact_set'] = 'urn:srcos:cv:${CV_NAME}:${CV_VERSION}'
d['source_rev']   = 'git:${GIT_COMMIT}'
d['flake_lock']   = '${FLAKE_LOCK_REV}'
d['eval_bundle']  = '${HOST}:${CV_VERSION}'
d['promoted_at']  = '${BUILT_AT}'
d['approved_by']  = ['build-and-push']

with open(path, 'w') as f:
    json.dump(d, f, indent=2)
    f.write('\n')
PYEOF
    ok "Updated channels/${CHANNEL}.json (cv=${CV_VERSION} commit=${GIT_SHORT})"
fi

# ── Step 4: Promote through lifecycle envs (optional) ─────────────────────────

if [[ ${#PROMOTE_ENVS[@]} -gt 0 ]]; then
    echo
    info "Promoting v${CV_VERSION} through: ${PROMOTE_ENVS[*]}"
    for env in "${PROMOTE_ENVS[@]}"; do
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
            warn "Promotion to ${env} already at this version — skipping"
        fi

        # Update the corresponding channel file after each promotion
        ENV_CHANNEL_FILE="${REPO_ROOT}/channels/${env}.json"
        if [[ -f "${ENV_CHANNEL_FILE}" ]]; then
            python3 - <<PYEOF
import json

path = '${ENV_CHANNEL_FILE}'
with open(path) as f:
    d = json.load(f)

d['artifact_set'] = 'urn:srcos:cv:${CV_NAME}:${CV_VERSION}'
d['source_rev']   = 'git:${GIT_COMMIT}'
d['flake_lock']   = '${FLAKE_LOCK_REV}'
d['eval_bundle']  = '${HOST}:${CV_VERSION}'
d['promoted_at']  = '${BUILT_AT}'
d['approved_by']  = ['build-and-push']

with open(path, 'w') as f:
    json.dump(d, f, indent=2)
    f.write('\n')
PYEOF
            ok "Updated channels/${env}.json"
        fi
    done
fi

# ── Done ──────────────────────────────────────────────────────────────────────

echo
ok "Done. ${CV_NAME} v${CV_VERSION} built from ${GIT_SHORT}."
if [[ ${#PROMOTE_ENVS[@]} -eq 0 ]]; then
    POLL="${SOURCEOS_POLL_INTERVAL:-300}"
    info "Channel ${CHANNEL} is at v${CV_VERSION}."
    info "Promote to stable: bash scripts/build-and-push.sh --host ${HOST} --promote stable"
    info "  or step by step: bash scripts/promote.sh --version ${CV_VERSION} --to candidate"
    info "                   bash scripts/promote.sh --version ${CV_VERSION} --to stable"
elif [[ " ${PROMOTE_ENVS[*]} " == *" stable "* ]]; then
    POLL="${SOURCEOS_POLL_INTERVAL:-300}"
    ok "sourceos-syncd will detect v${CV_VERSION} in stable within ${POLL}s."
    info "Force immediate check: systemctl restart sourceos-syncd"
    info "Watch:                 journalctl -u sourceos-syncd -f"
fi
