#!/usr/bin/env bash
# nix-cache-push.sh — push built store paths (+ closure) to the SourceOS GCS Nix
# binary cache so later builds pull them warm instead of rebuilding.
#
# Best-effort: a no-op (exit 0) unless both NIX_CACHE_BUCKET and
# NIX_CACHE_SECRET_KEY are set, and never fails the build.
#
#   NIX_CACHE_BUCKET=sourceos-artifacts-socioprophet \
#   NIX_CACHE_SECRET_KEY="$(cat cache.key)" \
#   bash scripts/nix-cache-push.sh <store-path|installable> ...
#
# Pull side is configured by .github/actions/setup-nix (public HTTPS substituter
# at gs://$BUCKET/nix-cache, served via https://storage.googleapis.com/...).
set -uo pipefail

BUCKET="${NIX_CACHE_BUCKET:-}"
KEY="${NIX_CACHE_SECRET_KEY:-}"
log() { printf '[nix-cache] %s\n' "$*"; }

[ -z "$BUCKET" ] && { log "NIX_CACHE_BUCKET unset — skipping push"; exit 0; }
[ -z "$KEY" ]    && { log "NIX_CACHE_SECRET_KEY unset — skipping push"; exit 0; }
command -v gsutil >/dev/null 2>&1 || { log "gsutil absent — skipping push"; exit 0; }
command -v nix    >/dev/null 2>&1 || { log "nix absent — skipping push"; exit 0; }
[ "$#" -eq 0 ] && { log "no paths given — nothing to push"; exit 0; }

tmpkey="$(mktemp)"; printf '%s' "$KEY" > "$tmpkey"
localdir="$(mktemp -d)"
cleanup() { rm -f "$tmpkey"; rm -rf "$localdir"; }
trap cleanup EXIT

# Copy the installables + their full runtime closure into a signed file:// cache.
if ! nix copy --to "file://$localdir?secret-key=$tmpkey" "$@" 2>&1; then
  log "nix copy failed (non-fatal) — skipping rsync"; exit 0
fi
# Sync to GCS (uses ambient GCP auth from the workflow's WIF login).
gsutil -m -q rsync -r "$localdir" "gs://$BUCKET/nix-cache/" \
  && log "pushed closure of [$*] to gs://$BUCKET/nix-cache/" \
  || log "gsutil rsync failed (non-fatal)"
exit 0
