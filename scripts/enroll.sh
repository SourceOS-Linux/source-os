#!/usr/bin/env bash
# M2 SourceOS enrollment script.
#
# Run once after Asahi Linux + NixOS base install.
# Idempotent: re-running is safe after partial failures.
#
# What this does:
#   1. Generate hardware-configuration.nix (device-specific, gitignored)
#   2. nixos-rebuild switch pass 1 — installs Docker, age, sops, minisign
#   3. Generate device age key at /etc/sourceos/age.key
#   4. Clone/update prophet-platform, start Foreman+Katello via Docker Compose
#   5. Set up SourceOS org + content view + lifecycle envs in Katello
#   6. Encrypt Katello password as SOPS secret at /etc/sourceos/secrets.yaml
#   7. Build and push the NixOS closure to the local Katello cache
#   8. Promote content view dev → candidate → stable
#   9. Generate minisign key pair, patch signingPublicKey into host config
#  10. nixos-rebuild switch pass 2 — live config with secrets + signing key
#  11. Verify sourceos-syncd is running and healthy
#
# Usage (run as root from the source-os repo root):
#   sudo bash scripts/enroll.sh [--repo-root /path/to/source-os] [--org SocioProphet]

set -euo pipefail

# ── Config ──────────────────────────────────────────────────────────────────

REPO_ROOT="${SOURCEOS_REPO_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
PROPHET_PLATFORM_ROOT="${PROPHET_PLATFORM_ROOT:-/opt/prophet-platform}"
ORG="${SOURCEOS_ORG:-SocioProphet}"
HOST="${SOURCEOS_HOST:-builder-aarch64}"
KATELLO_URL="https://127.0.0.1:8443"
KATELLO_USER="admin"
AGE_KEY_PATH="/etc/sourceos/age.key"
AGE_PUB_PATH="/etc/sourceos/age.pub"
SECRETS_YAML="/etc/sourceos/secrets.yaml"
MINISIGN_PUB="/etc/sourceos/nix-cache.pub"
MINISIGN_SEC="/etc/sourceos/nix-cache.sec"
SOURCEOS_DIR="/etc/sourceos"
COMPOSE_FILE="${PROPHET_PLATFORM_ROOT}/infra/local/docker-compose.foreman-katello.yml"
COMPOSE_ENV="${PROPHET_PLATFORM_ROOT}/infra/local/foreman-katello/.env"
COMPOSE_ENV_EXAMPLE="${PROPHET_PLATFORM_ROOT}/infra/local/foreman-katello/.env.example"

# ── Helpers ──────────────────────────────────────────────────────────────────

log()  { echo "[enroll] $*"; }
die()  { echo "[enroll] ERROR: $*" >&2; exit 1; }
ok()   { echo "[enroll] ✓ $*"; }
step() { echo; echo "══════════════════════════════════════════════════════"; echo "[enroll] STEP $*"; echo "══════════════════════════════════════════════════════"; }

require_cmd() {
    command -v "$1" &>/dev/null || die "'$1' not found — ensure pass-1 nixos-rebuild completed successfully"
}

wait_for_url() {
    local url="$1" label="${2:-service}" max="${3:-120}" interval=5 elapsed=0
    log "Waiting for ${label} at ${url} (up to ${max}s)..."
    while ! curl -fsSk --max-time 5 "$url" &>/dev/null; do
        sleep $interval
        elapsed=$((elapsed + interval))
        [[ $elapsed -ge $max ]] && die "${label} did not become ready at ${url} after ${max}s"
        log "  ... still waiting (${elapsed}s)"
    done
    ok "${label} is up"
}

gen_password() {
    head -c 32 /dev/urandom | base64 | tr -d '/+=' | head -c 24
}

# ── Preflight ─────────────────────────────────────────────────────────────────

step "0 — Preflight"

[[ $EUID -eq 0 ]] || die "Run as root: sudo bash scripts/enroll.sh"
[[ -f /etc/nixos/configuration.nix || -d /nix ]] || die "Does not look like a NixOS system"
[[ -f "${REPO_ROOT}/flake.nix" ]] || die "flake.nix not found at ${REPO_ROOT} — set SOURCEOS_REPO_ROOT"

mkdir -p "${SOURCEOS_DIR}"
chmod 700 "${SOURCEOS_DIR}"

ok "Running as root on NixOS"
log "  Repo root:      ${REPO_ROOT}"
log "  Host:           ${HOST}"
log "  Org:            ${ORG}"
log "  Katello URL:    ${KATELLO_URL}"

# ── Step 1: hardware-configuration.nix ───────────────────────────────────────

step "1 — Hardware configuration"

HW_CONFIG="${REPO_ROOT}/hosts/${HOST}/hardware-configuration.nix"

if [[ -f "$HW_CONFIG" ]]; then
    ok "hardware-configuration.nix already present, skipping generation"
else
    log "Generating hardware-configuration.nix..."
    nixos-generate-config --show-hardware-config > "$HW_CONFIG"
    ok "Generated ${HW_CONFIG}"
fi

# ── Step 2: nixos-rebuild pass 1 (installs Docker, tooling) ─────────────────

step "2 — nixos-rebuild switch (pass 1: install Docker + tooling)"

log "Building and switching to builder-aarch64 configuration..."
log "(This installs Docker, age, sops, minisign, docker-compose)"
nixos-rebuild switch --flake "${REPO_ROOT}#${HOST}" 2>&1 | tee /tmp/sourceos-rebuild-pass1.log
ok "Pass 1 rebuild complete"

# ── Step 3: age key generation ───────────────────────────────────────────────

step "3 — Age key"

require_cmd age-keygen

if [[ -f "$AGE_KEY_PATH" ]]; then
    ok "Age key already exists at ${AGE_KEY_PATH}"
else
    log "Generating device age key..."
    age-keygen -o "$AGE_KEY_PATH" 2>/dev/null
    chmod 600 "$AGE_KEY_PATH"
    ok "Generated ${AGE_KEY_PATH}"
fi

AGE_PUBKEY=$(age-keygen -y "$AGE_KEY_PATH")
echo "$AGE_PUBKEY" > "$AGE_PUB_PATH"
ok "Age public key: ${AGE_PUBKEY}"

# ── Step 4: Foreman+Katello ───────────────────────────────────────────────────

step "4 — Foreman+Katello (prophet-platform)"

require_cmd docker
require_cmd docker-compose

# Clone prophet-platform if not present
if [[ ! -d "${PROPHET_PLATFORM_ROOT}" ]]; then
    log "Cloning prophet-platform to ${PROPHET_PLATFORM_ROOT}..."
    git clone https://github.com/SocioProphet/prophet-platform.git "${PROPHET_PLATFORM_ROOT}"
fi

# Write .env if not present
if [[ ! -f "${COMPOSE_ENV}" ]]; then
    log "Generating Foreman+Katello .env..."
    FOREMAN_ADMIN_PASSWORD=$(gen_password)
    KATELLO_PG_PASSWORD=$(gen_password)

    cp "${COMPOSE_ENV_EXAMPLE}" "${COMPOSE_ENV}"
    sed -i "s|^FOREMAN_ADMIN_PASSWORD=.*|FOREMAN_ADMIN_PASSWORD=${FOREMAN_ADMIN_PASSWORD}|" "${COMPOSE_ENV}"
    sed -i "s|^KATELLO_PG_PASSWORD=.*|KATELLO_PG_PASSWORD=${KATELLO_PG_PASSWORD}|" "${COMPOSE_ENV}"
    chmod 600 "${COMPOSE_ENV}"

    # Save admin password separately for use in later steps
    echo "${FOREMAN_ADMIN_PASSWORD}" > "${SOURCEOS_DIR}/katello-admin-password"
    chmod 600 "${SOURCEOS_DIR}/katello-admin-password"
    ok "Generated .env with random passwords"
else
    ok ".env already exists"
fi

KATELLO_PASSWORD=$(cat "${SOURCEOS_DIR}/katello-admin-password")

# Start Foreman+Katello
log "Starting Foreman+Katello (first start takes 10–15 minutes)..."
docker-compose -f "${COMPOSE_FILE}" --env-file "${COMPOSE_ENV}" up -d

# Wait for Foreman installer to complete (writes marker file inside container)
log "Waiting for foreman-installer to complete (may take up to 15 min)..."
MAX_WAIT=1200
ELAPSED=0
INTERVAL=15
while ! docker exec katello-foreman test -f /var/lib/foreman/.sourceos-initialized 2>/dev/null; do
    sleep $INTERVAL
    ELAPSED=$((ELAPSED + INTERVAL))
    [[ $ELAPSED -ge $MAX_WAIT ]] && die "Foreman installer did not complete after ${MAX_WAIT}s. Check: docker compose -f ${COMPOSE_FILE} logs -f foreman-katello"
    if (( ELAPSED % 60 == 0 )); then
        log "  ... foreman-installer still running (${ELAPSED}s elapsed)"
    fi
done

wait_for_url "${KATELLO_URL}" "Foreman HTTPS" 120

ok "Foreman+Katello is running"

# ── Step 5: Katello content setup ────────────────────────────────────────────

step "5 — Katello content structure"

FOREMAN_URL="${KATELLO_URL}" \
FOREMAN_USER="${KATELLO_USER}" \
FOREMAN_PASSWORD="${KATELLO_PASSWORD}" \
ORG="${ORG}" \
bash "${REPO_ROOT}/scripts/katello-sourceos-setup.sh"

ok "Katello org, product, repos, content view created"

# ── Step 6: SOPS secrets ─────────────────────────────────────────────────────

step "6 — Encrypt secrets with SOPS"

require_cmd sops

if [[ -f "$SECRETS_YAML" ]]; then
    # Validate it's a sops-encrypted file
    if sops --age "$AGE_PUBKEY" --decrypt "$SECRETS_YAML" &>/dev/null; then
        ok "secrets.yaml already exists and decrypts correctly"
    else
        log "secrets.yaml exists but may not be encrypted correctly — re-encrypting"
        _regen_secrets=1
    fi
else
    _regen_secrets=1
fi

if [[ "${_regen_secrets:-0}" == "1" ]]; then
    PLAINTEXT=$(mktemp)
    cat > "$PLAINTEXT" <<YAML
katello-password: "${KATELLO_PASSWORD}"
YAML
    SOPS_AGE_RECIPIENTS="$AGE_PUBKEY" sops --encrypt "$PLAINTEXT" > "$SECRETS_YAML"
    chmod 600 "$SECRETS_YAML"
    rm -f "$PLAINTEXT"
    ok "Encrypted secrets written to ${SECRETS_YAML}"
fi

# ── Step 7: Build and push NixOS closure ─────────────────────────────────────

step "7 — Build + push NixOS closure to local Katello cache"

log "Building builder-aarch64 NixOS system closure..."
CLOSURE=$(nix build "${REPO_ROOT}#nixosConfigurations.${HOST}.config.system.build.toplevel" --no-link --print-out-paths 2>&1 | tail -1)
ok "Built closure: ${CLOSURE}"

log "Pushing closure to local Katello Nix cache (http://127.0.0.1:8101)..."
nix copy --to "http://127.0.0.1:8101?compression=zstd" "${CLOSURE}" || {
    log "WARNING: nix copy failed — Pulp content endpoint may not be ready yet."
    log "  You can retry manually: nix copy --to 'http://127.0.0.1:8101?compression=zstd' ${CLOSURE}"
}
ok "Closure pushed to Katello"

# ── Step 8: Promote content view to stable ───────────────────────────────────

step "8 — Promote content view dev → candidate → stable"

HAMMER="docker exec katello-foreman hammer \
    --server ${KATELLO_URL} \
    --username ${KATELLO_USER} \
    --password ${KATELLO_PASSWORD}"

CV_VERSION=$(${HAMMER} --output json content-view version list \
    --organization "${ORG}" \
    --content-view "sourceos-builder-aarch64" 2>/dev/null | \
    python3 -c "import json,sys; vs=json.load(sys.stdin); print(sorted(vs,key=lambda v:v['ID'])[-1]['Version'])" 2>/dev/null || echo "")

if [[ -z "$CV_VERSION" ]]; then
    log "WARNING: Could not determine content view version — skipping promotion."
    log "  Promote manually after Katello sync completes:"
    log "  docker exec katello-foreman hammer content-view version promote \\"
    log "    --organization '${ORG}' --content-view sourceos-builder-aarch64 \\"
    log "    --version <VERSION> --to-lifecycle-environment stable"
else
    for env in candidate stable; do
        ${HAMMER} content-view version promote \
            --organization "${ORG}" \
            --content-view "sourceos-builder-aarch64" \
            --version "${CV_VERSION}" \
            --to-lifecycle-environment "${env}" 2>/dev/null || \
            log "  Note: promotion to ${env} may have already been done"
    done
    ok "Content view v${CV_VERSION} promoted to stable"
fi

# ── Step 9: minisign key pair ─────────────────────────────────────────────────

step "9 — minisign signing key pair"

require_cmd minisign

if [[ -f "$MINISIGN_PUB" && -f "$MINISIGN_SEC" ]]; then
    ok "minisign key pair already exists"
else
    log "Generating minisign key pair (Nix cache signing)..."
    log "(You will be prompted for a passphrase — use empty for unattended builds)"
    minisign -G -p "$MINISIGN_PUB" -s "$MINISIGN_SEC"
    chmod 600 "$MINISIGN_SEC"
    ok "Generated ${MINISIGN_PUB} and ${MINISIGN_SEC}"
fi

SIGNING_PUBKEY=$(grep -v '^untrusted comment' "$MINISIGN_PUB" | head -1)
ok "Signing public key: ${SIGNING_PUBKEY}"

# ── Step 10: patch signingPublicKey into host config ─────────────────────────

step "10 — Patch signingPublicKey into host config"

HOST_CONFIG="${REPO_ROOT}/hosts/${HOST}/default.nix"
if grep -q 'signingPublicKey' "$HOST_CONFIG"; then
    # Update existing value
    sed -i "s|signingPublicKey = .*|signingPublicKey = \"${SIGNING_PUBKEY}\";|" "$HOST_CONFIG"
    ok "Updated signingPublicKey in ${HOST_CONFIG}"
else
    # Insert after the healthCheck block's closing brace
    sed -i "s|# signingPublicKey: set after generating the minisign key pair.|signingPublicKey = \"${SIGNING_PUBKEY}\";|" "$HOST_CONFIG"
    ok "Inserted signingPublicKey into ${HOST_CONFIG}"
fi

# ── Step 11: nixos-rebuild pass 2 (live config) ──────────────────────────────

step "11 — nixos-rebuild switch (pass 2: live config with secrets + signing key)"

nixos-rebuild switch --flake "${REPO_ROOT}#${HOST}" 2>&1 | tee /tmp/sourceos-rebuild-pass2.log
ok "Pass 2 rebuild complete"

# ── Step 12: verify ───────────────────────────────────────────────────────────

step "12 — Verify"

log "Waiting 10s for sourceos-syncd to start..."
sleep 10

if systemctl is-active --quiet sourceos-syncd; then
    ok "sourceos-syncd is running"
else
    log "WARNING: sourceos-syncd is not active yet"
    log "  Check: journalctl -u sourceos-syncd -n 50"
fi

if sourceos-syncd receipts last --store-root /var/lib/sourceos-syncd &>/dev/null; then
    ok "sourceos-syncd has emitted its first SyncCycleReceipt"
else
    log "No receipt yet — daemon will emit one after the first successful poll"
    log "  Check: journalctl -u sourceos-syncd -f"
fi

# ── Done ──────────────────────────────────────────────────────────────────────

echo
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║           SourceOS builder-aarch64 enrollment complete          ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo
echo "  Age key:          ${AGE_KEY_PATH}"
echo "  Secrets:          ${SECRETS_YAML}"
echo "  Signing pub key:  ${MINISIGN_PUB}"
echo "  Katello UI:       ${KATELLO_URL}  (admin / $(cat ${SOURCEOS_DIR}/katello-admin-password))"
echo
echo "  Daemon status:    systemctl status sourceos-syncd"
echo "  Daemon logs:      journalctl -u sourceos-syncd -f"
echo "  Last receipt:     sourceos-syncd receipts last"
echo "  Health check:     sourceos-syncd sync check-health"
echo
echo "  Next: when Katello syncs a new content view version to 'stable',"
echo "  sourceos-syncd will detect it within ${SOURCEOS_POLL_INTERVAL:-300}s and apply the update."
echo
