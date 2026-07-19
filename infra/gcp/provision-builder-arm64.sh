#!/usr/bin/env bash
# provision-builder-arm64.sh — Create aarch64 build worker VM on GCP
set -euo pipefail

PROJECT="socioprophet-platform"
ACCOUNT="michael@socioprophet.ai"
ZONE="us-central1-b"
INSTANCE_NAME="sourceos-builder-arm64"
MACHINE_TYPE="t2a-standard-16"
DISK_SIZE="200"
DISK_TYPE="pd-ssd"
TAG="sourceos-builder"
FIREWALL_RULE_NAME="allow-builder-ssh"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "=== SourceOS ARM64 Builder Provisioning ==="
echo "Project      : $PROJECT"
echo "Account      : $ACCOUNT"
echo "Zone         : $ZONE"
echo "Machine type : $MACHINE_TYPE"
echo ""

# Ensure correct project + account
gcloud config set project "$PROJECT"
gcloud config set account "$ACCOUNT"

# --- Firewall rule ---
echo "[1/3] Creating firewall rule: $FIREWALL_RULE_NAME ..."
if gcloud compute firewall-rules describe "$FIREWALL_RULE_NAME" --project="$PROJECT" &>/dev/null; then
  echo "  Firewall rule already exists, skipping."
else
  gcloud compute firewall-rules create "$FIREWALL_RULE_NAME" \
    --project="$PROJECT" \
    --direction=INGRESS \
    --priority=1000 \
    --network=default \
    --action=ALLOW \
    --rules=tcp:22 \
    --source-ranges=35.235.240.0/20 \
    --target-tags="$TAG"
  echo "  Created."
fi

# --- VM instance ---
echo "[2/3] Creating VM instance: $INSTANCE_NAME ..."
if gcloud compute instances describe "$INSTANCE_NAME" --zone="$ZONE" --project="$PROJECT" &>/dev/null; then
  echo "  Instance already exists, skipping creation."
else
  gcloud compute instances create "$INSTANCE_NAME" \
    --project="$PROJECT" \
    --zone="$ZONE" \
    --machine-type="$MACHINE_TYPE" \
    --image-family="ubuntu-2204-lts-arm64" \
    --image-project="ubuntu-os-cloud" \
    --boot-disk-size="${DISK_SIZE}GB" \
    --boot-disk-type="$DISK_TYPE" \
    --boot-disk-device-name="$INSTANCE_NAME" \
    --tags="$TAG" \
    --metadata-from-file="startup-script=${SCRIPT_DIR}/startup-builder-arm64.sh" \
    --no-service-account \
    --no-scopes
  echo "  Created."
fi

# --- Summary ---
echo ""
echo "[3/3] Done."
echo ""
echo "======================================"
echo " ARM64 Builder VM ready"
echo "======================================"
echo " Instance : $INSTANCE_NAME ($ZONE)"
echo ""
echo "Next steps:"
echo "  1. Set the GitHub Actions runner token metadata:"
echo "       gcloud compute instances add-metadata $INSTANCE_NAME \\"
echo "         --zone=$ZONE \\"
echo "         --metadata gh-runner-token=<token>"
echo ""
echo "  2. Optionally set an SSH pubkey for nix remote builds:"
echo "       gcloud compute instances add-metadata $INSTANCE_NAME \\"
echo "         --zone=$ZONE \\"
echo "         --metadata nix-ssh-pubkey=\"<pubkey>\""
echo ""
echo "  3. Wait ~10 min for Nix install + runner setup, then check logs:"
echo "       gcloud compute ssh $INSTANCE_NAME --zone=$ZONE -- \\"
echo "         tail -f /var/log/sourceos-builder-startup.log"
echo ""
echo "  4. Verify the runner appears in GitHub:"
echo "       https://github.com/organizations/SourceOS-Linux/settings/actions/runners"
echo "======================================"
