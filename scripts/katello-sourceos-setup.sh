#!/usr/bin/env bash
# Sets up SourceOS content structure in a running Foreman+Katello instance.
# Run after the foreman-installer bootstrap completes.
#
# Usage:
#   FOREMAN_URL=https://127.0.0.1:8443 \
#   FOREMAN_USER=admin \
#   FOREMAN_PASSWORD=<password> \
#   ORG=SocioProphet \
#   ./scripts/katello-sourceos-setup.sh
#
# Idempotent: re-running skips objects that already exist.

set -euo pipefail

FOREMAN_URL="${FOREMAN_URL:-https://127.0.0.1:8443}"
FOREMAN_USER="${FOREMAN_USER:-admin}"
FOREMAN_PASSWORD="${FOREMAN_PASSWORD:?FOREMAN_PASSWORD required}"
ORG="${ORG:-SocioProphet}"

HAMMER="hammer --server ${FOREMAN_URL} --username ${FOREMAN_USER} --password ${FOREMAN_PASSWORD}"

echo "=== SourceOS Katello content setup ==="
echo "Foreman: ${FOREMAN_URL}  Org: ${ORG}"

# ── 1. Lifecycle environments ─────────────────────────────────────────────
# Mirrors source-os/channels: dev → candidate → stable
echo "--- lifecycle environments"
$HAMMER lifecycle-environment create --organization "${ORG}" \
    --name dev --prior Library 2>/dev/null || echo "  dev: exists"
$HAMMER lifecycle-environment create --organization "${ORG}" \
    --name candidate --prior dev 2>/dev/null || echo "  candidate: exists"
$HAMMER lifecycle-environment create --organization "${ORG}" \
    --name stable --prior candidate 2>/dev/null || echo "  stable: exists"

# ── 2. Product ────────────────────────────────────────────────────────────
echo "--- product"
$HAMMER product create --organization "${ORG}" \
    --name "SourceOS" \
    --description "SourceOS Linux image artifacts and Nix binary cache" \
    2>/dev/null || echo "  SourceOS product: exists"

# ── 3. Repositories ───────────────────────────────────────────────────────
echo "--- repositories"

# aarch64: Nix binary cache (file-type; harmonia serves from local /nix/store)
$HAMMER repository create --organization "${ORG}" \
    --product "SourceOS" \
    --name "nix-cache-aarch64-linux" \
    --content-type file \
    --url "https://cache.nixos.org" \
    --download-policy immediate \
    2>/dev/null || echo "  nix-cache-aarch64-linux: exists"

# aarch64: NixOS system closure artifacts (NAR exports from local store)
$HAMMER repository create --organization "${ORG}" \
    --product "SourceOS" \
    --name "sourceos-closures-aarch64" \
    --content-type file \
    2>/dev/null || echo "  sourceos-closures-aarch64: exists"

# x86_64: Nix binary cache
$HAMMER repository create --organization "${ORG}" \
    --product "SourceOS" \
    --name "nix-cache-x86_64-linux" \
    --content-type file \
    --url "https://cache.nixos.org" \
    --download-policy immediate \
    2>/dev/null || echo "  nix-cache-x86_64-linux: exists"

# x86_64: NixOS system closure artifacts
$HAMMER repository create --organization "${ORG}" \
    --product "SourceOS" \
    --name "sourceos-closures-x86_64" \
    --content-type file \
    2>/dev/null || echo "  sourceos-closures-x86_64: exists"

# ── 4. Content views ──────────────────────────────────────────────────────
echo "--- content views"

# ── aarch64 builder ──
$HAMMER content-view create --organization "${ORG}" \
    --name "sourceos-builder-aarch64" \
    --description "SourceOS builder image content view for aarch64 (Asahi/M2)" \
    2>/dev/null || echo "  sourceos-builder-aarch64: exists"

$HAMMER content-view add-repository --organization "${ORG}" \
    --name "sourceos-builder-aarch64" \
    --product "SourceOS" \
    --repository "nix-cache-aarch64-linux" \
    2>/dev/null || echo "  nix-cache-aarch64-linux already in view"

$HAMMER content-view add-repository --organization "${ORG}" \
    --name "sourceos-builder-aarch64" \
    --product "SourceOS" \
    --repository "sourceos-closures-aarch64" \
    2>/dev/null || echo "  sourceos-closures-aarch64 already in view"

# ── x86_64 (shared by canary and stable/exit hosts; they track different lifecycle envs) ──
$HAMMER content-view create --organization "${ORG}" \
    --name "sourceos-x86_64" \
    --description "SourceOS x86_64 image content view (canary tracks candidate env; stable/exit track stable env)" \
    2>/dev/null || echo "  sourceos-x86_64: exists"

$HAMMER content-view add-repository --organization "${ORG}" \
    --name "sourceos-x86_64" \
    --product "SourceOS" \
    --repository "nix-cache-x86_64-linux" \
    2>/dev/null || echo "  nix-cache-x86_64-linux already in view"

$HAMMER content-view add-repository --organization "${ORG}" \
    --name "sourceos-x86_64" \
    --product "SourceOS" \
    --repository "sourceos-closures-x86_64" \
    2>/dev/null || echo "  sourceos-closures-x86_64 already in view"

# ── 5. Initial publish + dev promotion (idempotent) ───────────────────────

_bootstrap_cv() {
    local cv_name="$1"
    local desc="$2"

    local existing
    existing=$($HAMMER --output json content-view version list \
        --organization "${ORG}" \
        --content-view "${cv_name}" 2>/dev/null | \
        python3 -c "import json,sys; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "0")

    if [[ "${existing}" -eq 0 ]]; then
        echo "--- publishing ${cv_name} (this may take a minute)"
        $HAMMER content-view publish --organization "${ORG}" \
            --name "${cv_name}" \
            --description "${desc}"
    else
        echo "  ${cv_name}: already has ${existing} version(s) — skipping publish"
    fi

    local cv_version
    cv_version=$($HAMMER --output json content-view version list \
        --organization "${ORG}" \
        --content-view "${cv_name}" | python3 -c \
        "import json,sys; vs=json.load(sys.stdin); print(sorted(vs,key=lambda v:v['ID'])[-1]['Version'])")

    echo "--- promoting ${cv_name} v${cv_version} → dev"
    $HAMMER content-view version promote \
        --organization "${ORG}" \
        --content-view "${cv_name}" \
        --version "${cv_version}" \
        --to-lifecycle-environment dev \
        2>/dev/null || echo "  already at dev"
}

_bootstrap_cv "sourceos-builder-aarch64" "Initial publish — aarch64 dev channel bootstrap"
_bootstrap_cv "sourceos-x86_64"          "Initial publish — x86_64 dev channel bootstrap"

echo "=== Setup complete ==="
echo "Content views created and promoted to dev:"
echo "  sourceos-builder-aarch64  (aarch64 M2/Asahi builder)"
echo "  sourceos-x86_64           (x86_64 canary + stable + exit hosts)"
echo ""
echo "Next: build and push your first real closure:"
echo "  bash scripts/build-and-push.sh                         # aarch64 builder"
echo "  bash scripts/build-and-push.sh --host canary-x86_64   # x86_64 canary"
