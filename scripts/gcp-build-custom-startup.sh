#!/usr/bin/env bash
# gcp-build-custom-startup.sh — runs ON a GCP build VM (no-SSH lane) to build a
# user-customized SourceOS image for the paid tier. The backend creates a VM
# whose startup-script curls + execs this, passing the spec via instance
# metadata. Builds privately, uploads the artifact + status.json to the user's
# GCS prefix, then self-deletes the VM.
#
# Instance metadata keys read here:
#   sourceos-spec       build spec JSON
#   sourceos-uid        owning user id
#   sourceos-build-id   build id
#   sourceos-gcs-prefix gs://bucket/user-builds/<uid>/<id>
set -uo pipefail
exec > >(tee /var/log/sourceos-build.log) 2>&1
echo "=== sourceos custom build start $(date -u) ==="

md() { curl -s -H "Metadata-Flavor: Google" \
  "http://metadata.google.internal/computeMetadata/v1/instance/attributes/$1"; }
ZONE="$(curl -s -H 'Metadata-Flavor: Google' \
  http://metadata.google.internal/computeMetadata/v1/instance/zone | awk -F/ '{print $NF}')"
NAME="$(curl -s -H 'Metadata-Flavor: Google' \
  http://metadata.google.internal/computeMetadata/v1/instance/name)"

SPEC="$(md sourceos-spec)"
UID_="$(md sourceos-uid)"
BUILD_ID="$(md sourceos-build-id)"
PREFIX="$(md sourceos-gcs-prefix)"
# Optional: self-managed signing + cache (graceful if unset).
SIGN_KEY="$(md sourceos-sign-secret-key || true)"
CACHE_KEY="$(md sourceos-nix-cache-secret-key || true)"
CACHE_BUCKET="$(md sourceos-nix-cache-bucket || true)"
OS_VERSION="$(md sourceos-version || true)"; OS_VERSION="${OS_VERSION:-26.11}"

status() { printf '%s' "$1" | gsutil cp - "$PREFIX/status.json" || true; }
teardown() { gcloud --quiet compute instances delete "$NAME" --zone="$ZONE" || true; }
trap teardown EXIT

status '{"status":"building","lane":"gcp"}'

# Base deps + Nix (single-user is fine on an ephemeral VM).
apt-get update -qq
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq git jq curl xz-utils >/dev/null 2>&1
if ! command -v nix >/dev/null 2>&1; then
  curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix \
    | sh -s -- install --no-confirm
  . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh || true
fi
export PATH="/nix/var/nix/profiles/default/bin:$PATH"

# Build via the shared compose script (same one the GitHub lane uses).
git clone --depth=1 https://github.com/SourceOS-Linux/source-os.git /root/source-os
cd /root/source-os
printf '%s' "$SPEC" > /tmp/spec.json

if SPEC_FILE=/tmp/spec.json OUT=/root/out GCS_PREFIX="$PREFIX" \
     BUILD_ID="$BUILD_ID" BUILD_UID="$UID_" VERSION="$OS_VERSION" \
     SOURCEOS_SIGN_SECRET_KEY="$SIGN_KEY" \
     NIX_CACHE_SECRET_KEY="$CACHE_KEY" NIX_CACHE_BUCKET="$CACHE_BUCKET" \
     bash scripts/build-custom-image.sh; then
  ART="$(cat /root/out/artifact-url.txt 2>/dev/null || true)"
  status "$(printf '{"status":"complete","lane":"gcp","artifact":"%s"}' "$ART")"
  echo "=== build OK: $ART ==="
else
  status '{"status":"error","lane":"gcp"}'
  echo "=== build FAILED ==="
fi
echo "=== done $(date -u) — tearing down ==="
