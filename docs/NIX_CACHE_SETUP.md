# SourceOS Nix binary cache — one-time setup

Replaces the sunset `magic-nix-cache` (which threw `418 / ResourceExhausted`
throttling on large builds) with a persistent, GCS-backed Nix binary cache.
Builds **pull** warm over public HTTPS and **push** their closures so later
builds — especially custom image builds — don't rebuild from scratch.

Until the steps below are done, the pipelines simply install Nix and fall back
to `cache.nixos.org` (a strict reliability improvement over the throttling
action). The cache turns on once the vars/secret are present — nothing breaks
in the meantime.

## How it works
- **Pull**: `.github/actions/setup-nix` adds `https://storage.googleapis.com/<bucket>/nix-cache`
  as an extra substituter (public-read prefix) + the trusted public key.
- **Push**: `scripts/nix-cache-push.sh` copies built store paths to a signed
  `file://` cache and `gsutil rsync`s them to `gs://<bucket>/nix-cache/`
  (using the workflow's existing WIF GCP auth). `build-custom-image.sh` calls it
  after every build, so both the GitHub and GCP build lanes seed the cache.

> **Status (2026-06-22): this is already provisioned.** The cache lives in a
> **dedicated** public bucket `gs://sourceos-nix-cache-socioprophet` (NOT the
> artifacts bucket, which holds private `user-builds/` and stays private). The
> Actions vars/secrets below are set, and the keys are stored locally in
> `~/.sourceos-keys/`. The steps remain here for rotation / re-provisioning.

## One-time setup
1. **Generate a cache key pair** (ed25519, Nix's own format):
   ```sh
   nix-store --generate-binary-cache-key sourceos-nix-cache-1 cache-secret.key cache-public.key
   cat cache-public.key   # e.g. sourceos-nix-cache-1:AbC123...=
   ```
2. **Use a DEDICATED public bucket** — never make the artifacts bucket public
   (it contains private user builds). Create one and make only it public-read:
   ```sh
   gcloud storage buckets create gs://sourceos-nix-cache-socioprophet \
     --location=us-central1 --uniform-bucket-level-access
   gcloud storage buckets add-iam-policy-binding gs://sourceos-nix-cache-socioprophet \
     --member=allUsers --role=roles/storage.objectViewer
   # let the CI service account push closures:
   gcloud storage buckets add-iam-policy-binding gs://sourceos-nix-cache-socioprophet \
     --member=serviceAccount:sourceos-ci@socioprophet-platform.iam.gserviceaccount.com \
     --role=roles/storage.objectAdmin
   ```
3. **Set repo Actions variables** (Settings → Secrets and variables → Actions → Variables):
   - `NIX_CACHE_URL` = `https://storage.googleapis.com/sourceos-nix-cache-socioprophet/nix-cache`
   - `NIX_CACHE_PUBKEY` = the `sourceos-nix-cache-1:…` line from step 1
   - `NIX_CACHE_BUCKET` = `sourceos-nix-cache-socioprophet`
4. **Set the push secret** (Settings → Secrets → Actions → Secrets):
   - `NIX_CACHE_SECRET_KEY` = contents of `cache-secret.key`
5. Optional but recommended — **seed the editions** once so the first user
   builds are fast: run `build-custom` for desktop/server/edge (the closures get
   pushed automatically).

## Notes
- Push is best-effort: missing secret/bucket → no-op, never fails a build.
- The GCP build-VM lane (`gcp-build-custom-startup.sh`) inherits the same env
  via instance metadata if you pass `NIX_CACHE_*` there too (follow-up).
- Pull is anonymous, so PRs from forks still benefit from a warm cache.
