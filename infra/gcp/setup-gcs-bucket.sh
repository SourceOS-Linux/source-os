#!/usr/bin/env bash
# One-time setup: GCS bucket + service account + IAM for SourceOS CI.
set -euo pipefail

PROJECT=socioprophet-platform
BUCKET=sourceos-artifacts-socioprophet
SA_NAME=sourceos-ci
SA="${SA_NAME}@${PROJECT}.iam.gserviceaccount.com"
REGION=us-central1

echo "=== SourceOS CI: GCS + IAM setup ==="

gsutil mb -p "$PROJECT" -l "$REGION" -b on "gs://${BUCKET}" 2>/dev/null || echo "  bucket exists: gs://${BUCKET}"
gsutil lifecycle set /dev/stdin "gs://${BUCKET}" <<'LIFECYCLE'
{"rule":[{"action":{"type":"Delete"},"condition":{"age":90,"matchesPrefix":["closures/"]}}]}
LIFECYCLE

gcloud iam service-accounts create "$SA_NAME" \
  --project="$PROJECT" \
  --display-name="SourceOS CI builds" 2>/dev/null || echo "  SA exists: $SA"

gsutil iam ch "serviceAccount:${SA}:roles/storage.objectAdmin" "gs://${BUCKET}"

PROJECT_NUMBER=$(gcloud projects describe "$PROJECT" --format='value(projectNumber)')

gcloud iam service-accounts add-iam-policy-binding "$SA" \
  --project="$PROJECT" \
  --role=roles/iam.workloadIdentityUser \
  --member="principalSet://iam.googleapis.com/projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/github-pool/attribute.repository/SociOS-Linux/source-os"

echo ""
echo "=== Next: set up Workload Identity Federation ==="
echo "  bash infra/gcp/setup-wif.sh"
