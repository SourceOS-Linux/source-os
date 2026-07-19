#!/usr/bin/env bash
# One-time setup: GitHub Actions Workload Identity Federation for GCP.
set -euo pipefail

PROJECT=socioprophet-platform
POOL_ID=github-pool
PROVIDER_ID=github-provider
SA=sourceos-ci@${PROJECT}.iam.gserviceaccount.com

echo "=== SourceOS: GitHub Actions WIF setup ==="

gcloud iam workload-identity-pools create "$POOL_ID" \
  --project="$PROJECT" \
  --location=global \
  --display-name="GitHub Actions pool" 2>/dev/null || echo "  pool exists"

gcloud iam workload-identity-pools providers create-oidc "$PROVIDER_ID" \
  --project="$PROJECT" \
  --location=global \
  --workload-identity-pool="$POOL_ID" \
  --display-name="GitHub OIDC" \
  --issuer-uri="https://token.actions.githubusercontent.com" \
  --attribute-mapping="google.subject=assertion.sub,attribute.repository=assertion.repository,attribute.ref=assertion.ref" \
  --attribute-condition="assertion.repository_owner=='SociOS-Linux' || assertion.repository_owner=='SourceOS-Linux'" 2>/dev/null || echo "  provider exists"

PROJECT_NUMBER=$(gcloud projects describe "$PROJECT" --format='value(projectNumber)')

echo ""
echo "=== Set these GitHub secrets in SourceOS-Linux/source-os ==="
echo ""
echo "GCP_WORKLOAD_IDENTITY_PROVIDER:"
echo "  projects/${PROJECT_NUMBER}/locations/global/workloadIdentityPools/${POOL_ID}/providers/${PROVIDER_ID}"
echo ""
echo "GCP_SERVICE_ACCOUNT:"
echo "  ${SA}"
